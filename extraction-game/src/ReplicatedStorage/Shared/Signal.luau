--!strict
--[[
	Signal
	Lightweight pure-Luau signal. Handlers run in their own thread so a
	yielding or erroring listener never blocks the emitter.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> Connection,
	Once: (self: Signal, handler: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
	DisconnectAll: (self: Signal) -> (),
}

type Record = {
	Handler: (...any) -> (),
	Connected: boolean,
}

local Signal = {}

function Signal.new(): Signal
	local records: { Record } = {}

	local function connect(handler: (...any) -> ()): Connection
		local record: Record = { Handler = handler, Connected = true }
		table.insert(records, record)

		local connection: Connection
		connection = {
			Connected = true,
			Disconnect = function(_self: Connection)
				if not record.Connected then
					return
				end
				record.Connected = false
				connection.Connected = false
				local index = table.find(records, record)
				if index then
					table.remove(records, index)
				end
			end,
		}
		return connection
	end

	local signal: Signal
	signal = {
		Connect = function(_self: Signal, handler: (...any) -> ()): Connection
			return connect(handler)
		end,

		Once = function(_self: Signal, handler: (...any) -> ()): Connection
			local connection: Connection
			connection = connect(function(...: any)
				connection:Disconnect()
				handler(...)
			end)
			return connection
		end,

		Fire = function(_self: Signal, ...: any)
			local snapshot = table.clone(records)
			for _, record in snapshot do
				if record.Connected then
					task.spawn(record.Handler, ...)
				end
			end
		end,

		Wait = function(_self: Signal): ...any
			local thread = coroutine.running()
			signal:Once(function(...: any)
				task.spawn(thread, ...)
			end)
			return coroutine.yield()
		end,

		DisconnectAll = function(_self: Signal)
			for _, record in records do
				record.Connected = false
			end
			table.clear(records)
		end,
	}
	return signal
end

return Signal
