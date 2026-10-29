-- Turns the flat part floors into real Roblox terrain when the server starts:
--   * the spawn island gets a sloped sand beach, grass with animated blades, and a waving ocean
--   * every arena gets a textured ground in its theme (grass, cobblestone, sand, snow, basalt...)
--     with patches of a second and third material, and an ocean around the sea-themed ones
-- The old floor parts stay in the place file (so Studio's edit view still shows the maps) and
-- are hidden here. Clouds drift across the sky too.
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)

local World = {}
local terrain = workspace.Terrain
local M = Enum.Material

-- keep in sync with tools/build_place.py
local GRASS_TOP, BEACH_TOP = 1.25, 0.5
local GRASS_R, BEACH_R = 130, 160
local WATER_TOP = -1

-- theme: base material, patch materials
local GROUND = {
	grass = { M.Grass, { M.LeafyGrass, M.Ground } },
	marine = { M.Concrete, { M.Pavement, M.Asphalt } },
	town = { M.Cobblestone, { M.Pavement, M.Grass } },
	beach = { M.Sand, { M.Sandstone, M.Grass } },
	ship = { M.WoodPlanks, { M.WoodPlanks } },
	deepsea = { M.Sand, { M.Salt, M.Basalt, M.Rock } },
	snow = { M.Snow, { M.Glacier, M.Ice } },
	desert = { M.Sand, { M.Sandstone, M.Salt } },
	jungle = { M.LeafyGrass, { M.Mud, M.Grass, M.Ground } },
	sky = { M.Snow, { M.Ice, M.Salt } },
	spooky = { M.Mud, { M.Ground, M.Rock } },
	mangrove = { M.LeafyGrass, { M.Mud, M.Grass } },
	prison = { M.Slate, { M.Pavement, M.Concrete } },
	volcano = { M.Basalt, { M.CrackedLava, M.Rock } },
	wano = { M.Grass, { M.LeafyGrass, M.Pavement } },
}
-- themes that sit in the sea
local OCEAN = { beach = true, ship = true, deepsea = true, mangrove = true }

local COLORS = {
	[M.Grass] = Color3.fromRGB(96, 168, 74), [M.LeafyGrass] = Color3.fromRGB(70, 130, 60), [M.Sand] = Color3.fromRGB(230, 210, 150),
	[M.Ground] = Color3.fromRGB(120, 95, 70), [M.Mud] = Color3.fromRGB(80, 65, 55), [M.Snow] = Color3.fromRGB(240, 245, 252),
	[M.Basalt] = Color3.fromRGB(55, 48, 52), [M.CrackedLava] = Color3.fromRGB(255, 110, 40), [M.Cobblestone] = Color3.fromRGB(165, 150, 130),
	[M.WoodPlanks] = Color3.fromRGB(150, 105, 65), [M.Sandstone] = Color3.fromRGB(205, 165, 110), [M.Concrete] = Color3.fromRGB(160, 160, 168),
}

local function hide(part)
	if part and part:IsA("BasePart") then
		part.Transparency, part.CanCollide, part.CanQuery, part.CastShadow = 1, false, false, false
	end
end

local function fillCylinder(x, z, bottom, top, radius, material)
	terrain:FillCylinder(CFrame.new(x, (bottom + top) / 2, z), top - bottom, radius, material)
end

local function island()
	local c = Config.ISLAND_CENTER
	terrain:FillBlock(CFrame.new(c.X, -20, c.Z), Vector3.new(1400, 8, 1400), M.Sand) -- sea floor
	terrain:FillBlock(CFrame.new(c.X, (WATER_TOP - 16) / 2, c.Z), Vector3.new(1400, WATER_TOP + 16, 1400), M.Water)
	-- the beach slopes into the sea in rings, then the grass sits on top
	for _, ring in { { BEACH_R + 32, -9 }, { BEACH_R + 20, -5 }, { BEACH_R + 12, -2.5 }, { BEACH_R + 6, -0.8 }, { BEACH_R, BEACH_TOP } } do
		fillCylinder(c.X, c.Z, -16, ring[2], ring[1], M.Sand)
	end
	fillCylinder(c.X, c.Z, -8, GRASS_TOP, GRASS_R, M.Grass)
	local spawnIsland = workspace:FindFirstChild("SpawnIsland")
	if spawnIsland then
		for _, name in { "Sea", "Beach", "Grass" } do
			hide(spawnIsland:FindFirstChild(name))
		end
	end
end

local function arena(center, theme, seed)
	local ground = GROUND[theme] or GROUND.grass
	local rng = Random.new(seed)
	if OCEAN[theme] then
		-- open water around the arena, outside its border
		terrain:FillBlock(CFrame.new(center.X, -20, center.Z), Vector3.new(1300, 8, 1300), M.Sand)
		terrain:FillBlock(CFrame.new(center.X, (WATER_TOP - 16) / 2, center.Z), Vector3.new(1300, WATER_TOP + 16, 1300), M.Water)
	end
	terrain:FillBlock(CFrame.new(center.X, -4, center.Z), Vector3.new(1000, 8, 1000), ground[1])
	-- patches of other materials, flush with the floor
	for _ = 1, 70 do
		local x, z = rng:NextNumber(-470, 470), rng:NextNumber(-470, 470)
		local material = ground[2][rng:NextInteger(1, #ground[2])]
		fillCylinder(center.X + x, center.Z + z, -4, 0, rng:NextNumber(8, 34), material)
	end
end

function World.build()
	terrain.WaterColor = Color3.fromRGB(25, 115, 170)
	terrain.WaterReflectance = 0.35
	terrain.WaterTransparency = 0.55
	terrain.WaterWaveSize = 0.3
	terrain.WaterWaveSpeed = 14
	pcall(function()
		terrain.Decoration = true -- animated grass blades
	end)
	for material, color in COLORS do
		pcall(terrain.SetMaterialColor, terrain, material, color)
	end
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover, clouds.Density = 0.55, 0.7
	clouds.Parent = terrain

	island()
	local arenas = workspace:FindFirstChild("Arenas")
	local maps = table.clone(Config.Maps)
	table.insert(maps, Config.RAID.map)
	for i, map in maps do
		arena(map.center, map.theme, i * 7919)
		-- hide the arena's flat floor part (models are named "01 Map Name", "02 ...")
		local model = arenas and arenas:FindFirstChild(string.format("%02d %s", i, map.name))
		hide(model and model:FindFirstChild("Floor"))
		task.wait() -- spread the work over a few frames
	end
end

return World
