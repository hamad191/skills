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

Config.WEAPON_SLOTS_START = 3 -- buy more with the "Skill Slot" upgrade
Config.WEAPON_SLOTS_MAX = 8
Config.PASSIVE_SLOTS = 4
Config.WEAPON_MAX = 5
Config.PASSIVE_MAX = 5
Config.CHOICES = 3

Config.BASE_HEALTH = 100
Config.BASE_SPEED = 16
Config.BASE_MAGNET = 10

-- Skills fire on their own. Each character owns 6 skills (see Config.Classes); level-ups mostly
-- offer your own character's skills, and now and then a crewmate's ("crew skill").
-- A signature skill evolves when it is max level and its `evolveWith` passive is also max level.
-- kind: how it hits (cone | chain | projectile | clones | orbit | line | aura)
-- fx: the effect players see (punch | slash | lightning | grab | shot | kick | nova | hands | strike | wave | orbit)
-- anim: the character's attack animation (punch | slash | kick | throw | cast | cross)
-- Optional look tweaks: arcs (slash lines), arm (punch arm color), cloud (lightning from a cloud), fire (flames)
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Config.Weapons = {
	-- Luffy -------------------------------------------------------------------------
	GumGumPistol = {
		name = "Gum-Gum Pistol", desc = "Stretchy punches that pierce through enemies.",
		fx = "punch", anim = "punch",
		kind = "line", damage = 16, cooldown = 1.4, range = 35, width = 3, count = 1,
		color = rgb(230, 60, 60), evolveWith = "Vitality", evolvesInto = "GumGumGatling",
	},
	GumGumBazooka = {
		name = "Gum-Gum Bazooka", desc = "A two-palm blast that smashes a straight line.",
		fx = "punch", anim = "punch",
		kind = "line", damage = 42, cooldown = 3.2, range = 22, width = 5, count = 1, color = rgb(230, 60, 60),
	},
	GumGumWhip = {
		name = "Gum-Gum Whip", desc = "A stretching leg sweeps everything in front.",
		fx = "slash", anim = "kick", arcs = 1,
		kind = "cone", damage = 24, cooldown = 1.8, range = 18, angle = 160, color = rgb(255, 120, 90),
	},
	GumGumBalloon = {
		name = "Gum-Gum Balloon", desc = "Puff up and bounce enemies away.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 16, cooldown = 2.4, range = 10, color = rgb(255, 170, 120),
	},
	GumGumElephantGun = {
		name = "Gum-Gum Elephant Gun", desc = "A giant fist crashes down on a crowd.",
		fx = "strike", anim = "punch",
		kind = "clones", damage = 65, cooldown = 5, range = 9, count = 1, color = rgb(220, 40, 40),
	},
	RedHawk = {
		name = "Red Hawk", desc = "A blazing punch that explodes on impact.",
		fx = "shot", anim = "punch", fire = true,
		kind = "projectile", damage = 45, cooldown = 3, range = 45, radius = 6, color = rgb(255, 90, 40),
	},

	-- Zoro --------------------------------------------------------------------------
	ThreeSwordStyle = {
		name = "Three Sword Style", desc = "Slashes the nearest enemies with three swords.",
		fx = "slash", anim = "slash", arcs = 3,
		kind = "cone", damage = 20, cooldown = 1.3, range = 14, angle = 110,
		color = rgb(80, 220, 120), evolveWith = "Power", evolvesInto = "NineSwordStyle",
	},
	PoundCannon = {
		name = "360 Pound Cannon", desc = "A flying slash wave cuts down a line.",
		fx = "wave", anim = "slash",
		kind = "line", damage = 28, cooldown = 2.2, range = 45, width = 3, count = 1, color = rgb(120, 255, 160),
	},
	OniGiri = {
		name = "Oni Giri", desc = "Demon Slash: three blades thrust forward.",
		fx = "slash", anim = "slash", arcs = 3,
		kind = "cone", damage = 34, cooldown = 2.6, range = 22, angle = 45, color = rgb(60, 200, 90),
	},
	Tatsumaki = {
		name = "Tatsumaki", desc = "Dragon Twister: a cyclone of blades around you.",
		fx = "nova", anim = "slash",
		kind = "aura", damage = 18, cooldown = 2.2, range = 12, color = rgb(160, 255, 190),
	},
	ShishiSonson = {
		name = "Shishi Sonson", desc = "Lion's Song: a lightning-fast cut that leaps between foes.",
		fx = "lightning", anim = "slash",
		kind = "chain", damage = 24, cooldown = 2, range = 28, count = 4, color = rgb(200, 255, 210),
	},
	BlackRopeDragon = {
		name = "Black Rope Dragon", desc = "Black tornadoes of blades crash down.",
		fx = "strike", anim = "slash",
		kind = "clones", damage = 38, cooldown = 4.2, range = 8, count = 2, color = rgb(30, 110, 60),
	},

	-- Nami --------------------------------------------------------------------------
	ThunderTempo = {
		name = "Thunderbolt Tempo", desc = "Clima-Tact lightning jumps between enemies.",
		fx = "lightning", anim = "cast", cloud = true,
		kind = "chain", damage = 14, cooldown = 1.6, range = 30, count = 3,
		color = rgb(255, 240, 90), evolveWith = "Magnet", evolvesInto = "ZeusTempo",
	},
	CycloneTempo = {
		name = "Cyclone Tempo", desc = "Gusts of wind blast through the swarm.",
		fx = "wave", anim = "cast",
		kind = "line", damage = 18, cooldown = 2, range = 35, width = 3, count = 2, color = rgb(200, 240, 255),
	},
	MirageTempo = {
		name = "Mirage Tempo", desc = "Mirage copies of Nami burst with light.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 14, cooldown = 1.6, range = 9, color = rgb(255, 190, 90),
	},
	ThunderLance = {
		name = "Thunder Lance Tempo", desc = "Bolts of lightning strike from above.",
		fx = "strike", anim = "cast",
		kind = "clones", damage = 40, cooldown = 3.6, range = 6, count = 2, color = rgb(255, 240, 90),
	},
	WeatherEgg = {
		name = "Weather Egg", desc = "A weather bubble that bursts into a storm.",
		fx = "shot", anim = "throw",
		kind = "projectile", damage = 30, cooldown = 2.6, range = 50, radius = 8, color = rgb(120, 200, 255),
	},
	BlackBall = {
		name = "Black Ball", desc = "Thunderclouds circle you, shocking anyone close.",
		fx = "orbit",
		kind = "orbit", damage = 9, cooldown = 0.5, range = 9, count = 2, color = rgb(90, 90, 140),
	},

	-- Sanji -------------------------------------------------------------------------
	DiableJambe = {
		name = "Diable Jambe", desc = "Burning kicks hit everything around you.",
		fx = "kick", anim = "kick", fire = true,
		kind = "aura", damage = 12, cooldown = 0.8, range = 8,
		color = rgb(255, 90, 40), evolveWith = "Swiftness", evolvesInto = "IfritJambe",
	},
	Concasse = {
		name = "Concasse", desc = "A crushing heel drop from the sky.",
		fx = "strike", anim = "kick",
		kind = "clones", damage = 46, cooldown = 3.6, range = 8, count = 1, color = rgb(255, 200, 80),
	},
	PartyTable = {
		name = "Party Table Kick", desc = "A whirlwind of kicks while standing on your hands.",
		fx = "kick", anim = "kick",
		kind = "aura", damage = 10, cooldown = 1.2, range = 7, color = rgb(255, 250, 225),
	},
	MoutonShot = {
		name = "Mouton Shot", desc = "A kick so fast it fires a shockwave.",
		fx = "wave", anim = "kick",
		kind = "line", damage = 30, cooldown = 2.5, range = 28, width = 4, count = 1, color = rgb(255, 230, 150),
	},
	PoeleAFrire = {
		name = "Poele a Frire", desc = "Burning kicks rake a wide arc.",
		fx = "slash", anim = "kick", arcs = 2,
		kind = "cone", damage = 22, cooldown = 1.6, range = 13, angle = 140, color = rgb(255, 120, 40),
	},
	FlambageShot = {
		name = "Flambage Shot", desc = "A flaming kick that launches a fireball.",
		fx = "shot", anim = "kick", fire = true,
		kind = "projectile", damage = 34, cooldown = 2.6, range = 50, radius = 7, color = rgb(255, 110, 30),
	},

	-- Ace ---------------------------------------------------------------------------
	FireFist = {
		name = "Fire Fist", desc = "Launches a fireball that explodes.",
		fx = "shot", anim = "throw", fire = true,
		kind = "projectile", damage = 30, cooldown = 2.2, range = 60, radius = 7,
		color = rgb(255, 140, 30), evolveWith = "Area", evolvesInto = "FlameEmperor",
	},
	FireGun = {
		name = "Fire Gun", desc = "Bullets of flame fly from his fingertips.",
		fx = "wave", anim = "throw",
		kind = "line", damage = 14, cooldown = 1.5, range = 40, width = 2, count = 3, color = rgb(255, 150, 50),
	},
	Firefly = {
		name = "Firefly", desc = "Glowing fireflies circle you and burn enemies.",
		fx = "orbit",
		kind = "orbit", damage = 8, cooldown = 0.45, range = 8, count = 3, color = rgb(220, 255, 120),
	},
	FirePillar = {
		name = "Fire Pillar", desc = "Pillars of fire erupt under enemies.",
		fx = "strike", anim = "cast",
		kind = "clones", damage = 32, cooldown = 3, range = 7, count = 2, color = rgb(255, 90, 20),
	},
	FireFence = {
		name = "Fire Fence", desc = "A ring of flame bursts around you.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 16, cooldown = 2, range = 11, color = rgb(255, 140, 40),
	},
	CrossFire = {
		name = "Cross Fire", desc = "Blasts of flame forward and back.",
		fx = "slash", anim = "throw", arcs = 1,
		kind = "cone", damage = 26, cooldown = 2, range = 20, angle = 50, count = 2, color = rgb(255, 170, 60),
	},

	-- Robin -------------------------------------------------------------------------
	CienFleur = {
		name = "Cien Fleur", desc = "Arms sprout from the ground and crush enemies.",
		fx = "hands", anim = "cross",
		kind = "clones", damage = 22, cooldown = 3, range = 7, count = 2,
		color = rgb(200, 120, 255), evolveWith = "Haste", evolvesInto = "GigantescoMano",
	},
	SeisFleur = {
		name = "Seis Fleur", desc = "Arms grab enemy after enemy.",
		fx = "grab", anim = "cross",
		kind = "chain", damage = 22, cooldown = 2, range = 28, count = 4, color = rgb(200, 120, 255),
	},
	MilFleur = {
		name = "Mil Fleur", desc = "A field of arms sprouts all around you.",
		fx = "hands", anim = "cross",
		kind = "aura", damage = 18, cooldown = 2.4, range = 10, color = rgb(170, 90, 230),
	},
	FlowerStorm = {
		name = "Flower Storm", desc = "A storm of petals cuts through the swarm.",
		fx = "wave", anim = "cross",
		kind = "line", damage = 18, cooldown = 2, range = 35, width = 3, count = 2, color = rgb(255, 150, 210),
	},
	GiganteFleur = {
		name = "Gigante Fleur", desc = "A giant hand slams down on a crowd.",
		fx = "strike", anim = "cross",
		kind = "clones", damage = 50, cooldown = 4.4, range = 10, count = 1, color = rgb(160, 80, 220),
	},
	PetalGuard = {
		name = "Petal Guard", desc = "Petals swirl around you and slice anything close.",
		fx = "orbit",
		kind = "orbit", damage = 8, cooldown = 0.5, range = 7, count = 3, color = rgb(255, 160, 220),
	},

	-- Chopper -----------------------------------------------------------------------
	KungFuPoint = {
		name = "Kung Fu Point", desc = "Fists circle you and hit enemies.",
		fx = "orbit",
		kind = "orbit", damage = 10, cooldown = 0.5, range = 7, count = 2,
		color = rgb(255, 150, 190), evolveWith = "Vitality", evolvesInto = "MonsterPoint",
	},
	HeavyGong = {
		name = "Heavy Gong", desc = "Heavy Point: one huge furry punch.",
		fx = "punch", anim = "punch", arm = rgb(150, 100, 60),
		kind = "line", damage = 36, cooldown = 3, range = 16, width = 4, count = 1, color = rgb(255, 130, 180),
	},
	HornPoint = {
		name = "Horn Point", desc = "Charge with giant antlers.",
		fx = "slash", anim = "punch", arcs = 1,
		kind = "cone", damage = 20, cooldown = 1.5, range = 10, angle = 90, color = rgb(220, 170, 120),
	},
	RumbleBall = {
		name = "Rumble Ball", desc = "A burst of monster energy.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 12, cooldown = 2, range = 9, color = rgb(255, 150, 200),
	},
	CherryBlossom = {
		name = "Cherry Blossom Hoof", desc = "Hoof strikes that bloom from foe to foe.",
		fx = "lightning", anim = "punch",
		kind = "chain", damage = 18, cooldown = 1.8, range = 26, count = 4, color = rgb(255, 180, 220),
	},
	MedicineBomb = {
		name = "Medicine Bomb", desc = "Throws a medicine bomb that bursts.",
		fx = "shot", anim = "throw",
		kind = "projectile", damage = 28, cooldown = 2.4, range = 45, radius = 7, color = rgb(150, 255, 180),
	},

	-- Evolutions (cannot be picked directly, always level 1) --------------------------
	GumGumGatling = {
		name = "Gum-Gum Gatling", desc = "A storm of rubber punches in every direction.",
		fx = "punch", anim = "punch",
		kind = "line", damage = 50, cooldown = 0.8, range = 45, width = 4, count = 10,
		color = rgb(255, 40, 40), evolved = true, from = "GumGumPistol",
	},
	NineSwordStyle = {
		name = "Asura: Nine Sword Style", desc = "Nine blades slash in every direction.",
		fx = "slash", anim = "slash", arcs = 3,
		kind = "cone", damage = 90, cooldown = 1, range = 22, angle = 120, count = 4,
		color = rgb(40, 200, 90), evolved = true, from = "ThreeSwordStyle",
	},
	ZeusTempo = {
		name = "Zeus Thunderstorm", desc = "Lightning chains through the whole swarm.",
		fx = "lightning", anim = "cast", cloud = true,
		kind = "chain", damage = 70, cooldown = 0.9, range = 45, count = 10,
		color = rgb(255, 255, 160), evolved = true, from = "ThunderTempo",
	},
	IfritJambe = {
		name = "Ifrit Jambe", desc = "Blue-hot kicks scorch a huge area around you.",
		fx = "kick", anim = "kick", fire = true,
		kind = "aura", damage = 45, cooldown = 0.5, range = 14,
		color = rgb(80, 160, 255), evolved = true, from = "DiableJambe",
	},
	FlameEmperor = {
		name = "Flame Emperor", desc = "Giant fireballs that wipe out crowds.",
		fx = "shot", anim = "throw", fire = true,
		kind = "projectile", damage = 160, cooldown = 1.8, range = 70, radius = 16, count = 3,
		color = rgb(255, 80, 0), evolved = true, from = "FireFist",
	},
	GigantescoMano = {
		name = "Gigantesco Mano", desc = "Giant arms smash the battlefield.",
		fx = "hands", anim = "cross",
		kind = "clones", damage = 80, cooldown = 2.2, range = 9, count = 8,
		color = rgb(170, 80, 255), evolved = true, from = "CienFleur",
	},
	MonsterPoint = {
		name = "Monster Point", desc = "A huge ring of fists shreds anything close.",
		fx = "orbit",
		kind = "orbit", damage = 35, cooldown = 0.35, range = 10, count = 8,
		color = rgb(255, 100, 160), evolved = true, from = "KungFuPoint",
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
		weapon = "GumGumPistol",
		skills = { "GumGumPistol", "GumGumBazooka", "GumGumWhip", "GumGumBalloon", "GumGumElephantGun", "RedHawk" },
		bonus = { health = 30 },
	},
	Zoro = {
		title = "Pirate Hunter", perk = "+10% damage", color = Color3.fromRGB(60, 190, 90),
		weapon = "ThreeSwordStyle",
		skills = { "ThreeSwordStyle", "PoundCannon", "OniGiri", "Tatsumaki", "ShishiSonson", "BlackRopeDragon" },
		bonus = { damage = 0.10 },
	},
	Nami = {
		title = "Cat Burglar", perk = "+25% gold", color = Color3.fromRGB(255, 150, 40),
		weapon = "ThunderTempo",
		skills = { "ThunderTempo", "CycloneTempo", "MirageTempo", "ThunderLance", "WeatherEgg", "BlackBall" },
		bonus = { gold = 0.25 },
	},
	Sanji = {
		title = "Black Leg", perk = "+15% move speed", color = Color3.fromRGB(240, 200, 60),
		weapon = "DiableJambe",
		skills = { "DiableJambe", "Concasse", "PartyTable", "MoutonShot", "PoeleAFrire", "FlambageShot" },
		bonus = { speed = 0.15 },
	},
	Ace = {
		title = "Fire Fist", perk = "+15% area", color = Color3.fromRGB(255, 100, 30),
		weapon = "FireFist",
		skills = { "FireFist", "FireGun", "Firefly", "FirePillar", "FireFence", "CrossFire" },
		bonus = { area = 0.15 },
	},
	Robin = {
		title = "Devil Child", perk = "-10% cooldowns", color = Color3.fromRGB(150, 90, 220),
		weapon = "CienFleur",
		skills = { "CienFleur", "SeisFleur", "MilFleur", "FlowerStorm", "GiganteFleur", "PetalGuard" },
		bonus = { cooldown = 0.10 },
	},
	Chopper = {
		title = "Cotton Candy Lover", perk = "Heals nearby allies", color = Color3.fromRGB(255, 130, 180),
		weapon = "KungFuPoint",
		skills = { "KungFuPoint", "HeavyGong", "HornPoint", "RumbleBall", "CherryBlossom", "MedicineBomb" },
		bonus = { heal = 2 },
	},
}
Config.CLASS_ORDER = { "Luffy", "Zoro", "Nami", "Sanji", "Ace", "Robin", "Chopper" }

