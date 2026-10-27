# Anime Swarm

A roguelite "swarm survivor" game for Roblox (Luau, Rojo project), where every weapon is an anime-style skill.

## How it plays

1. **Lobby:** pick a class and spend gold on permanent upgrades.
2. **Run (10 minutes):** your skills fire on their own. Move to dodge the swarm.
   - Enemies drop **XP orbs** (blue, or purple for big ones). Walk near them to collect.
   - **Level up** and choose 1 of 3 cards: a new weapon, a weapon upgrade, or a passive.
     Press **1 / 2 / 3** or click. Press **R** to reroll (if you bought rerolls).
   - Up to **4 weapons** and **4 passives**, each up to level 5.
   - **Evolution:** max a weapon and its partner passive, and the next level-up offers its evolved form.
   - A **mini-boss** every 2 minutes, and the **final boss** at 10:00. Kill it to win.
3. **Results:** earn gold from kills, time survived, bosses, and a victory bonus. Gold is saved.

Co-op works: everyone shares the swarm. If you die you are out until the next run.

## Classes

| Class | Starting skill | Bonus |
| ----- | -------------- | ----- |
| Swordsman | Flame Slash | +30 max HP |
| Ninja | Shadow Clones | +15% move speed |
| Mage | Spiral Orb | +15% area |
| Healer | Spirit Orbs | Heals you and nearby allies |

## Skills and evolutions

| Skill | Partner passive | Evolves into |
| ----- | --------------- | ------------ |
| Flame Slash | Chakra Power | Inferno Dragon Slash |
| Lightning Chain | Haste | Thunder God's Wrath |
| Spiral Orb | Expansion | Giant Spiral Bomb |
| Shadow Clones | Swift Feet | Thousand Shadow Army |
| Spirit Orbs | Vitality | Guardian Spirit Ring |
| Wind Blades | Spirit Magnet | Hurricane Barrage |

## Run it

1. Install [Rojo](https://rojo.space) and the Rojo Studio plugin.
2. In this folder run `rojo serve`, then press Connect in the Studio plugin.
3. In Studio, make the Baseplate big (for example 1000 x 1 x 1000) and add a SpawnLocation.
4. To save gold in Studio, turn on Game Settings > Security > Enable Studio Access to API Services.
5. Press Play (or use Test > Start with 2+ players for co-op).

## Files

| File | What it does |
| ---- | ------------ |
| `src/shared/Config.lua` | All balance: skills, passives, classes, enemies, upgrades, run length |
| `src/server/Main.server.lua` | Lobby, run, and results loop; spawning; bosses; gold |
| `src/server/Weapons.lua` | How each skill fires and hits |
| `src/server/Enemies.lua` | Enemy movement, damage, XP orbs |
| `src/server/Progression.lua` | XP, level-up cards, evolutions |
| `src/server/PlayerData.lua` | Saving gold and permanent upgrades |
| `src/client/SwarmClient.client.lua` | HUD, level-up cards, lobby menus |
