--!strict
--[[
	LoadoutDisplay
	Shows YOUR selected weapons lying on the safehouse workbench (client-local
	models at Safehouse.Workbench.WeaponDisplays). They rebuild with a small
	drop-in whenever the loadout changes, so the LOADOUT camera shot always
	shows the real kit you'll deploy with.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local WeaponBuilder = require(Shared.Builders.WeaponBuilder)

local SettingsController = require(script.Parent.SettingsController)

local LoadoutDisplay = {}

-- Lying on the left side, barrel toward +Z, sights facing the alley (-X).
local LAY_FLAT = CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, math.rad(-90))
local OFFSETS: { [Types.WeaponSlot]: CFrame } = {
	Primary = CFrame.new(-0.45, 0, -1.0),
	Secondary = CFrame.new(0.7, 0, -1.6),
}

local anchors: { [Types.WeaponSlot]: BasePart } = {}
local shown: { [Types.WeaponSlot]: { Id: string, Model: Model } } = {}

local function dropIn(model: Model, target: CFrame)
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		local t = math.clamp(elapsed / 0.35, 0, 1)
		local bounce = 1 - (1 - t) ^ 3
		if model.Parent == nil then
			connection:Disconnect()
			return
		end
		model:PivotTo(target * CFrame.new(0, (1 - bounce) * 0.6, 0) * CFrame.Angles(0, (1 - bounce) * 0.3, 0))
		if t >= 1 then
			connection:Disconnect()
		end
	end)
end

local function show(slot: Types.WeaponSlot, weaponId: string, animate: boolean)
	local anchor = anchors[slot]
	if not anchor or not WeaponBuilder.has(weaponId) then
		return
	end
	local existing = shown[slot]
	if existing and existing.Id == weaponId then
		return
	end
	if existing then
		existing.Model:Destroy()
	end
	local target = anchor.CFrame * OFFSETS[slot] * LAY_FLAT
	local handles = WeaponBuilder.build(weaponId, target, true)
	handles.Model.Name = "Display_" .. weaponId
	handles.Model.Parent = Workspace
	shown[slot] = { Id = weaponId, Model = handles.Model }
	if animate then
		dropIn(handles.Model, target)
	end
end

local function apply(loadout: Types.Loadout, animate: boolean)
	show("Primary", loadout.Primary, animate)
	show("Secondary", loadout.Secondary, animate)
end

function LoadoutDisplay.init()
	task.spawn(function()
		local safehouse = Workspace:WaitForChild(Config.World.SafehouseName, 60)
		local bench = safehouse and safehouse:WaitForChild("Workbench", 30)
		local displays = bench and bench:WaitForChild("WeaponDisplays", 30)
		if not displays then
			warn("[LoadoutDisplay] Workbench.WeaponDisplays not found")
			return
		end
		local primary = displays:WaitForChild("Display_Primary", 10)
		local secondary = displays:WaitForChild("Display_Secondary", 10)
		if primary and primary:IsA("BasePart") then
			anchors.Primary = primary
		end
		if secondary and secondary:IsA("BasePart") then
			anchors.Secondary = secondary
		end
		apply(SettingsController.getLoadout(), false)
		SettingsController.LoadoutChanged:Connect(function(loadout: any)
			apply(loadout, true)
		end)
	end)
end

return LoadoutDisplay
