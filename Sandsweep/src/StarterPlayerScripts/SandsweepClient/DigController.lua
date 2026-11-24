-- DigController (ModuleScript) - StarterPlayerScripts/SandsweepClient/DigController
-- First-person digging: input, camera-centre raycast, request throttling,
-- procedural viewmodel (bob, sway, swing, suction recoil, spinning turbine).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ToolModels = require(Shared:WaitForChild("ToolModels"))
local Remotes = Shared:WaitForChild("Remotes")

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local DigController = {}

local player = Players.LocalPlayer
local Lot = GameConfig.Lot
local LOT_MIN = Vector3.new(Lot.CenterX - Lot.SizeX / 2, Lot.BottomY, Lot.CenterZ - Lot.SizeZ / 2)
local LOT_MAX = Vector3.new(Lot.CenterX + Lot.SizeX / 2, Lot.BottomY + Lot.Depth, Lot.CenterZ + Lot.SizeZ / 2)

local digRequest
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- input state
local mouseHeld = false
local pressQueued = false
local pressTime = 0
local lastDig = 0
local lastBagWarning = 0

-- viewmodel state
local vm = nil
local swingTime = 1
local swingDuration = 0.3
local equipProgress = 1
local bobTime = 0
local swayPitch, swayYaw = 0, 0
local lastCameraCFrame = nil
local fanAngle, fanSpeed = 0, 0
local suckBlend = 0
local scoopVisibleUntil = 0
local lastFill = -1

-- aggregated floating text for streaming tools
local pendingKg, pendingPosition, pendingTimer = 0, nil, 0

local function easeOutBack(t)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function insideLot(position)
	return position.X >= LOT_MIN.X - 1 and position.X <= LOT_MAX.X + 1
		and position.Z >= LOT_MIN.Z - 1 and position.Z <= LOT_MAX.Z + 1
		and position.Y >= LOT_MIN.Y - 1 and position.Y <= LOT_MAX.Y + 3
end

--------------------------------------------------------------------------
-- VIEWMODEL
--------------------------------------------------------------------------
local function destroyViewmodel()
	if vm and vm.Model then
		vm.Model:Destroy()
	end
	vm = nil
	Effects.SetVacuum(false)
end

local function buildViewmodel(toolId)
	destroyViewmodel()
	local camera = Workspace.CurrentCamera
	local model = ToolModels.Build(toolId, true)
	model.Name = "SandsweepViewmodel"
	local pivot = model:GetPivot()
	local entry = {
		ToolId = toolId,
		Model = model,
		Parts = {},
		Offsets = {},
		FanParts = {},
		FanRel = {},
		HubOffset = nil,
		Fill = nil,
		Scoop = model:FindFirstChild("SandScoop"),
		Tip = model.PrimaryPart:FindFirstChild("Tip"),
	}
	local fanFolder = model:FindFirstChild("Fan")
	if fanFolder then
		for _, part in ipairs(fanFolder:GetChildren()) do
			if part:GetAttribute("FanHub") then
				entry.HubOffset = pivot:ToObjectSpace(part.CFrame)
			end
		end
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local offset = pivot:ToObjectSpace(part.CFrame)
			if fanFolder and part:IsDescendantOf(fanFolder) and entry.HubOffset then
				table.insert(entry.FanParts, part)
				table.insert(entry.FanRel, entry.HubOffset:Inverse() * offset)
			else
				table.insert(entry.Parts, part)
				table.insert(entry.Offsets, offset)
			end
			local axis = part:GetAttribute("FillAxis")
			if part.Name == "SandFill" and axis then
				entry.Fill = {
					Part = part,
					Index = #entry.Parts,
					Axis = axis,
					OriginalSize = part.Size,
					OriginalOffset = offset,
				}
			end
		end
	end
	if entry.Scoop then
		entry.Scoop.Transparency = 1
	end
	model.Parent = camera
	vm = entry
	equipProgress = 0
	lastFill = -1
end

