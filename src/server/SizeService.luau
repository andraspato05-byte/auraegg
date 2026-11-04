--[[
	SizeService - grow big and SIZE MOG

	Every hatched animal on your base makes your character bigger (see
	Config.Rarities[].SizeBonus, max Config.MaxScale). Your size shows on the
	leaderboard (Size, in %) and as the player attribute "Size".

	MOG: stand next to a player who is smaller than you and press the MOG
	button (or G). They get launched backwards, drop any egg they were
	stealing, and you earn cash. The server checks size, distance, cooldown
	and immunity, so the client can't fake it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Session = require(script.Parent.Session)
local Remotes = require(script.Parent.Remotes)
local PlotService = require(script.Parent.PlotService)

local SizeService = {}

local COLOR_MOG = Color3.fromRGB(255, 90, 160)
local COLOR_BAD = Color3.fromRGB(255, 90, 90)
local TICK = 0.5

local lastMog = {} -- [Player] = time of their last MOG
local immuneUntil = {} -- [Player] = time until they can be mogged again

local function targetScale(player)
	return math.clamp(1 + PlotService.GetPetSizeBonus(player), 1, Config.MaxScale)
end

local function living(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or character.Parent == nil then
		return nil, nil
	end
	return character, root
end

local function applyScale(player, scale)
	local character = living(player)
	if not character then
		return
	end
	local ok, current = pcall(function()
		return character:GetScale()
	end)
	if not ok or type(current) ~= "number" or math.abs(current - scale) < 0.01 then
		return
	end
	local scaled, err = pcall(function()
		character:ScaleTo(scale)
	end)
	if not scaled then
		warn("[StealTheAuraEgg] Could not scale " .. player.Name .. ": " .. tostring(err))
		return
	end
	if scale > current then
		-- scaling happens around the middle of the body, so lift the character out of the floor
		character:PivotTo(character:GetPivot() + Vector3.new(0, (scale - current) * 3, 0))
	end
	PlotService.UpdateCarryOffset(player)
end

-- Recalculates and applies the player's size right away.
function SizeService.Refresh(player)
	local session = Session.Get(player)
	if not session or not session.Loaded then
		return
	end
	local scale = targetScale(player)
	player:SetAttribute("Size", scale)
	session.SizeValue.Value = math.floor(scale * 100 + 0.5)
	applyScale(player, scale)
end

local function onMog(player, target)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player or target.Parent ~= Players then
		return
	end
	if PlotService.IsShuttingDown() then
		return
	end
	local mySession = Session.Get(player)
	local theirSession = Session.Get(target)
	if not mySession or not mySession.Loaded or not theirSession or not theirSession.Loaded then
		return
	end

	local now = time()
	if now - (lastMog[player] or -math.huge) < Config.MogCooldown then
		return
	end
	if now < (immuneUntil[target] or 0) then
		Remotes.Notify(player, target.DisplayName .. " was just mogged. Give them a second!", COLOR_BAD)
		return
	end

	local myScale = player:GetAttribute("Size") or 1
	local theirScale = target:GetAttribute("Size") or 1
	if myScale - theirScale < Config.MogMinLead then
		Remotes.Notify(player, "You're not big enough to mog " .. target.DisplayName .. "! Hatch more animals.", COLOR_BAD)
		return
	end

	local _, myRoot = living(player)
	local _, theirRoot = living(target)
	if not myRoot or not theirRoot then
		return
	end
	local offset = theirRoot.Position - myRoot.Position
	if offset.Magnitude > Config.MogRange * myScale + 2 then
		return
	end

	lastMog[player] = now
	immuneUntil[target] = now + Config.MogImmunity

	local flat = Vector3.new(offset.X, 0, offset.Z)
	local direction = flat.Magnitude > 0.05 and flat.Unit or myRoot.CFrame.LookVector
	if PlotService.IsCarrying(target) then
		PlotService.CancelCarry(target, player.DisplayName .. " SIZE MOGGED you! You dropped the egg.")
	end
	Remotes.Knockback(target, direction * 70 + Vector3.new(0, 45, 0))

	local reward = math.max(Config.MogMinReward, math.floor((target:GetAttribute("Income") or 0) * Config.MogRewardSeconds))
	Session.AddCash(player, reward)
	Remotes.Notify(player, "You SIZE MOGGED " .. target.DisplayName .. "! +" .. Config.FormatCash(reward), COLOR_MOG)
	Remotes.Notify(target, player.DisplayName .. " SIZE MOGGED you!", COLOR_BAD)
end

function SizeService.Init()
	Remotes.MogEvent.OnServerEvent:Connect(onMog)

	Players.PlayerRemoving:Connect(function(player)
		lastMog[player] = nil
		immuneUntil[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(SizeService.Refresh, player)
				if not ok then
					warn("[StealTheAuraEgg] Size error: " .. tostring(err))
				end
			end
		end
	end)
end

return SizeService
