-- Enemy spawning, bodies, movement, attacks and skills (rifle shots, telegraphed blasts, lasers,
-- snipes, heals, bombs, nets, shadow-step blinks, air blades, reinforcements), damage, XP orbs and chests.
-- Each enemy is an anchored torso moved by the server, with jointed limbs (Motor6Ds) that every
-- client animates on its own (client/Rigs.lua): cheap enough for big swarms.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)
local Fx = require(script.Parent.Fx)

local Enemies = {}
Enemies.onKilled = function(_enemy, _killer) end
Enemies.onPickup = function(_player, _xp) end
Enemies.onChest = function(_runKey, _kind, _opener) end -- a crew member opened a treasure chest
Enemies.onSlow = function(_player, _factor, _seconds) end -- a seastone net hit a player
Enemies.onItem = function(_runKey, _kind, _target) end -- a crew member grabbed a pickup

local list, orbs, bullets, chests, items = {}, {}, {}, {}, {}
local nextBulletId = 0
local lastTargets = {} -- targets from the latest step, used when delayed blasts land
local NO_TARGETS = {}
local BULLET_SPEED = 45
local BLAST_COLOR = Color3.fromRGB(255, 80, 40)
local LASER_COLOR = Color3.fromRGB(255, 230, 90)
local SNIPE_COLOR = Color3.fromRGB(255, 60, 60)
local PLAYER_RADIUS = 1.5

-- Hurts a player target, after their Iron Body defense. Dashing and picking level-up cards
-- make players briefly untouchable.
local function hurt(t, amount)
	if t.s and (t.s.invulnerableUntil or 0) > os.clock() then
		return
	end
	t.hum:TakeDamage(amount * (1 - (t.armor or 0)))
end

local folder = Instance.new("Folder")
folder.Name = "Enemies"
folder.Parent = workspace
local orbFolder = Instance.new("Folder")
orbFolder.Name = "XPOrbs"
orbFolder.Parent = workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function groundY(x, z)
	local exclude = { folder, orbFolder }
	local fx = workspace:FindFirstChild("FX")
	if fx then
		table.insert(exclude, fx)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rayParams)
	return hit and hit.Position.Y
end

local function makePart(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function makeBar(part, scale, name)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 36)
	gui.StudsOffset = Vector3.new(0, 3.5 * scale, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 300
	gui.Adornee = part
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, 12)
	back.Position = UDim2.fromOffset(0, 22)
	back.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 40, 40)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner:Clone().Parent = fill
	return fill
end

local function dropOrb(pos, xp, runKey)
	-- merge into an existing orb of the same run when there are too many on the map
	if #orbs >= 250 then
		local o = orbs[math.random(#orbs)]
		if o.run == runKey then
			o.xp += xp
			return
		end
	end
	local big = xp >= 10
	local part = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (big and 1.6 or 0.9),
		Material = Enum.Material.Neon,
		Color = big and Color3.fromRGB(180, 80, 255) or Color3.fromRGB(70, 160, 255),
		Position = pos,
	}, orbFolder)
	table.insert(orbs, { part = part, xp = xp, run = runKey })
end

-- A glowing treasure chest; the first crew member to walk up opens it for the whole crew.
local function dropChest(pos, runKey, kind)
	local model = Instance.new("Model")
	model.Name = "TreasureChest"
	local gold = Color3.fromRGB(255, 200, 50)
	local base = makePart({ Name = "Base", Size = Vector3.new(3, 2, 2.2), Color = Color3.fromRGB(110, 70, 35), Material = Enum.Material.Wood, CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) }, model)
	makePart({ Name = "Lid", Size = Vector3.new(3.1, 0.8, 2.3), Color = Color3.fromRGB(130, 85, 40), Material = Enum.Material.Wood, CFrame = base.CFrame * CFrame.new(0, 1.4, 0) }, model)
	makePart({ Name = "Band", Size = Vector3.new(0.3, 2.9, 2.35), Color = gold, Material = Enum.Material.Metal, CFrame = base.CFrame * CFrame.new(0, 0.4, 0) }, model)
	local glow = makePart({ Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * 5, Color = gold, Material = Enum.Material.ForceField, CFrame = base.CFrame * CFrame.new(0, 0.6, 0) }, model)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = gold, 14, 2
	light.Parent = glow
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(60, 60)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 250
	tag.Parent = base
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.TextScaled = true
	icon.Text = "🎁"
	icon.Parent = tag
	model.Parent = folder
	table.insert(chests, { model = model, pos = base.Position, run = runKey, kind = kind, born = os.clock() })
end

-- A pickup (meat, magnet, Fleet Barrage) floating where a Marine fell.
local function dropItem(pos, runKey, kind)
	local def = Config.PICKUPS[kind]
	local part = makePart({
		Name = kind, Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, Material = Enum.Material.ForceField,
		Color = def.color, Position = pos + Vector3.new(0, 1.6, 0),
	}, orbFolder)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = def.color, 10, 1.5
	light.Parent = part
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(44, 44)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 160
	tag.Parent = part
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.TextScaled = true
	icon.Text = def.icon
	icon.Parent = tag
	table.insert(items, { part = part, pos = part.Position, kind = kind, run = runKey, born = os.clock() })
end

local function flash(e)
	if e.flashing then
		return
	end
	e.flashing = true
	e.root.Color = Color3.new(1, 1, 1)
	e.head.Color = Color3.new(1, 1, 1)
	task.delay(0.07, function()
		e.flashing = false
		if not e.dead then
			e.root.Color = e.color
			e.head.Color = e.skin
		end
	end)
end

