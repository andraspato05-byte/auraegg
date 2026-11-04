-- Save data cleaning in src/server/DataManager.luau
return function(H)
	local Config = H.loadModule("src/shared/Config.luau")
	local DataManager = H.loadModule("src/server/DataManager.luau")
	local sanitize = DataManager._Sanitize

	H.section("Saving: loading player data")

	H.test("new players get the starting data", function()
		local data = sanitize(nil)
		H.equal(data.Cash, Config.StartingCash, "cash")
		H.equal(data.Steals, 0, "steals")
		H.equal(data.Speed, 0, "speed")
		H.equal(data.BaseLevel, 1, "base level")
		H.equal(next(data.Eggs), nil, "no eggs")
	end)

	H.test("broken numbers fall back to safe values", function()
		local data = sanitize({ Cash = -50, Steals = 0 / 0, Speed = math.huge, BaseLevel = "x" })
		H.equal(data.Cash, Config.StartingCash, "negative cash")
		H.equal(data.Steals, 0, "NaN steals")
		H.equal(data.Speed, 0, "infinite speed")
		H.equal(data.BaseLevel, 1, "text base level")
	end)

	H.test("values are rounded and clamped", function()
		local data = sanitize({ Cash = 1234.9, Speed = 999999, BaseLevel = 50 })
		H.equal(data.Cash, 1234, "cash rounded down")
		H.equal(data.Speed, Config.MaxSpeed, "speed capped")
		H.equal(data.BaseLevel, #Config.BaseUpgrades, "level capped")
	end)

	H.test("eggs: valid slots kept, bad ones dropped", function()
		local data = sanitize({
			BaseLevel = 4,
			Eggs = {
				["1"] = { Id = "DustyAura", T = 10 },
				["2"] = "DragonAura:Storm", -- old format
				["3"] = { Id = "NotAnEgg" },
				["0"] = { Id = "DustyAura" },
				["11"] = { Id = "DustyAura" },
				["2.5"] = { Id = "DustyAura" },
			},
		})
		H.equal(data.Eggs[1].Id, "DustyAura", "slot 1")
		H.equal(data.Eggs[1].T, 10, "slot 1 timer")
		H.equal(data.Eggs[2].Id, "DragonAura", "legacy slot 2")
		H.equal(data.Eggs[2].M, "Storm", "legacy mutation")
		H.equal(data.Eggs[3], nil, "unknown egg dropped")
		H.equal(data.Eggs[0], nil, "slot 0 dropped")
		H.equal(data.Eggs[11], nil, "slot 11 dropped")
	end)

	H.test("old saves keep every pedestal that holds an egg", function()
		local data = sanitize({ Eggs = { ["7"] = { Id = "DustyAura" } } })
		H.expect(Config.GetBaseLevel(data.BaseLevel).Slots >= 7, "level " .. data.BaseLevel .. " locks slot 7")
		local fresh = sanitize({ BaseLevel = 1, Eggs = { ["2"] = { Id = "DustyAura" } } })
		H.equal(fresh.BaseLevel, 1, "saved level is respected")
	end)

	H.test("without DataStores the game runs but doesn't save", function()
		local data, canSave = DataManager.Load({ UserId = 1, Name = "Tester", Parent = true })
		H.equal(canSave, false, "canSave")
		H.equal(data.Cash, Config.StartingCash, "default data")
	end)
end
