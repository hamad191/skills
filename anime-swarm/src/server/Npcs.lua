-- Island NPCs: trainers, the gear smith, the upgrades bar and the store. Each one is a real R15
-- character in their own outfit, standing at their own stall (training dummies, a clinic, a
-- shipyard forge, a bar, a circus tent). Clients animate them (client/Rigs.lua). Each has a
-- prompt ("E" on keyboard, tap on phones) that opens its menu on the client.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(RS.Shared.Config)

local Npcs = {}

local SKIN = Color3.fromRGB(255, 205, 160)
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder standing upright
local FORWARD = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder pointing forward
local CYL, BALL, WEDGE = Enum.PartType.Cylinder, Enum.PartType.Ball, Enum.PartType.Wedge
local WOOD, PLANKS, METAL, NEON, FABRIC, SLATE, GLASS =
	Enum.Material.Wood, Enum.Material.WoodPlanks, Enum.Material.Metal, Enum.Material.Neon, Enum.Material.Fabric, Enum.Material.Slate, Enum.Material.Glass

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function makePart(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanTouch, p.CastShadow = true, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function groundY(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), params)
	return hit and hit.Position.Y or pos.Y
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.LuckiestGuy
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Outfits ---------------------------------------------------------------------------------
-- colors: body part colors. pieces: { body part, size, offset, color, shape?, material? },
-- measured on a default R15 body (head 1.2 tall, upper torso 1.6 tall); they follow the
-- actual part sizes. The head faces -Z; its top is at +0.6.

local NOMINAL_HEIGHT = {
	Head = 1.2, UpperTorso = 1.6, LowerTorso = 0.4, RightHand = 0.3, LeftHand = 0.3,
	RightUpperArm = 1.17, LeftUpperArm = 1.17, RightLowerArm = 1.05, LeftLowerArm = 1.05,
}

local function bodyColors(skin, shirt, sleeves, forearms, belt, pants, shoes, hands)
	return {
		Head = skin, UpperTorso = shirt, LowerTorso = belt,
		LeftUpperArm = sleeves, RightUpperArm = sleeves, LeftLowerArm = forearms, RightLowerArm = forearms,
		LeftHand = hands or skin, RightHand = hands or skin,
		LeftUpperLeg = pants, RightUpperLeg = pants, LeftLowerLeg = pants, RightLowerLeg = pants,
		LeftFoot = shoes, RightFoot = shoes,
	}
end

local function lens(x, color)
	return { "Head", Vector3.new(0.06, 0.34, 0.34), CFrame.new(x, 0.08, -0.63) * FORWARD, color, CYL, GLASS }
end