-- Bodies ----------------------------------------------------------------------------------
-- Sizes and offsets are at scale 1 and grow with the enemy's scale. The torso is 2 x 2 x 1.

local LEG_DEPTH = 2.6 -- torso center to the soles of the feet
local BALL, CYL, WEDGE = Enum.PartType.Ball, Enum.PartType.Cylinder, Enum.PartType.Wedge
local UP = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder standing upright
local STEEL = Color3.fromRGB(210, 215, 225)
local GUNMETAL = Color3.fromRGB(45, 45, 50)
local WOOD = Color3.fromRGB(110, 70, 40)
local DARK = Color3.fromRGB(25, 25, 30)
local GOLD = Color3.fromRGB(235, 190, 60)
local BOOTS = Color3.fromRGB(30, 30, 35)
local BELT = Color3.fromRGB(60, 40, 25)
local WHITE = Color3.fromRGB(245, 245, 248)

-- Jointed limbs: name, size, joint on the torso, joint on the limb, color key.
-- client/Rigs.lua swings the joints named LeftHip, RightHip, LeftShoulder, RightShoulder, Neck.
local LIMBS = {
	{ "LeftLeg", Vector3.new(0.9, 1.6, 0.95), Vector3.new(-0.5, -1, 0), Vector3.new(0, 0.8, 0), "accent", "LeftHip" },
	{ "RightLeg", Vector3.new(0.9, 1.6, 0.95), Vector3.new(0.5, -1, 0), Vector3.new(0, 0.8, 0), "accent", "RightHip" },
	{ "LeftArm", Vector3.new(0.75, 1.7, 0.75), Vector3.new(-1.4, 0.75, 0), Vector3.new(0, 0.75, 0), "color", "LeftShoulder" },
	{ "RightArm", Vector3.new(0.75, 1.7, 0.75), Vector3.new(1.4, 0.75, 0), Vector3.new(0, 0.75, 0), "color", "RightShoulder" },
	{ "Head", Vector3.new(1.7, 1.7, 1.7), Vector3.new(0, 1, 0), Vector3.new(0, -0.85, 0), "skin", "Neck", BALL },
}

-- A piece is { attach to, size, offset (CFrame or Vector3), color (Color3 or a color key), shape?, material? }.
local function piece(on, size, offset, color, shape, material)
	return { on, size, offset, color, shape, material }
end

local BASE = {
	piece("LeftArm", Vector3.new(0.65, 0.65, 0.65), Vector3.new(0, -0.95, 0), "skin", BALL),
	piece("RightArm", Vector3.new(0.65, 0.65, 0.65), Vector3.new(0, -0.95, 0), "skin", BALL),
	piece("LeftLeg", Vector3.new(0.95, 0.4, 1.15), Vector3.new(0, -0.62, -0.08), BOOTS),
	piece("RightLeg", Vector3.new(0.95, 0.4, 1.15), Vector3.new(0, -0.62, -0.08), BOOTS),
	piece("Torso", Vector3.new(2.04, 0.28, 1.04), Vector3.new(0, -0.82, 0), BELT),
	piece("Torso", Vector3.new(0.42, 0.3, 0.06), Vector3.new(0, -0.82, -0.54), GOLD, nil, Enum.Material.Metal),
	-- face: eyes, angry brows, mouth
	piece("Head", Vector3.new(0.32, 0.32, 0.32), Vector3.new(-0.33, 0.12, -0.72), "eyes", BALL),
	piece("Head", Vector3.new(0.32, 0.32, 0.32), Vector3.new(0.33, 0.12, -0.72), "eyes", BALL),
	piece("Head", Vector3.new(0.46, 0.1, 0.1), CFrame.new(-0.33, 0.38, -0.7) * CFrame.Angles(0, 0, -0.35), DARK),
	piece("Head", Vector3.new(0.46, 0.1, 0.1), CFrame.new(0.33, 0.38, -0.7) * CFrame.Angles(0, 0, 0.35), DARK),
	piece("Head", Vector3.new(0.46, 0.08, 0.06), Vector3.new(0, -0.32, -0.76), Color3.fromRGB(90, 40, 40)),
}

-- Marine sailor collar and neckerchief
local SAILOR = {
	piece("Torso", Vector3.new(1.7, 0.7, 0.08), Vector3.new(0, 0.6, 0.54), "accent"),
	piece("Torso", Vector3.new(0.5, 0.5, 0.08), CFrame.new(0, 0.65, -0.54) * CFrame.Angles(0, 0, math.pi / 4), "accent"),
}

local function marineCap(crown, band)
	return {
		piece("Head", Vector3.new(0.42, 1.75, 1.75), CFrame.new(0, 0.72, 0) * UP, crown, CYL),
		piece("Head", Vector3.new(0.14, 1.78, 1.78), CFrame.new(0, 0.56, 0) * UP, band, CYL),
		piece("Head", Vector3.new(1.1, 0.12, 0.6), Vector3.new(0, 0.55, -0.85), crown),
		piece("Head", Vector3.new(1.3, 0.6, 0.08), Vector3.new(0, 0.25, 0.8), crown),
	}
end

