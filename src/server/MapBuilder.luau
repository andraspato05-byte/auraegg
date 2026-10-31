--[[
	MapBuilder
	Builds the whole world from code when the server starts:
	  - ground, walkway and invisible map borders
	  - the Aura Egg Machine and the conveyor belt down the middle
	  - 8 player bases (4 on each side of the belt), each with
	    10 pedestals, 10 cash pads, a lock pad and a lock barrier

	Returns { Plots = {plotInfo...}, Belt = beltInfo } for the other services.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local PLOT_HALF = 28 -- bases are 56 x 56 studs
local PLOT_X = { -112.5, -37.5, 37.5, 112.5 }
local PLOT_Z = 50
local LAYOUT_PLOTS = 8
local LAYOUT_SLOTS = 10

local BELT_LENGTH = 430
local BELT_WIDTH = 12
local BELT_TOP = 1

local FLOOR_COLORS = {
	Color3.fromRGB(255, 170, 170),
	Color3.fromRGB(255, 205, 140),
	Color3.fromRGB(255, 240, 150),
	Color3.fromRGB(170, 240, 170),
	Color3.fromRGB(150, 220, 255),
	Color3.fromRGB(175, 170, 255),
	Color3.fromRGB(240, 170, 255),
	Color3.fromRGB(170, 255, 230),
}

local function newPart(parent, name, size, cframe, color, material, extra)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for property, value in extra do
			part[property] = value
		end
	end
	part.Parent = parent
	return part
end

-- Floating text attached to a part. size is in studs.
local function newBillboard(adornee, sizeX, sizeY, offset, text, color, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = adornee
	gui.Size = UDim2.new(sizeX, 0, sizeY, 0)
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 150

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = gui

	gui.Parent = adornee
	return label
end

local function buildEnvironment(mapFolder)
	-- Ground (top surface at Y = 0)
	newPart(mapFolder, "Ground", Vector3.new(520, 2, 340), CFrame.new(0, -1, 0), Color3.fromRGB(96, 176, 82), Enum.Material.Grass)

	-- Walkway along the belt
	newPart(mapFolder, "Walkway", Vector3.new(470, 0.2, 40), CFrame.new(0, 0.1, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Concrete)

	-- Invisible borders so nobody walks off the map
	local borderProps = { Transparency = 1, CanQuery = false, CastShadow = false }
	newPart(mapFolder, "BorderN", Vector3.new(520, 80, 2), CFrame.new(0, 40, 171), Color3.new(), nil, borderProps)
	newPart(mapFolder, "BorderS", Vector3.new(520, 80, 2), CFrame.new(0, 40, -171), Color3.new(), nil, borderProps)
	newPart(mapFolder, "BorderE", Vector3.new(2, 80, 340), CFrame.new(261, 40, 0), Color3.new(), nil, borderProps)
	newPart(mapFolder, "BorderW", Vector3.new(2, 80, 340), CFrame.new(-261, 40, 0), Color3.new(), nil, borderProps)

	-- Conveyor belt (top surface at Y = BELT_TOP)
	newPart(
		mapFolder,
		"ConveyorBelt",
		Vector3.new(BELT_LENGTH, 1, BELT_WIDTH),
		CFrame.new(0, BELT_TOP - 0.5, 0),
		Color3.fromRGB(40, 40, 50),
		Enum.Material.DiamondPlate
	)
	for _, side in { -1, 1 } do
		newPart(
			mapFolder,
			"BeltRail",
			Vector3.new(BELT_LENGTH, 1.6, 1),
			CFrame.new(0, 1, side * (BELT_WIDTH / 2 + 0.5)),
			Color3.fromRGB(160, 90, 255),
			Enum.Material.Neon
		)
	end
	for x = -200, 200, 16 do
		newPart(
			mapFolder,
			"BeltArrow",
			Vector3.new(0.6, 0.05, BELT_WIDTH - 4),
			CFrame.new(x, BELT_TOP + 0.03, 0),
			Color3.fromRGB(150, 100, 255),
			Enum.Material.Neon,
			{ CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 0.3 }
		)
	end

	-- The Aura Egg Machine where eggs come out
	local machineX = -(BELT_LENGTH / 2) - 7
	local machine = newPart(mapFolder, "AuraEggMachine", Vector3.new(14, 20, 24), CFrame.new(machineX, 10, 0), Color3.fromRGB(70, 40, 120))
	newPart(mapFolder, "MachineGlow", Vector3.new(14.4, 1.5, 24.4), CFrame.new(machineX, 16, 0), Color3.fromRGB(200, 120, 255), Enum.Material.Neon)
	newPart(mapFolder, "MachineMouth", Vector3.new(0.4, 7, 12), CFrame.new(machineX + 7.1, 4.5, 0), Color3.fromRGB(10, 5, 20), Enum.Material.Neon)
	newBillboard(machine, 26, 5, Vector3.new(0, 14, 0), "AURA EGG MACHINE", Color3.fromRGB(230, 180, 255), 400)

	-- Where unsold eggs leave the belt
	local drainX = (BELT_LENGTH / 2) + 7
	newPart(mapFolder, "EggDrain", Vector3.new(14, 12, 24), CFrame.new(drainX, 6, 0), Color3.fromRGB(45, 30, 70))
	newPart(mapFolder, "DrainMouth", Vector3.new(0.4, 7, 12), CFrame.new(drainX - 7.1, 4.5, 0), Color3.fromRGB(10, 5, 20), Enum.Material.Neon)

	-- Big title floating over the middle of the map
	local titleAnchor = newPart(
		mapFolder,
		"TitleAnchor",
		Vector3.new(1, 1, 1),
		CFrame.new(0, 34, 0),
		Color3.new(),
		nil,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }
	)
	newBillboard(titleAnchor, 80, 12, Vector3.new(), string.upper(Config.GameName), Color3.fromRGB(200, 140, 255), 800)

	-- Neutral spawn (players are moved to their own base right after spawning)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.7, 14)
	spawn.Color = Color3.fromRGB(180, 120, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = mapFolder
end

local function buildPlot(index, plotCFrame, parent)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")

	-- Local plot space: center of the floor at the origin, the entrance is on the -Z side.
	local function at(x, y, z)
		return plotCFrame * CFrame.new(x, y, z)
	end

	local floorColor = FLOOR_COLORS[index] or FLOOR_COLORS[1]
	local wallColor = Color3.fromRGB(235, 235, 245)
	local size = PLOT_HALF * 2

	newPart(model, "Floor", Vector3.new(size, 1, size), at(0, 0.5, 0), floorColor)
	newPart(model, "BackWall", Vector3.new(size, 12, 1), at(0, 7, PLOT_HALF - 0.5), wallColor)
	newPart(model, "LeftWall", Vector3.new(1, 12, size), at(-(PLOT_HALF - 0.5), 7, 0), wallColor)
	newPart(model, "RightWall", Vector3.new(1, 12, size), at(PLOT_HALF - 0.5, 7, 0), wallColor)
	newPart(model, "FrontWallLeft", Vector3.new(20, 12, 1), at(-18, 7, -(PLOT_HALF - 0.5)), wallColor)
	newPart(model, "FrontWallRight", Vector3.new(20, 12, 1), at(18, 7, -(PLOT_HALF - 0.5)), wallColor)
	newPart(model, "WallTrim", Vector3.new(size, 0.6, 1.2), at(0, 13.3, PLOT_HALF - 0.5), floorColor, Enum.Material.Neon)

	-- The lock barrier fills the 16-stud entrance gap. Invisible and walk-through until locked.
	local barrier = newPart(
		model,
		"LockBarrier",
		Vector3.new(16, 12, 1),
		at(0, 7, -(PLOT_HALF - 0.5)),
		Color3.fromRGB(255, 50, 50),
		Enum.Material.ForceField,
		{ CanCollide = false, Transparency = 1, CastShadow = false, CanTouch = false }
	)

	-- Owner name over the entrance
	local signAnchor = newPart(
		model,
		"SignAnchor",
		Vector3.new(1, 1, 1),
		at(0, 16, -(PLOT_HALF - 0.5)),
		Color3.new(),
		nil,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }
	)
	local signLabel = newBillboard(signAnchor, 22, 3.5, Vector3.new(), "Empty Base", Color3.fromRGB(255, 255, 255), 250)

	-- Pedestals: two columns of 5, cash pad next to each one (towards the middle aisle)
	local slots = {}
	for slotIndex = 1, LAYOUT_SLOTS do
		local column = slotIndex <= 5 and -1 or 1
		local row = (slotIndex - 1) % 5
		local x = 17 * column
		local z = -16 + row * 9

		local pedestal = newPart(
			model,
			"Pedestal" .. slotIndex,
			Vector3.new(6, 1.5, 6),
			at(x, 1.75, z),
			Color3.fromRGB(245, 245, 250),
			Enum.Material.Marble
		)
		newPart(model, "PedestalRim" .. slotIndex, Vector3.new(6.4, 0.3, 6.4), at(x, 2.35, z), floorColor, Enum.Material.Neon)

		local padX = x - 5.5 * column
		local pad = newPart(
			model,
			"CashPad" .. slotIndex,
			Vector3.new(4, 0.3, 4),
			at(padX, 1.15, z),
			Color3.fromRGB(70, 230, 110),
			Enum.Material.Neon,
			{ CanCollide = false, CanTouch = false }
		)
		local padLabel = newBillboard(pad, 5, 1.4, Vector3.new(0, 2.2, 0), "", Color3.fromRGB(120, 255, 140), 60)

		slots[slotIndex] = {
			Pedestal = pedestal,
			EggBaseCFrame = at(x, 2.5, z), -- top centre of the pedestal
			PadLocal = Vector3.new(padX, 0, z),
			PadLabel = padLabel,
		}
	end

	-- Lock pad at the back of the base
	local lockPadLocal = Vector3.new(0, 0, 22)
	local lockPad = newPart(
		model,
		"LockPad",
		Vector3.new(6, 0.3, 4),
		at(lockPadLocal.X, 1.15, lockPadLocal.Z),
		Color3.fromRGB(255, 70, 70),
		Enum.Material.Neon,
		{ CanCollide = false, CanTouch = false }
	)
	local lockLabel = newBillboard(lockPad, 8, 1.6, Vector3.new(0, 2.5, 0), "", Color3.fromRGB(255, 255, 255), 80)

	local eggsFolder = Instance.new("Folder")
	eggsFolder.Name = "Eggs"
	eggsFolder.Parent = model

	model.Parent = parent

	return {
		Index = index,
		Model = model,
		CFrame = plotCFrame,
		HalfSize = PLOT_HALF,
		Barrier = barrier,
		SignLabel = signLabel,
		Slots = slots,
		LockPadLocal = lockPadLocal,
		LockLabel = lockLabel,
		EggsFolder = eggsFolder,
		SpawnCFrame = at(0, 4, 6), -- facing the entrance
		EjectCFrame = at(0, 4, -38), -- just outside the entrance, on the walkway
	}
end

function MapBuilder.Build()
	assert(Config.MaxPlots <= LAYOUT_PLOTS, "The map only has room for " .. LAYOUT_PLOTS .. " bases")
	assert(Config.SlotsPerPlot == LAYOUT_SLOTS, "Each base is built with exactly " .. LAYOUT_SLOTS .. " pedestals")

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	buildEnvironment(mapFolder)
	mapFolder.Parent = workspace

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	local plots = {}
	for index = 1, Config.MaxPlots do
		local column = ((index - 1) % 4) + 1
		local side = index <= 4 and -1 or 1
		-- Rotate so every base's entrance (local -Z) faces the belt at Z = 0.
		local rotation = side == -1 and CFrame.Angles(0, math.pi, 0) or CFrame.new()
		local plotCFrame = CFrame.new(PLOT_X[column], 0, PLOT_Z * side) * rotation
		plots[index] = buildPlot(index, plotCFrame, plotsFolder)
	end

	return {
		Plots = plots,
		Belt = {
			StartX = -(BELT_LENGTH / 2) + 3,
			EndX = (BELT_LENGTH / 2) - 3,
			Z = 0,
			SurfaceY = BELT_TOP,
		},
	}
end

return MapBuilder
