local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Skills = require(RS.Shared.SkillConfig)

local useSkill = Instance.new("RemoteEvent")
useSkill.Name = "UseSkill"
useSkill.Parent = RS

local lastUsed = {} -- [player] = {[index] = os.clock()}

local function fx(cf, size, color, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery = true, false, false
	p.Material, p.Color, p.Transparency = Enum.Material.Neon, color, 0.3
	p.Shape = shape or Enum.PartType.Block
	p.Size, p.CFrame = size, cf
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.5)
end

local function hit(player, humanoid, amount)
	humanoid:SetAttribute("LastHitBy", player.UserId)
	humanoid:TakeDamage(amount)
end

local function damageMult(player)
	return 1 + (player:GetAttribute("DamageLevel") or 0) * 0.25
end

local function enemies()
	local list = {}
	for _, m in CS:GetTagged("Enemy") do
		local hum, root = m:FindFirstChildOfClass("Humanoid"), m:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			table.insert(list, { hum = hum, root = root })
		end
	end
	return list
end

local handlers = {}

function handlers.cone(player, root, s, dmg)
	local look = root.CFrame.LookVector
	fx(root.CFrame * CFrame.new(0, 0, -s.range / 2), Vector3.new(s.range, 1, s.range), s.color)
	for _, e in enemies() do
		local d = e.root.Position - root.Position
		if d.Magnitude <= s.range and d.Unit:Dot(look) > math.cos(math.rad(s.angle / 2)) then
			hit(player, e.hum, dmg)
		end
	end
end

function handlers.dash(player, root, s, dmg)
	local start, dir = root.Position, root.CFrame.LookVector
	root.AssemblyLinearVelocity = dir * (s.range / 0.2)
	fx(CFrame.lookAt(start + dir * s.range / 2, start + dir * s.range), Vector3.new(s.width, s.width, s.range), s.color)
	local hitSet = {}
	for _ = 1, 6 do
		task.wait(0.04)
		for _, e in enemies() do
			if not hitSet[e.hum] and (e.root.Position - root.Position).Magnitude <= s.width then
				hitSet[e.hum] = true
				hit(player, e.hum, dmg)
			end
		end
	end
end

function handlers.aoe(player, root, s, dmg)
	fx(root.CFrame, Vector3.one * s.range * 2, s.color, Enum.PartType.Ball)
	for _, e in enemies() do
		if (e.root.Position - root.Position).Magnitude <= s.range then
			hit(player, e.hum, dmg)
		end
	end
end

function handlers.pull(player, root, s, dmg)
	local center = root.Position + root.CFrame.LookVector * s.range
	fx(CFrame.new(center), Vector3.one * s.radius * 2, s.color, Enum.PartType.Ball)
	local caught = {}
	for _, e in enemies() do
		if (e.root.Position - center).Magnitude <= s.radius * 1.5 then
			table.insert(caught, e)
			e.root.CFrame = CFrame.new(center + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
		end
	end
	task.wait(0.5)
	for _, e in caught do
		if e.hum.Health > 0 then hit(player, e.hum, dmg) end
	end
end

function handlers.beam(player, root, s, dmg)
	local origin, dir = root.Position, root.CFrame.LookVector
	fx(CFrame.lookAt(origin + dir * s.range / 2, origin + dir * s.range), Vector3.new(s.width, s.width, s.range), s.color)
	for _, e in enemies() do
		local rel = e.root.Position - origin
		local along = rel:Dot(dir)
		if along > 0 and along <= s.range and (rel - dir * along).Magnitude <= s.width then
			hit(player, e.hum, dmg)
		end
	end
end

useSkill.OnServerEvent:Connect(function(player, index)
	local s = type(index) == "number" and Skills[index]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not s or not root then return end

	lastUsed[player] = lastUsed[player] or {}
	if os.clock() - (lastUsed[player][index] or -1e9) < s.cooldown then return end
	lastUsed[player][index] = os.clock()

	handlers[s.kind](player, root, s, s.damage * damageMult(player))
end)

Players.PlayerRemoving:Connect(function(p) lastUsed[p] = nil end)
