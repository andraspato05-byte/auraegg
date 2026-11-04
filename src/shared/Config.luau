--[[
	Config (ReplicatedStorage.Shared.Config)

	Every tunable setting for Steal the Aura Egg lives here, plus the full
	list of Aura Eggs. Shared by the server and the client.
]]

local Config = {}

Config.GameName = "Steal the Aura Egg"

-- Economy -------------------------------------------------------------------
Config.StartingCash = 100
Config.SellMultiplier = 0.5 -- selling an egg refunds this fraction of its price

-- Bases ---------------------------------------------------------------------
Config.MaxPlots = 8 -- the map has room for exactly 8 bases (set Max Players to 8)
Config.SlotsPerPlot = 10 -- the base layout has exactly 10 pedestals
Config.LockDuration = 60 -- seconds a base stays locked
Config.LockCooldown = 10 -- seconds after a lock ends before it can be locked again

-- Conveyor belt -------------------------------------------------------------
Config.BeltSpeed = 7 -- studs per second
Config.BeltSpawnInterval = 2.5 -- seconds between new eggs
Config.BeltMaxEggs = 40
Config.AnnounceRarityIndex = 5 -- announce eggs of this rarity index or higher (5 = Legendary)

-- Stealing ------------------------------------------------------------------
Config.StealHoldDuration = 1.5
Config.CarryWalkSpeed = 11
Config.NormalWalkSpeed = 16

-- AURA STORM event -------------------------------------------------------------
-- A purple lightning storm. While it lasts, eggs come out of the machine faster,
-- rare eggs are much more likely, and some eggs come out Storm-charged.
Config.Event = {
	Name = "AURA STORM",
	FirstDelay = 180, -- seconds after the server starts until the first storm
	Interval = 900, -- seconds between the start of one storm and the next
	Duration = 240, -- seconds a storm lasts
	WarningTime = 30, -- announce this many seconds before it starts
	SpawnIntervalMultiplier = 0.5, -- eggs come out twice as fast
	RareLuck = 3, -- Rare and better eggs are 3x more likely
	StormChance = 0.3, -- chance an egg comes out Storm-charged
}

-- Mutations are saved with the egg ("DragonAura:Storm") and change its value.
Config.Mutations = {
	Storm = {
		Name = "Storm",
		IncomeMultiplier = 3,
		PriceMultiplier = 2.5,
		Color = Color3.fromRGB(110, 200, 255),
	},
}

-- Animals (hatched eggs) ------------------------------------------------------
Config.PetIncomeMultiplier = 2 -- a hatched animal earns 2x what its egg did
Config.PetValueMultiplier = 2 -- and is worth 2x when sold
Config.MutationSizeMultiplier = 1.5 -- Storm animals make you grow 1.5x more

-- Size + MOG -------------------------------------------------------------------
-- Every hatched animal on your base makes you bigger (see Rarities.SizeBonus).
-- Stand next to a smaller player and press MOG (or G) to send them flying.
Config.MaxScale = 2.5 -- biggest a player can get (2.5x normal size)
Config.MogRange = 12 -- studs (grows with your size)
Config.MogMinLead = 0.1 -- you must be at least this much bigger than the target
Config.MogCooldown = 8 -- seconds between your MOGs
Config.MogImmunity = 6 -- seconds a mogged player can't be mogged again
Config.MogRewardSeconds = 5 -- reward = 5 seconds of the target's income...
Config.MogMinReward = 25 -- ...but at least this much

-- Base upgrades ----------------------------------------------------------------
-- Use the UPGRADE terminal inside your base. Slots = unlocked pedestals.
-- CashBonus 0.25 = +25% cash from everything on your base. LockBonus = extra lock seconds.
Config.BaseUpgrades = {
	{ Level = 1, Cost = 0, Slots = 4, CashBonus = 0, LockBonus = 0 },
	{ Level = 2, Cost = 300, Slots = 6, CashBonus = 0, LockBonus = 0 },
	{ Level = 3, Cost = 3000, Slots = 8, CashBonus = 0, LockBonus = 0 },
	{ Level = 4, Cost = 30000, Slots = 10, CashBonus = 0, LockBonus = 0 },
	{ Level = 5, Cost = 300000, Slots = 10, CashBonus = 0.25, LockBonus = 0 },
	{ Level = 6, Cost = 3000000, Slots = 10, CashBonus = 0.5, LockBonus = 30 },
	{ Level = 7, Cost = 30000000, Slots = 10, CashBonus = 1, LockBonus = 30 },
}

