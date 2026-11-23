-- Paste into View → Command Bar (edit mode, NOT while playing) and press Enter.
-- Applies the look-dev and bakes the safehouse into Workspace so you can
-- see and tweak it in the editor. Re-run any time to rebuild from code.
-- The server Bootstrap reuses a baked Safehouse instead of rebuilding it.

local SSS = game:GetService("ServerScriptService")
local server = SSS:WaitForChild("Server")
require(server.Services.LightingService).apply()
require(server.World.SafehouseBuilder).ensure(true)
game:GetService("Players").CharacterAutoLoads = false
print("[Zabour] Phase 1 studio setup complete. Remember: Lighting.Technology = Future (Properties panel) if it was listed above.")
