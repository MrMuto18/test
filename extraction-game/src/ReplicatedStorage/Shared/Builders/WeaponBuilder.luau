--!strict
--[[
	WeaponBuilder
	Procedural, multi-part tactical weapons (40-70 parts each):

	  SuppressedRifle  VK-9   — black anodized upper/lower, FDE furniture,
	                            picatinny rail with teeth, M-LOK handguard,
	                            vertical foregrip, light module, suppressor,
	                            holographic sight with emissive reticle
	  CompactSMG       KR-45  — polymer receiver, vented shroud, muzzle brake,
	                            angled foregrip, wire folding stock, reflex dot
	  HeavyPistol      M-50   — serrated slide, compensator, rail, rubber grip
	                            panels, micro red-dot

	Local space: origin = right-hand grip point, barrel = -Z, up = +Y.
	Every part is unanchored, massless, non-colliding, non-queryable and welded
	to Handle, so the weapon never blocks bullets or the camera.

	Attachments on Handle: Muzzle, Ejection, GripRight, GripLeft.
	Parts named "Magazine*" are the magazine (hidden/dropped on reload).
]]

local CollectionService = game:GetService("CollectionService")

local PartFactory = require(script.Parent.PartFactory)

export type WeaponHandles = {
	Model: Model,
	Handle: BasePart,
	Muzzle: Attachment,
	Ejection: Attachment,
	GripRight: Attachment,
	GripLeft: Attachment,
	Magazine: { BasePart },
}

type Style = PartFactory.Style

local WeaponBuilder = {}

local RUBBER = PartFactory.material("Rubber", Enum.Material.SmoothPlastic)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local STYLES: { [string]: Style } = {
	Anodized = PartFactory.style(rgb(30, 30, 32), Enum.Material.Metal, 0.05),
	Steel = PartFactory.style(rgb(70, 72, 76), Enum.Material.Metal, 0.12),
	SteelDark = PartFactory.style(rgb(22, 22, 24), Enum.Material.Metal, 0.04),
	Polymer = PartFactory.style(rgb(38, 38, 36), Enum.Material.SmoothPlastic, 0),
	FDE = PartFactory.style(rgb(146, 124, 94), Enum.Material.SmoothPlastic, 0),
	Rubber = PartFactory.style(rgb(26, 26, 26), RUBBER, 0),
	Brass = PartFactory.style(rgb(190, 150, 70), Enum.Material.Metal, 0.2),
	Lens = PartFactory.style(rgb(120, 170, 200), Enum.Material.Glass, 0.25, 0.75, false),
	LensRed = PartFactory.style(rgb(160, 60, 60), Enum.Material.Glass, 0.2, 0.7, false),
	LightLens = PartFactory.style(rgb(220, 235, 255), Enum.Material.Neon, 0, 0.3, false),
	Invisible = PartFactory.style(rgb(0, 0, 0), Enum.Material.SmoothPlastic, 0, 1, false),
}

type Ctx = {
	add: (name: string, size: Vector3, cf: CFrame, style: Style, shape: Enum.PartType?) -> BasePart,
	attach: (name: string, position: Vector3) -> Attachment,
	Handle: BasePart,
	Magazine: { BasePart },
}

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function alongZ(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z) * PartFactory.AxisZ
end

local function tilt(degrees: number): CFrame
	return CFrame.Angles(math.rad(degrees), 0, 0)
end

-- Emissive reticle drawn on the shooter-facing side of an optic window.
local function addReticle(window: BasePart, color: Color3, holographic: boolean)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Reticle"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 400
	gui.LightInfluence = 0
	gui.Brightness = 4
	gui.Parent = window

	local function circle(size: number, filled: boolean): Frame
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromOffset(size, size)
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = if filled then 0 else 1
		frame.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
		if not filled then
			local stroke = Instance.new("UIStroke")
			stroke.Color = color
			stroke.Thickness = 2
			stroke.Parent = frame
		end
		frame.Parent = gui
		return frame
	end
	circle(5, true)
	if holographic then
		circle(36, false)
	end
