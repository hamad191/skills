-- All game balance lives here.
local Config = {}

-- Waves: every run is split into waves of WAVE_LENGTH seconds. Most waves start with an event
-- (a squad arriving all at once); every MINIBOSS_WAVE-th wave a Vice Admiral leads the attack.
-- When the last wave ends, the map's boss arrives.
Config.WAVE_LENGTH = 30
Config.MINIBOSS_WAVE = 4
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
	{ key = "Foosha", name = "Windmill Village", theme = "grass", boss = "Captain Whiskers", bossColor = rgb(240, 240, 245), bossAccent = rgb(60, 90, 160) },
	{ key = "ShellsTown", name = "Fort Harbor", theme = "marine", boss = "Captain Ironjaw", bossColor = rgb(150, 150, 165), bossAccent = rgb(40, 50, 90) },
	{ key = "OrangeTown", name = "Citrus Town", theme = "town", boss = "Lieutenant Peacock", bossColor = rgb(250, 250, 250), bossAccent = rgb(200, 120, 40) },
	{ key = "SyrupVillage", name = "Palm Cape", theme = "beach", boss = "Hypno Jack", bossColor = rgb(90, 160, 90), bossAccent = rgb(40, 40, 60) },
	{ key = "Baratie", name = "Sea Restaurant", theme = "ship", boss = "Captain Ribcage", bossColor = rgb(235, 235, 240), bossAccent = rgb(90, 60, 40) },
	{ key = "ArlongPark", name = "Shark Reef", theme = "deepsea", boss = "Captain Shackles", bossColor = rgb(250, 200, 220), bossAccent = rgb(130, 30, 80) },
	{ key = "Loguetown", name = "Gallows Town", theme = "town", boss = "Captain Haze", bossColor = rgb(245, 245, 245), bossAccent = rgb(70, 110, 80) },
	{ key = "DrumIsland", name = "Snowcap Island", theme = "snow", boss = "Swordswoman Kiri", bossColor = rgb(80, 120, 200), bossAccent = rgb(30, 40, 80) },
	{ key = "Alabasta", name = "Dune Kingdom", theme = "desert", boss = "Vice Admiral Hound", bossColor = rgb(240, 230, 200), bossAccent = rgb(140, 90, 40) },
	{ key = "Jaya", name = "Vine Island", theme = "jungle", boss = "Vice Admiral Arachne", bossColor = rgb(60, 60, 70), bossAccent = rgb(150, 40, 40) },
	{ key = "Skypiea", name = "Cloud Isle", theme = "sky", boss = "Vice Admiral Glider", bossColor = rgb(250, 250, 255), bossAccent = rgb(230, 190, 60) },
	{ key = "Water7", name = "Canal City", theme = "town", boss = "Agent Longneck", bossColor = rgb(30, 30, 35), bossAccent = rgb(230, 230, 230) },
	{ key = "EniesLobby", name = "Court Island", theme = "marine", boss = "Agent Panthera", bossColor = rgb(20, 20, 25), bossAccent = rgb(240, 240, 240) },
	{ key = "ThrillerBark", name = "Haunted Isle", theme = "spooky", boss = "Vice Admiral Thornberry", bossColor = rgb(200, 60, 80), bossAccent = rgb(50, 20, 40) },
	{ key = "Sabaody", name = "Bubble Grove", theme = "mangrove", boss = "Admiral Flash", bossColor = rgb(255, 220, 60), bossAccent = rgb(250, 250, 250) },
	{ key = "ImpelDown", name = "Abyss Prison", theme = "prison", boss = "Warden Toxus", bossColor = rgb(90, 30, 110), bossAccent = rgb(30, 10, 40) },
	{ key = "Marineford", name = "Navy Fortress", theme = "marine", boss = "Admiral Magmus", bossColor = rgb(200, 30, 30), bossAccent = rgb(250, 250, 250) },
	{ key = "FishmanIsland", name = "Coral Kingdom", theme = "deepsea", boss = "Admiral Glacius", bossColor = rgb(80, 140, 230), bossAccent = rgb(250, 250, 250) },
	{ key = "PunkHazard", name = "Burning Isle", theme = "volcano", boss = "Vice Admiral Steelfist", bossColor = rgb(40, 40, 45), bossAccent = rgb(230, 230, 230) },
	{ key = "Wano", name = "Blossom Land", theme = "wano", boss = "Fleet Admiral Goldbeam", bossColor = rgb(240, 200, 60), bossAccent = rgb(250, 250, 250) },
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
	-- Rocco -------------------------------------------------------------------------
	GumGumPistol = {
		name = "Rubber Pistol", desc = "Stretchy punches that pierce through enemies.",
		fx = "punch", anim = "punch",
		kind = "line", damage = 16, cooldown = 1.4, range = 35, width = 3, count = 1,
		color = rgb(230, 60, 60), evolveWith = "Vitality", evolvesInto = "GumGumGatling",
	},
	GumGumBazooka = {
		name = "Rubber Bazooka", desc = "A two-palm blast that smashes a straight line.",
		fx = "punch", anim = "punch",
		kind = "line", damage = 42, cooldown = 3.2, range = 22, width = 5, count = 1, color = rgb(230, 60, 60),
	},
	GumGumWhip = {
		name = "Rubber Whip", desc = "A stretching leg sweeps everything in front.",
		fx = "slash", anim = "kick", arcs = 1,
		kind = "cone", damage = 24, cooldown = 1.8, range = 18, angle = 160, color = rgb(255, 120, 90),
	},
	GumGumBalloon = {
		name = "Rubber Balloon", desc = "Puff up and bounce enemies away.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 16, cooldown = 2.4, range = 10, color = rgb(255, 170, 120),
	},
	GumGumElephantGun = {
		name = "Giant Rubber Fist", desc = "A giant fist crashes down on a crowd.",
		fx = "strike", anim = "punch",
		kind = "clones", damage = 65, cooldown = 5, range = 9, count = 1, color = rgb(220, 40, 40),
	},
	RedHawk = {
		name = "Blazing Fist", desc = "A blazing punch that explodes on impact.",
		fx = "shot", anim = "punch", fire = true,
		kind = "projectile", damage = 45, cooldown = 3, range = 45, radius = 6, color = rgb(255, 90, 40),
	},

	-- Kenji --------------------------------------------------------------------------
	ThreeSwordStyle = {
		name = "Triple Blade", desc = "Slashes the nearest enemies with three swords.",
		fx = "slash", anim = "slash", arcs = 3,
		kind = "cone", damage = 20, cooldown = 1.3, range = 14, angle = 110,
		color = rgb(80, 220, 120), evolveWith = "Power", evolvesInto = "NineSwordStyle",
	},
	PoundCannon = {
		name = "Air Cannon Slash", desc = "A flying slash wave cuts down a line.",
		fx = "wave", anim = "slash",
		kind = "line", damage = 28, cooldown = 2.2, range = 45, width = 3, count = 1, color = rgb(120, 255, 160),
	},
	OniGiri = {
		name = "Demon Cut", desc = "Three blades thrust forward at once.",
		fx = "slash", anim = "slash", arcs = 3,
		kind = "cone", damage = 34, cooldown = 2.6, range = 22, angle = 45, color = rgb(60, 200, 90),
	},
	Tatsumaki = {
		name = "Blade Tornado", desc = "A cyclone of blades around you.",
		fx = "nova", anim = "slash",
		kind = "aura", damage = 18, cooldown = 2.2, range = 12, color = rgb(160, 255, 190),
	},
	ShishiSonson = {
		name = "Lion Strike", desc = "A lightning-fast cut that leaps between foes.",
		fx = "lightning", anim = "slash",
		kind = "chain", damage = 24, cooldown = 2, range = 28, count = 4, color = rgb(200, 255, 210),
	},
	BlackRopeDragon = {
		name = "Dragon Twister", desc = "Black tornadoes of blades crash down.",
		fx = "strike", anim = "slash",
		kind = "clones", damage = 38, cooldown = 4.2, range = 8, count = 2, color = rgb(30, 110, 60),
	},

	-- Skye --------------------------------------------------------------------------
	ThunderTempo = {
		name = "Thunder Bolt", desc = "Lightning from a storm staff jumps between enemies.",
		fx = "lightning", anim = "cast", cloud = true,
		kind = "chain", damage = 14, cooldown = 1.6, range = 30, count = 3,
		color = rgb(255, 240, 90), evolveWith = "Magnet", evolvesInto = "ZeusTempo",
	},
	CycloneTempo = {
		name = "Cyclone", desc = "Gusts of wind blast through the swarm.",
		fx = "wave", anim = "cast",
		kind = "line", damage = 18, cooldown = 2, range = 35, width = 3, count = 2, color = rgb(200, 240, 255),
	},
	MirageTempo = {
		name = "Mirage", desc = "Mirage copies of the navigator burst with light.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 14, cooldown = 1.6, range = 9, color = rgb(255, 190, 90),
	},
	ThunderLance = {
		name = "Thunder Lance", desc = "Bolts of lightning strike from above.",
		fx = "strike", anim = "cast",
		kind = "clones", damage = 40, cooldown = 3.6, range = 6, count = 2, color = rgb(255, 240, 90),
	},
	WeatherEgg = {
		name = "Weather Orb", desc = "A weather bubble that bursts into a storm.",
		fx = "shot", anim = "throw",
		kind = "projectile", damage = 30, cooldown = 2.6, range = 50, radius = 8, color = rgb(120, 200, 255),
	},
	BlackBall = {
		name = "Storm Cloud", desc = "Thunderclouds circle you, shocking anyone close.",
		fx = "orbit",
		kind = "orbit", damage = 9, cooldown = 0.5, range = 9, count = 2, color = rgb(90, 90, 140),
	},

	-- Blaze -------------------------------------------------------------------------
	DiableJambe = {
		name = "Flame Kick", desc = "Burning kicks hit everything around you.",
		fx = "kick", anim = "kick", fire = true,
		kind = "aura", damage = 12, cooldown = 0.8, range = 8,
		color = rgb(255, 90, 40), evolveWith = "Swiftness", evolvesInto = "IfritJambe",
	},
	Concasse = {
		name = "Crushing Heel", desc = "A crushing heel drop from the sky.",
		fx = "strike", anim = "kick",
		kind = "clones", damage = 46, cooldown = 3.6, range = 8, count = 1, color = rgb(255, 200, 80),
	},
	PartyTable = {
		name = "Handstand Spin", desc = "A whirlwind of kicks while standing on your hands.",
		fx = "kick", anim = "kick",
		kind = "aura", damage = 10, cooldown = 1.2, range = 7, color = rgb(255, 250, 225),
	},
	MoutonShot = {
		name = "Ram Shot", desc = "A kick so fast it fires a shockwave.",
		fx = "wave", anim = "kick",
		kind = "line", damage = 30, cooldown = 2.5, range = 28, width = 4, count = 1, color = rgb(255, 230, 150),
	},
	PoeleAFrire = {
		name = "Searing Sweep", desc = "Burning kicks rake a wide arc.",
		fx = "slash", anim = "kick", arcs = 2,
		kind = "cone", damage = 22, cooldown = 1.6, range = 13, angle = 140, color = rgb(255, 120, 40),
	},
	FlambageShot = {
		name = "Blaze Shot", desc = "A flaming kick that launches a fireball.",
		fx = "shot", anim = "kick", fire = true,
		kind = "projectile", damage = 34, cooldown = 2.6, range = 50, radius = 7, color = rgb(255, 110, 30),
	},

	-- Ignis ---------------------------------------------------------------------------
	FireFist = {
		name = "Flame Fist", desc = "Launches a fireball that explodes.",
		fx = "shot", anim = "throw", fire = true,
		kind = "projectile", damage = 30, cooldown = 2.2, range = 60, radius = 7,
		color = rgb(255, 140, 30), evolveWith = "Area", evolvesInto = "FlameEmperor",
	},
	FireGun = {
		name = "Fire Bullets", desc = "Bullets of flame fly from his fingertips.",
		fx = "wave", anim = "throw",
		kind = "line", damage = 14, cooldown = 1.5, range = 40, width = 2, count = 3, color = rgb(255, 150, 50),
	},
	Firefly = {
		name = "Ember Swarm", desc = "Glowing fireflies circle you and burn enemies.",
		fx = "orbit",
		kind = "orbit", damage = 8, cooldown = 0.45, range = 8, count = 3, color = rgb(220, 255, 120),
	},
	FirePillar = {
		name = "Fire Pillar", desc = "Pillars of fire erupt under enemies.",
		fx = "strike", anim = "cast",
		kind = "clones", damage = 32, cooldown = 3, range = 7, count = 2, color = rgb(255, 90, 20),
	},
	FireFence = {
		name = "Flame Wall", desc = "A ring of flame bursts around you.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 16, cooldown = 2, range = 11, color = rgb(255, 140, 40),
	},
	CrossFire = {
		name = "Cross Flame", desc = "Blasts of flame forward and back.",
		fx = "slash", anim = "throw", arcs = 1,
		kind = "cone", damage = 26, cooldown = 2, range = 20, angle = 50, count = 2, color = rgb(255, 170, 60),
	},

	-- Flora -------------------------------------------------------------------------
	CienFleur = {
		name = "Hundred Hands", desc = "Arms sprout from the ground and crush enemies.",
		fx = "hands", anim = "cross",
		kind = "clones", damage = 22, cooldown = 3, range = 7, count = 2,
		color = rgb(200, 120, 255), evolveWith = "Haste", evolvesInto = "GigantescoMano",
	},
	SeisFleur = {
		name = "Grasping Hands", desc = "Arms grab enemy after enemy.",
		fx = "grab", anim = "cross",
		kind = "chain", damage = 22, cooldown = 2, range = 28, count = 4, color = rgb(200, 120, 255),
	},
	MilFleur = {
		name = "Thousand Hands", desc = "A field of arms sprouts all around you.",
		fx = "hands", anim = "cross",
		kind = "aura", damage = 18, cooldown = 2.4, range = 10, color = rgb(170, 90, 230),
	},
	FlowerStorm = {
		name = "Petal Storm", desc = "A storm of petals cuts through the swarm.",
		fx = "wave", anim = "cross",
		kind = "line", damage = 18, cooldown = 2, range = 35, width = 3, count = 2, color = rgb(255, 150, 210),
	},
	GiganteFleur = {
		name = "Giant Hand", desc = "A giant hand slams down on a crowd.",
		fx = "strike", anim = "cross",
		kind = "clones", damage = 50, cooldown = 4.4, range = 10, count = 1, color = rgb(160, 80, 220),
	},
	PetalGuard = {
		name = "Petal Guard", desc = "Petals swirl around you and slice anything close.",
		fx = "orbit",
		kind = "orbit", damage = 8, cooldown = 0.5, range = 7, count = 3, color = rgb(255, 160, 220),
	},

	-- Tuck -----------------------------------------------------------------------
	KungFuPoint = {
		name = "Martial Form", desc = "Fists circle you and hit enemies.",
		fx = "orbit",
		kind = "orbit", damage = 10, cooldown = 0.5, range = 7, count = 2,
		color = rgb(255, 150, 190), evolveWith = "Vitality", evolvesInto = "MonsterPoint",
	},
	HeavyGong = {
		name = "Heavy Punch", desc = "One huge, furry punch.",
		fx = "punch", anim = "punch", arm = rgb(150, 100, 60),
		kind = "line", damage = 36, cooldown = 3, range = 16, width = 4, count = 1, color = rgb(255, 130, 180),
	},
	HornPoint = {
		name = "Horn Charge", desc = "Charge with giant antlers.",
		fx = "slash", anim = "punch", arcs = 1,
		kind = "cone", damage = 20, cooldown = 1.5, range = 10, angle = 90, color = rgb(220, 170, 120),
	},
	RumbleBall = {
		name = "Power Pill", desc = "A burst of monster energy.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 12, cooldown = 2, range = 9, color = rgb(255, 150, 200),
	},
	CherryBlossom = {
		name = "Blossom Hoof", desc = "Hoof strikes that bloom from foe to foe.",
		fx = "lightning", anim = "punch",
		kind = "chain", damage = 18, cooldown = 1.8, range = 26, count = 4, color = rgb(255, 180, 220),
	},
	MedicineBomb = {
		name = "Medicine Bomb", desc = "Throws a medicine bomb that bursts.",
		fx = "shot", anim = "throw",
		kind = "projectile", damage = 28, cooldown = 2.4, range = 45, radius = 7, color = rgb(150, 255, 180),
	},

	-- Marine (starter class) -----------------------------------------------------------
	MarineRifle = {
		name = "Marine Rifle", desc = "A quick rifle shot through a line of enemies.",
		fx = "wave", anim = "throw",
		kind = "line", damage = 14, cooldown = 1.3, range = 40, width = 1.5, count = 1,
		color = rgb(230, 220, 160), evolveWith = "Power", evolvesInto = "JusticeVolley",
	},
	CutlassSlash = {
		name = "Cutlass Slash", desc = "A wide swing of a Marine cutlass.",
		fx = "slash", anim = "slash", arcs = 1,
		kind = "cone", damage = 18, cooldown = 1.5, range = 12, angle = 110, color = rgb(200, 210, 230),
	},
	Cannonball = {
		name = "Cannonball", desc = "Lobs a cannonball that explodes.",
		fx = "shot", anim = "throw", fire = true,
		kind = "projectile", damage = 26, cooldown = 2.6, range = 50, radius = 6, color = rgb(90, 90, 100),
	},
	Rankyaku = {
		name = "Air Kick", desc = "A kick that launches a cutting blade of air.",
		fx = "wave", anim = "kick",
		kind = "line", damage = 24, cooldown = 2.2, range = 40, width = 3, count = 1, color = rgb(200, 240, 255),
	},
	Shigan = {
		name = "Finger Strike", desc = "Lightning-fast finger strikes that hop between enemies.",
		fx = "lightning", anim = "punch",
		kind = "chain", damage = 16, cooldown = 1.8, range = 26, count = 3, color = rgb(240, 240, 255),
	},
	BusterCall = {
		name = "Cannon Salvo", desc = "Warship cannons shell the battlefield.",
		fx = "strike", anim = "cast",
		kind = "clones", damage = 34, cooldown = 4, range = 7, count = 2, color = rgb(70, 110, 200),
	},

	-- Pip ------------------------------------------------------------------------
	FireBirdStar = {
		name = "Firebird Shot", desc = "A flaming bird fired from a slingshot that explodes.",
		fx = "shot", anim = "throw", fire = true,
		kind = "projectile", damage = 26, cooldown = 2, range = 60, radius = 6,
		color = rgb(255, 120, 40), evolveWith = "Area", evolvesInto = "FirebirdBarrage",
	},
	LeadStar = {
		name = "Lead Shot", desc = "Rapid lead pellets fly straight and true.",
		fx = "wave", anim = "throw",
		kind = "line", damage = 14, cooldown = 1.3, range = 45, width = 1.5, count = 2, color = rgb(200, 200, 210),
	},
	ExplosiveStar = {
		name = "Bomb Shot", desc = "Gunpowder pellets blow up the crowd.",
		fx = "strike", anim = "throw",
		kind = "clones", damage = 30, cooldown = 3, range = 6, count = 2, color = rgb(255, 150, 40),
	},
	TabascoStar = {
		name = "Hot Sauce Shot", desc = "A burst of spicy sauce burns everyone nearby.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 12, cooldown = 1.8, range = 8, color = rgb(230, 40, 30),
	},
	PopGreen = {
		name = "Sprout Seeds", desc = "Monster plants burst out of the ground.",
		fx = "strike", anim = "throw",
		kind = "clones", damage = 34, cooldown = 3.4, range = 7, count = 2, color = rgb(80, 200, 70),
	},
	ImpactDial = {
		name = "Impact Shell", desc = "Releases a crushing blast straight ahead.",
		fx = "slash", anim = "punch", arcs = 1,
		kind = "cone", damage = 34, cooldown = 2.4, range = 9, angle = 100, color = rgb(240, 220, 180),
	},

	-- Bolt -----------------------------------------------------------------------
	CoupDeVent = {
		name = "Air Blast", desc = "A blast of compressed air from his arms.",
		fx = "wave", anim = "punch",
		kind = "line", damage = 30, cooldown = 2.2, range = 40, width = 4, count = 1,
		color = rgb(140, 220, 255), evolveWith = "Vitality", evolvesInto = "RadicalBeam",
	},
	WeaponsLeft = {
		name = "Arm Cannon", desc = "Fires a cannon shell from his left arm.",
		fx = "shot", anim = "punch",
		kind = "projectile", damage = 22, cooldown = 1.8, range = 50, radius = 5, color = rgb(120, 140, 170),
	},
	StrongRight = {
		name = "Rocket Punch", desc = "A rocket punch on a chain.",
		fx = "punch", anim = "punch", arm = rgb(90, 140, 200),
		kind = "line", damage = 34, cooldown = 2.6, range = 20, width = 4, count = 1, color = rgb(60, 110, 200),
	},
	FrankyFireball = {
		name = "Fire Breath", desc = "Breathes a cone of fire.",
		fx = "slash", anim = "cast", arcs = 2,
		kind = "cone", damage = 18, cooldown = 1.4, range = 12, angle = 70, color = rgb(255, 130, 40),
	},
	GeneralCannon = {
		name = "Mech Cannon", desc = "Shells rain down from a giant robot.",
		fx = "strike", anim = "cast",
		kind = "clones", damage = 36, cooldown = 3.4, range = 7, count = 2, color = rgb(70, 140, 230),
	},
	FrankyCenter = {
		name = "Super Shockwave", desc = "A super shockwave all around.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 14, cooldown = 2, range = 9, color = rgb(80, 200, 255),
	},

	-- Bones ------------------------------------------------------------------------
	YahazuGiri = {
		name = "Arrow Cut", desc = "A cane-sword cut faster than sound.",
		fx = "slash", anim = "slash", arcs = 1,
		kind = "cone", damage = 22, cooldown = 1.2, range = 16, angle = 60,
		color = rgb(180, 220, 255), evolveWith = "Haste", evolvesInto = "SoulRequiem",
	},
	FrostBite = {
		name = "Soul Chill", desc = "A freezing cut that leaps from foe to foe.",
		fx = "lightning", anim = "slash",
		kind = "chain", damage = 18, cooldown = 1.8, range = 26, count = 4, color = rgb(150, 220, 255),
	},
	AubadeCoup = {
		name = "Rapier Thrust", desc = "A thrust of air that pierces a line.",
		fx = "wave", anim = "slash",
		kind = "line", damage = 26, cooldown = 2, range = 40, width = 2, count = 1, color = rgb(210, 230, 255),
	},
	GhostParade = {
		name = "Ghost Parade", desc = "Ghostly souls circle you.",
		fx = "orbit",
		kind = "orbit", damage = 8, cooldown = 0.5, range = 8, count = 3, color = rgb(200, 220, 255),
	},
	SoulParade = {
		name = "Spirit Parade", desc = "A chilling wave of soul power.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 14, cooldown = 1.8, range = 10, color = rgb(140, 200, 255),
	},
	IceBurn = {
		name = "Frost Burn", desc = "Ice pillars freeze enemies in place.",
		fx = "strike", anim = "slash",
		kind = "clones", damage = 30, cooldown = 3, range = 6, count = 2, color = rgb(170, 230, 255),
	},

	-- Kai ------------------------------------------------------------------------
	FishmanKarate = {
		name = "Tide Karate", desc = "A punch that sends shockwaves through the water in the air.",
		fx = "punch", anim = "punch", arm = rgb(70, 120, 200),
		kind = "line", damage = 20, cooldown = 1.5, range = 25, width = 4, count = 1,
		color = rgb(240, 140, 40), evolveWith = "Power", evolvesInto = "VagabondDrill",
	},
	SharkBrick = {
		name = "Shark Fist", desc = "A sweeping strike in front.",
		fx = "slash", anim = "punch", arcs = 1,
		kind = "cone", damage = 24, cooldown = 1.7, range = 12, angle = 120, color = rgb(80, 140, 230),
	},
	WaterHeart = {
		name = "Water Pulse", desc = "Throws a heavy ball of water that bursts.",
		fx = "shot", anim = "throw",
		kind = "projectile", damage = 30, cooldown = 2.6, range = 50, radius = 8, color = rgb(70, 170, 255),
	},
	FiveThousandTiles = {
		name = "Tidal Fist", desc = "A punch that crashes down like a tidal wave.",
		fx = "strike", anim = "punch",
		kind = "clones", damage = 55, cooldown = 4.4, range = 9, count = 1, color = rgb(60, 120, 220),
	},
	SharkArrows = {
		name = "Water Arrows", desc = "Arrows of water shoot through the swarm.",
		fx = "wave", anim = "throw",
		kind = "line", damage = 14, cooldown = 1.6, range = 40, width = 2, count = 3, color = rgb(120, 200, 255),
	},
	OceanCurrent = {
		name = "Ocean Current", desc = "Spins the current around you to throw enemies.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 16, cooldown = 2, range = 10, color = rgb(60, 160, 230),
	},

	-- Rook --------------------------------------------------------------------------
	RoomAmputate = {
		name = "Room Slice", desc = "Slices everything inside a wide arc.",
		fx = "slash", anim = "slash", arcs = 1,
		kind = "cone", damage = 24, cooldown = 1.6, range = 18, angle = 140,
		color = rgb(100, 220, 255), evolveWith = "Haste", evolvesInto = "GammaKnife",
	},
	CounterShock = {
		name = "Shock Palm", desc = "An electric shock that jumps between enemies.",
		fx = "lightning", anim = "cast",
		kind = "chain", damage = 20, cooldown = 1.8, range = 28, count = 4, color = rgb(255, 240, 100),
	},
	Injection = {
		name = "Needle Thrust", desc = "A piercing lunge with a long blade.",
		fx = "wave", anim = "slash",
		kind = "line", damage = 30, cooldown = 2, range = 50, width = 1.5, count = 1, color = rgb(220, 240, 255),
	},
	Shambles = {
		name = "Swap Blast", desc = "Swaps the ground beneath enemies for a blast.",
		fx = "strike", anim = "cast",
		kind = "clones", damage = 32, cooldown = 3, range = 6, count = 2, color = rgb(80, 200, 255),
	},
	Mes = {
		name = "Heart Cubes", desc = "Floating cubes circle you and cut enemies.",
		fx = "orbit",
		kind = "orbit", damage = 10, cooldown = 0.5, range = 8, count = 2, color = rgb(120, 230, 255),
	},
	RoomDome = {
		name = "Operating Dome", desc = "A blue dome pulses around you.",
		fx = "nova", anim = "cast",
		kind = "aura", damage = 14, cooldown = 2.2, range = 12, color = rgb(90, 190, 255),
	},

	-- Serena ------------------------------------------------------------------
	PerfumeFemur = {
		name = "Charm Kick", desc = "A kick that turns enemies to stone.",
		fx = "slash", anim = "kick", arcs = 1,
		kind = "cone", damage = 22, cooldown = 1.4, range = 14, angle = 100,
		color = rgb(255, 120, 180), evolveWith = "Power", evolvesInto = "LoveParadise",
	},
	SlaveArrow = {
		name = "Love Arrow", desc = "Heart arrows pierce through the crowd.",
		fx = "wave", anim = "cast",
		kind = "line", damage = 16, cooldown = 1.6, range = 40, width = 2, count = 3, color = rgb(255, 110, 170),
	},
	PistolKiss = {
		name = "Kiss Shot", desc = "Blows a kiss that bursts on impact.",
		fx = "shot", anim = "throw",
		kind = "projectile", damage = 26, cooldown = 2, range = 50, radius = 5, color = rgb(255, 90, 150),
	},
	MeroMellow = {
		name = "Petrify Beam", desc = "A wave of love petrifies everyone close.",
		fx = "nova", anim = "cross",
		kind = "aura", damage = 14, cooldown = 1.8, range = 10, color = rgb(255, 140, 200),
	},
	Salome = {
		name = "Serpent Strike", desc = "Her giant snake crashes down.",
		fx = "strike", anim = "cross",
		kind = "clones", damage = 50, cooldown = 4, range = 9, count = 1, color = rgb(160, 90, 200),
	},
	LoveHearts = {
		name = "Heart Storm", desc = "Hearts orbit you and strike anything close.",
		fx = "orbit",
		kind = "orbit", damage = 8, cooldown = 0.5, range = 7, count = 3, color = rgb(255, 120, 190),
	},

	-- Evolutions (cannot be picked directly, always level 1) --------------------------
	JusticeVolley = {
		name = "Justice Volley", desc = "A whole Marine squad fires at once.",
		fx = "wave", anim = "throw",
		kind = "line", damage = 60, cooldown = 0.9, range = 55, width = 2.5, count = 8,
		color = rgb(255, 240, 170), evolved = true, from = "MarineRifle",
	},
	GumGumGatling = {
		name = "Rubber Gatling", desc = "A storm of rubber punches in every direction.",
		fx = "punch", anim = "punch",
		kind = "line", damage = 50, cooldown = 0.8, range = 45, width = 4, count = 10,
		color = rgb(255, 40, 40), evolved = true, from = "GumGumPistol",
	},
	NineSwordStyle = {
		name = "Nine Blade Phantom", desc = "Nine blades slash in every direction.",
		fx = "slash", anim = "slash", arcs = 3,
		kind = "cone", damage = 90, cooldown = 1, range = 22, angle = 120, count = 4,
		color = rgb(40, 200, 90), evolved = true, from = "ThreeSwordStyle",
	},
	ZeusTempo = {
		name = "Thunder God Storm", desc = "Lightning chains through the whole swarm.",
		fx = "lightning", anim = "cast", cloud = true,
		kind = "chain", damage = 70, cooldown = 0.9, range = 45, count = 10,
		color = rgb(255, 255, 160), evolved = true, from = "ThunderTempo",
	},
	IfritJambe = {
		name = "Inferno Leg", desc = "Blue-hot kicks scorch a huge area around you.",
		fx = "kick", anim = "kick", fire = true,
		kind = "aura", damage = 45, cooldown = 0.5, range = 14,
		color = rgb(80, 160, 255), evolved = true, from = "DiableJambe",
	},
	FlameEmperor = {
		name = "Sun Flare", desc = "Giant fireballs that wipe out crowds.",
		fx = "shot", anim = "throw", fire = true,
		kind = "projectile", damage = 160, cooldown = 1.8, range = 70, radius = 16, count = 3,
		color = rgb(255, 80, 0), evolved = true, from = "FireFist",
	},
	GigantescoMano = {
		name = "Colossal Hands", desc = "Giant arms smash the battlefield.",
		fx = "hands", anim = "cross",
		kind = "clones", damage = 80, cooldown = 2.2, range = 9, count = 8,
		color = rgb(170, 80, 255), evolved = true, from = "CienFleur",
	},
	MonsterPoint = {
		name = "Monster Form", desc = "A huge ring of fists shreds anything close.",
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
		name = "Super Beam", desc = "Huge beams blast everything in their path.",
		fx = "wave", anim = "punch",
		kind = "line", damage = 140, cooldown = 1.2, range = 60, width = 6, count = 3,
		color = rgb(90, 230, 255), evolved = true, from = "CoupDeVent",
	},
	SoulRequiem = {
		name = "Requiem of Souls", desc = "Icy cuts in every direction.",
		fx = "slash", anim = "slash", arcs = 2,
		kind = "cone", damage = 95, cooldown = 0.9, range = 22, angle = 100, count = 4,
		color = rgb(160, 230, 255), evolved = true, from = "YahazuGiri",
	},
	VagabondDrill = {
		name = "Tidal Drill", desc = "Spiraling water punches drill through the swarm.",
		fx = "punch", anim = "punch", arm = rgb(70, 120, 200),
		kind = "line", damage = 70, cooldown = 1, range = 40, width = 5, count = 6,
		color = rgb(40, 140, 255), evolved = true, from = "FishmanKarate",
	},
	GammaKnife = {
		name = "Gamma Blade", desc = "Destroys enemies from the inside, one after another.",
		fx = "lightning", anim = "slash",
		kind = "chain", damage = 75, cooldown = 0.9, range = 40, count = 8,
		color = rgb(120, 240, 255), evolved = true, from = "RoomAmputate",
	},
	LoveParadise = {
		name = "Heart Paradise", desc = "Petrifying kicks in every direction.",
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
	MarineRifle = "🔫", CutlassSlash = "🗡️", Cannonball = "💣", Rankyaku = "🌬️", Shigan = "👉", BusterCall = "⚓",
	JusticeVolley = "🎖️",
}
for key, w in Config.Weapons do
	w.icon = ICONS[key] or "✨"
