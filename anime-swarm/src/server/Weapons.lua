-- Auto-firing anime weapons. Each weapon kind targets enemies on its own.
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Config = require(RS.Shared.Config)
local Enemies = require(script.Parent.Enemies)
local Progression = require(script.Parent.Progression)

local Weapons = {}
local projectiles = {}
local orbits = {} -- [player] = { [weaponName] = { parts } }

local fxFolder = Instance.new("Folder")
fxFolder.Name = "FX"
fxFolder.Parent = workspace

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function makeOrb(color, size)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * size
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Color = Enum.Material.Neon, color
	p.Parent = fxFolder
	return p
end

-- short-lived fading effect
local function fx(cf, size, color, shape, life)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Color, p.Transparency = Enum.Material.Neon, color, 0.3
	p.Shape = shape or Enum.PartType.Block
	p.Size, p.CFrame = size, cf
	p.Parent = fxFolder
	life = life or 0.35
	TweenService:Create(p, TweenInfo.new(life), { Transparency = 1 }):Play()
	Debris:AddItem(p, life + 0.05)
end

local function beamFx(from, to, width, color, life)
	local length = (to - from).Magnitude
	if length > 0.1 then
		fx(CFrame.lookAt((from + to) / 2, to), Vector3.new(width, 0.4, length), color, nil, life)
	end
end

local function stats(s, name, level)
	local w = Config.Weapons[name]
	local up = level - 1
	return {
		w = w,
		damage = w.damage * (1 + 0.25 * up) * Progression.damageMult(s),
		cooldown = w.cooldown * (1 - 0.06 * up) * Progression.cooldownMult(s),
		range = w.range * Progression.areaMult(s),
		radius = (w.radius or 0) * Progression.areaMult(s),
		count = (w.count or 1) + math.floor(up / 2),
	}
end

local function directionTo(root, target)
	local d = flat(target.root.Position - root.Position)
	if d.Magnitude < 0.1 then
		d = flat(root.CFrame.LookVector)
	end
	return d.Unit
end

local function rotate(dir, angle)
	return CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(dir)
end

local function orbitPositions(root, st, now)
	local out = {}
	for i = 1, st.count do
		local a = now * 3 + i * 2 * math.pi / st.count
		out[i] = root.Position + Vector3.new(math.cos(a) * st.range, 0, math.sin(a) * st.range)
	end
	return out
end

-- Each returns true if it fired, false if there was nothing to hit.
local fire = {}

function fire.cone(player, _s, root, st)
	local target = Enemies.nearest(root.Position, st.range * 2.5)
	if not target then
		return false
	end
	local base = directionTo(root, target)
	local cosHalf = math.cos(math.rad(st.w.angle / 2))
	local nearby = Enemies.inRadius(root.Position, st.range)
	for i = 0, st.count - 1 do
		local dir = rotate(base, i * 2 * math.pi / st.count)
		beamFx(root.Position, root.Position + dir * st.range, st.range, st.w.color)
		for _, e in nearby do
			local d = flat(e.root.Position - root.Position)
			if d.Magnitude < 0.1 or d.Unit:Dot(dir) >= cosHalf then
				Enemies.damage(e, st.damage, player)
			end
		end
	end
	return true
end

function fire.chain(player, _s, root, st)
	local current = Enemies.nearest(root.Position, st.range)
	if not current then
		return false
	end
	local hit, from = {}, root.Position
	for _ = 1, st.count do
		hit[current] = true
		local to = current.root.Position
		beamFx(from, to, 0.5, st.w.color, 0.2)
		Enemies.damage(current, st.damage, player)
		from = to
		current = Enemies.nearest(to, 15, hit)
		if not current then
			break
		end
	end
	return true
end

