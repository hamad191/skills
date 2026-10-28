-- Draws every skill effect on this client: stretching arms, sword arcs, lightning, projectiles,
-- spin kicks, energy bursts, sky strikes, flying waves, sprouting arms, orbiting objects,
-- hit sparks and damage numbers.
-- The server sends batches of events (see server/Fx.lua); nothing here affects gameplay.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Animate = require(script.Parent.Animate)

local Effects = {}
local handlers = {}

local folder = Instance.new("Folder")
folder.Name = "ClientFX"
folder.Parent = workspace

local SKIN = Color3.fromRGB(255, 205, 160)
local WHITE = Color3.new(1, 1, 1)
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SMOOTH = Enum.Material.SmoothPlastic
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- stands a cylinder's length (X axis) upright

-- helpers -------------------------------------------------------------------

local function rootOf(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function rotateY(dir, angle)
	return CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(dir)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(pos)
	local exclude = { folder }
	for _, name in { "Enemies", "XPOrbs", "FX" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0), rayParams)
	return hit and hit.Position or pos - Vector3.new(0, 3, 0)
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for k, v in props do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function tween(obj, time, goal, style, direction)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(obj, info, goal)
	t:Play()
	return t
end

local function fadeOut(p, time, goal)
	goal = goal or {}
	goal.Transparency = 1
	tween(p, time, goal)
	Debris:AddItem(p, time + 0.05)
end

