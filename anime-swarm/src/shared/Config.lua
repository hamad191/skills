-- All game balance lives here.
local Config = {}

Config.MINIBOSS_EVERY = 120
Config.RESULTS_TIME = 8
Config.MAX_ENEMIES = 150
Config.SPAWN_MIN, Config.SPAWN_MAX = 55, 85 -- spawn distance from players

-- Spawn island and voyage gates. Keep these in sync with tools/build_place.py.
Config.ISLAND_CENTER = Vector3.new(0, 0, 1400)
Config.GATES = { Vector3.new(-34, 0, 1488), Vector3.new(0, 0, 1500), Vector3.new(34, 0, 1488) }
Config.GATE_COLORS = { Color3.fromRGB(70, 190, 255), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 90, 90) }
Config.PORTAL_RADIUS = 7 -- stand this close to a gate's pad to board
Config.PORTAL_COUNTDOWN = 10
Config.ARENA_DROP_RADIUS = 25
Config.ARENA_HALF_SIZE = 500 -- every arena floor is 1000 x 1000
Config.MAP_SPACING = 1200

-- Every map has these 5 difficulties. Clear one to unlock the next on that map.
-- hp / damage / gold multiply the map's own values (gold +10% per step).
Config.Difficulties = {
	{ name = "Easy", color = Color3.fromRGB(90, 220, 120), hp = 1, damage = 1, gold = 1.0, runLength = 300 },
	{ name = "Normal", color = Color3.fromRGB(80, 170, 255), hp = 1.35, damage = 1.2, gold = 1.1, runLength = 360 },
	{ name = "Hard", color = Color3.fromRGB(255, 190, 50), hp = 1.8, damage = 1.45, gold = 1.2, runLength = 420 },
	{ name = "Very Hard", color = Color3.fromRGB(255, 110, 50), hp = 2.4, damage = 1.75, gold = 1.3, runLength = 480 },
	{ name = "Extreme", color = Color3.fromRGB(230, 40, 60), hp = 3.2, damage = 2.1, gold = 1.4, runLength = 600 },
}

-- 20 adventure maps in story order. Clear a map on Easy to unlock the next map.
-- theme picks the arena look (tools/build_place.py); boss is the Marine waiting at the end.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Config.Maps = {
	{ key = "Foosha", name = "Foosha Village", theme = "grass", boss = "Captain Nezumi", bossColor = rgb(240, 240, 245), bossAccent = rgb(60, 90, 160) },
	{ key = "ShellsTown", name = "Shells Town", theme = "marine", boss = "Captain Morgan", bossColor = rgb(150, 150, 165), bossAccent = rgb(40, 50, 90) },
	{ key = "OrangeTown", name = "Orange Town", theme = "town", boss = "Lieutenant Fullbody", bossColor = rgb(250, 250, 250), bossAccent = rgb(200, 120, 40) },
	{ key = "SyrupVillage", name = "Syrup Village", theme = "beach", boss = "Jango", bossColor = rgb(90, 160, 90), bossAccent = rgb(40, 40, 60) },
	{ key = "Baratie", name = "Baratie", theme = "ship", boss = "Captain T-Bone", bossColor = rgb(235, 235, 240), bossAccent = rgb(90, 60, 40) },
	{ key = "ArlongPark", name = "Arlong Park", theme = "deepsea", boss = "Captain Hina", bossColor = rgb(250, 200, 220), bossAccent = rgb(130, 30, 80) },
	{ key = "Loguetown", name = "Loguetown", theme = "town", boss = "Captain Smoker", bossColor = rgb(245, 245, 245), bossAccent = rgb(70, 110, 80) },
	{ key = "DrumIsland", name = "Drum Island", theme = "snow", boss = "Tashigi", bossColor = rgb(80, 120, 200), bossAccent = rgb(30, 40, 80) },
	{ key = "Alabasta", name = "Alabasta", theme = "desert", boss = "Vice Admiral Doberman", bossColor = rgb(240, 230, 200), bossAccent = rgb(140, 90, 40) },
	{ key = "Jaya", name = "Jaya", theme = "jungle", boss = "Vice Admiral Onigumo", bossColor = rgb(60, 60, 70), bossAccent = rgb(150, 40, 40) },
	{ key = "Skypiea", name = "Skypiea", theme = "sky", boss = "Vice Admiral Momonga", bossColor = rgb(250, 250, 255), bossAccent = rgb(230, 190, 60) },
	{ key = "Water7", name = "Water 7", theme = "town", boss = "Kaku of CP9", bossColor = rgb(30, 30, 35), bossAccent = rgb(230, 230, 230) },
	{ key = "EniesLobby", name = "Enies Lobby", theme = "marine", boss = "Rob Lucci of CP9", bossColor = rgb(20, 20, 25), bossAccent = rgb(240, 240, 240) },
	{ key = "ThrillerBark", name = "Thriller Bark", theme = "spooky", boss = "Vice Admiral Strawberry", bossColor = rgb(200, 60, 80), bossAccent = rgb(50, 20, 40) },
	{ key = "Sabaody", name = "Sabaody Archipelago", theme = "mangrove", boss = "Admiral Kizaru", bossColor = rgb(255, 220, 60), bossAccent = rgb(250, 250, 250) },
	{ key = "ImpelDown", name = "Impel Down", theme = "prison", boss = "Chief Warden Magellan", bossColor = rgb(90, 30, 110), bossAccent = rgb(30, 10, 40) },
	{ key = "Marineford", name = "Marineford", theme = "marine", boss = "Admiral Akainu", bossColor = rgb(200, 30, 30), bossAccent = rgb(250, 250, 250) },
	{ key = "FishmanIsland", name = "Fishman Island", theme = "deepsea", boss = "Admiral Aokiji", bossColor = rgb(80, 140, 230), bossAccent = rgb(250, 250, 250) },
	{ key = "PunkHazard", name = "Punk Hazard", theme = "volcano", boss = "Vice Admiral Vergo", bossColor = rgb(40, 40, 45), bossAccent = rgb(230, 230, 230) },
	{ key = "Wano", name = "Wano Country", theme = "wano", boss = "Fleet Admiral Sengoku", bossColor = rgb(240, 200, 60), bossAccent = rgb(250, 250, 250) },
}
Config.MapByKey = {}
for i, map in Config.Maps do
	map.index = i
	-- arenas sit in a 5-wide grid south of the island (tools/build_place.py uses the same formula)
	map.center = Vector3.new(((i - 1) % 5 - 2) * Config.MAP_SPACING, 0, -Config.MAP_SPACING * (1 + math.floor((i - 1) / 5)))
	map.hp = 0.7 + 0.12 * (i - 1)
	map.damage = 0.7 + 0.08 * (i - 1)
	map.gold = 1 + 0.2 * (i - 1)
	Config.MapByKey[map.key] = map
