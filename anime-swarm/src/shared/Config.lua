-- All game balance lives here.
local Config = {}

Config.MINIBOSS_EVERY = 120
Config.RESULTS_TIME = 8
Config.MAX_ENEMIES = 150
Config.SPAWN_MIN, Config.SPAWN_MAX = 55, 85 -- spawn distance from players

-- Spawn island and adventure portals. Keep these in sync with tools/build_place.py.
Config.ISLAND_CENTER = Vector3.new(0, 0, 1400)
Config.PORTAL_RADIUS = 7 -- stand this close to a portal's pad to board
Config.PORTAL_COUNTDOWN = 10
Config.ARENA_DROP_RADIUS = 25
Config.ARENA_HALF_SIZE = 500 -- every arena floor is 1000 x 1000

-- Each portal leads to an adventure with its own arena. hp / damage / gold multiply the base values.
Config.Adventures = {
	EastBlue = {
		name = "East Blue", difficulty = "Easy", stars = 1, color = Color3.fromRGB(70, 190, 255),
		desc = "Calm seas. Great for new pirates.",
		center = Vector3.new(0, 0, 0), portal = Vector3.new(-34, 0, 1488),
		runLength = 300, hp = 0.7, damage = 0.7, gold = 1,
	},
	GrandLine = {
		name = "Grand Line", difficulty = "Normal", stars = 2, color = Color3.fromRGB(255, 190, 50),
		desc = "Desert kingdoms and tougher Marines.",
		center = Vector3.new(-1600, 0, 0), portal = Vector3.new(0, 0, 1500),
		runLength = 480, hp = 1.2, damage = 1.1, gold = 1.75,
	},
	NewWorld = {
		name = "New World", difficulty = "Hard", stars = 3, color = Color3.fromRGB(255, 70, 70),
		desc = "Only the strongest survive. Huge rewards.",
		center = Vector3.new(1600, 0, 0), portal = Vector3.new(34, 0, 1488),
		runLength = 600, hp = 2, damage = 1.6, gold = 3,
	},
}
Config.ADVENTURE_ORDER = { "EastBlue", "GrandLine", "NewWorld" }

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
-- kind: how it hits (cone | chain | projectile | clones | orbit | line | aura)
-- fx / anim: the visual effect and character animation players see
Config.Weapons = {
	GumGumPistol = {
		name = "Gum-Gum Pistol", desc = "Stretchy punches that pierce through enemies.",
		fx = "punch", anim = "punch",
		kind = "line", damage = 16, cooldown = 1.4, range = 35, width = 3, count = 1,
		color = Color3.fromRGB(230, 60, 60), evolveWith = "Vitality", evolvesInto = "GumGumGatling",
	},
	ThreeSwordStyle = {
		name = "Three Sword Style", desc = "Slashes the nearest enemies with three swords.",
		fx = "slash", anim = "slash", arcs = 3,
		kind = "cone", damage = 20, cooldown = 1.3, range = 14, angle = 110,
		color = Color3.fromRGB(80, 220, 120), evolveWith = "Power", evolvesInto = "NineSwordStyle",
	},
	ThunderTempo = {
		name = "Thunderbolt Tempo", desc = "Clima-Tact lightning jumps between enemies.",
		fx = "lightning", anim = "cast",
		kind = "chain", damage = 14, cooldown = 1.6, range = 30, count = 3,
		color = Color3.fromRGB(255, 240, 90), evolveWith = "Magnet", evolvesInto = "ZeusTempo",
	},
	DiableJambe = {
		name = "Diable Jambe", desc = "Burning kicks hit everything around you.",
		fx = "kick", anim = "kick",
		kind = "aura", damage = 12, cooldown = 0.8, range = 8,
		color = Color3.fromRGB(255, 90, 40), evolveWith = "Swiftness", evolvesInto = "IfritJambe",
	},
	FireFist = {
		name = "Fire Fist", desc = "Launches a fireball that explodes.",
		fx = "fireball", anim = "throw",
		kind = "projectile", damage = 30, cooldown = 2.2, range = 60, radius = 7,
		color = Color3.fromRGB(255, 140, 30), evolveWith = "Area", evolvesInto = "FlameEmperor",
	},
	CienFleur = {
		name = "Cien Fleur", desc = "Arms sprout from the ground and crush enemies.",
		fx = "hands", anim = "cross",
		kind = "clones", damage = 22, cooldown = 3, range = 7, count = 2,
		color = Color3.fromRGB(200, 120, 255), evolveWith = "Haste", evolvesInto = "GigantescoMano",
	},
	KungFuPoint = {
		name = "Kung Fu Point", desc = "Fists circle you and hit enemies.",
		fx = "fists",
		kind = "orbit", damage = 10, cooldown = 0.5, range = 7, count = 2,
		color = Color3.fromRGB(255, 150, 190), evolveWith = "Vitality", evolvesInto = "MonsterPoint",
	},

	-- Evolutions (cannot be picked directly, always level 1)
	GumGumGatling = {
		name = "Gum-Gum Gatling", desc = "A storm of rubber punches in every direction.",
		fx = "punch", anim = "punch",
		kind = "line", damage = 50, cooldown = 0.8, range = 45, width = 4, count = 10,
		color = Color3.fromRGB(255, 40, 40), evolved = true, from = "GumGumPistol",
	},
	NineSwordStyle = {
		name = "Asura: Nine Sword Style", desc = "Nine blades slash in every direction.",
		fx = "slash", anim = "slash", arcs = 3,
		kind = "cone", damage = 90, cooldown = 1, range = 22, angle = 120, count = 4,
		color = Color3.fromRGB(40, 200, 90), evolved = true, from = "ThreeSwordStyle",
	},
	ZeusTempo = {
		name = "Zeus Thunderstorm", desc = "Lightning chains through the whole swarm.",
		fx = "lightning", anim = "cast",
		kind = "chain", damage = 70, cooldown = 0.9, range = 45, count = 10,
		color = Color3.fromRGB(255, 255, 160), evolved = true, from = "ThunderTempo",
	},
	IfritJambe = {
		name = "Ifrit Jambe", desc = "Blue-hot kicks scorch a huge area around you.",
		fx = "kick", anim = "kick",
		kind = "aura", damage = 45, cooldown = 0.5, range = 14,
		color = Color3.fromRGB(80, 160, 255), evolved = true, from = "DiableJambe",
	},
	FlameEmperor = {
		name = "Flame Emperor", desc = "Giant fireballs that wipe out crowds.",
		fx = "fireball", anim = "throw",
		kind = "projectile", damage = 160, cooldown = 1.8, range = 70, radius = 16, count = 3,
		color = Color3.fromRGB(255, 80, 0), evolved = true, from = "FireFist",
	},
	GigantescoMano = {
		name = "Gigantesco Mano", desc = "Giant arms smash the battlefield.",
		fx = "hands", anim = "cross",
		kind = "clones", damage = 80, cooldown = 2.2, range = 9, count = 8,
		color = Color3.fromRGB(170, 80, 255), evolved = true, from = "CienFleur",
	},
	MonsterPoint = {
		name = "Monster Point", desc = "A huge ring of fists shreds anything close.",
		fx = "fists",
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
	Luffy = {
		title = "Straw Hat", perk = "+30 max HP", color = Color3.fromRGB(220, 50, 50),
		weapon = "GumGumPistol", bonus = { health = 30 },
	},
	Zoro = {
		title = "Pirate Hunter", perk = "+10% damage", color = Color3.fromRGB(60, 190, 90),
		weapon = "ThreeSwordStyle", bonus = { damage = 0.10 },
	},
	Nami = {
		title = "Cat Burglar", perk = "+25% gold", color = Color3.fromRGB(255, 150, 40),
		weapon = "ThunderTempo", bonus = { gold = 0.25 },
	},
	Sanji = {
		title = "Black Leg", perk = "+15% move speed", color = Color3.fromRGB(240, 200, 60),
		weapon = "DiableJambe", bonus = { speed = 0.15 },
	},
	Ace = {
		title = "Fire Fist", perk = "+15% area", color = Color3.fromRGB(255, 100, 30),
		weapon = "FireFist", bonus = { area = 0.15 },
	},
	Robin = {
		title = "Devil Child", perk = "-10% cooldowns", color = Color3.fromRGB(150, 90, 220),
		weapon = "CienFleur", bonus = { cooldown = 0.10 },
	},
	Chopper = {
		title = "Cotton Candy Lover", perk = "Heals nearby allies", color = Color3.fromRGB(255, 130, 180),
		weapon = "KungFuPoint", bonus = { heal = 2 },
	},
}
Config.CLASS_ORDER = { "Luffy", "Zoro", "Nami", "Sanji", "Ace", "Robin", "Chopper" }

-- color = clothes, accent = cap and pants, skin = head and hands, eyes = glowing eye color
local SKIN = Color3.fromRGB(255, 205, 160)
Config.Enemies = {
	Grunt = {
		name = "Marine", hp = 20, speed = 11, damage = 6, xp = 1, scale = 1,
		color = Color3.fromRGB(240, 240, 245), accent = Color3.fromRGB(40, 80, 160), skin = SKIN,
	},
	Runner = {
		name = "Fishman", hp = 12, speed = 15, damage = 4, xp = 1, scale = 0.85,
		color = Color3.fromRGB(230, 120, 50), accent = Color3.fromRGB(30, 50, 90), skin = Color3.fromRGB(70, 150, 210),
	},
	Brute = {
		name = "Pacifista", hp = 110, speed = 8, damage = 14, xp = 6, scale = 1.7,
		color = Color3.fromRGB(55, 55, 65), accent = Color3.fromRGB(30, 30, 35), skin = Color3.fromRGB(200, 170, 140),
		eyes = Color3.fromRGB(255, 220, 60),
	},
	MiniBoss = {
		name = "Vice Admiral", hp = 1200, speed = 10, damage = 22, xp = 40, gold = 25, scale = 3, healthBar = true,
		color = Color3.fromRGB(250, 250, 250), accent = Color3.fromRGB(35, 35, 60), skin = SKIN,
	},
	Boss = {
		name = "Admiral", hp = 15000, speed = 12, damage = 40, xp = 0, gold = 300, scale = 5, healthBar = true,
		color = Color3.fromRGB(250, 250, 250), accent = Color3.fromRGB(150, 20, 30), skin = SKIN,
		eyes = Color3.fromRGB(255, 80, 40),
	},
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
