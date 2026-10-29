-- Game flow:
--   Spawn island: pick a character, train and gear up with the NPCs, step onto a voyage gate.
--   The first player on a pad is the captain and picks a map + difficulty they have unlocked.
--   When the gate's countdown ends, everyone on the pad sails to that map's arena.
--   Each adventure runs until its boss falls, its time runs out, or its whole crew is down.
--   Players can leave early (keeping the gold they earned) or be revived: with a revive from
--   the store, or by a crewmate standing in their revive circle.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(RS.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Enemies = require(script.Parent.Enemies)
local Progression = require(script.Parent.Progression)
local Weapons = require(script.Parent.Weapons)
local Fx = require(script.Parent.Fx)
local Portals = require(script.Parent.Portals)
local Gear = require(script.Parent.Gear)
local Npcs = require(script.Parent.Npcs)
local Monetization = require(script.Parent.Monetization)
local Rewards = require(script.Parent.Rewards)
local Leaderboards = require(script.Parent.Leaderboards)
local Guard = require(script.Parent.Guard)

Players.CharacterAutoLoads = false

local remotes = {}
local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "Remotes"
for _, name in {
	"State", "Stats", "LevelUp", "Choose", "Reroll", "SelectClass", "BuyMeta", "Meta", "Results", "Fx", "Portal",
	"Announce", "Voyage", "Dash", "Leave", "Revive", "Train", "Gear", "UnlockClass", "Wave",
	"Rewards", "Settings", "Sound",
} do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remoteFolder
	remotes[name] = r
end
remoteFolder.Parent = RS
Progression.init(remotes)
Fx.init(remotes.Fx)
Portals.build()
task.spawn(Npcs.build) -- building R15 characters can take a moment
Leaderboards.build()

local LOBBY_TEXT = "Step onto a voyage gate to choose an adventure!"
local selectedClass = {}
local runOf = {} -- [player] = the run they are in (nil = on the spawn island)
local runs = {} -- [mapKey] = run in progress (one crew per map at a time)
local lastDash = {} -- [player] = os.clock() of their last dash
local gates = {} -- [gateIndex] = { captain, map, difficulty, launchAt }
for i in Config.GATES do
	gates[i] = {}
end

-- The class a player plays: their pick, if they have unlocked it, else the Marine.
local function classOf(player)
	local pick = selectedClass[player]
	return pick and PlayerData.hasClass(player, pick) and pick or Config.DEFAULT_CLASS
end

local function sendMeta(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local costs = {}
	for name, m in Config.Meta do
		costs[name] = data.meta[name] < m.max and PlayerData.metaCost(name, data.meta[name]) or false
	end
	local boosts = {}
	for boost, untilTime in data.boosts do
		boosts[boost] = math.max(0, untilTime - os.time())
	end
	remotes.Meta:FireClient(player, {
		gold = data.gold, levels = data.meta, costs = costs, progress = data.progress, class = classOf(player),
		mastery = data.mastery, training = data.training, items = data.items, equipped = data.equipped,
		gearLevels = data.gearLevels, gearCopies = data.gearCopies, classes = data.classes,
		revives = data.revives, boosts = boosts, passes = Monetization.ownedList(player),
		dashCooldown = Monetization.dashCooldown(player), loadFailed = data.loadFailed == true,
		rewards = Rewards.snapshot(player), title = Leaderboards.titleFor(data.stats.gold or 0).title,
	})
end

local function sendLobby(player)
	remotes.State:FireClient(player, { phase = "Lobby", text = LOBBY_TEXT })
end

local function announce(run, text, color)
	for player in run.players do
		remotes.Announce:FireClient(player, text, color)
	end
end

-- Drops a player into the arena near `center` (exact = right on that spot).
local function sendToArena(player, center, exact)
	local character = player.Character
	local root = character and character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	local a = math.random() * 2 * math.pi
	local r = exact and 0 or math.random() * Config.ARENA_DROP_RADIUS
	Guard.allowTeleport(player)
	character:PivotTo(CFrame.new(center.X + math.cos(a) * r, center.Y + 5, center.Z + math.sin(a) * r))
end

-- A gold "VIP" tag over the heads of VIP pass owners.
local function addVipTag(character)
	local head = character:WaitForChild("Head", 5)
	if not head or head:FindFirstChild("VipTag") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Size = UDim2.fromOffset(90, 26)
	tag.StudsOffset = Vector3.new(0, 3.2, 0)
	tag.MaxDistance = 80
	tag.Parent = head
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "👑 VIP"
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = Color3.fromRGB(255, 205, 60)
	text.TextStrokeTransparency = 0.3
	text.Parent = tag
end

-- Revive circles ------------------------------------------------------------------------------
-- A knocked-out player leaves a glowing circle; a crewmate standing in it brings them back.

local downs = {} -- [player] = { run, pos, progress, part, fill }
local circleFolder = Instance.new("Folder")
circleFolder.Name = "ReviveCircles"
circleFolder.Parent = workspace

local function removeCircle(player)
	local down = downs[player]
	if down then
		down.part:Destroy()
		downs[player] = nil
	end
end

local function makeCircle(player, run, pos)
	removeCircle(player)
	local size = Config.CREW_REVIVE.radius * 2
	local part = Instance.new("Part")
	part.Name = player.Name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.3, size, size)
	part.CFrame = CFrame.new(pos.X, pos.Y - 2.6, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
	part.Color = Color3.fromRGB(255, 90, 140)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.45
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = part.Color, 14, 1.5
	light.Parent = part
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(200, 56)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 250
	tag.Parent = part
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0, 32)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.LuckiestGuy
	text.TextColor3 = Color3.fromRGB(255, 200, 220)
	text.TextStrokeTransparency = 0
	text.Text = "💖 REVIVE " .. player.DisplayName:upper()
	text.Parent = tag
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, -20, 0, 12)
	back.Position = UDim2.fromOffset(10, 38)
	back.BackgroundColor3 = Color3.fromRGB(40, 10, 25)
	back.Parent = tag
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 90, 140)
	fill.BorderSizePixel = 0
	fill.Parent = back
	part.Parent = circleFolder
	downs[player] = { run = run, pos = pos, progress = 0, part = part, fill = fill }
