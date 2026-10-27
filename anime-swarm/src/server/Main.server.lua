-- Game loop: Lobby (pick class, buy upgrades) -> Run (survive, level up, boss) -> Results (gold).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(RS.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Enemies = require(script.Parent.Enemies)
local Progression = require(script.Parent.Progression)
local Weapons = require(script.Parent.Weapons)

Players.CharacterAutoLoads = false

local remotes = {}
local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "Remotes"
for _, name in { "State", "Stats", "LevelUp", "Choose", "Reroll", "SelectClass", "BuyMeta", "Meta", "Results" } do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remoteFolder
	remotes[name] = r
end
remoteFolder.Parent = RS
Progression.init(remotes)

local phase = "Lobby"
local selectedClass = {}

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

local function startPlayer(player)
	local data = PlayerData.get(player)
	if data then
		Progression.start(player, selectedClass[player] or Config.DEFAULT_CLASS, data.meta)
		Progression.sync(player)
	end
end

local function sendToArena(player)
	local character = player.Character
	local root = character and character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	task.wait(0.1) -- let Roblox finish placing the character at the spawn first
	local a = math.random() * 2 * math.pi
	local r = math.random() * Config.ARENA_DROP_RADIUS
	local c = Config.ARENA_CENTER
	character:PivotTo(CFrame.new(c.X + math.cos(a) * r, c.Y + 5, c.Z + math.sin(a) * r))
end

local function onCharacter(player, character)
	local hum = character:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		local s = Progression.get(player)
		if phase == "Run" and s then
			-- out for the rest of the run
			s.dead = true
			Weapons.cleanup(player)
			remotes.LevelUp:FireClient(player, nil)
			return
		end
		task.wait(3)
		if phase ~= "Run" and player.Parent then
			player:LoadCharacter()
		end
	end)
	if phase == "Run" then
		if not Progression.get(player) then
			startPlayer(player) -- joined mid-run
		end
		task.spawn(sendToArena, player)
	end
	Progression.applyStats(player)
end

local function onPlayerAdded(player)
	PlayerData.load(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player:LoadCharacter()
	sendMeta(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
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
	if phase ~= "Run" and typeof(name) == "string" and Config.Classes[name] then
		selectedClass[player] = name
		sendMeta(player)
	end
end)
remotes.BuyMeta.OnServerEvent:Connect(function(player, name)
	if phase ~= "Run" and typeof(name) == "string" and PlayerData.buy(player, name) then
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

local function liveTargets()
	local targets = {}
	for player, s in Progression.all() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not s.dead and root and hum and hum.Health > 0 then
			table.insert(targets, { player = player, s = s, root = root, hum = hum, magnet = Progression.magnet(s) })
		end
	end
	return targets
end

RunService.Heartbeat:Connect(function(dt)
	if phase == "Run" then
		Enemies.step(dt, liveTargets())
		Weapons.step(dt)
	end
end)

local function spawnAround(kind, targets, hpScale, dmgScale)
	-- only around players already in the arena, never on the spawn island
	local inArena = {}
	for _, t in targets do
		local offset = t.root.Position - Config.ARENA_CENTER
		if math.abs(offset.X) <= Config.ARENA_HALF_SIZE and math.abs(offset.Z) <= Config.ARENA_HALF_SIZE then
			table.insert(inArena, t)
		end
	end
	if #inArena == 0 then
		return nil
	end
	local p = inArena[math.random(#inArena)].root.Position
	for _ = 1, 6 do
		local a = math.random() * 2 * math.pi
		local d = Config.SPAWN_MIN + math.random() * (Config.SPAWN_MAX - Config.SPAWN_MIN)
		local e = Enemies.spawn(kind, p.X + math.cos(a) * d, p.Z + math.sin(a) * d, hpScale, dmgScale)
		if e then
			return e
		end
	end
	-- the player is near the edge of the map: spawn close instead
	return Enemies.spawn(kind, p.X, p.Z + 15, hpScale, dmgScale)
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

local function runGame()
	phase = "Run"
	for _, player in Players:GetPlayers() do
		startPlayer(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			Progression.applyStats(player)
			task.spawn(sendToArena, player)
		else
			player:LoadCharacter()
		end
	end

	local start = os.clock()
	local nextMini = Config.MINIBOSS_EVERY
	local lastTick = 0
	local boss
	while true do
		local elapsed = os.clock() - start
		local minutes = elapsed / 60
		local targets = liveTargets()
		if #targets == 0 then
			return "Defeat", elapsed
		end

		local playerFactor = 1 + 0.3 * (#targets - 1)
		local hpScale = (1 + minutes * 0.4) * playerFactor
		local dmgScale = 1 + minutes * 0.15
		local desired = math.min(Config.MAX_ENEMIES, math.floor((15 + minutes * 12) * playerFactor))
		for _ = 1, math.min(4, desired - Enemies.count()) do
			spawnAround(pickKind(minutes), targets, hpScale, dmgScale)
		end
		if elapsed >= nextMini and elapsed < Config.RUN_LENGTH then
			nextMini += Config.MINIBOSS_EVERY
			spawnAround("MiniBoss", targets, hpScale, dmgScale)
		end
		if elapsed >= Config.RUN_LENGTH then
			if not boss then
				boss = spawnAround("Boss", targets, playerFactor, 1)
			elseif boss.dead then
				return "Victory", elapsed
			end
		end

		if os.clock() - lastTick >= 1 then
			lastTick = os.clock()
			healers(targets)
			local left = math.ceil(Config.RUN_LENGTH - elapsed)
			remotes.State:FireAllClients({
				phase = "Run",
				text = left > 0 and string.format("%d:%02d", left // 60, left % 60) or "FINAL BOSS!",
			})
			for player in Progression.all() do
				Progression.sync(player)
			end
		end
		task.wait(0.25)
	end
end

local function endGame(result, elapsed)
	phase = "Results"
	for player, s in Progression.all() do
		local data = PlayerData.get(player)
		if data then
			local gold = s.kills + math.floor(elapsed / 10) + s.bonusGold + (result == "Victory" and 500 or 0)
			gold = math.floor(gold * (1 + Progression.bonus(s, "gold")))
			data.gold += gold
			task.spawn(PlayerData.save, player)
			remotes.Results:FireClient(player, {
				result = result, gold = gold, kills = s.kills, level = s.level, time = math.floor(elapsed),
			})
			sendMeta(player)
		end
	end
	Weapons.clear()
	Enemies.clear()
	Progression.clear()
	remotes.State:FireAllClients({ phase = "Results", text = result == "Victory" and "VICTORY!" or "DEFEATED" })
	task.wait(Config.RESULTS_TIME)
end

while true do
	phase = "Lobby"
	for _, player in Players:GetPlayers() do
		player:LoadCharacter() -- fresh character with default stats, back on the spawn island
	end
	local t = Config.INTERMISSION
	while t > 0 do
		if #Players:GetPlayers() > 0 then
			t -= 1
		end
		remotes.State:FireAllClients({ phase = "Lobby", text = "Setting sail in " .. t })
		task.wait(1)
	end
	endGame(runGame())
end