local LOOKS = {
	Rayleigh = {
		scale = 1.05,
		colors = bodyColors(rgb(238, 196, 160), rgb(232, 230, 222), rgb(232, 230, 222), rgb(232, 230, 222), rgb(90, 70, 50), rgb(95, 75, 55), rgb(60, 45, 35)),
		pieces = {
			{ "Head", Vector3.new(1.26, 0.35, 1.28), Vector3.new(0, 0.5, 0.06), rgb(240, 240, 240) },
			{ "Head", Vector3.new(1.26, 0.9, 0.3), Vector3.new(0, 0.05, 0.52), rgb(240, 240, 240) },
			{ "Head", Vector3.new(0.12, 0.6, 0.9), Vector3.new(-0.62, 0.15, 0.15), rgb(240, 240, 240) },
			{ "Head", Vector3.new(0.12, 0.6, 0.9), Vector3.new(0.62, 0.15, 0.15), rgb(240, 240, 240) },
			{ "Head", Vector3.new(0.9, 0.45, 0.3), Vector3.new(0, -0.5, -0.48), rgb(245, 245, 245) },
			{ "Head", Vector3.new(0.7, 0.12, 0.1), Vector3.new(0, -0.2, -0.62), rgb(245, 245, 245) },
			lens(-0.24, rgb(40, 40, 50)),
			lens(0.24, rgb(40, 40, 50)),
			{ "Head", Vector3.new(0.16, 0.04, 0.04), Vector3.new(0, 0.1, -0.63), rgb(40, 40, 50) },
			{ "Head", Vector3.new(0.06, 0.62, 0.03), CFrame.new(0.26, 0.1, -0.655) * CFrame.Angles(0, 0, 0.25), rgb(150, 60, 60) },
			-- his sword at the hip
			{ "LowerTorso", Vector3.new(0.24, 0.24, 3.0), CFrame.new(-1.05, -0.1, 0.3) * CFrame.Angles(math.rad(55), 0, 0), rgb(25, 25, 30) },
			{ "LowerTorso", Vector3.new(0.3, 0.3, 0.12), CFrame.new(-1.05, 0.95, -0.55) * CFrame.Angles(math.rad(55), 0, 0), rgb(200, 170, 60), nil, METAL },
		},
	},
	Kureha = {
		scale = 1,
		colors = bodyColors(rgb(235, 195, 165), rgb(160, 70, 170), rgb(235, 195, 165), rgb(235, 195, 165), rgb(235, 195, 165), rgb(110, 50, 120), rgb(25, 25, 30)),
		pieces = {
			{ "Head", Vector3.new(1.3, 0.4, 1.3), Vector3.new(0, 0.48, 0.05), rgb(225, 225, 235) },
			{ "Head", Vector3.new(1.3, 2.4, 0.35), Vector3.new(0, -0.55, 0.55), rgb(225, 225, 235) },
			{ "Head", Vector3.new(0.15, 1.2, 0.5), Vector3.new(-0.65, -0.2, 0), rgb(225, 225, 235) },
			{ "Head", Vector3.new(0.15, 1.2, 0.5), Vector3.new(0.65, -0.2, 0), rgb(225, 225, 235) },
			{ "Head", Vector3.new(1.0, 0.24, 0.06), Vector3.new(0, 0.1, -0.63), rgb(120, 40, 140), nil, GLASS },
			-- a bottle of sake
			{ "RightHand", Vector3.new(0.8, 0.42, 0.42), CFrame.new(0, -0.5, -0.1) * UPRIGHT, rgb(225, 240, 245), CYL, GLASS },
			{ "RightHand", Vector3.new(0.35, 0.18, 0.18), CFrame.new(0, -0.02, -0.1) * UPRIGHT, rgb(225, 240, 245), CYL, GLASS },
			{ "UpperTorso", Vector3.new(0.5, 0.5, 0.06), CFrame.new(0, 0.2, -0.53) * CFrame.Angles(0, 0, math.pi / 4), rgb(240, 240, 245) },
		},
	},
	Tom = {
		scale = 1.3,
		colors = bodyColors(rgb(95, 150, 190), rgb(225, 200, 150), rgb(225, 200, 150), rgb(95, 150, 190), rgb(120, 80, 45), rgb(50, 70, 120), rgb(110, 70, 40)),
		pieces = {
			-- leather apron and tool pouches
			{ "UpperTorso", Vector3.new(1.7, 1.5, 0.08), Vector3.new(0, -0.05, -0.53), rgb(120, 80, 45), nil, Enum.Material.Leather },
			{ "LowerTorso", Vector3.new(1.7, 1.4, 0.08), Vector3.new(0, -0.5, -0.53), rgb(120, 80, 45), nil, Enum.Material.Leather },
			{ "LowerTorso", Vector3.new(0.4, 0.5, 0.4), Vector3.new(-0.85, -0.1, -0.2), rgb(90, 60, 35) },
			{ "LowerTorso", Vector3.new(0.4, 0.5, 0.4), Vector3.new(0.85, -0.1, -0.2), rgb(90, 60, 35) },
			-- headband, fin and big grin
			{ "Head", Vector3.new(0.2, 1.25, 1.25), CFrame.new(0, 0.3, 0) * UPRIGHT, rgb(200, 50, 40), CYL, FABRIC },
			{ "Head", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 0.3, 0.65), rgb(200, 50, 40), BALL, FABRIC },
			{ "Head", Vector3.new(0.25, 0.8, 0.9), Vector3.new(0, 0.6, 0.3), rgb(70, 120, 160), WEDGE },
			{ "Head", Vector3.new(0.75, 0.18, 0.12), Vector3.new(0, -0.3, -0.6), rgb(240, 240, 240) },
			-- the hammer
			{ "RightHand", Vector3.new(0.22, 0.22, 2.2), Vector3.new(0, -0.1, -1.0), rgb(130, 90, 50), nil, WOOD },
			{ "RightHand", Vector3.new(1.3, 0.7, 0.7), Vector3.new(0, -0.1, -2.1), rgb(90, 95, 105), nil, METAL },
		},
		sparks = true,
	},
	Shakky = {
		scale = 1,
		colors = bodyColors(rgb(240, 205, 175), rgb(30, 30, 35), rgb(240, 205, 175), rgb(240, 205, 175), rgb(60, 40, 70), rgb(40, 40, 50), rgb(150, 30, 40)),
		pieces = {
			{ "Head", Vector3.new(1.28, 0.4, 1.3), Vector3.new(0, 0.45, 0.05), rgb(25, 25, 30) },
			{ "Head", Vector3.new(1.28, 0.8, 0.35), Vector3.new(0, 0.05, 0.5), rgb(25, 25, 30) },
			{ "Head", Vector3.new(0.14, 0.7, 0.9), Vector3.new(-0.63, 0.05, 0.1), rgb(25, 25, 30) },
			{ "Head", Vector3.new(0.14, 0.7, 0.9), Vector3.new(0.63, 0.05, 0.1), rgb(25, 25, 30) },
			{ "Head", Vector3.new(0.15, 0.15, 0.15), Vector3.new(-0.62, -0.25, 0), rgb(240, 200, 60), BALL, METAL },
			{ "Head", Vector3.new(0.15, 0.15, 0.15), Vector3.new(0.62, -0.25, 0), rgb(240, 200, 60), BALL, METAL },
			-- her cigarette (it smokes, see below)
			{ "Head", Vector3.new(0.07, 0.07, 0.5), Vector3.new(0.25, -0.28, -0.85), rgb(245, 245, 245) },
			{ "Head", Vector3.new(0.1, 0.1, 0.1), Vector3.new(0.25, -0.28, -1.1), rgb(255, 120, 40), nil, NEON, "Ember" },
		},
	},
	Buggy = {
		scale = 1,
		colors = bodyColors(rgb(250, 245, 240), rgb(245, 245, 245), rgb(230, 70, 60), rgb(230, 70, 60), rgb(240, 190, 60), rgb(60, 90, 200), rgb(200, 40, 40), rgb(255, 255, 255)),
		pieces = {
			{ "Head", Vector3.new(0.42, 0.42, 0.42), Vector3.new(0, -0.02, -0.68), rgb(255, 40, 40), BALL },
			{ "Head", Vector3.new(1.28, 0.35, 1.28), Vector3.new(0, 0.45, 0.06), rgb(60, 110, 220) },
			{ "Head", Vector3.new(1.3, 1.6, 0.35), Vector3.new(0, -0.3, 0.55), rgb(60, 110, 220) },
			-- captain's hat with a skull and crossbones
			{ "Head", Vector3.new(0.12, 2.0, 2.0), CFrame.new(0, 0.62, 0) * UPRIGHT, rgb(30, 30, 50), CYL },
			{ "Head", Vector3.new(0.6, 1.35, 1.35), CFrame.new(0, 0.95, 0) * UPRIGHT, rgb(30, 30, 50), CYL },
			{ "Head", Vector3.new(0.08, 2.02, 2.02), CFrame.new(0, 0.66, 0) * UPRIGHT, rgb(240, 200, 60), CYL, METAL },
			{ "Head", Vector3.new(0.32, 0.32, 0.32), Vector3.new(0, 1.0, -0.66), rgb(250, 250, 250), BALL },
			{ "Head", Vector3.new(0.6, 0.08, 0.05), CFrame.new(0, 0.95, -0.7) * CFrame.Angles(0, 0, 0.6), rgb(250, 250, 250) },
			{ "Head", Vector3.new(0.6, 0.08, 0.05), CFrame.new(0, 0.95, -0.7) * CFrame.Angles(0, 0, -0.6), rgb(250, 250, 250) },
			-- red cape with a fur collar, and a striped shirt
			{ "UpperTorso", Vector3.new(2.4, 3.6, 0.1), Vector3.new(0, -0.9, 0.58), rgb(190, 30, 40), nil, FABRIC },
			{ "UpperTorso", Vector3.new(2.3, 0.35, 0.6), Vector3.new(0, 0.85, 0.35), rgb(250, 250, 250), nil, FABRIC },
			{ "UpperTorso", Vector3.new(2.04, 0.22, 1.04), Vector3.new(0, 0.35, 0), rgb(230, 70, 60) },
			{ "UpperTorso", Vector3.new(2.04, 0.22, 1.04), Vector3.new(0, -0.25, 0), rgb(230, 70, 60) },
		},
	},
}

