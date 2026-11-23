--!strict
--[[
	Net
	Owns every RemoteEvent / RemoteFunction. The server creates them once in
	Net.init(); both sides fetch them by name through Net.event / Net.func.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local CLIENT_TIMEOUT = 30

local Net = {}

Net.Events = {
	RequestDeploy = "RequestDeploy",
	SetLoadout = "SetLoadout",
	SaveSettings = "SaveSettings",
}

Net.Functions = {
	GetProfile = "GetProfile",
}

local function getFolder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_TIMEOUT)
	if not folder then
		error("[Net] Remotes folder never replicated — is the server Bootstrap running?")
	end
	return folder
end

local function fetch(name: string): Instance
	local folder = getFolder()
	local instance: Instance? = if RunService:IsServer()
		then folder:FindFirstChild(name)
		else folder:WaitForChild(name, CLIENT_TIMEOUT)
	if not instance then
		error(string.format("[Net] remote '%s' does not exist", name))
	end
	return instance
end

function Net.init()
	assert(RunService:IsServer(), "[Net] init() is server-only")
	local folder = getFolder()
	for _, name in Net.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Net.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Net.event(name: string): RemoteEvent
	local instance = fetch(name)
	if instance:IsA("RemoteEvent") then
		return instance
	end
	error(string.format("[Net] '%s' is not a RemoteEvent", name))
end

function Net.func(name: string): RemoteFunction
	local instance = fetch(name)
	if instance:IsA("RemoteFunction") then
		return instance
	end
	error(string.format("[Net] '%s' is not a RemoteFunction", name))
end

return Net
