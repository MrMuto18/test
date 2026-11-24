-- Effects (ModuleScript) - StarterPlayerScripts/SandsweepClient/Effects
-- All client-side juice: sand bursts, suction stream, floating "+kg" text,
-- camera shake, procedural sound shaping, fanfares and ambient desert dust.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Sandsweep")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Util = require(Shared:WaitForChild("Util"))

local Effects = {}

local Palette = GameConfig.Palette
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local fxFolder
local anchorPart
local textAnchor
local burstAttachment
local grainEmitter, dustEmitter
local suctionAttachment, suctionEmitter, suctionDust, suctionBeam
local ambientPart
local soundFolder
local templates = {}
local vacuumSound
local trauma = 0
local shakeTime = 0

local BURST = {
	Spoon = { Grains = 10, Dust = 2, Speed = 9 },
	Shovel = { Grains = 24, Dust = 5, Speed = 13 },
	HandVac = { Grains = 5, Dust = 2, Speed = 6 },
	TurbineVac = { Grains = 10, Dust = 4, Speed = 9 },
}

local function newPart(name)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = fxFolder
	return part
end

local function makeSound(name, soundId, volume, effects)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	for _, effect in ipairs(effects or {}) do
		effect.Parent = sound
	end
	sound.Parent = soundFolder
	templates[name] = sound
	return sound
end

local function eq(low, mid, high)
	local effect = Instance.new("EqualizerSoundEffect")
	effect.LowGain = low
	effect.MidGain = mid
	effect.HighGain = high
	return effect
end

local function distortion(level)
	local effect = Instance.new("DistortionSoundEffect")
	effect.Level = level
	return effect
end