-- Speed + treadmills ----------------------------------------------------------
-- Running on a treadmill in the gym earns Speed points.
-- Walk speed = NormalWalkSpeed + Speed * SpeedPerPoint (max MaxSpeed points).
Config.SpeedPerPoint = 0.05 -- 20 Speed = +1 walk speed
Config.MaxSpeed = 500 -- 500 Speed = 16 + 25 = 41 walk speed
Config.CarrySpeedFactor = 0.7 -- carrying an egg slows you to 70% (never below CarryWalkSpeed)
-- PushSpeed = how fast the belt pushes you back (studs/s). You need to run faster than it.
Config.Treadmills = {
	{ Tier = 1, Rate = 1, Required = 0, PushSpeed = 6 },
	{ Tier = 2, Rate = 2, Required = 100, PushSpeed = 12 },
	{ Tier = 3, Rate = 4, Required = 250, PushSpeed = 18 },
	{ Tier = 4, Rate = 8, Required = 400, PushSpeed = 24 },
}

function Config.GetWalkSpeed(speedPoints)
	local points = math.clamp(math.floor(speedPoints or 0), 0, Config.MaxSpeed)
	return Config.NormalWalkSpeed + points * Config.SpeedPerPoint
end

-- Bat -----------------------------------------------------------------------
Config.BatName = "Aura Bat"
Config.BatCooldown = 0.9
Config.BatRange = 9
Config.BatKnockback = 55

-- Saving --------------------------------------------------------------------
Config.DataStoreName = "StealTheAuraEgg_v1"
Config.AutosaveInterval = 120

-- Robux shop -------------------------------------------------------------------
-- Create these on the Creator Dashboard (create.roblox.com > your game >
-- Monetization > Passes / Developer Products) and paste each ID below.
-- An item with Id = 0 shows as "Not set up" in the shop and can't be bought.
Config.GamePasses = {
	{ Key = "DoubleCash", Id = 0, Name = "2x Cash", Description = "Every egg on your base makes double cash." },
	{ Key = "FastCarry", Id = 0, Name = "Speedy Thief", Description = "No slowdown while carrying a stolen egg." },
	{ Key = "LongLock", Id = 0, Name = "Mega Lock", Description = "Your base stays locked twice as long." },
}

Config.Products = {
	{ Key = "CashSmall", Id = 0, Name = "Pile of Cash", Cash = 10000 },
	{ Key = "CashMedium", Id = 0, Name = "Bag of Cash", Cash = 250000 },
	{ Key = "CashLarge", Id = 0, Name = "Vault of Cash", Cash = 5000000 },
	{ Key = "LuckyEgg", Id = 0, Name = "Lucky Aura Egg", LuckyEgg = true },
}

Config.LuckyEggMinRarity = 5 -- Lucky Aura Egg gives Legendary (5) or better
Config.DoubleCashMultiplier = 2
Config.LongLockMultiplier = 2

-- Rarities (Weight = how often this rarity appears on the belt) -------------
-- HatchTime = seconds on your base before the egg hatches into its animal.
-- SizeBonus = how much bigger each hatched animal makes its owner (1 = normal size).
Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 200), Weight = 50, HatchTime = 60, SizeBonus = 0.04 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 225, 100), Weight = 26, HatchTime = 90, SizeBonus = 0.06 },
	{ Name = "Rare", Color = Color3.fromRGB(60, 150, 255), Weight = 13, HatchTime = 120, SizeBonus = 0.09 },
	{ Name = "Epic", Color = Color3.fromRGB(180, 85, 255), Weight = 6.5, HatchTime = 180, SizeBonus = 0.13 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 195, 40), Weight = 3, HatchTime = 240, SizeBonus = 0.18 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 115), Weight = 1.2, HatchTime = 300, SizeBonus = 0.25 },
	{ Name = "Secret", Color = Color3.fromRGB(255, 255, 255), Weight = 0.3, HatchTime = 420, SizeBonus = 0.35 }, -- rainbow
}

