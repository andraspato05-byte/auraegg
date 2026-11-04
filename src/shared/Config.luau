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
Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 200), Weight = 50 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 225, 100), Weight = 26 },
	{ Name = "Rare", Color = Color3.fromRGB(60, 150, 255), Weight = 13 },
	{ Name = "Epic", Color = Color3.fromRGB(180, 85, 255), Weight = 6.5 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 195, 40), Weight = 3 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 115), Weight = 1.2 },
	{ Name = "Secret", Color = Color3.fromRGB(255, 255, 255), Weight = 0.3 }, -- shown as rainbow
}

-- Aura Eggs -----------------------------------------------------------------
-- Price = cost on the belt, Income = cash per second while it sits on your base
Config.Eggs = {
	-- Common
	{ Id = "DustyAura", Name = "Dusty Aura Egg", Rarity = "Common", Price = 25, Income = 1,
		EggColor = Color3.fromRGB(214, 200, 175), AuraColor = Color3.fromRGB(255, 245, 220) },
	{ Id = "PebbleAura", Name = "Pebble Aura Egg", Rarity = "Common", Price = 40, Income = 2,
		EggColor = Color3.fromRGB(150, 150, 155), AuraColor = Color3.fromRGB(225, 225, 230) },
	{ Id = "LeafyAura", Name = "Leafy Aura Egg", Rarity = "Common", Price = 60, Income = 3,
		EggColor = Color3.fromRGB(110, 190, 90), AuraColor = Color3.fromRGB(180, 255, 160) },

	-- Uncommon
	{ Id = "BubbleAura", Name = "Bubble Aura Egg", Rarity = "Uncommon", Price = 150, Income = 6,
		EggColor = Color3.fromRGB(140, 210, 255), AuraColor = Color3.fromRGB(205, 240, 255) },
	{ Id = "EmberAura", Name = "Ember Aura Egg", Rarity = "Uncommon", Price = 250, Income = 10,
		EggColor = Color3.fromRGB(240, 110, 50), AuraColor = Color3.fromRGB(255, 190, 90) },
	{ Id = "MintyAura", Name = "Minty Aura Egg", Rarity = "Uncommon", Price = 400, Income = 15,
		EggColor = Color3.fromRGB(150, 245, 200), AuraColor = Color3.fromRGB(110, 255, 190) },

	-- Rare
	{ Id = "FrostAura", Name = "Frost Aura Egg", Rarity = "Rare", Price = 1000, Income = 35,
		EggColor = Color3.fromRGB(200, 235, 255), AuraColor = Color3.fromRGB(120, 210, 255) },
	{ Id = "ThunderAura", Name = "Thunder Aura Egg", Rarity = "Rare", Price = 1800, Income = 60,
		EggColor = Color3.fromRGB(255, 230, 70), AuraColor = Color3.fromRGB(255, 255, 140) },
	{ Id = "OceanAura", Name = "Ocean Aura Egg", Rarity = "Rare", Price = 3000, Income = 95,
		EggColor = Color3.fromRGB(30, 110, 200), AuraColor = Color3.fromRGB(60, 200, 255) },

	-- Epic
	{ Id = "ShadowAura", Name = "Shadow Aura Egg", Rarity = "Epic", Price = 8000, Income = 230,
		EggColor = Color3.fromRGB(45, 35, 60), AuraColor = Color3.fromRGB(150, 70, 255) },
	{ Id = "CrystalAura", Name = "Crystal Aura Egg", Rarity = "Epic", Price = 14000, Income = 380,
		EggColor = Color3.fromRGB(235, 170, 255), AuraColor = Color3.fromRGB(255, 140, 255) },
	{ Id = "VoidAura", Name = "Void Aura Egg", Rarity = "Epic", Price = 25000, Income = 650,
		EggColor = Color3.fromRGB(15, 10, 25), AuraColor = Color3.fromRGB(110, 40, 200) },

	-- Legendary
	{ Id = "SolarAura", Name = "Solar Aura Egg", Rarity = "Legendary", Price = 60000, Income = 1500,
		EggColor = Color3.fromRGB(255, 170, 30), AuraColor = Color3.fromRGB(255, 220, 80) },
	{ Id = "DragonAura", Name = "Dragon Aura Egg", Rarity = "Legendary", Price = 110000, Income = 2600,
		EggColor = Color3.fromRGB(170, 25, 25), AuraColor = Color3.fromRGB(255, 90, 30) },
	{ Id = "CosmicAura", Name = "Cosmic Aura Egg", Rarity = "Legendary", Price = 200000, Income = 4500,
		EggColor = Color3.fromRGB(40, 30, 110), AuraColor = Color3.fromRGB(120, 160, 255) },

	-- Mythic
	{ Id = "PhoenixAura", Name = "Phoenix Aura Egg", Rarity = "Mythic", Price = 600000, Income = 12000,
		EggColor = Color3.fromRGB(255, 90, 20), AuraColor = Color3.fromRGB(255, 200, 40) },
	{ Id = "GalaxyAura", Name = "Galaxy Aura Egg", Rarity = "Mythic", Price = 1200000, Income = 22000,
		EggColor = Color3.fromRGB(70, 20, 120), AuraColor = Color3.fromRGB(255, 80, 200) },

	-- Secret
	{ Id = "RainbowAura", Name = "Rainbow Aura Egg", Rarity = "Secret", Price = 5000000, Income = 80000,
		EggColor = Color3.fromRGB(255, 255, 255), AuraColor = Color3.fromRGB(255, 255, 255) },
	{ Id = "OmegaAura", Name = "Omega Aura Egg", Rarity = "Secret", Price = 15000000, Income = 220000,
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
function Config.RollEggId(rng, minRarityIndex)
	local minIndex = minRarityIndex or 1
	local total = 0
	for _, rarity in Config.Rarities do
		if rarity.Index >= minIndex and Config.EggsByRarity[rarity.Name] then
			total += rarity.Weight
		end
	end

	local roll = rng:NextNumber() * total
	for _, rarity in Config.Rarities do
		local list = Config.EggsByRarity[rarity.Name]
		if rarity.Index >= minIndex and list then
			roll -= rarity.Weight
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