local HATS = {
	cap = marineCap(WHITE, "accent"),
	medic = (function()
		local pieces = marineCap(WHITE, Color3.fromRGB(200, 40, 50))
		table.insert(pieces, piece("Head", Vector3.new(0.42, 0.13, 0.05), Vector3.new(0, 0.75, -0.89), Color3.fromRGB(220, 30, 40)))
		table.insert(pieces, piece("Head", Vector3.new(0.13, 0.42, 0.05), Vector3.new(0, 0.75, -0.89), Color3.fromRGB(220, 30, 40)))
		return pieces
	end)(),
	officer = {
		piece("Head", Vector3.new(0.5, 1.9, 1.9), CFrame.new(0, 0.8, 0) * UP, WHITE, CYL),
		piece("Head", Vector3.new(0.2, 1.92, 1.92), CFrame.new(0, 0.62, 0) * UP, DARK, CYL),
		piece("Head", Vector3.new(1.2, 0.1, 0.55), Vector3.new(0, 0.58, -0.9), DARK),
		piece("Head", Vector3.new(0.36, 0.3, 0.06), Vector3.new(0, 0.84, -0.96), GOLD, nil, Enum.Material.Neon),
	},
	beret = {
		piece("Head", Vector3.new(1.9, 0.5, 1.9), CFrame.new(0.15, 0.75, 0) * CFrame.Angles(0, 0, 0.18), "accent", BALL),
		piece("Head", Vector3.new(0.2, 0.2, 0.06), Vector3.new(-0.3, 0.72, -0.9), GOLD),
	},
	bear = {
		piece("Head", Vector3.new(0.5, 1.85, 1.85), CFrame.new(0, 0.75, 0) * UP, "accent", CYL),
		piece("Head", Vector3.new(0.6, 0.6, 0.35), Vector3.new(-0.65, 1.1, 0), "accent", BALL),
		piece("Head", Vector3.new(0.6, 0.6, 0.35), Vector3.new(0.65, 1.1, 0), "accent", BALL),
		piece("Head", Vector3.new(0.3, 0.3, 0.1), Vector3.new(-0.65, 1.1, -0.15), Color3.fromRGB(240, 190, 170), BALL),
		piece("Head", Vector3.new(0.3, 0.3, 0.1), Vector3.new(0.65, 1.1, -0.15), Color3.fromRGB(240, 190, 170), BALL),
	},
	tophat = {
		piece("Head", Vector3.new(0.1, 2.2, 2.2), CFrame.new(0, 0.72, 0) * UP, DARK, CYL),
		piece("Head", Vector3.new(1.1, 1.45, 1.45), CFrame.new(0, 1.25, 0) * UP, DARK, CYL),
		piece("Head", Vector3.new(0.2, 1.48, 1.48), CFrame.new(0, 0.86, 0) * UP, Color3.fromRGB(70, 70, 75), CYL),
		-- white shirt and tie under the black suit
		piece("Torso", Vector3.new(0.6, 1.1, 0.06), Vector3.new(0, 0.4, -0.52), WHITE),
		piece("Torso", Vector3.new(0.18, 0.9, 0.08), Vector3.new(0, 0.35, -0.55), Color3.fromRGB(120, 20, 30)),
	},
	fin = {
		piece("Head", Vector3.new(0.3, 1.1, 1.3), Vector3.new(0, 1.05, 0.2), "skin", WEDGE),
		piece("Head", Vector3.new(0.12, 0.5, 0.06), CFrame.new(-0.6, -0.1, -0.5) * CFrame.Angles(0, 0.4, 0), DARK),
		piece("Head", Vector3.new(0.12, 0.5, 0.06), CFrame.new(0.6, -0.1, -0.5) * CFrame.Angles(0, -0.4, 0), DARK),
	},
	clown = {
		piece("Head", Vector3.new(1.95, 1.3, 1.95), Vector3.new(0, 0.4, 0.3), Color3.fromRGB(60, 110, 220), BALL),
		piece("Head", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, -0.05, -0.86), Color3.fromRGB(255, 40, 40), BALL, Enum.Material.Neon),
		-- striped shirt
		piece("Torso", Vector3.new(2.04, 0.3, 1.04), Vector3.new(0, 0.45, 0), WHITE),
		piece("Torso", Vector3.new(2.04, 0.3, 1.04), Vector3.new(0, -0.15, 0), WHITE),
	},
}
local SAILOR_HATS = { cap = true, medic = true, beret = true }

local GEAR = {
	sword = {
		piece("RightArm", Vector3.new(0.25, 0.25, 0.7), Vector3.new(0, -0.95, -0.3), DARK),
		piece("RightArm", Vector3.new(0.6, 0.12, 0.12), Vector3.new(0, -0.95, -0.66), GOLD, nil, Enum.Material.Metal),
		piece("RightArm", Vector3.new(0.1, 0.28, 3), Vector3.new(0, -0.95, -2.2), STEEL, nil, Enum.Material.Metal),
	},
	-- guns point down the arm: shooters hold their arms out, aiming them forward
	rifle = {
		piece("RightArm", Vector3.new(0.32, 3.2, 0.42), Vector3.new(0, -1.9, -0.2), GUNMETAL, nil, Enum.Material.Metal),
		piece("RightArm", Vector3.new(0.38, 0.9, 0.65), Vector3.new(0, -0.45, 0.15), WOOD, nil, Enum.Material.Wood),
	},
	longrifle = {
		piece("RightArm", Vector3.new(0.3, 4.4, 0.4), Vector3.new(0, -2.5, -0.2), Color3.fromRGB(55, 65, 50), nil, Enum.Material.Metal),
		piece("RightArm", Vector3.new(0.38, 0.9, 0.65), Vector3.new(0, -0.45, 0.15), WOOD, nil, Enum.Material.Wood),
		piece("RightArm", Vector3.new(0.9, 0.3, 0.3), CFrame.new(0, -1.6, -0.55) * UP, DARK, CYL),
	},
	net = {
		piece("RightArm", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, -1.4, -0.2), Color3.fromRGB(170, 160, 135), BALL, Enum.Material.Fabric),
		piece("Torso", Vector3.new(2.3, 0.3, 0.3), CFrame.new(0, 0.1, 0.55) * CFrame.Angles(0, 0, 0.7), Color3.fromRGB(150, 130, 100), CYL, Enum.Material.Fabric),
	},
	bomb = {
		piece("RightArm", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, -1.45, -0.25), DARK, BALL),
		piece("RightArm", Vector3.new(0.12, 0.5, 0.12), Vector3.new(0, -0.75, -0.25), Color3.fromRGB(200, 180, 140)),
		piece("RightArm", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, -0.45, -0.25), Color3.fromRGB(255, 160, 40), BALL, Enum.Material.Neon),
	},
	cannon = {
		piece("Torso", Vector3.new(3.2, 1.1, 1.1), CFrame.new(1.2, 1.2, -0.4) * CFrame.Angles(0, math.pi / 2, 0), GUNMETAL, CYL, Enum.Material.Metal),
		piece("Torso", Vector3.new(0.4, 1.3, 1.3), CFrame.new(1.2, 1.2, 1.1) * CFrame.Angles(0, math.pi / 2, 0), DARK, CYL),
	},
	coat = {
		piece("Torso", Vector3.new(2.4, 2.9, 0.2), Vector3.new(0, -0.55, 0.62), WHITE, nil, Enum.Material.Fabric),
		piece("Torso", Vector3.new(0.9, 0.25, 1.1), Vector3.new(-1.3, 0.95, 0), GOLD),
		piece("Torso", Vector3.new(0.9, 0.25, 1.1), Vector3.new(1.3, 0.95, 0), GOLD),
	},
}