local function updateFill()
	if not vm or not vm.Fill then
		return
	end
	local fill = ClientState.BagFraction()
	if math.abs(fill - lastFill) < 0.01 then
		return
	end
	lastFill = fill
	local info = vm.Fill
	local size = info.OriginalSize
	local axisVector = info.Axis == "X" and Vector3.xAxis or Vector3.zAxis
	local length = info.Axis == "X" and size.X or size.Z
	local newLength = math.max(0.02, length * fill)
	if info.Axis == "X" then
		info.Part.Size = Vector3.new(newLength, size.Y, size.Z)
	else
		info.Part.Size = Vector3.new(size.X, size.Y, newLength)
	end
	info.Part.Transparency = fill < 0.02 and 1 or 0
	vm.Offsets[info.Index] = info.OriginalOffset * CFrame.new(axisVector * ((length - newLength) / 2))
end

local function swingPose(toolId, t)
	if t >= 1 then
		return CFrame.identity
	end
	local a = math.sin(t * math.pi)
	if toolId == "Spoon" then
		return CFrame.new(-0.05 * a, -0.18 * a, -0.4 * a) * CFrame.Angles(-0.95 * a, 0.1 * a, 0.2 * a)
	elseif toolId == "Shovel" then
		-- thrust down & forward, then lift the scoop back up
		local thrust = math.sin(math.min(1, t * 1.6) * math.pi * 0.5)
		local lift = t > 0.55 and math.sin((t - 0.55) / 0.45 * math.pi) or 0
		return CFrame.new(-0.1 * a, -0.5 * thrust + 0.35 * lift, -0.7 * a)
			* CFrame.Angles(-1.0 * thrust + 0.9 * lift, 0.15 * a, 0.3 * a)
	end
	return CFrame.identity
end

local function updateViewmodel(dt, camera)
	if not vm then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		vm.Model.Parent = nil
		return
	end
	if vm.Model.Parent ~= camera then
		vm.Model.Parent = camera
	end

	-- walk bob & idle breathing
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local amplitude = math.min(speed / 16, 1.5)
	bobTime += dt * (4 + speed * 0.45)
	local breathe = math.sin(os.clock() * 1.6) * 0.012
	local bob = CFrame.new(math.cos(bobTime) * 0.035 * amplitude, math.abs(math.sin(bobTime)) * 0.05 * amplitude + breathe, 0)
		* CFrame.Angles(0, 0, math.cos(bobTime) * 0.012 * amplitude)

	-- sway from camera rotation
	if lastCameraCFrame then
		local delta = lastCameraCFrame:ToObjectSpace(camera.CFrame)
		local rx, ry = delta:ToOrientation()
		local alpha = math.min(1, dt * 12)
		swayPitch += (math.clamp(-rx * 2.5, -0.12, 0.12) - swayPitch) * alpha
		swayYaw += (math.clamp(-ry * 2.5, -0.15, 0.15) - swayYaw) * alpha
	end
	lastCameraCFrame = camera.CFrame
	local sway = CFrame.Angles(swayPitch, swayYaw, swayYaw * 0.6)

	-- swing animation
	if swingTime < 1 then
		swingTime = math.min(1, swingTime + dt / swingDuration)
	end
	local swing = swingPose(vm.ToolId, swingTime)
	if vm.Scoop then
		local visible = swingTime > 0.5 and swingTime < 1 or os.clock() < scoopVisibleUntil
		vm.Scoop.Transparency = visible and 0 or 1
	end

	-- suction recoil / vibration
	local tool = GameConfig.GetTool(vm.ToolId)
	local streaming = tool and tool.Mode == "Stream"
	local intensity = vm.ToolId == "TurbineVac" and 2.2 or 1
	local shakeX = (math.noise(os.clock() * 40, 1.3) * 0.012) * suckBlend * intensity
	local shakeY = (math.noise(2.1, os.clock() * 40) * 0.012) * suckBlend * intensity
	local suck = CFrame.new(shakeX, shakeY, 0.06 * suckBlend * intensity) * CFrame.Angles(0.03 * suckBlend, 0, 0)

	-- equip raise
	if equipProgress < 1 then
		equipProgress = math.min(1, equipProgress + dt / 0.35)
	end
	local e = 1 - easeOutBack(equipProgress)
	local equip = CFrame.new(0, -1.1 * e, 0.4 * e) * CFrame.Angles(-0.7 * e, 0, 0)

	local base = camera.CFrame * (ToolModels.ViewOffsets[vm.ToolId] or CFrame.new(1, -1, -2)) * bob * sway * equip * swing * suck

	updateFill()
	local parts, cframes = {}, {}
	for index, part in ipairs(vm.Parts) do
		parts[index] = part
		cframes[index] = base * vm.Offsets[index]
	end
	if vm.HubOffset and #vm.FanParts > 0 then
		local target = streaming and (ClientState.DigHeld or mouseHeld) and not ClientState.UIOpen and 40 or 3
		fanSpeed += (target - fanSpeed) * math.min(1, dt * 2.5)
		fanAngle = (fanAngle + fanSpeed * dt) % (math.pi * 2)
		local hub = base * vm.HubOffset * CFrame.Angles(fanAngle, 0, 0)
		for index, part in ipairs(vm.FanParts) do
			table.insert(parts, part)
			table.insert(cframes, hub * vm.FanRel[index])
		end
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