end

-- progress: [mapKey] = highest difficulty cleared on that map (0 or nil = none).
function Config.unlocked(progress, map, difficulty)
	if map.index > 1 and (progress[Config.Maps[map.index - 1].key] or 0) < 1 then
		return false -- clear the previous map on Easy first
	end
	return difficulty == 1 or (progress[map.key] or 0) >= difficulty - 1
end

Config.WEAPON_SLOTS_START = 3 -- buy more with the "Skill Slot" upgrade
Config.WEAPON_SLOTS_MAX = 8
Config.PASSIVE_SLOTS = 5
Config.BASE_CRIT_CHANCE = 0.05 -- every hit can crit
Config.BASE_CRIT_DAMAGE = 1.5 -- crits deal x1.5 before Critical Power
Config.MAX_DEFENSE = 0.6 -- damage taken can be cut by at most 60%
Config.WEAPON_MAX = 10
Config.PASSIVE_MAX = 5
Config.CHOICES = 3

-- A fused skill fires both of its skills, each boosted like this.
Config.FUSION = { damage = 2, cooldown = 0.8, area = 1.15, extraHits = 1 }

Config.BASE_HEALTH = 100
Config.BASE_SPEED = 16
Config.BASE_MAGNET = 10

-- Skills fire on their own. Each character owns 6 skills (see Config.Classes); level-ups mostly
-- offer your own character's skills, and now and then a crewmate's ("crew skill").
-- A signature skill evolves when it is max level and its `evolveWith` passive is also max level.
-- Any two max-level (or evolved) skills can be fused into one stronger skill (see Config.FUSION).
-- kind: how it hits (cone | chain | projectile | clones | orbit | line | aura)
-- fx: the effect players see (punch | slash | lightning | grab | shot | kick | nova | hands | strike | wave | orbit)
-- anim: the character's attack animation (punch | slash | kick | throw | cast | cross)
-- Optional look tweaks: arcs (slash lines), arm (punch arm color), cloud (lightning from a cloud), fire (flames)
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

	-- Usopp ------------------------------------------------------------------------
	FireBirdStar = {
		name = "Fire Bird Star", desc = "A flaming bird shot from Kabuto that explodes.",
		fx = "shot", anim = "throw", fire = true,
		kind = "projectile", damage = 26, cooldown = 2, range = 60, radius = 6,
		color = rgb(255, 120, 40), evolveWith = "Area", evolvesInto = "FirebirdBarrage",
	},
	LeadStar = {
		name = "Lead Star", desc = "Rapid lead pellets fly straight and true.",
		fx = "wave", anim = "throw",
		kind = "line", damage = 14, cooldown = 1.3, range = 45, width = 1.5, count = 2, color = rgb(200, 200, 210),
	},
	ExplosiveStar = {
		name = "Explosive Star", desc = "Gunpowder pellets blow up the crowd.",
		fx = "strike", anim = "throw",
		kind = "clones", damage = 30, cooldown = 3, range = 6, count = 2, color = rgb(255, 150, 40),
	},
	TabascoStar = {
		name = "Tabasco Star", desc = "A burst of spicy sauce burns everyone nearby.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 12, cooldown = 1.8, range = 8, color = rgb(230, 40, 30),
	},
	PopGreen = {
		name = "Pop Green", desc = "Monster plants burst out of the ground.",
		fx = "strike", anim = "throw",
		kind = "clones", damage = 34, cooldown = 3.4, range = 7, count = 2, color = rgb(80, 200, 70),
	},
	ImpactDial = {
		name = "Impact Dial", desc = "Releases a crushing blast straight ahead.",
		fx = "slash", anim = "punch", arcs = 1,
		kind = "cone", damage = 34, cooldown = 2.4, range = 9, angle = 100, color = rgb(240, 220, 180),
	},

	-- Franky -----------------------------------------------------------------------
	CoupDeVent = {
		name = "Coup de Vent", desc = "A blast of compressed air from his arms.",
		fx = "wave", anim = "punch",
		kind = "line", damage = 30, cooldown = 2.2, range = 40, width = 4, count = 1,
		color = rgb(140, 220, 255), evolveWith = "Vitality", evolvesInto = "RadicalBeam",
	},
	WeaponsLeft = {
		name = "Weapons Left", desc = "Fires a cannon shell from his left arm.",
		fx = "shot", anim = "punch",
		kind = "projectile", damage = 22, cooldown = 1.8, range = 50, radius = 5, color = rgb(120, 140, 170),
	},
	StrongRight = {
		name = "Strong Right", desc = "A rocket punch on a chain.",
		fx = "punch", anim = "punch", arm = rgb(90, 140, 200),
		kind = "line", damage = 34, cooldown = 2.6, range = 20, width = 4, count = 1, color = rgb(60, 110, 200),
	},
	FrankyFireball = {
		name = "Franky Fireball", desc = "Breathes a cone of fire.",
		fx = "slash", anim = "cast", arcs = 2,
		kind = "cone", damage = 18, cooldown = 1.4, range = 12, angle = 70, color = rgb(255, 130, 40),
	},
	GeneralCannon = {
		name = "General Cannon", desc = "Shells rain down from Franky General.",
		fx = "strike", anim = "cast",
		kind = "clones", damage = 36, cooldown = 3.4, range = 7, count = 2, color = rgb(70, 140, 230),
	},
	FrankyCenter = {
		name = "Franky Center", desc = "A SUPER shockwave all around.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 14, cooldown = 2, range = 9, color = rgb(80, 200, 255),
	},

	-- Brook ------------------------------------------------------------------------
	YahazuGiri = {
		name = "Yahazu Giri", desc = "A cane-sword cut faster than sound.",
		fx = "slash", anim = "slash", arcs = 1,
		kind = "cone", damage = 22, cooldown = 1.2, range = 16, angle = 60,
		color = rgb(180, 220, 255), evolveWith = "Haste", evolvesInto = "SoulRequiem",
	},
	FrostBite = {
		name = "Soul Solid", desc = "A freezing cut that leaps from foe to foe.",
		fx = "lightning", anim = "slash",
		kind = "chain", damage = 18, cooldown = 1.8, range = 26, count = 4, color = rgb(150, 220, 255),
	},
	AubadeCoup = {
		name = "Aubade Coup Droit", desc = "A thrust of air that pierces a line.",
		fx = "wave", anim = "slash",
		kind = "line", damage = 26, cooldown = 2, range = 40, width = 2, count = 1, color = rgb(210, 230, 255),
	},
	GhostParade = {
		name = "Ghost Parade", desc = "Ghostly souls circle you.",
		fx = "orbit",
		kind = "orbit", damage = 8, cooldown = 0.5, range = 8, count = 3, color = rgb(200, 220, 255),
	},
	SoulParade = {
		name = "Soul Parade", desc = "A chilling wave of soul power.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 14, cooldown = 1.8, range = 10, color = rgb(140, 200, 255),
	},
	IceBurn = {
		name = "Ice Burn", desc = "Ice pillars freeze enemies in place.",
		fx = "strike", anim = "slash",
		kind = "clones", damage = 30, cooldown = 3, range = 6, count = 2, color = rgb(170, 230, 255),
	},

	-- Jinbe ------------------------------------------------------------------------
	FishmanKarate = {
		name = "Fishman Karate", desc = "A punch that sends shockwaves through the water in the air.",
		fx = "punch", anim = "punch", arm = rgb(70, 120, 200),
		kind = "line", damage = 20, cooldown = 1.5, range = 25, width = 4, count = 1,
		color = rgb(240, 140, 40), evolveWith = "Power", evolvesInto = "VagabondDrill",
	},
	SharkBrick = {
		name = "Shark Brick Fist", desc = "A sweeping strike in front.",
		fx = "slash", anim = "punch", arcs = 1,
		kind = "cone", damage = 24, cooldown = 1.7, range = 12, angle = 120, color = rgb(80, 140, 230),
	},
	WaterHeart = {
		name = "Water Heart", desc = "Throws a heavy ball of water that bursts.",
		fx = "shot", anim = "throw",
		kind = "projectile", damage = 30, cooldown = 2.6, range = 50, radius = 8, color = rgb(70, 170, 255),
	},
	FiveThousandTiles = {
		name = "5000 Brick Fist", desc = "A punch that crashes down like a tidal wave.",
		fx = "strike", anim = "punch",
		kind = "clones", damage = 55, cooldown = 4.4, range = 9, count = 1, color = rgb(60, 120, 220),
	},
	SharkArrows = {
		name = "Shark Arrows", desc = "Arrows of water shoot through the swarm.",
		fx = "wave", anim = "throw",
		kind = "line", damage = 14, cooldown = 1.6, range = 40, width = 2, count = 3, color = rgb(120, 200, 255),
	},
	OceanCurrent = {
		name = "Ocean Current", desc = "Spins the current around you to throw enemies.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 16, cooldown = 2, range = 10, color = rgb(60, 160, 230),
	},

	-- Law --------------------------------------------------------------------------
	RoomAmputate = {
		name = "Room: Amputate", desc = "Slices everything inside a wide arc.",
		fx = "slash", anim = "slash", arcs = 1,
		kind = "cone", damage = 24, cooldown = 1.6, range = 18, angle = 140,
		color = rgb(100, 220, 255), evolveWith = "Haste", evolvesInto = "GammaKnife",
	},
	CounterShock = {
		name = "Counter Shock", desc = "An electric shock that jumps between enemies.",
		fx = "lightning", anim = "cast",
		kind = "chain", damage = 20, cooldown = 1.8, range = 28, count = 4, color = rgb(255, 240, 100),
	},
	Injection = {
		name = "Injection Shot", desc = "A piercing lunge with Kikoku.",
		fx = "wave", anim = "slash",
		kind = "line", damage = 30, cooldown = 2, range = 50, width = 1.5, count = 1, color = rgb(220, 240, 255),
	},
	Shambles = {
		name = "Shambles", desc = "Swaps the ground beneath enemies for a blast.",
		fx = "strike", anim = "cast",
		kind = "clones", damage = 32, cooldown = 3, range = 6, count = 2, color = rgb(80, 200, 255),
	},
	Mes = {
		name = "Mes", desc = "Floating cubes circle you and cut enemies.",
		fx = "orbit",
		kind = "orbit", damage = 10, cooldown = 0.5, range = 8, count = 2, color = rgb(120, 230, 255),
	},
	RoomDome = {
		name = "Room Dome", desc = "A blue dome pulses around you.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 14, cooldown = 2.2, range = 12, color = rgb(90, 190, 255),
	},

	-- Boa Hancock ------------------------------------------------------------------
	PerfumeFemur = {
		name = "Perfume Femur", desc = "A kick that turns enemies to stone.",
		fx = "slash", anim = "kick", arcs = 1,
		kind = "cone", damage = 22, cooldown = 1.4, range = 14, angle = 100,
		color = rgb(255, 120, 180), evolveWith = "Power", evolvesInto = "LoveParadise",
	},
	SlaveArrow = {
		name = "Slave Arrow", desc = "Heart arrows pierce through the crowd.",
		fx = "wave", anim = "cast",
		kind = "line", damage = 16, cooldown = 1.6, range = 40, width = 2, count = 3, color = rgb(255, 110, 170),
	},
	PistolKiss = {
		name = "Pistol Kiss", desc = "Blows a kiss that bursts on impact.",
		fx = "shot", anim = "throw",
		kind = "projectile", damage = 26, cooldown = 2, range = 50, radius = 5, color = rgb(255, 90, 150),
	},
	MeroMellow = {
		name = "Mero Mero Mellow", desc = "A wave of love petrifies everyone close.",
		fx = "nova", anim = "cross",
		kind = "aura", damage = 14, cooldown = 1.8, range = 10, color = rgb(255, 140, 200),
	},
	Salome = {
		name = "Salome Strike", desc = "Her giant snake crashes down.",
		fx = "strike", anim = "cross",
		kind = "clones", damage = 50, cooldown = 4, range = 9, count = 1, color = rgb(160, 90, 200),
	},
	LoveHearts = {
		name = "Love Hearts", desc = "Hearts orbit you and strike anything close.",
		fx = "orbit",
		kind = "orbit", damage = 8, cooldown = 0.5, range = 7, count = 3, color = rgb(255, 120, 190),
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
	FirebirdBarrage = {
		name = "Firebird Barrage", desc = "A flock of fire birds bombs the battlefield.",
		fx = "shot", anim = "throw", fire = true,
		kind = "projectile", damage = 120, cooldown = 1.4, range = 70, radius = 10, count = 4,
		color = rgb(255, 90, 20), evolved = true, from = "FireBirdStar",
	},
	RadicalBeam = {
		name = "Radical Beam", desc = "SUPER beams blast everything in their path.",
		fx = "wave", anim = "punch",
		kind = "line", damage = 140, cooldown = 1.2, range = 60, width = 6, count = 3,
		color = rgb(90, 230, 255), evolved = true, from = "CoupDeVent",
	},
	SoulRequiem = {
		name = "Soul King's Requiem", desc = "Icy cuts in every direction.",
		fx = "slash", anim = "slash", arcs = 2,
		kind = "cone", damage = 95, cooldown = 0.9, range = 22, angle = 100, count = 4,
		color = rgb(160, 230, 255), evolved = true, from = "YahazuGiri",
	},
	VagabondDrill = {
		name = "Vagabond Drill", desc = "Spiraling water punches drill through the swarm.",
		fx = "punch", anim = "punch", arm = rgb(70, 120, 200),
		kind = "line", damage = 70, cooldown = 1, range = 40, width = 5, count = 6,
		color = rgb(40, 140, 255), evolved = true, from = "FishmanKarate",
	},
	GammaKnife = {
		name = "Gamma Knife", desc = "Destroys enemies from the inside, one after another.",
		fx = "lightning", anim = "slash",
		kind = "chain", damage = 75, cooldown = 0.9, range = 40, count = 8,
		color = rgb(120, 240, 255), evolved = true, from = "RoomAmputate",
	},
	LoveParadise = {
		name = "Love-Love Paradise", desc = "Petrifying kicks in every direction.",
		fx = "slash", anim = "kick", arcs = 2,
		kind = "cone", damage = 95, cooldown = 0.9, range = 20, angle = 110, count = 4,
		color = rgb(255, 90, 170), evolved = true, from = "PerfumeFemur",
	},
}