-- Aura Eggs -----------------------------------------------------------------
-- Price = cost on the belt, Income = cash per second while it sits on your base
-- PetName / PetShape = the animal that hatches out of it (shapes: Bunny, Bear, Frog, Cat, Fox, Bird, Dragon)
Config.Eggs = {
	-- Common
	{ Id = "DustyAura", Name = "Dusty Aura Egg", Rarity = "Common", Price = 25, Income = 1, PetName = "Dust Bunny", PetShape = "Bunny",
		EggColor = Color3.fromRGB(214, 200, 175), AuraColor = Color3.fromRGB(255, 245, 220) },
	{ Id = "PebbleAura", Name = "Pebble Aura Egg", Rarity = "Common", Price = 40, Income = 2, PetName = "Pebble Bear", PetShape = "Bear",
		EggColor = Color3.fromRGB(150, 150, 155), AuraColor = Color3.fromRGB(225, 225, 230) },
	{ Id = "LeafyAura", Name = "Leafy Aura Egg", Rarity = "Common", Price = 60, Income = 3, PetName = "Leaf Frog", PetShape = "Frog",
		EggColor = Color3.fromRGB(110, 190, 90), AuraColor = Color3.fromRGB(180, 255, 160) },

	-- Uncommon
	{ Id = "BubbleAura", Name = "Bubble Aura Egg", Rarity = "Uncommon", Price = 150, Income = 6, PetName = "Bubble Cat", PetShape = "Cat",
		EggColor = Color3.fromRGB(140, 210, 255), AuraColor = Color3.fromRGB(205, 240, 255) },
	{ Id = "EmberAura", Name = "Ember Aura Egg", Rarity = "Uncommon", Price = 250, Income = 10, PetName = "Ember Fox", PetShape = "Fox",
		EggColor = Color3.fromRGB(240, 110, 50), AuraColor = Color3.fromRGB(255, 190, 90) },
	{ Id = "MintyAura", Name = "Minty Aura Egg", Rarity = "Uncommon", Price = 400, Income = 15, PetName = "Mint Bunny", PetShape = "Bunny",
		EggColor = Color3.fromRGB(150, 245, 200), AuraColor = Color3.fromRGB(110, 255, 190) },

	-- Rare
	{ Id = "FrostAura", Name = "Frost Aura Egg", Rarity = "Rare", Price = 1000, Income = 35, PetName = "Frost Bear", PetShape = "Bear",
		EggColor = Color3.fromRGB(200, 235, 255), AuraColor = Color3.fromRGB(120, 210, 255) },
	{ Id = "ThunderAura", Name = "Thunder Aura Egg", Rarity = "Rare", Price = 1800, Income = 60, PetName = "Thunder Bird", PetShape = "Bird",
		EggColor = Color3.fromRGB(255, 230, 70), AuraColor = Color3.fromRGB(255, 255, 140) },
	{ Id = "OceanAura", Name = "Ocean Aura Egg", Rarity = "Rare", Price = 3000, Income = 95, PetName = "Tide Frog", PetShape = "Frog",
		EggColor = Color3.fromRGB(30, 110, 200), AuraColor = Color3.fromRGB(60, 200, 255) },

	-- Epic
	{ Id = "ShadowAura", Name = "Shadow Aura Egg", Rarity = "Epic", Price = 8000, Income = 230, PetName = "Shadow Cat", PetShape = "Cat",
		EggColor = Color3.fromRGB(45, 35, 60), AuraColor = Color3.fromRGB(150, 70, 255) },
	{ Id = "CrystalAura", Name = "Crystal Aura Egg", Rarity = "Epic", Price = 14000, Income = 380, PetName = "Crystal Fox", PetShape = "Fox",
		EggColor = Color3.fromRGB(235, 170, 255), AuraColor = Color3.fromRGB(255, 140, 255) },
	{ Id = "VoidAura", Name = "Void Aura Egg", Rarity = "Epic", Price = 25000, Income = 650, PetName = "Void Raven", PetShape = "Bird",
		EggColor = Color3.fromRGB(15, 10, 25), AuraColor = Color3.fromRGB(110, 40, 200) },

	-- Legendary
	{ Id = "SolarAura", Name = "Solar Aura Egg", Rarity = "Legendary", Price = 60000, Income = 1500, PetName = "Solar Lion", PetShape = "Cat",
		EggColor = Color3.fromRGB(255, 170, 30), AuraColor = Color3.fromRGB(255, 220, 80) },
	{ Id = "DragonAura", Name = "Dragon Aura Egg", Rarity = "Legendary", Price = 110000, Income = 2600, PetName = "Fire Dragon", PetShape = "Dragon",
		EggColor = Color3.fromRGB(170, 25, 25), AuraColor = Color3.fromRGB(255, 90, 30) },
	{ Id = "CosmicAura", Name = "Cosmic Aura Egg", Rarity = "Legendary", Price = 200000, Income = 4500, PetName = "Cosmic Fox", PetShape = "Fox",
		EggColor = Color3.fromRGB(40, 30, 110), AuraColor = Color3.fromRGB(120, 160, 255) },

	-- Mythic
	{ Id = "PhoenixAura", Name = "Phoenix Aura Egg", Rarity = "Mythic", Price = 600000, Income = 12000, PetName = "Phoenix", PetShape = "Bird",
		EggColor = Color3.fromRGB(255, 90, 20), AuraColor = Color3.fromRGB(255, 200, 40) },
	{ Id = "GalaxyAura", Name = "Galaxy Aura Egg", Rarity = "Mythic", Price = 1200000, Income = 22000, PetName = "Galaxy Dragon", PetShape = "Dragon",
		EggColor = Color3.fromRGB(70, 20, 120), AuraColor = Color3.fromRGB(255, 80, 200) },

	-- Secret
	{ Id = "RainbowAura", Name = "Rainbow Aura Egg", Rarity = "Secret", Price = 5000000, Income = 80000, PetName = "Rainbow Dragon", PetShape = "Dragon",
		EggColor = Color3.fromRGB(255, 255, 255), AuraColor = Color3.fromRGB(255, 255, 255) },
	{ Id = "OmegaAura", Name = "Omega Aura Egg", Rarity = "Secret", Price = 15000000, Income = 220000, PetName = "Omega Dragon King", PetShape = "Dragon",
		EggColor = Color3.fromRGB(10, 10, 10), AuraColor = Color3.fromRGB(255, 255, 255) },
}

