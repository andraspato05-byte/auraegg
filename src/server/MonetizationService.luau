--[[
	MonetizationService
	Robux purchases:
	  - Game passes (bought once, kept forever): 2x Cash, Speedy Thief, Mega Lock.
	    Ownership is stored as player attributes "Pass_<Key>" = true, which
	    PlotService reads. Only the server sets them.
	  - Developer products (can be bought again): cash packs and a Lucky Aura Egg.
	    Granted in ProcessReceipt using Roblox's recommended pattern: every
	    PurchaseId is recorded in a DataStore so a purchase is never granted twice,
	    and returning NotProcessedYet makes Roblox retry it later, so it's never lost.

	Set the IDs in ReplicatedStorage.Shared.Config (GamePasses / Products).
]]

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Session = require(script.Parent.Session)
local Remotes = require(script.Parent.Remotes)
local PlotService = require(script.Parent.PlotService)
local DataManager = require(script.Parent.DataManager)

local MonetizationService = {}

local COLOR_GOOD = Color3.fromRGB(110, 255, 140)

local rng = Random.new()
local passById = {}
local productById = {}

for _, pass in Config.GamePasses do
	if pass.Id ~= 0 then
		passById[pass.Id] = pass
	end
end
for _, product in Config.Products do
	if product.Id ~= 0 then
		productById[product.Id] = product
	end
end

local purchaseStore = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName .. "_Purchases")
	end)
	if ok then
		purchaseStore = result
	end
end

local function grantPass(player, pass, announce)
	if player:GetAttribute("Pass_" .. pass.Key) == true then
		return
	end
	player:SetAttribute("Pass_" .. pass.Key, true)
	if announce then
		Remotes.Notify(player, "You got " .. pass.Name .. "! " .. pass.Description, COLOR_GOOD)
	end
end

-- Checks which game passes the player owns (yields).
function MonetizationService.LoadPasses(player)
	for _, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if player.Parent ~= Players then
				return
			end
			if ok and owns then
				grantPass(player, pass, false)
			elseif not ok then
				warn("[StealTheAuraEgg] Could not check game pass " .. pass.Key .. ": " .. tostring(owns))
			end
		end
	end
end

-- Gives the product to the player. Must not yield. Returns true on success.
local function grantProduct(player, product)
	if product.Cash then
		Session.AddCash(player, product.Cash)
		Remotes.Notify(player, "You got " .. Config.FormatCash(product.Cash) .. "!", COLOR_GOOD)
		return true
	end

	if product.LuckyEgg then
		local eggId = Config.RollEggId(rng, Config.LuckyEggMinRarity)
		local def = Config.GetEgg(eggId)
		local rarity = Config.GetRarity(def.Rarity)
		local plot = PlotService.GetPlot(player)
		local slotIndex = plot and PlotService.FindFreeSlot(plot)
		if plot and slotIndex then
			PlotService.PlaceEgg(plot, slotIndex, eggId)
			Remotes.Notify(player, "Lucky! You got a " .. def.Rarity .. " " .. def.Name .. "!", rarity.Color)
		else
			-- No room on the base: pay out the egg's full price instead so nothing is lost.
			Session.AddCash(player, def.Price)
			Remotes.Notify(
				player,
				"Your base was full, so your " .. def.Name .. " became " .. Config.FormatCash(def.Price) .. "!",
				rarity.Color
			)
		end
		Remotes.NotifyAll(player.DisplayName .. " got a " .. def.Rarity .. " " .. def.Name .. " from a Lucky Egg!", rarity.Color)
		return true
	end

	return false
end

local function processReceipt(receiptInfo)
	local product = productById[receiptInfo.ProductId]
	if not product then
		warn("[StealTheAuraEgg] Unknown developer product: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local session = player and Session.Get(player)
	if not player or not session or not session.Loaded or PlotService.IsShuttingDown() then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later
	end

	-- No DataStores (e.g. an unpublished Studio test): just grant it.
	if not purchaseStore or not DataManager.IsAvailable() then
		if grantProduct(player, product) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Their save didn't load, so anything granted now would be lost. Wait for a later retry.
	if not session.CanSave then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, recorded = pcall(function()
		return purchaseStore:UpdateAsync(receiptInfo.PurchaseId, function(alreadyGranted)
			if alreadyGranted then
				return true -- granted before (Roblox called us again); don't give it twice
			end
			if player.Parent ~= Players then
				return nil -- left: cancel, Roblox retries later
			end
			if not grantProduct(player, product) then
				error("Failed to grant product " .. product.Key)
			end
			return true
		end)
	end)

	if not ok then
		warn("[StealTheAuraEgg] ProcessReceipt failed: " .. tostring(recorded))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if recorded == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Save soon so the purchase is stored with the player's progress.
	if player.Parent == Players and session.CanSave and not session.FinalSaved then
		DataManager.Save(player.UserId, PlotService.BuildSaveData(player), false)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		local pass = passById[passId]
		if wasPurchased and pass and player.Parent == Players then
			grantPass(player, pass, true)
		end
	end)
end

return MonetizationService
