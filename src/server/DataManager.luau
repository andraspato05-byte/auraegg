--[[
	DataManager
	Loads and saves player progress (cash, steals and the eggs on each
	pedestal) with DataStoreService.

	Safety features (stealing moves eggs between players, so a stale or
	out-of-order save could duplicate eggs):
	  - Session lock: a server stamps the record with its JobId when it loads a
	    player, and other servers wait for that lock to be released (or go
	    stale) before loading the same player.
	  - Saves for the same player never overlap: if a save is already running,
	    the newest snapshot is queued and written right after it.
	  - WaitForAll() lets the server wait for every save before shutting down.

	In Studio, saving only works if the place is published and
	"Enable Studio Access to API Services" is on (Game Settings > Security).
	If DataStores are unavailable the game still runs, it just won't save.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataManager = {}

local SAVE_ATTEMPTS = 3
local LOAD_ATTEMPTS = 8
local FORCE_LOCK_ATTEMPT = 7 -- after this many tries (~20 s) take over a lock that was never released
local LOCK_STALE_SECONDS = Config.AutosaveInterval * 3 -- autosaves refresh the lock
local LOAD_RETRY_WAIT = 3

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[StealTheAuraEgg] DataStores are unavailable, progress will not be saved: " .. tostring(result))
	end
end

local writing = {} -- [userId] = true while a save worker is running
local queued = {} -- [userId] = { Data, Release } newest snapshot waiting to be written
local inFlight = 0

local function keyFor(userId)
	return "Player_" .. tostring(userId)
end

local function defaultData()
	return {
		Cash = Config.StartingCash,
		Steals = 0,
		Speed = 0,
		Eggs = {}, -- [slotIndex: number] = "EggId" or "EggId:Mutation"
	}
end

local function isValidCount(value)
	-- rejects NaN, negatives and infinity
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

local function sanitize(raw)
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end

	if isValidCount(raw.Cash) then
		data.Cash = math.floor(raw.Cash)
	end
	if isValidCount(raw.Steals) then
		data.Steals = math.floor(raw.Steals)
	end
	if isValidCount(raw.Speed) then
		data.Speed = math.min(raw.Speed, Config.MaxSpeed)
	end

	if type(raw.Eggs) == "table" then
		for key, saved in raw.Eggs do
			local index = tonumber(key)
			local eggId, mutationName = Config.DecodeEgg(saved)
			if index and index == math.floor(index) and index >= 1 and index <= Config.SlotsPerPlot and eggId then
				data.Eggs[index] = Config.EncodeEgg(eggId, mutationName) -- e.g. "DragonAura:Storm"
			end
		end
	end

	return data
end

local function isLockedByOtherServer(record)
	if type(record) ~= "table" or type(record.Lock) ~= "table" then
		return false
	end
	local lock = record.Lock
	if lock.JobId == game.JobId then
		return false
	end
	return type(lock.Time) == "number" and os.time() - lock.Time < LOCK_STALE_SECONDS
end

function DataManager.IsAvailable()
	return store ~= nil
end

-- Returns (data, canSave). canSave is false when loading failed, so the
-- caller must not save over what is really stored.
function DataManager.Load(player)
	if not store then
		return defaultData(), false
	end

	local userId = player.UserId
	local key = keyFor(userId)

	-- If this server is still writing this player's last session (quick rejoin), let it finish.
	for _ = 1, 60 do
		if not writing[userId] then
			break
		end
		task.wait(0.25)
	end

	for attempt = 1, LOAD_ATTEMPTS do
		local loaded = nil
		local blocked = false
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				-- this callback can run more than once, so reset the results each time
				loaded = nil
				blocked = false
				if attempt < FORCE_LOCK_ATTEMPT and isLockedByOtherServer(old) then
					blocked = true
					return nil -- cancel the write, try again later
				end
				local record = type(old) == "table" and old or {}
				loaded = sanitize(record)
				record.Lock = { JobId = game.JobId, Time = os.time() }
				return record
			end)
		end)

		if player.Parent == nil then
			-- Left while loading: give the lock back so their next server can load right away.
			if ok and loaded then
				pcall(function()
					store:UpdateAsync(key, function(old)
						if type(old) == "table" and type(old.Lock) == "table" and old.Lock.JobId == game.JobId then
							old.Lock = nil
							return old
						end
						return nil
					end)
				end)
			end
			return defaultData(), false
		end
		if ok and loaded then
			return loaded, true
		end
		if not ok then
			warn(string.format("[StealTheAuraEgg] Load failed for %s (attempt %d): %s", player.Name, attempt, tostring(err)))
		elseif blocked then
			warn(string.format("[StealTheAuraEgg] %s is still locked by another server (attempt %d)", player.Name, attempt))
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(LOAD_RETRY_WAIT)
		end
	end

	return defaultData(), false
end

local function write(userId, job)
	local key = keyFor(userId)
	for attempt = 1, SAVE_ATTEMPTS do
		local refused = false
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				refused = false
				if isLockedByOtherServer(old) then
					refused = true -- another server owns this player now; never overwrite it
					return nil
				end
				local record = {
					Cash = job.Data.Cash,
					Steals = job.Data.Steals,
					Speed = job.Data.Speed,
					Eggs = job.Data.Eggs,
				}
				if not job.Release then
					record.Lock = { JobId = game.JobId, Time = os.time() }
				end
				return record
			end)
		end)
		if ok then
			if refused then
				warn("[StealTheAuraEgg] Skipped saving " .. tostring(userId) .. ": another server owns the data")
			end
			return
		end
		warn(string.format("[StealTheAuraEgg] Save failed for %s (attempt %d): %s", tostring(userId), attempt, tostring(err)))
		if attempt < SAVE_ATTEMPTS then
			task.wait(attempt)
		end
	end
end

-- data = { Cash = number, Steals = number, Speed = number, Eggs = { ["1"] = eggId, ... } }
-- Egg keys must be strings so the DataStore stores a dictionary, not a holey array.
-- release = true for the final save of a session (player leaving / server closing).
-- Does not yield: the write happens in the background, in order, per player.
function DataManager.Save(userId, data, release)
	if not store or not data then
		return
	end

	local previous = queued[userId]
	queued[userId] = {
		Data = data,
		Release = (release == true) or (previous ~= nil and previous.Release),
	}

	if writing[userId] then
		return -- the running worker will pick up the newest snapshot
	end
	writing[userId] = true
	inFlight += 1

	task.spawn(function()
		while queued[userId] do
			local job = queued[userId]
			queued[userId] = nil
			local ok, err = pcall(write, userId, job)
			if not ok then
				warn("[StealTheAuraEgg] Save error for " .. tostring(userId) .. ": " .. tostring(err))
			end
		end
		writing[userId] = nil
		inFlight -= 1
	end)
end

-- Yields until every save has finished (or maxSeconds passes).
function DataManager.WaitForAll(maxSeconds)
	local waited = 0
	while inFlight > 0 and waited < maxSeconds do
		task.wait(0.1)
		waited += 0.1
	end
end

return DataManager