-- How each enemy holds itself (read by client/Rigs.lua): shooters aim, bombers carry.
local function styleOf(def)
	if def.gear == "rifle" or def.gear == "longrifle" or def.gear == "net" then
		return "aim"
	end
	return def.gear == "bomb" and "carry" or "march"
end

local function buildBody(def, colors, name, x, y, z)
	local s = def.scale
	local model = Instance.new("Model")
	model.Name = name
	local torso = makePart({ Name = "Torso", Size = Vector3.new(2, 2, 1) * s, Color = colors.color }, model)
	torso.CFrame = CFrame.new(x, y + LEG_DEPTH * s, z)
	local parts = { Torso = torso }

	local function newPart(partName, size, color, shape, material)
		local p = makePart({
			Name = partName, Size = size * s, Color = color, Shape = shape or Enum.PartType.Block,
			Material = material or Enum.Material.SmoothPlastic, CastShadow = false,
		}, nil)
		p.Anchored, p.Massless = false, true
		return p
	end
	for _, limb in LIMBS do
		local p = newPart(limb[1], limb[2], colors[limb[5]], limb[7])
		local joint = Instance.new("Motor6D")
		joint.Name = limb[6]
		joint.Part0, joint.Part1 = torso, p
		joint.C0, joint.C1 = CFrame.new(limb[3] * s), CFrame.new(limb[4] * s)
		joint.Parent = torso
		p.CFrame = torso.CFrame * joint.C0 * joint.C1:Inverse()
		p.Parent = model
		parts[limb[1]] = p
	end
	local function attach(list)
		for _, pc in list do
			local on = parts[pc[1]]
			local color = typeof(pc[4]) == "Color3" and pc[4] or colors[pc[4]] or DARK
			local p = newPart(pc[1] .. "Detail", pc[2], color, pc[5], pc[6])
			local offset = typeof(pc[3]) == "CFrame" and pc[3] or CFrame.new(pc[3])
			p.CFrame = on.CFrame * (offset - offset.Position + offset.Position * s)
			if pc[4] == "eyes" and def.eyes then
				p.Material = Enum.Material.Neon
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = on, p
			weld.Parent = p
			p.Parent = model
		end
	end
	attach(BASE)
	if SAILOR_HATS[def.hat] then
		attach(SAILOR)
	end
	attach(HATS[def.hat] or {})
	attach(GEAR[def.gear] or {})
	if def.gear == "coat" then
		-- JUSTICE on the back of every officer's coat
		local back
		for _, p in model:GetChildren() do
			if p.Name == "TorsoDetail" and p.Size.Z < 0.25 * s and p.Size.Y > 2.5 * s then
				back = p
			end
		end
		if back then
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Back
			gui.CanvasSize = Vector2.new(120, 140)
			gui.Parent = back
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 0.6)
			text.Position = UDim2.fromScale(0, 0.1)
			text.BackgroundTransparency = 1
			text.Text = "JUSTICE"
			text.TextScaled = true
			text.TextColor3 = DARK
			text.Font = Enum.Font.GothamBlack
			text.Parent = gui
		end
	end
	model.PrimaryPart = torso
	model:SetAttribute("Style", styleOf(def))
	model:SetAttribute("Scale", s)
	return model, parts
end

