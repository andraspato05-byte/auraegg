-- Game data and rules in src/shared/Config.luau
return function(H)
	local Config = H.loadModule("src/shared/Config.luau")
	local PetShapes = H.loadModule("src/server/PetShapes.luau")

	H.section("Config: eggs and rarities")

	H.test("every egg has valid, unique data", function()
		local seen = {}
		for _, egg in Config.Eggs do
			H.expect(not seen[egg.Id], "duplicate id " .. egg.Id)
			seen[egg.Id] = true
			H.expect(Config.GetRarity(egg.Rarity) ~= nil, egg.Id .. " has unknown rarity")
			H.expect(egg.Price > 0 and egg.Income > 0, egg.Id .. " needs a price and income")
			H.expect(type(egg.PetName) == "string" and egg.PetName ~= "", egg.Id .. " has no PetName")
			H.expect(PetShapes[egg.PetShape] ~= nil, egg.Id .. " has unknown PetShape " .. tostring(egg.PetShape))
			H.expect(egg.EggColor ~= nil and egg.AuraColor ~= nil, egg.Id .. " needs colours")
		end
	end)

	H.test("rarer eggs always cost more", function()
		local previousMax = 0
		for _, rarity in Config.Rarities do
			local minPrice, maxPrice = math.huge, 0
			for _, egg in Config.EggsByRarity[rarity.Name] or {} do
				minPrice = math.min(minPrice, egg.Price)
				maxPrice = math.max(maxPrice, egg.Price)
			end
			H.expect(minPrice > previousMax, rarity.Name .. " overlaps the price of the rarity below it")
			previousMax = maxPrice
		end
	end)

	H.test("every egg pays itself back within 2 minutes", function()
		for _, egg in Config.Eggs do
			local payback = egg.Price / egg.Income
			H.expect(payback <= 120, egg.Id .. " takes " .. payback .. "s to pay back")
		end
	end)

	H.test("hatch time and size bonus grow with rarity", function()
		for index = 2, #Config.Rarities do
			local lower, higher = Config.Rarities[index - 1], Config.Rarities[index]
			H.expect(higher.HatchTime >= lower.HatchTime, higher.Name .. " hatches faster than " .. lower.Name)
			H.expect(higher.SizeBonus > lower.SizeBonus, higher.Name .. " gives less size than " .. lower.Name)
		end
	end)

	H.test("the max size is reachable with a full base", function()
		local best = 0
		for _, rarity in Config.Rarities do
			best = math.max(best, rarity.SizeBonus)
		end
		H.expect(1 + best * Config.SlotsPerPlot >= Config.MaxScale, "MaxScale can never be reached")
	end)

	H.section("Config: egg rolls")

	H.test("roll odds follow the rarity weights", function()
		local rng = H.Random.new(7)
		local counts, total, weightSum = {}, 100000, 0
		for _, rarity in Config.Rarities do
			weightSum += rarity.Weight
			counts[rarity.Name] = 0
		end
		for _ = 1, total do
			local egg = Config.GetEgg(Config.RollEggId(rng))
			counts[egg.Rarity] += 1
		end
		for _, rarity in Config.Rarities do
			H.near(counts[rarity.Name] / total, rarity.Weight / weightSum, 0.01, rarity.Name .. " share")
		end
	end)

	H.test("minimum rarity is respected (Lucky Egg)", function()
		local rng = H.Random.new(3)
		for _ = 1, 5000 do
			local egg = Config.GetEgg(Config.RollEggId(rng, Config.LuckyEggMinRarity))
			H.expect(Config.GetRarity(egg.Rarity).Index >= Config.LuckyEggMinRarity, "rolled " .. egg.Rarity)
		end
	end)

	H.test("storm luck makes rare eggs more common", function()
		local function rareShare(luck)
			local rng = H.Random.new(11)
			local rare = 0
			for _ = 1, 50000 do
				local egg = Config.GetEgg(Config.RollEggId(rng, nil, luck))
				if Config.GetRarity(egg.Rarity).Index >= 3 then
					rare += 1
				end
			end
			return rare / 50000
		end
		H.expect(rareShare(Config.Event.RareLuck) > rareShare(1) * 2, "luck did not raise the rare share enough")
	end)

	H.section("Config: values and save format")

	H.test("number formatting", function()
		local cases = {
			[0] = "0",
			[999] = "999",
			[1000] = "1K",
			[1234] = "1.2K",
			[999999] = "999.9K",
			[1000000] = "1M",
			[1500000000] = "1.5B",
			[-1500] = "-1.5K",
		}
		for value, expected in cases do
			H.equal(Config.FormatNumber(value), expected, "FormatNumber(" .. value .. ")")
		end
		H.equal(Config.FormatCash(25), "$25", "FormatCash")
	end)

	H.test("animals earn and cost more, mutations multiply", function()
		local id = "DragonAura"
		local base = Config.GetEgg(id)
		H.equal(Config.GetEggIncome(id), base.Income, "egg income")
		H.equal(Config.GetEggIncome(id, nil, true), base.Income * Config.PetIncomeMultiplier, "animal income")
		H.equal(Config.GetEggIncome(id, "Storm", true), base.Income * 3 * Config.PetIncomeMultiplier, "storm animal")
		H.equal(Config.GetEggPrice(id, "Storm"), math.floor(base.Price * 2.5), "storm price")
		H.equal(Config.GetSizeBonus(id, nil, false), 0, "eggs give no size")
		H.expect(Config.GetSizeBonus(id, "Storm", true) > Config.GetSizeBonus(id, nil, true), "storm size bonus")
		H.equal(Config.GetEggDisplayName(id, "Storm", true), "Storm " .. base.PetName, "display name")
	end)

	H.test("save format round-trips", function()
		local saved = Config.EncodeEgg("FrostAura", "Storm", false, 42)
		local id, mutation, hatched, left = Config.DecodeEgg(saved)
		H.equal(id, "FrostAura", "id")
		H.equal(mutation, "Storm", "mutation")
		H.equal(hatched, false, "hatched")
		H.equal(left, 42, "hatch time left")

		id, mutation, hatched = Config.DecodeEgg(Config.EncodeEgg("FrostAura", nil, true))
		H.equal(id, "FrostAura", "animal id")
		H.equal(mutation, nil, "no mutation")
		H.equal(hatched, true, "animal hatched")
	end)

	H.test("old and broken saves decode safely", function()
		local id, mutation, hatched, left = Config.DecodeEgg("DragonAura:Storm")
		H.equal(id, "DragonAura", "legacy id")
		H.equal(mutation, "Storm", "legacy mutation")
		H.equal(hatched, false, "legacy eggs are unhatched")
		H.equal(left, Config.GetHatchTime("DragonAura"), "legacy eggs start a full timer")

		H.equal((Config.DecodeEgg("NotAnEgg")), nil, "unknown egg")
		H.equal((Config.DecodeEgg(42)), nil, "number")
		H.equal(select(2, Config.DecodeEgg({ Id = "DustyAura", M = "Lava" })), nil, "unknown mutation dropped")
		H.equal(select(4, Config.DecodeEgg({ Id = "DustyAura", T = 0 / 0 })), Config.GetHatchTime("DustyAura"), "NaN timer")
		H.equal(select(4, Config.DecodeEgg({ Id = "DustyAura", T = 99999 })), Config.GetHatchTime("DustyAura"), "timer clamped")
	end)

	H.section("Config: progression")

	H.test("base upgrades are in order and end at every pedestal", function()
		local previous = nil
		for index, level in Config.BaseUpgrades do
			H.equal(level.Level, index, "level number")
			H.expect(level.Slots <= Config.SlotsPerPlot, "too many slots at level " .. index)
			if previous then
				H.expect(level.Cost > previous.Cost, "level " .. index .. " is not more expensive")
				H.expect(level.Slots >= previous.Slots, "level " .. index .. " has fewer slots")
				H.expect(level.CashBonus >= previous.CashBonus, "level " .. index .. " has a smaller cash bonus")
			end
			previous = level
		end
		H.equal(previous.Slots, Config.SlotsPerPlot, "max level slots")
		H.equal(Config.GetBaseLevel(99).Level, #Config.BaseUpgrades, "level clamped high")
		H.equal(Config.GetBaseLevel(-5).Level, 1, "level clamped low")
	end)

	H.test("every treadmill can be run on once it unlocks", function()
		for _, tier in Config.Treadmills do
			local walk = Config.GetWalkSpeed(tier.Required)
			H.expect(walk > tier.PushSpeed, "tier " .. tier.Tier .. " pushes faster than a player can run")
		end
	end)

	H.test("walk speed is clamped", function()
		H.equal(Config.GetWalkSpeed(0), Config.NormalWalkSpeed, "min")
		H.equal(Config.GetWalkSpeed(10 ^ 9), Config.GetWalkSpeed(Config.MaxSpeed), "max")
	end)

	H.test("event timings make sense", function()
		local event = Config.Event
		H.expect(event.Duration < event.Interval, "storm lasts longer than the gap between storms")
		H.expect(event.WarningTime < event.FirstDelay, "warning comes before the server starts")
		H.expect(event.StormChance > 0 and event.StormChance <= 1, "storm chance out of range")
	end)

	H.test("every shop item has a name and something to give", function()
		for _, pass in Config.GamePasses do
			H.expect(pass.Key and pass.Name and pass.Description, "incomplete pass")
		end
		for _, product in Config.Products do
			H.expect(product.Cash or product.LuckyEgg, product.Key .. " gives nothing")
		end
	end)
end
