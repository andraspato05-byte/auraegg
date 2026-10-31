--[[
	BatService
	Every player gets an Aura Bat. Swinging it at a player knocks them back,
	and if they are carrying a stolen egg they drop it (it goes home).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local PlotService = require(script.Parent.PlotService)

local BatService = {}

local REST_GRIP = CFrame.new(0, 0, 1.6) -- hold the bat near its back end
local SWING_GRIP = CFrame.new(0, 0, 1.6) * CFrame.Angles(math.rad(-75), 0, 0)

local template = nil
local lastSwing = {} -- [Player] = time of last swing
local hookedTools = setmetatable({}, { __mode = "k" })

local function buildBat()
	local tool = Instance.new("Tool")
	tool.Name = Config.BatName
	tool.ToolTip = "Bonk thieves to make them drop your egg!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = REST_GRIP

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.7, 0.7, 4.6)
	handle.Color = Color3.fromRGB(125, 85, 50)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local tip = Instance.new("Part")
	tip.Name = "AuraTip"
	tip.Size = Vector3.new(1, 1, 1.6)
	tip.Color = Color3.fromRGB(120, 220, 255)
	tip.Material = Enum.Material.Neon
	tip.CanCollide = false
	tip.CanTouch = false
	tip.CanQuery = false
	tip.Massless = true
	tip.TopSurface = Enum.SurfaceType.Smooth
	tip.BottomSurface = Enum.SurfaceType.Smooth
	tip.CFrame = handle.CFrame * CFrame.new(0, 0, -1.9) -- the far end, away from the hand
	tip.Parent = tool

	local tipWeld = Instance.new("WeldConstraint")
	tipWeld.Part0 = handle
	tipWeld.Part1 = tip
	tipWeld.Parent = tip

	local swingSound = Instance.new("Sound")
	swingSound.Name = "SwingSound"
	swingSound.SoundId = "rbxasset://sounds/swordslash.wav" -- built into every Roblox install
	swingSound.Volume = 0.6
	swingSound.Parent = handle

	return tool
end

local function getLiving(player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil
	end
	return humanoid, root
end

local function swing(player, tool)
	local character = player.Character
	if not character or tool.Parent ~= character then
		return -- only works while equipped
	end
	local _, root = getLiving(player)
	if not root then
		return
	end

	local now = time()
	if now - (lastSwing[player] or -math.huge) < Config.BatCooldown then
		return
	end
	lastSwing[player] = now

	local handle = tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild("SwingSound")
	if sound then
		sound:Play()
	end

	tool.Grip = SWING_GRIP
	task.delay(0.25, function()
		if tool.Parent then
			tool.Grip = REST_GRIP
		end
	end)

	local look = root.CFrame.LookVector
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local _, otherRoot = getLiving(other)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				local flat = Vector3.new(offset.X, 0, offset.Z)
				if distance <= Config.BatRange then
					-- must be roughly in front of the swinger (or right on top of them)
					local inFront = flat.Magnitude < 1 or look:Dot(flat.Unit) > 0.1
					if inFront then
						local direction = flat.Magnitude >= 0.05 and flat.Unit or look
						PlotService.OnPlayerBonked(other, player)
						Remotes.Knockback(other, direction * Config.BatKnockback + Vector3.new(0, 30, 0))
					end
				end
			end
		end
	end
end

local function hookTool(player, tool)
	if hookedTools[tool] then
		return
	end
	hookedTools[tool] = true
	tool.Activated:Connect(function()
		swing(player, tool)
	end)
end

local function hasBat(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	return (backpack ~= nil and backpack:FindFirstChild(Config.BatName) ~= nil)
		or (character ~= nil and character:FindFirstChild(Config.BatName) ~= nil)
end

function BatService.Init()
	template = buildBat()
	template.Parent = StarterPack -- everyone gets a copy each time they spawn
end

-- Hooks up any bat the character equips (tools move into the character when equipped).
function BatService.HookCharacter(player, character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == Config.BatName then
			hookTool(player, child)
		end
	end)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child.Name == Config.BatName then
			hookTool(player, child)
		end
	end
end

-- Gives a bat if the player somehow spawned without one.
function BatService.EnsureBat(player)
	if player.Parent ~= Players or not template or hasBat(player) then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		template:Clone().Parent = backpack
	end
end

function BatService.Forget(player)
	lastSwing[player] = nil
end

return BatService