end

local function onCharacter(player, character)
	local hum = character:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		local s = Progression.get(player)
		local run = runOf[player]
		if run and s then
			-- out until revived or the crew's adventure ends; they can watch or leave
			s.dead = true
			Weapons.cleanup(player)
			remotes.LevelUp:FireClient(player, nil)
			remotes.Sound:FireClient(player, "Down")
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and not run.ending then
				makeCircle(player, run, root.Position)
			end
			return
		end
		task.wait(3)
		if player.Parent and not runOf[player] then
			player:LoadCharacter()
		end
	end)
	Progression.applyStats(player)
	task.spawn(function()
		character:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.3) -- let the body parts finish loading
		if character.Parent then
			Gear.apply(character, classOf(player))
			if Monetization.owns(player, "VIP") then
				addVipTag(character)
			end
			local data = PlayerData.get(player)
			if data then
				Leaderboards.tag(character, data.stats)
			end
		end
	end)
end

local function onPlayerAdded(player)
	PlayerData.load(player)
	if not player.Parent then
		return
	end
	Monetization.load(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	local data = PlayerData.get(player)
	Leaderboards.setup(player, data.stats)
	player:LoadCharacter()
	sendMeta(player)
	sendLobby(player)
	Rewards.welcome(player)
	if data and data.loadFailed then
		remotes.Announce:FireClient(player, "Your save couldn't load - progress won't save this visit. Try rejoining.", Config.RARITIES.Mythic)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local run = runOf[player]
	if run then
		run.players[player] = nil
	end
	runOf[player] = nil
	lastDash[player] = nil
	removeCircle(player)
	Weapons.cleanup(player)
	Progression.stop(player)
	selectedClass[player] = nil
	Monetization.release(player)
	local data = PlayerData.get(player)
	if data then
		Leaderboards.submit(player, data.stats, true)
	end
	Leaderboards.release(player)
	PlayerData.release(player)
end)

Enemies.onKilled = function(enemy, killer)
	local s = killer and Progression.get(killer)
	if s then
		s.kills += 1
		s.bonusGold += enemy.def.gold or 0
		Rewards.stat(killer, "kills", 1)
	end
	local run = runs[enemy.run]
	if run and enemy.kind == "MiniBoss" then
		for player in run.players do
			Rewards.stat(player, "minibosses", 1)
		end
	end
end
Enemies.onPickup = Progression.addXP
Enemies.onSlow = Progression.slow