-- Dresses an R15 body: recolors it and welds on the outfit pieces.
local function dress(model, look)
	local bodyColorsObj = model:FindFirstChildOfClass("BodyColors")
	if bodyColorsObj then
		bodyColorsObj:Destroy()
	end
	for name, color in look.colors do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color = color
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Outfit"
	folder.Parent = model
	for _, pc in look.pieces do
		local body = model:FindFirstChild(pc[1])
		if body and body:IsA("BasePart") then
			local k = NOMINAL_HEIGHT[pc[1]] and body.Size.Y / NOMINAL_HEIGHT[pc[1]] or 1
			local offset = typeof(pc[3]) == "CFrame" and pc[3] or CFrame.new(pc[3])
			offset = offset - offset.Position + offset.Position * k
			local p = Instance.new("Part")
			p.Name = pc[7] or (pc[1] .. "Piece")
			p.Shape = pc[5] or Enum.PartType.Block
			p.Size = pc[2] * k
			p.Color = pc[4]
			p.Material = pc[6] or Enum.Material.SmoothPlastic
			if p.Material == GLASS then
				p.Transparency = 0.25
			end
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
			p.CFrame = body.CFrame * offset
			local weld = Instance.new("Weld")
			weld.Part0, weld.Part1, weld.C0 = body, p, offset
			weld.Parent = p
			p.Parent = folder
		end
	end
	local ember = folder:FindFirstChild("Ember")
	if ember then
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(rgb(200, 200, 205))
		smoke.Size = NumberSequence.new(0.2, 0.9)
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Lifetime = NumberRange.new(1.5, 2.2)
		smoke.Speed = NumberRange.new(0.6, 1.2)
		smoke.Rate = 4
		smoke.Acceleration = Vector3.new(0, 1.2, 0)
		smoke.Parent = ember
	end
