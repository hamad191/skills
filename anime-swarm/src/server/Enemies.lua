-- Enemy spawning, movement, attacks (melee, rifle shots, telegraphed blasts), damage, and XP orbs.
-- Enemies are anchored parts moved by the server: cheap enough for big swarms.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)
local Fx = require(script.Parent.Fx)

local Enemies = {}
Enemies.onKilled = function(_enemy, _killer) end
Enemies.onPickup = function(_player, _xp) end
Enemies.onChest = function(_runKey, _kind, _opener) end -- a crew member opened a treasure chest

local list, orbs, bullets, chests = {}, {}, {}, {}
local nextBulletId = 0
local lastTargets = {} -- targets from the latest step, used when delayed blasts land
local NO_TARGETS = {}
local BULLET_SPEED = 45
local BLAST_COLOR = Color3.fromRGB(255, 80, 40)

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

-- What enemies carry: same format as BODY, plus an optional rotation. Colors here are fixed.
local STEEL = Color3.fromRGB(210, 215, 225)
local GUNMETAL = Color3.fromRGB(45, 45, 50)
local GEAR = {
	sword = {
		{ "Blade", Vector3.new(0.12, 0.3, 3), Vector3.new(1.45, -1.25, -1.6), STEEL },
		{ "Guard", Vector3.new(0.6, 0.15, 0.15), Vector3.new(1.45, -1.25, -0.1), Color3.fromRGB(200, 170, 60) },
	},
	rifle = {
		{ "Rifle", Vector3.new(0.35, 0.45, 3.4), Vector3.new(0.9, -0.5, -1.4), GUNMETAL },
		{ "Stock", Vector3.new(0.4, 0.7, 0.9), Vector3.new(0.9, -0.6, 0.2), Color3.fromRGB(110, 70, 40) },
	},
	cannon = {
		{ "Cannon", Vector3.new(3.2, 1.1, 1.1), Vector3.new(1.2, 1.2, -0.4), GUNMETAL, Enum.PartType.Cylinder, CFrame.Angles(0, math.pi / 2, 0) },
	},
	coat = {
		{ "Coat", Vector3.new(2.4, 2.8, 0.2), Vector3.new(0, -0.5, 0.62), Color3.fromRGB(250, 250, 250) },
		{ "EpauletL", Vector3.new(0.9, 0.25, 1.1), Vector3.new(-1.3, 0.95, 0), Color3.fromRGB(230, 190, 60) },
		{ "EpauletR", Vector3.new(0.9, 0.25, 1.1), Vector3.new(1.3, 0.95, 0), Color3.fromRGB(230, 190, 60) },
	},
}

-- runKey: which adventure this enemy belongs to; it only chases that crew.
-- look (optional): { name, color, accent } to dress up a named boss.
function Enemies.spawn(kind, x, z, hpScale, dmgScale, runKey, look)
	local def = Config.Enemies[kind]
	local y = groundY(x, z)
	if not y then
		return nil
	end
	look = look or {}
	local colors = { color = look.color or def.color, accent = look.accent or def.accent, skin = def.skin, eyes = def.eyes }
	local name = look.name or def.name
	local s = def.scale
	local model = Instance.new("Model")
	model.Name = name
	local torso = makePart({ Name = "Torso", Size = Vector3.new(2, 2, 1) * s, Color = colors.color }, model)
	torso.CFrame = CFrame.new(x, y + LEG_DEPTH * s, z)
	local parts = { Torso = torso }
	local function attach(pieceName, size, offset, color, shape, rotation)
		local p = makePart({ Name = pieceName, Size = size * s, Color = color, Shape = shape or Enum.PartType.Block }, nil)
		p.Anchored, p.Massless = false, true
		p.CFrame = torso.CFrame * CFrame.new(offset * s) * (rotation or CFrame.identity)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = torso, p
		weld.Parent = p
		p.Parent = model
		parts[pieceName] = p
		return p
	end
	for _, b in BODY do
		local p = attach(b[1], b[2], b[3], colors[b[4]] or Color3.fromRGB(20, 20, 20), b[5])
		if b[4] == "eyes" and def.eyes then
			p.Material = Enum.Material.Neon
		end
	end
	for _, g in GEAR[def.gear] or {} do
		attach(g[1], g[2], g[3], g[4], g[5], g[6])
	end
	model.PrimaryPart = torso
	model.Parent = folder

	local hp = def.hp * hpScale
	local now = os.clock()
	local e = {
		model = model, root = torso, head = parts.Head, def = def, kind = kind, run = runKey,
		color = colors.color, skin = colors.skin, name = name,
		hp = hp, maxHp = hp, damage = def.damage * dmgScale,
		radius = 1.2 * s, lastHit = 0, phase = math.random() * 10,
		nextAttack = now + math.random() * (def.fireRate or 1) + 1,
		nextSlam = now + (def.slamEvery or 0), nextRing = now + (def.ringEvery or 0),
	}
	if def.healthBar then
		e.bar = makeBar(torso, s, name)
	end
	table.insert(list, e)
	return e
