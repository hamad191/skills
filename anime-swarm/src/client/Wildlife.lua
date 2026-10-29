-- Little bits of life, drawn only on this client: seagulls circling overhead, butterflies over the
-- island's grass, fish leaping out of the sea, and fireflies drifting around you on dark maps.
-- Purely visual; skipped in low graphics mode.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Effects = require(script.Parent.Effects)

local Wildlife = {}
local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "Wildlife"
folder.Parent = workspace

local theme = "island"
local mapCenter = Config.ISLAND_CENTER
local SEA_THEMES = { island = true, beach = true, ship = true, deepsea = true, mangrove = true, marine = true }
local NIGHT_THEMES = { spooky = true, jungle = true, prison = true, mangrove = true, wano = true }
local GULLS, BUTTERFLIES, FIREFLIES = 7, 12, 14

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.Parent = folder
	return p
end

-- A bird or a butterfly: a body and two wings that flap.
local function flyer(bodySize, wingSize, bodyColor, wingColor)
	local body = part({ Shape = Enum.PartType.Ball, Size = bodySize, Color = bodyColor })
	local left = part({ Size = wingSize, Color = wingColor })
	local right = part({ Size = wingSize, Color = wingColor })
	return { body = body, left = left, right = right, wing = wingSize }
end

local function place(f, cf, flap)
	f.body.CFrame = cf
	local half = f.wing.X / 2
	f.left.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-half, 0, 0)
	f.right.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(half, 0, 0)
end

local function setVisible(list, visible)
	for _, f in list do
		for _, p in { f.body, f.left, f.right } do
			p.Transparency = visible and 0 or 1
		end
	end
end

local gulls, butterflies, fireflies = {}, {}, {}
for i = 1, GULLS do
	local f = flyer(Vector3.new(1.4, 0.8, 0.8), Vector3.new(2.4, 0.12, 0.9), Color3.fromRGB(245, 245, 245), Color3.fromRGB(225, 228, 235))
	f.radius, f.height, f.speed, f.phase = 50 + math.random() * 90, 38 + math.random() * 25, 0.15 + math.random() * 0.12, math.random() * 6.28
	gulls[i] = f
end
local BUTTERFLY_COLORS = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 120, 180), Color3.fromRGB(120, 190, 255), Color3.fromRGB(255, 255, 255) }
for i = 1, BUTTERFLIES do
	local f = flyer(Vector3.new(0.15, 0.15, 0.4), Vector3.new(0.5, 0.05, 0.45), Color3.fromRGB(40, 30, 30), BUTTERFLY_COLORS[i % 4 + 1])
	local a, r = math.random() * 6.28, 20 + math.random() * 90
	f.home = Config.ISLAND_CENTER + Vector3.new(math.cos(a) * r, 3 + math.random() * 2, math.sin(a) * r)
	f.phase = math.random() * 6.28
	butterflies[i] = f
end
for i = 1, FIREFLIES do
	local fly = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.3, Color = Color3.fromRGB(220, 255, 120), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = fly.Color, 6, 1
	light.Parent = fly
	fireflies[i] = { part = fly, light = light, offset = Vector3.new(math.random(-30, 30), math.random(2, 7), math.random(-30, 30)), phase = math.random() * 6.28 }
end

-- A fish jumps out of the sea in an arc and splashes back.
local function jumpFish(near)
	local a = math.random() * 6.28
	local d = theme == "island" and 170 + math.random() * 60 or 520 + math.random() * 60
	local from = Vector3.new(near.X + math.cos(a) * d, -1.5, near.Z + math.sin(a) * d)
	local dir = Vector3.new(-math.sin(a), 0, math.cos(a)) * 8
	local fish = part({ Size = Vector3.new(0.6, 0.6, 1.6), Color = Color3.fromRGB(120, 170, 210), Material = Enum.Material.Metal, Transparency = 0 })
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) / 1.1
		if t >= 1 or not fish.Parent then
			conn:Disconnect()
			fish:Destroy()
			return
		end
		local pos = from + dir * t + Vector3.new(0, math.sin(t * math.pi) * 5, 0)
		local vel = dir + Vector3.new(0, math.cos(t * math.pi) * 5 * math.pi, 0)
		fish.CFrame = CFrame.lookAt(pos, pos + vel)
	end)
	for _, spot in { from, from + dir } do
		local splash = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Color = Color3.fromRGB(220, 240, 255), Transparency = 0.3, Position = spot })
		TweenService:Create(splash, TweenInfo.new(0.5), { Size = Vector3.one * 3, Transparency = 1 }):Play()
		Debris:AddItem(splash, 0.6)
	end
end

-- The current place: "island", or a map's theme and its arena center.
function Wildlife.set(newTheme, center)
	theme = newTheme or "island"
	mapCenter = center or Config.ISLAND_CENTER
end

local nextFish = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local low = Effects.settings.low
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local here = root and root.Position or workspace.CurrentCamera.Focus.Position

	-- seagulls: around the island, or around you on sea maps
	local showGulls = not low and SEA_THEMES[theme] == true
	setVisible(gulls, showGulls)
	if showGulls then
		local center = theme == "island" and Config.ISLAND_CENTER or here
		for _, f in gulls do
			local a = now * f.speed + f.phase
			local pos = Vector3.new(center.X + math.cos(a) * f.radius, (theme == "island" and 0 or here.Y) + f.height, center.Z + math.sin(a) * f.radius)
			local ahead = pos + Vector3.new(-math.sin(a), 0, math.cos(a))
			place(f, CFrame.lookAt(pos, ahead) * CFrame.Angles(0, 0, -0.25), math.sin(now * 6 + f.phase) * 0.5)
		end
	end

	-- butterflies flutter around their flowers on the island
	local showButterflies = not low and theme == "island"
	setVisible(butterflies, showButterflies)
	if showButterflies then
		for _, f in butterflies do
			local t = now * 0.8 + f.phase
			local pos = f.home + Vector3.new(math.cos(t) * 3, math.sin(t * 2.3) * 0.8, math.sin(t * 1.3) * 3)
			place(f, CFrame.lookAt(pos, pos + Vector3.new(-math.sin(t), 0, math.cos(t))), math.sin(now * 18 + f.phase) * 0.9)
		end
	end

	-- fireflies drift around you on dark maps
	local showFireflies = not low and NIGHT_THEMES[theme] == true
	for _, fly in fireflies do
		fly.part.Transparency = showFireflies and 0 or 1
		fly.light.Enabled = showFireflies
		if showFireflies then
			local t = now * 0.5 + fly.phase
			fly.part.Position = here + fly.offset + Vector3.new(math.sin(t) * 3, math.sin(t * 1.7) * 1.5, math.cos(t * 0.8) * 3)
			fly.light.Brightness = 0.6 + math.sin(now * 3 + fly.phase) * 0.5
		end
	end

	-- now and then a fish jumps
	if not low and (theme == "island" or theme == "beach" or theme == "ship") and now >= nextFish then
		nextFish = now + 4 + math.random() * 5
		jumpFish(mapCenter)
	end
end)

return Wildlife