--------------------------------------------------------------------------
-- DIGGING
--------------------------------------------------------------------------
local function refreshFilter(camera)
	local exclude = { camera }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local fx = Effects.GetFolder()
	if fx then
		table.insert(exclude, fx)
	end
	local world = Workspace:FindFirstChild("SandsweepWorld")
	if world then
		local finds = world:FindFirstChild("Finds")
		if finds then
			table.insert(exclude, finds)
		end
		local ladders = world:FindFirstChild("Ladders", true)
		if ladders then
			table.insert(exclude, ladders)
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			table.insert(exclude, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
end

-- Returns hit position, ray direction, status ("valid", "far", "idle")
local function aim(camera, stats)
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	refreshFilter(camera)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * (stats.Range + 4), rayParams)
	if not result then
		return nil, ray.Direction, "idle"
	end
	if result.Instance ~= Workspace.Terrain or result.Material ~= Enum.Material.Sand or not insideLot(result.Position) then
		return nil, ray.Direction, "idle"
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local eye = head and head.Position or ray.Origin
	if (result.Position - eye).Magnitude > stats.Range then
		return nil, ray.Direction, "far"
	end
	return result.Position, ray.Direction, "valid"
end

local function flushFloatingText(force)
	if pendingKg > 0 and pendingPosition and (force or pendingTimer >= 0.35) then
		Effects.FloatingKg(pendingPosition, pendingKg)
		pendingKg, pendingPosition, pendingTimer = 0, nil, 0
	end
end

local function onDigResult(kg, _, _, position)
	local stats = ClientState.GetStats()
	if stats.Mode == "Stream" then
		pendingKg += kg
		pendingPosition = position
		Effects.Play("Dig", 0.25, 1.3 + math.random() * 0.3)
	else
		Effects.FloatingKg(position, kg)
		Effects.Play("Dig", 0.9, 0.75 + math.random() * 0.25)
		Effects.Play("Scoop", 0.6, 0.8 + math.random() * 0.2)
		scoopVisibleUntil = os.clock() + 0.25
	end
end

