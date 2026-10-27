-- Enemy spawning, chasing, damage, and XP orbs.
-- Enemies are anchored parts moved by the server: cheap enough for big swarms.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)
local Fx = require(script.Parent.Fx)

local Enemies = {}
Enemies.onKilled = function(_enemy, _killer) end
Enemies.onPickup = function(_player, _xp) end

local list, orbs = {}, {}

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
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, 12)
	back.Position = UDim2.fromOffset(0, 22)
	back.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 40, 40)
	fill.BorderSizePixel = 0
	fill.Parent = back
	return fill
end

local function dropOrb(pos, xp)
	-- merge into an existing orb when there are too many on the map
	if #orbs >= 250 then
		local o = orbs[math.random(#orbs)]
		o.xp += xp
		return
	end
	local big = xp >= 10
	local part = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (big and 1.6 or 0.9),
		Material = Enum.Material.Neon,
		Color = big and Color3.fromRGB(180, 80, 255) or Color3.fromRGB(70, 160, 255),
		Position = pos,
	}, orbFolder)
	table.insert(orbs, { part = part, xp = xp })
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
			e.root.Color = e.def.color
			e.head.Color = e.def.skin
		end
	end)
end

-- Body parts: name, size, offset from the torso, color key, shape (all scaled by def.scale)
local BODY = {
	{ "LeftLeg", Vector3.new(0.9, 1.6, 1), Vector3.new(-0.5, -1.8, 0), "accent" },
	{ "RightLeg", Vector3.new(0.9, 1.6, 1), Vector3.new(0.5, -1.8, 0), "accent" },
	{ "LeftArm", Vector3.new(0.8, 1.8, 0.8), Vector3.new(-1.45, -0.1, 0), "color" },
	{ "RightArm", Vector3.new(0.8, 1.8, 0.8), Vector3.new(1.45, -0.1, 0), "color" },
	{ "LeftHand", Vector3.new(0.7, 0.7, 0.7), Vector3.new(-1.45, -1.2, 0), "skin", Enum.PartType.Ball },
	{ "RightHand", Vector3.new(0.7, 0.7, 0.7), Vector3.new(1.45, -1.2, 0), "skin", Enum.PartType.Ball },
	{ "Head", Vector3.new(1.7, 1.7, 1.7), Vector3.new(0, 1.85, 0), "skin", Enum.PartType.Ball },
	{ "Cap", Vector3.new(1.8, 0.45, 1.8), Vector3.new(0, 2.65, 0), "accent" },
	{ "Brim", Vector3.new(1.2, 0.15, 0.6), Vector3.new(0, 2.45, -1), "accent" },
	{ "LeftEye", Vector3.new(0.32, 0.32, 0.32), Vector3.new(-0.35, 2, -0.75), "eyes", Enum.PartType.Ball },
	{ "RightEye", Vector3.new(0.32, 0.32, 0.32), Vector3.new(0.35, 2, -0.75), "eyes", Enum.PartType.Ball },
}
local LEG_DEPTH = 2.6 -- torso center to the soles of the feet

function Enemies.spawn(kind, x, z, hpScale, dmgScale)
	local def = Config.Enemies[kind]
	local y = groundY(x, z)
	if not y then
		return nil
	end
	local s = def.scale
	local model = Instance.new("Model")
	model.Name = def.name
	local torso = makePart({ Name = "Torso", Size = Vector3.new(2, 2, 1) * s, Color = def.color }, model)
	torso.CFrame = CFrame.new(x, y + LEG_DEPTH * s, z)
	local parts = { Torso = torso }
	for _, b in BODY do
		local name, size, offset, colorKey, shape = b[1], b[2], b[3], b[4], b[5]
		local color = def[colorKey] or Color3.fromRGB(20, 20, 20)
		local p = makePart({ Name = name, Size = size * s, Color = color, Shape = shape or Enum.PartType.Block }, nil)
		if colorKey == "eyes" and def.eyes then
			p.Material = Enum.Material.Neon
		end
		p.Anchored, p.Massless = false, true
		p.CFrame = torso.CFrame * CFrame.new(offset * s)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = torso, p
		weld.Parent = p
		p.Parent = model
		parts[name] = p
	end
	model.PrimaryPart = torso
	model.Parent = folder

	local hp = def.hp * hpScale
	local e = {
		model = model, root = torso, head = parts.Head, def = def, kind = kind,
		hp = hp, maxHp = hp, damage = def.damage * dmgScale,
		radius = 1.2 * s, lastHit = 0, phase = math.random() * 10,
	}
	if def.healthBar then
		e.bar = makeBar(torso, s, def.name)
	end
	table.insert(list, e)
	return e
end

function Enemies.damage(e, amount, player)
	if e.dead then
		return
	end
	e.hp -= amount
	if e.bar then
		e.bar.Size = UDim2.fromScale(math.max(e.hp, 0) / e.maxHp, 1)
	end
	if e.hp > 0 then
		flash(e)
		return
	end
	e.dead = true
	if e.def.xp > 0 then
		dropOrb(e.root.Position - Vector3.new(0, LEG_DEPTH * e.def.scale - 0.8, 0), e.def.xp)
	end
	Fx.emit("death", { pos = e.root.Position, c = e.def.color, s = e.def.scale })
	Enemies.onKilled(e, player)
	e.model:Destroy()
end

-- targets: array of { player, root, hum, magnet }
function Enemies.step(dt, targets)
	local now = os.clock()
	for i = #list, 1, -1 do
		local e = list[i]
		if e.dead then
			table.remove(list, i)
			continue
		end
		local best, bestDist
		for _, t in targets do
			local d = flat(t.root.Position - e.root.Position).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = t, d
			end
		end
		if best then
			local pos = e.root.Position
			local to = flat(best.root.Position - pos)
			local reach = e.radius + 2
			if bestDist > reach then
				local newPos = pos + to.Unit * math.min(e.def.speed * dt, bestDist - reach)
				-- waddle side to side while walking
				local sway = math.sin(now * 9 + e.phase) * 0.12
				e.root.CFrame = CFrame.lookAt(newPos, newPos + to) * CFrame.Angles(0, 0, sway)
			elseif now - e.lastHit >= 1 then
				e.lastHit = now
				best.hum:TakeDamage(e.damage)
			end
		end
	end

	for i = #orbs, 1, -1 do
		local o = orbs[i]
		local t = o.target
		if t and (t.hum.Health <= 0 or not t.root.Parent) then
			t, o.target = nil, nil
		end
		if not t then
			for _, candidate in targets do
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
				o.part.Position += to.Unit * math.min(to.Magnitude, 60 * dt)
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

function Enemies.count()
	return #list
end

function Enemies.clear()
	for _, e in list do
		e.dead = true
		e.model:Destroy()
	end
	table.clear(list)
	for _, o in orbs do
		o.part:Destroy()
	end
	table.clear(orbs)
end

return Enemies