function Effects.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "SandsweepFX_Local"
	fxFolder.Parent = Workspace

	anchorPart = newPart("FxAnchor")
	anchorPart.CFrame = CFrame.new(0, -500, 0)
	textAnchor = newPart("TextAnchor")
	textAnchor.CFrame = CFrame.identity

	-- burst emitters (moved to the hit point, then Emit())
	burstAttachment = Instance.new("Attachment")
	burstAttachment.Name = "Burst"
	burstAttachment.Parent = anchorPart

	grainEmitter = Instance.new("ParticleEmitter")
	grainEmitter.Name = "Grains"
	grainEmitter.Texture = SMOKE
	grainEmitter.Enabled = false
	grainEmitter.Color = ColorSequence.new(Palette.SandLight, Palette.SandDark)
	grainEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.12) })
	grainEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	grainEmitter.Lifetime = NumberRange.new(0.5, 0.9)
	grainEmitter.Speed = NumberRange.new(6, 12)
	grainEmitter.SpreadAngle = Vector2.new(55, 55)
	grainEmitter.Acceleration = Vector3.new(0, -45, 0)
	grainEmitter.Drag = 1
	grainEmitter.EmissionDirection = Enum.NormalId.Top
	grainEmitter.LightInfluence = 1
	grainEmitter.Parent = burstAttachment

	dustEmitter = Instance.new("ParticleEmitter")
	dustEmitter.Name = "Dust"
	dustEmitter.Texture = SMOKE
	dustEmitter.Enabled = false
	dustEmitter.Color = ColorSequence.new(Palette.SandLight)
	dustEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.4) })
	dustEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dustEmitter.Lifetime = NumberRange.new(0.8, 1.4)
	dustEmitter.Speed = NumberRange.new(1, 3)
	dustEmitter.SpreadAngle = Vector2.new(80, 80)
	dustEmitter.Drag = 2
	dustEmitter.RotSpeed = NumberRange.new(-40, 40)
	dustEmitter.Rotation = NumberRange.new(0, 360)
	dustEmitter.EmissionDirection = Enum.NormalId.Top
	dustEmitter.LightInfluence = 1
	dustEmitter.Parent = burstAttachment

	-- suction stream (vacuums)
	local suctionPart = newPart("Suction")
	suctionAttachment = Instance.new("Attachment")
	suctionAttachment.Name = "SuctionTarget"
	suctionAttachment.Parent = suctionPart

	suctionEmitter = Instance.new("ParticleEmitter")
	suctionEmitter.Name = "Stream"
	suctionEmitter.Texture = SMOKE
	suctionEmitter.Enabled = false
	suctionEmitter.Color = ColorSequence.new(Palette.SandLight, Palette.Sand)
	suctionEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.08) })
	suctionEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.6) })
	suctionEmitter.Lifetime = NumberRange.new(0.25, 0.3)
	suctionEmitter.Speed = NumberRange.new(20, 26)
	suctionEmitter.SpreadAngle = Vector2.new(6, 6)
	suctionEmitter.Rate = 80
	suctionEmitter.EmissionDirection = Enum.NormalId.Top
	suctionEmitter.Shape = Enum.ParticleEmitterShape.Sphere
	suctionEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	suctionEmitter.LightInfluence = 1
	suctionEmitter.Parent = suctionAttachment

	suctionDust = Instance.new("ParticleEmitter")
	suctionDust.Name = "Swirl"
	suctionDust.Texture = SMOKE
	suctionDust.Enabled = false
	suctionDust.Color = ColorSequence.new(Palette.SandLight)
	suctionDust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0.4) })
	suctionDust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
	suctionDust.Lifetime = NumberRange.new(0.4, 0.7)
	suctionDust.Speed = NumberRange.new(0.5, 2)
	suctionDust.SpreadAngle = Vector2.new(180, 180)
	suctionDust.RotSpeed = NumberRange.new(-180, 180)
	suctionDust.Rate = 18
	suctionDust.LightInfluence = 1
	suctionDust.Parent = suctionAttachment

	suctionBeam = Instance.new("Beam")
	suctionBeam.Name = "SuctionBeam"
	suctionBeam.Enabled = false
	suctionBeam.Attachment1 = suctionAttachment
	suctionBeam.Color = ColorSequence.new(Palette.SandLight, Palette.Sand)
	suctionBeam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.85) })
	suctionBeam.Width0 = 0.3
	suctionBeam.Width1 = 1.4
	suctionBeam.FaceCamera = true
	suctionBeam.Segments = 8
	suctionBeam.LightInfluence = 0.6
	suctionBeam.Parent = suctionPart

	-- ambient drifting desert dust around the camera
	ambientPart = newPart("AmbientDust")
	ambientPart.Size = Vector3.new(70, 14, 70)
	local ambient = Instance.new("ParticleEmitter")
	ambient.Name = "Wisps"
	ambient.Texture = SMOKE
	ambient.Color = ColorSequence.new(Palette.SandLight)
	ambient.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 2.5), NumberSequenceKeypoint.new(1, 4) })
	ambient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.88), NumberSequenceKeypoint.new(1, 1) })
	ambient.Lifetime = NumberRange.new(5, 8)
	ambient.Speed = NumberRange.new(0.5, 1.5)
	ambient.Acceleration = Vector3.new(2.5, 0, 1.2)
	ambient.Rate = 5
	ambient.RotSpeed = NumberRange.new(-15, 15)
	ambient.Shape = Enum.ParticleEmitterShape.Box
	ambient.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	ambient.LightInfluence = 1
	ambient.Parent = ambientPart

	-- sounds (built-in engine sounds shaped with EQ/distortion)
	soundFolder = Instance.new("Folder")
	soundFolder.Name = "SandsweepSounds"
	soundFolder.Parent = SoundService
	local S = GameConfig.Sounds
	makeSound("Dig", S.Dig, 0.7, { eq(6, -2, -14) })
	makeSound("Scoop", S.Scoop, 0.5, { eq(4, 0, -10) })
	makeSound("Swing", S.Swing, 0.35, { eq(0, 0, -6) })
	makeSound("Sell", S.Sell, 0.6)
	makeSound("Click", S.Click, 0.4)
	makeSound("Error", S.Error, 0.5, { eq(2, -4, -10) })
	makeSound("Chime", S.Chime, 0.55)
	makeSound("Splash", S.Splash, 0.35, { eq(4, -6, -20) })

	vacuumSound = Instance.new("Sound")
	vacuumSound.Name = "VacuumLoop"
	vacuumSound.SoundId = S.VacuumLoop
	vacuumSound.Looped = true
	vacuumSound.Volume = 0
	eq(-4, 2, -2).Parent = vacuumSound
	local vacuumDistortion = distortion(0)
	vacuumDistortion.Name = "Grit"
	vacuumDistortion.Parent = vacuumSound
	vacuumSound.Parent = soundFolder
end

--------------------------------------------------------------------------
-- SOUND
--------------------------------------------------------------------------
function Effects.Play(name, volumeScale, pitch)
	local template = templates[name]
	if not template then
		return
	end
	local sound = template:Clone()
	sound.Volume = template.Volume * (volumeScale or 1)
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = soundFolder
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function Effects.Fanfare()
	for index, pitch in ipairs({ 1, 1.26, 1.5, 2 }) do
		task.delay((index - 1) * 0.09, function()
			Effects.Play("Chime", 0.9, pitch)
		end)
	end
end

function Effects.CashRegister()
	Effects.Play("Sell", 1, 1)
	task.delay(0.08, function()
		Effects.Play("Sell", 0.8, 1.5)
	end)
end

--------------------------------------------------------------------------
-- BURSTS & TEXT
--------------------------------------------------------------------------
function Effects.DigBurst(position, toolId, isLocal, volumeScale)
	local preset = BURST[toolId] or BURST.Spoon
	anchorPart.CFrame = CFrame.new(position)
	grainEmitter.Speed = NumberRange.new(preset.Speed * 0.6, preset.Speed)
	grainEmitter:Emit(preset.Grains)
	dustEmitter:Emit(preset.Dust)
	if not isLocal then
		local camera = Workspace.CurrentCamera
		local distance = camera and (camera.CFrame.Position - position).Magnitude or 0
		local volume = math.clamp(1 - distance / 90, 0, 1) * (volumeScale or 0.5)
		if volume > 0.02 then
			Effects.Play("Dig", volume, 0.8 + math.random() * 0.3)
		end
	end