end

local function newCtx(model: Model, origin: CFrame): Ctx
	local handle = PartFactory.make({
		Name = "Handle",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = origin,
		Style = STYLES.Invisible,
		Anchored = false,
		Parent = model,
	})
	handle.Massless = true
	handle.CanQuery = false
	model.PrimaryPart = handle

	local ctx: Ctx
	ctx = {
		Handle = handle,
		Magazine = {},
		add = function(name: string, size: Vector3, cf: CFrame, style: Style, shape: Enum.PartType?): BasePart
			local part = PartFactory.make({
				Name = name,
				Size = size,
				CFrame = origin * cf,
				Style = style,
				Shape = shape,
				Anchored = false,
				Parent = model,
			})
			part.Massless = true
			part.CanQuery = false
			part.CastShadow = style.Transparency == nil or (style.Transparency :: number) < 0.5
			PartFactory.weld(handle, part)
			if string.sub(name, 1, 8) == "Magazine" then
				table.insert(ctx.Magazine, part)
			end
			return part
		end,
		attach = function(name: string, position: Vector3): Attachment
			local attachment = Instance.new("Attachment")
			attachment.Name = name
			attachment.Position = position
			attachment.Parent = handle
			return attachment
		end,
	}
	return ctx
end

local function railTeeth(ctx: Ctx, y: number, zStart: number, zEnd: number, width: number)
	local count = math.floor((zStart - zEnd) / 0.14)
	for i = 0, count do
		ctx.add("RailTooth" .. i, Vector3.new(width, 0.025, 0.045), at(0, y, zStart - i * 0.14), STYLES.Anodized)
	end
end

