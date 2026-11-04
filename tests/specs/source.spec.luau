-- The Luau source files themselves
return function(H)
	local fs = H.fs
	local luau = H.luau

	local function luauFiles(directory, out)
		out = out or {}
		for _, name in fs.readDir(directory) do
			local path = directory .. "/" .. name
			if fs.isDir(path) then
				luauFiles(path, out)
			elseif string.sub(name, -5) == ".luau" then
				table.insert(out, path)
			end
		end
		table.sort(out)
		return out
	end

	local files = luauFiles("src")

	H.section("Source: compiling and requires")

	H.test("every source file compiles", function()
		for _, path in files do
			local ok, err = pcall(luau.compile, fs.readFile(path))
			H.expect(ok, path .. ": " .. tostring(err))
		end
	end)

	-- module name -> list of server modules it requires
	local graph = {}
	for _, path in files do
		local module = string.match(path, "^src/server/([%w_]+)%.luau$")
			or string.match(path, "^src/server/([%w_]+)%.server%.luau$")
		if module then
			graph[module] = {}
			local source = fs.readFile(path)
			for target in string.gmatch(source, "require%(script%.Parent%.([%w_]+)%)") do
				table.insert(graph[module], target)
			end
			for target in string.gmatch(source, "require%(Server%.([%w_]+)%)") do
				table.insert(graph[module], target)
			end
		end
	end

	H.test("every required server module exists", function()
		for module, targets in graph do
			for _, target in targets do
				H.expect(fs.isFile("src/server/" .. target .. ".luau"), module .. " requires missing module " .. target)
			end
		end
	end)

	H.test("no circular requires", function()
		local state = {}
		local function visit(module, stack)
			if state[module] == "done" then
				return
			end
			H.expect(state[module] ~= "visiting", "require cycle: " .. table.concat(stack, " -> ") .. " -> " .. module)
			state[module] = "visiting"
			table.insert(stack, module)
			for _, target in graph[module] or {} do
				visit(target, stack)
			end
			table.remove(stack)
			state[module] = "done"
		end
		for module in graph do
			visit(module, {})
		end
	end)

	H.test("every remote the client waits for is created by the server", function()
		local created = {}
		for name in string.gmatch(fs.readFile("src/server/Remotes.luau"), 'getOrCreate%("([%w_]+)"%)') do
			created[name] = true
		end
		local client = fs.readFile("src/client/ClientMain.client.luau")
		for name in string.gmatch(client, 'remotes:WaitForChild%("([%w_]+)"%)') do
			H.expect(created[name], "client waits for remote '" .. name .. "' that is never created")
		end
	end)
end
