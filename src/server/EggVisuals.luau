--[[
	EggVisuals
	Builds the 3D model for an Aura Egg: an egg-shaped core, a glowing band,
	an aura shell, sparkle particles and a light. Higher rarities are
	bigger and glow more. Secret eggs get a rainbow aura (animated by the client).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local EggVisuals = {}

local BASE_SIZE = Vector3.new(2.6, 3.4, 2.6)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 255, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(120, 80, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 200)),
})

local function makeEllipsoid(name, size, color, material, transparency, anchored)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	part.Anchored = anchored
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere -- a Sphere SpecialMesh stretches to the part size, giving an egg shape
	mesh.Parent = part
	return part
end

local function weld(part0, part1)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part1
end

-- Returns model, eggDefinition, corePart. The model's PrimaryPart is the core.
-- mutationName (optional), e.g. "Storm", adds the mutation's look.
function EggVisuals.Create(eggId, anchored, mutationName)
	local def = Config.GetEgg(eggId)
	assert(def, "Unknown egg id: " .. tostring(eggId))
	local rarity = Config.GetRarity(def.Rarity)
	local scale = 1 + 0.1 * (rarity.Index - 1)
	local isSecret = def.Rarity == "Secret"

	local model = Instance.new("Model")
	local mutation = Config.GetMutation(mutationName)
	model.Name = Config.GetEggDisplayName(def.Id, mutationName)
	model:SetAttribute("EggId", def.Id)
	if mutation then
		model:SetAttribute("Mutation", mutation.Name)
	end

	local core = makeEllipsoid("Core", BASE_SIZE * scale, def.EggColor, Enum.Material.SmoothPlastic, 0, anchored)
	core.CastShadow = true
	core.CFrame = CFrame.new()
	core.Parent = model

	local band = makeEllipsoid(
		"Band",
		Vector3.new(core.Size.X * 1.04, 0.45 * scale, core.Size.Z * 1.04),
		def.AuraColor,
		Enum.Material.Neon,
		0,
		anchored
	)
	band.CFrame = CFrame.new(0, -0.15 * scale, 0)
	band.Parent = model
	weld(core, band)

	local strongAura = rarity.Index >= 4 -- Epic and above get the shimmering force-field aura
	local shell = makeEllipsoid(
		"Aura",
		core.Size * 1.35,
		def.AuraColor,
		strongAura and Enum.Material.ForceField or Enum.Material.Neon,
		strongAura and 0 or 0.82,
		anchored
	)
	shell.CFrame = CFrame.new()
	shell.Parent = model
	weld(core, shell)

	if isSecret then
		CollectionService:AddTag(shell, "RainbowAura")
		CollectionService:AddTag(band, "RainbowAura")
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "AuraAttachment"
	attachment.Parent = core

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AuraSparkles"
	emitter.Color = isSecret and RAINBOW or ColorSequence.new(def.AuraColor)
	emitter.LightEmission = 1
	emitter.Rate = 4 + rarity.Index * 4
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment

	local light = Instance.new("PointLight")
	light.Color = def.AuraColor
	light.Brightness = 1 + rarity.Index * 0.3
	light.Range = 6 + rarity.Index
	light.Shadows = false
	light.Parent = core

	if mutation then
		-- Storm-charged: an electric outer shell, crackling sparks and a blue glow
		local stormShell = makeEllipsoid(
			"MutationAura",
			core.Size * 1.6,
			mutation.Color,
			Enum.Material.ForceField,
			0,
			anchored
		)
		stormShell.CFrame = CFrame.new()
		stormShell.Parent = model
		weld(core, stormShell)

		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "MutationSparks"
		sparks.Color = ColorSequence.new(mutation.Color)
		sparks.LightEmission = 1
		sparks.Rate = 25
		sparks.Lifetime = NumberRange.new(0.15, 0.35)
		sparks.Speed = NumberRange.new(6, 10)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparks.Parent = attachment

		local stormLight = Instance.new("PointLight")
		stormLight.Name = "MutationLight"
		stormLight.Color = mutation.Color
		stormLight.Brightness = 2.5
		stormLight.Range = 12
		stormLight.Shadows = false
		stormLight.Parent = core
	end

	model.PrimaryPart = core
	return model, def, core
end

local function addLine(gui, text, color, index, count, rainbow)
	local label = Instance.new("TextLabel")
	label.Name = "Line" .. index
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1 / count, 0)
	label.Position = UDim2.new(0, 0, (index - 1) / count, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = gui
	if rainbow then
		CollectionService:AddTag(label, "RainbowText")
	end
	return label
end

-- Adds the floating name / rarity / income text above an egg.
-- extraText (optional) adds one more line, e.g. the price on the belt.
function EggVisuals.AddInfo(model, extraText, extraColor)
	local core = model.PrimaryPart
	local def = Config.GetEgg(model:GetAttribute("EggId"))
	local rarity = Config.GetRarity(def.Rarity)
	local mutationName = model:GetAttribute("Mutation")
	local mutation = Config.GetMutation(mutationName)

	local lines = {
		{ def.Name, Color3.fromRGB(255, 255, 255), false },
		{ def.Rarity, rarity.Color, def.Rarity == "Secret" },
	}
	if mutation then
		table.insert(lines, { string.upper(mutation.Name) .. " x" .. mutation.IncomeMultiplier, mutation.Color, false })
	end
	table.insert(lines, {
		Config.FormatCash(Config.GetEggIncome(def.Id, mutationName)) .. "/s",
		Color3.fromRGB(110, 255, 140),
		false,
	})
	if extraText then
		table.insert(lines, { extraText, extraColor or Color3.fromRGB(255, 220, 70), false })
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "EggInfo"
	gui.Adornee = core
	gui.Size = UDim2.new(7, 0, 0.8 * #lines, 0) -- scale = studs for BillboardGuis
	gui.StudsOffset = Vector3.new(0, core.Size.Y / 2 + 0.6 + 0.4 * #lines, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 70

	for index, line in lines do
		addLine(gui, line[1], line[2], index, #lines, line[3])
	end

	gui.Parent = core
	return gui
end

return EggVisuals
