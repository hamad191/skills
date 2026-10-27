-- All game balance lives here.
local Config = {}

Config.RUN_LENGTH = 600 -- seconds until the final boss appears
Config.MINIBOSS_EVERY = 120
Config.INTERMISSION = 20
Config.RESULTS_TIME = 8
Config.MAX_ENEMIES = 150
Config.SPAWN_MIN, Config.SPAWN_MAX = 55, 85 -- spawn distance from players

Config.WEAPON_SLOTS = 4
Config.PASSIVE_SLOTS = 4
Config.WEAPON_MAX = 5
Config.PASSIVE_MAX = 5
Config.CHOICES = 3

Config.BASE_HEALTH = 100
Config.BASE_SPEED = 16
Config.BASE_MAGNET = 10

-- Weapons fire on their own. A weapon evolves when it is max level and its
-- `evolveWith` passive is also max level.
-- kind: cone | chain | projectile | clones | orbit | line
Config.Weapons = {
	FlameSlash = {
		name = "Flame Slash", desc = "Slashes fire at the nearest enemy.",
		kind = "cone", damage = 18, cooldown = 1.3, range = 14, angle = 110,
		color = Color3.fromRGB(255, 120, 30), evolveWith = "Power", evolvesInto = "InfernoDragon",
	},
	LightningChain = {
		name = "Lightning Chain", desc = "Lightning jumps between enemies.",
		kind = "chain", damage = 14, cooldown = 1.6, range = 30, count = 3,
		color = Color3.fromRGB(255, 240, 90), evolveWith = "Haste", evolvesInto = "ThunderGod",
	},
	SpiralOrb = {
		name = "Spiral Orb", desc = "Throws a spinning orb that explodes.",
		kind = "projectile", damage = 30, cooldown = 2.2, range = 60, radius = 7,
		color = Color3.fromRGB(80, 160, 255), evolveWith = "Area", evolvesInto = "SpiralBomb",
	},
	ShadowClones = {
		name = "Shadow Clones", desc = "Clones appear and strike around you.",
		kind = "clones", damage = 22, cooldown = 3, range = 7, count = 2,
		color = Color3.fromRGB(140, 140, 170), evolveWith = "Swiftness", evolvesInto = "ShadowArmy",
	},
	SpiritOrbs = {
		name = "Spirit Orbs", desc = "Spirits circle you and hit enemies.",
		kind = "orbit", damage = 10, cooldown = 0.5, range = 7, count = 2,
		color = Color3.fromRGB(150, 255, 180), evolveWith = "Vitality", evolvesInto = "GuardianRing",
	},
	WindBlades = {
		name = "Wind Blades", desc = "Fires piercing blades of wind.",
		kind = "line", damage = 16, cooldown = 1.8, range = 40, width = 3, count = 2,
		color = Color3.fromRGB(200, 255, 255), evolveWith = "Magnet", evolvesInto = "Hurricane",
	},

	-- Evolutions (cannot be picked directly, always level 1)
	InfernoDragon = {
		name = "Inferno Dragon Slash", desc = "Fire dragons slash in every direction.",
		kind = "cone", damage = 90, cooldown = 1, range = 22, angle = 120, count = 4,
		color = Color3.fromRGB(255, 70, 20), evolved = true, from = "FlameSlash",
	},
	ThunderGod = {
		name = "Thunder God's Wrath", desc = "Lightning chains through the whole swarm.",
		kind = "chain", damage = 70, cooldown = 0.9, range = 45, count = 10,
		color = Color3.fromRGB(255, 255, 160), evolved = true, from = "LightningChain",
	},
	SpiralBomb = {
		name = "Giant Spiral Bomb", desc = "Huge orbs that wipe out crowds.",
		kind = "projectile", damage = 160, cooldown = 1.8, range = 70, radius = 16, count = 3,
		color = Color3.fromRGB(40, 110, 255), evolved = true, from = "SpiralOrb",
	},
	ShadowArmy = {
		name = "Thousand Shadow Army", desc = "An army of clones attacks.",
		kind = "clones", damage = 80, cooldown = 2.2, range = 9, count = 8,
		color = Color3.fromRGB(90, 90, 130), evolved = true, from = "ShadowClones",
	},
	GuardianRing = {
		name = "Guardian Spirit Ring", desc = "A ring of spirits shreds anything close.",
		kind = "orbit", damage = 35, cooldown = 0.35, range = 10, count = 8,
		color = Color3.fromRGB(90, 255, 140), evolved = true, from = "SpiritOrbs",
	},
	Hurricane = {
		name = "Hurricane Barrage", desc = "Wind blades fly everywhere.",
		kind = "line", damage = 60, cooldown = 1, range = 60, width = 5, count = 10,
		color = Color3.fromRGB(170, 255, 255), evolved = true, from = "WindBlades",
	},
}