end

-- A telegraphed blast: players see a red circle, then everyone still inside gets hit.
local function blast(e, pos, radius, damage, delay)
	Fx.emit("warn", { pos = pos, r = radius, t = delay })
	local runKey = e.run
	task.delay(delay, function()
		for _, t in lastTargets[runKey] or NO_TARGETS do
			if t.hum.Health > 0 and flat(t.root.Position - pos).Magnitude <= radius then
				hurt(t, damage)
			end
		end
		Fx.emit("slam", { pos = pos, r = radius, c = BLAST_COLOR })
	end)
end

-- A rifle bullet flying flat toward the target.
local function shoot(e, target)
	nextBulletId += 1
	local from = e.root.Position
	local dir = flat(target.root.Position - from)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, -1)
	local range = e.def.range * 1.6
	table.insert(bullets, { id = nextBulletId, pos = from, dir = dir, left = range, damage = e.damage, run = e.run })
	Fx.emit("eshot", { id = nextBulletId, o = from, d = dir, speed = BULLET_SPEED, len = range })
end

-- Ranged and boss attacks. Melee hits happen in Enemies.step.
local function specialAttacks(e, target, dist, targets, now)
	local def = e.def
	if def.ai == "ranged" and dist <= def.range and now >= e.nextAttack then
		e.nextAttack = now + def.fireRate
		shoot(e, target)
	elseif def.ai == "artillery" and dist <= def.range and now >= e.nextAttack then
		e.nextAttack = now + def.fireRate
		blast(e, target.root.Position, def.blast, e.damage, 1.4)
	elseif def.ai == "boss" then
		if now >= e.nextSlam then
			e.nextSlam = now + def.slamEvery
			local victim = targets[math.random(#targets)]
			blast(e, victim.root.Position, def.blast, e.damage * 1.5, 1.2)
		end
		if def.ringEvery and now >= e.nextRing then
			e.nextRing = now + def.ringEvery
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
		e.bar.Size = UDim2.fromScale(math.max(e.hp, 0) / e.maxHp, 1)
	end
	if e.hp > 0 then
		flash(e)
		return
	end
	e.dead = true
	if e.def.xp > 0 then
		dropOrb(e.root.Position - Vector3.new(0, LEG_DEPTH * e.def.scale - 0.8, 0), e.def.xp, e.run)
	end
	Fx.emit("death", { pos = e.root.Position, c = e.color, s = e.def.scale })
	local chestChance = Config.CHESTS[e.kind]
	if chestChance and math.random() < chestChance then
		dropChest(e.root.Position - Vector3.new(0, LEG_DEPTH * e.def.scale, 0), e.run, e.kind)
	end
	Enemies.onKilled(e, player)
	e.model:Destroy()
end

-- targetsByRun: [runKey] = array of { player, root, hum, magnet }
function Enemies.step(dt, targetsByRun)
	local now = os.clock()
	lastTargets = targetsByRun
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
			local pos = e.root.Position
			local to = flat(best.root.Position - pos)
			local reach = e.radius + 2
			-- shooters stop at a distance; everyone else walks right up
			local stopAt = (e.def.ai == "ranged" or e.def.ai == "artillery") and e.def.range * 0.8 or reach
			if bestDist > stopAt then
				local newPos = pos + to.Unit * math.min(e.def.speed * dt, bestDist - stopAt)
				-- waddle side to side while walking
				local sway = math.sin(now * 9 + e.phase) * 0.12
				e.root.CFrame = CFrame.lookAt(newPos, newPos + to) * CFrame.Angles(0, 0, sway)
			end
			if bestDist <= reach and now - e.lastHit >= 1 then
				e.lastHit = now
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

	for i = #bullets, 1, -1 do
		local b = bullets[i]
		local move = BULLET_SPEED * dt
		b.pos += b.dir * move
		b.left -= move
		local hit
		for _, t in targetsByRun[b.run] or NO_TARGETS do
			if flat(t.root.Position - b.pos).Magnitude <= 2.2 then
				hit = t
				break
			end
		end
		if hit then
			hurt(hit, b.damage)
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

function Enemies.count(runKey)
	local n = 0
	for _, e in list do
		if e.run == runKey and not e.dead then
			n += 1
		end
	end
	return n
end

-- Removes one adventure's enemies, bullets, chests and XP orbs.
function Enemies.clear(runKey)
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
