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
-- kind: cone | chain | projectile | clones | orbit | line | aura
Config.Weapons = {
	GumGumPistol = {
		name = "Gum-Gum Pistol", desc = "Stretchy punches that pierce through enemies.",
		kind = "line", damage = 16, cooldown = 1.4, range = 35, width = 3, count = 1,
		color = Color3.fromRGB(230, 60, 60), evolveWith = "Vitality", evolvesInto = "GumGumGatling",
	},
	ThreeSwordStyle = {
		name = "Three Sword Style", desc = "Slashes the nearest enemies with three swords.",
		kind = "cone", damage = 20, cooldown = 1.3, range = 14, angle = 110,
		color = Color3.fromRGB(80, 220, 120), evolveWith = "Power", evolvesInto = "NineSwordStyle",
	},
	ThunderTempo = {
		name = "Thunderbolt Tempo", desc = "Clima-Tact lightning jumps between enemies.",
		kind = "chain", damage = 14, cooldown = 1.6, range = 30, count = 3,
		color = Color3.fromRGB(255, 240, 90), evolveWith = "Magnet", evolvesInto = "ZeusTempo",
	},
	DiableJambe = {
		name = "Diable Jambe", desc = "Burning kicks hit everything around you.",
		kind = "aura", damage = 12, cooldown = 0.8, range = 8,
		color = Color3.fromRGB(255, 90, 40), evolveWith = "Swiftness", evolvesInto = "IfritJambe",
	},
	FireFist = {
		name = "Fire Fist", desc = "Launches a fireball that explodes.",
		kind = "projectile", damage = 30, cooldown = 2.2, range = 60, radius = 7,
		color = Color3.fromRGB(255, 140, 30), evolveWith = "Area", evolvesInto = "FlameEmperor",
	},
	CienFleur = {
		name = "Cien Fleur", desc = "Arms sprout from the ground and crush enemies.",
		kind = "clones", damage = 22, cooldown = 3, range = 7, count = 2,
		color = Color3.fromRGB(200, 120, 255), evolveWith = "Haste", evolvesInto = "GigantescoMano",
	},
	KungFuPoint = {
		name = "Kung Fu Point", desc = "Fists circle you and hit enemies.",
		kind = "orbit", damage = 10, cooldown = 0.5, range = 7, count = 2,
		color = Color3.fromRGB(255, 150, 190), evolveWith = "Vitality", evolvesInto = "MonsterPoint",
	},

	-- Evolutions (cannot be picked directly, always level 1)
	GumGumGatling = {
		name = "Gum-Gum Gatling", desc = "A storm of rubber punches in every direction.",
		kind = "line", damage = 50, cooldown = 0.8, range = 45, width = 4, count = 10,
		color = Color3.fromRGB(255, 40, 40), evolved = true, from = "GumGumPistol",
	},
	NineSwordStyle = {
		name = "Asura: Nine Sword Style", desc = "Nine blades slash in every direction.",
		kind = "cone", damage = 90, cooldown = 1, range = 22, angle = 120, count = 4,
		color = Color3.fromRGB(40, 200, 90), evolved = true, from = "ThreeSwordStyle",
	},
	ZeusTempo = {
		name = "Zeus Thunderstorm", desc = "Lightning chains through the whole swarm.",
		kind = "chain", damage = 70, cooldown = 0.9, range = 45, count = 10,
		color = Color3.fromRGB(255, 255, 160), evolved = true, from = "ThunderTempo",
	},
	IfritJambe = {
		name = "Ifrit Jambe", desc = "Blue-hot kicks scorch a huge area around you.",
		kind = "aura", damage = 45, cooldown = 0.5, range = 14,
		color = Color3.fromRGB(80, 160, 255), evolved = true, from = "DiableJambe",
	},
	FlameEmperor = {
		name = "Flame Emperor", desc = "Giant fireballs that wipe out crowds.",
		kind = "projectile", damage = 160, cooldown = 1.8, range = 70, radius = 16, count = 3,
		color = Color3.fromRGB(255, 80, 0), evolved = true, from = "FireFist",
	},
	GigantescoMano = {
		name = "Gigantesco Mano", desc = "Giant arms smash the battlefield.",
		kind = "clones", damage = 80, cooldown = 2.2, range = 9, count = 8,
		color = Color3.fromRGB(170, 80, 255), evolved = true, from = "CienFleur",
	},
	MonsterPoint = {
		name = "Monster Point", desc = "A huge ring of fists shreds anything close.",
		kind = "orbit", damage = 35, cooldown = 0.35, range = 10, count = 8,
		color = Color3.fromRGB(255, 100, 160), evolved = true, from = "KungFuPoint",
	},
}

-- `per` is added once per passive level to the named stat.
Config.Passives = {
	Power = { name = "Haki", desc = "+10% damage", stat = "damage", per = 0.10 },
	Haste = { name = "Haste", desc = "-8% cooldowns", stat = "cooldown", per = 0.08 },
	Area = { name = "Expansion", desc = "+10% area", stat = "area", per = 0.10 },
	Swiftness = { name = "Swift Feet", desc = "+8% move speed", stat = "speed", per = 0.08 },
	Vitality = { name = "Vitality", desc = "+20 max HP", stat = "health", per = 20 },
	Magnet = { name = "Treasure Magnet", desc = "+25% pickup range", stat = "magnet", per = 0.25 },
}

Config.DEFAULT_CLASS = "Luffy"
Config.Classes = {
	Luffy = { desc = "Gum-Gum Pistol. +30 max HP.", weapon = "GumGumPistol", bonus = { health = 30 } },
	Zoro = { desc = "Three Sword Style. +10% damage.", weapon = "ThreeSwordStyle", bonus = { damage = 0.10 } },
	Nami = { desc = "Thunderbolt Tempo. +25% gold.", weapon = "ThunderTempo", bonus = { gold = 0.25 } },
	Sanji = { desc = "Diable Jambe. +15% speed.", weapon = "DiableJambe", bonus = { speed = 0.15 } },
	Ace = { desc = "Fire Fist. +15% area.", weapon = "FireFist", bonus = { area = 0.15 } },
	Robin = { desc = "Cien Fleur. -10% cooldowns.", weapon = "CienFleur", bonus = { cooldown = 0.10 } },
	Chopper = { desc = "Kung Fu Point. Heals nearby allies.", weapon = "KungFuPoint", bonus = { heal = 2 } },
}
Config.CLASS_ORDER = { "Luffy", "Zoro", "Nami", "Sanji", "Ace", "Robin", "Chopper" }

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
