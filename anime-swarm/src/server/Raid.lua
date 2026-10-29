-- The raid gate on the island: every so often it opens for a minute and everyone standing on it
-- sails together to fight a giant raid boss (Main starts the run through Raid.onLaunch).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(RS.Shared.Config)

local Raid = {}
Raid.canJoin = function(_player)
	return true
end
Raid.busy = function()
	return false
end
Raid.onLaunch = function(_players) end
Raid.announce = function(_text) end

local RAID = Config.RAID
local status -- TextLabel over the gate
local pad
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local function makePart(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanTouch = true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

function Raid.build()
	local hit = workspace:Raycast(RAID.gate + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0))
	local y = hit and hit.Position.Y or RAID.gate.Y
	local base = Vector3.new(RAID.gate.X, y, RAID.gate.Z)
	local model = Instance.new("Model")
	model.Name = "RaidGate"
	local size = RAID.radius * 2
	makePart({ Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, size + 4, size + 4), CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0)) * UPRIGHT, Color = Color3.fromRGB(80, 85, 95), Material = Enum.Material.Slate }, model)
	pad = makePart({
		Name = "Whirlpool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, size, size), CFrame = CFrame.new(base + Vector3.new(0, 1.05, 0)) * UPRIGHT,
		Color = Color3.fromRGB(30, 90, 140), Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false,
	}, model)
	-- swirling blades (spun by client/Effects like the voyage gates' swirls)
	local center = CFrame.new(base + Vector3.new(0, 1.3, 0)) * CFrame.Angles(math.pi / 2, 0, 0)
	for i = 1, 6 do
		local blade = makePart({
			Name = "Swirl", Size = Vector3.new(RAID.radius * 1.8, 0.6, 0.15), CFrame = center, Color = Color3.fromRGB(120, 220, 255),
			Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, CanQuery = false,
		}, model)
		blade:SetAttribute("Center", center)
		blade:SetAttribute("Phase", i * math.pi / 3)
		CollectionService:AddTag(blade, "PortalSwirl")
	end
	-- tentacles rising from the water, and a big sign
	for i = 1, 5 do
		local a = i * math.pi * 2 / 5
		local pos = base + Vector3.new(math.cos(a) * (RAID.radius + 2), 0, math.sin(a) * (RAID.radius + 2))
		for j = 0, 3 do
			makePart({
				Name = "Tentacle", Shape = Enum.PartType.Ball, Size = Vector3.one * (2.2 - j * 0.45),
				Position = pos + Vector3.new(math.cos(a) * j * 0.5, 1 + j * 1.6, math.sin(a) * j * 0.5),
				Color = Color3.fromRGB(60, 150, 170), Material = Enum.Material.SmoothPlastic, CanCollide = j == 0,
			}, model)
		end
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(80, 200, 255), 20, 2
	light.Parent = pad
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(320, 90)
	board.StudsOffset = Vector3.new(0, 9, 0)
	board.MaxDistance = 220
	board.LightInfluence = 0
	board.Parent = pad
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 44)
	title.BackgroundTransparency = 1
	title.Text = "🐙 RAID GATE"
	title.TextScaled = true
	title.Font = Enum.Font.LuckiestGuy
	title.TextColor3 = Color3.fromRGB(120, 220, 255)
	title.TextStrokeTransparency = 0
	title.Parent = board
	status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, 0, 0, 34)
	status.Position = UDim2.fromOffset(0, 48)
	status.BackgroundTransparency = 1
	status.TextScaled = true
	status.Font = Enum.Font.FredokaOne
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextStrokeTransparency = 0.2
	status.Parent = board
	model.Parent = workspace
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function playersOnPad()
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and Raid.canJoin(player) then
			local d = Vector3.new(root.Position.X - RAID.gate.X, 0, root.Position.Z - RAID.gate.Z).Magnitude
			if d <= RAID.radius then
				table.insert(list, player)
			end
		end
	end
	return list
end

task.spawn(function()
	local nextAt = os.clock() + RAID.first
	local closeAt
	while true do
		task.wait(0.25)
		if not status then
			continue
		end
		local now = os.clock()
		if closeAt then
			local aboard = playersOnPad()
			status.Text = string.format("OPEN! Step in - sailing in %s  (%d aboard)", clock(closeAt - now), #aboard)
			pad.Color = Color3.fromRGB(40, 160, 220)
			if now >= closeAt then
				closeAt = nil
				nextAt = now + RAID.every
				if #aboard > 0 then
					Raid.onLaunch(aboard)
				else
					Raid.announce("🐙 Nobody answered the raid... the Leviathan sinks back into the deep.")
				end
			end
		elseif Raid.busy() then
			status.Text = "A raid is under way!"
			pad.Color = Color3.fromRGB(30, 90, 140)
		elseif now >= nextAt then
			closeAt = now + RAID.open
			Raid.announce("🐙 THE LEVIATHAN RISES! The raid gate is open for " .. RAID.open .. "s - step in to join!")
		else
			status.Text = "Next raid in " .. clock(nextAt - now)
			pad.Color = Color3.fromRGB(30, 90, 140)
		end
	end
end)

return Raid