local function step(dt)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- camera shake applied after the default camera update
	camera.CFrame = camera.CFrame * Effects.GetShake(dt)
	Effects.UpdateAmbient(camera.CFrame.Position)

	local state = ClientState.State
	local stats = ClientState.GetStats()
	if not vm or vm.ToolId ~= state.EquippedTool then
		buildViewmodel(state.EquippedTool)
	end

	-- hide our own third-person tool in first person
	local character = player.Character
	local thirdPerson = character and character:FindFirstChild("SandsweepTool")
	if thirdPerson then
		for _, part in ipairs(thirdPerson:GetDescendants()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
	end

	local now = os.clock()
	local blocked = ClientState.UIOpen or not state.Loaded
	local holding = (mouseHeld or ClientState.DigHeld) and not blocked
	if pressQueued and now - pressTime > 0.3 then
		pressQueued = false
	end

	local hitPosition, direction, status = aim(camera, stats)
	local full = ClientState.BagFraction() >= 0.999
	if blocked then
		ClientState.Crosshair = "idle"
	elseif status == "valid" and full then
		ClientState.Crosshair = "full"
	else
		ClientState.Crosshair = status
	end

	local streaming = stats.Mode == "Stream"
	local wants = (stats.Mode == "Click" and pressQueued) or (stats.Mode ~= "Click" and (holding or pressQueued))
	if blocked then
		wants = false
	end
	local sucking = streaming and holding and status == "valid" and not full
	suckBlend += ((sucking and 1 or (streaming and holding and 0.35 or 0)) - suckBlend) * math.min(1, dt * 10)

	if wants and now - lastDig >= stats.Cooldown then
		if status == "valid" then
			pressQueued = false
			if full then
				if now - lastBagWarning > 1.2 then
					lastBagWarning = now
					Effects.Play("Error", 0.7, 0.9)
					ClientState.Notified:Fire({ Kind = "BagFull", Local = true })
				end
			else
				lastDig = now
				digRequest:FireServer(hitPosition, direction.Unit)
				local tool = GameConfig.GetTool(stats.ToolId)
				Effects.DigBurst(hitPosition, stats.ToolId, true)
				Effects.Shake(tool and tool.Shake or 0.05)
				if not streaming then
					swingDuration = math.clamp(stats.Cooldown * 0.9, 0.18, 0.4)
					swingTime = 0
					Effects.Play("Swing", 0.8, 0.9 + math.random() * 0.25)
				end
			end
		elseif stats.Mode ~= "Stream" and pressQueued and now - pressTime < 0.05 then
			-- swing at nothing (still feels responsive)
			pressQueued = false
			if swingTime >= 1 then
				swingDuration = math.clamp(stats.Cooldown * 0.9, 0.18, 0.4)
				swingTime = 0
				Effects.Play("Swing", 0.5, 1.1)
			end
		end
	end

	-- suction VFX & motor sound
	Effects.SetVacuum(sucking, stats.ToolId, vm and vm.Tip, hitPosition, dt)
	Effects.UpdateVacuumSound(streaming and holding, stats.ToolId, sucking, dt)

	pendingTimer += dt
	flushFloatingText(false)

	updateViewmodel(dt, camera)
end

--------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------
local function isDigInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2
end

local EQUIP_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

function DigController.Press()
	pressQueued = true
	pressTime = os.clock()
end

function DigController.Init()
	digRequest = Remotes:WaitForChild("DigRequest")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if isDigInput(input) then
			mouseHeld = true
			if not ClientState.UIOpen then
				DigController.Press()
			end
		elseif EQUIP_KEYS[input.KeyCode] then
			local tool = GameConfig.Tools[EQUIP_KEYS[input.KeyCode]]
			if tool and ClientState.State.OwnedTools[tool.Id] and ClientState.State.EquippedTool ~= tool.Id then
				task.spawn(function()
					local ok, message = ClientState.Purchase("Equip", tool.Id)
					if not ok then
						ClientState.Notified:Fire({ Kind = "Toast", Text = message, Color = "Terracotta" })
					end
				end)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isDigInput(input) then
			mouseHeld = false
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		mouseHeld = false
	end)

	ClientState.DigResult:Connect(onDigResult)
	ClientState.Changed:Connect(function(state, previousTool)
		if previousTool and previousTool ~= state.EquippedTool then
			Effects.Play("Click", 1, 0.8)
		end
	end)

	Remotes:WaitForChild("DigFx").OnClientEvent:Connect(function(digger, position, toolId)
		if digger ~= player and typeof(position) == "Vector3" then
			Effects.DigBurst(position, toolId, false, 0.45)
		end
	end)

	player.CharacterAdded:Connect(function()
		lastCameraCFrame = nil
		equipProgress = 0
		mouseHeld = false
	end)

	RunService:BindToRenderStep("SandsweepDig", Enum.RenderPriority.Camera.Value + 1, step)
end

return DigController
