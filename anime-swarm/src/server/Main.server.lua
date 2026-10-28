-- Game flow:
--   Spawn island: pick a character, train and gear up with the NPCs, step onto a voyage gate.
--   The first player on a pad is the captain and picks a map + difficulty they have unlocked.
--   When the gate's countdown ends, everyone on the pad sails to that map's arena.
--   Each adventure runs until its boss falls, its time runs out, or its whole crew is down.
--   Players can leave early (keeping the gold they earned) or be revived.
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

Players.CharacterAutoLoads = false

local remotes = {}
local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "Remotes"
for _, name in {
	"State", "Stats", "LevelUp", "Choose", "Reroll", "SelectClass", "BuyMeta", "Meta", "Results", "Fx", "Portal",
	"Announce", "Voyage", "Dash", "Leave", "Revive", "Train", "Gear",
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
Npcs.build()

local LOBBY_TEXT = "Step onto a voyage gate to choose an adventure!"
local selectedClass = {}
local runOf = {} -- [player] = the run they are in (nil = on the spawn island)
local runs = {} -- [mapKey] = run in progress (one crew per map at a time)
local lastDash = {} -- [player] = os.clock() of their last dash
local gates = {} -- [gateIndex] = { captain, map, difficulty, launchAt }
for i in Config.GATES do
	gates[i] = {}
end

local function classOf(player)
	return selectedClass[player] or Config.DEFAULT_CLASS
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
		revives = data.revives, boosts = boosts, passes = Monetization.ownedList(player),
		dashCooldown = Monetization.dashCooldown(player), loadFailed = data.loadFailed == true,
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

local function sendToArena(player, center)
	local character = player.Character
	local root = character and character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	local a = math.random() * 2 * math.pi
	local r = math.random() * Config.ARENA_DROP_RADIUS
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

local function onCharacter(player, character)
	local hum = character:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		local s = Progression.get(player)
		if runOf[player] and s then
			-- out until revived or the crew's adventure ends; they can watch or leave
			s.dead = true
			Weapons.cleanup(player)
			remotes.LevelUp:FireClient(player, nil)
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
	player:LoadCharacter()
	sendMeta(player)
	sendLobby(player)
	local data = PlayerData.get(player)
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
	Weapons.cleanup(player)
	Progression.stop(player)
	selectedClass[player] = nil
	Monetization.release(player)
	PlayerData.release(player)
end)

Enemies.onKilled = function(enemy, killer)
	local s = killer and Progression.get(killer)
	if s then
		s.kills += 1
		s.bonusGold += enemy.def.gold or 0
	end
end
Enemies.onPickup = Progression.addXP

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

-- Picks a free gear drop for a victory, or nil. Owning it already turns it into gold.
local function rollDrop(difficulty)
	local drops = Config.DROPS[difficulty]
	if math.random() > drops.chance then
		return nil
	end
	local total = 0
	for _, weight in drops.weights do
		total += weight
	end
	local roll, rarity = math.random() * total, "Common"
	for name, weight in drops.weights do
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
	local unlocked, drop
	if result == "Victory" then
		if PlayerData.recordClear(player, map.key, run.difficulty) then
			unlocked = unlockMessage(map, run.difficulty)
		end
		local item = rollDrop(run.difficulty)
		if item then
			if PlayerData.grantItem(player, item.id) then
				drop = { name = item.name, icon = item.icon, rarity = item.rarity }
			else
				gold += Config.DUPLICATE_GOLD[item.rarity]
				drop = { name = item.name, icon = item.icon, rarity = item.rarity, duplicate = Config.DUPLICATE_GOLD[item.rarity] }
			end
		end
	end
	data.gold += gold
	task.spawn(PlayerData.save, player)
	remotes.Results:FireClient(player, {
		result = result, adventure = map.name .. "  -  " .. diff.name, color = diff.color,
		gold = gold, kills = s.kills, level = s.level, time = math.floor(elapsed), unlocked = unlocked, drop = drop,
	})
end

-- Takes a player out of their run and back to the island.
local function sendHome(player)
	runOf[player] = nil
	Weapons.cleanup(player)
	Progression.stop(player)
	if player.Parent then
		player:LoadCharacter() -- back to the spawn island with default stats
		sendMeta(player)
		sendLobby(player)
	end
end

-- Running an adventure --------------------------------------------------------------------