-- Icon shown on cards, skill slots and menus.
local ICONS = {
	GumGumPistol = "👊", GumGumBazooka = "🤜", GumGumWhip = "🦵", GumGumBalloon = "🎈", GumGumElephantGun = "🐘", RedHawk = "🦅",
	ThreeSwordStyle = "⚔️", PoundCannon = "🌪️", OniGiri = "👹", Tatsumaki = "🌀", ShishiSonson = "🦁", BlackRopeDragon = "🐉",
	ThunderTempo = "⚡", CycloneTempo = "💨", MirageTempo = "🌫️", ThunderLance = "🌩️", WeatherEgg = "🥚", BlackBall = "☁️",
	DiableJambe = "🔥", Concasse = "🦶", PartyTable = "🌀", MoutonShot = "💥", PoeleAFrire = "🍳", FlambageShot = "☄️",
	FireFist = "🔥", FireGun = "🔫", Firefly = "✨", FirePillar = "🌋", FireFence = "⭕", CrossFire = "✖️",
	CienFleur = "🌸", SeisFleur = "🤲", MilFleur = "💐", FlowerStorm = "🌺", GiganteFleur = "✋", PetalGuard = "🏵️",
	KungFuPoint = "🥊", HeavyGong = "💪", HornPoint = "🦌", RumbleBall = "💊", CherryBlossom = "🌸", MedicineBomb = "🧪",
	FireBirdStar = "🐦", LeadStar = "🎯", ExplosiveStar = "💣", TabascoStar = "🌶️", PopGreen = "🌱", ImpactDial = "🐚",
	CoupDeVent = "💨", WeaponsLeft = "🔫", StrongRight = "🦾", FrankyFireball = "🔥", GeneralCannon = "🤖", FrankyCenter = "⭐",
	YahazuGiri = "🎻", FrostBite = "❄️", AubadeCoup = "🎼", GhostParade = "👻", SoulParade = "💀", IceBurn = "🧊",
	FishmanKarate = "🥋", SharkBrick = "🦈", WaterHeart = "💧", FiveThousandTiles = "🧱", SharkArrows = "🏹", OceanCurrent = "🌊",
	RoomAmputate = "🔵", CounterShock = "⚡", Injection = "💉", Shambles = "🔄", Mes = "🧊", RoomDome = "🔷",
	PerfumeFemur = "👠", SlaveArrow = "💘", PistolKiss = "💋", MeroMellow = "💗", Salome = "🐍", LoveHearts = "💕",
	GumGumGatling = "👊", NineSwordStyle = "⚔️", ZeusTempo = "⛈️", IfritJambe = "🔥", FlameEmperor = "☀️",
	GigantescoMano = "🙌", MonsterPoint = "🦍", FirebirdBarrage = "🐦", RadicalBeam = "🌟", SoulRequiem = "🎻",
	VagabondDrill = "🌊", GammaKnife = "🔪", LoveParadise = "💖",
}
for key, w in Config.Weapons do
	w.icon = ICONS[key] or "✨"
