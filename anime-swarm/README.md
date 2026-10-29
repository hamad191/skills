# Anime Swarm

A roguelite "swarm survivor" game for Roblox (Luau, Rojo project), where every weapon is an anime-style skill and you play as a crew of original pirate heroes.

## How it plays

1. **Spawn island:** everyone starts as a **Marine Recruit**. Every pirate is locked: unlock them with gold
   in **CREW** (see Characters below), then visit the island NPCs (press **E** or tap):
   - **Old Captain Grey** trains your skills (+6% damage, -2% cooldown per level, up to 10, forever).
   - **Granny Doc** trains passives (+15% to that passive's effect per level, up to 5).
   - **Hammond the Shipwright** sells, equips and upgrades **gear**: one weapon, one outfit and one charm.
   - **Madam Roxie** sells permanent upgrades; **Bingo the Clown** runs the Robux store.
   - **The Sea Sage** at the shrine handles **rebirths** (see Rebirth below).
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
   - **Waves:** every run is split into 30-second waves (**WAVE 3 / 10** at the top). Each wave opens with a
     big banner and usually a **wave event**: a squad that lands all at once (see Waves below).
     Every 4th wave a **Vice Admiral** leads the attack, and after the last wave the map's
     **named Marine boss** arrives (FINAL WAVE).
   - **Treasure chests:** every Vice Admiral drops one, and Marine Captains, Shadow Agents and Iron Sentinels
     sometimes do. Walk into it and **everyone in the crew** gets a gear roll.
   - **Pickups** sometimes drop: 🍖 meat heals 30%, 🧲 a magnet pulls in every XP orb, 💣 a Fleet Barrage
     wipes out the Marines around you.
   - The final boss must fall within 4 minutes (it enrages after 3), or the Marines win.
5. **Results:** gold from kills, time, bosses and victory, a **first-clear bonus**, new unlocks, damage
   dealt by each of your skills, and sometimes a free **gear drop** (rarer on harder difficulties;
   Mythic gear only drops from bosses). Then back to the island.

**LEAVE** (top left, tap twice) sails home early with the gold earned so far. If you are knocked out you
leave a pink **revive circle**: a crewmate standing in it for 4 seconds brings you back. You can also
watch your crewmates, use a **Revive** (or buy one on the spot with Robux), or leave. Picking
level-up cards gives a moment of safety. Your crewmates' health shows under the LEAVE button.

New players get a **first-time guide** (a golden trail to Captain Grey, then to a gate, then tips during
their first adventure) and a 1,000 gold welcome gift for finishing it.

## Economy

Prices are steep on purpose, so progress takes many runs (tune them in `src/shared/Config.lua`).

| What | Price |
| ---- | ----- |
| Pirates | 4,000 (Pip) up to 150,000 (Rocco) |
| Shop upgrades | Skill Slot 2,000 (x2 each), Might / Toughness 400, Greed 600, Reach 500, Reroll 1,500 (x1.6 to x1.9 each level) |
| Captain Grey's skill training | 600 gold, x1.6 each level (`Config.MASTERY`) |
| Granny Doc's passive training | 1,000 gold, x1.8 each level (`Config.TRAINING`) |
| Gear at Tom's | 1,500 Common, 7,500 Rare, 25,000 Epic, 90,000 Legendary (Mythic only drops) |
| Gear upgrades | 1 spare copy + gold: 400 / 1,200 / 3,500 / 9,000 / 20,000 by rarity, x1.55 each level |

## Passives

| Passive | Per level |
| ------- | --------- |
| Fighting Spirit | +10% damage |
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
| Weapon | Rusty Cutlass (Common), Marine Saber (Rare), Slingshot Staff (Epic), White Wind Katana (Epic), Black Autumn Blade (Legendary), Abyss Blade (Mythic, boss drop) |
| Outfit | Sailor Shirt (Common), Marine Coat (Rare), Speedy Trunks (Epic), Helmsman's Kimono (Epic), Anchorstone Armor (Legendary), Emperor's Cloak (Mythic, boss drop) |
| Charm | Lucky Coin (Common), Island Compass (Rare), Snail Phone (Epic), Eternal Compass (Epic), Treasure Map (Legendary), Mystic Fruit (Mythic, boss drop) |

## Island NPCs

Each NPC is a real R15 character in their own outfit (Captain Grey's glasses, scar and white hair,
Granny Doc's sunglasses and sake, Hammond the fishman's apron and hammer, Madam Roxie's smoking
cigarette, Bingo's red nose, hat and cape) standing at their own stall: training dummies, a clinic with a bubbling
cauldron, a shipyard forge, a bar, a circus awning with treasure, and the Sea Sage's shrine with a
glowing star. They breathe, look at you,
wave when you walk up, play their own idle (Hammond's hammer sparks on the anvil, Bingo laughs) and
greet you in a speech bubble when you talk to them.

## Rebirth

Talk to the **Sea Sage** to be reborn: you lose your gold, shop upgrades and skill/passive training,
and keep every pirate, all your gear, map progress, achievements and stats. Each rebirth adds
**+25% gold and +10% damage forever** (they stack, up to 50 rebirths). The first costs 150,000 gold;
each one after costs 1.6x more (`Config.REBIRTH`). Rebirths show as stars on your title, in the
player list and on their own leaderboard.

## Endless mode and raids

- **Endless mode:** at a voyage gate, turn on **♾️ ENDLESS** for any map and difficulty you have
  already cleared. Waves never stop, the map's boss returns every 10 waves (stronger each time), and
  the run ends when the crew falls. You earn gold per wave reached, a chance at gear, and a spot on
  the HIGHEST ENDLESS WAVE leaderboard. `Config.ENDLESS`
- **Raids:** every 30 minutes (first one 10 minutes after the server starts) the **raid gate** south
  of the spawn opens for 60 seconds. Everyone standing on it sails together to the Leviathan's
  arena, starts 8 levels up, and has 5 minutes to defeat the giant sea king for 4,000 bonus gold and
  a guaranteed Legendary-tier gear roll. `Config.RAID`

## Map hazards

From the second wave, most maps throw something at you: eruptions on the volcano, frost patches that
slow you on the snow, quicksand in the desert, lightning in the sky, ghost flames, poison vents,
fire arrows, whirlpools, falling coconuts, and fort or ship cannons. Each shows a colored circle
first: step out. `Config.HAZARDS`

## Playing together

Every friend in your crew gives **+10% gold** (up to +30%). If you have a Roblox group, put its ID
in `Config.SOCIAL.groupId` and members get **+10% gold** too. The REWARDS menu has an **INVITE
FRIENDS** button.

## World and details

- **Real terrain** (built when the server starts, `src/server/World.lua`): the island has textured
  grass with animated blades, a sand beach that slopes into a **waving ocean**, and every arena has a
  textured ground in its theme (grass, concrete, cobblestone, sand, wood planks, snow, basalt with
  glowing cracked lava, mud, slate...) broken up by patches of other materials. Sea-themed arenas sit
  in open water. Clouds drift across the sky and change with each map.
- **The island:** stepping-stone paths from the spawn to every NPC, the raid gate and the
  leaderboards, a signpost with an arrow toward each one, and flower beds.
- **Wildlife** (on your screen only, off in low graphics): seagulls circling overhead, butterflies over
  the island, fish leaping out of the sea, fireflies on dark maps.
- **Materials:** enemy uniforms are cloth, boots and belts leather, the Iron Sentinel metal.

Studio's edit view still shows the old flat floors; the terrain appears when you press Play.

## The look

A "High Seas" pirate style: deep-sea panels with gold rope trim and rivets, glossy buttons, cartoon
fonts, and WANTED posters for every pirate in CREW (with their bounty: the unlock price). In
adventures: a wave tracker, wave banners, a boss health bar, a combo counter (ON FIRE! RAMPAGE!
UNSTOPPABLE!), arrows at the screen edge pointing to treasure chests and bosses, and red edges
when you're hurt or low on health.

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

## Rewards

The 🎁 **REWARDS** menu (a red "!" shows when something is ready):

- **Daily login:** 500 / 800 / 1,200 / 1,600 / 2,200 / 3,000 / 5,000 gold + a revive on days 1-7 of a
  streak (day 7 repeats; missing a day starts over). `Config.DAILY_REWARDS`
- **Daily quests:** 3 a day from a pool (defeat Marines, win, reach a wave or level, Vice Admirals,
  chests, a named boss, pickups, revive a crewmate), each paying gold. `Config.QUESTS`
- **Codes:** players redeem each once. Add codes for updates and your socials in `Config.CODES`
  (starts with SETSAIL, TREASURE and HIGHSEAS).
- **Achievements:** 13 of them, shown in game. To also give real Roblox badges, create badges on the
  Creator Dashboard (your experience > Engagement > Badges) and paste their IDs into `Config.BADGES`.

**Fame:** five leaderboards on the island (biggest bounty, most Marines defeated, most victories,
highest endless wave, most rebirths), 💰 Bounty, ☠️ Kills and ⭐ Rebirths columns in the player list, and a title over your head from your all-time
bounty: Rookie, Pirate, Supernova, Warlord, Emperor, King of the Seas (`Config.TITLES`).

## Sound and settings

Every skill, hit, explosion, laser, pickup, chest, level-up, wave and button has a sound (built-in
Roblox sounds; swap any of them in `Config.SOUNDS`). Music is silent until you pick tracks: open the
Creator Store > Audio > Music, copy a track's ID, and paste it into `Config.MUSIC` (Lobby, Battle,
Boss). The ⚙️ **SETTINGS** menu (side menu, or the gear button in adventures) has music and effects
volume, damage numbers, camera shake and a low graphics mode for phones; settings are saved.

Each map has its own mood: time of day, haze, color tint and weather (snow, ash and embers, cherry
blossoms, falling leaves, desert dust, rising bubbles, ghostly mist).

## Fair play

- Players moving faster than they should (beyond walking, plus room for a dash) are pulled back.
- Every request (buying, training, picking cards...) is rate limited.
- Effects are only sent to players near them, so crews on other maps don't slow each other down.

## Saving

Saves use a session lock (two servers can't overwrite each other), retry failed loads, autosave every
2 minutes, and never save over a save that failed to load. Purchases and unlocks ask for a save;
several in a row become one write (at most one every 8 seconds per player), and only one write per
player runs at a time. In Studio, turn on Game Settings > Security
> Enable Studio Access to API Services to test saving and purchases.

## Maps

Every arena has its own props, ground detail, a themed border wall and two big landmarks
(windmill, watchtower, fountain, shipwreck, sea dome, snow castle, pyramid, giant tree, golden bell,
haunted mansion, giant bubble, prison tower, volcano, pagoda...).

| # | Map | Theme | Boss |
| - | --- | ----- | ---- |
| 1 | Windmill Village | Grassland | Captain Whiskers |
| 2 | Fort Harbor | Marine base | Captain Ironjaw |
| 3 | Citrus Town | Town | Lieutenant Peacock |
| 4 | Palm Cape | Beach | Hypno Jack |
| 5 | Sea Restaurant | Ship deck | Captain Ribcage |
| 6 | Shark Reef | Sea floor | Captain Shackles |
| 7 | Gallows Town | Town | Captain Haze |
| 8 | Snowcap Island | Snow | Swordswoman Kiri |
| 9 | Dune Kingdom | Desert | Vice Admiral Hound |
| 10 | Vine Island | Jungle | Vice Admiral Arachne |
| 11 | Cloud Isle | Clouds | Vice Admiral Glider |
| 12 | Canal City | Town | Agent Longneck |
| 13 | Court Island | Marine base | Agent Panthera |
| 14 | Haunted Isle | Spooky | Vice Admiral Thornberry |
| 15 | Bubble Grove | Mangroves and bubbles | Admiral Flash |
| 16 | Abyss Prison | Prison | Warden Toxus |
| 17 | Navy Fortress | Marine base | Admiral Magmus |
| 18 | Coral Kingdom | Sea floor | Admiral Glacius |
| 19 | Burning Isle | Volcano | Vice Admiral Steelfist |
| 20 | Blossom Land | Cherry blossoms | Fleet Admiral Goldbeam |

## Enemies

Every enemy has a jointed body (arms and legs swing as they walk), a face, its own hat (Marine
caps, officer caps, a medic's red cross, a sniper's beret, Iron Sentinel bear ears, a Shadow Agent top hat,
a fishman fin, clown hair) and its own gear. Officers wear the JUSTICE coat. Red strips and
circles on the ground are warnings: step out before they fill up.

| Enemy | How it fights | Shows up from |
| ----- | ------------- | ------------- |
| Marine Recruit | Walks up and hits | Map 1 |
| Marine Swordsman | Lunges along a short red line | Map 1 |
| Marine Rifleman | Ranged: keeps its distance and shoots | Map 1 |
| Shark Raider | Fast and fragile | Map 2 |
| Bomb Clown | Runs at you, lights its fuse and explodes (kill it first!) | Map 2 |
| Marine Medic | Stays back and heals hurt Marines nearby | Map 3 |
| Iron Sentinel | Very tough; fires a wide **laser** after aiming (red strip) | Map 4 |
| Chain Netter | Ranged: throws nets that **slow** you | Map 5 |
| Marine Cannoneer | Shells your position (red circle: move!) | Map 6 |
| Marine Sniper | Long range: a thin red line, then a painful shot | Map 7 |
| Marine Captain | Elite in a coat; calls in **reinforcements** | Map 8 |
| Shadow Agent | **Shadow-steps** next to you; kicks flying air blades | Map 12 |
| Vice Admiral | Mini-boss: telegraphed slams and reinforcements | Every 4th wave |
| Named boss | Slams, a ring of strikes and a huge laser | Final wave |

## Waves

Waves are 30 seconds (`Config.WAVE_LENGTH`), so a run has 10 to 20 of them. From wave 2, most
waves open with an event (`Config.WAVE_EVENTS`); the squad grows with the wave number and crew size:

| Event | What happens | From |
| ----- | ------------ | ---- |
| HORDE! | A pack of recruits charges from one side | Wave 1 |
| SURROUNDED! | A ring of Marines closes in from all around | Wave 2 |
| FIRING SQUAD | A line of riflemen | Wave 2 |
| BOMB CLOWNS | A pack of Bomb Clowns | Wave 3 |
| SWORD SQUAD | Swordsmen all around you | Wave 4 |
| SNIPER NEST | A line of snipers | Wave 4, map 2+ |
| SENTINEL SQUAD | Three Iron Sentinels and their lasers | Wave 5, map 3+ |
| CHAIN NETS | A line of netters | Wave 5, map 4+ |
| SHADOW RUSH | Shadow Agents surround you | Wave 6, map 6+ |

## Characters

Every character wears their own gear (straw hat, swords, storm staff, slingshot and long nose, afro and cane...).
All names are original: the crew, skills, maps, bosses, enemies, gear and NPCs are inspired by classic
pirate anime archetypes without using any series' names, so the game is safe to publish.

| Character | Starting skill | Bonus | Unlock |
| --------- | -------------- | ----- | ------ |
| Marine | Marine Rifle | +10 max HP | Free (everyone starts here) |
| Pip, the King of Slingshots | Firebird Shot | +1 reroll each run | 4,000 gold |
| Skye, the Storm Navigator | Thunder Bolt | +25% gold | 6,000 gold |
| Tuck, the Reindeer Doctor | Martial Form | Heals nearby allies | 8,000 gold |
| Kenji, the Three-Blade Hunter | Triple Blade | +10% damage | 12,000 gold |
| Blaze, the Flame-Kick Chef | Flame Kick | +15% move speed | 12,000 gold |
| Flora, the Thousand-Hand Scholar | Hundred Hands | -10% cooldowns | 18,000 gold |
| Bolt, the Cyborg Shipwright | Air Blast | +8% damage, +20 max HP | 25,000 gold |
| Bones, the Skeleton Musician | Arrow Cut | +30% pickup range | 30,000 gold |
| Kai, the Tide Master | Tide Karate | +50 max HP | 40,000 gold |
| Ignis, the Fire Commander | Flame Fist | +15% area | 60,000 gold |
| Rook, the Room Surgeon | Room Slice | -8% cooldowns, +8% area | 80,000 gold |
| Serena, the Snake Empress | Charm Kick | +15% damage | 100,000 gold |
| Rocco, the Rubber Captain | Rubber Pistol | +30 max HP | 150,000 gold |

## Skills

Every character has **6 skills**, each with its own icon. You start a run with your character's first (signature) skill.
Level-ups mostly offer your own character's skills; now and then a crewmate's skill shows up as a
rare **Crew Skill** card.

You start with **3 skill slots**. Buy more with the **Skill Slot** upgrade in the Shop, up to **8**.

| Character | Skills (signature first) |
| --------- | ------------------------ |
| Marine | Marine Rifle, Cutlass Slash, Cannonball, Air Kick, Finger Strike, Cannon Salvo |
| Pip | Firebird Shot, Lead Shot, Bomb Shot, Hot Sauce Shot, Sprout Seeds, Impact Shell |
| Skye | Thunder Bolt, Cyclone, Mirage, Thunder Lance, Weather Orb, Storm Cloud |
| Tuck | Martial Form, Heavy Punch, Horn Charge, Power Pill, Blossom Hoof, Medicine Bomb |
| Kenji | Triple Blade, Air Cannon Slash, Demon Cut, Blade Tornado, Lion Strike, Dragon Twister |
| Blaze | Flame Kick, Handstand Spin, Ram Shot, Searing Sweep, Blaze Shot |
| Flora | Hundred Hands, Grasping Hands, Thousand Hands, Petal Storm, Giant Hand, Petal Guard |
| Bolt | Air Blast, Arm Cannon, Rocket Punch, Fire Breath, Mech Cannon, Super Shockwave |
| Bones | Arrow Cut, Soul Chill, Rapier Thrust, Ghost Parade, Spirit Parade, Frost Burn |
| Kai | Tide Karate, Shark Fist, Water Pulse, Tidal Fist, Water Arrows, Ocean Current |
| Ignis | Flame Fist, Fire Bullets, Fire Pillar, Flame Wall, Cross Flame |
| Rook | Room Slice, Shock Palm, Needle Thrust, Heart Cubes, Operating Dome |
| Serena | Charm Kick, Love Arrow, Kiss Shot, Petrify Beam, Serpent Strike, Heart Storm |
| Rocco | Rubber Pistol, Rubber Bazooka, Rubber Whip, Rubber Balloon, Giant Rubber Fist, Blazing Fist |

**Fusion:** any two max-level (or evolved) skills can be fused into one. The fused skill fires both
skills together with x2 damage, 20% faster attacks, 15% more area and +1 hit, and takes only one slot.
Tune it with `Config.FUSION`.

Signature skills also evolve when the skill and its partner passive are both max level:

| Signature skill | Partner passive | Evolves into |
| --------------- | --------------- | ------------ |
| Marine Rifle | Fighting Spirit | Justice Volley |
| Firebird Shot | Expansion | Firebird Barrage |
| Thunder Bolt | Treasure Magnet | Thunder God Storm |
| Martial Form | Vitality | Monster Form |
| Triple Blade | Fighting Spirit | Nine Blade Phantom |
| Flame Kick | Swift Feet | Inferno Leg |
| Hundred Hands | Haste | Colossal Hands |
| Air Blast | Vitality | Super Beam |
| Arrow Cut | Haste | Requiem of Souls |
| Tide Karate | Fighting Spirit | Tidal Drill |
| Flame Fist | Expansion | Sun Flare |
| Room Slice | Haste | Gamma Blade |
| Charm Kick | Fighting Spirit | Heart Paradise |
| Rubber Pistol | Vitality | Rubber Gatling |

## Run it

**Easiest:** open `AnimeSwarm.rbxlx` in Roblox Studio (File > Open from File) and press Play.
The spawn island and all 20 arenas are already built (the voyage gates appear when you press Play). After editing code, rebuild it with `python3 tools/build_place.py`.

**With Rojo (live sync while you edit):**

1. Install [Rojo](https://rojo.space) and the Rojo Studio plugin.
2. Open `AnimeSwarm.rbxlx` in Studio (it has the map), then run `rojo serve` here and press Connect.
3. Rojo now keeps the scripts in sync with the files in `src/` as you edit.
4. To test saving, leaderboards and badges in Studio, turn on Game Settings > Security > Enable Studio Access to API Services.
5. Press Play (or use Test > Start with 2+ players for co-op).

## Files

| File | What it does |
| ---- | ------------ |
| `src/shared/Config.lua` | All balance: skills and icons, passives, characters, enemies, maps, difficulties, upgrades |
| `src/server/Main.server.lua` | Gate boarding and captains, running each adventure, spawning, bosses, rewards, unlocks |
| `src/server/Portals.lua` | Builds the voyage gates and tracks who is standing on their pads |
| `src/server/Gear.lua` | Each character's hats, swords and other worn gear |
| `src/server/Npcs.lua` | The island NPCs (R15 characters in outfits), their stalls and prompts |
| `src/server/Monetization.lua` | Game passes, developer products, revives and boosts |
| `src/server/Weapons.lua` | How each skill fires and hits |
| `src/server/Enemies.lua` | Jointed enemy bodies, hats and gear, movement, skills (lasers, snipes, heals, bombs, nets, blinks, reinforcements), XP orbs, chests |
| `src/server/Progression.lua` | XP, level-up cards, evolutions |
| `src/server/PlayerData.lua` | Safe saving: gold, upgrades, training, gear, progress, purchases, stats, quests, settings |
| `src/server/Rewards.lua` | Daily rewards, quests, codes, achievements and badges, the first-time guide's gift |
| `src/server/Leaderboards.lua` | Island leaderboards, player list stats, bounty titles |
| `src/server/Guard.lua` | Speed check and request rate limits |
| `src/server/Raid.lua` | The island's raid gate and its timer |
| `src/server/World.lua` | Terrain for the island and every arena, water, clouds |
| `src/server/Fx.lua` | Sends effect events (what happened) to the players near them |
| `src/client/SwarmClient.client.lua` | Connects the UI to the server; dash, NPC prompts, purchases, spectating |
| `src/client/Theme.lua` | Colors, fonts, UI building blocks and screen-size scaling |
| `src/client/Hud.lua` | In-run HUD, waves, boss bar, combo, crew health, edge arrows, level-up cards, results |
| `src/client/Lobby.lua` | Crew, training, gear, shop, rewards, store and map select menus, gate banner |
| `src/client/Effects.lua` | Skill effects, hit sparks, damage numbers, portal swirls |
| `src/client/Animate.lua` | Punch, slash, kick, throw and cast animations (R15) |
| `src/client/Rigs.lua` | Enemy walk cycles and attack poses, NPC idles, waves and speech bubbles |
| `src/client/Sounds.lua` | Sound effects (3D, with spam limits) and music crossfades |
| `src/client/Settings.lua` | The settings menu |
| `src/client/Tutorial.lua` | The first-time guide |
| `src/client/Ambience.lua` | Per-map lighting, haze, tint, clouds and weather |
| `src/client/Wildlife.lua` | Seagulls, butterflies, jumping fish and fireflies |
| `tools/build_place.py` | Builds `AnimeSwarm.rbxlx`: the spawn island, 20 themed arenas, lighting and all scripts |
