--[[
	STEAL THE AURA EGG - client

	  - HUD: cash, income per second, carry banner, how-to-play tips
	  - notification toasts sent by the server
	  - shows "Steal" only on other people's eggs and "Sell" only on yours
	  - rainbow colours for Secret eggs
	  - bat knockback
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyEvent = remotes:WaitForChild("Notify")
local knockbackEvent = remotes:WaitForChild("Knockback")

------------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------------

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function newLabel(parent, name, text, size, position, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = parent
	return label
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AuraEggHud"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Cash panel (top middle)
local cashPanel = Instance.new("Frame")
cashPanel.Name = "CashPanel"
cashPanel.AnchorPoint = Vector2.new(0.5, 0)
cashPanel.Position = UDim2.new(0.5, 0, 0, 8)
cashPanel.Size = UDim2.new(0, 260, 0, 70)
cashPanel.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
cashPanel.BackgroundTransparency = 0.15
cashPanel.Parent = screenGui
addCorner(cashPanel, 14)
addStroke(cashPanel, Color3.fromRGB(180, 110, 255), 2)

local cashLabel = newLabel(
	cashPanel,
	"Cash",
	"$0",
	UDim2.new(1, -16, 0.6, 0),
	UDim2.new(0, 8, 0, 4),
	Color3.fromRGB(120, 255, 140)
)
local incomeLabel = newLabel(
	cashPanel,
	"Income",
	"+$0/s",
	UDim2.new(1, -16, 0.32, 0),
	UDim2.new(0, 8, 0.62, 0),
	Color3.fromRGB(255, 230, 120)
)

-- Notifications (under the cash panel)
local notifyHolder = Instance.new("Frame")
notifyHolder.Name = "Notifications"
notifyHolder.AnchorPoint = Vector2.new(0.5, 0)
notifyHolder.Position = UDim2.new(0.5, 0, 0, 86)
notifyHolder.Size = UDim2.new(0, 460, 0, 220)
notifyHolder.BackgroundTransparency = 1
notifyHolder.Parent = screenGui

local notifyLayout = Instance.new("UIListLayout")
notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifyLayout.Padding = UDim.new(0, 4)
notifyLayout.Parent = notifyHolder

-- Carry banner (bottom middle)
local carryBanner = newLabel(
	screenGui,
	"CarryBanner",
	"",
	UDim2.new(0, 520, 0, 44),
	UDim2.new(0.5, -260, 1, -150),
	Color3.fromRGB(255, 220, 90)
)
carryBanner.BackgroundTransparency = 0.25
carryBanner.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
carryBanner.Visible = false
addCorner(carryBanner, 12)

-- How to play (bottom left, fades after a while)
local tips = Instance.new("TextLabel")
tips.Name = "HowToPlay"
tips.AnchorPoint = Vector2.new(0, 1)
tips.Position = UDim2.new(0, 12, 1, -12)
tips.Size = UDim2.new(0, 330, 0, 150)
tips.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
tips.BackgroundTransparency = 0.25
tips.Font = Enum.Font.GothamMedium
tips.TextSize = 14
tips.TextWrapped = true
tips.TextXAlignment = Enum.TextXAlignment.Left
tips.TextYAlignment = Enum.TextYAlignment.Top
tips.TextColor3 = Color3.fromRGB(255, 255, 255)
tips.Text = "HOW TO PLAY\n"
	.. "- Buy Aura Eggs from the conveyor belt (E)\n"
	.. "- Eggs on your base make cash every second\n"
	.. "- Stand on the green pads to collect the cash\n"
	.. "- Steal eggs from other bases (hold E) and run home\n"
	.. "- Bonk thieves with your Aura Bat to get eggs back\n"
	.. "- Stand on the red pad to lock your base"
tips.Parent = screenGui
addCorner(tips, 10)
local tipsPadding = Instance.new("UIPadding")
tipsPadding.PaddingLeft = UDim.new(0, 10)
tipsPadding.PaddingRight = UDim.new(0, 10)
tipsPadding.PaddingTop = UDim.new(0, 8)
tipsPadding.Parent = tips

task.delay(30, function()
	local fade = TweenInfo.new(1.5)
	TweenService:Create(tips, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	task.wait(1.6)
	tips.Visible = false
end)

------------------------------------------------------------------------------
-- Cash / income / carrying
------------------------------------------------------------------------------

local function refreshIncome()
	local income = player:GetAttribute("Income") or 0
	incomeLabel.Text = "+" .. Config.FormatCash(income) .. "/s"
end

local function refreshCarry()
	local carrying = player:GetAttribute("CarryingEgg")
	if type(carrying) == "string" and carrying ~= "" then
		carryBanner.Text = "Carrying " .. carrying .. "! Run back to your base!"
		carryBanner.Visible = true
	else
		carryBanner.Visible = false
	end
end

player:GetAttributeChangedSignal("Income"):Connect(refreshIncome)
player:GetAttributeChangedSignal("CarryingEgg"):Connect(refreshCarry)
refreshIncome()
refreshCarry()

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash")
	local function refreshCash()
		cashLabel.Text = Config.FormatCash(cash.Value)
	end
	cash.Changed:Connect(refreshCash)
	refreshCash()
end)

------------------------------------------------------------------------------
-- Notifications
------------------------------------------------------------------------------

local notifyCount = 0
local MAX_NOTIFICATIONS = 5

notifyEvent.OnClientEvent:Connect(function(text, color)
	if type(text) ~= "string" then
		return
	end
	if typeof(color) ~= "Color3" then
		color = Color3.fromRGB(255, 255, 255)
	end

	notifyCount += 1
	local label = newLabel(notifyHolder, "Notification", text, UDim2.new(1, 0, 0, 32), UDim2.new(), color)
	label.LayoutOrder = notifyCount
	label.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
	label.BackgroundTransparency = 0.3
	addCorner(label, 8)

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 22
	constraint.Parent = label

	-- keep only the newest few on screen
	local labels = {}
	for _, child in notifyHolder:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #labels - MAX_NOTIFICATIONS do
		labels[index]:Destroy()
	end

	task.delay(4, function()
		if label.Parent then
			local fade = TweenService:Create(label, TweenInfo.new(0.6), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				BackgroundTransparency = 1,
			})
			fade:Play()
			fade.Completed:Wait()
			label:Destroy()
		end
	end)
end)

------------------------------------------------------------------------------
-- Prompt filtering: Steal on other people's eggs, Sell on your own
------------------------------------------------------------------------------

local function applyPrompt(prompt)
	local kind = prompt:GetAttribute("Kind")
	if kind == nil then
		return
	end
	local isMine = prompt:GetAttribute("OwnerUserId") == player.UserId
	if kind == "Steal" then
		prompt.Enabled = not isMine
	elseif kind == "Sell" then
		prompt.Enabled = isMine
	end
end

local function watchPrompt(instance)
	if instance:IsA("ProximityPrompt") then
		applyPrompt(instance)
		instance:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			applyPrompt(instance)
		end)
	end
end

workspace.DescendantAdded:Connect(watchPrompt)
for _, descendant in workspace:GetDescendants() do
	watchPrompt(descendant)
end

------------------------------------------------------------------------------
-- Rainbow Secret eggs
------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	local color = Color3.fromHSV((os.clock() * 0.25) % 1, 0.85, 1)
	for _, instance in CollectionService:GetTagged("RainbowAura") do
		if instance:IsA("BasePart") then
			instance.Color = color
		end
	end
	for _, instance in CollectionService:GetTagged("RainbowText") do
		if instance:IsA("TextLabel") then
			instance.TextColor3 = color
		end
	end
end)

------------------------------------------------------------------------------
-- Bat knockback
------------------------------------------------------------------------------

knockbackEvent.OnClientEvent:Connect(function(velocity)
	if typeof(velocity) ~= "Vector3" then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	task.delay(0.6, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end)