-- `per` is added once per passive level to the named stat.
Config.Passives = {
	Power = { name = "Chakra Power", desc = "+10% damage", stat = "damage", per = 0.10 },
	Haste = { name = "Haste", desc = "-8% cooldowns", stat = "cooldown", per = 0.08 },
	Area = { name = "Expansion", desc = "+10% area", stat = "area", per = 0.10 },
	Swiftness = { name = "Swift Feet", desc = "+8% move speed", stat = "speed", per = 0.08 },
	Vitality = { name = "Vitality", desc = "+20 max HP", stat = "health", per = 20 },
	Magnet = { name = "Spirit Magnet", desc = "+25% pickup range", stat = "magnet", per = 0.25 },
}

Config.Classes = {
	Swordsman = { desc = "Flame Slash. +30 max HP.", weapon = "FlameSlash", bonus = { health = 30 } },
	Ninja = { desc = "Shadow Clones. +15% speed.", weapon = "ShadowClones", bonus = { speed = 0.15 } },
	Mage = { desc = "Spiral Orb. +15% area.", weapon = "SpiralOrb", bonus = { area = 0.15 } },
	Healer = { desc = "Spirit Orbs. Heals nearby allies.", weapon = "SpiritOrbs", bonus = { heal = 2 } },
}
Config.CLASS_ORDER = { "Swordsman", "Ninja", "Mage", "Healer" }

Config.Enemies = {
	Grunt = { hp = 20, speed = 11, damage = 6, xp = 1, scale = 1, color = Color3.fromRGB(110, 30, 50) },
	Runner = { hp = 12, speed = 15, damage = 4, xp = 1, scale = 0.8, color = Color3.fromRGB(220, 170, 40) },
	Brute = { hp = 110, speed = 8, damage = 14, xp = 6, scale = 1.7, color = Color3.fromRGB(60, 60, 90) },
	MiniBoss = { hp = 1200, speed = 10, damage = 22, xp = 40, gold = 25, scale = 3, color = Color3.fromRGB(170, 40, 200), healthBar = true },
	Boss = { hp = 15000, speed = 12, damage = 40, xp = 0, gold = 300, scale = 5, color = Color3.fromRGB(160, 0, 0), healthBar = true },
}

-- Permanent upgrades bought with gold between runs. Cost = cost * META_GROWTH ^ level.
Config.Meta = {
	Might = { name = "Might", desc = "+5% damage", stat = "damage", per = 0.05, max = 10, cost = 100 },
	Toughness = { name = "Toughness", desc = "+10 max HP", stat = "health", per = 10, max = 10, cost = 100 },
	Greed = { name = "Greed", desc = "+10% gold", stat = "gold", per = 0.10, max = 10, cost = 150 },
	Reach = { name = "Reach", desc = "+10% pickup range", stat = "magnet", per = 0.10, max = 5, cost = 120 },
	Reroll = { name = "Reroll", desc = "+1 reroll per run", stat = "reroll", per = 1, max = 5, cost = 300 },
}
Config.META_ORDER = { "Might", "Toughness", "Greed", "Reach", "Reroll" }
Config.META_GROWTH = 1.5

return Config