function fire.projectile(player, _s, root, st)
	local targets = Enemies.closest(root.Position, st.range, st.count)
	if #targets == 0 then
		return false
	end
	for i = 1, st.count do
		local target = targets[(i - 1) % #targets + 1]
		table.insert(projectiles, {
			player = player, pos = root.Position, dir = directionTo(root, target),
			left = st.range, damage = st.damage, radius = st.radius, color = st.w.color,
			part = makeOrb(st.w.color, 2),
		})
	end
	return true
end

function fire.clones(player, _s, root, st)
	if not Enemies.nearest(root.Position, 40) then
		return false
	end
	for i = 1, st.count do
		task.delay((i - 1) * 0.12, function()
			if not root.Parent then
				return
			end
			local offset = Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
			local target = Enemies.nearest(root.Position + offset, 30)
			local pos = target and target.root.Position or root.Position + offset
			pos = Vector3.new(pos.X, root.Position.Y, pos.Z)
			fx(CFrame.new(pos), Vector3.new(2, 5, 1), Color3.fromRGB(25, 25, 35), nil, 0.5) -- the clone
			fx(CFrame.new(pos), Vector3.one * st.range * 2, st.w.color, Enum.PartType.Ball)
			for _, e in Enemies.inRadius(pos, st.range) do
				Enemies.damage(e, st.damage, player)
			end
		end)
	end
	return true
end

function fire.orbit(player, _s, root, st)
	for _, pos in orbitPositions(root, st, os.clock()) do
		for _, e in Enemies.inRadius(pos, 2.5) do
			Enemies.damage(e, st.damage, player)
		end
	end
	return true
end

function fire.line(player, _s, root, st)
	local target = Enemies.nearest(root.Position, st.range)
	if not target then
		return false
	end
	local first = directionTo(root, target)
	local origin = root.Position
	local nearby = Enemies.inRadius(origin, st.range)
	for i = 1, st.count do
		local dir = i == 1 and first or rotate(first, math.random() * 2 * math.pi)
		beamFx(origin, origin + dir * st.range, st.w.width, st.w.color, 0.25)
		for _, e in nearby do
			local rel = flat(e.root.Position - origin)
			local along = rel:Dot(dir)
			if along > 0 and (rel - dir * along).Magnitude <= st.w.width + e.radius then
				Enemies.damage(e, st.damage, player)
			end
		end
	end
	return true
end

local function stepProjectiles(dt)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local move = 60 * dt
		p.pos += p.dir * move
		p.left -= move
		p.part.CFrame = CFrame.new(p.pos)
		if p.left <= 0 or Enemies.nearest(p.pos, 1.5) then
			fx(CFrame.new(p.pos), Vector3.one * p.radius * 2, p.color, Enum.PartType.Ball)
			for _, e in Enemies.inRadius(p.pos, p.radius) do
				Enemies.damage(e, p.damage, p.player)
			end
			p.part:Destroy()
			table.remove(projectiles, i)
		end
	end
end

local function updateOrbit(playerOrbits, name, root, st, now)
	local parts = playerOrbits[name] or {}
	playerOrbits[name] = parts
	while #parts < st.count do
		table.insert(parts, makeOrb(st.w.color, 1.6))
	end
	while #parts > st.count do
		table.remove(parts):Destroy()
	end
	for i, pos in orbitPositions(root, st, now) do
		parts[i].CFrame = CFrame.new(pos)
	end
end

function Weapons.cleanup(player)
	for _, parts in orbits[player] or {} do
		for _, p in parts do
			p:Destroy()
		end
	end
	orbits[player] = nil
end

function Weapons.clear()
	for _, p in projectiles do
		p.part:Destroy()
	end
	table.clear(projectiles)
	for player in orbits do
		Weapons.cleanup(player)
	end
end

function Weapons.step(dt)
	local now = os.clock()
	stepProjectiles(dt)
	for player, s in Progression.all() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if s.dead or not root then
			Weapons.cleanup(player)
			continue
		end
		local playerOrbits = orbits[player] or {}
		orbits[player] = playerOrbits
		-- remove orbit visuals for weapons that evolved away
		for name, parts in playerOrbits do
			if not s.weapons[name] then
				for _, p in parts do
					p:Destroy()
				end
				playerOrbits[name] = nil
			end
		end
		for name, level in s.weapons do
			local st = stats(s, name, level)
			if st.w.kind == "orbit" then
				updateOrbit(playerOrbits, name, root, st, now)
			end
			if now >= (s.timers[name] or 0) then
				local fired = fire[st.w.kind](player, s, root, st)
				s.timers[name] = now + (fired and st.cooldown or 0.2)
			end
		end
	end
end

return Weapons
