local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")

local waveInfo = Instance.new("RemoteEvent")
waveInfo.Name = "WaveInfo"
waveInfo.Parent = RS

local upgrade = Instance.new("RemoteEvent")
upgrade.Name = "BuyDamage"
upgrade.Parent = RS

local SPAWN_RADIUS = 80
local BETWEEN_WAVES = 8

Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name, coins.Parent = "Coins", stats
	local kills = Instance.new("IntValue")
	kills.Name, kills.Parent = "Kills", stats
	stats.Parent = player
	player:SetAttribute("DamageLevel", 0)
end)

upgrade.OnServerEvent:Connect(function(player)
	local coins = player:FindFirstChild("leaderstats") and player.leaderstats.Coins
	local level = player:GetAttribute("DamageLevel") or 0
	local cost = 50 * (level + 1)
	if coins and coins.Value >= cost then
		coins.Value -= cost
		player:SetAttribute("DamageLevel", level + 1)
	end
end)

local function makeEnemy(wave, position)
	local m = Instance.new("Model")
	m.Name = "Swarmling"

	local root = Instance.new("Part")
	root.Name, root.Size, root.Position = "HumanoidRootPart", Vector3.new(2, 2, 1), position
	root.Color = Color3.fromRGB(60 + math.min(wave * 8, 180), 20, 40)
	root.Parent = m
	local head = Instance.new("Part")
	head.Name, head.Shape, head.Size = "Head", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6)
	head.Color, head.Position = root.Color, position + Vector3.new(0, 1.8, 0)
	head.Parent = m
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = root, head, root

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 60 + wave * 25
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = math.min(10 + wave * 0.6, 24)
	hum.Parent = m
	m.PrimaryPart = root
	m.Parent = workspace
	CS:AddTag(m, "Enemy")

	hum.Died:Connect(function()
		local killer = Players:GetPlayerByUserId(hum:GetAttribute("LastHitBy") or 0)
		if killer and killer:FindFirstChild("leaderstats") then
			killer.leaderstats.Coins.Value += 5 + wave
			killer.leaderstats.Kills.Value += 1
		end
		task.wait(0.5)
		m:Destroy()
	end)

	-- chase nearest player and bite on contact
	task.spawn(function()
		local lastBite = 0
		while hum.Health > 0 and m.Parent do
			local best, bestDist
			for _, p in Players:GetPlayers() do
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				if r and h and h.Health > 0 then
					local d = (r.Position - root.Position).Magnitude
					if not bestDist or d < bestDist then best, bestDist = p, d end
				end
			end
			if best then
				hum:MoveTo(best.Character.HumanoidRootPart.Position)
				if bestDist < 4 and os.clock() - lastBite > 1 then
					lastBite = os.clock()
					best.Character.Humanoid:TakeDamage(5 + wave)
				end
			end
			task.wait(0.2)
		end
	end)
end

local function alive()
	return #CS:GetTagged("Enemy")
end

task.spawn(function()
	local wave = 0
	while true do
		while #Players:GetPlayers() == 0 do task.wait(1) end
		wave += 1
		for t = BETWEEN_WAVES, 1, -1 do
			waveInfo:FireAllClients(wave, "Starting in " .. t)
			task.wait(1)
		end
		local count = 5 + wave * 3
		for i = 1, count do
			local angle = math.random() * math.pi * 2
			makeEnemy(wave, Vector3.new(math.cos(angle) * SPAWN_RADIUS, 4, math.sin(angle) * SPAWN_RADIUS))
			waveInfo:FireAllClients(wave, ("Enemies left: %d"):format(alive()))
			task.wait(0.4)
		end
		while alive() > 0 do
			waveInfo:FireAllClients(wave, ("Enemies left: %d"):format(alive()))
			task.wait(0.5)
		end
	end
end)
