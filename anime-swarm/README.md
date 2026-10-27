# Anime Swarm

A roguelite "swarm survivor" game for Roblox (Luau, Rojo project), where every weapon is an anime skill and you play as One Piece characters.

## How it plays

1. **Spawn island:** explore the island, pick a pirate in **CREW** and buy permanent upgrades in **SHOP**.
2. **Portals:** walk onto the glowing pad in front of a portal. After a 10 second countdown,
   everyone standing on that pad sets sail together.

   | Portal | Difficulty | Arena | Run length | Gold |
   | ------ | ---------- | ----- | ---------- | ---- |
   | East Blue | Easy | Grassland with palms | 5 min | x1 |
   | Grand Line | Normal | Desert with cacti and ruins | 8 min | x1.75 |
   | New World | Hard | Volcanic rock with lava cracks | 10 min | x3 |

   Different crews can be on different adventures at the same time.
3. **Adventure:** your skills fire on their own. Move to dodge the swarm.
   - Enemies drop **XP orbs** (blue, or purple for big ones). Walk near them to collect.
   - **Level up** and choose 1 of 3 cards: a new skill, a skill upgrade, or a passive.
     Press **1 / 2 / 3** or click. Press **R** to reroll (if you bought rerolls).
   - **3 skill slots** to start (buy up to **8**) and **4 passive** slots. Skills level up to **10**, passives to 5.
   - **Fusion:** once two skills are max level (or evolved), a FUSION card can merge them into one skill
     that fires both together with double damage, faster attacks and an extra hit, and frees a slot.
   - **Evolution:** max a skill and its partner passive, and the next level-up offers its evolved form.
   - A **Vice Admiral** every 2 minutes, and the **Admiral** when the timer runs out. Defeat it to win.
4. **Results:** earn gold from kills, time survived, bosses and a victory bonus, then sail back to the island.

If you are knocked out, your crew fights on; you return to the island when the adventure ends.

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

## Skills

Every character has **6 skills**. You start a run with your character's first (signature) skill.
Level-ups mostly offer your own character's skills; now and then a crewmate's skill shows up as a
rare **Crew Skill** card.

You start with **3 skill slots**. Buy more with the **Skill Slot** upgrade in the Shop, up to **8**.

| Character | Skills (signature first) |
| --------- | ------------------------ |
| Luffy | Gum-Gum Pistol, Gum-Gum Bazooka, Gum-Gum Whip, Gum-Gum Balloon, Gum-Gum Elephant Gun, Red Hawk |
| Zoro | Three Sword Style, 360 Pound Cannon, Oni Giri, Tatsumaki, Shishi Sonson, Black Rope Dragon |
| Nami | Thunderbolt Tempo, Cyclone Tempo, Mirage Tempo, Thunder Lance Tempo, Weather Egg, Black Ball |
| Sanji | Diable Jambe, Concasse, Party Table Kick, Mouton Shot, Poele a Frire, Flambage Shot |
| Ace | Fire Fist, Fire Gun, Firefly, Fire Pillar, Fire Fence, Cross Fire |
| Robin | Cien Fleur, Seis Fleur, Mil Fleur, Flower Storm, Gigante Fleur, Petal Guard |
| Chopper | Kung Fu Point, Heavy Gong, Horn Point, Rumble Ball, Cherry Blossom Hoof, Medicine Bomb |

**Fusion:** any two max-level (or evolved) skills can be fused into one. The fused skill fires both
skills together with x2 damage, 20% faster attacks, 15% more area and +1 hit, and takes only one slot.
Tune it with `Config.FUSION`.

Signature skills also evolve when the skill and its partner passive are both max level:

| Signature skill | Partner passive | Evolves into |
| --------------- | --------------- | ------------ |
| Gum-Gum Pistol | Vitality | Gum-Gum Gatling |
| Three Sword Style | Haki | Asura: Nine Sword Style |
| Thunderbolt Tempo | Treasure Magnet | Zeus Thunderstorm |
| Diable Jambe | Swift Feet | Ifrit Jambe |
| Fire Fist | Expansion | Flame Emperor |
| Cien Fleur | Haste | Gigantesco Mano |
| Kung Fu Point | Vitality | Monster Point |

## Run it

**Easiest:** open `AnimeSwarm.rbxlx` in Roblox Studio (File > Open from File) and press Play.
The spawn island and all three arenas are already built (the portals appear when you press Play). After editing code, rebuild it with `python3 tools/build_place.py`.

**With Rojo (live sync while you edit):**

1. Install [Rojo](https://rojo.space) and the Rojo Studio plugin.
2. Open `AnimeSwarm.rbxlx` in Studio (it has the map), then run `rojo serve` here and press Connect.
3. Rojo now keeps the scripts in sync with the files in `src/` as you edit.
4. To save gold in Studio, turn on Game Settings > Security > Enable Studio Access to API Services.
5. Press Play (or use Test > Start with 2+ players for co-op).

## Files

| File | What it does |
| ---- | ------------ |
| `src/shared/Config.lua` | All balance: skills, passives, characters, enemies, adventures, upgrades |
| `src/server/Main.server.lua` | Portal boarding, running each adventure, spawning, bosses, rewards |
| `src/server/Portals.lua` | Builds the portals and tracks who is standing on their pads |
| `src/server/Weapons.lua` | How each skill fires and hits |
| `src/server/Enemies.lua` | Enemy bodies, movement, damage, XP orbs |
| `src/server/Progression.lua` | XP, level-up cards, evolutions |
| `src/server/PlayerData.lua` | Saving gold and permanent upgrades |
| `src/server/Fx.lua` | Sends effect events (what happened) to every client |
| `src/client/SwarmClient.client.lua` | Connects the UI to the server |
| `src/client/Theme.lua` | Colors, fonts and UI building blocks |
| `src/client/Hud.lua` | In-run HUD, level-up cards, announcements, results screen |
| `src/client/Lobby.lua` | Character select, upgrade shop, gold, portal boarding banner |
| `src/client/Effects.lua` | Skill effects, hit sparks, damage numbers, portal swirls |
| `src/client/Animate.lua` | Punch, slash, kick, throw and cast animations (R15) |
| `tools/build_place.py` | Builds `AnimeSwarm.rbxlx`: the spawn island, arenas, lighting and all scripts |
