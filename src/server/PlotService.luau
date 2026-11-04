--[[
	PlotService
	Everything that happens on a player's base:
	  - assigning / releasing bases
	  - placing eggs on pedestals and earning cash every second
	  - collecting cash from the green pads
	  - locking the base with the red pad
	  - selling your own eggs
	  - stealing other players' eggs, carrying them home, and dropping them
	    if you die or get bonked with a bat
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EggVisuals = require(script.Parent.EggVisuals)
local PetVisuals = require(script.Parent.PetVisuals)
local Session = require(script.Parent.Session)
local Remotes = require(script.Parent.Remotes)

local PlotService = {}

local COLOR_GOOD = Color3.fromRGB(110, 255, 140)
local COLOR_BAD = Color3.fromRGB(255, 90, 90)
local COLOR_INFO = Color3.fromRGB(255, 220, 90)
local COLOR_ALERT = Color3.fromRGB(255, 150, 40)

local PROMPT_DISTANCE = 10
local MAX_INTERACT_DISTANCE = 16 -- server-side sanity check for prompts
local CARRY_HEIGHT = 3.3 -- studs above the HumanoidRootPart to the bottom of a carried egg

local plots = {} -- array of plot states
local plotByPlayer = {} -- [Player] = plot state
local carriers = {} -- [Player] = { FromPlot, SlotIndex, EggId, Mutation, Hatched, Model, Weld, StartTime, MinTime, Speed, LastPos, LastMoveTime }
local holdStarts = {} -- [Player] = { Prompt, Time } when they started holding a Steal prompt
local collisionGroupsReady = false
local shuttingDown = false

local MOVE_SLACK_MULTIPLIER = 1.6 -- carriers may move this much faster than CarryWalkSpeed (lag, jumps)
local MOVE_SLACK_STUDS = 4
local HOLD_TOLERANCE = 0.7 -- the server must see at least 70% of the hold time (network jitter)

local carriedFolder = Instance.new("Folder")
carriedFolder.Name = "CarriedEggs"
carriedFolder.Parent = workspace

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

-- Returns humanoid, rootPart for a living character, or nil.
local function getLivingCharacter(player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil
	end
	return humanoid, root
end

local function ownerGroupName(index)
	return "PlotOwner" .. index
end

local function barrierGroupName(index)
	return "PlotBarrier" .. index
end

local function isInsidePlot(plot, position)
	local localPos = plot.Info.CFrame:PointToObjectSpace(position)
	local half = plot.Info.HalfSize
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half and localPos.Y > -5 and localPos.Y < 40
end

local function sellPrice(eggId, mutationName, hatched)
	return math.floor(Config.GetEggPrice(eggId, mutationName, hatched) * Config.SellMultiplier)
end

-- The owner's base upgrade level (see Config.BaseUpgrades).
local function levelOf(plot)
	local session = plot.Owner and Session.Get(plot.Owner)
	return Config.GetBaseLevel(session and session.BaseLevel or 1)
end

local function unlockedSlots(plot)
	return math.min(levelOf(plot).Slots, #plot.Slots)
end

local function findFreeSlot(plot)
	for index = 1, unlockedSlots(plot) do
		if plot.Slots[index].EggId == nil then
			return index
		end
	end
	return nil
end

local function characterScale(player)
	local character = player.Character
	if character then
		local ok, scale = pcall(function()
			return character:GetScale()
		end)
		if ok and type(scale) == "number" then
			return scale
		end
	end
	return 1
end

-- A CFrame on a base, raised so a scaled-up character doesn't start inside the floor.
local function standingCFrame(baseCFrame, player)
	return baseCFrame + Vector3.new(0, 3 * (characterScale(player) - 1), 0)
end

-- Game pass effects. The attributes are set only by MonetizationService on the
-- server (attributes a client sets on itself do not replicate), so they can be trusted.
local function cashMultiplier(player)
	local pass = (player and player:GetAttribute("Pass_DoubleCash") == true) and Config.DoubleCashMultiplier or 1
	local session = player and Session.Get(player)
	local base = Config.GetBaseLevel(session and session.BaseLevel or 1)
	return pass * (1 + base.CashBonus)
end

local function carrySpeedFor(player)
	local walkSpeed = Session.GetWalkSpeed(player)
	if player:GetAttribute("Pass_FastCarry") == true then
		return walkSpeed
	end
	return math.max(Config.CarryWalkSpeed, walkSpeed * Config.CarrySpeedFactor)
end

local function lockDurationFor(player)
	local duration = (player and player:GetAttribute("Pass_LongLock") == true)
			and Config.LockDuration * Config.LongLockMultiplier
		or Config.LockDuration
	local session = player and Session.Get(player)
	return duration + Config.GetBaseLevel(session and session.BaseLevel or 1).LockBonus
end

local function getIncome(plot)
	local total = 0
	for _, slot in plot.Slots do
		if slot.EggId and not slot.StolenBy then
			total += Config.GetEggIncome(slot.EggId, slot.Mutation, slot.Hatched)
		end
	end
	return total * cashMultiplier(plot.Owner)
end

local function updateIncomeAttribute(plot)
	if plot.Owner then
		plot.Owner:SetAttribute("Income", getIncome(plot))
	end
end

local LOCKED_COLOR = Color3.fromRGB(110, 110, 120)

local function updatePadLabel(plot, slotIndex)
	local slot = plot.Slots[slotIndex]
	local info = plot.Info.Slots[slotIndex]
	local label = info.PadLabel

	-- Pedestals above the base level are locked (grey) until the base is upgraded.
	local locked = plot.Owner ~= nil and slotIndex > unlockedSlots(plot) and slot.EggId == nil
	info.Rim.Color = locked and LOCKED_COLOR or info.RimColor
	info.Pad.Color = locked and LOCKED_COLOR or info.PadColor

	if locked then
		local needed = 1
		for level, upgrade in Config.BaseUpgrades do
			if upgrade.Slots >= slotIndex then
				needed = level
				break
			end
		end
		label.Text = "LOCKED (Lv " .. needed .. ")"
		label.TextColor3 = LOCKED_COLOR
	elseif slot.StolenBy then
		label.Text = "STOLEN!"
		label.TextColor3 = COLOR_BAD
	elseif slot.EggId then
		label.Text = Config.FormatCash(slot.Pending)
		label.TextColor3 = COLOR_GOOD
	else
		label.Text = ""
	end
end

local function updateLockLabel(plot, now)
	local label = plot.Info.LockLabel
	if not plot.Owner then
		label.Text = ""
	elseif plot.LockedUntil > 0 then
		label.Text = "LOCKED " .. math.max(0, math.ceil(plot.LockedUntil - now)) .. "s"
		label.TextColor3 = COLOR_BAD
	elseif now < plot.CooldownUntil then
		label.Text = "READY IN " .. math.ceil(plot.CooldownUntil - now) .. "s"
		label.TextColor3 = Color3.fromRGB(190, 190, 190)
	else
		label.Text = "STEP HERE TO LOCK"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function setBarrier(plot, locked)
	local barrier = plot.Info.Barrier
	barrier.CanCollide = locked
	barrier.Transparency = locked and 0 or 1
end

local function makePrompt(parent, kind, actionText, objectText, holdDuration, keyCode, ownerUserId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = kind .. "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration
	prompt.KeyboardKeyCode = keyCode
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	-- The client hides "Steal" on your own eggs and "Sell" on other people's eggs.
	-- Attributes are set before parenting so they replicate together with the prompt.
	prompt:SetAttribute("Kind", kind)
	prompt:SetAttribute("OwnerUserId", ownerUserId)
	prompt.Parent = parent
	return prompt
end

------------------------------------------------------------------------------
-- Pedestal rendering
------------------------------------------------------------------------------

local HATCH_COLOR = Color3.fromRGB(150, 220, 255)

local function formatTime(seconds)
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function renderSlot(plot, slotIndex)
	local slot = plot.Slots[slotIndex]
	if slot.Display then
		slot.Display:Destroy()
		slot.Display = nil
	end

	if slot.EggId and not slot.StolenBy and plot.Owner then
		local model, _, core = PetVisuals.CreateItem(slot.EggId, true, slot.Mutation, slot.Hatched)
		local displayName = Config.GetEggDisplayName(slot.EggId, slot.Mutation, slot.Hatched)
		if slot.Hatched then
			EggVisuals.AddInfo(model)
			slot.HatchLabel = nil
		else
			local _, hatchLabel = EggVisuals.AddInfo(model, "Hatches in " .. formatTime(slot.HatchLeft), HATCH_COLOR)
			slot.HatchLabel = hatchLabel
		end

		local ownerUserId = plot.Owner.UserId
		local stealPrompt =
			makePrompt(core, "Steal", "Steal", displayName, Config.StealHoldDuration, Enum.KeyCode.E, ownerUserId)
		stealPrompt.PromptButtonHoldBegan:Connect(function(player)
			holdStarts[player] = { Prompt = stealPrompt, Time = time() }
		end)
		stealPrompt.Triggered:Connect(function(player)
			-- The hold timer runs on the client, so make sure the player really held it.
			local hold = holdStarts[player]
			holdStarts[player] = nil
			if not hold or hold.Prompt ~= stealPrompt then
				return
			end
			if time() - hold.Time < Config.StealHoldDuration * HOLD_TOLERANCE then
				return
			end
			PlotService.TrySteal(player, plot, slotIndex)
		end)

		local sellPrompt = makePrompt(
			core,
			"Sell",
			"Sell for " .. Config.FormatCash(sellPrice(slot.EggId, slot.Mutation, slot.Hatched)),
			displayName,
			1,
			Enum.KeyCode.F,
			ownerUserId
		)
		sellPrompt.Triggered:Connect(function(player)
			PlotService.TrySell(player, plot, slotIndex)
		end)

		local baseCFrame = plot.Info.Slots[slotIndex].EggBaseCFrame
		model:PivotTo(baseCFrame * CFrame.new(0, (model:GetAttribute("BottomOffset") or core.Size.Y / 2) + 0.15, 0))
		model.Parent = plot.Info.EggsFolder
		slot.Display = model
	end

	updatePadLabel(plot, slotIndex)
end

-- hatched / hatchLeft are optional: a new egg starts with its full hatch time.
local function placeEgg(plot, slotIndex, eggId, mutationName, hatched, hatchLeft)
	local slot = plot.Slots[slotIndex]
	slot.EggId = eggId
	slot.Mutation = mutationName
	slot.Hatched = hatched == true
	slot.HatchLeft = hatchLeft or Config.GetHatchTime(eggId)
	slot.Pending = 0
	slot.StolenBy = nil
	renderSlot(plot, slotIndex)
	updateIncomeAttribute(plot)
end

local function collectSlot(plot, slotIndex)
	local slot = plot.Slots[slotIndex]
	if plot.Owner and slot.Pending > 0 then
		Session.AddCash(plot.Owner, slot.Pending)
		slot.Pending = 0
		updatePadLabel(plot, slotIndex)
	end
end

------------------------------------------------------------------------------
-- Locking
------------------------------------------------------------------------------

local function lockPlot(plot, now)
	local duration = lockDurationFor(plot.Owner)
	plot.LockedUntil = now + duration
	setBarrier(plot, true)
	updateLockLabel(plot, now)

	-- Push anyone who is not the owner out of the base so they are not trapped inside.
	for _, player in Players:GetPlayers() do
		if player ~= plot.Owner then
			local _, root = getLivingCharacter(player)
			if root and isInsidePlot(plot, root.Position) then
				local ejectCFrame = standingCFrame(plot.Info.EjectCFrame, player)
				player.Character:PivotTo(ejectCFrame)
				local carry = carriers[player]
				if carry then
					-- the server moved them, so this jump must not count as speed hacking
					carry.LastPos = ejectCFrame.Position
					carry.LastMoveTime = now
				end
				Remotes.Notify(player, "That base just got locked!", COLOR_ALERT)
			end
		end
	end

	Remotes.Notify(plot.Owner, "Base locked for " .. duration .. " seconds!", COLOR_GOOD)
end

local function unlockPlot(plot, now)
	plot.LockedUntil = 0
	plot.CooldownUntil = now + Config.LockCooldown
	setBarrier(plot, false)
	Remotes.Notify(plot.Owner, "Your base is unlocked! Thieves can get in.", COLOR_ALERT)
end

------------------------------------------------------------------------------
-- Carrying stolen eggs
------------------------------------------------------------------------------

local function carryOffset(thief, model)
	local bottom = model:GetAttribute("BottomOffset") or 1.7
	return CFrame.new(0, CARRY_HEIGHT * characterScale(thief) + bottom, 0)
end

local function createCarryModel(thief, eggId, mutationName, hatched, root)
	local model, _, core = PetVisuals.CreateItem(eggId, false, mutationName, hatched)
	model.Name = "Carried_" .. thief.Name
	EggVisuals.AddInfo(model, "STOLEN BY " .. string.upper(thief.DisplayName), COLOR_BAD)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end

	local offset = carryOffset(thief, model)
	model:PivotTo(root.CFrame * offset)

	local carryWeld = Instance.new("Weld")
	carryWeld.Name = "CarryWeld"
	carryWeld.Part0 = root
	carryWeld.Part1 = core
	carryWeld.C0 = offset
	carryWeld.C1 = core.PivotOffset -- keeps the model's pivot (not the body part) at the offset
	carryWeld.Parent = core

	model.Parent = carriedFolder
	return model, carryWeld
end

-- Clears the carry state without touching who owns the egg.
local function endCarry(thief)
	local carry = carriers[thief]
	if not carry then
		return nil
	end
	carriers[thief] = nil

	if carry.Model then
		carry.Model:Destroy()
	end

	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Session.GetWalkSpeed(thief)
	end
	thief:SetAttribute("CarryingEgg", "")
	return carry
end

-- The thief failed: the egg goes back onto the owner's pedestal.
function PlotService.CancelCarry(thief, message)
	local carry = endCarry(thief)
	if not carry then
		return
	end

	local plot = carry.FromPlot
	local slot = plot.Slots[carry.SlotIndex]
	if slot.StolenBy == thief then
		slot.StolenBy = nil
		renderSlot(plot, carry.SlotIndex)
		updateIncomeAttribute(plot)
		if plot.Owner and plot.Owner ~= thief then
			local eggName = Config.GetEggDisplayName(carry.EggId, carry.Mutation, carry.Hatched)
			Remotes.Notify(plot.Owner, "Your " .. eggName .. " is back on its pedestal!", COLOR_GOOD)
		end
	end

	if message then
		Remotes.Notify(thief, message, COLOR_BAD)
	end
end

-- The thief made it home: the egg moves to the thief's base.
local function deliver(thief)
	local carry = carriers[thief]
	local ownPlot = plotByPlayer[thief]
	if not carry or not ownPlot or shuttingDown then
		return
	end

	local victimPlot = carry.FromPlot
	local victimSlot = victimPlot.Slots[carry.SlotIndex]
	if victimSlot.StolenBy ~= thief or victimSlot.EggId ~= carry.EggId then
		-- State changed underneath us (should not happen); drop the carry safely.
		PlotService.CancelCarry(thief, nil)
		return
	end

	local freeIndex = findFreeSlot(ownPlot)
	if not freeIndex then
		PlotService.CancelCarry(thief, "Your base is full! The egg flew back to its owner.")
		return
	end

	local def = Config.GetEgg(carry.EggId)
	local eggName = Config.GetEggDisplayName(carry.EggId, carry.Mutation, carry.Hatched)
	local hatchLeft = victimSlot.HatchLeft
	local victim = victimPlot.Owner

	-- Remove from the victim
	victimSlot.EggId = nil
	victimSlot.Mutation = nil
	victimSlot.Hatched = false
	victimSlot.Pending = 0
	victimSlot.StolenBy = nil
	renderSlot(victimPlot, carry.SlotIndex)
	updateIncomeAttribute(victimPlot)

	-- Give to the thief
	endCarry(thief)
	placeEgg(ownPlot, freeIndex, carry.EggId, carry.Mutation, carry.Hatched, hatchLeft)
	Session.AddSteal(thief)

	Remotes.Notify(thief, "You stole the " .. eggName .. "!", COLOR_GOOD)
	if victim then
		Remotes.Notify(victim, thief.DisplayName .. " stole your " .. eggName .. "!", COLOR_BAD)
	end

	local rarity = Config.GetRarity(def.Rarity)
	if rarity.Index >= Config.AnnounceRarityIndex and victim then
		Remotes.NotifyAll(
			thief.DisplayName .. " stole a " .. def.Rarity .. " " .. eggName .. " from " .. victim.DisplayName .. "!",
			rarity.Color
		)
	end
end

------------------------------------------------------------------------------
-- Prompt actions
------------------------------------------------------------------------------

local function isWithinReach(player, position)
	local _, root = getLivingCharacter(player)
	return root ~= nil and (root.Position - position).Magnitude <= MAX_INTERACT_DISTANCE
end

function PlotService.TrySteal(thief, plot, slotIndex)
	if shuttingDown then
		return
	end
	local session = Session.Get(thief)
	if not session or not session.Loaded then
		return
	end
	if plot.Owner == nil or plot.Owner == thief then
		return
	end
	local ownerSession = Session.Get(plot.Owner)
	if not ownerSession or not ownerSession.Loaded then
		return
	end
	-- If only one of the two players can save, a steal would delete or duplicate the egg.
	if ownerSession.CanSave ~= session.CanSave then
		Remotes.Notify(thief, "Stealing is off for this player right now (their save didn't load).", COLOR_BAD)
		return
	end

	local slot = plot.Slots[slotIndex]
	if not slot or not slot.EggId or slot.StolenBy or not slot.Display then
		return
	end

	local humanoid, root = getLivingCharacter(thief)
	if not humanoid or not root then
		return
	end
	if not isWithinReach(thief, slot.Display:GetPivot().Position) then
		return
	end

	local thiefPlot = plotByPlayer[thief]
	if not thiefPlot then
		Remotes.Notify(thief, "You need a base before you can steal!", COLOR_BAD)
		return
	end
	if carriers[thief] then
		Remotes.Notify(thief, "You are already carrying an egg!", COLOR_BAD)
		return
	end
	if plot.LockedUntil > 0 then
		Remotes.Notify(thief, "This base is locked!", COLOR_BAD)
		return
	end
	if not findFreeSlot(thiefPlot) then
		Remotes.Notify(thief, "Your base is full! Sell an egg first.", COLOR_BAD)
		return
	end

	-- The owner keeps whatever cash the egg already made.
	collectSlot(plot, slotIndex)

	local eggId = slot.EggId
	local mutationName = slot.Mutation
	local hatched = slot.Hatched
	local eggName = Config.GetEggDisplayName(eggId, mutationName, hatched)
	slot.StolenBy = thief
	renderSlot(plot, slotIndex)
	updateIncomeAttribute(plot)

	-- Shortest legal time to walk home, used to reject teleporting thieves.
	local now = time()
	local carrySpeed = carrySpeedFor(thief)
	local homeOffset = thiefPlot.Info.CFrame.Position - root.Position
	local homeDistance = Vector3.new(homeOffset.X, 0, homeOffset.Z).Magnitude
	local walkDistance = math.max(0, homeDistance - thiefPlot.Info.HalfSize * 1.5)

	carriers[thief] = {
		FromPlot = plot,
		SlotIndex = slotIndex,
		EggId = eggId,
		Mutation = mutationName,
		Hatched = hatched,
		Model = nil,
		Weld = nil,
		StartTime = now,
		MinTime = walkDistance / (carrySpeed * MOVE_SLACK_MULTIPLIER),
		Speed = carrySpeed,
		LastPos = root.Position,
		LastMoveTime = now,
	}
	local carryModel, carryWeld = createCarryModel(thief, eggId, mutationName, hatched, root)
	carriers[thief].Model = carryModel
	carriers[thief].Weld = carryWeld
	humanoid.WalkSpeed = carrySpeed
	thief:SetAttribute("CarryingEgg", eggName)

	Remotes.Notify(thief, "You grabbed the " .. eggName .. "! Run back to your base!", COLOR_INFO)
	Remotes.Notify(plot.Owner, thief.DisplayName .. " is stealing your " .. eggName .. "! Bonk them with your bat!", COLOR_ALERT)
end

function PlotService.TrySell(player, plot, slotIndex)
	if shuttingDown or plot.Owner ~= player then
		return
	end
	local slot = plot.Slots[slotIndex]
	if not slot or not slot.EggId or slot.StolenBy or not slot.Display then
		return
	end
	if not isWithinReach(player, slot.Display:GetPivot().Position) then
		return
	end

	collectSlot(plot, slotIndex)

	local eggName = Config.GetEggDisplayName(slot.EggId, slot.Mutation, slot.Hatched)
	local amount = sellPrice(slot.EggId, slot.Mutation, slot.Hatched)
	Session.AddCash(player, amount)

	slot.EggId = nil
	slot.Mutation = nil
	slot.Hatched = false
	slot.Pending = 0
	renderSlot(plot, slotIndex)
	updateIncomeAttribute(plot)

	Remotes.Notify(player, "Sold " .. eggName .. " for " .. Config.FormatCash(amount), COLOR_GOOD)
end

-- Called by BatService when `victim` gets bonked by `attacker`.
function PlotService.OnPlayerBonked(victim, attacker)
	local carry = carriers[victim]
	if carry then
		PlotService.CancelCarry(victim, attacker.DisplayName .. " bonked you! You dropped the egg.")
		Remotes.Notify(attacker, "You bonked " .. victim.DisplayName .. " and saved the egg!", COLOR_GOOD)
	end
end

------------------------------------------------------------------------------
-- Public API used by the other services
------------------------------------------------------------------------------

function PlotService.GetPlot(player)
	return plotByPlayer[player]
end

function PlotService.FindFreeSlot(plot)
	return findFreeSlot(plot)
end

function PlotService.PlaceEgg(plot, slotIndex, eggId, mutationName, hatched, hatchLeft)
	placeEgg(plot, slotIndex, eggId, mutationName, hatched, hatchLeft)
end

function PlotService.IsCarrying(player)
	return carriers[player] ~= nil
end

-- Sets the humanoid's walk speed from the player's Speed stat (slower while carrying).
function PlotService.RefreshWalkSpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local carry = carriers[player]
	humanoid.WalkSpeed = carry and carry.Speed or Session.GetWalkSpeed(player)
end

-- Updates everything that depends on the base level: sign, pedestal locks, terminal text.
function PlotService.RefreshBase(plot)
	local info = plot.Info
	if plot.Owner then
		local level = levelOf(plot)
		info.SignLabel.Text = plot.Owner.DisplayName .. "'s Base  (Lv " .. level.Level .. ")"
		local nextLevel = Config.BaseUpgrades[level.Level + 1]
		if nextLevel then
			local perks = {}
			if nextLevel.Slots > level.Slots then
				table.insert(perks, (nextLevel.Slots - level.Slots) .. " more pedestals")
			end
			if nextLevel.CashBonus > level.CashBonus then
				table.insert(perks, "+" .. math.floor(nextLevel.CashBonus * 100 + 0.5) .. "% cash")
			end
			if nextLevel.LockBonus > level.LockBonus then
				table.insert(perks, "+" .. (nextLevel.LockBonus - level.LockBonus) .. "s lock")
			end
			info.UpgradeLabel.Text = "UPGRADE TO LV " .. nextLevel.Level .. ": " .. Config.FormatCash(nextLevel.Cost)
				.. "\n" .. table.concat(perks, ", ")
			info.UpgradePrompt.ObjectText = "Level " .. nextLevel.Level .. " (" .. Config.FormatCash(nextLevel.Cost) .. ")"
			info.UpgradePrompt.ActionText = "Upgrade Base"
		else
			info.UpgradeLabel.Text = "MAX LEVEL BASE!"
			info.UpgradePrompt.ObjectText = "Max level"
			info.UpgradePrompt.ActionText = "Maxed"
		end
		info.UpgradePrompt:SetAttribute("OwnerUserId", plot.Owner.UserId)
	else
		info.UpgradeLabel.Text = ""
		info.UpgradePrompt:SetAttribute("OwnerUserId", 0)
	end
	for slotIndex = 1, #plot.Slots do
		updatePadLabel(plot, slotIndex)
	end
	updateIncomeAttribute(plot)
end

function PlotService.TryUpgrade(player, plot)
	if shuttingDown or plot.Owner ~= player then
		return
	end
	local session = Session.Get(player)
	if not session or not session.Loaded then
		return
	end
	local nextLevel = Config.BaseUpgrades[session.BaseLevel + 1]
	if not nextLevel then
		Remotes.Notify(player, "Your base is already max level!", COLOR_INFO)
		return
	end
	if not Session.TrySpend(player, nextLevel.Cost) then
		Remotes.Notify(player, "You need " .. Config.FormatCash(nextLevel.Cost) .. " to upgrade your base!", COLOR_BAD)
		return
	end
	session.BaseLevel = nextLevel.Level
	PlotService.RefreshBase(plot)
	Remotes.Notify(player, "Base upgraded to level " .. nextLevel.Level .. "!", COLOR_GOOD)
end

-- Sum of the size bonuses of the hatched animals on the player's base.
function PlotService.GetPetSizeBonus(player)
	local plot = plotByPlayer[player]
	if not plot then
		return 0
	end
	local total = 0
	for _, slot in plot.Slots do
		if slot.EggId and slot.Hatched and not slot.StolenBy then
			total += Config.GetSizeBonus(slot.EggId, slot.Mutation, true)
		end
	end
	return total
end

-- Called after the player's size changes so a carried egg stays above their head.
function PlotService.UpdateCarryOffset(player)
	local carry = carriers[player]
	if carry and carry.Weld and carry.Model then
		carry.Weld.C0 = carryOffset(player, carry.Model)
	end
end

function PlotService.IsShuttingDown()
	return shuttingDown
end

-- Server is closing: freeze stealing/buying/selling and put every carried egg back,
-- so the final save snapshot can't be changed afterwards.
function PlotService.BeginShutdown()
	shuttingDown = true
	local thieves = {}
	for thief in carriers do
		table.insert(thieves, thief)
	end
	for _, thief in thieves do
		PlotService.CancelCarry(thief, nil)
	end
end

function PlotService.Forget(player)
	holdStarts[player] = nil
end

function PlotService.AssignPlot(player)
	local existing = plotByPlayer[player]
	if existing then
		return existing
	end

	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			plotByPlayer[player] = plot
			plot.Info.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.Info.Model:SetAttribute("OwnerName", player.DisplayName)
			updateLockLabel(plot, time())
			PlotService.RefreshBase(plot)
			player:SetAttribute("Income", 0)
			player:SetAttribute("CarryingEgg", "")
			return plot
		end
	end
	return nil
end

-- Puts saved eggs and animals back on the pedestals. eggs = { [slotIndex] = saved item }
function PlotService.LoadEggs(player, eggs)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	for slotIndex, saved in eggs do
		local slot = plot.Slots[slotIndex]
		local eggId, mutationName, hatched, hatchLeft = Config.DecodeEgg(saved)
		if slot and slot.EggId == nil and eggId then
			placeEgg(plot, slotIndex, eggId, mutationName, hatched, hatchLeft)
		end
	end
	PlotService.RefreshBase(plot)
	updateIncomeAttribute(plot)
end

-- Collision group + move the new character onto its base.
function PlotService.SetupCharacter(player, character)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end

	if collisionGroupsReady then
		local groupName = ownerGroupName(plot.Index)
		local function apply(instance)
			if instance:IsA("BasePart") then
				instance.CollisionGroup = groupName
			end
		end
		for _, descendant in character:GetDescendants() do
			apply(descendant)
		end
		character.DescendantAdded:Connect(apply)
	end

	task.spawn(function()
		-- wait a moment so the engine has finished placing the character at a spawn
		task.wait(0.15)
		if character.Parent and plotByPlayer[player] == plot then
			character:PivotTo(standingCFrame(plot.Info.SpawnCFrame, player))
		end
	end)
end

-- Must be called before saving when a player leaves: puts every egg that is
-- mid-steal back where it belongs so nothing is lost or duplicated.
function PlotService.PrepareForLeave(player)
	PlotService.CancelCarry(player, nil)

	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	local thieves = {}
	for thief, carry in carriers do
		if carry.FromPlot == plot then
			table.insert(thieves, thief)
		end
	end
	for _, thief in thieves do
		PlotService.CancelCarry(thief, "The owner left, so the egg went back!")
	end
end

-- Snapshot of what should be saved for this player.
function PlotService.BuildSaveData(player)
	local session = Session.Get(player)
	if not session then
		return nil
	end

	local eggs = {}
	local pending = 0
	local plot = plotByPlayer[player]
	if plot then
		for slotIndex, slot in plot.Slots do
			if slot.EggId then
				-- An egg that is being stolen right now still belongs to its owner.
				eggs[tostring(slotIndex)] = Config.EncodeEgg(slot.EggId, slot.Mutation, slot.Hatched, slot.HatchLeft)
				pending += slot.Pending
			end
		end
	elseif session.SavedEggs then
		-- No base yet (server was full): keep the eggs they already own untouched.
		for slotIndex, eggId in session.SavedEggs do
			eggs[tostring(slotIndex)] = eggId
		end
	end

	return {
		Cash = session.Cash + pending,
		Steals = session.Steals,
		Speed = session.Speed,
		BaseLevel = session.BaseLevel,
		Eggs = eggs,
	}
end

function PlotService.ReleasePlot(player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil

	-- Safety net in case PrepareForLeave was not called.
	local thieves = {}
	for thief, carry in carriers do
		if carry.FromPlot == plot then
			table.insert(thieves, thief)
		end
	end
	for _, thief in thieves do
		endCarry(thief)
	end

	plot.Owner = nil
	for slotIndex, slot in plot.Slots do
		if slot.Display then
			slot.Display:Destroy()
			slot.Display = nil
		end
		slot.EggId = nil
		slot.Mutation = nil
		slot.Hatched = false
		slot.HatchLeft = 0
		slot.HatchLabel = nil
		slot.Pending = 0
		slot.StolenBy = nil
		updatePadLabel(plot, slotIndex)
	end

	plot.LockedUntil = 0
	plot.CooldownUntil = 0
	setBarrier(plot, false)
	updateLockLabel(plot, time())
	plot.Info.SignLabel.Text = "Empty Base"
	plot.Info.Model:SetAttribute("OwnerUserId", 0)
	plot.Info.Model:SetAttribute("OwnerName", "")
	PlotService.RefreshBase(plot)
end

------------------------------------------------------------------------------
-- Game loops
------------------------------------------------------------------------------

-- Runs once per second: income, lock timers and labels.
local function tickSecond()
	local now = time()
	for _, plot in plots do
		if plot.Owner then
			for slotIndex, slot in plot.Slots do
				if slot.EggId and not slot.StolenBy then
					slot.Pending += Config.GetEggIncome(slot.EggId, slot.Mutation, slot.Hatched) * cashMultiplier(plot.Owner)

					-- Eggs hatch while they sit on a base (the timer pauses while one is being stolen).
					if not slot.Hatched then
						slot.HatchLeft -= 1
						if slot.HatchLeft <= 0 then
							slot.Hatched = true
							slot.HatchLeft = 0
							renderSlot(plot, slotIndex)
							local def = Config.GetEgg(slot.EggId)
							local rarity = Config.GetRarity(def.Rarity)
							Remotes.Notify(
								plot.Owner,
								"Your " .. Config.GetEggDisplayName(slot.EggId, slot.Mutation, false) .. " hatched into a "
									.. Config.GetEggDisplayName(slot.EggId, slot.Mutation, true) .. "!",
								rarity.Color
							)
						elseif slot.HatchLabel then
							slot.HatchLabel.Text = "Hatches in " .. formatTime(slot.HatchLeft)
						end
					end
				end
				updatePadLabel(plot, slotIndex)
			end
			updateIncomeAttribute(plot)
		end

		if plot.LockedUntil > 0 and now >= plot.LockedUntil then
			unlockPlot(plot, now)
		end
		updateLockLabel(plot, now)
	end
end

-- Runs 10 times per second: deliveries and pads.
local function tickFast()
	-- Thieves reaching their own base
	local thieves = {}
	for thief in carriers do
		table.insert(thieves, thief)
	end
	for _, thief in thieves do
		local carry = carriers[thief]
		if carry then
			local _, root = getLivingCharacter(thief)
			if not root then
				PlotService.CancelCarry(thief, "You dropped the egg!")
			else
				local now = time()
				local position = root.Position
				local moved = Vector3.new(position.X - carry.LastPos.X, 0, position.Z - carry.LastPos.Z).Magnitude
				-- Measure from the last time they moved, so a laggy player whose
				-- position arrives in one burst isn't punished.
				local allowed = carry.Speed * (now - carry.LastMoveTime) * MOVE_SLACK_MULTIPLIER
					+ MOVE_SLACK_STUDS
				if moved > allowed then
					PlotService.CancelCarry(thief, "You moved too fast and dropped the egg!")
				else
					if moved > 0.01 then
						carry.LastPos = position
						carry.LastMoveTime = now
					end
					local ownPlot = plotByPlayer[thief]
					if
						ownPlot
						and now - carry.StartTime >= carry.MinTime
						and isInsidePlot(ownPlot, position)
					then
						deliver(thief)
					end
				end
			end
		end
	end

	-- Owners standing on their cash pads / lock pad
	local now = time()
	for _, plot in plots do
		local owner = plot.Owner
		if owner then
			local _, root = getLivingCharacter(owner)
			if root then
				local localPos = plot.Info.CFrame:PointToObjectSpace(root.Position)
				if localPos.Y > -2 and localPos.Y < 10 then
					for slotIndex, slotInfo in plot.Info.Slots do
						local padPos = slotInfo.PadLocal
						if math.abs(localPos.X - padPos.X) <= 2.6 and math.abs(localPos.Z - padPos.Z) <= 2.6 then
							collectSlot(plot, slotIndex)
						end
					end

					local lockPadPos = plot.Info.LockPadLocal
					if math.abs(localPos.X - lockPadPos.X) <= 3.6 and math.abs(localPos.Z - lockPadPos.Z) <= 2.6 then
						if plot.LockedUntil == 0 and now >= plot.CooldownUntil then
							lockPlot(plot, now)
						end
					end
				end
			end
		end
	end
end

local function runLoop(interval, step, name)
	task.spawn(function()
		while true do
			task.wait(interval)
			local ok, err = pcall(step)
			if not ok then
				warn("[StealTheAuraEgg] " .. name .. " error: " .. tostring(err))
			end
		end
	end)
end

function PlotService.Init(plotInfos)
	for index, info in plotInfos do
		local plot = {
			Index = index,
			Info = info,
			Owner = nil,
			LockedUntil = 0,
			CooldownUntil = 0,
			Slots = {},
		}
		for slotIndex = 1, Config.SlotsPerPlot do
			plot.Slots[slotIndex] = {
				EggId = nil,
				Mutation = nil,
				Hatched = false,
				HatchLeft = 0,
				HatchLabel = nil,
				Pending = 0,
				StolenBy = nil,
				Display = nil,
			}
		end
		plots[index] = plot
	end

	-- Collision groups let the owner walk through their own lock barrier.
	local ok, err = pcall(function()
		for index = 1, #plots do
			for _, groupName in { ownerGroupName(index), barrierGroupName(index) } do
				if not PhysicsService:IsCollisionGroupRegistered(groupName) then
					PhysicsService:RegisterCollisionGroup(groupName)
				end
			end
			PhysicsService:CollisionGroupSetCollidable(barrierGroupName(index), ownerGroupName(index), false)
		end
	end)
	if ok then
		collisionGroupsReady = true
		for index, plot in plots do
			plot.Info.Barrier.CollisionGroup = barrierGroupName(index)
		end
	else
		warn("[StealTheAuraEgg] Could not set up collision groups (owners will be blocked by their own lock): " .. tostring(err))
	end

	-- Upgrade terminal in every base (only the owner sees the prompt)
	for _, plot in plots do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UpgradePrompt"
		prompt.ActionText = "Upgrade Base"
		prompt.ObjectText = ""
		prompt.HoldDuration = 0.5
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Kind", "Upgrade")
		prompt:SetAttribute("OwnerUserId", 0)
		prompt.Triggered:Connect(function(player)
			if isWithinReach(player, plot.Info.UpgradeTerminal.Position) then
				PlotService.TryUpgrade(player, plot)
			end
		end)
		prompt.Parent = plot.Info.UpgradeTerminal
		plot.Info.UpgradePrompt = prompt
		PlotService.RefreshBase(plot)
	end

	runLoop(1, tickSecond, "Income loop")
	runLoop(0.1, tickFast, "Pad loop")
end

return PlotService
