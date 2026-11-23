--!strict
--[[
	Spring
	Damped harmonic spring on Vector3 (use the X component for scalars).
	Integrated with fixed sub-steps so it stays stable at any frame rate.

		local s = Spring.new(Vector3.zero, 6, 0.8) -- 6 Hz, damping ratio 0.8
		s.Target = Vector3.new(1, 0, 0)
		local p = s:update(dt)
		s:impulse(Vector3.new(0, 4, 0)) -- add velocity (recoil kicks, bumps)
]]

local SUBSTEP = 1 / 240
local MAX_DT = 0.1

local SpringClass = {}
SpringClass.__index = SpringClass

type SpringData = {
	Position: Vector3,
	Velocity: Vector3,
	Target: Vector3,
	Frequency: number,
	Damping: number,
}

export type Spring = typeof(setmetatable({} :: SpringData, SpringClass))

function SpringClass.new(initial: Vector3, frequency: number, damping: number): Spring
	local data: SpringData = {
		Position = initial,
		Velocity = Vector3.zero,
		Target = initial,
		Frequency = frequency,
		Damping = damping,
	}
	return setmetatable(data, SpringClass)
end

function SpringClass.update(self: Spring, dt: number): Vector3
	local remaining = math.min(dt, MAX_DT)
	local omega = self.Frequency * 2 * math.pi
	local stiffness = omega * omega
	local damping = 2 * self.Damping * omega

	local position = self.Position
	local velocity = self.Velocity
	local target = self.Target

	while remaining > 1e-6 do
		local h = math.min(SUBSTEP, remaining)
		local acceleration = (target - position) * stiffness - velocity * damping
		velocity += acceleration * h
		position += velocity * h
		remaining -= h
	end

	self.Position = position
	self.Velocity = velocity
	return position
end

function SpringClass.impulse(self: Spring, velocity: Vector3)
	self.Velocity += velocity
end

function SpringClass.reset(self: Spring, value: Vector3)
	self.Position = value
	self.Target = value
	self.Velocity = Vector3.zero
end

return SpringClass