end

-- `per` is added once per passive level to the named stat.
Config.Passives = {
	Power = { icon = "💪", name = "Haki", desc = "+10% damage", stat = "damage", per = 0.10 },
	Haste = { icon = "⏩", name = "Haste", desc = "-8% cooldowns", stat = "cooldown", per = 0.08 },
	Area = { icon = "⭕", name = "Expansion", desc = "+10% area", stat = "area", per = 0.10 },
	Swiftness = { icon = "👟", name = "Swift Feet", desc = "+8% move speed", stat = "speed", per = 0.08 },
	Vitality = { icon = "❤️", name = "Vitality", desc = "+20 max HP", stat = "health", per = 20 },
	Magnet = { icon = "🧲", name = "Treasure Magnet", desc = "+25% pickup range", stat = "magnet", per = 0.25 },
	Multiply = { icon = "✳️", name = "Multiply", desc = "+1 extra hit every 2 levels", stat = "count", per = 0.5 },
	Critical = { icon = "🎯", name = "Critical Eye", desc = "+5% critical hit chance", stat = "crit", per = 0.05 },
	CritDamage = { icon = "💢", name = "Critical Power", desc = "+25% critical hit damage", stat = "critDamage", per = 0.25 },
	Regen = { icon = "💚", name = "Regeneration", desc = "+0.6 HP every second", stat = "regen", per = 0.6 },
	Armor = { icon = "🛡️", name = "Iron Body", desc = "-6% damage taken", stat = "defense", per = 0.06 },
}