--------------------------------------------------------------------------------
-- VK-9 suppressed rifle
--------------------------------------------------------------------------------
local function buildRifle(ctx: Ctx)
	local S = STYLES
	local add = ctx.add

	-- Receivers
	add("LowerReceiver", Vector3.new(0.2, 0.26, 0.85), at(0, 0.16, -0.2), S.Anodized)
	add("MagWell", Vector3.new(0.2, 0.2, 0.3), at(0, 0.0, -0.45), S.Anodized)
	add("UpperReceiver", Vector3.new(0.21, 0.22, 1.05), at(0, 0.39, -0.2), S.Anodized)
	add("EjectionPort", Vector3.new(0.02, 0.09, 0.26), at(0.106, 0.4, -0.15), S.SteelDark)
	add("DustCover", Vector3.new(0.015, 0.1, 0.22), at(0.112, 0.33, -0.15), S.Anodized)
	add("ForwardAssist", Vector3.new(0.06, 0.06, 0.12), at(0.12, 0.42, 0.05), S.Steel)
	add("ChargingHandle", Vector3.new(0.26, 0.05, 0.08), at(0, 0.48, 0.3), S.Anodized)
	add("BoltRelease", Vector3.new(0.03, 0.08, 0.14), at(-0.11, 0.2, -0.32), S.Steel)
	add("Selector", Vector3.new(0.03, 0.05, 0.05), at(-0.11, 0.22, -0.02), S.Steel)

	-- Top rail
	add("TopRail", Vector3.new(0.13, 0.04, 1.75), at(0, 0.52, -0.55), S.Anodized)
	railTeeth(ctx, 0.545, 0.25, -1.35, 0.15)

	-- Handguard (FDE) with M-LOK slots
	add("Handguard", Vector3.new(0.25, 0.25, 1.15), at(0, 0.37, -1.3), S.FDE)
	add("HandguardCap", Vector3.new(0.26, 0.26, 0.05), at(0, 0.37, -1.875), S.Anodized)
	for _, side in { -1, 1 } do
		for i, z in { -0.95, -1.3, -1.65 } do
			add("MLok" .. side .. i, Vector3.new(0.02, 0.06, 0.18), at(side * 0.126, 0.37, z), S.SteelDark)
		end
	end
	add("BottomRail", Vector3.new(0.1, 0.04, 0.6), at(0, 0.23, -1.35), S.Anodized)
	add("Foregrip", Vector3.new(0.1, 0.32, 0.1), at(0, 0.06, -0.85), S.Polymer)
	add("ForegripCap", Vector3.new(0.11, 0.04, 0.11), at(0, -0.1, -0.85), S.Rubber)
	add("ForegripClamp", Vector3.new(0.12, 0.06, 0.16), at(0, 0.21, -0.85), S.Anodized)

	-- Light module
	add("LightBody", Vector3.new(0.07, 0.1, 0.32), at(-0.16, 0.38, -1.55), S.Anodized)
	add("LightLens", Vector3.new(0.05, 0.07, 0.02), at(-0.16, 0.38, -1.72), S.LightLens)
	add("LightMount", Vector3.new(0.05, 0.06, 0.1), at(-0.13, 0.38, -1.5), S.Anodized)

	-- Barrel + suppressor
	add("Barrel", Vector3.new(0.25, 0.09, 0.09), alongZ(0, 0.38, -2.0), S.SteelDark, Enum.PartType.Cylinder)
	add("Suppressor", Vector3.new(0.85, 0.23, 0.23), alongZ(0, 0.38, -2.5), S.Anodized, Enum.PartType.Cylinder)
	add("SuppressorRingA", Vector3.new(0.04, 0.24, 0.24), alongZ(0, 0.38, -2.1), S.Steel, Enum.PartType.Cylinder)
	add("SuppressorRingB", Vector3.new(0.05, 0.24, 0.24), alongZ(0, 0.38, -2.92), S.Steel, Enum.PartType.Cylinder)
	add("SuppressorBore", Vector3.new(0.02, 0.07, 0.07), alongZ(0, 0.38, -2.95), S.SteelDark, Enum.PartType.Cylinder)

	-- Grip, trigger
	add("PistolGrip", Vector3.new(0.15, 0.42, 0.22), at(0, -0.08, 0.06) * tilt(-18), S.Polymer)
	add("GripTexture", Vector3.new(0.155, 0.26, 0.14), at(0, -0.1, 0.07) * tilt(-18), S.Rubber)
	add("TriggerGuard", Vector3.new(0.04, 0.04, 0.32), at(0, 0.02, -0.2), S.Anodized)
	add("Trigger", Vector3.new(0.03, 0.1, 0.03), at(0, 0.07, -0.16), S.Steel)

	-- Curved magazine (two segments + baseplate)
	add("Magazine", Vector3.new(0.14, 0.55, 0.26), at(0, -0.28, -0.5) * tilt(12), S.Polymer)
	add("MagazineLower", Vector3.new(0.14, 0.3, 0.26), at(0, -0.62, -0.6) * tilt(22), S.Polymer)
	add("MagazineBase", Vector3.new(0.16, 0.05, 0.28), at(0, -0.77, -0.66) * tilt(22), S.Rubber)

	-- Stock
	add("BufferTube", Vector3.new(0.55, 0.12, 0.12), alongZ(0, 0.38, 0.55), S.Anodized, Enum.PartType.Cylinder)
	add("Stock", Vector3.new(0.17, 0.3, 0.5), at(0, 0.31, 0.88), S.FDE)
	add("CheekRiser", Vector3.new(0.15, 0.06, 0.36), at(0, 0.48, 0.86), S.FDE)
	add("ButtPad", Vector3.new(0.19, 0.36, 0.06), at(0, 0.3, 1.15), S.Rubber)
	add("SlingPoint", Vector3.new(0.05, 0.05, 0.08), at(0.1, 0.3, 0.72), S.Steel)

	-- Holographic sight
	add("HoloBase", Vector3.new(0.15, 0.07, 0.38), at(0, 0.57, -0.3), S.Anodized)
	add("HoloWallL", Vector3.new(0.025, 0.22, 0.32), at(-0.075, 0.72, -0.32), S.Anodized)
	add("HoloWallR", Vector3.new(0.025, 0.22, 0.32), at(0.075, 0.72, -0.32), S.Anodized)
	add("HoloHood", Vector3.new(0.175, 0.025, 0.32), at(0, 0.835, -0.32), S.Anodized)
	add("HoloKnob", Vector3.new(0.05, 0.07, 0.12), at(0.11, 0.6, -0.25), S.Steel)
	local window = add("HoloWindow", Vector3.new(0.125, 0.19, 0.015), at(0, 0.715, -0.45), S.Lens)
	addReticle(window, rgb(255, 60, 60), true)

	ctx.attach("Muzzle", Vector3.new(0, 0.38, -3.0))
	ctx.attach("Ejection", Vector3.new(0.14, 0.4, -0.15))
	ctx.attach("GripRight", Vector3.new(0, 0, 0))
	ctx.attach("GripLeft", Vector3.new(0, 0.02, -0.85))
