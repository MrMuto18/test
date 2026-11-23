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

export type WeaponDef = {
	DisplayName: string,
	Class: string,
	Slot: WeaponSlot,
	Description: string,
	Stats: WeaponStats,
	Order: number,
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