end

-- A real R15 character. Returns nil if Roblox can't build one (the caller falls back to blocks).
local function buildRig(npc, look, cf)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("Couldn't build " .. npc.name .. ": " .. tostring(model))
		return nil
	end
	model.Name = npc.name
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		model:Destroy()
		return nil
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	pcall(function()
		hum.EvaluateStateMachine = false -- they never walk or fall
	end)
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	dress(model, look)
	if look.scale ~= 1 then
		pcall(model.ScaleTo, model, look.scale)
	end
	root.Anchored = true
	model:PivotTo(cf * CFrame.new(0, hum.HipHeight + root.Size.Y / 2, 0))
	return model, model:FindFirstChild("UpperTorso") or root
end

-- The old blocky figure, used if a real character can't be built.
local function buildBlocky(npc, cf, model)
	local function body(name, size, offset, color, shape)
		return makePart({ Name = name, Size = size, Color = color, Shape = shape or Enum.PartType.Block, CFrame = cf * offset }, model)
	end
	body("LeftLeg", Vector3.new(0.9, 2, 1), CFrame.new(-0.5, 1, 0), rgb(45, 45, 55))
	body("RightLeg", Vector3.new(0.9, 2, 1), CFrame.new(0.5, 1, 0), rgb(45, 45, 55))
	local torso = body("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), npc.color)
	body("LeftArm", Vector3.new(0.8, 2, 0.8), CFrame.new(-1.45, 3, 0), npc.color)
	body("RightArm", Vector3.new(0.8, 2, 0.8), CFrame.new(1.45, 3, 0), npc.color)
	body("Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 4.85, 0), SKIN, BALL)
	return torso
end

-- Stalls --------------------------------------------------------------------------------------
-- Built around each NPC: -Z is toward the island center (where players come from).

local function signBoard(add, text, color)
	add("SignPostL", Vector3.new(0.5, 8, 0.5), CFrame.new(-3.4, 4, 4.6), rgb(100, 65, 35), nil, WOOD)
	add("SignPostR", Vector3.new(0.5, 8, 0.5), CFrame.new(3.4, 4, 4.6), rgb(100, 65, 35), nil, WOOD)
	local board = add("SignBoard", Vector3.new(7.6, 1.8, 0.3), CFrame.new(0, 7.2, 4.6), rgb(90, 55, 30), nil, PLANKS)
	add("SignTrim", Vector3.new(7.9, 0.2, 0.35), CFrame.new(0, 8.15, 4.6), color, nil, METAL)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(380, 90)
	gui.LightInfluence = 0
	gui.Parent = board
	label(gui, { Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.1), Text = text, TextColor3 = rgb(255, 225, 150) })
end

local STALLS = {}

function STALLS.Rayleigh(add)
	for _, x in { -4.5, 4.5 } do
		add("DummyPost", Vector3.new(0.6, 4, 0.6), CFrame.new(x, 2, 2.5), rgb(140, 95, 55), nil, WOOD)
		add("DummyArms", Vector3.new(3, 0.4, 0.4), CFrame.new(x, 3.2, 2.5), rgb(140, 95, 55), nil, WOOD)
		add("DummyBody", Vector3.new(1.6, 1.8, 1.0), CFrame.new(x, 3, 2.5), rgb(210, 180, 110), nil, FABRIC)
		add("DummyHead", Vector3.new(1.3, 1.3, 1.3), CFrame.new(x, 4.6, 2.5), rgb(220, 190, 120), BALL, FABRIC)
	end
	-- a rack of practice swords
	add("RackBar", Vector3.new(4, 0.3, 0.3), CFrame.new(0, 2.6, 3.6), rgb(100, 65, 35), nil, WOOD)
	for i = -1, 1 do
		add("RackSword", Vector3.new(0.15, 3.2, 0.3), CFrame.new(i * 1.2, 1.7, 3.4) * CFrame.Angles(math.rad(-12), 0, 0), rgb(205, 210, 220), nil, METAL)
	end
	signBoard(add, "⚔️ HAKI TRAINING", rgb(220, 220, 230))
end

function STALLS.Kureha(add)
	add("Cabinet", Vector3.new(5, 5, 1.4), CFrame.new(0, 2.5, 3.2), rgb(120, 80, 50), nil, WOOD)
	for row = 0, 2 do
		add("Shelf", Vector3.new(4.6, 0.15, 0.5), CFrame.new(0, 1.2 + row * 1.4, 2.4), rgb(90, 60, 35), nil, WOOD)
		for i = 0, 4 do
			local colors = { rgb(255, 80, 120), rgb(90, 220, 140), rgb(90, 160, 255), rgb(255, 200, 70), rgb(200, 110, 255) }
			add("Potion", Vector3.new(0.7, 0.4, 0.4), CFrame.new(-1.8 + i * 0.9, 1.65 + row * 1.4, 2.4) * UPRIGHT, colors[(i + row) % 5 + 1], CYL, NEON)
		end
	end
	add("CrossH", Vector3.new(2.2, 0.6, 0.2), CFrame.new(0, 5.7, 3.0), rgb(220, 40, 50))
	add("CrossV", Vector3.new(0.6, 2.2, 0.2), CFrame.new(0, 5.7, 3.0), rgb(220, 40, 50))
	-- a bubbling cauldron
	add("Cauldron", Vector3.new(1.6, 2.2, 2.2), CFrame.new(3.6, 0.8, 0.8) * UPRIGHT, rgb(40, 40, 45), CYL, METAL)
	local brew = add("Brew", Vector3.new(0.2, 1.9, 1.9), CFrame.new(3.6, 1.6, 0.8) * UPRIGHT, rgb(110, 255, 140), CYL, NEON)
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(rgb(150, 255, 170))
	bubbles.Size = NumberSequence.new(0.3, 0)
	bubbles.Lifetime = NumberRange.new(0.6, 1)
	bubbles.Speed = NumberRange.new(1, 2)
	bubbles.Rate = 6
	bubbles.EmissionDirection = Enum.NormalId.Right
	bubbles.Parent = brew
	signBoard(add, "💊 KUREHA'S CLINIC", rgb(220, 60, 90))
end

function STALLS.Tom(add)
	-- anvil in front of him, a glowing forge, timber and a ship's frame being built
	add("AnvilBase", Vector3.new(0.9, 1.5, 0.9), CFrame.new(0.9, 0.75, -2.8), rgb(50, 50, 55), nil, METAL)
	local anvil = add("Anvil", Vector3.new(2.2, 0.6, 1.0), CFrame.new(0.9, 1.75, -2.8), rgb(80, 85, 95), nil, METAL)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(rgb(255, 200, 80))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Lifetime = NumberRange.new(0.2, 0.45)
	sparks.Speed = NumberRange.new(8, 14)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Rate = 0
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = anvil
	add("Forge", Vector3.new(3, 2.4, 3), CFrame.new(-4.2, 1.2, 1.5), rgb(90, 85, 85), nil, SLATE)
	local coals = add("Coals", Vector3.new(2.4, 0.3, 2.4), CFrame.new(-4.2, 2.45, 1.5), rgb(255, 110, 30), nil, NEON)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat = 4, 6
	fire.Parent = coals
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = rgb(255, 140, 60), 14, 2
	glow.Parent = coals
	for i = 0, 2 do
		add("Plank", Vector3.new(4, 0.3, 0.8), CFrame.new(4.2, 0.2 + i * 0.32, 1.6) * CFrame.Angles(0, math.rad(i * 8), 0), rgb(170, 120, 70), nil, PLANKS)
	end
	add("Keel", Vector3.new(11, 0.6, 0.6), CFrame.new(0, 0.3, 6.5), rgb(130, 90, 50), nil, WOOD)
	for i = -2, 2 do
		local x = i * 2.4
		add("RibL", Vector3.new(0.4, 4, 0.4), CFrame.new(x, 2, 6.5) * CFrame.new(0, 0, -1.6) * CFrame.Angles(math.rad(-20), 0, 0), rgb(150, 105, 60), nil, WOOD)
		add("RibR", Vector3.new(0.4, 4, 0.4), CFrame.new(x, 2, 6.5) * CFrame.new(0, 0, 1.6) * CFrame.Angles(math.rad(20), 0, 0), rgb(150, 105, 60), nil, WOOD)
	end
	signBoard(add, "🔨 GALLEY-LA GEAR", rgb(240, 200, 60))
end

function STALLS.Shakky(add)
	-- she stands behind her bar
	add("Counter", Vector3.new(6.4, 3, 1.6), CFrame.new(0, 1.5, -2.2), rgb(110, 60, 40), nil, WOOD)
	add("CounterTop", Vector3.new(6.8, 0.3, 2.0), CFrame.new(0, 3.1, -2.2), rgb(70, 35, 25), nil, WOOD)
	local colors = { rgb(90, 200, 120), rgb(200, 80, 60), rgb(240, 200, 80) }
	for i = 1, 3 do
		add("Bottle", Vector3.new(0.9, 0.35, 0.35), CFrame.new(-2.6 + i * 0.5, 3.7, -2.0) * UPRIGHT, colors[i], CYL, GLASS)
	end
	add("Glass", Vector3.new(0.4, 0.35, 0.35), CFrame.new(1.6, 3.45, -2.3) * UPRIGHT, rgb(200, 240, 255), CYL, GLASS)
	for _, x in { -2.2, 0, 2.2 } do
		add("StoolLeg", Vector3.new(0.3, 2.2, 0.3), CFrame.new(x, 1.1, -4), rgb(60, 60, 65), nil, METAL)
		add("StoolSeat", Vector3.new(0.3, 1.3, 1.3), CFrame.new(x, 2.3, -4) * UPRIGHT, rgb(170, 40, 60), CYL, FABRIC)
	end
	add("BackShelf", Vector3.new(6, 3.6, 0.8), CFrame.new(0, 1.8, 2.4), rgb(90, 50, 35), nil, WOOD)
	for i = 0, 6 do
		add("ShelfBottle", Vector3.new(0.9, 0.35, 0.35), CFrame.new(-2.4 + i * 0.8, 4.05, 2.4) * UPRIGHT, colors[i % 3 + 1], CYL, GLASS)
	end
	local lamp = add("Lamp", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 6, 0), rgb(255, 120, 160), BALL, NEON)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = rgb(255, 120, 170), 12, 1.5
	light.Parent = lamp
	add("LampCord", Vector3.new(0.08, 1.6, 0.08), CFrame.new(0, 7.2, 0), rgb(30, 30, 30))
	add("LampBeam", Vector3.new(7, 0.4, 0.4), CFrame.new(0, 8, 0), rgb(100, 65, 35), nil, WOOD)
	signBoard(add, "🍸 SHAKKY'S RIP-OFF BAR", rgb(200, 60, 90))