Config.DEFAULT_CLASS = "Luffy"
Config.Classes = {
	Luffy = {
		icon = "👒", title = "Straw Hat", perk = "+30 max HP", color = Color3.fromRGB(220, 50, 50),
		weapon = "GumGumPistol",
		skills = { "GumGumPistol", "GumGumBazooka", "GumGumWhip", "GumGumBalloon", "GumGumElephantGun", "RedHawk" },
		bonus = { health = 30 },
	},
	Zoro = {
		icon = "⚔️", title = "Pirate Hunter", perk = "+10% damage", color = Color3.fromRGB(60, 190, 90),
		weapon = "ThreeSwordStyle",
		skills = { "ThreeSwordStyle", "PoundCannon", "OniGiri", "Tatsumaki", "ShishiSonson", "BlackRopeDragon" },
		bonus = { damage = 0.10 },
	},
	Nami = {
		icon = "🍊", title = "Cat Burglar", perk = "+25% gold", color = Color3.fromRGB(255, 150, 40),
		weapon = "ThunderTempo",
		skills = { "ThunderTempo", "CycloneTempo", "MirageTempo", "ThunderLance", "WeatherEgg", "BlackBall" },
		bonus = { gold = 0.25 },
	},
	Sanji = {
		icon = "🦵", title = "Black Leg", perk = "+15% move speed", color = Color3.fromRGB(240, 200, 60),
		weapon = "DiableJambe",
		skills = { "DiableJambe", "Concasse", "PartyTable", "MoutonShot", "PoeleAFrire", "FlambageShot" },
		bonus = { speed = 0.15 },
	},
	Ace = {
		icon = "🔥", title = "Fire Fist", perk = "+15% area", color = Color3.fromRGB(255, 100, 30),
		weapon = "FireFist",
		skills = { "FireFist", "FireGun", "Firefly", "FirePillar", "FireFence", "CrossFire" },
		bonus = { area = 0.15 },
	},
	Robin = {
		icon = "🌸", title = "Devil Child", perk = "-10% cooldowns", color = Color3.fromRGB(150, 90, 220),
		weapon = "CienFleur",
		skills = { "CienFleur", "SeisFleur", "MilFleur", "FlowerStorm", "GiganteFleur", "PetalGuard" },
		bonus = { cooldown = 0.10 },
	},
	Chopper = {
		icon = "🦌", title = "Cotton Candy Lover", perk = "Heals nearby allies", color = Color3.fromRGB(255, 130, 180),
		weapon = "KungFuPoint",
		skills = { "KungFuPoint", "HeavyGong", "HornPoint", "RumbleBall", "CherryBlossom", "MedicineBomb" },
		bonus = { heal = 2 },
	},
	Usopp = {
		icon = "🎯", title = "King of Snipers", perk = "+1 reroll each run", color = Color3.fromRGB(200, 160, 70),
		weapon = "FireBirdStar",
		skills = { "FireBirdStar", "LeadStar", "ExplosiveStar", "TabascoStar", "PopGreen", "ImpactDial" },
		bonus = { reroll = 1 },
	},
	Franky = {
		icon = "🤖", title = "Cyborg", perk = "+8% damage, +20 max HP", color = Color3.fromRGB(70, 170, 240),
		weapon = "CoupDeVent",
		skills = { "CoupDeVent", "WeaponsLeft", "StrongRight", "FrankyFireball", "GeneralCannon", "FrankyCenter" },
		bonus = { damage = 0.08, health = 20 },
	},
	Brook = {
		icon = "💀", title = "Soul King", perk = "+30% pickup range", color = Color3.fromRGB(150, 130, 200),
		weapon = "YahazuGiri",
		skills = { "YahazuGiri", "FrostBite", "AubadeCoup", "GhostParade", "SoulParade", "IceBurn" },
		bonus = { magnet = 0.3 },
	},
	Jinbe = {
		icon = "🦈", title = "Knight of the Sea", perk = "+50 max HP", color = Color3.fromRGB(60, 120, 210),
		weapon = "FishmanKarate",
		skills = { "FishmanKarate", "SharkBrick", "WaterHeart", "FiveThousandTiles", "SharkArrows", "OceanCurrent" },
		bonus = { health = 50 },
	},
	Law = {
		icon = "🩺", title = "Surgeon of Death", perk = "-8% cooldowns, +8% area", color = Color3.fromRGB(240, 210, 80),
		weapon = "RoomAmputate",
		skills = { "RoomAmputate", "CounterShock", "Injection", "Shambles", "Mes", "RoomDome" },
		bonus = { cooldown = 0.08, area = 0.08 },
	},
	Hancock = {
		icon = "🐍", title = "Pirate Empress", perk = "+15% damage", color = Color3.fromRGB(240, 90, 150),
		weapon = "PerfumeFemur",
		skills = { "PerfumeFemur", "SlaveArrow", "PistolKiss", "MeroMellow", "Salome", "LoveHearts" },
		bonus = { damage = 0.15 },
	},
}
Config.CLASS_ORDER = { "Luffy", "Zoro", "Nami", "Sanji", "Ace", "Robin", "Chopper", "Usopp", "Franky", "Brook", "Jinbe", "Law", "Hancock" }

