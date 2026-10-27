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

-- Sum of class bonus, passives and permanent upgrades for one stat.
function Progression.bonus(s, stat)
	local total = s.classBonus[stat] or 0
	for name, level in s.passives do
		local p = Config.Passives[name]
		if p.stat == stat then
			total += p.per * level
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

function Progression.xpNeeded(level)
	return 5 + level * 3
end

function Progression.get(player)
	return states[player]
end

function Progression.all()
	return states
end

function Progression.start(player, className, meta)
	local class = Config.Classes[className] or Config.Classes[Config.DEFAULT_CLASS]
	local s = {
		level = 1, xp = 0, kills = 0, bonusGold = 0, dead = false,
		weapons = { [class.weapon] = 1 }, passives = {}, timers = {},
		classBonus = class.bonus, meta = meta, choices = nil, pending = 0,
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
		local w = Config.Weapons[name]
		table.insert(weapons, { name = w.name, level = level, evo = w.evolved == true, color = w.color })
	end
	for name, level in s.passives do
		table.insert(passives, { name = Config.Passives[name].name, level = level })
	end
	remotes.Stats:FireClient(player, {
		level = s.level, xp = s.xp, need = Progression.xpNeeded(s.level),
		kills = s.kills, weapons = weapons, passives = passives,
	})
end

local function hasEvolutionOf(s, baseName)
	for name in s.weapons do
		if Config.Weapons[name].from == baseName then
			return true
		end
	end
	return false
end

local function buildChoices(s)
	local picks, pool = {}, {}
	for name, level in s.weapons do
		local w = Config.Weapons[name]
		if w.evolvesInto and level >= Config.WEAPON_MAX and (s.passives[w.evolveWith] or 0) >= Config.PASSIVE_MAX then
			table.insert(picks, { type = "evolve", key = name })
		elseif not w.evolved and level < Config.WEAPON_MAX then
			table.insert(pool, { type = "weapon", key = name })
		end
	end
	if count(s.weapons) < Config.WEAPON_SLOTS then
		for name, w in Config.Weapons do
			if not w.evolved and not s.weapons[name] and not hasEvolutionOf(s, name) then
				table.insert(pool, { type = "weapon", key = name })
			end
		end
	end
	for name, level in s.passives do
		if level < Config.PASSIVE_MAX then
			table.insert(pool, { type = "passive", key = name })
		end
	end
	if count(s.passives) < Config.PASSIVE_SLOTS then
		for name in Config.Passives do
			if not s.passives[name] then
				table.insert(pool, { type = "passive", key = name })
			end
		end
	end

	while #picks > Config.CHOICES do
		table.remove(picks)
	end
	while #picks < Config.CHOICES and #pool > 0 do
		table.insert(picks, table.remove(pool, math.random(#pool)))
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
		return {
			title = w.name, color = w.color, level = level, max = Config.WEAPON_MAX,
			tag = level == 1 and "NEW SKILL" or "UPGRADE",
			text = level == 1 and w.desc or "More damage, faster attacks, more hits.",
		}
	elseif c.type == "passive" then
		local p = Config.Passives[c.key]
		local level = (s.passives[c.key] or 0) + 1
		return {
			title = p.name, text = p.desc, color = Color3.fromRGB(200, 210, 230),
			tag = level == 1 and "NEW PASSIVE" or "PASSIVE", level = level, max = Config.PASSIVE_MAX,
		}
	elseif c.type == "evolve" then
		local evo = Config.Weapons[Config.Weapons[c.key].evolvesInto]
		return { title = evo.name, text = evo.desc, color = evo.color, tag = "EVOLUTION" }
	elseif c.type == "heal" then
		return { title = "Meat on the Bone", text = "Heal 50 HP.", color = Color3.fromRGB(255, 170, 120), tag = "BONUS" }
	end
	return { title = "Gold Pouch", text = "+25 gold at the end of the run.", color = Color3.fromRGB(255, 215, 0), tag = "BONUS" }
end

function Progression.offer(player)
	local s = states[player]
	s.choices = buildChoices(s)
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
	s.xp += amount
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