end

function STALLS.Buggy(add)
	-- a striped circus awning
	for _, x in { -4.6, 4.6 } do
		for _, z in { -2.6, 3 } do
			add("TentPole", Vector3.new(0.4, 7, 0.4), CFrame.new(x, 3.5, z), rgb(240, 200, 60), nil, METAL)
		end
	end
	for i = 0, 7 do
		local x = -4.4 + i * 1.26
		add("Awning", Vector3.new(1.26, 0.25, 6.4), CFrame.new(x + 0.63, 7.2, 0.2) * CFrame.Angles(math.rad(-10), 0, 0), i % 2 == 0 and rgb(220, 40, 50) or rgb(250, 250, 250), nil, FABRIC)
	end
	-- a treasure pile and a stack of Buggy Balls
	add("Chest", Vector3.new(2.6, 1.6, 1.8), CFrame.new(3, 0.8, 2), rgb(120, 75, 35), nil, WOOD)
	add("ChestBand", Vector3.new(2.7, 0.25, 1.9), CFrame.new(3, 1.2, 2), rgb(240, 200, 60), nil, METAL)
	for i = 0, 5 do
		add("Coin", Vector3.new(0.12, 0.6, 0.6), CFrame.new(2.2 + (i % 3) * 0.6, 1.7 + math.floor(i / 3) * 0.12, 1.7 + math.floor(i / 3) * 0.4) * UPRIGHT, rgb(255, 210, 60), CYL, METAL)
	end
	local gem = add("Gem", Vector3.new(0.6, 0.6, 0.6), CFrame.new(3.6, 1.9, 2.1), rgb(90, 200, 255), BALL, NEON)
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = rgb(150, 220, 255)
	sparkle.Parent = gem
	add("Cannon", Vector3.new(2.6, 1, 1), CFrame.new(-3.4, 1.2, 2) * CFrame.Angles(0, math.rad(60), math.rad(20)), rgb(40, 40, 45), CYL, METAL)
	add("CannonWheelL", Vector3.new(0.3, 1.2, 1.2), CFrame.new(-3.4, 0.6, 1.4) * CFrame.Angles(0, math.rad(60), 0), rgb(110, 70, 40), CYL, WOOD)
	for i, pos in { Vector3.new(-1.6, 0.5, 2.6), Vector3.new(-0.7, 0.5, 2.6), Vector3.new(-1.15, 1.3, 2.6) } do
		add("BuggyBall" .. i, Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos), rgb(30, 30, 35), BALL)
	end
	signBoard(add, "💎 BUGGY'S TREASURES", rgb(60, 130, 230))
