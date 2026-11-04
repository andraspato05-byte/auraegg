-- The built place file (StealTheAuraEgg.rbxlx): does it contain everything the scripts expect?
return function(H)
	local fs = H.fs
	local roblox = H.roblox
	local Config = H.loadModule("src/shared/Config.luau")

	local game = roblox.deserializePlace(fs.readFile("StealTheAuraEgg.rbxlx"))
	local workspace = game:GetService("Workspace")

	local function find(root, path)
		local current = root
		for name in string.gmatch(path, "[^/]+") do
			current = current and current:FindFirstChild(name)
		end
		return current
	end

	H.section("Place: scripts and services")

	H.test("every server module is in ServerScriptService.Server", function()
		local server = find(game:GetService("ServerScriptService"), "Server")
		H.expect(server, "ServerScriptService.Server is missing")
		for _, name in fs.readDir("src/server") do
			local scriptName = string.match(name, "^([%w_]+)%.server%.luau$") or string.match(name, "^([%w_]+)%.luau$")
			if scriptName then
				local instance = server:FindFirstChild(scriptName)
				H.expect(instance, scriptName .. " is missing from the place")
				local expectedClass = string.find(name, "%.server%.luau$") and "Script" or "ModuleScript"
				H.equal(instance.ClassName, expectedClass, scriptName .. " class")
			end
		end
	end)

	H.test("client script, shared config and PetModels folder exist", function()
		H.expect(find(game:GetService("StarterPlayer"), "StarterPlayerScripts/ClientMain"), "ClientMain missing")
		H.expect(find(game:GetService("ReplicatedStorage"), "Shared/Config"), "Shared.Config missing")
		H.expect(find(game:GetService("ReplicatedStorage"), "PetModels"), "PetModels folder missing")
	end)

	H.section("Place: map")

	local mapBuilder = fs.readFile("src/server/MapBuilder.luau")
	local plots = workspace:FindFirstChild("Plots")
	local map = workspace:FindFirstChild("Map")

	H.test("every map part MapBuilder needs exists", function()
		H.expect(map and plots, "Workspace.Map / Workspace.Plots missing")
		for name in string.gmatch(mapBuilder, 'need%(map, "([%w_]+)"%)') do
			H.expect(map:FindFirstChild(name), "Workspace.Map." .. name .. " is missing")
		end
	end)

	H.test("every base has every part MapBuilder needs", function()
		local single, numbered = {}, {}
		for name in string.gmatch(mapBuilder, 'need%(model, "([%w_]+)"%)') do
			table.insert(single, name)
		end
		for prefix in string.gmatch(mapBuilder, 'need%(model, "([%w_]+)" %.%. slotIndex%)') do
			table.insert(numbered, prefix)
		end
		H.expect(#single >= 5 and #numbered >= 3, "could not read the names MapBuilder needs")
		for index = 1, Config.MaxPlots do
			local plot = plots:FindFirstChild("Plot" .. index)
			H.expect(plot, "Plot" .. index .. " is missing")
			for _, name in single do
				H.expect(plot:FindFirstChild(name), "Plot" .. index .. "." .. name .. " is missing")
			end
			for _, prefix in numbered do
				for slot = 1, Config.SlotsPerPlot do
					H.expect(plot:FindFirstChild(prefix .. slot), "Plot" .. index .. "." .. prefix .. slot .. " is missing")
				end
			end
		end
	end)

	H.test("every base faces the conveyor belt and they don't overlap", function()
		local origins = {}
		for index = 1, Config.MaxPlots do
			local origin = plots:FindFirstChild("Plot" .. index):FindFirstChild("Origin").CFrame
			local towardBelt = roblox.Vector3.new(0, 0, -origin.Position.Z).Unit
			H.expect(origin.LookVector:Dot(towardBelt) > 0.99, "Plot" .. index .. " entrance doesn't face the belt")
			table.insert(origins, origin.Position)
		end
		for a = 1, #origins do
			for b = a + 1, #origins do
				local gap = origins[a] - origins[b]
				H.expect(math.max(math.abs(gap.X), math.abs(gap.Z)) >= 58, "Plot" .. a .. " and Plot" .. b .. " overlap")
			end
		end
	end)

	H.test("pads don't overlap pedestals and everything stays inside the base", function()
		local plot = plots:FindFirstChild("Plot1")
		local origin = plot:FindFirstChild("Origin").CFrame
		local function box(part)
			local p = origin:PointToObjectSpace(part.CFrame.Position)
			return p, part.Size
		end
		local function overlaps(a, b)
			local pa, sa = box(a)
			local pb, sb = box(b)
			return math.abs(pa.X - pb.X) < (sa.X + sb.X) / 2 and math.abs(pa.Z - pb.Z) < (sa.Z + sb.Z) / 2
		end
		local items = { plot:FindFirstChild("LockPad"), plot:FindFirstChild("UpgradeTerminal") }
		for slot = 1, Config.SlotsPerPlot do
			table.insert(items, plot:FindFirstChild("Pedestal" .. slot))
			table.insert(items, plot:FindFirstChild("CashPad" .. slot))
		end
		for i = 1, #items do
			local p, s = box(items[i])
			H.expect(math.abs(p.X) + s.X / 2 <= 28 and math.abs(p.Z) + s.Z / 2 <= 28, items[i].Name .. " sticks out of the base")
			for j = i + 1, #items do
				H.expect(not overlaps(items[i], items[j]), items[i].Name .. " overlaps " .. items[j].Name)
			end
		end
	end)

	H.test("treadmills: 4 tiers in each of the 2 gyms, each with a belt", function()
		local count, tiers = 0, {}
		for _, descendant in map:GetDescendants() do
			if descendant.ClassName == "Model" and descendant.Name == "Treadmill" then
				count += 1
				local tier = descendant:GetAttribute("Tier")
				tiers[tier] = (tiers[tier] or 0) + 1
				local belt = descendant:FindFirstChild("Belt")
				H.expect(belt and belt:IsA("BasePart"), "a treadmill has no Belt")
			end
		end
		H.equal(count, 8, "treadmill count")
		for _, tier in Config.Treadmills do
			H.equal(tiers[tier.Tier], 2, "treadmills of tier " .. tier.Tier)
		end
	end)

	H.test("there is a spawn point", function()
		local spawn = map:FindFirstChild("LobbySpawn")
		H.expect(spawn and spawn.ClassName == "SpawnLocation", "LobbySpawn missing")
	end)

	H.section("Place: GUI")

	H.test("every GUI element the client script waits for exists", function()
		local client = fs.readFile("src/client/ClientMain.client.luau")
		local hud = find(game:GetService("StarterGui"), "AuraEggHud")
		H.expect(hud, "StarterGui.AuraEggHud missing")

		-- follow `local x = y:WaitForChild("Name")` chains starting at the HUD
		local paths = { hud = "" }
		local checked = 0
		for variable, parent, name in string.gmatch(client, "local (%w+) = (%w+):WaitForChild%(\"([%w_]+)\"%)") do
			if paths[parent] then
				local path = paths[parent] .. "/" .. name
				H.expect(find(hud, path), "AuraEggHud" .. string.gsub(path, "/", ".") .. " is missing")
				paths[variable] = path
				checked += 1
			end
		end
		-- the shop rows are clones of ItemTemplate
		paths.row = paths.itemTemplate
		for name in string.gmatch(client, 'row:WaitForChild%("([%w_]+)"%)') do
			H.expect(find(hud, paths.row .. "/" .. name), "ItemTemplate." .. name .. " is missing")
			checked += 1
		end
		H.expect(checked >= 15, "only found " .. checked .. " GUI lookups to check")
	end)
end
