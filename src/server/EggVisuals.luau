--[[
	EggVisuals
	Builds the 3D model for an Aura Egg: an egg-shaped core, a glowing band,
	an aura shell, sparkle particles and a light. Higher rarities are
	bigger and glow more. Secret eggs get a rainbow aura (animated by the client).

	Also shared with PetVisuals: the aura effects (AddEffects) and the floating
	name tag (AddInfo).

	Every item model gets these attributes: EggId, Mutation (optional),
	Hatched (true for animals), BottomOffset (studs from the core's centre down
	to the model's bottom) and TopOffset (from the centre up to the top).
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

function EggVisuals.MakeEllipsoid(name, size, color, material, transparency, anchored)
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
	mesh.MeshType = Enum.MeshType.Sphere -- a Sphere SpecialMesh stretches to the part size
	mesh.Parent = part
	return part
end

function EggVisuals.Weld(part0, part1)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part1
end

-- Rarity scale used for eggs and animals: Common 1.0 ... Secret 1.6
function EggVisuals.RarityScale(def)
	return 1 + 0.1 * (Config.GetRarity(def.Rarity).Index - 1)
end

-- Aura shell, sparkles, light and mutation effects around `core`.
-- shellSize = size of the glowing aura ellipsoid (centred on the core).
function EggVisuals.AddEffects(model, core, def, mutationName, shellSize, anchored)
	local rarity = Config.GetRarity(def.Rarity)
	local scale = EggVisuals.RarityScale(def)
	local mutation = Config.GetMutation(mutationName)
	local isSecret = def.Rarity == "Secret"

	local strongAura = rarity.Index >= 4 -- Epic and above get the shimmering force-field aura
	local shell = EggVisuals.MakeEllipsoid(
		"Aura",
		shellSize,
		def.AuraColor,
		strongAura and Enum.Material.ForceField or Enum.Material.Neon,
		strongAura and 0 or 0.82,
		anchored
	)
	shell.CanQuery = false
	shell.CFrame = CFrame.new(core.Position)
	shell.Parent = model
	EggVisuals.Weld(core, shell)
	if isSecret then
		CollectionService:AddTag(shell, "RainbowAura")
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
		local stormShell = EggVisuals.MakeEllipsoid(
			"MutationAura",
			shellSize * 1.2,
			mutation.Color,
			Enum.Material.ForceField,
			0,
			anchored
		)
		stormShell.CanQuery = false
		stormShell.CFrame = CFrame.new(core.Position)
		stormShell.Parent = model
		EggVisuals.Weld(core, stormShell)

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
end

-- Sets the attributes every item model carries.
function EggVisuals.Tag(model, def, mutationName, hatched, bottomOffset, topOffset)
	local mutation = Config.GetMutation(mutationName)
	model.Name = Config.GetEggDisplayName(def.Id, mutationName, hatched)
	model:SetAttribute("EggId", def.Id)
	model:SetAttribute("Hatched", hatched == true)
	if mutation then
		model:SetAttribute("Mutation", mutation.Name)
	end
	model:SetAttribute("BottomOffset", bottomOffset)
	model:SetAttribute("TopOffset", topOffset)
end

-- Returns model, eggDefinition, corePart. The model's PrimaryPart is the core.
-- mutationName (optional), e.g. "Storm", adds the mutation's look.
function EggVisuals.Create(eggId, anchored, mutationName)
	local def = Config.GetEgg(eggId)
	assert(def, "Unknown egg id: " .. tostring(eggId))
	local scale = EggVisuals.RarityScale(def)

	local model = Instance.new("Model")

	local core =
		EggVisuals.MakeEllipsoid("Core", BASE_SIZE * scale, def.EggColor, Enum.Material.SmoothPlastic, 0, anchored)
	core.CastShadow = true
	core.CFrame = CFrame.new()
	core.Parent = model

	local band = EggVisuals.MakeEllipsoid(
		"Band",
		Vector3.new(core.Size.X * 1.04, 0.45 * scale, core.Size.Z * 1.04),
		def.AuraColor,
		Enum.Material.Neon,
		0,
		anchored
	)
	band.CFrame = CFrame.new(0, -0.15 * scale, 0)
	band.Parent = model
	EggVisuals.Weld(core, band)
	if def.Rarity == "Secret" then
		CollectionService:AddTag(band, "RainbowAura")
	end

	EggVisuals.AddEffects(model, core, def, mutationName, core.Size * 1.35, anchored)
	EggVisuals.Tag(model, def, mutationName, false, core.Size.Y / 2, core.Size.Y / 2)

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

-- Adds the floating name / rarity / income text above an egg or animal.
-- extraText (optional) adds one more line, e.g. the price on the belt or the hatch timer.
-- Returns the BillboardGui and the extra line's TextLabel (nil without extraText).
function EggVisuals.AddInfo(model, extraText, extraColor)
	local core = model.PrimaryPart
	local def = Config.GetEgg(model:GetAttribute("EggId"))
	local rarity = Config.GetRarity(def.Rarity)
	local mutationName = model:GetAttribute("Mutation")
	local mutation = Config.GetMutation(mutationName)
	local hatched = model:GetAttribute("Hatched") == true
	local topOffset = model:GetAttribute("TopOffset") or core.Size.Y / 2

	local lines = {
		{ hatched and def.PetName or def.Name, Color3.fromRGB(255, 255, 255), false },
		{ def.Rarity .. (hatched and " Animal" or ""), rarity.Color, def.Rarity == "Secret" },
	}
	if mutation then
		table.insert(lines, { string.upper(mutation.Name) .. " x" .. mutation.IncomeMultiplier, mutation.Color, false })
	end
	table.insert(lines, {
		Config.FormatCash(Config.GetEggIncome(def.Id, mutationName, hatched)) .. "/s",
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
	gui.StudsOffset = Vector3.new(0, topOffset + 0.6 + 0.4 * #lines, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 70

	local extraLabel = nil
	for index, line in lines do
		local label = addLine(gui, line[1], line[2], index, #lines, line[3])
		if extraText and index == #lines then
			extraLabel = label
		end
	end

	gui.Parent = core
	return gui, extraLabel
end

return EggVisuals
