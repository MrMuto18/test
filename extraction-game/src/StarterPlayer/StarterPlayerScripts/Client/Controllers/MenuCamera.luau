--!strict
--[[
	MenuCamera
	Cinematic camera for the safehouse menu.

	final = shotBase(eased between CameraRig parts) * dolly * breathing * parallax

	• Shots are invisible parts under Safehouse.CameraRig. Attributes on each
	  part (FieldOfView, FocusDistance, InFocusRadius) drive lens + DOF, so a
	  designer can re-frame shots in Studio without touching code.
	• Breathing = layered Perlin noise on position + rotation (handheld feel).
	• Parallax = spring-smoothed rotation toward the mouse/right stick.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Spring = require(Shared.Spring)

local CinematicGrade = require(script.Parent.CinematicGrade)

local MenuCamera = {}

local RENDER_NAME = "MenuCamera"
local C = Config.Camera.Menu

local rig: Instance? = nil
local running = false

local fromCF = CFrame.identity
local toCF = CFrame.identity
local fromFov = 38
local toFov = 38
local transitionTime = 0
local transitionDuration = 0

local dollySpring = Spring.new(Vector3.zero, 0.7, 1)
local parallaxSpring = Spring.new(Vector3.zero, C.ParallaxFrequency, 0.9)
local gamepadLook = Vector2.zero

local lastCF = CFrame.identity
local lastFov = 38

local function easeInOutQuint(t: number): number
	if t < 0.5 then
		return 16 * t * t * t * t * t
	end
	local f = -2 * t + 2
	return 1 - (f * f * f * f * f) / 2
end

local function getShot(name: string): BasePart?
	local container = rig
	if not container then
		return nil
	end
	local part = container:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function attrNumber(part: BasePart, name: string, fallback: number): number
	local value = part:GetAttribute(name)
	return if typeof(value) == "number" then value else fallback
end

local function currentBase(): (CFrame, number)
	if transitionDuration <= 0 then
		return toCF, toFov
	end
	local alpha = easeInOutQuint(math.clamp(transitionTime / transitionDuration, 0, 1))
	return fromCF:Lerp(toCF, alpha), fromFov + (toFov - fromFov) * alpha
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable

	if transitionDuration > 0 then
		transitionTime += dt
		if transitionTime >= transitionDuration then
			transitionDuration = 0
		end
	end
	local base, fov = currentBase()

	-- Breathing (handheld drift)
	local t = os.clock() * C.BreathSpeed
	local pos = Vector3.new(math.noise(t, 1.3), math.noise(t * 0.8, 7.1), math.noise(t * 0.7, 3.7)) * (C.BreathPosition * 2)
	local rotScale = math.rad(C.BreathRotation) * 2
	local breathRot = CFrame.Angles(
		math.noise(t * 1.2, 11.1) * rotScale,
		math.noise(t * 0.9, 5.3) * rotScale,
		math.noise(t * 0.6, 2.9) * rotScale * 0.5
	)

	-- Parallax toward pointer / right stick
	local viewport = camera.ViewportSize
	local mouse = UserInputService:GetMouseLocation()
	local nx = if viewport.X > 0 then math.clamp(mouse.X / viewport.X * 2 - 1, -1, 1) else 0
	local ny = if viewport.Y > 0 then math.clamp(mouse.Y / viewport.Y * 2 - 1, -1, 1) else 0
	if gamepadLook.Magnitude > 0.1 then
		nx, ny = gamepadLook.X, -gamepadLook.Y
	end
	parallaxSpring.Target = Vector3.new(-nx * math.rad(C.ParallaxYaw), -ny * math.rad(C.ParallaxPitch), 0)
	local parallax = parallaxSpring:update(dt)
	local dolly = dollySpring:update(dt)

	local final = base * CFrame.new(0, 0, -dolly.X) * CFrame.new(pos) * breathRot * CFrame.Angles(parallax.Y, parallax.X, 0)
	camera.CFrame = final
	camera.FieldOfView = fov
	lastCF = final
	lastFov = fov
end

function MenuCamera.init()
	local safehouse = Workspace:WaitForChild(Config.World.SafehouseName, 60)
	rig = if safehouse then safehouse:WaitForChild("CameraRig", 30) else nil
	if not rig then
		warn("[MenuCamera] Safehouse.CameraRig not found — menu camera will hold its last frame.")
	end

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadLook = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
end

-- Moves to a rig shot. instant = cut (used when entering the menu).
function MenuCamera.goTo(shotName: string, instant: boolean?)
	local shot = getShot(shotName)
	if not shot then
		return
	end
	local targetFov = attrNumber(shot, "FieldOfView", 38)
	if instant or not running then
		fromCF, toCF = shot.CFrame, shot.CFrame
		fromFov, toFov = targetFov, targetFov
		transitionDuration = 0
	else
		local currentCF, currentFov = currentBase()
		fromCF, fromFov = currentCF, currentFov
		toCF, toFov = shot.CFrame, targetFov
		transitionTime = 0
		transitionDuration = C.ShotTransitionTime
	end
	CinematicGrade.setMenuFocus(attrNumber(shot, "FocusDistance", 20), attrNumber(shot, "InFocusRadius", 8), instant)
end

function MenuCamera.start(shotName: string)
	dollySpring:reset(Vector3.zero)
	parallaxSpring:reset(Vector3.zero)
	running = false
	MenuCamera.goTo(shotName, true)
	running = true
	RunService:UnbindFromRenderStep(RENDER_NAME)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, step)
	step(0)
end

function MenuCamera.stop()
	running = false
	RunService:UnbindFromRenderStep(RENDER_NAME)
end

-- Slow push-in while the server spawns the character.
function MenuCamera.pushIn(studs: number)
	dollySpring.Target = Vector3.new(studs, 0, 0)
end

function MenuCamera.getCFrame(): CFrame
	return lastCF
end

function MenuCamera.getFieldOfView(): number
	return lastFov
end

function MenuCamera.isRunning(): boolean
	return running
end

return MenuCamera
