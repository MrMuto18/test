-- ClientState (ModuleScript) - StarterPlayerScripts/SandsweepClient/ClientState
-- Client mirror of the server-owned state + tiny signal helpers.
-- The client NEVER decides cash, weight or purchases; it only displays them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = Shared:WaitForChild("Remotes")

local ClientState = {}

ClientState.State = {
	Loaded = false,
	Cash = 0,
	BagKg = 0,
	BagTier = 1,
	EquippedTool = "Hands",
	OwnedTools = { Hands = true },
	Skills = { DigSpeed = 0, DigRadius = 0, SandValue = 0, WalkSpeed = 0 },
	Finds = {},
	OwnedVehicles = {},
	Factory = {},
	FactoryBufferKg = 0,
	Stats = {},
	Derived = GameConfig.ComputeStats(GameConfig.DefaultData),
	DataMode = "Pending",
}
ClientState.Lot = { Name = GameConfig.Lot.Name, Percent = 0, Generating = false, FindsRemaining = #GameConfig.Finds }
ClientState.UIOpen = false
ClientState.DigHeld = false -- set by the mobile DIG button
ClientState.InVehicle = nil -- { Model, Config, ... } while seated in a machine
ClientState.Crosshair = "idle" -- "idle" | "valid" | "full" | "far" | "outside"

-- Pure-Lua signal (no table copying, safe to pass any value)
local function newSignal()
	local listeners = {}
	local signal = {}
	function signal:Connect(fn)
		listeners[fn] = true
		return {
			Disconnect = function()
				listeners[fn] = nil
			end,
		}
	end
	function signal:Fire(...)
		for fn in pairs(listeners) do
			task.spawn(fn, ...)
		end
	end
	return signal
end

ClientState.Changed = newSignal() -- (state)
ClientState.LotChanged = newSignal() -- (lot)
ClientState.BagChanged = newSignal() -- (bagKg, capacity)
ClientState.Notified = newSignal() -- (payload)
ClientState.DigResult = newSignal() -- (kg, bagKg, capacity, position)
ClientState.MenuRequested = newSignal() -- (menuName)

local function applySnapshot(snapshot)
	if type(snapshot) ~= "table" or not snapshot.Loaded then
		return
	end
	local previousTool = ClientState.State.EquippedTool
	ClientState.State = snapshot
	if snapshot.Lot then
		ClientState.Lot = snapshot.Lot
		ClientState.LotChanged:Fire(ClientState.Lot)
	end
	ClientState.Changed:Fire(snapshot, previousTool)
	ClientState.BagChanged:Fire(snapshot.BagKg, snapshot.Derived.Capacity)
end

function ClientState.Init()
	Remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(applySnapshot)
	Remotes:WaitForChild("LotUpdate").OnClientEvent:Connect(function(lot)
		if type(lot) == "table" then
			ClientState.Lot = lot
			ClientState.LotChanged:Fire(lot)
		end
	end)
	Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			ClientState.Notified:Fire(payload)
		end
	end)
	Remotes:WaitForChild("DigResult").OnClientEvent:Connect(function(kg, bagKg, capacity, position)
		ClientState.State.BagKg = bagKg
		if ClientState.State.Derived then
			ClientState.State.Derived.Capacity = capacity
		end
		ClientState.DigResult:Fire(kg, bagKg, capacity, position)
		ClientState.BagChanged:Fire(bagKg, capacity)
	end)
	Remotes:WaitForChild("OpenMenu").OnClientEvent:Connect(function(menuName)
		ClientState.MenuRequested:Fire(menuName)
	end)

	task.spawn(function()
		local getState = Remotes:WaitForChild("GetState")
		for _ = 1, 60 do
			local ok, snapshot = pcall(function()
				return getState:InvokeServer()
			end)
			if ok and type(snapshot) == "table" and snapshot.Loaded then
				applySnapshot(snapshot)
				return
			end
			task.wait(1)
		end
	end)
end

-- Ask the server to buy/equip something. Returns success, message.
function ClientState.Purchase(kind, id)
	local ok, success, message = pcall(function()
		return Remotes:WaitForChild("Purchase"):InvokeServer(kind, id)
	end)
	if not ok then
		return false, "Connection hiccup - try again"
	end
	return success == true, message or ""
end

function ClientState.GetStats()
	return ClientState.State.Derived or GameConfig.ComputeStats(GameConfig.DefaultData)
end

function ClientState.BagFraction()
	local stats = ClientState.GetStats()
	if stats.Capacity <= 0 then
		return 0
	end
	return math.clamp(ClientState.State.BagKg / stats.Capacity, 0, 1)
end

return ClientState
