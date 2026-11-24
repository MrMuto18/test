#!/usr/bin/env python3
"""Bundle every Luau source in src/ into ONE Roblox Studio Command Bar installer.

Usage:  python3 build_installer.py   ->  writes SandsweepInstaller.lua
"""
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "SandsweepInstaller.lua")

# (container key, parent path, instance name, class, source file)
ENTRIES = [
    ("RS", "Sandsweep", "GameConfig", "ModuleScript", "ReplicatedStorage/Sandsweep/GameConfig.lua"),
    ("RS", "Sandsweep", "Util", "ModuleScript", "ReplicatedStorage/Sandsweep/Util.lua"),
    ("RS", "Sandsweep", "PartKit", "ModuleScript", "ReplicatedStorage/Sandsweep/PartKit.lua"),
    ("RS", "Sandsweep", "ToolModels", "ModuleScript", "ReplicatedStorage/Sandsweep/ToolModels.lua"),
    ("RS", "Sandsweep", "FindModels", "ModuleScript", "ReplicatedStorage/Sandsweep/FindModels.lua"),
    ("RS", "Sandsweep", "VehicleModels", "ModuleScript", "ReplicatedStorage/Sandsweep/VehicleModels.lua"),
    ("SSS", "Sandsweep", "WorldBuilder", "ModuleScript", "ServerScriptService/Sandsweep/WorldBuilder.lua"),
    ("SSS", "Sandsweep", "LotService", "ModuleScript", "ServerScriptService/Sandsweep/LotService.lua"),
    ("SSS", "Sandsweep", "FindsService", "ModuleScript", "ServerScriptService/Sandsweep/FindsService.lua"),
    ("SSS", "Sandsweep", "DataService", "ModuleScript", "ServerScriptService/Sandsweep/DataService.lua"),
    ("SSS", "Sandsweep", "FactoryService", "ModuleScript", "ServerScriptService/Sandsweep/FactoryService.lua"),
    ("SSS", "Sandsweep", "VehicleService", "ModuleScript", "ServerScriptService/Sandsweep/VehicleService.lua"),
    ("SSS", "Sandsweep", "Main", "Script", "ServerScriptService/Sandsweep/Main.server.lua"),
    ("SPS", "", "SandsweepClient", "LocalScript", "StarterPlayerScripts/SandsweepClient/init.client.lua"),
    ("SPS", "SandsweepClient", "ClientState", "ModuleScript", "StarterPlayerScripts/SandsweepClient/ClientState.lua"),
    ("SPS", "SandsweepClient", "Effects", "ModuleScript", "StarterPlayerScripts/SandsweepClient/Effects.lua"),
    ("SPS", "SandsweepClient", "DigController", "ModuleScript", "StarterPlayerScripts/SandsweepClient/DigController.lua"),
    ("SPS", "SandsweepClient", "Interface", "ModuleScript", "StarterPlayerScripts/SandsweepClient/Interface.lua"),
    ("SPS", "SandsweepClient", "VehicleController", "ModuleScript", "StarterPlayerScripts/SandsweepClient/VehicleController.lua"),
]

REMOTE_EVENTS = ["DigRequest", "DigResult", "DigFx", "StateUpdate", "LotUpdate", "Notify", "OpenMenu", "VehicleAction", "FactoryFx"]
REMOTE_FUNCTIONS = ["Purchase", "GetState"]

HEADER = r'''-- =====================================================================
--  SANDSWEEP - one-paste Roblox Studio installer
--  Paste this whole file into View > Command Bar, press Enter, then Play.
--  Re-running it cleanly replaces a previous Sandsweep install.
-- =====================================================================
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local Lighting = game:GetService("Lighting")

pcall(function() ChangeHistoryService:SetWaypoint("Before Sandsweep install") end)

for _, old in ipairs({
	ReplicatedStorage:FindFirstChild("Sandsweep"),
	ServerScriptService:FindFirstChild("Sandsweep"),
	StarterPlayerScripts:FindFirstChild("SandsweepClient"),
}) do
	if old then old:Destroy() end
end

local function make(className, name, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local Containers = {
	RS = make("Folder", "Sandsweep", ReplicatedStorage),
	SSS = make("Folder", "Sandsweep", ServerScriptService),
	SPS = StarterPlayerScripts,
}
local remotes = make("Folder", "Remotes", Containers.RS)
'''

FOOTER = r'''
-- Studio-only settings (Lighting.Technology can only be set from Studio)
pcall(function() Lighting.Technology = Enum.Technology.Future end)
StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
StarterPlayer.CharacterWalkSpeed = 16

-- Remove the default template Baseplate/SpawnLocation (the game builds its own world)
for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
	local part = workspace:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		part:Destroy()
		print("[Sandsweep] Removed default " .. name)
	end
end

pcall(function() ChangeHistoryService:SetWaypoint("Sandsweep installed") end)
print("[Sandsweep] Installed! Press Play (F5). Tip: enable Game Settings > Security > Studio Access to API Services to test DataStore saving.")
'''


def pick_level(sources):
    level = 6
    while any(("]" + "=" * level + "]") in s for s in sources):
        level += 1
    return level


def main():
    sources = []
    for entry in ENTRIES:
        with open(os.path.join(SRC, entry[4]), encoding="utf-8") as f:
            sources.append(f.read())
    level = pick_level(sources)
    open_b, close_b = "[" + "=" * level + "[", "]" + "=" * level + "]"

    out = [HEADER]
    for name in REMOTE_EVENTS:
        out.append(f'make("RemoteEvent", "{name}", remotes)\n')
    for name in REMOTE_FUNCTIONS:
        out.append(f'make("RemoteFunction", "{name}", remotes)\n')
    out.append("\nlocal created = {}\n")
    for (container, parent, name, cls, path), source in zip(ENTRIES, sources):
        if parent == "" or (container in ("RS", "SSS") and parent == "Sandsweep"):
            parent_expr = f"Containers.{container}"
        else:
            parent_expr = f'created["{parent}"]'
        out.append(f"\n-- {cls}: {path}\n")
        out.append(f'created["{name}"] = make("{cls}", "{name}", {parent_expr})\n')
        out.append(f'created["{name}"].Source = {open_b}\n{source}{close_b}\n')
    out.append(FOOTER)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("".join(out))
    total = sum(len(s.splitlines()) for s in sources)
    print(f"Wrote {OUT} ({os.path.getsize(OUT)//1024} KB, {total} source lines, bracket level {level})")


if __name__ == "__main__":
    main()
