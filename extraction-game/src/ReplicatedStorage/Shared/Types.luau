--!strict
--[[
	Types
	Shared type contracts between server and client. No runtime dependencies.
]]

export type QualityLevel = "Low" | "Medium" | "High" | "Ultra"

export type PlayerState = "Menu" | "Deploying" | "Deployed"

export type WeaponSlot = "Primary" | "Secondary"

export type PlayerSettings = {
	Quality: QualityLevel,
	FieldOfView: number,
	Sensitivity: number,
}

export type Loadout = {
	Primary: string,
	Secondary: string,
}

export type WeaponStats = {
	Damage: number,
	FireRate: number,
	Handling: number,
	Range: number,
}

export type FireMode = "Auto" | "Semi"

export type Stance = "Stand" | "Crouch" | "Slide"

export type WeaponCombat = {
	Damage: number,
	HeadMultiplier: number,
	RPM: number,
	FireMode: FireMode,
	MagSize: number,
	Reserve: number,
	ReloadTime: number,
	EmptyReloadTime: number,
	DrawTime: number,
	Range: number,
	FalloffStart: number,
	MinDamageRatio: number,
	HipSpread: number, -- degrees (cone half-angle)
	AdsSpread: number,
	MoveSpread: number, -- added at full run speed
	SpreadPerShot: number,
	MaxBloom: number,
	BloomRecovery: number, -- degrees per second
	RecoilPitch: number, -- degrees per shot
	RecoilYaw: number, -- max random yaw, degrees
	RecoilRecovery: number, -- 0..1 share of climb that recovers
	AdsFovMultiplier: number,
	AdsTime: number,
	MoveSpeedMultiplier: number,
	Suppressed: boolean,
	TracerColor: Color3,
	FireSound: string, -- key into Config.Audio
}

export type WeaponDef = {
	DisplayName: string,
	Class: "RIFLE" | "SMG" | "PISTOL",
	Slot: WeaponSlot,
	Description: string,
	Stats: WeaponStats,
	Order: number,
	Combat: WeaponCombat,
}

export type ProfileData = {
	Version: number,
	Settings: PlayerSettings,
	Loadout: Loadout,
	Stash: { [string]: number },
	StashValue: number,
}

export type ClientProfile = {
	Settings: PlayerSettings,
	Loadout: Loadout,
	StashValue: number,
}

export type AudioDef = {
	Id: string,
	Volume: number,
	Speed: number,
	Group: "UI" | "Ambience" | "World",
}

export type QualityPreset = {
	RainRate: number,
	Splashes: boolean,
	GroundMist: boolean,
	Beams: boolean,
	SunRays: boolean,
	DepthOfField: boolean,
	BloomScale: number,
	Lightning: boolean,
	ExhaustSmoke: boolean,
	LightShadows: boolean,
}

return {}