-- Which character each skill belongs to (filled in from the skill lists above).
Config.SkillOwner = {}
for className, class in Config.Classes do
	for _, skill in class.skills do
		Config.SkillOwner[skill] = className
	end
end

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

-- Permanent upgrades bought with gold between runs. Cost = cost * (growth or META_GROWTH) ^ level.
Config.Meta = {
	SkillSlot = {
		name = "Skill Slot", desc = "+1 skill slot", stat = "slots", per = 1, max = 5, cost = 300, growth = 1.7,
	},
	Might = { name = "Might", desc = "+5% damage", stat = "damage", per = 0.05, max = 10, cost = 100 },
	Toughness = { name = "Toughness", desc = "+10 max HP", stat = "health", per = 10, max = 10, cost = 100 },
	Greed = { name = "Greed", desc = "+10% gold", stat = "gold", per = 0.10, max = 10, cost = 150 },
	Reach = { name = "Reach", desc = "+10% pickup range", stat = "magnet", per = 0.10, max = 5, cost = 120 },
	Reroll = { name = "Reroll", desc = "+1 reroll per run", stat = "reroll", per = 1, max = 5, cost = 300 },
}
Config.META_ORDER = { "SkillSlot", "Might", "Toughness", "Greed", "Reach", "Reroll" }
Config.META_GROWTH = 1.5

return Config
