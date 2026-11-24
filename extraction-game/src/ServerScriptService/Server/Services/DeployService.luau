--!strict
--[[
	DeployService
	Server-authoritative player state machine:

		Menu  --(RequestDeploy)-->  Deploying  --(character spawned)-->  Deployed
		  ^                                                                  |
		  +------------------(death, after ReturnToMenuDelay)----------------+

	Characters never auto-load: you only exist in the world after DEPLOY.
	State is replicated through the "State" player attribute.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

local DeployService = {}
DeployService.Deployed = Signal.new() -- (player, character)

local deployPoints: { BasePart } = {}
local pointCursor = 0
local lastRequest: { [Player]: number } = {}

local function setState(player: Player, state: Types.PlayerState)
	player:SetAttribute("State", state)
end

local function getState(player: Player): string?
	local value = player:GetAttribute("State")
	return if typeof(value) == "string" then value else nil
end

local function nextDeployCFrame(): CFrame
	if #deployPoints == 0 then
		return Config.World.Origin * CFrame.new(5, 3.5, -2)
	end
	pointCursor = pointCursor % #deployPoints + 1
	local point = deployPoints[pointCursor]
	-- HumanoidRootPart centre ≈ 3 studs above the floor for R15 / R6.
	return point.CFrame + Vector3.new(0, 3.2, 0)
end

local function returnToMenu(player: Player, character: Model)
	if player.Parent == nil or player.Character ~= character then
		return
	end
	player.Character = nil
	character:Destroy()
	setState(player, "Menu")
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.Died:Once(function()
		task.delay(Config.Deploy.ReturnToMenuDelay, returnToMenu, player, character)
	end)
	-- Character removed some other way (kick, LoadCharacter elsewhere).
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil and player.Parent and player.Character == nil and getState(player) == "Deployed" then
			setState(player, "Menu")
		end
	end)
end

local function onDeployRequest(player: Player)
	if getState(player) ~= "Menu" then
		return
	end
	local now = os.clock()
	if (lastRequest[player] or -math.huge) + Config.Deploy.RequestCooldown > now then
		return
	end
	lastRequest[player] = now
	setState(player, "Deploying")

	local spawnCF = nextDeployCFrame()
	local placement = player.CharacterAdded:Connect(function(character: Model)
		character:PivotTo(spawnCF)
	end)
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	placement:Disconnect()

	local character = player.Character
	if not ok or not character or not player.Parent then
		warn("[Deploy] spawn failed for", player.Name, err)
		if player.Parent then
			setState(player, "Menu")
		end
		return
	end

	-- Re-assert placement in case appearance loading moved the rig.
	if (character:GetPivot().Position - spawnCF.Position).Magnitude > 4 then
		character:PivotTo(spawnCF)
	end
	watchCharacter(player, character)
	character:SetAttribute("Stance", "Stand")
	character:SetAttribute("Sprinting", false)
	character:SetAttribute("AimPitch", 0)
	character:SetAttribute("Aiming", false)
	DeployService.Deployed:Fire(player, character)
	setState(player, "Deployed")
end

function DeployService.init(safehouse: Model)
	Players.CharacterAutoLoads = false

	local folder = safehouse:FindFirstChild("DeployPoints")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(deployPoints, child)
			end
		end
		table.sort(deployPoints, function(a: BasePart, b: BasePart): boolean
			return a.Name < b.Name
		end)
	else
		warn("[Deploy] Safehouse has no DeployPoints folder; using fallback spawn.")
	end

	local function onPlayerAdded(player: Player)
		-- If CharacterAutoLoads was still on when this player joined, remove
		-- the stray rig so everyone starts in the menu.
		local stray = player.Character
		if stray then
			player.Character = nil
			stray:Destroy()
		end
		setState(player, "Menu")
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastRequest[player] = nil
	end)

	Net.event(Net.Events.RequestDeploy).OnServerEvent:Connect(onDeployRequest)
end

return DeployService
