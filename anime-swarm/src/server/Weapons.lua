-- Auto-firing anime weapons. Each weapon kind targets and damages enemies on its own,
-- then tells clients what to draw through Fx.
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)
local Enemies = require(script.Parent.Enemies)
local Progression = require(script.Parent.Progression)
local Fx = require(script.Parent.Fx)

local Weapons = {}
local projectiles = {}
local orbitSent = {} -- [player] = { [weaponName] = signature last sent to clients }
local loadoutSent = {} -- [player] = signature of the skill emblems last sent to clients
local nextShotId = 0
local nextOrbitResync = 0

local PROJECTILE_SPEED = 60
local MAX_HITS_SHOWN = 15

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function stats(s, name, level)
	local w = Config.Weapons[name]
	local up = level - 1
	local mastery = s.mastery[w.from or name] or 0 -- Captain Grey's training (evolutions use their base skill)
	return {
		w = w,
		damage = w.damage * (1 + 0.2 * up) * (1 + Config.MASTERY.damage * mastery) * Progression.damageMult(s),
		cooldown = w.cooldown * (1 - 0.04 * up) * (1 - Config.MASTERY.cooldown * mastery) * Progression.cooldownMult(s),
		range = w.range * Progression.areaMult(s),
		radius = (w.radius or 0) * Progression.areaMult(s),
		count = (w.count or 1) + math.floor(up / 3) + math.floor(Progression.bonus(s, "count")),
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

-- Uses server time so clients can draw orbiting fists in the same place.
local function orbitPositions(root, st)
	local now = workspace:GetServerTimeNow()
	local out = {}
	for i = 1, st.count do
		local a = now * 3 + i * 2 * math.pi / st.count
		out[i] = root.Position + Vector3.new(math.cos(a) * st.range, 0, math.sin(a) * st.range)
	end
	return out
end

-- Damages an enemy (rolling for a critical hit) and records the hit so clients can show
-- sparks and damage numbers.
local function strike(s, player, e, damage, hits)
	if e.dead then
		return
	end
	local crit = math.random() < Config.BASE_CRIT_CHANCE + Progression.bonus(s, "crit")
	if crit then
		damage *= Config.BASE_CRIT_DAMAGE + Progression.bonus(s, "critDamage")
	end
	if #hits < MAX_HITS_SHOWN then
		table.insert(hits, { e.root.Position, math.floor(damage + 0.5), crit })
	end
	-- damage per skill, for the results screen
	local source = s.firing or "?"
	s.damageBy[source] = (s.damageBy[source] or 0) + math.min(damage, e.hp)
	Enemies.damage(e, damage, player)
end

-- Each returns true if it fired, false if there was nothing to hit.
local fire = {}

function fire.cone(player, s, root, st)
	local target = Enemies.nearest(root.Position, st.range * 2.5)
	if not target then
		return false
	end
	local base = directionTo(root, target)
	local cosHalf = math.cos(math.rad(st.w.angle / 2))
	local nearby = Enemies.inRadius(root.Position, st.range)
	for i = 0, st.count - 1 do
		local dir = rotate(base, i * 2 * math.pi / st.count)
		local hits = {}
		for _, e in nearby do
			local d = flat(e.root.Position - root.Position)
			if d.Magnitude < 0.1 or d.Unit:Dot(dir) >= cosHalf then
				strike(s, player, e, st.damage, hits)
			end
		end
		Fx.emit(st.w.fx, {
			p = player, anim = st.w.anim, c = st.w.color, o = root.Position, d = dir,
			r = st.range, a = st.w.angle, arcs = st.w.arcs or 1, hits = hits,
		})
	end
	return true
end

function fire.chain(player, s, root, st)
	local current = Enemies.nearest(root.Position, st.range)
	if not current then
		return false
	end
	local visited, points, hits = {}, {}, {}
	for _ = 1, st.count do
		visited[current] = true
		table.insert(points, current.root.Position)
		strike(s, player, current, st.damage, hits)
		current = Enemies.nearest(points[#points], 15, visited)
		if not current then
			break
		end
	end
	Fx.emit(st.w.fx, { p = player, anim = st.w.anim, c = st.w.color, cloud = st.w.cloud, pts = points, hits = hits })
	return true
end

function fire.projectile(player, s, root, st)
	local targets = Enemies.closest(root.Position, st.range, st.count)
	if #targets == 0 then
		return false
	end
	for i = 1, st.count do
		local target = targets[(i - 1) % #targets + 1]
		nextShotId += 1
		local shot = {
			id = nextShotId, player = player, s = s, pos = root.Position, dir = directionTo(root, target),
			left = st.range, damage = st.damage, radius = st.radius, color = st.w.color, fire = st.w.fire,
			source = s.firing,
		}
		table.insert(projectiles, shot)
		Fx.emit("shot", {
			id = shot.id, p = player, anim = i == 1 and st.w.anim or nil, c = st.w.color, fire = st.w.fire,
			o = shot.pos, d = shot.dir, len = st.range, speed = PROJECTILE_SPEED, size = 1.5 + st.radius / 4,
		})
	end
	return true
end

function fire.clones(player, s, root, st)
	if not Enemies.nearest(root.Position, 40) then
		return false
	end
	Fx.emit("anim", { p = player, anim = st.w.anim })
	for i = 1, st.count do
		task.delay((i - 1) * 0.12, function()
			if not root.Parent then
				return
			end
			local offset = Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
			local target = Enemies.nearest(root.Position + offset, 30)
			local pos = target and target.root.Position or root.Position + offset
			pos = Vector3.new(pos.X, root.Position.Y, pos.Z)
			local hits = {}
			for _, e in Enemies.inRadius(pos, st.range) do
				strike(s, player, e, st.damage, hits)
			end
			Fx.emit(st.w.fx, { c = st.w.color, pos = pos, r = st.range, hits = hits })
		end)
	end
	return true
end

function fire.orbit(player, s, root, st)
	local hits = {}
	for _, pos in orbitPositions(root, st) do
		for _, e in Enemies.inRadius(pos, 2.5) do
			strike(s, player, e, st.damage, hits)
		end
	end
	if #hits > 0 then
		Fx.emit("hits", { c = st.w.color, hits = hits })
	end
	return true
end

function fire.line(player, s, root, st)
	local target = Enemies.nearest(root.Position, st.range)
	if not target then
		return false
	end
	local first = directionTo(root, target)
	local origin = root.Position
	local nearby = Enemies.inRadius(origin, st.range)
	for i = 1, st.count do
		local dir = i == 1 and first or rotate(first, math.random() * 2 * math.pi)
		local hits = {}
		for _, e in nearby do
			local rel = flat(e.root.Position - origin)
			local along = rel:Dot(dir)
			if along > 0 and (rel - dir * along).Magnitude <= st.w.width + e.radius then
				strike(s, player, e, st.damage, hits)
			end
		end
		Fx.emit(st.w.fx, {
			p = player, anim = i == 1 and st.w.anim or nil, c = st.w.color, arm = st.w.arm,
			o = origin, d = dir, len = st.range, w = st.w.width, i = i, hits = hits,
		})
	end
	return true
end

function fire.aura(player, s, root, st)
	local nearby = Enemies.inRadius(root.Position, st.range)
	if #nearby == 0 then
		return false
	end
	local hits = {}
	for _, e in nearby do
		strike(s, player, e, st.damage, hits)
	end
	Fx.emit(st.w.fx, {
		p = player, anim = st.w.anim, c = st.w.color, fire = st.w.fire,
		o = root.Position, pos = root.Position, r = st.range, hits = hits,
	})
	return true
end

local function stepProjectiles(dt)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local move = PROJECTILE_SPEED * dt
		p.pos += p.dir * move
		p.left -= move
		if p.left <= 0 or Enemies.nearest(p.pos, 1.5) then
			local hits = {}
			p.s.firing = p.source
			for _, e in Enemies.inRadius(p.pos, p.radius) do
				strike(p.s, p.player, e, p.damage, hits)
			end
			Fx.emit("boom", { id = p.id, pos = p.pos, r = p.radius, c = p.color, fire = p.fire, hits = hits })
			table.remove(projectiles, i)
		end
	end
end

-- Tells clients which orbiting fists to draw around a player (st = nil removes them).
local function syncOrbit(player, name, st)
	local sent = orbitSent[player] or {}
	orbitSent[player] = sent
	local signature = st and st.count .. ":" .. math.floor(st.range * 10) or nil
	if sent[name] ~= signature then
		sent[name] = signature
		Fx.emit("orbit", {
			p = player, key = name, n = st and st.count or 0, r = st and st.range or 0, c = st and st.w.color,
		})
	end
end

-- Tells clients which skill emblems to float around a player (one per owned skill).
local function syncLoadout(player, s)
	local names = {}
	for name in s.weapons do
		table.insert(names, name)
	end
	table.sort(names)
	local signature = table.concat(names, ",")
	if loadoutSent[player] == signature then
		return
	end
	loadoutSent[player] = signature
	local items = {}
	for _, name in names do
		local def = Progression.def(name)
		local look = def.fused and Config.Weapons[def.parts[1]] or def
		if look.kind ~= "orbit" then -- orbiting skills already circle the player
			table.insert(items, { icon = def.icon, c = def.color, fx = look.fx, fire = look.fire })
		end
	end
	Fx.emit("loadout", { p = player, items = items })
end

-- Stops drawing a player's orbiting weapons and emblems and drops their projectiles in flight.
function Weapons.cleanup(player)
	if orbitSent[player] then
		Fx.emit("orbit", { p = player, all = true, n = 0 })
		orbitSent[player] = nil
	end
	if loadoutSent[player] then
		Fx.emit("loadout", { p = player, items = {} })
		loadoutSent[player] = nil
	end
	for i = #projectiles, 1, -1 do
		if projectiles[i].player == player then
			table.remove(projectiles, i)
		end
	end
end

-- Draws orbiting weapons and fires the weapon when its cooldown is up. `key` names its timer.
local function useWeapon(player, s, root, key, st, now)
	if st.w.kind == "orbit" then
		syncOrbit(player, key, st)
	end
	if now >= (s.timers[key] or 0) then
		s.firing = key:match("^(.-)#%d+$") or key -- fused parts count toward their fusion
		local fired = fire[st.w.kind](player, s, root, st)
		s.timers[key] = now + (fired and st.cooldown or 0.2)
	end
end

function Weapons.step(dt)
	local now = os.clock()
	if now >= nextOrbitResync then
		-- redraw orbits from scratch now and then so players who join mid-run see them too
		nextOrbitResync = now + 3
		for player in orbitSent do
			if orbitSent[player] then
				Fx.emit("orbit", { p = player, all = true, n = 0 })
				orbitSent[player] = nil
			end
		end
		table.clear(loadoutSent)
	end
	stepProjectiles(dt)
	for player, s in Progression.all() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if s.dead or not root then
			Weapons.cleanup(player)
			continue
		end
		syncLoadout(player, s)
		for key in orbitSent[player] or {} do
			local owner = key:match("^(.-)#%d+$") or key -- fused parts are "<fusion>#1" and "<fusion>#2"
			if not s.weapons[owner] then
				syncOrbit(player, key, nil) -- evolved or fused away
			end
		end
		for name, level in s.weapons do
			local def = Progression.def(name)
			if def.fused then
				-- a fusion fires both of its skills at max level, boosted
				for i, part in def.parts do
					local st = stats(s, part, Config.Weapons[part].evolved and 1 or Config.WEAPON_MAX)
					st.damage *= Config.FUSION.damage
					st.cooldown *= Config.FUSION.cooldown
					st.range *= Config.FUSION.area
					st.radius *= Config.FUSION.area
					st.count += Config.FUSION.extraHits
					useWeapon(player, s, root, name .. "#" .. i, st, now)
				end
			else
				useWeapon(player, s, root, name, stats(s, name, level), now)
			end
		end
	end
end

return Weapons