function Enemies.spawn(kind, x, z, hpScale, dmgScale, runKey, look)
	local def = Config.Enemies[kind]
	local y = groundY(x, z)
	if not y then
		return nil
	end
	look = look or {}
	if look.hat or look.gear or look.skin or look.eyes then
		-- a custom boss (e.g. the raid's sea king): same stats, different body
		def = setmetatable({ hat = look.hat, gear = look.gear, skin = look.skin, eyes = look.eyes }, { __index = def })
	end
	local colors = { color = look.color or def.color, accent = look.accent or def.accent, skin = def.skin, eyes = def.eyes or DARK }
	local name = look.name or def.name
	local model, parts = buildBody(def, colors, name, x, y, z)
	if def.healthBar then
		model:SetAttribute("Boss", name)
		model:SetAttribute("BossTier", kind == "Boss" and 2 or 1)
		model:SetAttribute("Hp", 1)
	end
	model.Parent = folder

	local hp = def.hp * hpScale
	local now = os.clock()
	local e = {
		model = model, root = parts.Torso, head = parts.Head, def = def, kind = kind, run = runKey,
		color = colors.color, skin = colors.skin, name = name,
		hp = hp, maxHp = hp, damage = def.damage * dmgScale, hpScale = hpScale, dmgScale = dmgScale,
		radius = 1.2 * def.scale, lastHit = 0, phase = math.random() * 10, busyUntil = 0,
		nextAttack = now + math.random() * (def.fireRate or 1) + 1,
		nextSlam = now + (def.slamEvery or 0), nextRing = now + (def.ringEvery or 0),
		cool = {},
	}
	-- skills start partly charged so a squad doesn't fire all at once
	for skill, cooldown in def.skills or {} do
		e.cool[skill] = now + cooldown * (0.4 + math.random() * 0.6)
	end
	if def.healthBar then
		e.bar = makeBar(parts.Torso, def.scale, name)
	end
	table.insert(list, e)
	return e
end

-- Removes an enemy without a reward (a Bomb Clown that blew itself up).
local function vanish(e)
	e.dead = true
	e.model:Destroy()
end

-- Attacks -----------------------------------------------------------------------------------

-- Tells clients to play an attack pose: "swing" (melee), "cast" (both arms up), "shoot".
local function pose(e, kind)
	e.model:SetAttribute("Pose", kind)
	e.model:SetAttribute("PoseAt", os.clock())
end

local function faceTo(e, dir)
	local pos = e.root.Position
	e.root.CFrame = CFrame.lookAt(pos, pos + dir)
end

local function groundPos(e)
	return e.root.Position - Vector3.new(0, LEG_DEPTH * e.def.scale - 0.2, 0)
end

-- A telegraphed blast: players see a red circle, then everyone still inside gets hit.
local function blast(e, pos, radius, damage, delay, onLand)
	Fx.emit("warn", { pos = pos, r = radius, t = delay })
	local runKey = e.run
	task.delay(delay, function()
		if onLand and not onLand() then
			return
		end
		for _, t in lastTargets[runKey] or NO_TARGETS do
			if t.hum.Health > 0 and flat(t.root.Position - pos).Magnitude <= radius then
				hurt(t, damage)
			end
		end
		Fx.emit("slam", { pos = pos, r = radius, c = BLAST_COLOR })
	end)
end

-- A telegraphed straight line (Iron Sentinel lasers, sniper shots, sword lunges): a red strip shows
-- on the ground, then everyone still on it gets hit. The enemy holds still while aiming.
local function lineAttack(e, dir, length, width, damage, delay, beam)
	local from = groundPos(e)
	e.busyUntil = os.clock() + delay + 0.2
	faceTo(e, dir)
	pose(e, beam.pose)
	Fx.emit("line", { o = from, d = dir, len = length, w = width, t = delay, c = beam.color })
	local runKey = e.run
	task.delay(delay, function()
		if e.dead then
			return
		end
		for _, t in lastTargets[runKey] or NO_TARGETS do
			local rel = flat(t.root.Position - from)
			local along = rel:Dot(dir)
			if t.hum.Health > 0 and along >= 0 and along <= length and (rel - dir * along).Magnitude <= width / 2 + PLAYER_RADIUS then
				hurt(t, damage)
			end
		end
		local eye = e.head.Position
		Fx.emit("beam", { o = eye, d = dir, len = length, w = beam.width, c = beam.color })
		if beam.lunge then
			-- the swordsman dashes along his line
			local pos = e.root.Position + dir * length * 0.85
			local y = groundY(pos.X, pos.Z)
			if y then
				e.root.CFrame = CFrame.lookAt(Vector3.new(pos.X, y + LEG_DEPTH * e.def.scale, pos.Z), Vector3.new(pos.X, y + LEG_DEPTH * e.def.scale, pos.Z) + dir)
			end
		end
	end)
end

-- A projectile flying flat toward the target (rifle bullets, air blades, seastone nets).
local function shoot(e, target, opts)
	opts = opts or {}
	nextBulletId += 1
	local from = e.root.Position
	local dir = flat(target.root.Position - from)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, -1)
	local range = (e.def.range or 30) * 1.6
	local speed = opts.speed or BULLET_SPEED
	table.insert(bullets, {
		id = nextBulletId, pos = from, dir = dir, left = range, damage = opts.damage or e.damage, run = e.run,
		speed = speed, radius = opts.radius or 2.2, slow = opts.slow, slowTime = opts.slowTime,
	})
	Fx.emit("eshot", { id = nextBulletId, o = from, d = dir, speed = speed, len = range, c = opts.color, s = opts.size })
	pose(e, "shoot")
end

local SKILLS = {}

-- Swordsman: a quick lunge along a short red line.
function SKILLS.dash(e, target, dist)
	if dist > 22 or dist < 4 then
		return false
	end
	local dir = flat(target.root.Position - e.root.Position).Unit
	lineAttack(e, dir, 20, 3, e.damage * 1.5, 0.55, { color = Color3.fromRGB(220, 230, 255), width = 0.6, pose = "swing", lunge = true })
	return true
end

-- Iron Sentinel (and the final boss): a wide laser from the mouth after a long aim.
function SKILLS.laser(e, target, dist)
	if dist > e.def.range then
		return false
	end
	local dir = flat(target.root.Position - e.root.Position).Unit
	lineAttack(e, dir, e.def.range + 8, 4 * math.max(1, e.def.scale / 2), e.damage * 1.6, 1.1, { color = LASER_COLOR, width = 1.4, pose = "cast" })
	return true
end

