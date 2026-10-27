-- Draws every skill effect on this client: stretching arms, sword arcs, lightning,
-- fireballs, fire kicks, sprouting arms, orbiting fists, hit sparks and damage numbers.
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
local function addTrail(p, color, width, life)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
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

local function damageNumber(pos, amount)
	if numbersShown >= 40 then
		return
	end
	numbersShown += 1
	local holder = part({
		Transparency = 1, Size = Vector3.one * 0.2,
		Position = pos + Vector3.new(math.random() * 2 - 1, 2, math.random() * 2 - 1),
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(70, 32)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(amount)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = amount >= 100 and Color3.fromRGB(255, 200, 40) or WHITE
	label.TextStrokeTransparency = 0
	label.Parent = gui
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
		damageNumber(hit[1], hit[2])
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

-- Luffy: the arm stretches out to full range and snaps back.
function handlers.punch(ev)
	task.delay(((ev.i or 1) - 1) * 0.035, function()
		local root = rootOf(ev.p)
		local start = (root and root.Position or ev.o) + Vector3.new(0, 0.5, 0)
		local dir, length, thick = ev.d, ev.len, 1.1
		local arm = part({
			Shape = Enum.PartType.Cylinder, Material = SMOOTH, Color = SKIN,
			Size = Vector3.new(0.2, thick, thick), CFrame = along(start, dir, 0.1),
		})
		local sleeve = part({
			Shape = Enum.PartType.Cylinder, Material = SMOOTH, Color = ev.c,
			Size = Vector3.new(1.5, thick * 1.3, thick * 1.3), CFrame = along(start, dir, 0.75),
		})
		local fist = part({ Shape = Enum.PartType.Ball, Material = SMOOTH, Color = SKIN, Size = Vector3.one * 2.4, CFrame = CFrame.new(start) })
		local out = 0.09
		tween(arm, out, { Size = Vector3.new(length, thick, thick), CFrame = along(start, dir, length / 2) }, Enum.EasingStyle.Linear)
		tween(fist, out, { CFrame = CFrame.new(start + dir * length) }, Enum.EasingStyle.Linear)
		task.delay(out, function()
			local tip = start + dir * length
			shockwave(tip, 3, WHITE, 0.2)
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

-- Zoro: three sword arcs at different heights.
function handlers.slash(ev)
	local radius = ev.r * 0.75
	for j = 1, ev.arcs do
		local offset = j - (ev.arcs + 1) / 2
		arc(ev.o, ev.d, radius * (1 + offset * 0.12), ev.a, ev.c, offset * 0.8 - 0.4, 0.1)
	end
	showHits(ev.hits, ev.c)
end

-- Nami: a storm cloud strikes the first enemy, then lightning chains on.
function handlers.lightning(ev)
	local points = ev.pts
	if #points == 0 then
		return
	end
	local first = points[1]
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
	flashLight(first, ev.c, 18, 0.3)
	for i = 1, #points - 1 do
		task.delay(i * 0.04, function()
			bolt(points[i], points[i + 1], ev.c, 0.45)
			flashLight(points[i + 1], ev.c, 10, 0.2)
		end)
	end
	showHits(ev.hits, ev.c)
end

-- Ace: flying fireballs. The server says where each one explodes ("boom").
local shots = {}

function handlers.shot(ev)
	local size = ev.size or 2
	local ball = part({ Shape = Enum.PartType.Ball, Color = ev.c, Transparency = 0.1, Size = Vector3.one * size, Position = ev.o })
	local fire = Instance.new("Fire")
	fire.Color, fire.SecondaryColor = ev.c, Color3.fromRGB(255, 220, 90)
	fire.Size, fire.Heat = size * 2, 0
	fire.Parent = ball
	addTrail(ball, ev.c, size, 0.25)
	shots[ev.id] = { part = ball, pos = ev.o, dir = ev.d, left = ev.len, speed = ev.speed }
	Debris:AddItem(ball, ev.len / ev.speed + 1)
	ignite(ev.p, "RightHand", ev.c, 0.3)
end

function handlers.boom(ev)
	local shot = shots[ev.id]
	if shot then
		shot.part:Destroy()
		shots[ev.id] = nil
	end
	local explosion = Instance.new("Explosion")
	explosion.Position = ev.pos
	explosion.BlastRadius = ev.r
	explosion.BlastPressure = 0 -- visual only
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = workspace
	local sphere = part({ Shape = Enum.PartType.Ball, Color = ev.c, Transparency = 0.1, Size = Vector3.one * 2, Position = ev.pos })
	fadeOut(sphere, 0.35, { Size = Vector3.one * ev.r * 2 })
	burst(ev.pos, ev.c, 25, { texture = TEX_FIRE, size = 3, speed = ev.r * 2.5, life = 0.5 })
	burst(ev.pos, Color3.fromRGB(90, 90, 90), 10, { texture = TEX_SMOKE, size = 4, speed = ev.r, life = 0.8, gravity = Vector3.new(0, 8, 0) })
	flashLight(ev.pos, ev.c, ev.r * 2.5, 0.4)
	showHits(ev.hits, ev.c)
end

-- Sanji: a flaming spin kick around the player.
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
		burst(pos, ev.c, 4, { texture = TEX_FIRE, size = 2.5, speed = 3, life = 0.45, gravity = Vector3.new(0, 15, 0) })
	end
	ignite(ev.p, "RightFoot", ev.c, 0.35)
	showHits(ev.hits, ev.c)
end

-- Robin: arms sprout from the ground in a circle of petals.
function handlers.hands(ev)
	local ground = groundAt(ev.pos)
	local scale = ev.r / 7
	shockwave(ground + Vector3.new(0, 0.15, 0), ev.r, ev.c, 0.5)
	local count = scale > 1.2 and 7 or 4
	for i = 1, count do
		local a = i / count * 2 * math.pi + math.random()
		local d = math.random() * ev.r * 0.6
		local base = CFrame.new(ground + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
			* CFrame.Angles(math.rad(math.random(-20, 20)), 0, math.rad(math.random(-20, 20)))
		local height = (3.5 + math.random() * 2) * scale
		local width = 0.7 * scale
		local arm = part({ Material = SMOOTH, Color = SKIN, Size = Vector3.new(width, 0.1, width), CFrame = base })
		local cuff = part({ Color = ev.c, Size = Vector3.new(width * 1.4, 0.5 * scale, width * 1.4), CFrame = base * CFrame.new(0, 0.25 * scale, 0) })
		local hand = part({ Shape = Enum.PartType.Ball, Material = SMOOTH, Color = SKIN, Size = Vector3.one * width * 1.7, CFrame = base })
		tween(arm, 0.14, { Size = Vector3.new(width, height, width), CFrame = base * CFrame.new(0, height / 2, 0) }, Enum.EasingStyle.Back)
		tween(hand, 0.14, { CFrame = base * CFrame.new(0, height, 0) }, Enum.EasingStyle.Back)
		task.delay(0.45, function()
			for _, p in { arm, cuff, hand } do
				fadeOut(p, 0.2)
			end
		end)
	end
	burst(ground + Vector3.new(0, 2, 0), Color3.fromRGB(255, 160, 220), 16, { size = 1.2, speed = 8, life = 0.6, gravity = Vector3.new(0, -6, 0) })
	showHits(ev.hits, ev.c)
end

-- Chopper: fists circling the player (positions follow server time).
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

-- An enemy goes down in a puff of smoke.
function handlers.death(ev)
	burst(ev.pos, Color3.fromRGB(200, 200, 200), math.floor(6 * ev.s) + 2, { texture = TEX_SMOKE, size = 2.5 * ev.s, speed = 6, life = 0.5, gravity = Vector3.new(0, 6, 0) })
	burst(ev.pos, ev.c, 6, { size = 1, speed = 15, life = 0.3 })
end

function handlers.anim(_ev) end -- the animation itself is played in Effects.play

-- Per-frame updates -------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt)
	for id, shot in shots do
		if not shot.part.Parent then
			shots[id] = nil
		elseif shot.left > 0 then
			local move = math.min(shot.left, shot.speed * dt)
			shot.pos += shot.dir * move
			shot.left -= move
			shot.part.Position = shot.pos
		end
	end

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
	local handler = handlers[ev.k]
	if handler then
		local ok, err = pcall(handler, ev)
		if not ok then
			warn("Effect " .. tostring(ev.k) .. " failed: " .. tostring(err))
		end
	end
end

function Effects.clear()
	for player in orbits do
		clearOrbits(player)
	end
	for _, shot in shots do
		shot.part:Destroy()
	end
	table.clear(shots)
end

return Effects