end

-- One NPC ---------------------------------------------------------------------------------

local function build(npc, folder)
	local model = Instance.new("Model")
	model.Name = npc.name .. " Stall"
	local y = groundY(npc.position)
	local base = Vector3.new(npc.position.X, y, npc.position.Z)
	local cf = CFrame.lookAt(base, Vector3.new(Config.ISLAND_CENTER.X, y, Config.ISLAND_CENTER.Z))

	local function add(name, size, offset, color, shape, material)
		return makePart({
			Name = name, Size = size, Color = color, Shape = shape or Enum.PartType.Block, CFrame = cf * offset,
			Material = material or Enum.Material.SmoothPlastic, CanCollide = name ~= "Lamp" and name ~= "Awning",
		}, model)
	end
	add("Rug", Vector3.new(0.2, 9, 9), CFrame.new(0, 0.1, 0) * UPRIGHT, npc.accent, Enum.PartType.Cylinder, FABRIC).CanCollide = false
	add("RugTrim", Vector3.new(0.18, 9.8, 9.8), CFrame.new(0, 0.08, 0) * UPRIGHT, npc.color, Enum.PartType.Cylinder, FABRIC).CanCollide = false
	if STALLS[npc.look] then
		STALLS[npc.look](add)
	end

	local look = LOOKS[npc.look]
	local character, anchor
	if look then
		character, anchor = buildRig(npc, look, cf * CFrame.new(0, 0.2, 0))
	end
	if character then
		character.Parent = model
		character:SetAttribute("Style", npc.style)
		CollectionService:AddTag(character, "IslandNPC")
	else
		anchor = buildBlocky(npc, cf, model)
	end

	-- floating name tag: icon, name and role
	local head = character and character:FindFirstChild("Head") or anchor
	local board = Instance.new("BillboardGui")
	board.Name = "NameTag"
	board.Size = UDim2.fromOffset(230, 92)
	board.StudsOffset = Vector3.new(0, 3.2 * (look and look.scale or 1), 0)
	board.MaxDistance = 90
	board.LightInfluence = 0
	board.Parent = head
	local icon = label(board, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0.5, -20, 0, 0), Text = npc.icon })
	icon.BackgroundTransparency, icon.BackgroundColor3 = 0, npc.accent
	Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
	label(board, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 42), Text = npc.name, TextStrokeTransparency = 0 })
	local role = label(board, {
		Size = UDim2.new(0.8, 0, 0, 20), Position = UDim2.new(0.1, 0, 0, 70), Text = npc.role:upper(),
		Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 225, 140), BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromRGB(20, 30, 50),
	})
	Instance.new("UICorner", role).CornerRadius = UDim.new(1, 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Talk"
	prompt.ActionText = "Talk"
	prompt.ObjectText = npc.name .. " - " .. npc.role
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Panel", npc.panel) -- read by client/SwarmClient to open the menu
	prompt:SetAttribute("Tab", npc.tab)
	prompt:SetAttribute("Line", npc.line) -- what they say when you talk to them
	prompt.Parent = anchor

	model.Parent = folder
end

function Npcs.build()
	local folder = Instance.new("Folder")
	folder.Name = "IslandNPCs"
	folder.Parent = workspace
	for _, npc in Config.NPCS do
		local ok, err = pcall(build, npc, folder)
		if not ok then
			warn("Couldn't build NPC " .. npc.name .. ": " .. tostring(err))
		end
	end
end

return Npcs
