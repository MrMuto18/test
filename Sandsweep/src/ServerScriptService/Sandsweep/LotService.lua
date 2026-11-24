-- LotService (ModuleScript) - ServerScriptService/Sandsweep/LotService
-- Owns the Smooth Terrain dig site: generation, voxel-accurate digging,
-- remnant sweeping, cover checks for buried finds and % cleared tracking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Sandsweep"):WaitForChild("GameConfig"))

local LotService = {}

local Lot = GameConfig.Lot
local terrain = Workspace.Terrain
local SAND = Enum.Material.Sand
local AIR = Enum.Material.Air
local RES = 4
local VOXEL_VOLUME = RES * RES * RES

local LOT_MIN = Vector3.new(Lot.CenterX - Lot.SizeX / 2, Lot.BottomY, Lot.CenterZ - Lot.SizeZ / 2)
local LOT_MAX = Vector3.new(Lot.CenterX + Lot.SizeX / 2, Lot.BottomY + Lot.Depth, Lot.CenterZ + Lot.SizeZ / 2)
local LOT_REGION = Region3.new(LOT_MIN, LOT_MAX):ExpandToGrid(RES)

LotService.Min = LOT_MIN
LotService.Max = LOT_MAX
LotService.Top = LOT_MAX.Y
LotService.InitialVolume = 1
LotService.CurrentVolume = 1
LotService.Percent = 0
LotService.Generating = false
LotService.Seed = 0
LotService.Dirty = false

local function clampVector(v, minV, maxV)
	return Vector3.new(math.clamp(v.X, minV.X, maxV.X), math.clamp(v.Y, minV.Y, maxV.Y), math.clamp(v.Z, minV.Z, maxV.Z))
end

-- Lowest-corner world position of voxel (x, y, z) inside a region read at RES.
local function voxelCenter(region, x, y, z)
	local regionMin = region.CFrame.Position - region.Size / 2
	return regionMin + Vector3.new((x - 0.5) * RES, (y - 0.5) * RES, (z - 0.5) * RES)
end

local function sumSand(materials, occupancies)
	local size = materials.Size
	local total = 0
	for x = 1, size.X do
		local mx, ox = materials[x], occupancies[x]
		for y = 1, size.Y do
			local my, oy = mx[y], ox[y]
			for z = 1, size.Z do
				if my[z] == SAND then
					total += oy[z]
				end
			end
		end
	end
	return total * VOXEL_VOLUME
end

-- Surface height (studs above lot bottom) for the initial gentle dunes
local function surfaceHeight(worldX, worldZ, seed)
	local n1 = math.noise(worldX * Lot.NoiseScale, worldZ * Lot.NoiseScale, seed)
	local n2 = math.noise(worldX * Lot.NoiseScale * 2.3, worldZ * Lot.NoiseScale * 2.3, seed + 17.3) * 0.4
	local n = math.clamp((n1 + n2) * 0.9 + 0.5, 0, 1)
	return Lot.SurfaceMin + (Lot.SurfaceMax - Lot.SurfaceMin) * n
end

function LotService.Generate(seed)
	LotService.Generating = true
	LotService.Seed = seed or math.random(1, 100000)
	local seedValue = LotService.Seed * 0.013 + 0.37

	local size = LOT_REGION.Size / RES
	local nx, ny, nz = math.floor(size.X + 0.5), math.floor(size.Y + 0.5), math.floor(size.Z + 0.5)
	local regionMin = LOT_REGION.CFrame.Position - LOT_REGION.Size / 2
	local materials, occupancies = {}, {}
	for x = 1, nx do
		materials[x], occupancies[x] = {}, {}
		for y = 1, ny do
			materials[x][y], occupancies[x][y] = {}, {}
		end
		for z = 1, nz do
			local worldX = regionMin.X + (x - 0.5) * RES
			local worldZ = regionMin.Z + (z - 0.5) * RES
			local height = surfaceHeight(worldX, worldZ, seedValue)
			for y = 1, ny do
				local layerBottom = (regionMin.Y - Lot.BottomY) + (y - 1) * RES
				local occupancy = math.clamp((height - layerBottom) / RES, 0, 1)
				if occupancy > 0.03 then
					materials[x][y][z] = SAND
					occupancies[x][y][z] = occupancy
				else
					materials[x][y][z] = AIR
					occupancies[x][y][z] = 0
				end
			end
		end
	end
	terrain:WriteVoxels(LOT_REGION, RES, materials, occupancies)

	local readMaterials, readOccupancies = terrain:ReadVoxels(LOT_REGION, RES)
	LotService.InitialVolume = math.max(1, sumSand(readMaterials, readOccupancies))
	LotService.CurrentVolume = LotService.InitialVolume
	LotService.Percent = 0
	LotService.Dirty = false
	LotService.Generating = false
	return LotService.InitialVolume
