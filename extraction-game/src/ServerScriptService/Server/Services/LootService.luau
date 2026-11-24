--!strict
--[[
	LootService
	Server-authoritative carry system for heavy loot bags.

	  • spawnBag(cframe, value)   physical bag with a "Grab" prompt
	  • Grab → bag is slung on the player's back (massless, no collision),
	    character attributes CarryingBag / CarryValue drive the slowed movement
	  • Drop (G / D-pad down) → bag lands in front of you, grabbable again
	  • Death or leaving drops the bag where you fell (unextracted loot is lost
	    to whoever picks it up)
	  • consumeCarried / giveCarried let the vehicle trunk move bags in and out
	  • Practice bags by the garage respawn after they leave their pad

	Phase 4 lootables call spawnBag(); extraction banks CarryValue + trunk value.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local LootBagBuilder = require(Shared.Builders.LootBagBuilder)
local Net = require(Shared.Net)

local LootService = {}

type Carry = {
	Value: number,
	Model: Model,
}

local carried: { [Player]: Carry } = {}

local function formatValue(value: number): string
	local s = tostring(math.floor(value))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return "$" .. out
end

local function torsoOf(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then torso else nil
end

local function setCarryAttributes(player: Player, value: number?)
	player:SetAttribute("CarryValue", value or 0)
	local character = player.Character
	if character then
		character:SetAttribute("CarryingBag", value ~= nil)
		character:SetAttribute("CarryValue", value or 0)
	end
end

local function setPhysical(model: Model, physical: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local isBody = d == model.PrimaryPart
			d.Massless = not (physical and isBody)
			d.CanCollide = physical and isBody
			d.CanQuery = physical
		end
	end
end

local pickUp: (player: Player, model: Model, value: number) -> ()

local function addPrompt(model: Model, value: number)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "Grab"
	prompt.ObjectText = "LOOT · " .. formatValue(value)
	prompt.HoldDuration = 0.45
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = body
	prompt.Triggered:Connect(function(player: Player)
		pickUp(player, model, value)
	end)
end

local function attachToBack(player: Player, model: Model, value: number): boolean
	local character = player.Character
	local torso = if character then torsoOf(character) else nil
	local body = model.PrimaryPart
	if not character or not torso or not body then
		return false
	end
	local prompt = body:FindFirstChild("GrabPrompt")
	if prompt then
		prompt:Destroy()
	end
	setPhysical(model, false)
	body.Anchored = false
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = torso
	weld.Part1 = body
	-- Across the upper back, long axis side to side.
	weld.C0 = CFrame.new(0, 0.15, 1.05) * CFrame.Angles(0, math.rad(90), math.rad(8))
	weld.Parent = body
	model.Parent = character
	carried[player] = { Value = value, Model = model }
	setCarryAttributes(player, value)
	return true
end

pickUp = function(player: Player, model: Model, value: number)
	if carried[player] or player:GetAttribute("State") ~= "Deployed" then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or humanoid.Sit then
		return
	end
	local body = model.PrimaryPart
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not body or not root or not root:IsA("BasePart") or (body.Position - root.Position).Magnitude > 12 then
		return
	end
	local pad = model:GetAttribute("PracticePad")
	attachToBack(player, model, value)
	if typeof(pad) == "number" then
		LootService.schedulePracticeRespawn(pad)
	end
end

function LootService.spawnBag(cf: CFrame, value: number, parent: Instance?): Model
	local handles = LootBagBuilder.build(cf, 1, false)
	handles.Model:SetAttribute("Value", value)
	addPrompt(handles.Model, value)
	handles.Model.Parent = parent or workspace
	return handles.Model
end

function LootService.drop(player: Player)
	local carry = carried[player]
	if not carry then
		return
	end
	carried[player] = nil
	local model = carry.Model
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local weld = model.PrimaryPart and model.PrimaryPart:FindFirstChild("CarryWeld")
	if weld then
		weld:Destroy()
	end
	local dropCF = if root and root:IsA("BasePart")
		then root.CFrame * CFrame.new(0, -1.2, -Config.Loot.DropDistance)
		elseif model.PrimaryPart then model.PrimaryPart.CFrame
		else CFrame.identity
	model.Parent = workspace
	model:PivotTo(dropCF)
	setPhysical(model, true)
	model:SetAttribute("PracticePad", nil)
	addPrompt(model, carry.Value)
	if player.Parent then
		setCarryAttributes(player, nil)
	end
end

function LootService.isCarrying(player: Player): boolean
	return carried[player] ~= nil
end

function LootService.carryValue(player: Player): number
	local carry = carried[player]
	return if carry then carry.Value else 0
end

-- Removes the carried bag (e.g. loaded into a trunk) and returns its value.
function LootService.consumeCarried(player: Player): number?
	local carry = carried[player]
	if not carry then
		return nil
	end
	carried[player] = nil
	carry.Model:Destroy()
	setCarryAttributes(player, nil)
	return carry.Value
end

-- Puts a new bag of `value` straight onto the player's back (e.g. from a trunk).
function LootService.giveCarried(player: Player, value: number): boolean
	if carried[player] then
		return false
	end
	local character = player.Character
	local torso = if character then torsoOf(character) else nil
	if not torso then
		return false
	end
	local handles = LootBagBuilder.build(torso.CFrame, 1, false)
	handles.Model:SetAttribute("Value", value)
	return attachToBack(player, handles.Model, value)
end

--------------------------------------------------------------------------------
-- Practice bags
--------------------------------------------------------------------------------
local practiceFolder: Folder? = nil
local practiceTokens: { [number]: number } = {}

local function spawnPractice(index: number)
	local def = Config.Loot.PracticeBags[index]
	local folder = practiceFolder
	if not def or not folder then
		return
	end
	local cf = Config.World.Origin * CFrame.new(def.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(90), 0)
	local model = LootService.spawnBag(cf, def.Value, folder)
	model:SetAttribute("PracticePad", index)
end

function LootService.schedulePracticeRespawn(index: number)
	practiceTokens[index] = (practiceTokens[index] or 0) + 1
	local token = practiceTokens[index]
	task.delay(Config.Loot.PracticeRespawn, function()
		if practiceTokens[index] == token then
			spawnPractice(index)
		end
	end)
end

function LootService.init(safehouse: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Loot"
	folder.Parent = safehouse
	practiceFolder = folder
	for index in Config.Loot.PracticeBags do
		spawnPractice(index)
	end

	Net.event(Net.Events.DropBag).OnServerEvent:Connect(function(player: Player)
		LootService.drop(player)
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Once(function()
					LootService.drop(player)
				end)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		LootService.drop(player)
	end)
end

return LootService
