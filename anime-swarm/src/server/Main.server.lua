-- Game flow:
--   Spawn island: pick a character, buy upgrades, step onto an adventure portal's pad.
--   When the portal's countdown ends, everyone on the pad sails to that adventure's arena.
--   Each adventure runs on its own until its boss falls or its whole crew is down.
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

Players.CharacterAutoLoads = false

local remotes = {}
local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "Remotes"
for _, name in {
	"State", "Stats", "LevelUp", "Choose", "Reroll", "SelectClass", "BuyMeta", "Meta", "Results", "Fx", "Portal", "Announce",
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

local LOBBY_TEXT = "Step into a portal to start an adventure!"
local selectedClass = {}
local runOf = {} -- [player] = the run they are in (nil = on the spawn island)
local runs = {} -- [adventureKey] = run in progress

local function sendMeta(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local costs = {}
	for name, m in Config.Meta do
		costs[name] = data.meta[name] < m.max and PlayerData.metaCost(name, data.meta[name]) or false
	end
	remotes.Meta:FireClient(player, {
		gold = data.gold, levels = data.meta, costs = costs,
		class = selectedClass[player] or Config.DEFAULT_CLASS,
	})
end

local function sendLobby(player)
	remotes.State:FireClient(player, { phase = "Lobby", text = LOBBY_TEXT })
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

local function onCharacter(player, character)
	local hum = character:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		local s = Progression.get(player)
		if runOf[player] and s then
			-- out until the crew's adventure ends
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
end

local function onPlayerAdded(player)
	PlayerData.load(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player:LoadCharacter()
	sendMeta(player)
	sendLobby(player)
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
	Weapons.cleanup(player)
	Progression.stop(player)
	selectedClass[player] = nil
	PlayerData.release(player)
end)

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
		sendMeta(player)
	end
end)
remotes.BuyMeta.OnServerEvent:Connect(function(player, name)
	if not runOf[player] and typeof(name) == "string" and PlayerData.buy(player, name) then
		sendMeta(player)
	end
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
			table.insert(targets, { player = player, s = s, root = root, hum = hum, magnet = Progression.magnet(s) })
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

local function spawnAround(kind, run, targets, hpScale, dmgScale)
	-- only around crew members who have landed in the arena
	local landed = {}
	for _, t in targets do
		local offset = t.root.Position - run.adv.center
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
		local e = Enemies.spawn(kind, p.X + math.cos(a) * d, p.Z + math.sin(a) * d, hpScale, dmgScale, run.key)
		if e then
			return e
		end
	end
	-- the player is near the edge of the map: spawn close instead
	return Enemies.spawn(kind, p.X, p.Z + 15, hpScale, dmgScale, run.key)
end

local function pickKind(minutes)
	local r = math.random()
	if minutes >= 3 and r < 0.12 then
		return "Brute"
	elseif minutes >= 1 and r < 0.35 then
		return "Runner"
	end
	return "Grunt"
end

local function healers(targets)
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

local function announce(run, text, color)
	for player in run.players do
		remotes.Announce:FireClient(player, text, color)
	end
end

local function playRun(run)
	local adv = run.adv
	local start = os.clock()
	local nextMini = Config.MINIBOSS_EVERY
	local lastTick = 0
	local boss
	task.wait(1) -- let the crew land
	while true do
		local elapsed = os.clock() - start
		local minutes = elapsed / 60
		local targets = runTargets(run)
		if #targets == 0 then
			return "Defeat", elapsed
		end

		local crew = 1 + 0.3 * (#targets - 1)
		local hpScale = (1 + minutes * 0.4) * crew * adv.hp
		local dmgScale = (1 + minutes * 0.15) * adv.damage
		local desired = math.min(Config.MAX_ENEMIES, math.floor((15 + minutes * 12) * crew))
		for _ = 1, math.min(4, desired - Enemies.count(run.key)) do
			spawnAround(pickKind(minutes), run, targets, hpScale, dmgScale)
		end
		if elapsed >= nextMini and elapsed < adv.runLength then
			nextMini += Config.MINIBOSS_EVERY
			if spawnAround("MiniBoss", run, targets, hpScale, dmgScale) then
				announce(run, "A Vice Admiral appeared!", Color3.fromRGB(190, 90, 255))
			end
		end
		if elapsed >= adv.runLength then
			if not boss then
				boss = spawnAround("Boss", run, targets, crew * adv.hp, adv.damage)
				if boss then
					announce(run, "The Admiral has arrived!", Color3.fromRGB(255, 60, 60))
				end
			elseif boss.dead then
				return "Victory", elapsed
			end
		end

		if os.clock() - lastTick >= 1 then
			lastTick = os.clock()
			healers(targets)
			local left = math.ceil(adv.runLength - elapsed)
			local clock = left > 0 and string.format("%d:%02d", left // 60, left % 60) or "FINAL BOSS!"
			for player in run.players do
				local s = Progression.get(player)
				remotes.State:FireClient(player, {
					phase = "Run", text = clock, adventure = adv.name, color = adv.color, down = s ~= nil and s.dead,
				})
				Progression.sync(player)
			end
		end
		task.wait(0.25)
	end
end

local function finishRun(run, result, elapsed)
	local adv = run.adv
	for player in run.players do
		local s, data = Progression.get(player), PlayerData.get(player)
		if s and data then
			local gold = s.kills + math.floor(elapsed / 10) + s.bonusGold + (result == "Victory" and 500 or 0)
			gold = math.floor(gold * adv.gold * (1 + Progression.bonus(s, "gold")))
			data.gold += gold
			task.spawn(PlayerData.save, player)
			remotes.Results:FireClient(player, {
				result = result, adventure = adv.name, color = adv.color,
				gold = gold, kills = s.kills, level = s.level, time = math.floor(elapsed),
			})
			remotes.State:FireClient(player, { phase = "Results", text = result == "Victory" and "VICTORY!" or "DEFEATED" })
		end
		Weapons.cleanup(player)
		Progression.stop(player)
	end
	Enemies.clear(run.key)
	task.wait(Config.RESULTS_TIME)
	for player in run.players do
		runOf[player] = nil
		if player.Parent then
			player:LoadCharacter() -- back to the spawn island with default stats
			sendMeta(player)
			sendLobby(player)
		end
	end
	runs[run.key] = nil
end

local function startRun(key, crew)
	local adv = Config.Adventures[key]
	local run = { key = key, adv = adv, players = {} }
	runs[key] = run
	for _, player in crew do
		local data = PlayerData.get(player)
		if player.Parent and data and not runOf[player] then
			run.players[player] = true
			runOf[player] = run
			Progression.start(player, selectedClass[player] or Config.DEFAULT_CLASS, data.meta)
			Progression.applyStats(player)
			Progression.sync(player)
			remotes.State:FireClient(player, { phase = "Run", text = "Set sail!", adventure = adv.name, color = adv.color })
			task.spawn(sendToArena, player, adv.center)
		end
	end
	finishRun(run, playRun(run))
end

-- Portal boarding: whoever stands on a pad when its countdown ends sets sail together.
local launchAt = {} -- [adventureKey] = os.clock() when that portal launches
while true do
	for _, key in Config.ADVENTURE_ORDER do
		local adv = Config.Adventures[key]
		local aboard = {}
		for _, player in Portals.playersInside(key) do
			if not runOf[player] then
				table.insert(aboard, player)
			end
		end
		local status
		if runs[key] then
			launchAt[key] = nil
			status = "Adventure in progress..."
		elseif #aboard == 0 then
			launchAt[key] = nil
			status = "Step in to set sail!"
		else
			launchAt[key] = launchAt[key] or os.clock() + Config.PORTAL_COUNTDOWN
			local left = math.ceil(launchAt[key] - os.clock())
			if left <= 0 then
				launchAt[key] = nil
				status = "Setting sail!"
				task.spawn(startRun, key, aboard)
			else
				status = string.format("%d aboard  -  sailing in %d", #aboard, left)
			end
		end
		Portals.setStatus(key, status)
		for _, player in aboard do
			remotes.Portal:FireClient(player, {
				name = adv.name, difficulty = adv.difficulty, stars = adv.stars, color = adv.color, text = status,
			})
		end
	end
	task.wait(0.25)
end