end

function LotService.IsInside(position, margin)
	margin = margin or 0
	return position.X >= LOT_MIN.X - margin
		and position.X <= LOT_MAX.X + margin
		and position.Z >= LOT_MIN.Z - margin
		and position.Z <= LOT_MAX.Z + margin
		and position.Y >= LOT_MIN.Y - margin
		and position.Y <= LOT_MAX.Y + margin + 2
end

-- Remove sand in a ball. Returns the exact sand volume (cubic studs) removed,
-- measured by reading voxels before and after FillBall. Air is never counted.
function LotService.Dig(center, radius)
	if LotService.Generating then
		return 0
	end
	local pad = Vector3.new(radius + RES, radius + RES, radius + RES)
	local readMin = clampVector(center - pad, LOT_MIN, LOT_MAX)
	local readMax = clampVector(center + pad, LOT_MIN, LOT_MAX)
	if readMax.X - readMin.X < 0.01 or readMax.Y - readMin.Y < 0.01 or readMax.Z - readMin.Z < 0.01 then
		return 0
	end
	local region = Region3.new(readMin, readMax):ExpandToGrid(RES)

	local beforeMaterials, beforeOccupancies = terrain:ReadVoxels(region, RES)
	terrain:FillBall(center, radius, AIR)
	local afterMaterials, afterOccupancies = terrain:ReadVoxels(region, RES)

	local size = beforeMaterials.Size
	local removed = 0
	local sweepDistance = radius + RES * 0.75
	local rewrite = false
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				local before = (beforeMaterials[x][y][z] == SAND) and beforeOccupancies[x][y][z] or 0
				local after = (afterMaterials[x][y][z] == SAND) and afterOccupancies[x][y][z] or 0
				-- Sweep up tiny remnants right next to the dig so "every grain" is reachable
				if after > 0 and after < Lot.RemnantThreshold and before > 0 then
					if (voxelCenter(region, x, y, z) - center).Magnitude <= sweepDistance then
						afterMaterials[x][y][z] = AIR
						afterOccupancies[x][y][z] = 0
						after = 0
						rewrite = true
					end
				end
				if before > after then
					removed += before - after
				end
			end
		end
	end
	if rewrite then
		terrain:WriteVoxels(region, RES, afterMaterials, afterOccupancies)
	end
	if removed > 0 then
		LotService.Dirty = true
	end
	return removed * VOXEL_VOLUME
end

-- Recount remaining sand and update the cleared fraction.
function LotService.Recount()
	local materials, occupancies = terrain:ReadVoxels(LOT_REGION, RES)
	LotService.CurrentVolume = sumSand(materials, occupancies)
	LotService.Percent = math.clamp(1 - LotService.CurrentVolume / LotService.InitialVolume, 0, 1)
	LotService.Dirty = false
	return LotService.Percent
end

function LotService.IsCleared()
	return LotService.Percent >= Lot.ClearedThreshold
end

-- Average sand occupancy in the voxel column covering a point (from its
-- bottom up to `above` studs over it). Used to confirm a find is uncovered.
function LotService.CoverOccupancy(position, above)
	local low = clampVector(position - Vector3.new(0.5, 0.5, 0.5), LOT_MIN, LOT_MAX)
	local high = clampVector(position + Vector3.new(0.5, above, 0.5), LOT_MIN, LOT_MAX)
	if high.Y - low.Y < 0.01 then
		return 0
	end
	local region = Region3.new(low, high):ExpandToGrid(RES)
	local materials, occupancies = terrain:ReadVoxels(region, RES)
	local size = materials.Size
	local total, count = 0, 0
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				count += 1
				if materials[x][y][z] == SAND then
					total += occupancies[x][y][z]
				end
			end
		end
	end
	return count > 0 and total / count or 0
end

-- Raycast check: is there sand directly above a point?
local coverParams = RaycastParams.new()
coverParams.FilterType = Enum.RaycastFilterType.Include
coverParams.FilterDescendantsInstances = { terrain }

function LotService.IsCoveredAbove(position, clearance)
	local origin = Vector3.new(position.X, LOT_MAX.Y + 20, position.Z)
	local targetY = position.Y + clearance
	if targetY >= origin.Y then
		return false
	end
	local result = Workspace:Raycast(origin, Vector3.new(0, targetY - origin.Y, 0), coverParams)
	return result ~= nil and result.Material == SAND
end

return LotService
