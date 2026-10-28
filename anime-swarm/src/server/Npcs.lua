-- Island NPCs: trainers, the gear smith, the upgrades bar and the store. Each one has a
-- prompt ("E" on keyboard, tap on phones) that opens its menu on the client.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)

local Npcs = {}

local SKIN = Color3.fromRGB(255, 205, 160)
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local function makePart(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanTouch, p.CastShadow = true, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function groundY(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), params)
	return hit and hit.Position.Y or pos.Y
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function build(npc, folder)
	local model = Instance.new("Model")
	model.Name = npc.name
	local y = groundY(npc.position)
	local base = Vector3.new(npc.position.X, y, npc.position.Z)
	local cf = CFrame.lookAt(base, Vector3.new(Config.ISLAND_CENTER.X, y, Config.ISLAND_CENTER.Z))
	local function body(name, size, offset, color, shape)
		return makePart({ Name = name, Size = size, Color = color, Shape = shape or Enum.PartType.Block, CFrame = cf * offset }, model)
	end

	-- a round rug to stand on, then a simple blocky figure
	makePart({
		Name = "Rug", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 9, 9), Color = npc.accent,
		Material = Enum.Material.Fabric, CanCollide = false, CFrame = cf * CFrame.new(0, 0.1, 0) * UPRIGHT,
	}, model)
	body("LeftLeg", Vector3.new(0.9, 2, 1), CFrame.new(-0.5, 1, 0), Color3.fromRGB(45, 45, 55))
	body("RightLeg", Vector3.new(0.9, 2, 1), CFrame.new(0.5, 1, 0), Color3.fromRGB(45, 45, 55))
	local torso = body("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), npc.color)
	body("LeftArm", Vector3.new(0.8, 2, 0.8), CFrame.new(-1.45, 3, 0), npc.color)
	body("RightArm", Vector3.new(0.8, 2, 0.8), CFrame.new(1.45, 3, 0) * CFrame.Angles(math.rad(-25), 0, 0), npc.color)
	body("Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 4.85, 0), SKIN, Enum.PartType.Ball)
	body("Hat", Vector3.new(0.5, 1.9, 1.9), CFrame.new(0, 5.75, 0) * UPRIGHT, npc.accent, Enum.PartType.Cylinder)
	body("Brim", Vector3.new(0.12, 2.6, 2.6), CFrame.new(0, 5.5, 0) * UPRIGHT, npc.accent, Enum.PartType.Cylinder)
	for _, side in { -0.32, 0.32 } do
		body("Eye", Vector3.new(0.25, 0.25, 0.25), CFrame.new(side, 5, -0.72), Color3.fromRGB(25, 25, 30), Enum.PartType.Ball)
	end

	-- floating icon, name and role
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(220, 86)
	board.StudsOffset = Vector3.new(0, 4.6, 0)
	board.MaxDistance = 90
	board.Parent = torso
	label(board, { Size = UDim2.new(1, 0, 0, 34), Text = npc.icon })
	label(board, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 34), Text = npc.name })
	label(board, {
		Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 62), Text = npc.role:upper(),
		Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 205, 90),
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Talk"
	prompt.ActionText = "Talk"
	prompt.ObjectText = npc.name .. " - " .. npc.role
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Panel", npc.panel) -- read by client/SwarmClient to open the menu
	prompt:SetAttribute("Tab", npc.tab)
	prompt.Parent = torso

	model.Parent = folder
end

function Npcs.build()
	local folder = Instance.new("Folder")
	folder.Name = "IslandNPCs"
	folder.Parent = workspace
	for _, npc in Config.NPCS do
		build(npc, folder)
	end
end

return Npcs
