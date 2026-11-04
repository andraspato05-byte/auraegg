--[[
	STEAL THE AURA EGG - server entry point

	Builds the map, starts every service, and handles players joining,
	spawning, leaving and the server shutting down.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(Server.Remotes) -- creates the RemoteEvents first
local MapBuilder = require(Server.MapBuilder)
local Session = require(Server.Session)
local DataManager = require(Server.DataManager)
local PlotService = require(Server.PlotService)
local ConveyorService = require(Server.ConveyorService)
local BatService = require(Server.BatService)
local TreadmillService = require(Server.TreadmillService)
local EventService = require(Server.EventService)
local MonetizationService = require(Server.MonetizationService)

------------------------------------------------------------------------------
-- World setup
------------------------------------------------------------------------------

Lighting.ClockTime = 14.5
Lighting.Brightness = 2
Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 160)
if not Lighting:FindFirstChildOfClass("BloomEffect") then
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

-- Build everything before any character can fall into the void.
local world = MapBuilder.Build()
PlotService.Init(world.Plots)
EventService.Init()
ConveyorService.Init(world.Belt)
BatService.Init()
TreadmillService.Init(world.Treadmills)
MonetizationService.Init()

------------------------------------------------------------------------------
-- Players
------------------------------------------------------------------------------

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or character.Parent == nil then
		return
	end

	humanoid.WalkSpeed = Session.GetWalkSpeed(player)
	humanoid.Died:Connect(function()
		PlotService.CancelCarry(player, "You got knocked out and dropped the egg!")
	end)

	PlotService.SetupCharacter(player, character)
	BatService.HookCharacter(player, character)
	task.delay(1, BatService.EnsureBat, player)
end

-- When a base frees up, give it to a loaded player who joined while every base was taken.
local function giveFreeBasesToWaitingPlayers()
	for _, player in Players:GetPlayers() do
		local session = Session.Get(player)
		if session and session.Loaded and not PlotService.GetPlot(player) then
			local plot = PlotService.AssignPlot(player)
			if not plot then
				return -- no free bases left
			end
			PlotService.LoadEggs(player, session.SavedEggs or {})
			session.SavedEggs = nil
			if player.Character then
				PlotService.SetupCharacter(player, player.Character)
			end
			Remotes.Notify(player, "A base opened up. It's yours now!", Color3.fromRGB(110, 255, 140))
		end
	end
end

local function onPlayerAdded(player)
	if Session.Get(player) then
		return -- already handled
	end
	local session = Session.Create(player)
	task.spawn(MonetizationService.LoadPasses, player)

	local plot = PlotService.AssignPlot(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		PlotService.CancelCarry(player, nil)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	local data, canSave = DataManager.Load(player)
	if player.Parent ~= Players then
		return -- left while loading
	end

	session.CanSave = canSave
	Session.SetCash(player, data.Cash)
	Session.SetSteals(player, data.Steals)
	Session.SetSpeed(player, data.Speed)
	PlotService.RefreshWalkSpeed(player)
	if PlotService.GetPlot(player) then
		PlotService.LoadEggs(player, data.Eggs)
	else
		session.SavedEggs = data.Eggs -- kept safe until a base frees up
	end
	session.Loaded = true

	Remotes.Notify(player, "Welcome to " .. Config.GameName .. "!", Color3.fromRGB(200, 140, 255))
	if plot then
		Remotes.Notify(player, "Your base has your name over the entrance.", Color3.fromRGB(255, 220, 90))
	else
		Remotes.Notify(player, "All bases are taken! You'll get one as soon as someone leaves.", Color3.fromRGB(255, 90, 90))
		giveFreeBasesToWaitingPlayers()
	end
	if not canSave then
		Remotes.Notify(player, "Saving is off (DataStores unavailable). Progress resets when you leave.", Color3.fromRGB(255, 150, 40))
	end
end

local function onPlayerRemoving(player)
	-- Put every egg that is mid-steal back first, so nothing is lost or duplicated.
	PlotService.PrepareForLeave(player)

	local session = Session.Get(player)
	local saveData = nil
	if session and session.Loaded and session.CanSave and not session.FinalSaved then
		saveData = PlotService.BuildSaveData(player)
	end

	PlotService.ReleasePlot(player)
	Session.Remove(player)
	BatService.Forget(player)
	PlotService.Forget(player)

	if saveData then
		DataManager.Save(player.UserId, saveData, true) -- final save, releases the session lock
	end

	if not PlotService.IsShuttingDown() then
		giveFreeBasesToWaitingPlayers()
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

------------------------------------------------------------------------------
-- Saving
------------------------------------------------------------------------------

-- DataManager.Save never yields and never runs two saves for the same player at once.
local function saveEveryone(isFinal)
	for _, player in Players:GetPlayers() do
		local session = Session.Get(player)
		if session and session.Loaded and session.CanSave and not session.FinalSaved then
			local data = PlotService.BuildSaveData(player)
			if data then
				if isFinal then
					session.FinalSaved = true -- PlayerRemoving must not save an older/newer copy after this
				end
				DataManager.Save(player.UserId, data, isFinal)
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		if PlotService.IsShuttingDown() then
			break
		end
		saveEveryone(false)
	end
end)

game:BindToClose(function()
	-- Freeze anything that moves eggs between players, then take one final snapshot.
	PlotService.BeginShutdown()
	saveEveryone(true)
	-- Wait for every save, including ones started by players who just left.
	DataManager.WaitForAll(25)
end)