-- Sniper: a long, thin, very painful shot.
function SKILLS.snipe(e, target, dist)
	if dist > e.def.range + 10 then
		return false
	end
	local dir = flat(target.root.Position - e.root.Position).Unit
	lineAttack(e, dir, e.def.range + 20, 2.2, e.damage, 1.3, { color = SNIPE_COLOR, width = 0.35, pose = "shoot" })
	return true
end

-- Medic: heals every nearby Marine that is hurt.
function SKILLS.heal(e)
	local healed = false
	for _, other in list do
		if not other.dead and other.run == e.run and other.hp < other.maxHp
			and flat(other.root.Position - e.root.Position).Magnitude <= e.def.healRadius then
			other.hp = math.min(other.maxHp, other.hp + other.maxHp * e.def.heal)
			if other.bar then
				other.bar.Size = UDim2.fromScale(other.hp / other.maxHp, 1)
				other.model:SetAttribute("Hp", other.hp / other.maxHp)
			end
			healed = true
		end
	end
	if healed then
		pose(e, "cast")
		Fx.emit("heal", { pos = groundPos(e), r = e.def.healRadius })
	end
	return true -- checks again after the cooldown either way
end

-- Bomb Clown: runs up, lights the fuse, and blows up (taking itself out).
function SKILLS.bomb(e, _target, dist)
	if dist > 5 or e.fusing then
		return false
	end
	e.fusing = true
	e.busyUntil = os.clock() + 10
	pose(e, "cast")
	blast(e, groundPos(e), e.def.blast, e.damage, 1, function()
		if e.dead then
			return false -- defused: killed before it went off
		end
		vanish(e)
		return true
	end)
	return true
end

-- Chain Netter: a slow net that halves your speed for a moment.
function SKILLS.net(e, target, dist)
	if dist > e.def.range then
		return false
	end
	shoot(e, target, {
		speed = 32, radius = 2.8, damage = e.damage, slow = e.def.slow, slowTime = e.def.slowTime,
		color = Color3.fromRGB(200, 190, 160), size = 2,
	})
	return true
end

-- Shadow Agent: shadow-step - vanishes and reappears right beside you.
function SKILLS.blink(e, target, dist)
	if dist < 10 or dist > 80 then
		return false
	end
	local a = math.random() * math.pi * 2
	local spot = target.root.Position + Vector3.new(math.cos(a) * 5, 0, math.sin(a) * 5)
	local y = groundY(spot.X, spot.Z)
	if not y then
		return false
	end
	Fx.emit("puff", { pos = e.root.Position })
	local pos = Vector3.new(spot.X, y + LEG_DEPTH * e.def.scale, spot.Z)
	e.root.CFrame = CFrame.lookAt(pos, Vector3.new(target.root.Position.X, pos.Y, target.root.Position.Z))
	Fx.emit("puff", { pos = pos })
	e.lastHit = os.clock() - 0.4 -- a moment to react before the first hit
	return true
end

-- Shadow Agent: Air Kick - a kicked blade of air.
function SKILLS.rankyaku(e, target, dist)
	if dist > e.def.range or dist < 8 then
		return false
	end
	shoot(e, target, { speed = 60, radius = 2.6, damage = e.damage * 0.8, color = Color3.fromRGB(190, 240, 255), size = 1.6 })
	return true
end

-- Captains and Vice Admirals: call in a few recruits.
function SKILLS.call(e)
	if Enemies.count(e.run) >= Config.MAX_ENEMIES then
		return false
	end
	pose(e, "cast")
	Fx.emit("shout", { pos = e.head.Position, text = "REINFORCEMENTS!" })
	local pos = e.root.Position
	for k = 1, 3 do
		local a = k * math.pi * 2 / 3 + math.random()
		Enemies.spawn("Grunt", pos.X + math.cos(a) * 7, pos.Z + math.sin(a) * 7, e.hpScale, e.dmgScale, e.run)
	end
	return true
end