end

-- `per` is added once per passive level to the named stat.
Config.Passives = {
	Power = { icon = "💪", name = "Fighting Spirit", desc = "+10% damage", stat = "damage", per = 0.10 },
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

-- Everyone starts as a Marine. Pirates are unlocked with gold in CREW (cost).
-- name = what players see (the table keys are internal ids used by saves).
Config.DEFAULT_CLASS = "Marine"
Config.Classes = {
	Marine = {
		name = "Marine", icon = "⚓", title = "Marine Recruit", perk = "+10 max HP", color = Color3.fromRGB(50, 90, 170),
		weapon = "MarineRifle", cost = 0,
		skills = { "MarineRifle", "CutlassSlash", "Cannonball", "Rankyaku", "Shigan", "BusterCall" },
		bonus = { health = 10 },
	},
	Luffy = {
		name = "Rocco", icon = "👒", title = "Rubber Captain", perk = "+30 max HP", color = Color3.fromRGB(220, 50, 50),
		weapon = "GumGumPistol", cost = 150000,
		skills = { "GumGumPistol", "GumGumBazooka", "GumGumWhip", "GumGumBalloon", "GumGumElephantGun", "RedHawk" },
		bonus = { health = 30 },
	},
	Zoro = {
		name = "Kenji", icon = "⚔️", title = "Three-Blade Hunter", perk = "+10% damage", color = Color3.fromRGB(60, 190, 90),
		weapon = "ThreeSwordStyle", cost = 12000,
		skills = { "ThreeSwordStyle", "PoundCannon", "OniGiri", "Tatsumaki", "ShishiSonson", "BlackRopeDragon" },
		bonus = { damage = 0.10 },
	},
	Nami = {
		name = "Skye", icon = "🍊", title = "Storm Navigator", perk = "+25% gold", color = Color3.fromRGB(255, 150, 40),
		weapon = "ThunderTempo", cost = 6000,
		skills = { "ThunderTempo", "CycloneTempo", "MirageTempo", "ThunderLance", "WeatherEgg", "BlackBall" },
		bonus = { gold = 0.25 },
	},
	Sanji = {
		name = "Blaze", icon = "🦵", title = "Flame-Kick Chef", perk = "+15% move speed", color = Color3.fromRGB(240, 200, 60),
		weapon = "DiableJambe", cost = 12000,
		skills = { "DiableJambe", "Crushing Heel", "PartyTable", "MoutonShot", "PoeleAFrire", "FlambageShot" },
		bonus = { speed = 0.15 },
	},
	Ace = {
		name = "Ignis", icon = "🔥", title = "Fire Commander", perk = "+15% area", color = Color3.fromRGB(255, 100, 30),
		weapon = "FireFist", cost = 60000,
		skills = { "FireFist", "FireGun", "Ember Swarm", "FirePillar", "FireFence", "CrossFire" },
		bonus = { area = 0.15 },
	},
	Robin = {
		name = "Flora", icon = "🌸", title = "Thousand-Hand Scholar", perk = "-10% cooldowns", color = Color3.fromRGB(150, 90, 220),
		weapon = "CienFleur", cost = 18000,
		skills = { "CienFleur", "SeisFleur", "MilFleur", "FlowerStorm", "GiganteFleur", "PetalGuard" },
		bonus = { cooldown = 0.10 },
	},
	Chopper = {
		name = "Tuck", icon = "🦌", title = "Reindeer Doctor", perk = "Heals nearby allies", color = Color3.fromRGB(255, 130, 180),
		weapon = "KungFuPoint", cost = 8000,
		skills = { "KungFuPoint", "HeavyGong", "HornPoint", "RumbleBall", "CherryBlossom", "MedicineBomb" },
		bonus = { heal = 2 },
	},
	Usopp = {
		name = "Pip", icon = "🎯", title = "King of Slingshots", perk = "+1 reroll each run", color = Color3.fromRGB(200, 160, 70),
		weapon = "FireBirdStar", cost = 4000,
		skills = { "FireBirdStar", "LeadStar", "ExplosiveStar", "TabascoStar", "PopGreen", "ImpactDial" },
		bonus = { reroll = 1 },
	},
	Franky = {
		name = "Bolt", icon = "🤖", title = "Cyborg Shipwright", perk = "+8% damage, +20 max HP", color = Color3.fromRGB(70, 170, 240),
		weapon = "CoupDeVent", cost = 25000,
		skills = { "CoupDeVent", "WeaponsLeft", "StrongRight", "FrankyFireball", "GeneralCannon", "FrankyCenter" },
		bonus = { damage = 0.08, health = 20 },
	},
	Brook = {
		name = "Bones", icon = "💀", title = "Skeleton Musician", perk = "+30% pickup range", color = Color3.fromRGB(150, 130, 200),
		weapon = "YahazuGiri", cost = 30000,
		skills = { "YahazuGiri", "FrostBite", "AubadeCoup", "GhostParade", "SoulParade", "IceBurn" },
		bonus = { magnet = 0.3 },
	},
	Jinbe = {
		name = "Kai", icon = "🦈", title = "Tide Master", perk = "+50 max HP", color = Color3.fromRGB(60, 120, 210),
		weapon = "FishmanKarate", cost = 40000,
		skills = { "FishmanKarate", "SharkBrick", "WaterHeart", "FiveThousandTiles", "SharkArrows", "OceanCurrent" },
		bonus = { health = 50 },
	},
	Law = {
		name = "Rook", icon = "🩺", title = "Room Surgeon", perk = "-8% cooldowns, +8% area", color = Color3.fromRGB(240, 210, 80),
		weapon = "RoomAmputate", cost = 80000,
		skills = { "RoomAmputate", "CounterShock", "Injection", "Swap Blast", "Mes", "RoomDome" },
		bonus = { cooldown = 0.08, area = 0.08 },
	},
	Hancock = {
		name = "Serena", icon = "🐍", title = "Snake Empress", perk = "+15% damage", color = Color3.fromRGB(240, 90, 150),
		weapon = "PerfumeFemur", cost = 100000,
		skills = { "PerfumeFemur", "SlaveArrow", "PistolKiss", "MeroMellow", "Salome", "LoveHearts" },
		bonus = { damage = 0.15 },
	},
}
-- Cheapest first, so CREW reads as a path from Marine recruit to rubber captain.
Config.CLASS_ORDER = {
	"Marine", "Usopp", "Nami", "Chopper", "Zoro", "Sanji", "Robin", "Franky", "Brook", "Jinbe", "Ace", "Law", "Hancock", "Luffy",
}

-- Which character each skill belongs to (filled in from the skill lists above).
Config.SkillOwner = {}
for className, class in Config.Classes do
	for _, skill in class.skills do
		Config.SkillOwner[skill] = className
	end
end

-- color = clothes, accent = trousers and collar, skin = head and hands, eyes = glowing eye color
-- hat: cap | officer | beret | medic | bear | tophat | fin | clown. gear: what they carry
-- (sword | rifle | longrifle | cannon | coat | bomb | net). ai: how they move and fight:
--   melee (walk up and hit), ranged (keep distance and shoot), artillery (shell an area),
--   support (stay back), boss (melee plus telegraphed slams; the final boss also calls down a
--   ring of strikes). keepAway = stop at 80% of range.
-- skills = { name = cooldown } (see server/Enemies.lua):
--   dash (lunging slash), laser (Iron Sentinel beam), snipe (long aimed shot), heal (heals nearby
--   Marines), bomb (runs up and explodes), net (slows you), blink (shadow-step next to you),
--   rankyaku (flying air blade), call (summons recruits)
local SKIN = Color3.fromRGB(255, 205, 160)
local WHITE = Color3.fromRGB(240, 240, 245)
local NAVY = Color3.fromRGB(35, 60, 130)
Config.Enemies = {
	Grunt = { name = "Marine Recruit", hp = 20, speed = 11, damage = 6, xp = 1, scale = 1, color = WHITE, accent = NAVY, skin = SKIN, hat = "cap" },
	Swordsman = {
		name = "Marine Swordsman", hp = 34, speed = 13, damage = 9, xp = 2, scale = 1.05,
		color = WHITE, accent = Color3.fromRGB(25, 45, 110), skin = SKIN, gear = "sword", hat = "cap",
		skills = { dash = 6 },
	},
	Rifleman = {
		name = "Marine Rifleman", hp = 18, speed = 10, damage = 7, xp = 2, scale = 1,
		color = WHITE, accent = Color3.fromRGB(50, 90, 60), skin = SKIN, gear = "rifle", hat = "cap",
		ai = "ranged", keepAway = true, range = 32, fireRate = 2.6,
	},
	Runner = {
		name = "Shark Raider", hp = 12, speed = 15, damage = 4, xp = 1, scale = 0.85,
		color = Color3.fromRGB(230, 120, 50), accent = Color3.fromRGB(30, 50, 90), skin = Color3.fromRGB(70, 150, 210), hat = "fin",
	},
	Bomber = {
		name = "Bomb Clown", hp = 14, speed = 16, damage = 24, xp = 2, scale = 0.95,
		color = Color3.fromRGB(235, 70, 70), accent = Color3.fromRGB(60, 90, 200), skin = Color3.fromRGB(250, 240, 235),
		gear = "bomb", hat = "clown", skills = { bomb = 0 }, blast = 7,
	},
	Medic = {
		name = "Marine Medic", hp = 30, speed = 10, damage = 4, xp = 3, scale = 1,
		color = WHITE, accent = Color3.fromRGB(200, 40, 50), skin = SKIN, hat = "medic",
		ai = "support", keepAway = true, range = 26, skills = { heal = 5 }, healRadius = 22, heal = 0.25,
	},
	Netter = {
		name = "Chain Netter", hp = 26, speed = 10, damage = 4, xp = 3, scale = 1.05,
		color = WHITE, accent = Color3.fromRGB(70, 60, 50), skin = SKIN, gear = "net", hat = "cap",
		ai = "support", keepAway = true, range = 30, skills = { net = 4.5 }, slow = 0.5, slowTime = 2,
	},
	Cannoneer = {
		name = "Marine Cannoneer", hp = 60, speed = 7, damage = 16, xp = 4, scale = 1.25,
		color = Color3.fromRGB(200, 205, 215), accent = Color3.fromRGB(60, 60, 70), skin = SKIN, gear = "cannon", hat = "cap",
		ai = "artillery", keepAway = true, range = 45, fireRate = 5, blast = 6,
	},
	Sniper = {
		name = "Marine Sniper", hp = 16, speed = 9, damage = 20, xp = 3, scale = 1,
		color = Color3.fromRGB(80, 105, 65), accent = Color3.fromRGB(45, 60, 40), skin = SKIN, gear = "longrifle", hat = "beret",
		ai = "support", keepAway = true, range = 62, skills = { snipe = 5 },
	},
	Brute = {
		name = "Iron Sentinel", hp = 110, speed = 8, damage = 14, xp = 6, scale = 1.7,
		color = Color3.fromRGB(55, 55, 65), accent = Color3.fromRGB(30, 30, 35), skin = Color3.fromRGB(200, 170, 140),
		eyes = Color3.fromRGB(255, 220, 60), hat = "bear", skills = { laser = 7 }, range = 46,
	},
	Captain = {
		name = "Marine Captain", hp = 220, speed = 11, damage = 16, xp = 10, scale = 1.4,
		color = Color3.fromRGB(250, 250, 250), accent = Color3.fromRGB(20, 35, 90), skin = SKIN, gear = "coat", hat = "officer",
		skills = { call = 14 },
	},
	Agent = {
		name = "Shadow Agent", hp = 140, speed = 17, damage = 14, xp = 8, scale = 1.1,
		color = Color3.fromRGB(25, 25, 30), accent = Color3.fromRGB(15, 15, 20), skin = SKIN, hat = "tophat",
		range = 34, skills = { blink = 6, rankyaku = 4 },
	},
	MiniBoss = {
		name = "Vice Admiral", hp = 1200, speed = 10, damage = 22, xp = 40, gold = 25, scale = 3, healthBar = true,
		color = Color3.fromRGB(250, 250, 250), accent = Color3.fromRGB(35, 35, 60), skin = SKIN, gear = "coat", hat = "officer",
		ai = "boss", slamEvery = 6, blast = 8, range = 40, skills = { call = 16 },
	},
	Boss = {
		name = "Admiral", hp = 15000, speed = 12, damage = 40, xp = 0, gold = 300, scale = 5, healthBar = true,
		color = Color3.fromRGB(250, 250, 250), accent = Color3.fromRGB(150, 20, 30), skin = SKIN, gear = "coat", hat = "officer",
		eyes = Color3.fromRGB(255, 80, 40), ai = "boss", slamEvery = 5, ringEvery = 12, blast = 9, range = 60, skills = { laser = 9 },
	},
}

-- Which enemies show up: { kind, from map #, from minute, weight }. Later maps bring tougher Marines.
Config.SPAWN_TABLE = {
	{ "Grunt", 1, 0, 10 },
	{ "Swordsman", 1, 1, 4 },
	{ "Rifleman", 1, 1.5, 2.5 },
	{ "Runner", 2, 1, 3 },
	{ "Bomber", 2, 1.5, 2 },
	{ "Medic", 3, 2, 1.2 },
	{ "Brute", 4, 3, 1.5 },
	{ "Netter", 5, 2, 1.5 },
	{ "Cannoneer", 6, 2, 1.5 },
	{ "Sniper", 7, 2.5, 1.2 },
	{ "Captain", 8, 3, 1 },
	{ "Agent", 12, 2, 1.5 },
}

-- Wave events: a squad that arrives all at once at the start of a wave.
-- kind = who comes (nil = the map's usual mix), count grows with the wave number and crew size,
-- shape = pack (one big group from one side), ring (all around you) or line (a firing line).
-- fromWave / fromMap: the first wave number and map where the event can happen.
Config.WAVE_EVENTS = {
	{ title = "HORDE!", sub = "A mob of recruits charges in", kind = "Grunt", count = 14, shape = "pack", fromWave = 1, fromMap = 1, weight = 3, color = rgb(255, 200, 70) },
	{ title = "SURROUNDED!", sub = "They're closing in - break out!", count = 16, shape = "ring", fromWave = 2, fromMap = 1, weight = 3, color = rgb(255, 120, 60) },
	{ title = "FIRING SQUAD", sub = "Riflemen take aim - keep moving!", kind = "Rifleman", count = 7, shape = "line", fromWave = 2, fromMap = 1, weight = 2, color = rgb(120, 200, 255) },
	{ title = "BOMB CLOWNS", sub = "Don't let them reach you!", kind = "Bomber", count = 7, shape = "pack", fromWave = 3, fromMap = 1, weight = 2, color = rgb(255, 80, 80) },
	{ title = "SWORD SQUAD", sub = "Swordsmen lunge at you", kind = "Swordsman", count = 8, shape = "ring", fromWave = 4, fromMap = 1, weight = 1.5, color = rgb(200, 220, 255) },
	{ title = "SNIPER NEST", sub = "Step out of the red lines!", kind = "Sniper", count = 4, shape = "line", fromWave = 4, fromMap = 2, weight = 1.5, color = rgb(120, 230, 120) },
	{ title = "SENTINEL SQUAD", sub = "Dodge their lasers!", kind = "Brute", count = 3, shape = "pack", fromWave = 5, fromMap = 3, weight = 1.5, color = rgb(255, 220, 60) },
	{ title = "CHAIN NETS", sub = "Nets slow you down", kind = "Netter", count = 5, shape = "line", fromWave = 5, fromMap = 4, weight = 1.2, color = rgb(160, 140, 110) },
	{ title = "SHADOW RUSH", sub = "Assassins blink right next to you", kind = "Agent", count = 3, shape = "ring", fromWave = 6, fromMap = 6, weight = 1.2, color = rgb(190, 120, 255) },
}

-- Permanent upgrades bought with gold between runs. Cost = cost * (growth or META_GROWTH) ^ level.
Config.Meta = {
	SkillSlot = {
		icon = "🧩", name = "Skill Slot", desc = "+1 skill slot", stat = "slots", per = 1, max = 5, cost = 2000, growth = 2,
	},
	Might = { icon = "⚔️", name = "Might", desc = "+5% damage", stat = "damage", per = 0.05, max = 10, cost = 400, growth = 1.6 },
	Toughness = { icon = "❤️", name = "Toughness", desc = "+10 max HP", stat = "health", per = 10, max = 10, cost = 400, growth = 1.6 },
	Greed = { icon = "💰", name = "Greed", desc = "+10% gold", stat = "gold", per = 0.10, max = 10, cost = 600, growth = 1.7 },
	Reach = { icon = "🧲", name = "Reach", desc = "+10% pickup range", stat = "magnet", per = 0.10, max = 5, cost = 500, growth = 1.6 },
	Reroll = { icon = "🎲", name = "Reroll", desc = "+1 reroll per run", stat = "reroll", per = 1, max = 5, cost = 1500, growth = 1.9 },
}
Config.META_ORDER = { "SkillSlot", "Might", "Toughness", "Greed", "Reach", "Reroll" }
Config.META_GROWTH = 1.5

-- Dash: Shift on keyboard, L2 on a gamepad, an on-screen button on phones.
Config.DASH = { cooldown = 2.5, speed = 85, duration = 0.18, invulnerable = 0.35 }
Config.LEVELUP_SHIELD = 2.5 -- seconds of safety while level-up cards are open
Config.BOSS_TIME_LIMIT = 240 -- the final boss must fall in time, or the Marines win
Config.BOSS_ENRAGE_AT = 180 -- ...and hits much harder after this long

-- Island NPCs (built by server/Npcs.lua). Their prompt opens a menu (panel / tab).
-- Keep positions clear of the island props in tools/build_place.py.
-- look: the outfit built in server/Npcs.lua. style: their idle animation (client/Rigs.lua).
Config.NPCS = {
	{ name = "Old Captain Grey", role = "Skill Trainer", icon = "⚔️", panel = "train", tab = "skills", look = "Rayleigh", style = "swordsman",
		line = "Willpower beats everything. Show me your skills!", position = Vector3.new(-28, 0, 1414), color = Color3.fromRGB(235, 235, 240), accent = Color3.fromRGB(70, 70, 80) },
	{ name = "Granny Doc", role = "Passive Trainer", icon = "💊", panel = "train", tab = "passives", look = "Kureha", style = "sip",
		line = "Heh-heh! One spoonful of my medicine and you'll feel twenty again!", position = Vector3.new(-30, 0, 1386), color = Color3.fromRGB(150, 80, 160), accent = Color3.fromRGB(235, 235, 245) },
	{ name = "Hammond the Shipwright", role = "Gear Smith", icon = "🔨", panel = "gear", look = "Tom", style = "hammer",
		line = "Every ship and every blade, built with pride! Ha-ha!", position = Vector3.new(30, 0, 1384), color = Color3.fromRGB(60, 110, 160), accent = Color3.fromRGB(240, 200, 60) },
	{ name = "Madam Roxie", role = "Upgrades", icon = "🍸", panel = "shop", look = "Shakky", style = "smoke",
		line = "Welcome to my bar, sweetie. Upgrades aren't free, you know.", position = Vector3.new(36, 0, 1406), color = Color3.fromRGB(40, 40, 50), accent = Color3.fromRGB(200, 60, 90) },
	{ name = "Bingo the Clown", role = "Robux Store", icon = "💎", panel = "store", look = "Buggy", style = "laugh",
		line = "Ha-ha-haa! Treasure for flashy pirates!", position = Vector3.new(0, 0, 1370), color = Color3.fromRGB(220, 60, 60), accent = Color3.fromRGB(60, 130, 230) },
	{ name = "The Sea Sage", role = "Rebirth", icon = "⭐", panel = "rebirth", look = "Sage", style = "pray",
		line = "To be reborn, you must let go of everything... and return stronger.", position = Vector3.new(-60, 0, 1450), color = Color3.fromRGB(240, 150, 40), accent = Color3.fromRGB(250, 220, 120) },
}

-- Island training, paid with gold and kept forever. Captain Grey trains skills, Granny Doc passives.
Config.MASTERY = { max = 10, damage = 0.06, cooldown = 0.02, cost = 600, growth = 1.6 }
Config.TRAINING = { max = 5, boost = 0.15, cost = 1000, growth = 1.8 }

function Config.trainCost(kind, level)
	local t = kind == "skill" and Config.MASTERY or Config.TRAINING
	return math.floor(t.cost * t.growth ^ level)
end

-- Gear: one item per slot. Buy with gold from Hammond, or win Mythic/other drops from bosses.
-- bonus uses the same stat names as passives (damage, cooldown, health, crit, xp, gold, ...).
Config.RARITIES = {
	Common = Color3.fromRGB(170, 175, 190), Rare = Color3.fromRGB(80, 160, 255), Epic = Color3.fromRGB(180, 100, 255),
	Legendary = Color3.fromRGB(255, 190, 50), Mythic = Color3.fromRGB(255, 70, 90),
}
Config.GEAR_SLOTS = { "weapon", "outfit", "charm" }
Config.GEAR_SLOT_NAMES = { weapon = "Weapon", outfit = "Outfit", charm = "Charm" }
Config.GEAR_SLOT_ICONS = { weapon = "🗡️", outfit = "🧥", charm = "🧿" }
Config.GEAR_ITEMS = {
	{ id = "RustyCutlass", slot = "weapon", name = "Rusty Cutlass", icon = "🗡️", rarity = "Common", cost = 1500, bonus = { damage = 0.05 } },
	{ id = "MarineSaber", slot = "weapon", name = "Marine Saber", icon = "⚔️", rarity = "Rare", cost = 7500, bonus = { damage = 0.10, crit = 0.03 } },
	{ id = "Kabuto", slot = "weapon", name = "Slingshot Staff", icon = "🎯", rarity = "Epic", cost = 25000, bonus = { area = 0.12, cooldown = 0.06 } },
	{ id = "WadoIchimonji", slot = "weapon", name = "White Wind Katana", icon = "🗡️", rarity = "Epic", cost = 25000, bonus = { damage = 0.15, crit = 0.05 } },
	{ id = "Shusui", slot = "weapon", name = "Black Autumn Blade", icon = "⚔️", rarity = "Legendary", cost = 90000, bonus = { damage = 0.22, critDamage = 0.30 } },
	{ id = "Enma", slot = "weapon", name = "Abyss Blade", icon = "🔥", rarity = "Mythic", cost = 0, bonus = { damage = 0.30, crit = 0.08, critDamage = 0.40 } },
	{ id = "SailorShirt", slot = "outfit", name = "Sailor Shirt", icon = "👕", rarity = "Common", cost = 1500, bonus = { health = 20 } },
	{ id = "MarineCoat", slot = "outfit", name = "Marine Coat", icon = "🧥", rarity = "Rare", cost = 7500, bonus = { health = 40, defense = 0.04 } },
	{ id = "FrankySpeedo", slot = "outfit", name = "Speedy Trunks", icon = "🩳", rarity = "Epic", cost = 25000, bonus = { speed = 0.10, regen = 1 } },
	{ id = "JinbeKimono", slot = "outfit", name = "Helmsman's Kimono", icon = "👘", rarity = "Epic", cost = 25000, bonus = { health = 60, defense = 0.08 } },
	{ id = "SeastoneArmor", slot = "outfit", name = "Anchorstone Armor", icon = "🛡️", rarity = "Legendary", cost = 90000, bonus = { health = 100, defense = 0.12 } },
	{ id = "EmperorCloak", slot = "outfit", name = "Emperor's Cloak", icon = "👑", rarity = "Mythic", cost = 0, bonus = { health = 150, defense = 0.15, regen = 2 } },
	{ id = "LuckyCoin", slot = "charm", name = "Lucky Coin", icon = "🪙", rarity = "Common", cost = 1500, bonus = { gold = 0.10 } },
	{ id = "LogPose", slot = "charm", name = "Island Compass", icon = "🧭", rarity = "Rare", cost = 7500, bonus = { magnet = 0.30, xp = 0.10 } },
	{ id = "DenDenMushi", slot = "charm", name = "Snail Phone", icon = "🐌", rarity = "Epic", cost = 25000, bonus = { cooldown = 0.08, area = 0.08 } },
	{ id = "EternalPose", slot = "charm", name = "Eternal Compass", icon = "📍", rarity = "Epic", cost = 25000, bonus = { xp = 0.20, cooldown = 0.05 } },
	{ id = "TreasureMap", slot = "charm", name = "Treasure Map", icon = "🗺️", rarity = "Legendary", cost = 90000, bonus = { gold = 0.30, magnet = 0.40 } },
	{ id = "DevilFruit", slot = "charm", name = "Mystic Fruit", icon = "🍇", rarity = "Mythic", cost = 0, bonus = { damage = 0.15, cooldown = 0.10, xp = 0.25 } },
}
Config.GearById = {}
for _, item in Config.GEAR_ITEMS do
	Config.GearById[item.id] = item
end

-- Free gear drops on victory: chance per difficulty and how rare the drop tends to be.
-- Owning the item already turns the drop into gold.
Config.DROPS = {
	{ chance = 0.3, weights = { Common = 70, Rare = 25, Epic = 5 } },
	{ chance = 0.35, weights = { Common = 45, Rare = 40, Epic = 14, Legendary = 1 } },
	{ chance = 0.4, weights = { Common = 25, Rare = 45, Epic = 25, Legendary = 5 } },
	{ chance = 0.5, weights = { Rare = 40, Epic = 40, Legendary = 17, Mythic = 3 } },
	{ chance = 0.6, weights = { Epic = 50, Legendary = 38, Mythic = 12 } },
}
-- Getting gear you already own gives a spare copy, used to upgrade it (gold once you have
-- enough copies to reach +10).
Config.DUPLICATE_GOLD = { Common = 500, Rare = 2000, Epic = 6000, Legendary = 15000, Mythic = 30000 }

-- Gear upgrades at Hammond's: each level costs one duplicate copy of the item plus gold, and adds
-- 10% of the item's base stats (+10 doubles them).
Config.GEAR_UPGRADE = {
	max = 10, per = 0.10, growth = 1.55,
	cost = { Common = 400, Rare = 1200, Epic = 3500, Legendary = 9000, Mythic = 20000 },
}
function Config.gearUpgradeCost(item, level)
	return math.floor(Config.GEAR_UPGRADE.cost[item.rarity] * Config.GEAR_UPGRADE.growth ^ level)
end
-- An item's stats at an upgrade level.
function Config.gearStats(item, level)
	local scale = 1 + Config.GEAR_UPGRADE.per * (level or 0)
	local stats = {}
	for stat, value in item.bonus do
		stats[stat] = stat == "health" and math.floor(value * scale) or value * scale
	end
	return stats
end

-- Treasure chests dropped during adventures: chance per enemy kind. Opening one gives every
-- crew member a gear roll (rarity follows the difficulty, see Config.DROPS).
Config.CHESTS = { MiniBoss = 1, Captain = 0.04, Agent = 0.04, Brute = 0.03 }

-- How each stat reads in menus, e.g. "+10% damage".
local STAT_TEXT = {
	damage = "+%d%% damage", cooldown = "-%d%% cooldowns", area = "+%d%% area", speed = "+%d%% speed",
	magnet = "+%d%% pickup range", gold = "+%d%% gold", crit = "+%d%% crit chance", critDamage = "+%d%% crit damage",
	defense = "-%d%% damage taken", xp = "+%d%% XP",
}
function Config.describeBonus(bonus)
	local parts = {}
	for _, stat in { "damage", "crit", "critDamage", "cooldown", "area", "health", "defense", "regen", "speed", "magnet", "xp", "gold" } do
		local value = bonus[stat]
		if value then
			if stat == "health" then
				table.insert(parts, "+" .. value .. " max HP")
			elseif stat == "regen" then
				table.insert(parts, "+" .. value .. " HP/s")
			else
				table.insert(parts, string.format(STAT_TEXT[stat], math.floor(value * 100 + 0.5)))
			end
		end
	end
	return table.concat(parts, ", ")
end

-- Robux purchases. Create these on the Roblox Creator Dashboard (your experience > Monetization)
-- and paste their IDs here. Anything left at id = 0 shows as "not set up" and can't be bought.
-- Prices are set on the dashboard. Suggested: 2x Gold 299, VIP 399, Lucky Pirate 149,
-- Swift Dash 99; gold packs 49 / 199 / 649; boosts 79 each; Revive 25.
Config.GAME_PASSES = {
	DoubleGold = { id = 0, icon = "💰", name = "2x Gold", desc = "Double gold from every adventure, forever." },
	VIP = { id = 0, icon = "👑", name = "VIP", desc = "+25% XP, +10% damage and a VIP tag.", bonus = { xp = 0.25, damage = 0.10 } },
	LuckyPirate = { id = 0, icon = "🎲", name = "Lucky Pirate", desc = "+2 rerolls in every run.", bonus = { reroll = 2 } },
	SwiftDash = { id = 0, icon = "💨", name = "Swift Dash", desc = "Dash 40% more often." },
}
Config.PASS_ORDER = { "DoubleGold", "VIP", "LuckyPirate", "SwiftDash" }
Config.SWIFT_DASH = 0.6 -- dash cooldown multiplier with Swift Dash
Config.PRODUCTS = {
	Gold5k = { id = 0, icon = "💰", name = "5,000 Gold", desc = "A pouch of gold.", gold = 5000 },
	Gold25k = { id = 0, icon = "💰", name = "25,000 Gold", desc = "A chest of gold.", gold = 25000 },
	Gold100k = { id = 0, icon = "💎", name = "100,000 Gold", desc = "A pirate king's treasure.", gold = 100000 },
	XPBoost = { id = 0, icon = "⚡", name = "2x XP Boost", desc = "Double XP for 30 minutes.", boost = "xp", minutes = 30 },
	GoldBoost = { id = 0, icon = "🪙", name = "2x Gold Boost", desc = "Double gold for 30 minutes.", boost = "gold", minutes = 30 },
	Revive = { id = 0, icon = "💖", name = "Revive", desc = "Get back up with full HP when knocked out.", revive = true },
}
Config.PRODUCT_ORDER = { "Gold5k", "Gold25k", "Gold100k", "XPBoost", "GoldBoost", "Revive" }

-- Sounds and music ---------------------------------------------------------------------------
-- Built-in Roblox sounds (rbxasset://) work right away. Swap any id for an audio asset from the
-- Creator Store ("rbxassetid://123456") to change it; an empty id is silent. Music is empty until
-- you pick tracks: Creator Store > Audio > Music, copy a track's ID into Config.MUSIC.
-- pitch = random playback speed range; gap = the shortest time between two plays.
Config.SOUNDS = {
	Hit = { id = "rbxasset://sounds/swordslash.wav", volume = 0.12, pitch = { 1.5, 1.9 }, gap = 0.07 },
	Slash = { id = "rbxasset://sounds/swordslash.wav", volume = 0.3, pitch = { 0.9, 1.1 }, gap = 0.08 },
	Punch = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.3, pitch = { 0.7, 0.9 }, gap = 0.08 },
	Shot = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.18, pitch = { 1.6, 2 }, gap = 0.08 },
	Boom = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.35, pitch = { 0.5, 0.7 }, gap = 0.1 },
	Zap = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, pitch = { 0.5, 0.6 }, gap = 0.1 },
	Burst = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.25, pitch = { 0.8, 1 }, gap = 0.1 },
	Laser = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.5, pitch = { 0.45, 0.55 }, gap = 0.15 },
	EnemyShot = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.12, pitch = { 2.2, 2.6 }, gap = 0.1 },
	Heal = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.2, pitch = { 1.4, 1.5 }, gap = 0.3 },
	Dash = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.35, pitch = { 1.2, 1.4 }, gap = 0.1 },
	Chest = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = { 1.2, 1.2 } },
	Pickup = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = { 1.6, 1.6 } },
	LevelUp = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = { 1, 1 } },
	Wave = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = { 0.4, 0.4 } },
	Boss = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.7, pitch = { 0.35, 0.35 } },
	Down = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.5 },
	Click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.45, gap = 0.03 },
	Coins = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = { 1.8, 1.8 } },
	Victory = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = { 0.8, 0.8 } },
}
Config.MUSIC = { Lobby = "", Battle = "", Boss = "" } -- e.g. Battle = "rbxassetid://1234567"