-- Which character each skill belongs to (filled in from the skill lists above).
Config.SkillOwner = {}
for className, class in Config.Classes do
	for _, skill in class.skills do
		Config.SkillOwner[skill] = className
	end
end

-- color = clothes, accent = cap and pants, skin = head and hands, eyes = glowing eye color
-- gear: what they carry (sword | rifle | cannon | coat). ai: how they fight:
--   melee (walk up and hit), ranged (keep distance and shoot), artillery (shell an area),
--   boss (melee plus telegraphed slams; the final boss also calls down a ring of strikes)
local SKIN = Color3.fromRGB(255, 205, 160)
local WHITE = Color3.fromRGB(240, 240, 245)
local NAVY = Color3.fromRGB(35, 60, 130)
Config.Enemies = {
	Grunt = { name = "Marine Recruit", hp = 20, speed = 11, damage = 6, xp = 1, scale = 1, color = WHITE, accent = NAVY, skin = SKIN },
	Swordsman = {
		name = "Marine Swordsman", hp = 34, speed = 13, damage = 9, xp = 2, scale = 1.05,
		color = WHITE, accent = Color3.fromRGB(25, 45, 110), skin = SKIN, gear = "sword",
	},
	Rifleman = {
		name = "Marine Rifleman", hp = 18, speed = 10, damage = 7, xp = 2, scale = 1,
		color = WHITE, accent = Color3.fromRGB(50, 90, 60), skin = SKIN, gear = "rifle",
		ai = "ranged", range = 32, fireRate = 2.6,
	},
	Runner = {
		name = "Fishman", hp = 12, speed = 15, damage = 4, xp = 1, scale = 0.85,
		color = Color3.fromRGB(230, 120, 50), accent = Color3.fromRGB(30, 50, 90), skin = Color3.fromRGB(70, 150, 210),
	},
	Cannoneer = {
		name = "Marine Cannoneer", hp = 60, speed = 7, damage = 16, xp = 4, scale = 1.25,
		color = Color3.fromRGB(200, 205, 215), accent = Color3.fromRGB(60, 60, 70), skin = SKIN, gear = "cannon",
		ai = "artillery", range = 45, fireRate = 5, blast = 6,
	},
	Brute = {
		name = "Pacifista", hp = 110, speed = 8, damage = 14, xp = 6, scale = 1.7,
		color = Color3.fromRGB(55, 55, 65), accent = Color3.fromRGB(30, 30, 35), skin = Color3.fromRGB(200, 170, 140),
		eyes = Color3.fromRGB(255, 220, 60),
	},
	Captain = {
		name = "Marine Captain", hp = 220, speed = 11, damage = 16, xp = 10, scale = 1.4,
		color = Color3.fromRGB(250, 250, 250), accent = Color3.fromRGB(20, 35, 90), skin = SKIN, gear = "coat",
	},
	Agent = {
		name = "CP9 Agent", hp = 140, speed = 17, damage = 14, xp = 8, scale = 1.1,
		color = Color3.fromRGB(25, 25, 30), accent = Color3.fromRGB(15, 15, 20), skin = SKIN,
	},
	MiniBoss = {
		name = "Vice Admiral", hp = 1200, speed = 10, damage = 22, xp = 40, gold = 25, scale = 3, healthBar = true,
		color = Color3.fromRGB(250, 250, 250), accent = Color3.fromRGB(35, 35, 60), skin = SKIN, gear = "coat",
		ai = "boss", slamEvery = 6, blast = 8,
	},
	Boss = {
		name = "Admiral", hp = 15000, speed = 12, damage = 40, xp = 0, gold = 300, scale = 5, healthBar = true,
		color = Color3.fromRGB(250, 250, 250), accent = Color3.fromRGB(150, 20, 30), skin = SKIN, gear = "coat",
		eyes = Color3.fromRGB(255, 80, 40), ai = "boss", slamEvery = 5, ringEvery = 12, blast = 9,
	},
}