end

--------------------------------------------------------------------------------
-- KR-45 compact SMG
--------------------------------------------------------------------------------
local function buildSMG(ctx: Ctx)
	local S = STYLES
	local add = ctx.add

	add("Receiver", Vector3.new(0.22, 0.32, 0.95), at(0, 0.26, -0.25), S.Polymer)
	add("ReceiverTop", Vector3.new(0.2, 0.06, 0.95), at(0, 0.44, -0.25), S.Anodized)
	add("TopRail", Vector3.new(0.12, 0.04, 0.7), at(0, 0.49, -0.3), S.Anodized)
	railTeeth(ctx, 0.515, 0.0, -0.6, 0.14)
	add("EjectionPort", Vector3.new(0.02, 0.08, 0.22), at(0.112, 0.32, -0.2), S.SteelDark)
	add("ChargingKnob", Vector3.new(0.06, 0.05, 0.08), at(-0.13, 0.36, -0.55), S.Steel)
	add("Selector", Vector3.new(0.03, 0.05, 0.05), at(-0.12, 0.2, -0.05), S.Steel)

	-- Vented shroud + brake
	add("Shroud", Vector3.new(0.2, 0.2, 0.45), at(0, 0.3, -0.95), S.Anodized)
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			add("ShroudVent" .. side .. i, Vector3.new(0.02, 0.05, 0.08), at(side * 0.101, 0.32, -0.8 - i * 0.13), S.SteelDark)
		end
	end
	add("Barrel", Vector3.new(0.22, 0.12, 0.12), alongZ(0, 0.3, -1.29), S.SteelDark, Enum.PartType.Cylinder)
	add("MuzzleBrake", Vector3.new(0.14, 0.15, 0.15), alongZ(0, 0.3, -1.36), S.Anodized, Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		add("BrakePort" .. side, Vector3.new(0.02, 0.04, 0.08), at(side * 0.07, 0.3, -1.36), S.SteelDark)
	end

	-- Grip, trigger, angled foregrip
	add("PistolGrip", Vector3.new(0.14, 0.38, 0.2), at(0, -0.05, 0.05) * tilt(-15), S.Polymer)
	add("GripTexture", Vector3.new(0.145, 0.24, 0.13), at(0, -0.06, 0.06) * tilt(-15), S.Rubber)
	add("TriggerGuard", Vector3.new(0.04, 0.04, 0.3), at(0, 0.05, -0.18), S.Polymer)
	add("Trigger", Vector3.new(0.03, 0.09, 0.03), at(0, 0.1, -0.15), S.Steel)
	add("AngledGrip", Vector3.new(0.1, 0.1, 0.32), at(0, 0.12, -0.85) * tilt(-20), S.Polymer)
	add("BottomRail", Vector3.new(0.1, 0.04, 0.4), at(0, 0.19, -0.9), S.Anodized)

	-- Straight magazine
	add("Magazine", Vector3.new(0.12, 0.62, 0.2), at(0, -0.18, -0.38) * tilt(6), S.SteelDark)
	add("MagazineBase", Vector3.new(0.14, 0.05, 0.22), at(0, -0.5, -0.36) * tilt(6), S.Polymer)

	-- Wire folding stock
	for _, y in { 0.36, 0.16 } do
		for _, x in { -0.06, 0.06 } do
			add("StockRail", Vector3.new(0.035, 0.035, 0.7), at(x, y, 0.55), S.Steel)
		end
	end
	add("StockHinge", Vector3.new(0.16, 0.26, 0.08), at(0, 0.26, 0.22), S.Anodized)
	add("ButtPlate", Vector3.new(0.16, 0.34, 0.05), at(0, 0.26, 0.92), S.Rubber)

	-- Reflex sight
	add("ReflexBase", Vector3.new(0.12, 0.05, 0.22), at(0, 0.54, -0.3), S.Anodized)
	add("ReflexPostL", Vector3.new(0.02, 0.16, 0.04), at(-0.06, 0.64, -0.36), S.Anodized)
	add("ReflexPostR", Vector3.new(0.02, 0.16, 0.04), at(0.06, 0.64, -0.36), S.Anodized)
	add("ReflexTop", Vector3.new(0.14, 0.02, 0.04), at(0, 0.725, -0.36), S.Anodized)
	local window = add("ReflexWindow", Vector3.new(0.1, 0.14, 0.01), at(0, 0.64, -0.36), S.LensRed)
	addReticle(window, rgb(255, 50, 50), false)

	ctx.attach("Muzzle", Vector3.new(0, 0.3, -1.45))
	ctx.attach("Ejection", Vector3.new(0.14, 0.32, -0.2))
	ctx.attach("GripRight", Vector3.new(0, 0, 0))
	ctx.attach("GripLeft", Vector3.new(0, 0.08, -0.85))
end

--------------------------------------------------------------------------------
-- M-50 heavy pistol
--------------------------------------------------------------------------------
local function buildPistol(ctx: Ctx)
	local S = STYLES
	local add = ctx.add

	add("Slide", Vector3.new(0.15, 0.17, 0.95), at(0, 0.33, -0.28), S.SteelDark)
	for i = 0, 4 do
		add("RearSerration" .. i, Vector3.new(0.155, 0.12, 0.018), at(0, 0.33, 0.06 + i * 0.03), S.Anodized)
	end
	for i = 0, 2 do
		add("FrontSerration" .. i, Vector3.new(0.155, 0.1, 0.018), at(0, 0.33, -0.55 - i * 0.03), S.Anodized)
	end
	add("EjectionPort", Vector3.new(0.02, 0.07, 0.2), at(0.076, 0.36, -0.2), S.Steel)
	add("Frame", Vector3.new(0.14, 0.12, 0.8), at(0, 0.2, -0.3), S.Polymer)
	add("DustRail", Vector3.new(0.1, 0.04, 0.25), at(0, 0.13, -0.55), S.Polymer)
	add("Compensator", Vector3.new(0.15, 0.15, 0.18), at(0, 0.33, -0.84), S.Anodized)
	add("CompPort", Vector3.new(0.06, 0.02, 0.1), at(0, 0.41, -0.84), S.SteelDark)
	add("Bore", Vector3.new(0.02, 0.07, 0.07), alongZ(0, 0.33, -0.94), S.SteelDark, Enum.PartType.Cylinder)

	add("Grip", Vector3.new(0.14, 0.48, 0.24), at(0, -0.08, 0.06) * tilt(-18), S.Polymer)
	add("GripPanel", Vector3.new(0.145, 0.3, 0.16), at(0, -0.06, 0.07) * tilt(-18), S.Rubber)
	add("Beavertail", Vector3.new(0.12, 0.05, 0.14), at(0, 0.2, 0.2) * tilt(-30), S.Polymer)
	add("TriggerGuard", Vector3.new(0.04, 0.04, 0.3), at(0, 0.08, -0.2), S.Polymer)
	add("Trigger", Vector3.new(0.03, 0.09, 0.03), at(0, 0.12, -0.16), S.Steel)
	add("Hammer", Vector3.new(0.05, 0.08, 0.06), at(0, 0.38, 0.22), S.Steel)
	add("SlideStop", Vector3.new(0.02, 0.04, 0.14), at(-0.08, 0.24, -0.25), S.Steel)

	add("Magazine", Vector3.new(0.11, 0.44, 0.19), at(0, -0.1, 0.07) * tilt(-18), S.SteelDark)
	add("MagazineBase", Vector3.new(0.15, 0.06, 0.25), at(0, -0.34, 0.14) * tilt(-18), S.Polymer)

	add("RearSight", Vector3.new(0.12, 0.05, 0.05), at(0, 0.44, 0.12), S.Anodized)
	add("FrontSight", Vector3.new(0.03, 0.05, 0.04), at(0, 0.44, -0.7), S.Anodized)
	add("DotHousing", Vector3.new(0.1, 0.09, 0.16), at(0, 0.46, -0.1), S.Anodized)
	local window = add("DotWindow", Vector3.new(0.08, 0.06, 0.01), at(0, 0.48, -0.18), S.LensRed)
	addReticle(window, rgb(255, 50, 50), false)

	ctx.attach("Muzzle", Vector3.new(0, 0.33, -0.98))
	ctx.attach("Ejection", Vector3.new(0.1, 0.38, -0.2))
	ctx.attach("GripRight", Vector3.new(0, 0, 0))
	ctx.attach("GripLeft", Vector3.new(-0.12, -0.05, 0.02))
end

local BUILDERS: { [string]: (Ctx) -> () } = {
	SuppressedRifle = buildRifle,
	CompactSMG = buildSMG,
	HeavyPistol = buildPistol,
}

function WeaponBuilder.has(weaponId: string): boolean
	return BUILDERS[weaponId] ~= nil
end

-- origin: world CFrame of the grip point. Anchored = true for display props.
function WeaponBuilder.build(weaponId: string, origin: CFrame?, anchored: boolean?): WeaponHandles
	local builder = BUILDERS[weaponId]
	assert(builder, "[WeaponBuilder] unknown weapon " .. tostring(weaponId))

	local model = Instance.new("Model")
	model.Name = weaponId
	model:SetAttribute("WeaponId", weaponId)
	local ctx = newCtx(model, origin or CFrame.identity)
	builder(ctx)
	ctx.Handle.Anchored = anchored == true
	CollectionService:AddTag(model, "Weapon")

	local function need(name: string): Attachment
		local attachment = ctx.Handle:FindFirstChild(name)
		assert(attachment and attachment:IsA("Attachment"), "[WeaponBuilder] missing attachment " .. name)
		return attachment
	end

	return {
		Model = model,
		Handle = ctx.Handle,
		Muzzle = need("Muzzle"),
		Ejection = need("Ejection"),
		GripRight = need("GripRight"),
		GripLeft = need("GripLeft"),
		Magazine = ctx.Magazine,
	}
end

-- Finds the standard attachments on an already-built weapon model.
function WeaponBuilder.resolve(model: Model): WeaponHandles?
	local handle = model:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return nil
	end
	local function find(name: string): Attachment?
		local attachment = handle:FindFirstChild(name)
		return if attachment and attachment:IsA("Attachment") then attachment else nil
	end
	local muzzle, ejection, right, left = find("Muzzle"), find("Ejection"), find("GripRight"), find("GripLeft")
	if not (muzzle and ejection and right and left) then
		return nil
	end
	local magazine: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 8) == "Magazine" then
			table.insert(magazine, child)
		end
	end
	return {
		Model = model,
		Handle = handle,
		Muzzle = muzzle,
		Ejection = ejection,
		GripRight = right,
		GripLeft = left,
		Magazine = magazine,
	}
end

return WeaponBuilder