-- Daily rewards and quests -------------------------------------------------------------------

-- Log in on consecutive days for bigger rewards (day 7 repeats; missing a day starts over).
Config.DAILY_REWARDS = {
	{ gold = 500 }, { gold = 800 }, { gold = 1200 }, { gold = 1600 }, { gold = 2200 }, { gold = 3000 }, { gold = 5000, revives = 1 },
}
-- Three quests are picked each day (UTC). stat = what counts; max = best in one run instead of a total.
Config.QUESTS = {
	{ id = "kill400", text = "Defeat 400 Marines", stat = "kills", goal = 400, gold = 1000 },
	{ id = "kill1500", text = "Defeat 1,500 Marines", stat = "kills", goal = 1500, gold = 2500 },
	{ id = "win1", text = "Win an adventure", stat = "wins", goal = 1, gold = 1200 },
	{ id = "win3", text = "Win 3 adventures", stat = "wins", goal = 3, gold = 3000 },
	{ id = "wave8", text = "Reach wave 8", stat = "wave", goal = 8, gold = 1200, max = true },
	{ id = "level15", text = "Reach level 15 in one run", stat = "level", goal = 15, gold = 1000, max = true },
	{ id = "mini3", text = "Defeat 3 Vice Admirals", stat = "minibosses", goal = 3, gold = 1500 },
	{ id = "chest2", text = "Open 2 treasure chests", stat = "chests", goal = 2, gold = 1200 },
	{ id = "boss1", text = "Defeat a named boss", stat = "bosses", goal = 1, gold = 1500 },
	{ id = "pickup5", text = "Grab 5 pickups (meat, magnets, bombs)", stat = "pickups", goal = 5, gold = 1000 },
	{ id = "revive1", text = "Revive a crewmate", stat = "revives", goal = 1, gold = 1500 },
}
Config.QUESTS_PER_DAY = 3

