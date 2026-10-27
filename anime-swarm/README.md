# Anime Swarm

Wave-survival game for Roblox (Luau, Rojo project). Survive endless, growing waves using anime-style skills.

| Key | Skill |
| --- | ----- |
| 1 | Flame Dragon Slash (cone) |
| 2 | Lightning Dash (dash + hit) |
| 3 | Spirit Burst (AoE) |
| 4 | Gravity Crush (pull + slam) |
| 5 | Ultimate Dragon Wave (beam) |
| 6 | Spiral Orb (short, wide orb) |
| 7 | Shadow Clones (3 clone strikes) |
| U | Buy damage upgrade (50 x level coins) |

Enemies: Swarmling, Runner (fast, wave 3+), Tank (slow, wave 5+), and a Boss every 5th wave.

## Run
1. Install Rojo and the Rojo Studio plugin.
2. `rojo serve` in this folder, then Connect in Studio. Add a Baseplate and a SpawnLocation.
3. Press Play.

Tweak skills in `src/shared/SkillConfig.lua`. Cooldowns and damage are validated on the server.
