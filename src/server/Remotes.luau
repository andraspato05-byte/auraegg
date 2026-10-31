--[[
	Remotes
	Creates the RemoteEvents used to talk to clients and wraps them in
	small helpers that never error on players who already left.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
end

local function getOrCreate(name)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

Remotes.NotifyEvent = getOrCreate("Notify") -- (text: string, color: Color3)
Remotes.KnockbackEvent = getOrCreate("Knockback") -- (velocity: Vector3)

folder.Parent = ReplicatedStorage

local WHITE = Color3.fromRGB(255, 255, 255)

local function isInGame(player)
	return player ~= nil and player.Parent == Players
end

function Remotes.Notify(player, text, color)
	if isInGame(player) then
		Remotes.NotifyEvent:FireClient(player, text, color or WHITE)
	end
end

function Remotes.NotifyAll(text, color)
	Remotes.NotifyEvent:FireAllClients(text, color or WHITE)
end

function Remotes.Knockback(player, velocity)
	if isInGame(player) then
		Remotes.KnockbackEvent:FireClient(player, velocity)
	end
end

return Remotes
