# Anime Swarm

A roguelite "swarm survivor" game for Roblox (Luau, Rojo project), where every weapon is an anime skill and you play as One Piece characters.

## How it plays

1. **Lobby:** pick a character and spend gold on permanent upgrades.
2. **Run (10 minutes):** your skills fire on their own. Move to dodge the swarm.
   - Enemies drop **XP orbs** (blue, or purple for big ones). Walk near them to collect.
   - **Level up** and choose 1 of 3 cards: a new weapon, a weapon upgrade, or a passive.
     Press **1 / 2 / 3** or click. Press **R** to reroll (if you bought rerolls).
   - Up to **4 weapons** and **4 passives**, each up to level 5.
   - **Evolution:** max a weapon and its partner passive, and the next level-up offers its evolved form.
   - A **mini-boss** every 2 minutes, and the **final boss** at 10:00. Kill it to win.
3. **Results:** earn gold from kills, time survived, bosses, and a victory bonus. Gold is saved.

Co-op works: everyone shares the swarm. If you die you are out until the next run.

## Characters (One Piece fan game)

| Character | Starting skill | Bonus |
| --------- | -------------- | ----- |
| Luffy | Gum-Gum Pistol | +30 max HP |
| Zoro | Three Sword Style | +10% damage |
| Nami | Thunderbolt Tempo | +25% gold |
| Sanji | Diable Jambe | +15% move speed |
| Ace | Fire Fist | +15% area |
| Robin | Cien Fleur | -10% cooldowns |
| Chopper | Kung Fu Point | Heals you and nearby allies |

## Skills and evolutions

Any character can pick up any skill from level-up cards.

| Skill | Partner passive | Evolves into |
| ----- | --------------- | ------------ |
| Gum-Gum Pistol | Vitality | Gum-Gum Gatling |
| Three Sword Style | Haki | Asura: Nine Sword Style |
| Thunderbolt Tempo | Treasure Magnet | Zeus Thunderstorm |
| Diable Jambe | Swift Feet | Ifrit Jambe |
| Fire Fist | Expansion | Flame Emperor |
| Cien Fleur | Haste | Gigantesco Mano |
| Kung Fu Point | Vitality | Monster Point |

## Run it

**Easiest:** open `AnimeSwarm.rbxlx` in Roblox Studio (File > Open from File) and press Play.
The baseplate and spawn are already set up. After editing code, rebuild it with `python3 tools/build_place.py`.

**With Rojo (live sync while you edit):**

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
