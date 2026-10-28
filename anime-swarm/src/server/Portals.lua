-- Builds the voyage gates on the spawn island and tracks who is standing on their pads.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(RS.Shared.Config)

local Portals = {}
local built = {} -- [gateIndex] = { pad = Vector3, status = TextLabel }

local STONE = Color3.fromRGB(70, 72, 88)
local RING_RADIUS = 7.5
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- stands a cylinder's length (X axis) upright

local function makePart(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanTouch, p.CastShadow = true, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.LuckiestGuy
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
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

local function buildPortal(index, position, color, folder)
	local model = Instance.new("Model")
	model.Name = "Voyage Gate " .. index
	local y = groundY(position)
	local base = Vector3.new(position.X, y, position.Z)
	-- the portal's front (-Z) faces the spawn point
	local cf = CFrame.lookAt(base, Vector3.new(Config.ISLAND_CENTER.X, y, Config.ISLAND_CENTER.Z))
	local ringCenter = cf * CFrame.new(0, 10, 0)

	makePart({
		Name = "Platform", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate, Color = STONE,
		Size = Vector3.new(1, 24, 24), CFrame = cf * CFrame.new(0, 0.5, 0) * UPRIGHT,
	}, model)
	local padCF = cf * CFrame.new(0, 1.05, -4)
	local pad = makePart({
		Name = "Pad", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color,
		Transparency = 0.35, CanCollide = false,
		Size = Vector3.new(0.1, Config.PORTAL_RADIUS * 2, Config.PORTAL_RADIUS * 2), CFrame = padCF * UPRIGHT,
	}, model)
	local rising = Instance.new("ParticleEmitter")
	rising.Color = ColorSequence.new(color)
	rising.LightEmission = 1
	rising.Rate = 10
	rising.Lifetime = NumberRange.new(1.2, 2)
	rising.Speed = NumberRange.new(0.5, 1.5)
	rising.Acceleration = Vector3.new(0, 4, 0)
	rising.Size = NumberSequence.new(0.5, 0)
	rising.Parent = pad

	-- stone ring with a glowing inner trim
	makePart({ Name = "Foot", Material = Enum.Material.Slate, Color = STONE, Size = Vector3.new(6, 1.6, 2.4), CFrame = cf * CFrame.new(0, 1.6, 0) }, model)
	local segments = 28
	for i = 0, segments - 1 do
		local a = i / segments * 2 * math.pi
		local spin = CFrame.Angles(0, 0, a)
		makePart({
			Name = "Ring", Material = Enum.Material.Slate, Color = STONE,
			Size = Vector3.new(1.6, 2 * math.pi * RING_RADIUS / segments * 1.15, 1.8),
			CFrame = ringCenter * CFrame.new(math.cos(a) * RING_RADIUS, math.sin(a) * RING_RADIUS, 0) * spin,
		}, model)
		local r = RING_RADIUS - 1
		makePart({
			Name = "Trim", Material = Enum.Material.Neon, Color = color, CanCollide = false,
			Size = Vector3.new(0.35, 2 * math.pi * r / segments * 1.15, 2),
			CFrame = ringCenter * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0) * spin,
		}, model)
	end

	-- the swirling gateway itself
	local discCF = ringCenter * CFrame.Angles(0, math.pi / 2, 0)
	local discSize = Vector3.new(0.3, 2 * RING_RADIUS - 1.6, 2 * RING_RADIUS - 1.6)
	local glow = makePart({
		Name = "Glow", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color,
		Transparency = 0.45, CanCollide = false, Size = discSize, CFrame = discCF,
	}, model)
	makePart({
		Name = "Vortex", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = color,
		CanCollide = false, Size = discSize + Vector3.new(0.3, 0, 0), CFrame = discCF,
	}, model)
	for i = 0, 2 do
		local blade = makePart({
			Name = "Swirl", Material = Enum.Material.Neon, Color = color:Lerp(Color3.new(1, 1, 1), 0.5),
			Transparency = 0.3, CanCollide = false, Size = Vector3.new(0.4, 2 * RING_RADIUS - 3, 0.15),
			CFrame = ringCenter * CFrame.Angles(0, 0, i * math.pi / 3),
		}, model)
		blade:SetAttribute("Center", ringCenter)
		blade:SetAttribute("Phase", i * math.pi / 3)
		CollectionService:AddTag(blade, "PortalSwirl") -- spun by client/Effects.lua
	end
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(color)
	sparkles.LightEmission = 1
	sparkles.Rate = 15
	sparkles.Lifetime = NumberRange.new(1, 2)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.Size = NumberSequence.new(0.7, 0)
	sparkles.Parent = glow
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 26, 2
	light.Parent = glow

	-- pillars, arch and name plate
	for _, side in { -1, 1 } do
		local x = side * 11
		makePart({ Name = "Pillar", Material = Enum.Material.Slate, Color = STONE, Size = Vector3.new(2.6, 20, 2.6), CFrame = cf * CFrame.new(x, 11, 0) }, model)
		makePart({ Name = "PillarGlow", Material = Enum.Material.Neon, Color = color, CanCollide = false, Size = Vector3.new(0.5, 17, 2.8), CFrame = cf * CFrame.new(x, 11, 0) }, model)
		makePart({ Name = "Orb", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = color, CanCollide = false, Size = Vector3.one * 2.6, CFrame = cf * CFrame.new(x, 23.3, 0) }, model)
	end
	local arch = makePart({ Name = "Arch", Material = Enum.Material.Slate, Color = STONE, Size = Vector3.new(25, 3, 3), CFrame = cf * CFrame.new(0, 20.5, 0) }, model)
	local plate = Instance.new("SurfaceGui")
	plate.Face = Enum.NormalId.Front
	plate.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	plate.PixelsPerStud = 40
	plate.Parent = arch
	label(plate, { Size = UDim2.fromScale(1, 1), Text = "VOYAGE GATE " .. index, TextColor3 = color })

	-- floating info: difficulty, description, live status
	local anchor = makePart({ Name = "Info", Transparency = 1, CanCollide = false, CanQuery = false, Size = Vector3.one, CFrame = cf * CFrame.new(0, 28, 0) }, model)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(320, 96)
	board.MaxDistance = 220
	board.Parent = anchor
	label(board, { Size = UDim2.new(1, 0, 0.38, 0), Text = "★ ADVENTURE ★", TextColor3 = Color3.fromRGB(255, 215, 80) })
	label(board, { Size = UDim2.new(1, 0, 0.27, 0), Position = UDim2.fromScale(0, 0.4), Font = Enum.Font.FredokaOne, Text = "Step in to pick a map and difficulty" })
	local status = label(board, {
		Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.7),
		Font = Enum.Font.FredokaOne, Text = "Step in to set sail!", TextColor3 = color,
	})

	model.Parent = folder
	built[index] = { pad = padCF.Position, status = status }
end

function Portals.build()
	local folder = Instance.new("Folder")
	folder.Name = "Portals"
	folder.Parent = workspace
	for index, position in Config.GATES do
		buildPortal(index, position, Config.GATE_COLORS[index], folder)
	end
end

-- Living players whose character stands on the portal's pad.
function Portals.playersInside(index)
	local portal = built[index]
	local inside = {}
	if not portal then
		return inside
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local offset = root.Position - portal.pad
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.PORTAL_RADIUS and offset.Y > -2 and offset.Y < 10 then
				table.insert(inside, player)
			end
		end
	end
	return inside
end

function Portals.setStatus(index, text)
	local portal = built[index]
	if portal and portal.status.Text ~= text then
		portal.status.Text = text
	end
end

return Portals
