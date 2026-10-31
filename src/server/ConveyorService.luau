--[[
	ConveyorService
	Spawns random Aura Eggs from the Aura Egg Machine, slides them down the
	belt, and lets players buy them. A bought egg goes straight onto a free
	pedestal in the buyer's base.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EggVisuals = require(script.Parent.EggVisuals)
local Session = require(script.Parent.Session)
local Remotes = require(script.Parent.Remotes)
local PlotService = require(script.Parent.PlotService)

local ConveyorService = {}

local COLOR_GOOD = Color3.fromRGB(110, 255, 140)
local COLOR_BAD = Color3.fromRGB(255, 90, 90)
local COLOR_PRICE = Color3.fromRGB(255, 220, 70)
local MAX_BUY_DISTANCE = 20

local rng = Random.new()
local beltEggs = {} -- array of { Model, EggId, X, Angle, HalfHeight, Bought }
local belt = nil
local folder = nil

local function positionEgg(entry)
	local y = belt.SurfaceY + entry.HalfHeight + 0.3
	entry.Model:PivotTo(CFrame.new(entry.X, y, belt.Z) * CFrame.Angles(0, entry.Angle, 0))
end

local function removeEntry(entry)
	local index = table.find(beltEggs, entry)
	if index then
		table.remove(beltEggs, index)
	end
	if entry.Model then
		entry.Model:Destroy()
	end
end

local function tryBuy(player, entry)
	if entry.Bought or not entry.Model.Parent or PlotService.IsShuttingDown() then
		return
	end

	local session = Session.Get(player)
	if not session or not session.Loaded then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - entry.Model:GetPivot().Position).Magnitude > MAX_BUY_DISTANCE then
		return
	end

	local def = Config.GetEgg(entry.EggId)
	local plot = PlotService.GetPlot(player)
	if not plot then
		Remotes.Notify(player, "You don't have a base yet!", COLOR_BAD)
		return
	end

	local slotIndex = PlotService.FindFreeSlot(plot)
	if not slotIndex then
		Remotes.Notify(player, "Your base is full! Sell an egg to make room.", COLOR_BAD)
		return
	end

	if not Session.TrySpend(player, def.Price) then
		Remotes.Notify(player, "You need " .. Config.FormatCash(def.Price) .. " to buy the " .. def.Name .. "!", COLOR_BAD)
		return
	end

	entry.Bought = true
	removeEntry(entry)
	PlotService.PlaceEgg(plot, slotIndex, entry.EggId)
	Remotes.Notify(player, "You bought the " .. def.Name .. "! It's on your base now.", COLOR_GOOD)
end

local function spawnEgg()
	if #beltEggs >= Config.BeltMaxEggs then
		return
	end

	local eggId = Config.RollEggId(rng)
	local model, def, core = EggVisuals.Create(eggId, true)
	EggVisuals.AddInfo(model, Config.FormatCash(def.Price), COLOR_PRICE)

	local entry = {
		Model = model,
		EggId = eggId,
		X = belt.StartX,
		Angle = rng:NextNumber() * math.pi * 2,
		HalfHeight = core.Size.Y / 2,
		Bought = false,
	}

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy " .. Config.FormatCash(def.Price)
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0.25
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		tryBuy(player, entry)
	end)
	prompt.Parent = core

	positionEgg(entry)
	model.Parent = folder
	table.insert(beltEggs, entry)

	local rarity = Config.GetRarity(def.Rarity)
	if rarity.Index >= Config.AnnounceRarityIndex then
		Remotes.NotifyAll("A " .. def.Rarity .. " " .. def.Name .. " just came out of the machine!", rarity.Color)
	end
end

local function step(dt)
	for index = #beltEggs, 1, -1 do
		local entry = beltEggs[index]
		entry.X += Config.BeltSpeed * dt
		entry.Angle += dt * 0.8
		if entry.X >= belt.EndX then
			table.remove(beltEggs, index)
			entry.Model:Destroy()
		else
			positionEgg(entry)
		end
	end
end

function ConveyorService.Init(beltInfo)
	belt = beltInfo

	folder = Instance.new("Folder")
	folder.Name = "BeltEggs"
	folder.Parent = workspace

	RunService.Heartbeat:Connect(step)

	task.spawn(function()
		while true do
			local ok, err = pcall(spawnEgg)
			if not ok then
				warn("[StealTheAuraEgg] Belt spawn error: " .. tostring(err))
			end
			task.wait(Config.BeltSpawnInterval)
		end
	end)
end

return ConveyorService