local function spawnAround(kind, run, targets, hpScale, dmgScale, look)
	-- only around crew members who have landed in the arena
	local landed = {}
	for _, t in targets do
		local offset = t.root.Position - run.map.center
		if math.abs(offset.X) <= Config.ARENA_HALF_SIZE and math.abs(offset.Z) <= Config.ARENA_HALF_SIZE then
			table.insert(landed, t)
		end
	end
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
	local nextMini = Config.MINIBOSS_EVERY
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

		local crew = 1 + 0.3 * (#targets - 1)
		local hpScale = (1 + minutes * 0.4) * crew * map.hp * diff.hp
		local dmgScale = (1 + minutes * 0.15) * map.damage * diff.damage
		local desired = math.min(Config.MAX_ENEMIES, math.floor((15 + minutes * 12) * crew))
		for _ = 1, math.min(4, desired - Enemies.count(run.key)) do
			spawnAround(pickKind(minutes, map.index), run, targets, hpScale, dmgScale)
		end
		if elapsed >= nextMini and elapsed < diff.runLength then
			nextMini += Config.MINIBOSS_EVERY
			if spawnAround("MiniBoss", run, targets, hpScale, dmgScale) then
				announce(run, "A Vice Admiral appeared!", Color3.fromRGB(190, 90, 255))
			end
		end
		if elapsed >= diff.runLength then
			if not boss then
				local look = { name = map.boss, color = map.bossColor, accent = map.bossAccent }
				boss = spawnAround("Boss", run, targets, crew * map.hp * diff.hp, map.damage * diff.damage, look)
				if boss then
					bossAt = elapsed
					announce(run, map.boss .. " has arrived!", Color3.fromRGB(255, 60, 60))
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
					down = s ~= nil and s.dead, boss = boss ~= nil, crew = crewIds,
				})
				Progression.sync(player)
			end
		end
		task.wait(0.25)
	end
end

local function finishRun(run, result)
	run.ending = true
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
	s.dead = false
	s.invulnerableUntil = os.clock() + 3
	player:LoadCharacter()
	task.spawn(sendToArena, player, run.map.center)
	announce(run, player.DisplayName .. " is back in the fight!", Config.RARITIES.Legendary)
	task.spawn(PlayerData.save, player)
	sendMeta(player)
	return true
end

-- Player requests -------------------------------------------------------------------------

remotes.Choose.OnServerEvent:Connect(function(player, index)
	if typeof(index) == "number" then
		Progression.choose(player, index)
	end
end)
remotes.Reroll.OnServerEvent:Connect(Progression.reroll)
remotes.Meta.OnServerEvent:Connect(sendMeta)
remotes.SelectClass.OnServerEvent:Connect(function(player, name)
	if not runOf[player] and typeof(name) == "string" and Config.Classes[name] then
		selectedClass[player] = name
		Gear.apply(player.Character, name)
		sendMeta(player)
	end
end)
remotes.BuyMeta.OnServerEvent:Connect(function(player, name)
	if not runOf[player] and typeof(name) == "string" and PlayerData.buy(player, name) then
		sendMeta(player)
	end
end)
remotes.Train.OnServerEvent:Connect(function(player, kind, name)
	if not runOf[player] and typeof(kind) == "string" and typeof(name) == "string" and PlayerData.train(player, kind, name) then
		sendMeta(player)
	end
end)
remotes.Gear.OnServerEvent:Connect(function(player, action, id)
	if runOf[player] or typeof(action) ~= "string" or typeof(id) ~= "string" then
		return
	end
	local changed = action == "buy" and PlayerData.buyGear(player, id) or action == "equip" and PlayerData.equipGear(player, id)
	if changed then
		sendMeta(player)
	end
end)
-- The captain of a gate picks where the crew sails.
remotes.Voyage.OnServerEvent:Connect(function(player, mapKey, difficulty)
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
end)
-- The client moves the character; the server grants the dash's moment of safety and shows it.
remotes.Dash.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastDash[player] or 0) < Monetization.dashCooldown(player) * 0.9 then
		return
	end
	lastDash[player] = now
	local s = Progression.get(player)
	if s and not s.dead then
		s.invulnerableUntil = math.max(s.invulnerableUntil, now + Config.DASH.invulnerable)
	end
	Fx.emit("dash", { p = player })
end)
-- Leaving keeps the gold earned so far (no victory bonus).
remotes.Leave.OnServerEvent:Connect(function(player)
	local run = runOf[player]
	if run and not run.ending then
		reward(player, run, "Defeat")
		run.players[player] = nil
		sendHome(player)
	end
end)
remotes.Revive.OnServerEvent:Connect(revive)

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
