-- Per-run player state: XP, levels, level-up choices, weapons, passives, evolutions.
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)

local Progression = {}
local states = {} -- [player] = state
local remotes

function Progression.init(r)
	remotes = r
end

local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- Sum of class bonus, passives (boosted by Dr. Kureha's training), permanent upgrades,
-- gear, game passes and boosts for one stat.
function Progression.bonus(s, stat)
	local total = (s.classBonus[stat] or 0) + (s.extra[stat] or 0)
	for name, level in s.passives do
		local p = Config.Passives[name]
		if p.stat == stat then
			total += p.per * level * (1 + Config.TRAINING.boost * (s.training[name] or 0))
		end
	end
	for name, level in s.meta do
		local m = Config.Meta[name]
		if m and m.stat == stat then
			total += m.per * level
		end
	end
	return total
end

function Progression.damageMult(s)
	return 1 + Progression.bonus(s, "damage")
end

function Progression.cooldownMult(s)
	return math.max(0.4, 1 - Progression.bonus(s, "cooldown"))
end

function Progression.areaMult(s)
	return 1 + Progression.bonus(s, "area")
end

function Progression.magnet(s)
	return Config.BASE_MAGNET * (1 + Progression.bonus(s, "magnet"))
end

-- Skill slots: a few to start, more from the "Skill Slot" upgrade.
function Progression.slots(s)
	return math.min(Config.WEAPON_SLOTS_MAX, Config.WEAPON_SLOTS_START + math.floor(Progression.bonus(s, "slots")))
end

function Progression.xpNeeded(level)
	return 5 + level * 2
end

-- Fused skills are made on the fly from any two skills, so they live here instead of Config.
local fusionDefs = {} -- [fusionKey] = { name, desc, color, fused = true, parts = { a, b } }

local function fusionKey(a, b)
	if a > b then
		a, b = b, a
	end
	local key = "Fusion_" .. a .. "_" .. b
	if not fusionDefs[key] then
		local wa, wb = Config.Weapons[a], Config.Weapons[b]
		fusionDefs[key] = {
			name = wa.name .. " x " .. wb.name,
			desc = "Fires " .. wa.name .. " and " .. wb.name .. " together, much stronger.",
			color = wa.color:Lerp(wb.color, 0.5), icon = wa.icon .. wb.icon, fused = true, parts = { a, b },
		}
	end
	return key
end

-- Definition of any skill a player can own: a Config skill, an evolution or a fusion.
function Progression.def(name)
	return Config.Weapons[name] or fusionDefs[name]
end

function Progression.get(player)
	return states[player]
end

function Progression.all()
	return states
end

-- data: the player's save (upgrades, mastery, training). extra: stat bonuses from gear,
-- passes and boosts for this run.
function Progression.start(player, className, data, extra)
	if not Config.Classes[className] then
		className = Config.DEFAULT_CLASS
	end
	local class = Config.Classes[className]
	local s = {
		class = className, level = 1, xp = 0, kills = 0, bonusGold = 0, dead = false,
		weapons = { [class.weapon] = 1 }, passives = {}, timers = {},
		classBonus = class.bonus, meta = data.meta, mastery = data.mastery, training = data.training,
		extra = extra or {}, choices = nil, pending = 0, invulnerableUntil = 0,
	}
	s.rerolls = math.floor(Progression.bonus(s, "reroll"))
	states[player] = s
	return s
end

function Progression.stop(player)
	if states[player] then
		states[player] = nil
		if player.Parent then
			remotes.LevelUp:FireClient(player, nil)
		end
	end
end

function Progression.applyStats(player)
	local s = states[player]
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not s or not hum or hum.Health <= 0 then
		return
	end
	local ratio = hum.Health / hum.MaxHealth
	hum.MaxHealth = Config.BASE_HEALTH + Progression.bonus(s, "health")
	hum.Health = hum.MaxHealth * ratio
	hum.WalkSpeed = Config.BASE_SPEED * (1 + Progression.bonus(s, "speed"))
end

function Progression.sync(player)
	local s = states[player]
	if not s then
		return
	end
	local weapons, passives = {}, {}
	for name, level in s.weapons do
		local w = Progression.def(name)
		table.insert(weapons, {
			name = w.name, level = level, evo = w.evolved == true, fused = w.fused == true, color = w.color, icon = w.icon,
		})
	end
	for name, level in s.passives do
		table.insert(passives, { name = Config.Passives[name].name, level = level, icon = Config.Passives[name].icon })
	end
	remotes.Stats:FireClient(player, {
		level = s.level, xp = s.xp, need = Progression.xpNeeded(s.level),
		kills = s.kills, weapons = weapons, passives = passives, slots = Progression.slots(s),
	})
end

-- True if the player already has this skill, its evolution, or a fusion containing either.
local function ownsSkill(s, key)
	for name in s.weapons do
		local def = Progression.def(name)
		for _, part in def.fused and def.parts or { name } do
			if part == key or Config.Weapons[part].from == key then
				return true
			end
		end
	end
	return false
end

-- A skill can be fused once it is max level or evolved. Fusions can't be fused again.
local function fusionReady(name, level)
	local w = Config.Weapons[name]
	return w ~= nil and (w.evolved or level >= Config.WEAPON_MAX)
end

-- How likely each kind of card is. Crewmates' skills are rare so your own character's 6 come first.
local WEIGHT = { upgrade = 4, ownSkill = 3, crewSkill = 0.15, passive = 2 }

-- Removes and returns one entry, picked by weight.
local function takeWeighted(pool)
	local total = 0
	for _, c in pool do
		total += c.weight
	end
	local roll = math.random() * total
	for i, c in pool do
		roll -= c.weight
		if roll <= 0 then
			return table.remove(pool, i)
		end
	end
	return table.remove(pool)
end

local function buildChoices(s)
	local picks, pool, ready = {}, {}, {}
	for name, level in s.weapons do
		local w = Progression.def(name)
		if w.evolvesInto and level >= Config.WEAPON_MAX and (s.passives[w.evolveWith] or 0) >= Config.PASSIVE_MAX then
			table.insert(picks, { type = "evolve", key = name })
		elseif not w.evolved and not w.fused and level < Config.WEAPON_MAX then
			table.insert(pool, { type = "weapon", key = name, weight = WEIGHT.upgrade })
		end
		if fusionReady(name, level) then
			table.insert(ready, name)
		end
	end
	if #ready >= 2 then
		-- offer one random pair of maxed skills to fuse (reroll for a different pair)
		local a = table.remove(ready, math.random(#ready))
		table.insert(picks, { type = "fuse", a = a, b = ready[math.random(#ready)] })
	end
	if count(s.weapons) < Progression.slots(s) then
		for name, w in Config.Weapons do
			if not w.evolved and not ownsSkill(s, name) then
				local own = Config.SkillOwner[name] == s.class
				table.insert(pool, { type = "weapon", key = name, weight = own and WEIGHT.ownSkill or WEIGHT.crewSkill })
			end
		end
	end
	for name, level in s.passives do
		if level < Config.PASSIVE_MAX then
			table.insert(pool, { type = "passive", key = name, weight = WEIGHT.passive })
		end
	end
	if count(s.passives) < Config.PASSIVE_SLOTS then
		for name in Config.Passives do
			if not s.passives[name] then
				table.insert(pool, { type = "passive", key = name, weight = WEIGHT.passive })
			end
		end
	end

	while #picks > Config.CHOICES do
		table.remove(picks)
	end
	while #picks < Config.CHOICES and #pool > 0 do
		table.insert(picks, takeWeighted(pool))
	end
	if #picks == 0 then
		picks = { { type = "heal" }, { type = "gold" } }
	end
	return picks
end

local function describe(s, c)
	if c.type == "weapon" then
		local w = Config.Weapons[c.key]
		local level = (s.weapons[c.key] or 0) + 1
		local owner = Config.SkillOwner[c.key]
		local crew = level == 1 and owner ~= s.class
		return {
			title = w.name, color = w.color, icon = w.icon, level = level, max = Config.WEAPON_MAX,
			tag = crew and "CREW SKILL" or level == 1 and "NEW SKILL" or "UPGRADE",
			text = crew and owner .. "'s skill: " .. w.desc or level == 1 and w.desc or "More damage, faster attacks, more hits.",
		}
	elseif c.type == "passive" then
		local p = Config.Passives[c.key]
		local level = (s.passives[c.key] or 0) + 1
		return {
			title = p.name, text = p.desc, color = Color3.fromRGB(200, 210, 230), icon = p.icon,
			tag = level == 1 and "NEW PASSIVE" or "PASSIVE", level = level, max = Config.PASSIVE_MAX,
		}
	elseif c.type == "evolve" then
		local evo = Config.Weapons[Config.Weapons[c.key].evolvesInto]
		return { title = evo.name, text = evo.desc, color = evo.color, icon = evo.icon, tag = "EVOLUTION" }
	elseif c.type == "fuse" then
		local fused = Progression.def(fusionKey(c.a, c.b))
		return {
			title = fused.name, color = fused.color, icon = fused.icon, tag = "FUSION",
			text = "Fuse two maxed skills into one: both fire together with double damage. Frees a slot!",
		}
	elseif c.type == "heal" then
		return { title = "Meat on the Bone", text = "Heal 50 HP.", color = Color3.fromRGB(255, 170, 120), icon = "🍖", tag = "BONUS" }
	end
	return { title = "Gold Pouch", text = "+25 gold at the end of the run.", color = Color3.fromRGB(255, 215, 0), icon = "💰", tag = "BONUS" }
end

function Progression.offer(player)
	local s = states[player]
	s.choices = buildChoices(s)
	-- a moment of safety while the cards are open (the run keeps going in co-op)
	s.invulnerableUntil = math.max(s.invulnerableUntil, os.clock() + Config.LEVELUP_SHIELD)
	local cards = {}
	for i, c in s.choices do
		cards[i] = describe(s, c)
	end
	remotes.LevelUp:FireClient(player, cards, s.rerolls)
end

function Progression.addXP(player, amount)
	local s = states[player]
	if not s or s.dead then
		return
	end
	s.xp += amount * (1 + Progression.bonus(s, "xp"))
	while s.xp >= Progression.xpNeeded(s.level) do
		s.xp -= Progression.xpNeeded(s.level)
		s.level += 1
		s.pending += 1
	end
	if s.pending > 0 and not s.choices then
		Progression.offer(player)
	end
	Progression.sync(player)
end

function Progression.choose(player, index)
	local s = states[player]
	local c = s and not s.dead and s.choices and s.choices[index]
	if not c then
		return
	end
	if c.type == "weapon" then
		s.weapons[c.key] = (s.weapons[c.key] or 0) + 1
	elseif c.type == "passive" then
		s.passives[c.key] = (s.passives[c.key] or 0) + 1
	elseif c.type == "evolve" then
		s.weapons[c.key] = nil
		s.timers[c.key] = nil
		s.weapons[Config.Weapons[c.key].evolvesInto] = 1
	elseif c.type == "fuse" then
		s.weapons[c.a], s.weapons[c.b] = nil, nil
		s.timers[c.a], s.timers[c.b] = nil, nil
		s.weapons[fusionKey(c.a, c.b)] = 1
	elseif c.type == "heal" then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = math.min(hum.MaxHealth, hum.Health + 50)
		end
	else
		s.bonusGold += 25
	end
	s.choices = nil
	s.pending -= 1
	Progression.applyStats(player)
	if s.pending > 0 then
		Progression.offer(player)
	else
		remotes.LevelUp:FireClient(player, nil)
	end
	Progression.sync(player)
end

function Progression.reroll(player)
	local s = states[player]
	if s and s.choices and s.rerolls > 0 then
		s.rerolls -= 1
		Progression.offer(player)
	end
end

return Progression