-- Ranged attacks, boss attacks and skills. Melee hits happen in Enemies.step.
local function specialAttacks(e, target, dist, targets, now)
	local def = e.def
	if now < e.busyUntil then
		return
	end
	for skill, cooldown in def.skills or {} do
		if now >= e.cool[skill] and SKILLS[skill](e, target, dist) then
			e.cool[skill] = now + cooldown
			return -- one skill at a time
		end
	end
	if def.ai == "ranged" and dist <= def.range and now >= e.nextAttack then
		e.nextAttack = now + def.fireRate
		shoot(e, target)
	elseif def.ai == "artillery" and dist <= def.range and now >= e.nextAttack then
		e.nextAttack = now + def.fireRate
		pose(e, "cast")
		blast(e, target.root.Position, def.blast, e.damage, 1.4)
	elseif def.ai == "boss" then
		if now >= e.nextSlam then
			e.nextSlam = now + def.slamEvery
			local victim = targets[math.random(#targets)]
			pose(e, "swing")
			blast(e, victim.root.Position, def.blast, e.damage * 1.5, 1.2)
		end
		if def.ringEvery and now >= e.nextRing then
			e.nextRing = now + def.ringEvery
			pose(e, "cast")
			for k = 1, 6 do
				local a = k * math.pi / 3
				blast(e, e.root.Position + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14), 7, e.damage, 1.5)
			end
		end
	end
end

function Enemies.damage(e, amount, player)
	if e.dead then
		return
	end
	e.hp -= amount
	if e.bar then
		local ratio = math.max(e.hp, 0) / e.maxHp
		e.bar.Size = UDim2.fromScale(ratio, 1)
		e.model:SetAttribute("Hp", ratio)
	end
	if e.hp > 0 then
		flash(e)
		-- regular Marines get knocked back a little
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and not e.def.healthBar and Config.KNOCKBACK > 0 and os.clock() >= e.busyUntil then
			local away = flat(e.root.Position - root.Position)
			if away.Magnitude > 0.1 then
				e.root.CFrame += away.Unit * (Config.KNOCKBACK / e.def.scale)
			end
		end
		return
	end
	e.dead = true
	if e.def.xp > 0 then
		dropOrb(e.root.Position - Vector3.new(0, LEG_DEPTH * e.def.scale - 0.8, 0), e.def.xp, e.run)
	end
	Fx.emit("death", { pos = e.root.Position, c = e.color, s = e.def.scale })
	local ground = e.root.Position - Vector3.new(0, LEG_DEPTH * e.def.scale, 0)
	local chestChance = Config.CHESTS[e.kind]
	if chestChance and math.random() < chestChance then
		dropChest(ground, e.run, e.kind)
	end
	for kind, def in Config.PICKUPS do
		if math.random() < def.chance then
			dropItem(ground, e.run, kind)
			break
		end
	end
	Enemies.onKilled(e, player)
	e.model:Destroy()
end

-- Keeps the swarm from melting into one blob: overlapping enemies push each other apart
-- (big ones push harder). Uses a grid so each enemy only checks its neighbors.
local CELL = 6
local function cellKey(x, z)
	return (math.floor(x / CELL) + 32768) * 65536 + (math.floor(z / CELL) + 32768)
end

local function separation()
	local grid = {}
	for _, e in list do
		if not e.dead then
			local p = e.root.Position
			local key = cellKey(p.X, p.Z)
			local cell = grid[key]
			if not cell then
				cell = {}
				grid[key] = cell
			end
			table.insert(cell, e)
			e.push = nil
		end
	end
	for _, e in list do
		if not e.dead then
			local p = e.root.Position
			local cx, cz = math.floor(p.X / CELL), math.floor(p.Z / CELL)
			local px, pz = 0, 0
			for dx = -1, 1 do
				for dz = -1, 1 do
					for _, other in grid[(cx + dx + 32768) * 65536 + (cz + dz + 32768)] or NO_TARGETS do
						if other ~= e then
							local o = other.root.Position
							local ox, oz = p.X - o.X, p.Z - o.Z
							local d = math.sqrt(ox * ox + oz * oz)
							local reach = (e.radius + other.radius) * 1.1
							if d < reach then
								if d < 0.01 then
									ox, oz, d = math.random() - 0.5, math.random() - 0.5, 0.5
								end
								local share = other.radius / (e.radius + other.radius)
								local strength = (reach - d) * share
								px += ox / d * strength
								pz += oz / d * strength
							end
						end
					end
				end
			end
			if px ~= 0 or pz ~= 0 then
				e.push = Vector3.new(px, 0, pz)
			end
		end
	end
end

-- targetsByRun: [runKey] = array of { player, root, hum, magnet }
function Enemies.step(dt, targetsByRun)
	local now = os.clock()
	lastTargets = targetsByRun
	separation()
	for i = #list, 1, -1 do
		local e = list[i]
		if e.dead then
			table.remove(list, i)
			continue
		end
		local best, bestDist
		for _, t in targetsByRun[e.run] or NO_TARGETS do
			local d = flat(t.root.Position - e.root.Position).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = t, d
			end
		end
		if best then
			local busy = now < e.busyUntil
			local pos = e.root.Position
			local to = flat(best.root.Position - pos)
			local reach = e.radius + 2
			-- shooters and support stop at a distance; everyone else walks right up
			local stopAt = e.def.keepAway and e.def.range * 0.8 or reach
			local push = e.push and e.push * math.min(1, dt * 10) or Vector3.zero
			if not busy and bestDist > stopAt then
				local newPos = pos + to.Unit * math.min(e.def.speed * dt, bestDist - stopAt) + push
				local sway = math.sin(now * 9 + e.phase) * 0.04
				e.root.CFrame = CFrame.lookAt(newPos, newPos + to) * CFrame.Angles(0, 0, sway)
			elseif not busy and to.Magnitude > 0.1 then
				local newPos = pos + push
				e.root.CFrame = CFrame.lookAt(newPos, newPos + to) -- keep facing the target while standing
			end
			if not busy and bestDist <= reach and now - e.lastHit >= 1 then
				e.lastHit = now
				pose(e, "swing")
				hurt(best, e.damage)
			end
			specialAttacks(e, best, bestDist, targetsByRun[e.run], now)
		end
	end

	for i = #chests, 1, -1 do
		local chest = chests[i]
		-- bob gently so it catches the eye
		chest.model:PivotTo(CFrame.new(chest.pos + Vector3.new(0, math.sin((now - chest.born) * 3) * 0.3, 0)) * CFrame.Angles(0, now - chest.born, 0))
		for _, t in targetsByRun[chest.run] or NO_TARGETS do
			if flat(t.root.Position - chest.pos).Magnitude <= 5 then
				Fx.emit("chest", { pos = chest.pos })
				Enemies.onChest(chest.run, chest.kind, t.player)
				chest.model:Destroy()
				table.remove(chests, i)
				break
			end
		end
	end

	for i = #items, 1, -1 do
		local item = items[i]
		local age = now - item.born
		local taken
		for _, t in targetsByRun[item.run] or NO_TARGETS do
			if flat(t.root.Position - item.pos).Magnitude <= 4 then
				taken = t
				break
			end
		end
		if taken then
			Fx.emit("pickup", { pos = item.pos, c = item.part.Color, icon = Config.PICKUPS[item.kind].icon })
			Enemies.onItem(item.run, item.kind, taken)
		end
		if taken or age > Config.PICKUP_LIFETIME then
			item.part:Destroy()
			table.remove(items, i)
		else
			-- bob, and blink during the last few seconds
			item.part.Position = item.pos + Vector3.new(0, math.sin(age * 3) * 0.4, 0)
			item.part.Transparency = age > Config.PICKUP_LIFETIME - 4 and (math.floor(age * 6) % 2) * 0.6 or 0
		end
	end

	for i = #bullets, 1, -1 do
		local b = bullets[i]
		local move = b.speed * dt
		b.pos += b.dir * move
		b.left -= move
		local hit
		for _, t in targetsByRun[b.run] or NO_TARGETS do
			if flat(t.root.Position - b.pos).Magnitude <= b.radius then
				hit = t
				break
			end
		end
		if hit then
			hurt(hit, b.damage)
			if b.slow and hit.player then
				Enemies.onSlow(hit.player, b.slow, b.slowTime)
			end
		end
		if hit or b.left <= 0 then
			Fx.emit("eshotEnd", { id = b.id })
			table.remove(bullets, i)
		end
	end

	for i = #orbs, 1, -1 do
		local o = orbs[i]
		local t = o.target
		if t and (t.hum.Health <= 0 or not t.root.Parent) then
			t, o.target = nil, nil
		end
		if not t then
			for _, candidate in targetsByRun[o.run] or NO_TARGETS do
				if (candidate.root.Position - o.part.Position).Magnitude <= candidate.magnet then
					t, o.target = candidate, candidate
					break
				end
			end
		end
		if t then
			local to = t.root.Position - o.part.Position
			if to.Magnitude < 2 then
				Enemies.onPickup(t.player, o.xp)
				o.part:Destroy()
				table.remove(orbs, i)
			else
				o.part.Position += to.Unit * math.min(to.Magnitude, (o.fast and 160 or 60) * dt)
			end
		end
	end
end

-- A map hazard: a telegraphed circle (eruption, lightning, quicksand...) that hurts, and maybe
-- slows, everyone of the run still inside when it lands. h = a Config.HAZARDS entry.
function Enemies.hazard(runKey, pos, h, damage)
	Fx.emit("warn", { pos = pos, r = h.radius, t = h.delay, c = h.color })
	task.delay(h.delay, function()
		for _, t in lastTargets[runKey] or NO_TARGETS do
			if t.hum.Health > 0 and flat(t.root.Position - pos).Magnitude <= h.radius then
				hurt(t, damage)
				if h.slow and t.player then
					Enemies.onSlow(t.player, h.slow, h.slowTime)
				end
			end
		end
		Fx.emit(h.fx or "slam", { pos = pos, r = h.radius, c = h.color })
	end)
end

-- Magnet pickup: every XP orb of the run flies to this player.
function Enemies.magnetize(runKey, target)
	for _, o in orbs do
		if o.run == runKey then
			o.target, o.fast = target, true
		end
	end
end

-- Fleet Barrage pickup: wipes out the Marines around `pos`; bosses only lose a slice of health.
function Enemies.busterCall(pos, radius, runKey, player)
	Fx.emit("buster", { pos = pos, r = radius })
	for _, e in table.clone(list) do
		if not e.dead and e.run == runKey and flat(e.root.Position - pos).Magnitude <= radius then
			if e.def.healthBar then
				Enemies.damage(e, e.maxHp * Config.PICKUPS.BusterCall.bossDamage, player)
			else
				Enemies.damage(e, e.hp + 1, player)
			end
		end
	end
end

function Enemies.nearest(pos, maxDist, exclude)
	local best, bestDist = nil, maxDist
	for _, e in list do
		if not e.dead and not (exclude and exclude[e]) then
			local d = flat(e.root.Position - pos).Magnitude - e.radius
			if d <= bestDist then
				best, bestDist = e, d
			end
		end
	end
	return best
end

-- up to n enemies within maxDist, closest first
function Enemies.closest(pos, maxDist, n)
	local found = {}
	for _, e in list do
		if not e.dead then
			local d = flat(e.root.Position - pos).Magnitude - e.radius
			if d <= maxDist then
				table.insert(found, { e = e, d = d })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.d < b.d
	end)
	local out = {}
	for i = 1, math.min(n, #found) do
		out[i] = found[i].e
	end
	return out
end

function Enemies.inRadius(pos, r)
	local out = {}
	for _, e in list do
		if not e.dead and flat(e.root.Position - pos).Magnitude <= r + e.radius then
			table.insert(out, e)
		end
	end
	return out
end

function Enemies.count(runKey)
	local n = 0
	for _, e in list do
		if e.run == runKey and not e.dead then
			n += 1
		end
	end
	return n
end

-- Removes one adventure's enemies, bullets, chests, pickups and XP orbs.
function Enemies.clear(runKey)
	for i = #items, 1, -1 do
		if items[i].run == runKey then
			items[i].part:Destroy()
			table.remove(items, i)
		end
	end
	for i = #chests, 1, -1 do
		if chests[i].run == runKey then
			chests[i].model:Destroy()
			table.remove(chests, i)
		end
	end
	for i = #bullets, 1, -1 do
		if bullets[i].run == runKey then
			Fx.emit("eshotEnd", { id = bullets[i].id })
			table.remove(bullets, i)
		end
	end
	for i = #list, 1, -1 do
		local e = list[i]
		if e.run == runKey then
			e.dead = true
			e.model:Destroy()
			table.remove(list, i)
		end
	end
	for i = #orbs, 1, -1 do
		if orbs[i].run == runKey then
			orbs[i].part:Destroy()
			table.remove(orbs, i)
		end
	end
end

return Enemies