-- One-shot particle burst. opts: texture, size, speed, life, gravity
local function burst(pos, color, count, opts)
	opts = opts or {}
	local life = opts.life or 0.3
	local speed = opts.speed or 12
	local holder = part({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = opts.texture or TEX_SPARK
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(opts.size or 1, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(life, life * 1.6)
	emitter.Speed = NumberRange.new(speed, speed * 1.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Acceleration = opts.gravity or Vector3.zero
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, life * 2 + 0.2)
end

local function flashLight(pos, color, range, time)
	local holder = part({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, range, 5
	light.Parent = holder
	tween(light, time, { Brightness = 0 })
	Debris:AddItem(holder, time + 0.05)
end

-- Flat expanding shockwave disc on the ground.
local function shockwave(pos, radius, color, time)
	local p = part({
		Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.25,
		Size = Vector3.new(0.2, 1, 1), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
	})
	fadeOut(p, time, { Size = Vector3.new(0.2, radius * 2, radius * 2) })
end

-- Briefly sets a body part on fire (Sanji's foot, Ace's fist).
local function ignite(player, partName, color, time)
	local character = player and player.Character
	local limb = character and character:FindFirstChild(partName)
	if limb then
		local fire = Instance.new("Fire")
		fire.Color, fire.SecondaryColor = color, Color3.fromRGB(255, 230, 120)
		fire.Size, fire.Heat = 4, 8
		fire.Parent = limb
		Debris:AddItem(fire, time)
	end
end

-- Attaches a glowing trail to a moving part.
local function addTrail(p, color, width, life, axis)
	local offset = axis == "X" and Vector3.new(width / 2, 0, 0) or Vector3.new(0, width / 2, 0)
	local a0 = Instance.new("Attachment")
	a0.Position = offset
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = -offset
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = life
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = p
end

-- Damage numbers and hit sparks ---------------------------------------------

local numbersShown = 0

local function damageNumber(pos, amount, crit)
	if numbersShown >= 40 then
		return
	end
	numbersShown += 1
	local holder = part({
		Transparency = 1, Size = Vector3.one * 0.2,
		Position = pos + Vector3.new(math.random() * 2 - 1, 2, math.random() * 2 - 1),
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = crit and UDim2.fromOffset(110, 46) or UDim2.fromOffset(70, 32)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = crit and amount .. "!" or tostring(amount)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = crit and Color3.fromRGB(255, 80, 70) or amount >= 100 and Color3.fromRGB(255, 200, 40) or WHITE
	label.TextStrokeTransparency = 0
	label.Parent = gui
	if crit then
		-- critical hits pop in big
		local pop = Instance.new("UIScale")
		pop.Scale = 1.8
		pop.Parent = label
		tween(pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	tween(gui, 0.7, { StudsOffset = Vector3.new(0, 3, 0) })
	tween(label, 0.7, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.75, function()
		numbersShown -= 1
		holder:Destroy()
	end)
end

local function showHits(hits, color)
	for i, hit in hits or {} do
		if i <= 6 then
			burst(hit[1], color, 6, { size = 0.9, speed = 14, life = 0.25 })
		end
		damageNumber(hit[1], hit[2], hit[3])
	end
end

-- Effect pieces ---------------------------------------------------------------

-- A crescent slash that sweeps across `angle` degrees around `origin`.
local function arc(origin, dir, radius, angle, color, height, sweepTime)
	local segments = math.max(6, math.floor(angle / 12))
	local step = math.rad(angle) / segments
	local half = math.rad(angle) / 2
	for i = 0, segments - 1 do
		local t = (i + 0.5) / segments
		task.delay(sweepTime * t, function()
			local a = -half + (i + 0.5) * step
			local center = origin + rotateY(dir, a) * radius + Vector3.new(0, height, 0)
			local tangent = rotateY(dir, a + math.pi / 2)
			local width = 0.3 + 1.5 * math.sin(math.pi * t)
			local length = radius * step * 1.2
			local cf = CFrame.lookAt(center, center + tangent)
			local glow = part({ Color = color, Transparency = 0.15, Size = Vector3.new(width, 0.2, length), CFrame = cf })
			local core = part({ Color = WHITE, Size = Vector3.new(width * 0.35, 0.25, length), CFrame = cf })
			fadeOut(glow, 0.25, { Size = Vector3.new(width * 1.6, 0.2, length) })
			fadeOut(core, 0.15)
		end)
	end
end

-- A jagged lightning bolt between two points.
local function bolt(from, to, color, width)
	local points = { from }
	local n = math.clamp(math.floor((to - from).Magnitude / 4), 3, 10)
	for i = 1, n - 1 do
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3
		table.insert(points, from:Lerp(to, i / n) + jitter)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		if length > 0.05 then
			local cf = CFrame.lookAt((a + b) / 2, b)
			local glow = part({ Color = color, Transparency = 0.2, Size = Vector3.new(width, width, length), CFrame = cf })
			local core = part({ Color = WHITE, Size = Vector3.new(width * 0.4, width * 0.4, length), CFrame = cf })
			fadeOut(glow, 0.22)
			fadeOut(core, 0.12)
		end
	end
end

-- CFrame for a cylinder lying along `dir`, centered `distance` studs from `start`.
local function along(start, dir, distance)
	local center = start + dir * distance
	return CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.pi / 2, 0)
end

-- Handlers: one per effect kind the server sends ---------------------------------

-- Stretching punch (Luffy, Chopper): the arm shoots out to full range and snaps back.
function handlers.punch(ev)
	task.delay(((ev.i or 1) - 1) * 0.035, function()
		local root = rootOf(ev.p)
		local start = (root and root.Position or ev.o) + Vector3.new(0, 0.5, 0)
		local dir, length = ev.d, ev.len
		local size = (ev.w or 3) / 3
		local thick = 1.1 * size
		local skin = ev.arm or SKIN
		local arm = part({
			Shape = Enum.PartType.Cylinder, Material = SMOOTH, Color = skin,
			Size = Vector3.new(0.2, thick, thick), CFrame = along(start, dir, 0.1),
		})
		local sleeve = part({
			Shape = Enum.PartType.Cylinder, Material = SMOOTH, Color = ev.c,
			Size = Vector3.new(1.5, thick * 1.3, thick * 1.3), CFrame = along(start, dir, 0.75),
		})
		local fist = part({ Shape = Enum.PartType.Ball, Material = SMOOTH, Color = skin, Size = Vector3.one * 2.4 * size, CFrame = CFrame.new(start) })
		local out = 0.09
		tween(arm, out, { Size = Vector3.new(length, thick, thick), CFrame = along(start, dir, length / 2) }, Enum.EasingStyle.Linear)
		tween(fist, out, { CFrame = CFrame.new(start + dir * length) }, Enum.EasingStyle.Linear)
		task.delay(out, function()
			local tip = start + dir * length
			shockwave(tip, 3 * size, WHITE, 0.2)
			burst(tip, ev.c, 8, { size = 1.2, speed = 16 })
			local back = 0.12
			tween(arm, back, { Size = Vector3.new(0.2, thick, thick), CFrame = along(start, dir, 0.1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(fist, back, { CFrame = CFrame.new(start) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, p in { arm, sleeve, fist } do
				Debris:AddItem(p, back + 0.02)
			end
		end)
		showHits(ev.hits, ev.c)
	end)
end

-- Sword or kick arcs sweeping in front (several lines for Zoro's three swords).
function handlers.slash(ev)
	local radius = ev.r * 0.75
	for j = 1, ev.arcs do
		local offset = j - (ev.arcs + 1) / 2
		arc(ev.o, ev.d, radius * (1 + offset * 0.12), ev.a, ev.c, offset * 0.8 - 0.4, 0.1)
	end
	showHits(ev.hits, ev.c)
end

-- Lightning that jumps from enemy to enemy; Nami's starts from a storm cloud.
function handlers.lightning(ev)
	local points = ev.pts
	if #points == 0 then
		return
	end
	local first = points[1]
	if ev.cloud then
		local cloud = first + Vector3.new(0, 22, 0)
		for _ = 1, 5 do
			local puff = part({
				Shape = Enum.PartType.Ball, Material = SMOOTH, Color = Color3.fromRGB(70, 70, 90), Transparency = 0.15,
				Size = Vector3.one * (5 + math.random() * 3),
				Position = cloud + Vector3.new(math.random(-5, 5), math.random() * 1.5, math.random(-5, 5)),
			})
			fadeOut(puff, 0.7)
		end
		bolt(cloud, first, ev.c, 0.7)
	else
		local root = rootOf(ev.p)
		if root then
			bolt(root.Position, first, ev.c, 0.45)
		end
	end
	flashLight(first, ev.c, 18, 0.3)
	for i = 1, #points - 1 do
		task.delay(i * 0.04, function()
			bolt(points[i], points[i + 1], ev.c, 0.45)
			flashLight(points[i + 1], ev.c, 10, 0.2)
		end)
	end
	showHits(ev.hits, ev.c)
end

-- Arms that sprout from the ground (Robin). Returns nothing; parts clean themselves up.
local function sproutArms(ground, spread, count, scale, color)
	for i = 1, count do
		local a = i / count * 2 * math.pi + math.random()
		local d = math.random() * spread
		local base = CFrame.new(ground + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
			* CFrame.Angles(math.rad(math.random(-20, 20)), 0, math.rad(math.random(-20, 20)))
		local height = (3.5 + math.random() * 2) * scale
		local width = 0.7 * scale
		local arm = part({ Material = SMOOTH, Color = SKIN, Size = Vector3.new(width, 0.1, width), CFrame = base })
		local cuff = part({ Color = color, Size = Vector3.new(width * 1.4, 0.5 * scale, width * 1.4), CFrame = base * CFrame.new(0, 0.25 * scale, 0) })
		local hand = part({ Shape = Enum.PartType.Ball, Material = SMOOTH, Color = SKIN, Size = Vector3.one * width * 1.7, CFrame = base })
		tween(arm, 0.14, { Size = Vector3.new(width, height, width), CFrame = base * CFrame.new(0, height / 2, 0) }, Enum.EasingStyle.Back)
		tween(hand, 0.14, { CFrame = base * CFrame.new(0, height, 0) }, Enum.EasingStyle.Back)
		task.delay(0.45, function()
			for _, p in { arm, cuff, hand } do
				fadeOut(p, 0.2)
			end
		end)
	end
end

local PETALS = Color3.fromRGB(255, 160, 220)

-- A patch of arms bursting up with petals.
function handlers.hands(ev)
	local ground = groundAt(ev.pos or ev.o)
	local scale = math.min(ev.r / 7, 1.6)
	shockwave(ground + Vector3.new(0, 0.15, 0), ev.r, ev.c, 0.5)
	sproutArms(ground, ev.r * 0.6, ev.r > 8 and 7 or 4, scale, ev.c)
	burst(ground + Vector3.new(0, 2, 0), PETALS, 16, { size = 1.2, speed = 8, life = 0.6, gravity = Vector3.new(0, -6, 0) })
	showHits(ev.hits, ev.c)
end

-- Arms grabbing one enemy after another.
function handlers.grab(ev)
	for i, point in ev.pts do
		task.delay((i - 1) * 0.06, function()
			local ground = groundAt(point)
			sproutArms(ground, 1, 2, 0.7, ev.c)
			burst(ground + Vector3.new(0, 2, 0), PETALS, 6, { size = 1, speed = 6, life = 0.5 })
		end)
	end
	showHits(ev.hits, ev.c)
end

-- Projectiles: fireballs or glowing orbs. The server says where each one bursts ("boom").
local shots = {}

function handlers.shot(ev)
	local size = ev.size or 2
	local ball = part({ Shape = Enum.PartType.Ball, Color = ev.c, Transparency = 0.1, Size = Vector3.one * size, Position = ev.o })
	if ev.fire then
		local flames = Instance.new("Fire")
		flames.Color, flames.SecondaryColor = ev.c, Color3.fromRGB(255, 220, 90)
		flames.Size, flames.Heat = size * 2, 0
		flames.Parent = ball
		ignite(ev.p, "RightHand", ev.c, 0.3)
	end
	addTrail(ball, ev.c, size, 0.25)
	shots[ev.id] = { part = ball, pos = ev.o, dir = ev.d, left = ev.len, speed = ev.speed }
	Debris:AddItem(ball, ev.len / ev.speed + 1)
end

function handlers.boom(ev)
	local shot = shots[ev.id]
	if shot then
		shot.part:Destroy()
		shots[ev.id] = nil
	end
	local sphere = part({ Shape = Enum.PartType.Ball, Color = ev.c, Transparency = 0.1, Size = Vector3.one * 2, Position = ev.pos })
	fadeOut(sphere, 0.35, { Size = Vector3.one * ev.r * 2 })
	if ev.fire then
		local explosion = Instance.new("Explosion")
		explosion.Position = ev.pos
		explosion.BlastRadius = ev.r
		explosion.BlastPressure = 0 -- visual only
		explosion.DestroyJointRadiusPercent = 0
		explosion.ExplosionType = Enum.ExplosionType.NoCraters
		explosion.Parent = workspace
		burst(ev.pos, ev.c, 25, { texture = TEX_FIRE, size = 3, speed = ev.r * 2.5, life = 0.5 })
		burst(ev.pos, Color3.fromRGB(90, 90, 90), 10, { texture = TEX_SMOKE, size = 4, speed = ev.r, life = 0.8, gravity = Vector3.new(0, 8, 0) })
	else
		shockwave(groundAt(ev.pos) + Vector3.new(0, 0.2, 0), ev.r, ev.c, 0.35)
		burst(ev.pos, ev.c, 20, { size = 1.5, speed = ev.r * 2, life = 0.45 })
	end
	flashLight(ev.pos, ev.c, ev.r * 2.5, 0.4)
	showHits(ev.hits, ev.c)
end

-- Spin kick around the player; Sanji's burning kicks add flames.
function handlers.kick(ev)
	local root = rootOf(ev.p)
	local center = root and root.Position or ev.o
	local ground = groundAt(center)
	local facing = root and Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit or Vector3.new(0, 0, -1)
	arc(center, facing, ev.r * 0.7, 360, ev.c, -1.5, 0.14)
	shockwave(ground + Vector3.new(0, 0.2, 0), ev.r, ev.c, 0.3)
	for i = 1, 8 do
		local a = i * math.pi / 4
		local pos = ground + Vector3.new(math.cos(a) * ev.r * 0.8, 1, math.sin(a) * ev.r * 0.8)
		if ev.fire then
			burst(pos, ev.c, 4, { texture = TEX_FIRE, size = 2.5, speed = 3, life = 0.45, gravity = Vector3.new(0, 15, 0) })
		else
			burst(pos, ev.c, 3, { size = 1, speed = 6, life = 0.3 })
		end
	end
	if ev.fire then
		ignite(ev.p, "RightFoot", ev.c, 0.35)
	end
	showHits(ev.hits, ev.c)
end

-- Energy bursting out around the player (balloon, cyclone, fire fence, rumble ball...).
function handlers.nova(ev)
	local root = rootOf(ev.p)
	local center = root and root.Position or ev.o
	local ground = groundAt(center)
	local sphere = part({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = ev.c, Size = Vector3.one * 2, Position = center })
	fadeOut(sphere, 0.4, { Size = Vector3.one * ev.r * 2 })
	shockwave(ground + Vector3.new(0, 0.25, 0), ev.r, ev.c, 0.35)
	burst(center, ev.c, 16, { size = 1.4, speed = ev.r * 2, life = 0.35 })
	flashLight(center, ev.c, ev.r * 2, 0.25)
	showHits(ev.hits, ev.c)
end

-- A column crashing down from the sky (giant fist, heel drop, fire pillar, thunder lance...).
function handlers.strike(ev)
	local ground = groundAt(ev.pos)
	local width = ev.r * 1.1
	local column = part({
		Shape = Enum.PartType.Cylinder, Color = ev.c, Transparency = 0.15,
		Size = Vector3.new(60, width, width), CFrame = CFrame.new(ground + Vector3.new(0, 30, 0)) * UPRIGHT,
	})
	local core = part({
		Shape = Enum.PartType.Cylinder, Color = WHITE,
		Size = Vector3.new(60, width * 0.35, width * 0.35), CFrame = column.CFrame,
	})
	fadeOut(column, 0.35, { Size = Vector3.new(60, width * 0.2, width * 0.2) })
	fadeOut(core, 0.2)
	shockwave(ground + Vector3.new(0, 0.2, 0), ev.r * 1.3, ev.c, 0.4)
	burst(ground + Vector3.new(0, 1, 0), ev.c, 14, { size = 2, speed = ev.r * 2, life = 0.4 })
	flashLight(ground + Vector3.new(0, 3, 0), ev.c, ev.r * 3, 0.3)
	showHits(ev.hits, ev.c)
end

-- A crescent wave flying down a line (sword waves, wind, petals, fire bullets...).
function handlers.wave(ev)
	task.delay(((ev.i or 1) - 1) * 0.06, function()
		local root = rootOf(ev.p)
		local start = root and root.Position or ev.o
		local finish = start + ev.d * ev.len
		local width = (ev.w or 3) * 1.6
		local travel = ev.len / 90
		local pieces = {}
		for side = -1, 1 do
			-- a center blade and two swept-back wings make the crescent
			local offset = CFrame.new(side * width * 0.42, 0, math.abs(side) * width * 0.25) * CFrame.Angles(0, -side * math.rad(28), 0)
			local blade = part({
				Color = side == 0 and WHITE or ev.c, Transparency = side == 0 and 0 or 0.15,
				Size = Vector3.new(side == 0 and width * 0.5 or width * 0.45, 0.3, 0.8),
				CFrame = CFrame.lookAt(start, finish) * offset,
			})
			table.insert(pieces, { part = blade, offset = offset })
		end
		addTrail(pieces[2].part, ev.c, width, 0.2, "X")
		for _, piece in pieces do
			tween(piece.part, travel, { CFrame = CFrame.lookAt(finish, finish + ev.d) * piece.offset }, Enum.EasingStyle.Linear)
			Debris:AddItem(piece.part, travel + 0.05)
		end
		showHits(ev.hits, ev.c)
	end)
end

-- Things circling the player: fists, clouds, fireflies, petals (positions follow server time).
local orbits = {} -- [player] = { [weaponName] = { parts = {}, r = radius } }

local function clearOrbits(player)
	for _, o in orbits[player] or {} do
		for _, p in o.parts do
			p:Destroy()
		end
	end
	orbits[player] = nil
end

function handlers.orbit(ev)
	if ev.all then
		clearOrbits(ev.p)
		return
	end
	local mine = orbits[ev.p] or {}
	orbits[ev.p] = mine
	local o = mine[ev.key] or { parts = {} }
	mine[ev.key] = o
	o.r = ev.r
	while #o.parts < ev.n do
		local fist = part({ Shape = Enum.PartType.Ball, Material = SMOOTH, Color = ev.c, Size = Vector3.one * 1.8 })
		addTrail(fist, ev.c, 1.2, 0.2)
		table.insert(o.parts, fist)
	end
	while #o.parts > ev.n do
		table.remove(o.parts):Destroy()
	end
	if ev.n == 0 then
		mine[ev.key] = nil
	end
end

function handlers.hits(ev)
	showHits(ev.hits, ev.c)
end

-- A dash: a burst of wind and fading afterimages left behind the player.
function handlers.dash(ev)
	local root = rootOf(ev.p)
	if not root then
		return
	end
	burst(root.Position, Color3.fromRGB(200, 230, 255), 10, { size = 1.2, speed = 10, life = 0.3 })
	for i = 0, 3 do
		task.delay(i * 0.04, function()
			if root.Parent then
				local ghost = part({ Color = Color3.fromRGB(150, 200, 255), Transparency = 0.45, Size = Vector3.new(2, 5, 1), CFrame = root.CFrame })
				fadeOut(ghost, 0.3)
			end
		end)
	end
end

-- An enemy goes down in a puff of smoke.
function handlers.death(ev)
	burst(ev.pos, Color3.fromRGB(200, 200, 200), math.floor(6 * ev.s) + 2, { texture = TEX_SMOKE, size = 2.5 * ev.s, speed = 6, life = 0.5, gravity = Vector3.new(0, 6, 0) })
	burst(ev.pos, ev.c, 6, { size = 1, speed = 15, life = 0.3 })
end

-- A red strip on the ground: a laser, snipe or lunge will sweep along it when it fills up.
function handlers.line(ev)
	local ground = groundAt(ev.o) + Vector3.new(0, 0.12, 0)
	local cf = CFrame.lookAt(ground, ground + ev.d)
	local strip = part({
		Color = ev.c, Transparency = 0.6, Size = Vector3.new(ev.w, 0.1, ev.len),
		CFrame = cf * CFrame.new(0, 0, -ev.len / 2),
	})
	local edge = part({ Color = Color3.fromRGB(255, 50, 50), Transparency = 0.3, Size = Vector3.new(ev.w, 0.12, 0.3), CFrame = cf * CFrame.new(0, 0, -ev.len) })
	local fill = part({ Color = Color3.fromRGB(255, 60, 40), Transparency = 0.35, Size = Vector3.new(ev.w, 0.14, 0.1), CFrame = cf })
	tween(fill, ev.t, { Size = Vector3.new(ev.w, 0.14, ev.len), CFrame = cf * CFrame.new(0, 0, -ev.len / 2) }, Enum.EasingStyle.Linear)
	Debris:AddItem(strip, ev.t)
	Debris:AddItem(edge, ev.t)
	Debris:AddItem(fill, ev.t)
end

-- The beam itself: a bright column of light that fades fast.
function handlers.beam(ev)
	local from = ev.o
	local to = from + ev.d * ev.len
	local cf = CFrame.lookAt(from, to) * CFrame.new(0, 0, -ev.len / 2)
	local beam = part({ Color = ev.c, Size = Vector3.new(ev.w, ev.w, ev.len), CFrame = cf })
	local core = part({ Color = WHITE, Size = Vector3.new(ev.w * 0.4, ev.w * 0.4, ev.len), CFrame = cf })
	fadeOut(beam, 0.35, { Size = Vector3.new(ev.w * 2, ev.w * 2, ev.len) })
	fadeOut(core, 0.25)
	flashLight(from, ev.c, 16, 0.3)
	burst(to, ev.c, 10, { size = 1.2, speed = 12, life = 0.3 })
end

-- A medic's healing pulse.
function handlers.heal(ev)
	local green = Color3.fromRGB(110, 255, 150)
	shockwave(groundAt(ev.pos) + Vector3.new(0, 0.2, 0), ev.r, green, 0.5)
	burst(ev.pos + Vector3.new(0, 2, 0), green, 14, { size = 1, speed = 6, life = 0.6, gravity = Vector3.new(0, 10, 0) })
end

-- Soru: a puff of smoke where a CP9 agent vanishes or appears.
function handlers.puff(ev)
	burst(ev.pos, Color3.fromRGB(230, 230, 235), 14, { texture = TEX_SMOKE, size = 3, speed = 8, life = 0.4 })
	burst(ev.pos, Color3.fromRGB(150, 200, 255), 6, { size = 1, speed = 18, life = 0.2 })
end

-- A shout floating over an officer's head ("REINFORCEMENTS!").
function handlers.shout(ev)
	local holder = part({ Transparency = 1, Size = Vector3.one * 0.2, Position = ev.pos + Vector3.new(0, 3, 0) })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 46)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
	gui.Parent = holder
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = ev.text
	text.TextScaled = true
	text.Font = Enum.Font.LuckiestGuy
	text.TextColor3 = Color3.fromRGB(255, 220, 90)
	text.TextStrokeTransparency = 0
	text.Parent = gui
	tween(holder, 1.4, { Position = holder.Position + Vector3.new(0, 4, 0) })
	tween(text, 1.4, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(holder, 1.5)
end

-- A treasure chest bursts open: gold sparkles fountain up.
function handlers.chest(ev)
	local gold = Color3.fromRGB(255, 205, 60)
	burst(ev.pos, gold, 24, { size = 1.2, speed = 18, life = 0.6, gravity = Vector3.new(0, -30, 0) })
	burst(ev.pos, WHITE, 8, { size = 0.8, speed = 10, life = 0.4 })
	shockwave(groundAt(ev.pos) + Vector3.new(0, 0.2, 0), 6, gold, 0.4)
	flashLight(ev.pos, gold, 18, 0.6)
end

function handlers.anim(_ev) end -- the animation itself is played in Effects.play

-- Enemy attacks -------------------------------------------------------------------

-- A red warning circle on the ground: the blast lands when it fills up. Get out!
function handlers.warn(ev)
	local ground = groundAt(ev.pos) + Vector3.new(0, 0.15, 0)
	local size = ev.r * 2
	local ring = part({
		Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 40, 40), Transparency = 0.55,
		Size = Vector3.new(0.15, size, size), CFrame = CFrame.new(ground) * UPRIGHT,
	})
	local fill = part({
		Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 130, 60), Transparency = 0.3,
		Size = Vector3.new(0.2, 0.5, 0.5), CFrame = ring.CFrame,
	})
	tween(fill, ev.t, { Size = Vector3.new(0.2, size, size) }, Enum.EasingStyle.Linear)
	Debris:AddItem(ring, ev.t)
	Debris:AddItem(fill, ev.t)
end

function handlers.slam(ev)
	local ground = groundAt(ev.pos)
	local center = ground + Vector3.new(0, 1, 0)
	shockwave(ground + Vector3.new(0, 0.3, 0), ev.r * 1.2, ev.c, 0.35)
	local sphere = part({ Shape = Enum.PartType.Ball, Color = ev.c, Transparency = 0.2, Size = Vector3.one * 2, Position = center })
	fadeOut(sphere, 0.3, { Size = Vector3.one * ev.r * 2 })
	burst(center, ev.c, 16, { texture = TEX_FIRE, size = 2.5, speed = ev.r * 2, life = 0.4 })
	burst(center, Color3.fromRGB(90, 90, 90), 8, { texture = TEX_SMOKE, size = 3, speed = ev.r, life = 0.6, gravity = Vector3.new(0, 6, 0) })
end

-- Marine rifle bullets. The server says when each one hits or runs out ("eshotEnd").
local enemyShots = {}

function handlers.eshot(ev)
	local color = ev.c or Color3.fromRGB(255, 230, 120)
	local size = ev.s or 0.7
	local bullet = part({ Shape = Enum.PartType.Ball, Color = color, Size = Vector3.one * size, Position = ev.o })
	if ev.s then
		bullet.Material = Enum.Material.ForceField -- nets and air blades: a soft glowing ball
	end
	addTrail(bullet, color, size * 0.6, 0.15)
	enemyShots[ev.id] = { part = bullet, pos = ev.o, dir = ev.d, left = ev.len, speed = ev.speed }
	Debris:AddItem(bullet, ev.len / ev.speed + 0.5)
end

function handlers.eshotEnd(ev)
	local shot = enemyShots[ev.id]
	if shot then
		shot.part:Destroy()
		enemyShots[ev.id] = nil
	end
end

-- Skill emblems ------------------------------------------------------------------
-- Every skill a player owns floats around them as a little charm whose shape follows the skill:
-- blades for sword and wave skills, a fist for punches, rings for bursts, petals for Robin...

local loadouts = {} -- [player] = { emblems = { { part, color, fx, size } } }

local function makeEmblem(item)
	local fx, color = item.fx, item.c
	local p
	if fx == "slash" or fx == "wave" then
		p = part({ Color = color, Size = Vector3.new(0.25, 0.5, 1.8) })
	elseif fx == "nova" then
		p = part({ Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.15, Size = Vector3.new(0.15, 1.4, 1.4) })
	elseif fx == "strike" then
		p = part({ Color = color, Size = Vector3.one * 0.8 })
	elseif fx == "punch" then
		p = part({ Shape = Enum.PartType.Ball, Material = SMOOTH, Color = SKIN, Size = Vector3.one * 1.1 })
	elseif fx == "hands" or fx == "grab" then
		p = part({ Shape = Enum.PartType.Ball, Color = PETALS, Size = Vector3.one * 0.8 })
	else
		p = part({ Shape = Enum.PartType.Ball, Color = color, Size = Vector3.one * 0.9 })
	end
	if item.fire then
		local flames = Instance.new("Fire")
		flames.Color, flames.SecondaryColor = color, Color3.fromRGB(255, 220, 90)
		flames.Size, flames.Heat = 1.5, 0
		flames.Parent = p
	end
	if fx == "lightning" then
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness = color, 6, 2
		glow.Parent = p
	end
	addTrail(p, color, 0.35, 0.25)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(26, 26)
	gui.StudsOffset = Vector3.new(0, 1.1, 0)
	gui.MaxDistance = 70
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = item.icon or ""
	label.Parent = gui
	return { part = p, color = color, fx = fx, size = p.Size }
end

local function clearLoadout(player)
	local loadout = loadouts[player]
	if loadout then
		for _, emblem in loadout.emblems do
			emblem.part:Destroy()
		end
	end
	loadouts[player] = nil
end

function handlers.loadout(ev)
	clearLoadout(ev.p)
	if #ev.items > 0 then
		local emblems = {}
		for _, item in ev.items do
			table.insert(emblems, makeEmblem(item))
		end
		loadouts[ev.p] = { emblems = emblems }
	end
end

-- The emblem of the skill that just fired swells for a moment.
local function pulseEmblem(player, color)
	local loadout = loadouts[player]
	for _, emblem in loadout and loadout.emblems or {} do
		if emblem.color == color and not emblem.pulsing then
			emblem.pulsing = true
			tween(emblem.part, 0.08, { Size = emblem.size * 1.8 })
			task.delay(0.1, function()
				tween(emblem.part, 0.15, { Size = emblem.size })
				emblem.pulsing = false
			end)
		end
	end
end

local function moveEmblems(now)
	for player, loadout in loadouts do
		local root = rootOf(player)
		if not root or not player.Parent then
			clearLoadout(player)
			continue
		end
		local count = #loadout.emblems
		for i, emblem in loadout.emblems do
			local a = now * 1.4 + i * 2 * math.pi / count
			local pos = root.Position + Vector3.new(math.cos(a) * 3.4, 1.6 + math.sin(now * 3 + i) * 0.35, math.sin(a) * 3.4)
			local fx = emblem.fx
			if fx == "slash" or fx == "wave" then
				local ahead = pos + Vector3.new(-math.sin(a), 0, math.cos(a))
				emblem.part.CFrame = CFrame.lookAt(pos, ahead) * CFrame.Angles(0, 0, now * 6)
			elseif fx == "nova" or fx == "strike" then
				emblem.part.CFrame = CFrame.new(pos) * CFrame.Angles(now * 2, now * 3, now)
			else
				emblem.part.CFrame = CFrame.new(pos)
			end
		end
	end
end

-- Per-frame updates -------------------------------------------------------------

local function moveShots(list, dt)
	for id, shot in list do
		if not shot.part.Parent then
			list[id] = nil
		elseif shot.left > 0 then
			local move = math.min(shot.left, shot.speed * dt)
			shot.pos += shot.dir * move
			shot.left -= move
			shot.part.Position = shot.pos
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	moveShots(shots, dt)
	moveShots(enemyShots, dt)

	local now = workspace:GetServerTimeNow()
	for player, mine in orbits do
		local root = rootOf(player)
		if not root or not player.Parent then
			clearOrbits(player)
			continue
		end
		for _, o in mine do
			local n = #o.parts
			for i, p in o.parts do
				local a = now * 3 + i * 2 * math.pi / n
				p.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * o.r, 0, math.sin(a) * o.r))
			end
		end
	end

	moveEmblems(now)

	-- spin the swirl blades inside the island's portals
	for _, blade in CollectionService:GetTagged("PortalSwirl") do
		local center = blade:GetAttribute("Center")
		if center then
			blade.CFrame = center * CFrame.Angles(0, 0, now * 1.5 + (blade:GetAttribute("Phase") or 0))
		end
	end
end)

-- Public ------------------------------------------------------------------------

function Effects.play(ev)
	if ev.p and ev.anim then
		Animate.play(ev.p, ev.anim)
	end
	if ev.p and ev.c then
		pulseEmblem(ev.p, ev.c)
	end
	local handler = handlers[ev.k]
	if handler then
		local ok, err = pcall(handler, ev)
		if not ok then
			warn("Effect " .. tostring(ev.k) .. " failed: " .. tostring(err))
		end
	end
end

function Effects.clear()
	for player in loadouts do
		clearLoadout(player)
	end
	for player in orbits do
		clearOrbits(player)
	end
	for _, list in { shots, enemyShots } do
		for _, shot in list do
			shot.part:Destroy()
		end
		table.clear(list)
	end
end

return Effects