-- Codes players can redeem once each (REWARDS menu). Add new ones for updates and your socials.
Config.CODES = {
	SETSAIL = { gold = 1000 },
	TREASURE = { gold = 2000 },
	HIGHSEAS = { gold = 1500, revives = 1 },
}

-- First clear of a map + difficulty pays a bonus: (base + perMap * (map # - 1)) * difficulty #.
Config.FIRST_CLEAR = { base = 500, perMap = 150 }

-- Badges: create them on the Creator Dashboard (your experience > Engagement > Badges) and paste
-- the IDs here. id = 0 means not set up yet (skipped).
Config.BADGES = {
	Welcome = { id = 0, name = "Welcome Aboard" }, -- first visit
	FirstVictory = { id = 0, name = "First Victory" },
	FirstPirate = { id = 0, name = "First Recruit" }, -- unlock a pirate
	FullCrew = { id = 0, name = "Full Crew" }, -- unlock every pirate
	Kills1000 = { id = 0, name = "1,000 Marines Down" },
	Kills10000 = { id = 0, name = "10,000 Marines Down" },
	Extreme = { id = 0, name = "Extreme Clear" }, -- win any map on Extreme
	Conqueror = { id = 0, name = "Seven Seas Conqueror" }, -- win the last map
	Mythic = { id = 0, name = "Mythic Treasure" }, -- get a Mythic item
	Lifesaver = { id = 0, name = "Lifesaver" }, -- revive a crewmate
	Reborn = { id = 0, name = "Reborn" }, -- rebirth once
	Raider = { id = 0, name = "Leviathan Slayer" }, -- win a raid
	Endless = { id = 0, name = "Wave Rider" }, -- reach wave 25 in endless mode
}

-- Leaderboards on the island (all-time, updated every couple of minutes).
Config.LEADERBOARDS = {
	{ stat = "gold", title = "BIGGEST BOUNTY", icon = "💰" },
	{ stat = "kills", title = "MOST MARINES DEFEATED", icon = "☠️" },
	{ stat = "wins", title = "MOST VICTORIES", icon = "🏆" },
	{ stat = "endless", title = "HIGHEST ENDLESS WAVE", icon = "♾️" },
	{ stat = "rebirths", title = "MOST REBIRTHS", icon = "⭐" },
}
Config.LEADERBOARD_SPOTS = {
	Vector3.new(49, 0, 1426), Vector3.new(58, 0, 1442), Vector3.new(67, 0, 1458), Vector3.new(76, 0, 1474), Vector3.new(85, 0, 1490),
}
Config.LEADERBOARD_FACE = Vector3.new(0, 0, 1452)

-- Titles over your head, from your all-time bounty (total gold earned).
Config.TITLES = {
	{ bounty = 0, title = "Rookie", color = rgb(200, 210, 220) },
	{ bounty = 10000, title = "Pirate", color = rgb(120, 200, 255) },
	{ bounty = 50000, title = "Supernova", color = rgb(120, 230, 140) },
	{ bounty = 200000, title = "Warlord", color = rgb(255, 200, 70) },
	{ bounty = 1000000, title = "Emperor", color = rgb(255, 110, 70) },
	{ bounty = 5000000, title = "King of the Seas", color = rgb(255, 90, 200) },
}

-- Adventures --------------------------------------------------------------------------------

-- Pickups that sometimes drop from defeated Marines.
--   Meat heals, Magnet pulls in every XP orb, Fleet Barrage wipes out nearby Marines.
Config.PICKUPS = {
	Meat = { icon = "🍖", chance = 0.012, heal = 0.3, color = rgb(210, 120, 70) },
	Magnet = { icon = "🧲", chance = 0.004, color = rgb(90, 160, 255) },
	BusterCall = { icon = "💣", chance = 0.0025, radius = 70, bossDamage = 0.08, color = rgb(255, 80, 60) },
}
Config.PICKUP_LIFETIME = 25

-- Knocked-out crewmates leave a revive circle: stand in it to bring them back.
Config.CREW_REVIVE = { time = 4, radius = 7, health = 0.5 }

-- Hits push regular Marines back a little (studs per hit, less for big ones).
Config.KNOCKBACK = 0.5

-- Rebirth (the Sea Sage): start over for a permanent bonus. Resets gold, shop upgrades and
-- training; keeps pirates, gear, map progress, achievements and stats.
-- Cost of the next rebirth = cost * growth ^ rebirths so far. Bonuses stack per rebirth.
Config.REBIRTH = { cost = 150000, growth = 1.6, gold = 0.25, damage = 0.10, max = 50 }

-- Endless mode: on a map + difficulty you have cleared, the waves never stop. Every few waves
-- the map's boss returns, stronger each time. Your best wave goes on a leaderboard.
Config.ENDLESS = { bossEvery = 10, waveGold = 40, minWave = 1 }

-- Raids: every so often a raid gate opens on the island for everyone. The crew starts a few
-- levels up and must defeat a giant boss before time runs out.
Config.RAID = {
	every = 1800, first = 600, open = 60, time = 300, levels = 8,
	gate = Vector3.new(0, 0, 1322), radius = 9,
	map = {
		key = "Raid", name = "Leviathan Raid", theme = "deepsea", index = 12, hp = 2.2, damage = 1.6, gold = 3,
		boss = "Leviathan, the Sea King", bossColor = rgb(40, 110, 130), bossAccent = rgb(20, 40, 70),
		bossLook = { hat = "fin", gear = "none", skin = rgb(60, 150, 170), eyes = rgb(255, 60, 60) },
	},
	difficulty = 3, bossHp = 3, gold = 4000, dropTier = 4,
}
Config.RAID.map.center = Vector3.new(-2 * Config.MAP_SPACING, 0, -5 * Config.MAP_SPACING) -- arena #21 (tools/build_place.py)

-- Playing together: extra gold for every friend in your crew, and for members of your Roblox
-- group (set groupId to your group's ID; 0 = off).
Config.SOCIAL = { groupId = 0, groupGold = 0.10, friendGold = 0.10, maxFriendGold = 0.30 }

-- Map hazards by theme: telegraphed circles that hurt (and sometimes slow) anyone inside.
-- They start after the first wave. damage is multiplied by the map and difficulty.
Config.HAZARDS = {
	volcano = { name = "Eruptions", every = 6, count = 3, radius = 7, damage = 16, delay = 1.4, color = rgb(255, 90, 30) },
	snow = { name = "Frost patches", every = 8, count = 2, radius = 9, damage = 4, delay = 1.2, color = rgb(160, 220, 255), slow = 0.55, slowTime = 2.5 },
	desert = { name = "Quicksand", every = 9, count = 2, radius = 8, damage = 3, delay = 1.2, color = rgb(230, 190, 110), slow = 0.5, slowTime = 2 },
	sky = { name = "Lightning", every = 5, count = 2, radius = 6, damage = 14, delay = 1.1, color = rgb(150, 200, 255), fx = "strike" },
	spooky = { name = "Ghost flames", every = 7, count = 3, radius = 6, damage = 12, delay = 1.3, color = rgb(170, 110, 255) },
	prison = { name = "Poison vents", every = 7, count = 3, radius = 7, damage = 10, delay = 1.3, color = rgb(150, 220, 90) },
	wano = { name = "Fire arrows", every = 7, count = 4, radius = 5, damage = 10, delay = 1.2, color = rgb(255, 120, 80) },
	deepsea = { name = "Whirlpools", every = 9, count = 2, radius = 9, damage = 6, delay = 1.3, color = rgb(60, 140, 230), slow = 0.6, slowTime = 2 },
	jungle = { name = "Falling coconuts", every = 6, count = 3, radius = 4, damage = 12, delay = 1.1, color = rgb(160, 110, 60) },
	marine = { name = "Fort cannons", every = 8, count = 2, radius = 7, damage = 12, delay = 1.4, color = rgb(255, 160, 60) },
	ship = { name = "Cannon fire", every = 8, count = 2, radius = 7, damage = 12, delay = 1.4, color = rgb(255, 160, 60) },
}

-- Anti-cheat: players moving faster than their walk speed x slack (plus room for a dash) are
-- pulled back to where they were.
Config.MOVE_CHECK = { every = 0.5, slack = 1.6, extra = 4, dash = 24 }

return Config
