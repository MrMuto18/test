-- Util (ModuleScript) - ReplicatedStorage/Sandsweep/Util
-- Small shared helpers: number formatting, table copy, vector validation.

local Util = {}

function Util.Commas(number)
	local negative = number < 0
	local formatted = tostring(math.floor(math.abs(number)))
	while true do
		local replaced, count = string.gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return (negative and "-" or "") .. formatted
end

function Util.FormatCash(number)
	number = math.floor(number + 0.5)
	if number >= 1e9 then
		return string.format("$%.2fB", number / 1e9)
	elseif number >= 1e7 then
		return string.format("$%.2fM", number / 1e6)
	end
	return "$" .. Util.Commas(number)
end

function Util.FormatKg(number)
	if number >= 10000 then
		return Util.Commas(number)
	end
	return string.format("%.1f", number)
end

function Util.FormatPercent(fraction)
	return string.format("%.1f%%", math.clamp(fraction, 0, 1) * 100)
end

function Util.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[key] = Util.DeepCopy(inner)
	end
	return copy
end

-- Fill in missing keys from template (recursively), keeping existing values.
function Util.Reconcile(target, template)
	for key, inner in pairs(template) do
		if target[key] == nil then
			target[key] = Util.DeepCopy(inner)
		elseif type(inner) == "table" and type(target[key]) == "table" then
			Util.Reconcile(target[key], inner)
		end
	end
	return target
end

function Util.CountKeys(dictionary)
	local count = 0
	for _ in pairs(dictionary) do
		count += 1
	end
	return count
end

local function isFiniteNumber(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Util.IsFiniteVector(v)
	return typeof(v) == "Vector3" and isFiniteNumber(v.X) and isFiniteNumber(v.Y) and isFiniteNumber(v.Z)
end

function Util.Lerp(a, b, t)
	return a + (b - a) * t
end

return Util
