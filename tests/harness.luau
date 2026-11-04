--[[
	Tiny test harness for Lune (https://lune-org.github.io/docs).

	  - H.test(name, fn), H.expect(...), H.equal(...), H.near(...)
	  - H.loadModule(path): runs one of the game's ModuleScripts outside Roblox,
	    with Roblox datatypes from @lune/roblox and small stand-ins for game,
	    script, require, task and Random.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local H = {}

H.passed = 0
H.failed = 0
H.failures = {}

function H.section(name)
	print("\n" .. name)
end

function H.test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		H.passed += 1
		print("  ok    " .. name)
	else
		H.failed += 1
		table.insert(H.failures, name .. ": " .. tostring(err))
		print("  FAIL  " .. name .. "\n        " .. tostring(err))
	end
end

function H.expect(condition, message)
	if not condition then
		error(message or "expectation failed", 2)
	end
end

function H.equal(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message or "values differ", tostring(expected), tostring(actual)), 2)
	end
end

function H.near(actual, expected, tolerance, message)
	if math.abs(actual - expected) > tolerance then
		error(
			string.format("%s: expected %s (+-%s), got %s", message or "values differ", tostring(expected), tostring(tolerance), tostring(actual)),
			2
		)
	end
end

------------------------------------------------------------------------------
-- Deterministic stand-in for Roblox's Random
------------------------------------------------------------------------------

local Random = {}
Random.__index = Random

function Random.new(seed)
	return setmetatable({ state = (seed or 12345) % 2147483647 }, Random)
end

function Random:NextNumber(min, max)
	-- Park-Miller LCG; good enough for statistics in tests
	self.state = (self.state * 48271) % 2147483647
	local value = self.state / 2147483647
	if min and max then
		return min + value * (max - min)
	end
	return value
end

function Random:NextInteger(min, max)
	return math.min(max, min + math.floor(self:NextNumber() * (max - min + 1)))
end

H.Random = Random

------------------------------------------------------------------------------
-- Loading game modules outside Roblox
------------------------------------------------------------------------------

local moduleCache = {}

local function modulePointer(path)
	return { __modulePath = path }
end

-- An object whose children are other module files in `directory`.
local function folderPointer(directory)
	return setmetatable({}, {
		__index = function(_, name)
			return modulePointer(directory .. "/" .. name .. ".luau")
		end,
	})
end

local fakeServices = {
	ReplicatedStorage = {
		WaitForChild = function(_, name)
			if name == "Shared" then
				return {
					WaitForChild = function(_, moduleName)
						return modulePointer("src/shared/" .. moduleName .. ".luau")
					end,
				}
			end
			error("ReplicatedStorage." .. name .. " is not available in tests")
		end,
	},
	DataStoreService = {
		GetDataStore = function()
			error("DataStores are not available in tests")
		end,
	},
}

local fakeGame = {
	JobId = "test-server",
	GetService = function(_, name)
		local service = fakeServices[name]
		if not service then
			error("game:GetService('" .. name .. "') is not available in tests")
		end
		return service
	end,
}

function H.loadModule(path)
	if moduleCache[path] then
		return moduleCache[path]
	end

	local directory = string.match(path, "^(.*)/[^/]+$") or "."
	local environment = {
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Enum = roblox.Enum,
		Random = Random,
		game = fakeGame,
		workspace = {},
		script = { Parent = folderPointer(directory) },
		task = {
			wait = function() end,
			spawn = function(fn, ...)
				fn(...)
			end,
			delay = function() end,
			defer = function() end,
		},
		warn = function() end,
		time = os.clock,
		require = function(target)
			if type(target) == "table" and target.__modulePath then
				return H.loadModule(target.__modulePath)
			end
			error("require() of an unknown target in tests")
		end,
	}

	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = environment })
	local result = chunk()
	moduleCache[path] = result
	return result
end

H.roblox = roblox
H.fs = fs
H.luau = luau

return H