end

function Effects.FloatingText(position, text, color)
	local attachment = Instance.new("Attachment")
	attachment.Parent = textAnchor
	attachment.WorldPosition = position + Vector3.new((math.random() - 0.5) * 0.8, 0.6, (math.random() - 0.5) * 0.8)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 44)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Adornee = attachment
	billboard.Parent = attachment

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color or Palette.Cream
	label.TextStrokeColor3 = Palette.Ink
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard

	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(billboard, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 2.4, 0) }):Play()
	task.delay(0.55, function()
		TweenService:Create(label, TweenInfo.new(0.55), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.2, function()
		attachment:Destroy()
	end)
end

function Effects.FloatingKg(position, kg)
	Effects.FloatingText(position, string.format("+%s kg", Util.FormatKg(kg)), Palette.Cream)
end

--------------------------------------------------------------------------
-- SUCTION STREAM
--------------------------------------------------------------------------
local vacuumActive = false
function Effects.SetVacuum(active, toolId, tipAttachment, hitPosition)
	local isTurbine = toolId == "TurbineVac"
	if active and tipAttachment and hitPosition then
		local tipPosition = tipAttachment.WorldPosition
		local toTip = tipPosition - hitPosition
		local distance = math.max(0.5, toTip.Magnitude)
		-- orient so the emitter's +Y faces the nozzle
		local look = CFrame.lookAt(hitPosition, tipPosition)
		suctionAttachment.Parent.CFrame = look * CFrame.Angles(-math.pi / 2, 0, 0)
		local lifetime = 0.28
		suctionEmitter.Lifetime = NumberRange.new(lifetime * 0.9, lifetime)
		suctionEmitter.Speed = NumberRange.new(distance / lifetime * 0.9, distance / lifetime)
		suctionEmitter.Rate = isTurbine and 160 or 70
		suctionEmitter.SpreadAngle = isTurbine and Vector2.new(10, 10) or Vector2.new(5, 5)
		suctionEmitter.Size = isTurbine
				and NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.12) })
			or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.08) })
		suctionDust.Rate = isTurbine and 40 or 15
		suctionBeam.Attachment0 = tipAttachment
		suctionBeam.Width0 = isTurbine and 0.7 or 0.3
		suctionBeam.Width1 = isTurbine and 3.2 or 1.4
		suctionBeam.TextureSpeed = 4
		if not vacuumActive then
			vacuumActive = true
			suctionEmitter.Enabled = true
			suctionDust.Enabled = true
			suctionBeam.Enabled = true
		end
	elseif vacuumActive then
		vacuumActive = false
		suctionEmitter.Enabled = false
		suctionDust.Enabled = false
		suctionBeam.Enabled = false
	end
end

-- Motor hum: runs while a vacuum trigger is held (even with no sand in reach)
function Effects.UpdateVacuumSound(running, toolId, loaded, dt)
	if not vacuumSound then
		return
	end
	local isTurbine = toolId == "TurbineVac"
	local targetVolume = running and (isTurbine and 0.55 or 0.35) or 0
	local targetPitch = running and ((isTurbine and 0.95 or 1.55) + (loaded and -0.08 or 0.06)) or 0.6
	vacuumSound.Volume += (targetVolume - vacuumSound.Volume) * math.min(1, dt * 8)
	vacuumSound.PlaybackSpeed += (targetPitch - vacuumSound.PlaybackSpeed) * math.min(1, dt * 5)
	local grit = vacuumSound:FindFirstChild("Grit")
	if grit then
		grit.Level = isTurbine and 0.38 or 0.12
	end
	if vacuumSound.Volume > 0.01 then
		if not vacuumSound.IsPlaying then
			vacuumSound:Play()
		end
	elseif vacuumSound.IsPlaying then
		vacuumSound:Stop()
	end
end

--------------------------------------------------------------------------
-- CAMERA SHAKE (trauma based)
--------------------------------------------------------------------------
function Effects.Shake(amount)
	trauma = math.clamp(trauma + amount, 0, 1)
end

function Effects.GetShake(dt)
	trauma = math.max(0, trauma - dt * 1.8)
	if trauma <= 0 then
		return CFrame.identity
	end
	shakeTime += dt * 28
	local power = trauma * trauma
	local pitch = math.noise(shakeTime, 0.3, 0) * 0.035 * power
	local yaw = math.noise(0.7, shakeTime, 0) * 0.035 * power
	local roll = math.noise(0, 0.4, shakeTime) * 0.025 * power
	return CFrame.Angles(pitch, yaw, roll)
end

function Effects.UpdateAmbient(cameraPosition)
	if ambientPart then
		ambientPart.CFrame = CFrame.new(cameraPosition + Vector3.new(-12, 2, -6))
	end
end

function Effects.GetFolder()
	return fxFolder
end

return Effects
