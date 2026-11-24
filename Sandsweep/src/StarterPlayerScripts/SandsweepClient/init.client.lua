-- SandsweepClient (LocalScript) - StarterPlayer/StarterPlayerScripts/SandsweepClient
-- Client entry point. Child ModuleScripts: ClientState, Effects, DigController, Interface.

local ClientState = require(script:WaitForChild("ClientState"))
local Effects = require(script:WaitForChild("Effects"))
local DigController = require(script:WaitForChild("DigController"))
local Interface = require(script:WaitForChild("Interface"))

ClientState.Init()
Effects.Init()
Interface.Init({
	OnDigPress = DigController.Press,
})
DigController.Init()
