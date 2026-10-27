-- Anime-style skills. Edit numbers here to balance the game.
-- kind: cone | dash | aoe | pull | beam | clones
return {
	{ key = "FlameSlash",    name = "Flame Dragon Slash", kind = "cone", cooldown = 2,  damage = 40,  range = 16, angle = 100, color = Color3.fromRGB(255, 120, 30) },
	{ key = "LightningDash", name = "Lightning Dash",     kind = "dash", cooldown = 4,  damage = 55,  range = 32, width = 6,    color = Color3.fromRGB(255, 240, 90) },
	{ key = "SpiritBurst",   name = "Spirit Burst",       kind = "aoe",  cooldown = 6,  damage = 90,  range = 22,               color = Color3.fromRGB(90, 200, 255) },
	{ key = "GravityCrush",  name = "Gravity Crush",      kind = "pull", cooldown = 10, damage = 120, range = 40, radius = 20,  color = Color3.fromRGB(170, 80, 255) },
	{ key = "DragonWave",    name = "Ultimate Dragon Wave", kind = "beam", cooldown = 20, damage = 300, range = 90, width = 12, color = Color3.fromRGB(255, 60, 90) },
	{ key = "SpiralOrb",     name = "Spiral Orb",         kind = "beam", cooldown = 8,  damage = 160, range = 30, width = 8,    color = Color3.fromRGB(80, 160, 255) },
	{ key = "ShadowClones",  name = "Shadow Clones",      kind = "clones", cooldown = 14, damage = 70, range = 18,              color = Color3.fromRGB(120, 120, 140) },
}
