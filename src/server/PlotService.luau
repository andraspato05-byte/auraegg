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
local carriers = {} -- [Player] = { FromPlot, SlotIndex, EggId, Model, StartTime, MinTime, LastPos, LastMoveTime }
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

local function sellPrice(def)
	return math.floor(def.Price * Config.SellMultiplier)
end

local function findFreeSlot(plot)
	for index, slot in plot.Slots do
		if slot.EggId == nil then
			return index
		end
	end
	return nil
end

-- Game pass effects. The attributes are set only by MonetizationService on the
-- server (attributes a client sets on itself do not replicate), so they can be trusted.
local function cashMultiplier(player)
	return (player and player:GetAttribute("Pass_DoubleCash") == true) and Config.DoubleCashMultiplier or 1
end

local function carrySpeedFor(player)
	local walkSpeed = Session.GetWalkSpeed(player)
	if player:GetAttribute("Pass_FastCarry") == true then
		return walkSpeed
	end
	return math.max(Config.CarryWalkSpeed, walkSpeed * Config.CarrySpeedFactor)
end

local function lockDurationFor(player)
	return (player and player:GetAttribute("Pass_LongLock") == true) and Config.LockDuration * Config.LongLockMultiplier
		or Config.LockDuration
end

local function getIncome(plot)
	local total = 0
	for _, slot in plot.Slots do
		if slot.EggId and not slot.StolenBy then
			local def = Config.GetEgg(slot.EggId)
			if def then
				total += def.Income
			end
		end
	end
	return total * cashMultiplier(plot.Owner)
end

local function updateIncomeAttribute(plot)
	if plot.Owner then
		plot.Owner:SetAttribute("Income", getIncome(plot))
	end
end

local function updatePadLabel(plot, slotIndex)
	local slot = plot.Slots[slotIndex]
	local label = plot.Info.Slots[slotIndex].PadLabel
	if slot.StolenBy then
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

local function renderSlot(plot, slotIndex)
	local slot = plot.Slots[slotIndex]
	if slot.Display then
		slot.Display:Destroy()
		slot.Display = nil
	end

	if slot.EggId and not slot.StolenBy and plot.Owner then
		local model, def, core = EggVisuals.Create(slot.EggId, true)
		EggVisuals.AddInfo(model)

		local ownerUserId = plot.Owner.UserId
		local stealPrompt =
			makePrompt(core, "Steal", "Steal", def.Name, Config.StealHoldDuration, Enum.KeyCode.E, ownerUserId)
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
			"Sell for " .. Config.FormatCash(sellPrice(def)),
			def.Name,
			1,
			Enum.KeyCode.F,
			ownerUserId
		)
		sellPrompt.Triggered:Connect(function(player)
			PlotService.TrySell(player, plot, slotIndex)
		end)

		local baseCFrame = plot.Info.Slots[slotIndex].EggBaseCFrame
		model:PivotTo(baseCFrame * CFrame.new(0, core.Size.Y / 2 + 0.15, 0))
		model.Parent = plot.Info.EggsFolder
		slot.Display = model
	end

	updatePadLabel(plot, slotIndex)
end

local function placeEgg(plot, slotIndex, eggId)
	local slot = plot.Slots[slotIndex]
	slot.EggId = eggId
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
				player.Character:PivotTo(plot.Info.EjectCFrame)
				local carry = carriers[player]
				if carry then
					-- the server moved them, so this jump must not count as speed hacking
					carry.LastPos = plot.Info.EjectCFrame.Position
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

