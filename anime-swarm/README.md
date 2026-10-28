# Anime Swarm

A roguelite "swarm survivor" game for Roblox (Luau, Rojo project), where every weapon is an anime skill and you play as One Piece characters.

## How it plays

1. **Spawn island:** everyone starts as a **Marine Recruit**. Every pirate is locked: unlock them with gold
   in **CREW** (see Characters below), then visit the island NPCs (press **E** or tap):
   - **Silvers Rayleigh** trains your skills (+6% damage, -2% cooldown per level, up to 10, forever).
   - **Dr. Kureha** trains passives (+15% to that passive's effect per level, up to 5).
   - **Tom the Shipwright** sells, equips and upgrades **gear**: one weapon, one outfit and one charm.
   - **Shakky** sells permanent upgrades; **Buggy** runs the Robux store.
   The side menu (CREW, TRAIN, GEAR, SHOP, STORE) opens the same menus.
2. **Voyage gates:** walk onto the glowing pad of one of the 3 gates. The first player on the pad is the
   **captain** and picks a map and difficulty (maps are only chosen at a gate); after a 10 second countdown
   everyone on the pad sets sail.
3. **20 maps x 5 difficulties:** Easy, Normal, Hard, Very Hard, Extreme.
   - Clear a difficulty to unlock the next one on that map. Each step up gives **+10% gold**
     (and tougher, longer runs: 5 to 10 minutes).
   - Clear a map on Easy to unlock the next map. Later maps are tougher and pay more gold.
   - One crew per map at a time; different crews can be on different maps at once.
4. **Adventure:** your skills fire on their own. Move to dodge the swarm, and **dash** with **Shift**
   (L2 on a gamepad, the DASH button on phones) to zip away untouchable for a moment.
   - Enemies drop **XP orbs** (blue, or purple for big ones). Walk near them to collect.
   - **Level up** and choose 1 of 3 cards: a new skill, a skill upgrade, or a passive.
     Press **1 / 2 / 3** or click. Press **R** to reroll.
   - **3 skill slots** to start (buy up to **8**) and **5 passive** slots. Skills level up to **10**, passives to 5.
   - Every skill you own floats around your character as a little emblem (a blade, fist, ring, spark, petal...)
     that swells each time the skill fires.
   - **Fusion:** once two skills are max level (or evolved), a FUSION card can merge them into one skill
     that fires both together with double damage, faster attacks and an extra hit, and frees a slot.
   - A **Vice Admiral** every 2 minutes, and the map's **named Marine boss** when the timer runs out.
   - **Treasure chests:** every Vice Admiral drops one, and Marine Captains, CP9 Agents and Pacifistas
     sometimes do. Walk into it and **everyone in the crew** gets a gear roll.
   - The final boss must fall within 4 minutes (it enrages after 3), or the Marines win.
5. **Results:** gold from kills, time, bosses and victory, new unlocks, and sometimes a free **gear drop**
   (rarer on harder difficulties; Mythic gear only drops from bosses). Then back to the island.

**LEAVE** (top left, tap twice) sails home early with the gold earned so far. If you are knocked out you
can watch your crewmates, use a **Revive** (or buy one on the spot with Robux), or leave. Picking
level-up cards gives a moment of safety.

## Economy

Prices are steep on purpose, so progress takes many runs (tune them in `src/shared/Config.lua`).

| What | Price |
| ---- | ----- |
| Pirates | 4,000 (Usopp) up to 150,000 (Luffy) |
| Shop upgrades | Skill Slot 2,000 (x2 each), Might / Toughness 400, Greed 600, Reach 500, Reroll 1,500 (x1.6 to x1.9 each level) |
| Rayleigh's skill training | 600 gold, x1.6 each level (`Config.MASTERY`) |
| Kureha's passive training | 1,000 gold, x1.8 each level (`Config.TRAINING`) |
| Gear at Tom's | 1,500 Common, 7,500 Rare, 25,000 Epic, 90,000 Legendary (Mythic only drops) |
| Gear upgrades | 1 spare copy + gold: 400 / 1,200 / 3,500 / 9,000 / 20,000 by rarity, x1.55 each level |

## Passives

| Passive | Per level |
| ------- | --------- |
| Haki | +10% damage |
| Haste | -8% cooldowns |
| Expansion | +10% area |
| Swift Feet | +8% move speed |
| Vitality | +20 max HP |
| Treasure Magnet | +25% pickup range |
| Multiply | +1 extra hit every 2 levels |
| Critical Eye | +5% critical hit chance (5% base) |
| Critical Power | +25% critical damage (x1.5 base) |
| Regeneration | +0.6 HP every second |
| Iron Body | -6% damage taken (up to 60%) |

Critical hits show big red damage numbers.

## Gear

Gear comes from Tom's shop, end-of-run drops and treasure chests.

- **Upgrading** needs a **duplicate**: getting an item you already own gives a **spare copy**. At Tom's, one
  spare copy plus gold upgrades it **+1** (each level adds +10% to the item's stats, up to **+10**).
- Copies beyond what +10 needs are paid out as gold (500 Common up to 30,000 Mythic).

| Slot | Items (rarity) |
| ---- | -------------- |
| Weapon | Rusty Cutlass (Common), Marine Saber (Rare), Kabuto (Epic), Wado Ichimonji (Epic), Shusui (Legendary), Enma (Mythic, boss drop) |
| Outfit | Sailor Shirt (Common), Marine Coat (Rare), Super Speedo (Epic), Jinbe's Kimono (Epic), Seastone Armor (Legendary), Emperor's Cloak (Mythic, boss drop) |
| Charm | Lucky Coin (Common), Log Pose (Rare), Den Den Mushi (Epic), Eternal Pose (Epic), Treasure Map (Legendary), Devil Fruit (Mythic, boss drop) |

## Robux store (setup needed)

| Type | What | Effect |
| ---- | ---- | ------ |
| Game pass | 2x Gold | Double gold from every adventure |
| Game pass | VIP | +25% XP, +10% damage, a VIP tag |
| Game pass | Lucky Pirate | +2 rerolls every run |
| Game pass | Swift Dash | Dash 40% more often |
| Product | 5,000 / 25,000 / 100,000 Gold | Gold |
| Product | 2x XP Boost, 2x Gold Boost | 30 minutes each |
| Product | Revive | Get back up with full HP when knocked out (also sold right on the knocked-out screen) |

To turn them on: publish the game, then on the Creator Dashboard open your experience >
**Monetization** and create the passes (Passes) and products (Developer Products), setting your own
prices. Paste each ID into `Config.GAME_PASSES` / `Config.PRODUCTS` in `src/shared/Config.lua` and
rebuild. Until then they show as "NOT SET UP". Products are only granted after the purchase saves.
Suggested prices: 2x Gold 299, VIP 399, Lucky Pirate 149, Swift Dash 99 Robux; gold packs 49 / 199 / 649;
boosts 79 each; Revive 25.
Free gear drops are never sold for Robux (no paid random rewards).

## Saving

Saves use a session lock (two servers can't overwrite each other), retry failed loads, autosave every
2 minutes, and never save over a save that failed to load. In Studio, turn on Game Settings > Security
> Enable Studio Access to API Services to test saving and purchases.

## Maps

Every arena has its own props, ground detail, a themed border wall and two big landmarks
(windmill, watchtower, fountain, shipwreck, sea dome, snow castle, pyramid, giant tree, golden bell,
haunted mansion, giant bubble, prison tower, volcano, pagoda...).

| # | Map | Theme | Boss |
| - | --- | ----- | ---- |
| 1 | Foosha Village | Grassland | Captain Nezumi |
| 2 | Shells Town | Marine base | Captain Morgan |
| 3 | Orange Town | Town | Lieutenant Fullbody |
| 4 | Syrup Village | Beach | Jango |
| 5 | Baratie | Ship deck | Captain T-Bone |
| 6 | Arlong Park | Sea floor | Captain Hina |
| 7 | Loguetown | Town | Captain Smoker |
| 8 | Drum Island | Snow | Tashigi |
| 9 | Alabasta | Desert | Vice Admiral Doberman |
| 10 | Jaya | Jungle | Vice Admiral Onigumo |
| 11 | Skypiea | Clouds | Vice Admiral Momonga |
| 12 | Water 7 | Town | Kaku of CP9 |
| 13 | Enies Lobby | Marine base | Rob Lucci of CP9 |
| 14 | Thriller Bark | Spooky | Vice Admiral Strawberry |
| 15 | Sabaody Archipelago | Mangroves and bubbles | Admiral Kizaru |
| 16 | Impel Down | Prison | Chief Warden Magellan |
| 17 | Marineford | Marine base | Admiral Akainu |
| 18 | Fishman Island | Sea floor | Admiral Aokiji |
| 19 | Punk Hazard | Volcano | Vice Admiral Vergo |
| 20 | Wano Country | Cherry blossoms | Fleet Admiral Sengoku |

## Enemies

| Enemy | How it fights | Shows up from |
| ----- | ------------- | ------------- |
| Marine Recruit | Walks up and hits | Map 1 |
| Marine Swordsman | Faster, carries a sword | Map 1 |
| Fishman | Fast and fragile | Map 2 |
| Marine Rifleman | Keeps its distance and shoots bullets | Map 2 |
| Pacifista | Slow, very tough | Map 4 |
| Marine Cannoneer | Shells your position (red circle: move!) | Map 6 |
| Marine Captain | Elite in a white coat | Map 8 |
| CP9 Agent | Very fast elite | Map 12 |
| Vice Admiral | Mini-boss with telegraphed slams | Every 2 minutes |
| Named boss | Slams plus a ring of strikes | End of every run |

## Characters (One Piece fan game)

Every character wears their own gear (straw hat, swords, Clima-Tact, slingshot and long nose, afro and cane...).

| Character | Starting skill | Bonus | Unlock |
| --------- | -------------- | ----- | ------ |
| Marine Recruit | Marine Rifle | +10 max HP | Free (everyone starts here) |
| Usopp | Fire Bird Star | +1 reroll each run | 4,000 gold |
| Nami | Thunderbolt Tempo | +25% gold | 6,000 gold |
| Chopper | Kung Fu Point | Heals you and nearby allies | 8,000 gold |
| Zoro | Three Sword Style | +10% damage | 12,000 gold |
| Sanji | Diable Jambe | +15% move speed | 12,000 gold |
| Robin | Cien Fleur | -10% cooldowns | 18,000 gold |
| Franky | Coup de Vent | +8% damage, +20 max HP | 25,000 gold |
| Brook | Yahazu Giri | +30% pickup range | 30,000 gold |
| Jinbe | Fishman Karate | +50 max HP | 40,000 gold |
| Ace | Fire Fist | +15% area | 60,000 gold |
| Law | Room: Amputate | -8% cooldowns, +8% area | 80,000 gold |
| Hancock | Perfume Femur | +15% damage | 100,000 gold |
| Luffy | Gum-Gum Pistol | +30 max HP | 150,000 gold |

## Skills

Every character has **6 skills**, each with its own icon. You start a run with your character's first (signature) skill.
Level-ups mostly offer your own character's skills; now and then a crewmate's skill shows up as a
rare **Crew Skill** card.

You start with **3 skill slots**. Buy more with the **Skill Slot** upgrade in the Shop, up to **8**.

| Character | Skills (signature first) |
| --------- | ------------------------ |
| Marine | Marine Rifle, Cutlass Slash, Cannonball, Rankyaku, Shigan, Buster Call |
| Luffy | Gum-Gum Pistol, Gum-Gum Bazooka, Gum-Gum Whip, Gum-Gum Balloon, Gum-Gum Elephant Gun, Red Hawk |
| Zoro | Three Sword Style, 360 Pound Cannon, Oni Giri, Tatsumaki, Shishi Sonson, Black Rope Dragon |
| Nami | Thunderbolt Tempo, Cyclone Tempo, Mirage Tempo, Thunder Lance Tempo, Weather Egg, Black Ball |
| Sanji | Diable Jambe, Concasse, Party Table Kick, Mouton Shot, Poele a Frire, Flambage Shot |
| Ace | Fire Fist, Fire Gun, Firefly, Fire Pillar, Fire Fence, Cross Fire |
| Robin | Cien Fleur, Seis Fleur, Mil Fleur, Flower Storm, Gigante Fleur, Petal Guard |
| Chopper | Kung Fu Point, Heavy Gong, Horn Point, Rumble Ball, Cherry Blossom Hoof, Medicine Bomb |
| Usopp | Fire Bird Star, Lead Star, Explosive Star, Tabasco Star, Pop Green, Impact Dial |
| Franky | Coup de Vent, Weapons Left, Strong Right, Franky Fireball, General Cannon, Franky Center |
| Brook | Yahazu Giri, Soul Solid, Aubade Coup Droit, Ghost Parade, Soul Parade, Ice Burn |
| Jinbe | Fishman Karate, Shark Brick Fist, Water Heart, 5000 Brick Fist, Shark Arrows, Ocean Current |
| Law | Room: Amputate, Counter Shock, Injection Shot, Shambles, Mes, Room Dome |
| Hancock | Perfume Femur, Slave Arrow, Pistol Kiss, Mero Mero Mellow, Salome Strike, Love Hearts |

**Fusion:** any two max-level (or evolved) skills can be fused into one. The fused skill fires both
skills together with x2 damage, 20% faster attacks, 15% more area and +1 hit, and takes only one slot.
Tune it with `Config.FUSION`.

Signature skills also evolve when the skill and its partner passive are both max level:

| Signature skill | Partner passive | Evolves into |
| --------------- | --------------- | ------------ |
| Marine Rifle | Haki | Justice Volley |
| Gum-Gum Pistol | Vitality | Gum-Gum Gatling |
| Three Sword Style | Haki | Asura: Nine Sword Style |
| Thunderbolt Tempo | Treasure Magnet | Zeus Thunderstorm |
| Diable Jambe | Swift Feet | Ifrit Jambe |
| Fire Fist | Expansion | Flame Emperor |
| Cien Fleur | Haste | Gigantesco Mano |
| Kung Fu Point | Vitality | Monster Point |
| Fire Bird Star | Expansion | Firebird Barrage |
| Coup de Vent | Vitality | Radical Beam |
| Yahazu Giri | Haste | Soul King's Requiem |
| Fishman Karate | Haki | Vagabond Drill |
| Room: Amputate | Haste | Gamma Knife |
| Perfume Femur | Haki | Love-Love Paradise |

## Run it

**Easiest:** open `AnimeSwarm.rbxlx` in Roblox Studio (File > Open from File) and press Play.
The spawn island and all 20 arenas are already built (the voyage gates appear when you press Play). After editing code, rebuild it with `python3 tools/build_place.py`.

**With Rojo (live sync while you edit):**

1. Install [Rojo](https://rojo.space) and the Rojo Studio plugin.
2. Open `AnimeSwarm.rbxlx` in Studio (it has the map), then run `rojo serve` here and press Connect.
3. Rojo now keeps the scripts in sync with the files in `src/` as you edit.
4. To save gold in Studio, turn on Game Settings > Security > Enable Studio Access to API Services.
5. Press Play (or use Test > Start with 2+ players for co-op).

## Files

| File | What it does |
| ---- | ------------ |
| `src/shared/Config.lua` | All balance: skills and icons, passives, characters, enemies, maps, difficulties, upgrades |
| `src/server/Main.server.lua` | Gate boarding and captains, running each adventure, spawning, bosses, rewards, unlocks |
| `src/server/Portals.lua` | Builds the voyage gates and tracks who is standing on their pads |
| `src/server/Gear.lua` | Each character's hats, swords and other worn gear |
| `src/server/Npcs.lua` | The island NPCs and their prompts |
| `src/server/Monetization.lua` | Game passes, developer products, revives and boosts |
| `src/server/Weapons.lua` | How each skill fires and hits |
| `src/server/Enemies.lua` | Enemy bodies and gear, movement, rifle shots, telegraphed blasts, XP orbs |
| `src/server/Progression.lua` | XP, level-up cards, evolutions |
| `src/server/PlayerData.lua` | Safe saving: gold, upgrades, training, gear, progress, purchases |
| `src/server/Fx.lua` | Sends effect events (what happened) to every client |
| `src/client/SwarmClient.client.lua` | Connects the UI to the server; dash, NPC prompts, purchases, spectating |
| `src/client/Theme.lua` | Colors, fonts, UI building blocks and screen-size scaling |
| `src/client/Hud.lua` | In-run HUD, level-up cards, announcements, results screen |
| `src/client/Lobby.lua` | Crew, training, gear, shop, store and map select menus, gate banner |
| `src/client/Effects.lua` | Skill effects, hit sparks, damage numbers, portal swirls |
| `src/client/Animate.lua` | Punch, slash, kick, throw and cast animations (R15) |
| `tools/build_place.py` | Builds `AnimeSwarm.rbxlx`: the spawn island, 20 themed arenas, lighting and all scripts |
