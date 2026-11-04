--[[
	Session
	Holds each player's live cash / steals while they are in the server and
	mirrors them into leaderstats so they show on the player list.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Session = {}

local sessions = {}

function Session.Create(player)
	local existing = sessions[player]
	if existing then
		return existing
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = 0
	cashValue.Parent = leaderstats

	local stealsValue = Instance.new("IntValue")
	stealsValue.Name = "Steals"
	stealsValue.Value = 0
	stealsValue.Parent = leaderstats

	local speedValue = Instance.new("IntValue")
	speedValue.Name = "Speed"
	speedValue.Value = 0
	speedValue.Parent = leaderstats

	local sizeValue = Instance.new("IntValue")
	sizeValue.Name = "Size" -- percent: 100 = normal, 250 = max
	sizeValue.Value = 100
	sizeValue.Parent = leaderstats

	leaderstats.Parent = player

	local session = {
		Player = player,
		Cash = 0,
		Steals = 0,
		Speed = 0, -- treadmill Speed points (can be fractional; leaderstats shows the whole number)
		BaseLevel = 1, -- base upgrade level (see Config.BaseUpgrades)
		Loaded = false, -- true once saved data has been applied
		CanSave = false, -- false if loading failed, so we never overwrite real data
		SavedEggs = nil, -- eggs kept aside while the player is waiting for a free base
		FinalSaved = false, -- true once the shutdown save has been queued
		CashValue = cashValue,
		StealsValue = stealsValue,
		SpeedValue = speedValue,
		SizeValue = sizeValue,
	}
	sessions[player] = session
	return session
end

function Session.Get(player)
	return sessions[player]
end

function Session.Remove(player)
	sessions[player] = nil
end

function Session.SetCash(player, amount)
	local session = sessions[player]
	if not session then
		return
	end
	session.Cash = math.max(0, math.floor(amount))
	session.CashValue.Value = session.Cash
end

function Session.AddCash(player, amount)
	local session = sessions[player]
	if not session then
		return
	end
	Session.SetCash(player, session.Cash + amount)
end

-- Returns true and takes the money if the player can afford it.
function Session.TrySpend(player, amount)
	local session = sessions[player]
	if not session or session.Cash < amount then
		return false
	end
	Session.SetCash(player, session.Cash - amount)
	return true
end

function Session.SetSteals(player, amount)
	local session = sessions[player]
	if not session then
		return
	end
	session.Steals = math.max(0, math.floor(amount))
	session.StealsValue.Value = session.Steals
end

-- Returns true if the whole-number Speed changed (so walk speed should be refreshed).
function Session.SetSpeed(player, amount)
	local session = sessions[player]
	if not session then
		return false
	end
	local before = math.floor(session.Speed)
	session.Speed = math.clamp(amount, 0, Config.MaxSpeed)
	session.SpeedValue.Value = math.floor(session.Speed)
	return math.floor(session.Speed) ~= before
end

function Session.AddSpeed(player, amount)
	local session = sessions[player]
	if not session then
		return false
	end
	return Session.SetSpeed(player, session.Speed + amount)
end

function Session.GetWalkSpeed(player)
	local session = sessions[player]
	return Config.GetWalkSpeed(session and session.Speed or 0)
end

function Session.AddSteal(player)
	local session = sessions[player]
	if session then
		Session.SetSteals(player, session.Steals + 1)
	end
end

return Session