local function createCarryModel(thief, eggId, root)
	local model, _, core = EggVisuals.Create(eggId, false)
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

	local offset = CFrame.new(0, CARRY_HEIGHT + core.Size.Y / 2, 0)
	model:PivotTo(root.CFrame * offset)

	local carryWeld = Instance.new("Weld")
	carryWeld.Name = "CarryWeld"
	carryWeld.Part0 = root
	carryWeld.Part1 = core
	carryWeld.C0 = offset
	carryWeld.C1 = CFrame.new()
	carryWeld.Parent = core

	model.Parent = carriedFolder
	return model
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
			local def = Config.GetEgg(carry.EggId)
			Remotes.Notify(plot.Owner, "Your " .. (def and def.Name or "egg") .. " is back on its pedestal!", COLOR_GOOD)
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
	local victim = victimPlot.Owner

	-- Remove from the victim
	victimSlot.EggId = nil
	victimSlot.Pending = 0
	victimSlot.StolenBy = nil
	renderSlot(victimPlot, carry.SlotIndex)
	updateIncomeAttribute(victimPlot)

	-- Give to the thief
	endCarry(thief)
	placeEgg(ownPlot, freeIndex, carry.EggId)
	Session.AddSteal(thief)

	Remotes.Notify(thief, "You stole the " .. def.Name .. "!", COLOR_GOOD)
	if victim then
		Remotes.Notify(victim, thief.DisplayName .. " stole your " .. def.Name .. "!", COLOR_BAD)
	end

	local rarity = Config.GetRarity(def.Rarity)
	if rarity.Index >= Config.AnnounceRarityIndex and victim then
		Remotes.NotifyAll(
			thief.DisplayName .. " stole a " .. def.Rarity .. " " .. def.Name .. " from " .. victim.DisplayName .. "!",
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
	local def = Config.GetEgg(eggId)
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
		Model = createCarryModel(thief, eggId, root),
		StartTime = now,
		MinTime = walkDistance / (carrySpeed * MOVE_SLACK_MULTIPLIER),
		Speed = carrySpeed,
		LastPos = root.Position,
		LastMoveTime = now,
	}
	humanoid.WalkSpeed = carrySpeed
	thief:SetAttribute("CarryingEgg", def.Name)

	Remotes.Notify(thief, "You grabbed the " .. def.Name .. "! Run back to your base!", COLOR_INFO)
	Remotes.Notify(plot.Owner, thief.DisplayName .. " is stealing your " .. def.Name .. "! Bonk them with your bat!", COLOR_ALERT)
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

	local def = Config.GetEgg(slot.EggId)
	local amount = sellPrice(def)
	Session.AddCash(player, amount)

	slot.EggId = nil
	slot.Pending = 0
	renderSlot(plot, slotIndex)
	updateIncomeAttribute(plot)

	Remotes.Notify(player, "Sold " .. def.Name .. " for " .. Config.FormatCash(amount), COLOR_GOOD)
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

function PlotService.PlaceEgg(plot, slotIndex, eggId)
	placeEgg(plot, slotIndex, eggId)
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
			plot.Info.SignLabel.Text = player.DisplayName .. "'s Base"
			updateLockLabel(plot, time())
			player:SetAttribute("Income", 0)
			player:SetAttribute("CarryingEgg", "")
			return plot
		end
	end
	return nil
end

-- Puts saved eggs back on the pedestals. eggs = { [slotIndex] = eggId }
function PlotService.LoadEggs(player, eggs)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	for slotIndex, eggId in eggs do
		local slot = plot.Slots[slotIndex]
		if slot and slot.EggId == nil and Config.GetEgg(eggId) then
			placeEgg(plot, slotIndex, eggId)
		end
	end
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
			character:PivotTo(plot.Info.SpawnCFrame)
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
				eggs[tostring(slotIndex)] = slot.EggId
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
					local def = Config.GetEgg(slot.EggId)
					if def then
						slot.Pending += def.Income * cashMultiplier(plot.Owner)
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
						local pad = slotInfo.PadLocal
						if math.abs(localPos.X - pad.X) <= 2.6 and math.abs(localPos.Z - pad.Z) <= 2.6 then
							collectSlot(plot, slotIndex)
						end
					end

					local lockPad = plot.Info.LockPadLocal
					if math.abs(localPos.X - lockPad.X) <= 3.6 and math.abs(localPos.Z - lockPad.Z) <= 2.6 then
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
			plot.Slots[slotIndex] = { EggId = nil, Pending = 0, StolenBy = nil, Display = nil }
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

	runLoop(1, tickSecond, "Income loop")
	runLoop(0.1, tickFast, "Pad loop")
end

return PlotService
