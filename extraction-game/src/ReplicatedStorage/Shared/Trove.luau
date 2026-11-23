--!strict
--[[
	Trove
	Collects connections, instances, threads and cleanup callbacks so a whole
	feature can be torn down with one Clean() call.
]]

export type Trove = {
	Add: (self: Trove, item: any) -> any,
	Connect: (self: Trove, signal: RBXScriptSignal, handler: (...any) -> ()) -> RBXScriptConnection,
	BindToRenderStep: (self: Trove, name: string, priority: number, fn: (dt: number) -> ()) -> (),
	Clean: (self: Trove) -> (),
}

local RunService = game:GetService("RunService")

local Trove = {}

local function cleanItem(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		(item :: RBXScriptConnection):Disconnect()
	elseif kind == "Instance" then
		(item :: Instance):Destroy()
	elseif kind == "function" then
		(item :: () -> ())()
	elseif kind == "thread" then
		local thread = item :: thread
		if coroutine.status(thread) ~= "dead" then
			pcall(task.cancel, thread)
		end
	elseif kind == "table" then
		if typeof(item.Destroy) == "function" then
			item:Destroy()
		elseif typeof(item.Disconnect) == "function" then
			item:Disconnect()
		elseif typeof(item.Clean) == "function" then
			item:Clean()
		end
	end
end

function Trove.new(): Trove
	local items: { any } = {}

	local trove: Trove
	trove = {
		Add = function(_self: Trove, item: any): any
			table.insert(items, item)
			return item
		end,

		Connect = function(_self: Trove, signal: RBXScriptSignal, handler: (...any) -> ()): RBXScriptConnection
			local connection = signal:Connect(handler)
			table.insert(items, connection)
			return connection
		end,

		BindToRenderStep = function(_self: Trove, name: string, priority: number, fn: (dt: number) -> ())
			RunService:BindToRenderStep(name, priority, fn)
			table.insert(items, function()
				RunService:UnbindFromRenderStep(name)
			end)
		end,

		Clean = function(_self: Trove)
			-- Clean in reverse so later dependents go first.
			for index = #items, 1, -1 do
				local item = items[index]
				items[index] = nil
				local ok, err = pcall(cleanItem, item)
				if not ok then
					warn("[Trove] cleanup error:", err)
				end
			end
		end,
	}
	return trove
end

return Trove
