--[[
	PetVisuals
	Builds the animal that hatches out of an Aura Egg.

	Real 3D models: import models/pets/<Shape>.fbx with Studio's 3D Importer and
	put the result in ReplicatedStorage.PetModels, named after the shape
	(Bunny, Bear, Frog, Cat, Fox, Bird, Dragon). Their mesh parts are recoloured
	by name: Body = egg colour, Accent = aura colour, Eyes = black,
	Shine = white, Detail = nose / beak / horns colour.

	Until a shape is imported, the same animal is built from simple parts
	(PetShapes.luau, generated together with the FBX files).

	The model is turned to face -Z automatically (using where its eyes are),
	scaled to its rarity's size, and gets the same aura effects as eggs.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EggVisuals = require(script.Parent.EggVisuals)
local PetShapes = require(script.Parent.PetShapes)

local PetVisuals = {}

local BASE_LENGTH = 3.4 -- studs from nose to tail for a Common animal
local GROUPS = { "body", "accent", "eyes", "shine", "detail" }
local EYE_COLOR = Color3.fromRGB(20, 20, 25)
local SHINE_COLOR = Color3.fromRGB(255, 255, 255)

local function groupOf(part)
	local name = string.lower(part.Name)
	for _, group in GROUPS do
		if string.sub(name, 1, #group) == group then
			return group
		end
	end
	return nil
end

local function collectParts(model)
	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- Simple-parts version from PetShapes.
local function buildFallback(shapeData)
	local model = Instance.new("Model")
	local body = nil
	for _, piece in shapeData.Pieces do
		local part = EggVisuals.MakeEllipsoid(piece.Group, piece.Size, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 0, true)
		part.CFrame = piece.CFrame
		part.Parent = model
		if body == nil and piece.Group == "Body" then
			body = part
		end
	end
	return model, body
end

-- Imported mesh version. Returns nil if the template has no parts.
local function buildFromTemplate(template)
	local clone = template:Clone()
	local parts = collectParts(clone)
	if #parts == 0 then
		clone:Destroy()
		return nil, nil
	end

	local model = Instance.new("Model")
	for _, part in parts do
		part.Parent = model -- flatten any folders / sub-models the importer made
	end
	clone:Destroy()

	local body = nil
	for _, part in parts do
		if groupOf(part) == "body" then
			body = part
			break
		end
	end
	if not body then
		local bestVolume = -1
		for _, part in parts do
			local volume = part.Size.X * part.Size.Y * part.Size.Z
			if volume > bestVolume then
				bestVolume = volume
				body = part
			end
		end
	end

	-- Turn the animal so its eyes point towards -Z, whatever axes the import used.
	local eyeSum = Vector3.zero
	local eyeCount = 0
	for _, part in parts do
		if groupOf(part) == "eyes" then
			eyeSum += part.Position
			eyeCount += 1
		end
	end
	if eyeCount > 0 then
		local offset = eyeSum / eyeCount - body.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 0.001 then
			local heading = math.atan2(-flat.X, -flat.Z)
			local turn = CFrame.new(body.Position) * CFrame.Angles(0, -heading, 0) * CFrame.new(-body.Position)
			for _, part in parts do
				part.CFrame = turn * part.CFrame
			end
		end
	end

	return model, body
end

local function scaleParts(parts, origin, factor)
	for _, part in parts do
		local rotation = part.CFrame.Rotation
		local position = origin + (part.Position - origin) * factor
		part.Size = part.Size * factor
		part.CFrame = CFrame.new(position) * rotation
	end
end

local function style(parts, body, def, shapeData, anchored)
	local rarity = Config.GetRarity(def.Rarity)
	local glowAccent = rarity.Index >= 4 -- Epic and above: glowing aura markings
	for _, part in parts do
		part.Anchored = anchored
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = part == body
		part.CastShadow = true
		local group = groupOf(part)
		if group == "body" then
			part.Color = def.EggColor
			part.Material = Enum.Material.SmoothPlastic
		elseif group == "accent" then
			part.Color = def.AuraColor
			part.Material = glowAccent and Enum.Material.Neon or Enum.Material.SmoothPlastic
			if def.Rarity == "Secret" then
				CollectionService:AddTag(part, "RainbowAura")
			end
		elseif group == "eyes" then
			part.Color = EYE_COLOR
			part.Material = Enum.Material.SmoothPlastic
		elseif group == "shine" then
			part.Color = SHINE_COLOR
			part.Material = Enum.Material.Neon
			part.CastShadow = false
		elseif group == "detail" then
			part.Color = shapeData.DetailColor
			part.Material = Enum.Material.SmoothPlastic
		end
		if part ~= body then
			EggVisuals.Weld(body, part)
		end
	end
end

-- Returns model, eggDefinition, bodyPart (the model's PrimaryPart), like EggVisuals.Create.
function PetVisuals.Create(eggId, anchored, mutationName)
	local def = Config.GetEgg(eggId)
	assert(def, "Unknown egg id: " .. tostring(eggId))
	local shapeName = def.PetShape or "Bunny"
	local shapeData = PetShapes[shapeName] or PetShapes.Bunny

	local model, body = nil, nil
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	local template = folder and folder:FindFirstChild(shapeName)
	if template then
		local ok, builtModel, builtBody = pcall(buildFromTemplate, template)
		if ok and builtModel then
			model, body = builtModel, builtBody
		elseif not ok then
			warn("[StealTheAuraEgg] Could not use PetModels." .. shapeName .. ": " .. tostring(builtModel))
		end
	end
	if not model then
		model, body = buildFallback(shapeData)
	end

	local parts = collectParts(model)

	-- Move the body to the origin, then scale the whole animal to its rarity size.
	local shift = -body.Position
	for _, part in parts do
		part.CFrame = part.CFrame + shift
	end
	local minPoint = Vector3.new(math.huge, math.huge, math.huge)
	local maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)
	local function measure()
		minPoint = Vector3.new(math.huge, math.huge, math.huge)
		maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, part in parts do
			-- world-space extents of the part's box
			local half = part.Size / 2
			local cf = part.CFrame
			local extent = Vector3.new(
				math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z,
				math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z,
				math.abs(cf.RightVector.Z) * half.X + math.abs(cf.UpVector.Z) * half.Y + math.abs(cf.LookVector.Z) * half.Z
			)
			local low = cf.Position - extent
			local high = cf.Position + extent
			minPoint = Vector3.new(math.min(minPoint.X, low.X), math.min(minPoint.Y, low.Y), math.min(minPoint.Z, low.Z))
			maxPoint = Vector3.new(math.max(maxPoint.X, high.X), math.max(maxPoint.Y, high.Y), math.max(maxPoint.Z, high.Z))
		end
	end
	measure()
	local size = maxPoint - minPoint
	local longest = math.max(size.X, size.Z, 0.01)
	scaleParts(parts, Vector3.zero, BASE_LENGTH * EggVisuals.RarityScale(def) / longest)
	measure()
	size = maxPoint - minPoint

	-- The pivot is a world-aligned frame at the body, so "forward" is always -Z.
	body.PivotOffset = body.CFrame:Inverse() * CFrame.new(body.Position)
	model.PrimaryPart = body

	style(parts, body, def, shapeData, anchored)
	EggVisuals.AddEffects(model, body, def, mutationName, size * 1.25, anchored)
	-- body is at the origin, so the extents are the offsets to the bottom and top
	EggVisuals.Tag(model, def, mutationName, true, -minPoint.Y, maxPoint.Y)
	return model, def, body
end

-- Egg or animal, depending on `hatched`.
function PetVisuals.CreateItem(eggId, anchored, mutationName, hatched)
	if hatched then
		return PetVisuals.Create(eggId, anchored, mutationName)
	end
	return EggVisuals.Create(eggId, anchored, mutationName)
end

return PetVisuals
