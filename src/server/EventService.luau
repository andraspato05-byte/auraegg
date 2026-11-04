--[[
	EventService - the AURA STORM event

	Every Config.Event.Interval seconds (first one after Config.Event.FirstDelay)
	a purple lightning storm rolls in for Config.Event.Duration seconds:
	  - the sky goes dark purple with storm clouds (lightning flashes on clients)
	  - the Aura Egg Machine sends eggs out twice as fast
	  - Rare and better eggs are 3x more likely
	  - 30% of eggs come out Storm-charged (3x income, saved with the egg)

	The schedule is shared with clients through Workspace attributes:
	  EventName, EventActive, EventEndsAt, NextEventAt (server time, see
	  workspace:GetServerTimeNow()).

	In Studio, the "START STORM" button on screen starts one right away.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)

local EventService = {}

local STORM_COLOR = Color3.fromRGB(150, 200, 255)

local active = false
local endsAt = 0
local nextAt = 0
local warned = false
local savedLighting = nil
local stormObjects = {}

local function now()
	return workspace:GetServerTimeNow()
end

local function publish()
	workspace:SetAttribute("EventName", Config.Event.Name)
	workspace:SetAttribute("EventActive", active)
	workspace:SetAttribute("EventEndsAt", endsAt)
	workspace:SetAttribute("NextEventAt", nextAt)
end

local function applyStormLook()
	savedLighting = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
	}
	Lighting.ClockTime = 19.2
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(70, 50, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 80, 170)

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "AuraStormTint"
	tint.TintColor = Color3.fromRGB(205, 185, 255)
	tint.Saturation = 0.15
	tint.Contrast = 0.1
	tint.Parent = Lighting
	table.insert(stormObjects, tint)

	local clouds = Instance.new("Clouds")
	clouds.Name = "AuraStormClouds"
	clouds.Cover = 0.85
	clouds.Density = 0.7
	clouds.Color = Color3.fromRGB(90, 60, 140)
	clouds.Parent = workspace.Terrain
	table.insert(stormObjects, clouds)
end

local function removeStormLook()
	for _, object in stormObjects do
		object:Destroy()
	end
	table.clear(stormObjects)
	if savedLighting then
		for property, value in savedLighting do
			Lighting[property] = value
		end
		savedLighting = nil
	end
end

function EventService.IsActive()
	return active
end

function EventService.Start()
	if active then
		return
	end
	local t = now()
	active = true
	warned = false
	endsAt = t + Config.Event.Duration
	nextAt = t + Config.Event.Interval
	applyStormLook()
	publish()
	Remotes.NotifyAll(
		"The " .. Config.Event.Name .. " has begun! Rare eggs x" .. Config.Event.RareLuck .. " and Storm eggs (x3 cash)!",
		STORM_COLOR
	)
end

function EventService.Stop()
	if not active then
		return
	end
	active = false
	endsAt = 0
	removeStormLook()
	publish()
	Remotes.NotifyAll("The " .. Config.Event.Name .. " is over. Storm eggs keep their power!", STORM_COLOR)
end

local function step()
	local t = now()
	if active then
		if t >= endsAt then
			EventService.Stop()
		end
	else
		if not warned and nextAt - t <= Config.Event.WarningTime and nextAt - t > 0 then
			warned = true
			Remotes.NotifyAll(
				"An " .. Config.Event.Name .. " is coming in " .. math.ceil(nextAt - t) .. " seconds!",
				STORM_COLOR
			)
		end
		if t >= nextAt then
			EventService.Start()
		end
	end
end

function EventService.Init()
	nextAt = now() + Config.Event.FirstDelay
	publish()

	-- Studio-only test button. Live servers ignore it.
	Remotes.StartEventEvent.OnServerEvent:Connect(function()
		if RunService:IsStudio() then
			EventService.Start()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(step)
			if not ok then
				warn("[StealTheAuraEgg] Event error: " .. tostring(err))
			end
		end
	end)
end

return EventService