local function runTargets(run)
	local targets = {}
	for player in run.players do
		local s = Progression.get(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if s and not s.dead and root and hum and hum.Health > 0 then
			table.insert(targets, {
				player = player, s = s, root = root, hum = hum, magnet = Progression.magnet(s),
				armor = math.min(Config.MAX_DEFENSE, Progression.bonus(s, "defense")),
			})
		end
	end
	return targets
end

RunService.Heartbeat:Connect(function(dt)
	local targetsByRun = {}
	for key, run in runs do
		targetsByRun[key] = runTargets(run)
	end
	Enemies.step(dt, targetsByRun)
	Weapons.step(dt)
	Fx.flush()
end)

-- Rewards ---------------------------------------------------------------------------------

-- A random gear item, its rarity rolled with a difficulty's drop weights.
local function rollItem(difficulty)
	local weights = Config.DROPS[difficulty].weights
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll, rarity = math.random() * total, "Common"
	for name, weight in weights do
		roll -= weight
		if roll <= 0 then
			rarity = name
			break
		end
	end
	local pool = {}
	for _, item in Config.GEAR_ITEMS do
		if item.rarity == rarity then
			table.insert(pool, item)
		end
	end
	return pool[math.random(#pool)]
end

-- Gives a player a dropped item. New items are kept; owned ones become a spare copy for
-- upgrading (or gold once they have enough copies). Returns what to show them.
local function giveItem(player, item)
	local outcome = PlayerData.grantItem(player, item.id)
	local data = PlayerData.get(player)
	local drop = { name = item.name, icon = item.icon, rarity = item.rarity, outcome = outcome }
	if outcome == "gold" and data then
		drop.gold = Config.DUPLICATE_GOLD[item.rarity]
		data.gold += drop.gold
	end
	if item.rarity == "Mythic" then
		Rewards.achieve(player, "Mythic")
	end
	PlayerData.requestSave(player)
	return drop
end

local function dropText(drop)
	if drop.outcome == "new" then
		return string.format("🎁 New gear: %s %s (%s)", drop.icon, drop.name, drop.rarity)
	elseif drop.outcome == "copy" then
		return string.format("🎁 Spare %s %s - use it to upgrade at Tom's", drop.icon, drop.name)
	end
	return string.format("🎁 %s %s (maxed) - +%s gold", drop.icon, drop.name, drop.gold or 0)
end

-- A treasure chest gives every crew member a gear roll: a Vice Admiral's follows the
-- difficulty, an elite Marine's is one step lower.
Enemies.onChest = function(runKey, kind, opener)
	local run = runs[runKey]
	if not run then
		return
	end
	local tier = kind == "MiniBoss" and run.difficulty or math.max(1, run.difficulty - 1)
	for player in run.players do
		local drop = giveItem(player, rollItem(tier))
		local who = player == opener and "" or opener.DisplayName .. " opened a chest!  "
		remotes.Announce:FireClient(player, who .. dropText(drop), Config.RARITIES[drop.rarity])
		Rewards.stat(player, "chests", 1)
	end
end

-- Pickups: meat heals, a magnet pulls in every XP orb, a Buster Call clears the area.
Enemies.onItem = function(runKey, kind, target)
	local def = Config.PICKUPS[kind]
	local player = target.player
	if kind == "Meat" then
		target.hum.Health = math.min(target.hum.MaxHealth, target.hum.Health + target.hum.MaxHealth * def.heal)
	elseif kind == "Magnet" then
		Enemies.magnetize(runKey, target)
	elseif kind == "BusterCall" then
		Enemies.busterCall(target.root.Position, def.radius, runKey, player)
		local run = runs[runKey]
		if run then
			announce(run, player.DisplayName .. " called a BUSTER CALL!", Color3.fromRGB(255, 80, 60))
		end
	end
	Rewards.stat(player, "pickups", 1)
end

-- What a first clear of this map + difficulty opens up.
local function unlockMessage(map, difficulty)
	local unlocked = {}
	if Config.Difficulties[difficulty + 1] then
		table.insert(unlocked, map.name .. " " .. Config.Difficulties[difficulty + 1].name)
	end
	if difficulty == 1 and Config.Maps[map.index + 1] then
		table.insert(unlocked, Config.Maps[map.index + 1].name)
	end
	return #unlocked > 0 and "Unlocked: " .. table.concat(unlocked, " and ") or nil
end

-- Gold, unlocks and drops for one player at the end of their adventure (or when they leave).
local function reward(player, run, result)
	local s, data = Progression.get(player), PlayerData.get(player)
	if not s or not data then
		return
	end
	local map, diff = run.map, run.diff
	local elapsed = os.clock() - run.start
	local gold = s.kills + math.floor(elapsed / 10) + s.bonusGold + (result == "Victory" and 500 or 0)
	gold = math.floor(gold * map.gold * diff.gold * (1 + Progression.bonus(s, "gold")) * Monetization.goldMultiplier(player))
	local unlocked, drop, firstClear
	if result == "Victory" then
		if PlayerData.recordClear(player, map.key, run.difficulty) then
			unlocked = unlockMessage(map, run.difficulty)
			firstClear = (Config.FIRST_CLEAR.base + Config.FIRST_CLEAR.perMap * (map.index - 1)) * run.difficulty
			gold += firstClear
		end
		if math.random() < Config.DROPS[run.difficulty].chance then
			drop = dropText(giveItem(player, rollItem(run.difficulty)))
		end
		Rewards.stat(player, "wins", 1)
		Rewards.stat(player, "bosses", 1)
		Rewards.achieve(player, "FirstVictory")
		if run.difficulty == #Config.Difficulties then
			Rewards.achieve(player, "Extreme")
		end
		if map.index == #Config.Maps then
			Rewards.achieve(player, "Conqueror")
		end
	end
	data.gold += gold
	Rewards.stat(player, "gold", gold)
	Rewards.stat(player, "runs", 1)
	Rewards.best(player, "level", s.level)
	PlayerData.requestSave(player)

	-- damage per skill, biggest first
	local damage = {}
	for name, amount in s.damageBy do
		local def = Progression.def(name)
		if def and amount >= 1 then
			table.insert(damage, { name = def.name, icon = def.icon, color = def.color, amount = math.floor(amount) })
		end
	end
	table.sort(damage, function(a, b)
		return a.amount > b.amount
	end)
	for i = #damage, 7, -1 do
		damage[i] = nil
	end
	remotes.Results:FireClient(player, {
		result = result, adventure = map.name .. "  -  " .. diff.name, color = diff.color,
		gold = gold, kills = s.kills, level = s.level, time = math.floor(elapsed), unlocked = unlocked, drop = drop,
		firstClear = firstClear, damage = damage,
	})
	remotes.Sound:FireClient(player, result == "Victory" and "Victory" or "Down")
end

-- Takes a player out of their run and back to the island.
local function sendHome(player)
	runOf[player] = nil
	removeCircle(player)
	Weapons.cleanup(player)
	Progression.stop(player)
	if player.Parent then
		player:LoadCharacter() -- back to the spawn island with default stats
		sendMeta(player)
		sendLobby(player)
	end
end

-- Running an adventure --------------------------------------------------------------------

-- Crew members who have landed in the arena (enemies only spawn around them).
local function landedTargets(run, targets)
	local landed = {}
	for _, t in targets do
		local offset = t.root.Position - run.map.center
		if math.abs(offset.X) <= Config.ARENA_HALF_SIZE and math.abs(offset.Z) <= Config.ARENA_HALF_SIZE then
			table.insert(landed, t)
		end
	end
	return landed
end

local function spawnAround(kind, run, targets, hpScale, dmgScale, look)
	local landed = landedTargets(run, targets)
	if #landed == 0 then
		return nil
	end
	local p = landed[math.random(#landed)].root.Position
	for _ = 1, 6 do
		local a = math.random() * 2 * math.pi
		local d = Config.SPAWN_MIN + math.random() * (Config.SPAWN_MAX - Config.SPAWN_MIN)
		local e = Enemies.spawn(kind, p.X + math.cos(a) * d, p.Z + math.sin(a) * d, hpScale, dmgScale, run.key, look)
		if e then
			return e
		end
	end
	-- the player is near the edge of the map: spawn close instead
	return Enemies.spawn(kind, p.X, p.Z + 15, hpScale, dmgScale, run.key, look)
end

-- Weighted pick from Config.SPAWN_TABLE: later maps and later minutes bring tougher Marines.
local function pickKind(minutes, mapIndex)
	local options, total = {}, 0
	for _, row in Config.SPAWN_TABLE do
		if mapIndex >= row[2] and minutes >= row[3] then
			table.insert(options, row)
			total += row[4]
		end
	end
	local roll = math.random() * total
	for _, row in options do
		roll -= row[4]
		if roll <= 0 then
			return row[1]
		end
	end
	return "Grunt"
end

-- Waves ----------------------------------------------------------------------------------------

-- This wave's event: one the map and wave number allow, picked by weight.
local function pickEvent(wave, mapIndex)
	local options, total = {}, 0
	for _, ev in Config.WAVE_EVENTS do
		if wave >= ev.fromWave and mapIndex >= ev.fromMap then
			table.insert(options, ev)
			total += ev.weight
		end
	end
	local roll = math.random() * total
	for _, ev in options do
		roll -= ev.weight
		if roll <= 0 then
			return ev
		end
	end
	return options[1]
end

-- A wave event's squad arrives around one crew member: a pack charging from one side, a ring
-- closing in from all around, or a firing line.
local function spawnSquad(ev, run, wave, crew, hpScale, dmgScale, minutes)
	local landed = landedTargets(run, runTargets(run))
	if #landed == 0 then
		return
	end
	local center = landed[math.random(#landed)].root.Position
	local count = math.floor(ev.count * (1 + (wave - 1) * 0.08) * crew + 0.5)
	count = math.min(count, Config.MAX_ENEMIES + 30 - Enemies.count(run.key))
	local a = math.random() * math.pi * 2
	local edge = Config.ARENA_HALF_SIZE - 10
	for i = 1, count do
		local x, z
		if ev.shape == "ring" then
			local angle = a + i / count * math.pi * 2
			x, z = center.X + math.cos(angle) * 42, center.Z + math.sin(angle) * 42
		elseif ev.shape == "line" then
			local side = (i - (count + 1) / 2) * 7
			local dx, dz = math.cos(a), math.sin(a)
			x, z = center.X + dx * 50 - dz * side, center.Z + dz * 50 + dx * side
		else
			local d = 58 + math.random() * 10
			x = center.X + math.cos(a) * d + math.random(-8, 8)
			z = center.Z + math.sin(a) * d + math.random(-8, 8)
		end
		x = math.clamp(x, run.map.center.X - edge, run.map.center.X + edge)
		z = math.clamp(z, run.map.center.Z - edge, run.map.center.Z + edge)
		Enemies.spawn(ev.kind or pickKind(minutes, run.map.index), x, z, hpScale, dmgScale, run.key)
	end
end

local function sendWave(run, info)
	for player in run.players do
		remotes.Wave:FireClient(player, info)
	end
end

-- Starts wave `wave` of `total`: shows the banner, then the event squad (and every few waves a
-- Vice Admiral) lands a moment later.
local function startWave(run, wave, total, crew, hpScale, dmgScale, minutes)
	for player in run.players do
		Rewards.best(player, "wave", wave)
	end
	local event = wave > 1 and pickEvent(wave, run.map.index) or nil
	local mini = wave % Config.MINIBOSS_WAVE == 0
	local info = { n = wave, total = total, title = "THE MARINES ARE COMING", sub = "Survive and grow stronger", color = Color3.fromRGB(120, 200, 255) }
	if event then
		info.title, info.sub, info.color = event.title, event.sub, event.color
	end
	if mini then
		info.title = "VICE ADMIRAL" .. (event and "  +  " .. event.title or "")
		info.sub = "A Vice Admiral leads this wave!"
		info.color = Color3.fromRGB(190, 90, 255)
	end
	sendWave(run, info)
	task.delay(1.5, function()
		if run.ending or runs[run.key] ~= run then
			return
		end
		if event then
			spawnSquad(event, run, wave, crew, hpScale, dmgScale, minutes)
		end
		if mini then
			spawnAround("MiniBoss", run, runTargets(run), hpScale, dmgScale)
		end
	end)
end

-- Brings a knocked-out player back where they fell. how = "crew" (a crewmate's circle) or "item".
local function bringBack(player, run, pos, health)
	local s = Progression.get(player)
	s.dead = false
	s.invulnerableUntil = os.clock() + 3
	removeCircle(player)
	Guard.allowTeleport(player, 5)
	player:LoadCharacter()
	task.spawn(function()
		sendToArena(player, pos, true)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and health < 1 then
			task.wait(0.2)
			hum.Health = hum.MaxHealth * health
		end
	end)
end

-- Crewmates standing in a revive circle fill it up; it drains slowly when they step out.
local function updateCircles(run, targets, dt)
	for player, down in downs do
		if down.run == run and runOf[player] == run then
			local helper
			for _, t in targets do
				if t.player ~= player and Vector3.new(t.root.Position.X - down.pos.X, 0, t.root.Position.Z - down.pos.Z).Magnitude <= Config.CREW_REVIVE.radius then
					helper = t.player
					break
				end
			end
			down.progress = helper and down.progress + dt or math.max(0, down.progress - dt * 0.5)
			down.fill.Size = UDim2.fromScale(down.progress / Config.CREW_REVIVE.time, 1)
			if helper and down.progress >= Config.CREW_REVIVE.time then
				bringBack(player, run, down.pos, Config.CREW_REVIVE.health)
				announce(run, helper.DisplayName .. " revived " .. player.DisplayName .. "!", Config.RARITIES.Legendary)
				Rewards.stat(helper, "revives", 1)
			end
		elseif downs[player] and runOf[player] ~= down.run then
			removeCircle(player)
		end
	end
end

-- Once a second: Regeneration heals its owner, and healers (Chopper) heal everyone nearby.
local function healers(targets)
	for _, t in targets do
		local regen = Progression.bonus(t.s, "regen")
		if regen > 0 then
			t.hum.Health = math.min(t.hum.MaxHealth, t.hum.Health + regen)
		end
	end
	for _, healer in targets do
		local amount = Progression.bonus(healer.s, "heal")
		if amount > 0 then
			for _, t in targets do
				if (t.root.Position - healer.root.Position).Magnitude <= 30 then
					t.hum.Health = math.min(t.hum.MaxHealth, t.hum.Health + amount)
				end
			end
		end
	end
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function playRun(run)
	local map, diff = run.map, run.diff
	local waves = math.max(1, math.floor(diff.runLength / Config.WAVE_LENGTH))
	local wave = 0
	local lastTick = 0
	local boss, bossAt, enraged
	task.wait(1) -- let the crew land
	while true do
		local elapsed = os.clock() - run.start
		local minutes = elapsed / 60
		local targets = runTargets(run)
		if #targets == 0 then
			return "Defeat"
		end

		updateCircles(run, targets, 0.25)
		local crew = 1 + 0.3 * (#targets - 1)
		local hpScale = (1 + minutes * 0.4) * crew * map.hp * diff.hp
		local dmgScale = (1 + minutes * 0.15) * map.damage * diff.damage
		local desired = math.min(Config.MAX_ENEMIES, math.floor((15 + minutes * 12) * crew))
		for _ = 1, math.min(4, desired - Enemies.count(run.key)) do
			spawnAround(pickKind(minutes, map.index), run, targets, hpScale, dmgScale)
		end
		local due = math.min(waves, math.floor(elapsed / Config.WAVE_LENGTH) + 1)
		if due > wave and elapsed < diff.runLength then
			wave = due
			startWave(run, wave, waves, crew, hpScale, dmgScale, minutes)
		end
		if elapsed >= diff.runLength then
			if not boss then
				local look = { name = map.boss, color = map.bossColor, accent = map.bossAccent }
				boss = spawnAround("Boss", run, targets, crew * map.hp * diff.hp, map.damage * diff.damage, look)
				if boss then
					bossAt = elapsed
					sendWave(run, {
						n = "FINAL", total = waves, title = map.boss:upper(), boss = true,
						sub = string.format("Defeat them within %d:%02d!", Config.BOSS_TIME_LIMIT // 60, Config.BOSS_TIME_LIMIT % 60),
						color = Color3.fromRGB(255, 60, 60),
					})
				end
			elseif boss.dead then
				return "Victory"
			elseif elapsed - bossAt >= Config.BOSS_TIME_LIMIT then
				announce(run, "Time's up! The Marines hold the line.", Color3.fromRGB(255, 60, 60))
				return "Defeat"
			elseif not enraged and elapsed - bossAt >= Config.BOSS_ENRAGE_AT then
				enraged = true
				boss.damage *= 1.75
				announce(run, map.boss .. " is ENRAGED!", Color3.fromRGB(255, 40, 40))
			end
		end

		if os.clock() - lastTick >= 1 then
			lastTick = os.clock()
			healers(targets)
			local text = not boss and clock(diff.runLength - elapsed)
				or "BOSS  " .. clock(Config.BOSS_TIME_LIMIT - (elapsed - bossAt))
			local crewIds = {}
			for player in run.players do
				table.insert(crewIds, player.UserId)
			end
			for player in run.players do
				local s = Progression.get(player)
				remotes.State:FireClient(player, {
					phase = "Run", text = text, adventure = map.name .. "  -  " .. diff.name, color = diff.color,
					down = s ~= nil and s.dead, boss = boss ~= nil, crew = crewIds, map = map.key, theme = map.theme,
					wave = wave, waves = waves, waveLeft = not boss and math.max(0, wave * Config.WAVE_LENGTH - elapsed) or nil,
				})
				Progression.sync(player)
			end
		end
		task.wait(0.25)
	end
end

local function finishRun(run, result)
	run.ending = true
	for player, down in downs do
		if down.run == run then
			removeCircle(player)
		end
	end
	for player in run.players do
		reward(player, run, result)
		remotes.State:FireClient(player, { phase = "Results", text = result == "Victory" and "VICTORY!" or "DEFEATED" })
		Weapons.cleanup(player)
		Progression.stop(player)
	end
	Enemies.clear(run.key)
	task.wait(Config.RESULTS_TIME)
	for player in run.players do
		sendHome(player)
	end
	runs[run.key] = nil
end

local function startRun(map, difficulty, crew)
	local diff = Config.Difficulties[difficulty]
	local run = { key = map.key, map = map, diff = diff, difficulty = difficulty, players = {}, start = os.clock() }
	runs[map.key] = run
	for _, player in crew do
		local data = PlayerData.get(player)
		if player.Parent and data and not runOf[player] then
			run.players[player] = true
			runOf[player] = run
			local extra = PlayerData.gearBonus(player)
			for stat, value in Monetization.bonus(player) do
				extra[stat] = (extra[stat] or 0) + value
			end
			Progression.start(player, classOf(player), data, extra)
			Progression.applyStats(player)
			Progression.sync(player)
			remotes.State:FireClient(player, {
				phase = "Run", text = "Set sail!", adventure = map.name .. "  -  " .. diff.name, color = diff.color,
				map = map.key, theme = map.theme,
			})
			task.spawn(sendToArena, player, map.center)
		end
	end
	finishRun(run, playRun(run))
end

-- Revives a knocked-out player in their run using one revive (from the store).
local function revive(player)
	local run, s, data = runOf[player], Progression.get(player), PlayerData.get(player)
	if not (run and not run.ending and s and s.dead and data and data.revives > 0) then
		return false
	end
	data.revives -= 1
	local down = downs[player]
	bringBack(player, run, down and down.pos or run.map.center, 1)
	announce(run, player.DisplayName .. " is back in the fight!", Config.RARITIES.Legendary)
	PlayerData.requestSave(player)
	sendMeta(player)
	return true
end

-- Player requests -------------------------------------------------------------------------

remotes.Choose.OnServerEvent:Connect(Guard.limit("choose", 8, function(player, index)
	if typeof(index) == "number" then
		Progression.choose(player, index)
	end
end))
remotes.Reroll.OnServerEvent:Connect(Guard.limit("reroll", 4, Progression.reroll))
remotes.Meta.OnServerEvent:Connect(Guard.limit("meta", 2, sendMeta))
local function selectClass(player, name)
	selectedClass[player] = name
	Gear.apply(player.Character, name)
	sendMeta(player)
end
remotes.SelectClass.OnServerEvent:Connect(Guard.limit("class", 4, function(player, name)
	if not runOf[player] and typeof(name) == "string" and PlayerData.hasClass(player, name) then
		selectClass(player, name)
	end
end))
-- Pirates are bought with gold; buying one also picks it.
remotes.UnlockClass.OnServerEvent:Connect(Guard.limit("unlock", 2, function(player, name)
	if not runOf[player] and typeof(name) == "string" and PlayerData.unlockClass(player, name) then
		PlayerData.requestSave(player)
		Rewards.achieve(player, "FirstPirate")
		local data = PlayerData.get(player)
		local all = true
		for className in Config.Classes do
			all = all and data.classes[className] == true
		end
		if all then
			Rewards.achieve(player, "FullCrew")
		end
		selectClass(player, name)
	end
end))
remotes.BuyMeta.OnServerEvent:Connect(Guard.limit("buy", 5, function(player, name)
	if not runOf[player] and typeof(name) == "string" and PlayerData.buy(player, name) then
		PlayerData.requestSave(player)
		sendMeta(player)
	end
end))
remotes.Train.OnServerEvent:Connect(Guard.limit("train", 5, function(player, kind, name)
	if not runOf[player] and typeof(kind) == "string" and typeof(name) == "string" and PlayerData.train(player, kind, name) then
		PlayerData.requestSave(player)
		sendMeta(player)
	end
end))
remotes.Gear.OnServerEvent:Connect(Guard.limit("gear", 5, function(player, action, id)
	if runOf[player] or typeof(action) ~= "string" or typeof(id) ~= "string" then
		return
	end
	local changed = action == "buy" and PlayerData.buyGear(player, id)
		or action == "equip" and PlayerData.equipGear(player, id)
		or action == "upgrade" and PlayerData.upgradeGear(player, id)
	if changed then
		PlayerData.requestSave(player)
		sendMeta(player)
	end
end))
-- The captain of a gate picks where the crew sails.
remotes.Voyage.OnServerEvent:Connect(Guard.limit("voyage", 4, function(player, mapKey, difficulty)
	if typeof(mapKey) ~= "string" or typeof(difficulty) ~= "number" then
		return
	end
	for _, gate in gates do
		if gate.captain == player then
			if PlayerData.unlocked(player, mapKey, difficulty) and not runs[mapKey] then
				gate.map, gate.difficulty, gate.launchAt = mapKey, difficulty, nil
			end
			return
		end
	end
end))
-- The client moves the character; the server grants the dash's moment of safety and shows it.
remotes.Dash.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastDash[player] or 0) < Monetization.dashCooldown(player) * 0.9 then
		return
	end
	lastDash[player] = now
	Guard.dashed(player)
	local s = Progression.get(player)
	if s and not s.dead then
		s.invulnerableUntil = math.max(s.invulnerableUntil, now + Config.DASH.invulnerable)
	end
	Fx.emit("dash", { p = player })
end)
-- Leaving keeps the gold earned so far (no victory bonus).
remotes.Leave.OnServerEvent:Connect(Guard.limit("leave", 1, function(player)
	local run = runOf[player]
	if run and not run.ending then
		reward(player, run, "Defeat")
		run.players[player] = nil
		sendHome(player)
	end
end))
remotes.Revive.OnServerEvent:Connect(Guard.limit("revive", 1, revive))
Rewards.init(remotes, sendMeta)

Monetization.onChanged = function(player)
	sendMeta(player)
	if Monetization.owns(player, "VIP") and player.Character then
		task.spawn(addVipTag, player.Character)
	end
end
Monetization.onRevive = revive

-- Voyage gates ----------------------------------------------------------------------------

-- The first player on a pad is captain; when the countdown ends, the crew sails.
local function updateGate(index, gate)
	local aboard = {}
	for _, player in Portals.playersInside(index) do
		if not runOf[player] then
			table.insert(aboard, player)
		end
	end
	if not table.find(aboard, gate.captain) then
		-- the captain stepped off: the next player in line takes over and picks again
		gate.captain, gate.map, gate.difficulty, gate.launchAt = aboard[1], nil, nil, nil
	end
	if gate.map and runs[gate.map] then
		gate.map, gate.difficulty, gate.launchAt = nil, nil, nil -- another crew got there first
	end
	local map = gate.map and Config.MapByKey[gate.map]
	local diff = gate.difficulty and Config.Difficulties[gate.difficulty]

	local status
	if not gate.captain then
		status = "Step in to choose an adventure"
	elseif not map then
		status = gate.captain.DisplayName .. " is choosing an adventure..."
	else
		gate.launchAt = gate.launchAt or os.clock() + Config.PORTAL_COUNTDOWN
		local left = math.ceil(gate.launchAt - os.clock())
		if left <= 0 then
			status = "Setting sail!"
			local difficulty = gate.difficulty
			gate.captain, gate.map, gate.difficulty, gate.launchAt = nil, nil, nil, nil
			task.spawn(startRun, map, difficulty, aboard)
		else
			status = string.format("%s - %s  |  %d aboard  |  sailing in %d", map.name, diff.name, #aboard, left)
		end
	end
	Portals.setStatus(index, status)
	local busy = {}
	for key in runs do
		busy[key] = true
	end
	for _, player in aboard do
		remotes.Portal:FireClient(player, {
			gate = index, color = Config.GATE_COLORS[index], text = status,
			captain = player == gate.captain, captainName = gate.captain and gate.captain.DisplayName,
			map = gate.map, difficulty = gate.difficulty, busy = busy,
		})
	end
end

while true do
	for index, gate in gates do
		updateGate(index, gate)
	end
	task.wait(0.25)
end