-- Lookup tables ---------------------------------------------------------------
Config.RarityByName = {}
for index, rarity in Config.Rarities do
	rarity.Index = index
	Config.RarityByName[rarity.Name] = rarity
end

Config.EggById = {}
Config.EggsByRarity = {}
for _, egg in Config.Eggs do
	assert(Config.RarityByName[egg.Rarity], "Egg " .. egg.Id .. " has an unknown rarity: " .. egg.Rarity)
	assert(Config.EggById[egg.Id] == nil, "Duplicate egg id: " .. egg.Id)
	Config.EggById[egg.Id] = egg
	local list = Config.EggsByRarity[egg.Rarity]
	if not list then
		list = {}
		Config.EggsByRarity[egg.Rarity] = list
	end
	table.insert(list, egg)
end

function Config.GetEgg(eggId)
	return Config.EggById[eggId]
end

function Config.GetRarity(rarityName)
	return Config.RarityByName[rarityName]
end

-- Picks a random egg id using the rarity weights.
-- minRarityIndex (optional) skips rarities below it, e.g. 5 = Legendary or better.
-- rareLuck (optional) multiplies the weight of Rare (index 3) and better.
function Config.RollEggId(rng, minRarityIndex, rareLuck)
	local minIndex = minRarityIndex or 1
	local luck = rareLuck or 1
	local function weightOf(rarity)
		return rarity.Index >= 3 and rarity.Weight * luck or rarity.Weight
	end

	local total = 0
	for _, rarity in Config.Rarities do
		if rarity.Index >= minIndex and Config.EggsByRarity[rarity.Name] then
			total += weightOf(rarity)
		end
	end

	local roll = rng:NextNumber() * total
	for _, rarity in Config.Rarities do
		local list = Config.EggsByRarity[rarity.Name]
		if rarity.Index >= minIndex and list then
			roll -= weightOf(rarity)
			if roll <= 0 then
				return list[rng:NextInteger(1, #list)].Id
			end
		end
	end

	-- floating point leftovers: return the last eligible egg
	for index = #Config.Eggs, 1, -1 do
		local egg = Config.Eggs[index]
		if Config.GetRarity(egg.Rarity).Index >= minIndex then
			return egg.Id
		end
	end
	return Config.Eggs[1].Id
end

-- Egg / animal helpers -----------------------------------------------------------
-- Every item on a pedestal is an egg id, an optional mutation (e.g. "Storm") and
-- whether it has hatched into its animal yet.

function Config.GetMutation(mutationName)
	if mutationName == nil then
		return nil
	end
	return Config.Mutations[mutationName]
end

function Config.GetHatchTime(eggId)
	local def = Config.GetEgg(eggId)
	if not def then
		return 60
	end
	return Config.GetRarity(def.Rarity).HatchTime
end

function Config.GetEggIncome(eggId, mutationName, hatched)
	local def = Config.GetEgg(eggId)
	if not def then
		return 0
	end
	local mutation = Config.GetMutation(mutationName)
	local income = def.Income * (mutation and mutation.IncomeMultiplier or 1)
	if hatched then
		income *= Config.PetIncomeMultiplier
	end
	return income
end

function Config.GetEggPrice(eggId, mutationName, hatched)
	local def = Config.GetEgg(eggId)
	if not def then
		return 0
	end
	local mutation = Config.GetMutation(mutationName)
	local price = def.Price * (mutation and mutation.PriceMultiplier or 1)
	if hatched then
		price *= Config.PetValueMultiplier
	end
	return math.floor(price)
end

function Config.GetEggDisplayName(eggId, mutationName, hatched)
	local def = Config.GetEgg(eggId)
	local name = def and (hatched and def.PetName or def.Name) or tostring(eggId)
	local mutation = Config.GetMutation(mutationName)
	if mutation then
		return mutation.Name .. " " .. name
	end
	return name
end

-- How much bigger a hatched animal makes its owner (eggs give nothing).
function Config.GetSizeBonus(eggId, mutationName, hatched)
	local def = Config.GetEgg(eggId)
	if not def or not hatched then
		return 0
	end
	local bonus = Config.GetRarity(def.Rarity).SizeBonus
	if Config.GetMutation(mutationName) then
		bonus *= Config.MutationSizeMultiplier
	end
	return bonus
end

-- Saved form of an item: { Id = "DragonAura", M = "Storm", P = true } for a hatched
-- animal, or { Id = "DragonAura", T = 120 } for an egg with 120 seconds left.
function Config.EncodeEgg(eggId, mutationName, hatched, hatchLeft)
	return {
		Id = eggId,
		M = mutationName,
		P = hatched and true or nil,
		T = (not hatched) and math.max(0, math.floor(hatchLeft or Config.GetHatchTime(eggId))) or nil,
	}
end

-- Accepts a saved item (table, or the older "EggId" / "EggId:Mutation" text).
-- Returns eggId, mutationName, hatched, hatchLeft; eggId is nil if it isn't valid.
function Config.DecodeEgg(saved)
	local eggId, mutationName, hatched, hatchLeft
	if type(saved) == "string" then
		eggId, mutationName = string.match(saved, "^([^:]+):([^:]+)$")
		if not eggId then
			eggId = saved
			mutationName = nil
		end
	elseif type(saved) == "table" then
		eggId = saved.Id
		mutationName = saved.M
		hatched = saved.P == true
		hatchLeft = saved.T
	end

	if type(eggId) ~= "string" or not Config.GetEgg(eggId) then
		return nil, nil, false, 0
	end
	if type(mutationName) ~= "string" or not Config.Mutations[mutationName] then
		mutationName = nil -- unknown mutation: keep the egg, drop the mutation
	end
	hatched = hatched == true
	local fullTime = Config.GetHatchTime(eggId)
	if type(hatchLeft) ~= "number" or hatchLeft ~= hatchLeft then
		hatchLeft = fullTime
	end
	hatchLeft = math.clamp(math.floor(hatchLeft), 0, fullTime)
	return eggId, mutationName, hatched, hatchLeft
end

function Config.GetBaseLevel(level)
	local index = math.clamp(math.floor(level or 1), 1, #Config.BaseUpgrades)
	return Config.BaseUpgrades[index]
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

-- 1234 -> "1.2K", 5000000 -> "5M"
function Config.FormatNumber(value)
	local n = math.floor(value)
	local v = math.abs(n)
	local index = 1
	while v >= 1000 and index < #SUFFIXES do
		v /= 1000
		index += 1
	end

	local text
	if index == 1 then
		text = tostring(math.floor(v))
	else
		text = string.format("%.1f", math.floor(v * 10) / 10)
		text = string.gsub(text, "%.0$", "")
	end

	if n < 0 then
		text = "-" .. text
	end
	return text .. SUFFIXES[index]
end

function Config.FormatCash(value)
	return "$" .. Config.FormatNumber(value)
end

return Config
