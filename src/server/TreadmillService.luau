--[[
	TreadmillService
	Treadmills in the two gyms. Each belt pushes you backwards, so you have to
	keep running to stay on it. While you're on one you earn Speed points,
	and Speed makes you walk faster (see Config.GetWalkSpeed).

	Higher tiers push harder and give more Speed, but need a minimum Speed.
	Tier data lives in Config.Treadmills.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Session = require(script.Parent.Session)
local Remotes = require(script.Parent.Remotes)
local PlotService = require(script.Parent.PlotService)
local MapBuilder = require(script.Parent.MapBuilder)

local TreadmillService = {}

local TICK = 0.25
local NOTICE_COOLDOWN = 3

local tierByNumber = {}
for _, tier in Config.Treadmills do
	tierByNumber[tier.Tier] = tier
end

local treadmills = {} -- { Belt, Tier }
local lastNotice = {} -- [Player] = time of last "need more Speed" message

local function isOnBelt(belt, position)
	local localPos = belt.CFrame:PointToObjectSpace(position)
	local half = belt.Size / 2
	return math.abs(localPos.X) <= half.X + 0.5 and math.abs(localPos.Z) <= half.Z and localPos.Y > 0 and localPos.Y < 6
end

local function tick()
	local now = time()
	for _, player in Players:GetPlayers() do
		local session = Session.Get(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if session and session.Loaded and humanoid and root and humanoid.Health > 0 then
			for _, treadmill in treadmills do
				if isOnBelt(treadmill.Belt, root.Position) then
					local tier = treadmill.Tier
					if session.Speed >= tier.Required then
						if session.Speed < Config.MaxSpeed then
							if Session.AddSpeed(player, tier.Rate * TICK) then
								PlotService.RefreshWalkSpeed(player)
							end
						end
					elseif now - (lastNotice[player] or -math.huge) >= NOTICE_COOLDOWN then
						lastNotice[player] = now
						Remotes.Notify(
							player,
							"You need " .. tier.Required .. " Speed for this treadmill!",
							Color3.fromRGB(255, 150, 40)
						)
					end
					break -- only one treadmill counts at a time
				end
			end
		end
	end
end

function TreadmillService.Init(treadmillModels)
	for _, model in treadmillModels do
		local tier = tierByNumber[model:GetAttribute("Tier")]
		local belt = model:FindFirstChild("Belt")
		if tier and belt and belt:IsA("BasePart") then
			-- An anchored part with a velocity works like a conveyor: it pushes whoever stands on it.
			-- The runner faces the belt's LookVector, so it pushes the opposite way.
			belt.AssemblyLinearVelocity = -belt.CFrame.LookVector * tier.PushSpeed
			table.insert(treadmills, { Belt = belt, Tier = tier })

			local console = model:FindFirstChild("Console")
			if console then
				local text = "TIER " .. tier.Tier .. "  +" .. tier.Rate .. " Speed/s"
				if tier.Required > 0 then
					text ..= "\nNeeds " .. tier.Required .. " Speed"
				end
				MapBuilder.NewBillboard(console, 9, 2.6, Vector3.new(0, 3, 0), text, Color3.fromRGB(255, 255, 255), 80)
			end
		else
			warn("[StealTheAuraEgg] Treadmill " .. model:GetFullName() .. " is missing its Belt or has an unknown Tier")
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastNotice[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(tick)
			if not ok then
				warn("[StealTheAuraEgg] Treadmill error: " .. tostring(err))
			end
		end
	end)
end

return TreadmillService