-- Which enemies show up: { kind, from map #, from minute, weight }. Later maps bring tougher Marines.
Config.SPAWN_TABLE = {
	{ "Grunt", 1, 0, 10 },
	{ "Swordsman", 1, 1, 4 },
	{ "Runner", 2, 1, 3 },
	{ "Rifleman", 2, 1.5, 3 },
	{ "Brute", 4, 3, 1.5 },
	{ "Cannoneer", 6, 2, 1.5 },
	{ "Captain", 8, 3, 1 },
	{ "Agent", 12, 2, 1.5 },
}

-- Permanent upgrades bought with gold between runs. Cost = cost * (growth or META_GROWTH) ^ level.
Config.Meta = {
	SkillSlot = {
		icon = "🧩", name = "Skill Slot", desc = "+1 skill slot", stat = "slots", per = 1, max = 5, cost = 300, growth = 1.7,
	},
	Might = { icon = "⚔️", name = "Might", desc = "+5% damage", stat = "damage", per = 0.05, max = 10, cost = 100 },
	Toughness = { icon = "❤️", name = "Toughness", desc = "+10 max HP", stat = "health", per = 10, max = 10, cost = 100 },
	Greed = { icon = "💰", name = "Greed", desc = "+10% gold", stat = "gold", per = 0.10, max = 10, cost = 150 },
	Reach = { icon = "🧲", name = "Reach", desc = "+10% pickup range", stat = "magnet", per = 0.10, max = 5, cost = 120 },
	Reroll = { icon = "🎲", name = "Reroll", desc = "+1 reroll per run", stat = "reroll", per = 1, max = 5, cost = 300 },
}
Config.META_ORDER = { "SkillSlot", "Might", "Toughness", "Greed", "Reach", "Reroll" }
Config.META_GROWTH = 1.5

return Config
