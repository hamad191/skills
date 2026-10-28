-- Signature gear each pirate wears or carries (hats, swords, staffs...), welded onto the
-- character on the server so every player sees it. Built from plain parts: no assets needed.
local Gear = {}

local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local UP = CFrame.Angles(0, 0, math.pi / 2) -- cylinder standing upright
local FORWARD = CFrame.Angles(0, math.pi / 2, 0) -- cylinder pointing forward (-Z)
local METAL, NEON, FABRIC = Enum.Material.Metal, Enum.Material.Neon, Enum.Material.Fabric
local SKIN = Color3.fromRGB(255, 205, 160)
local STEEL = Color3.fromRGB(215, 220, 230)
local BLACK = Color3.fromRGB(20, 20, 25)

-- R6 rigs have fewer parts; attach to the closest one.
local R6 = {
	UpperTorso = "Torso", LowerTorso = "Torso", RightHand = "Right Arm", LeftHand = "Left Arm",
	RightLowerArm = "Right Arm", LeftLowerArm = "Left Arm", LeftUpperArm = "Left Arm",
	RightFoot = "Right Leg", LeftFoot = "Left Leg",
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- A piece is { body part, size, offset from that part, color, shape?, material? }.
local function hat(brim, crown, band, height, y)
	y = y or 0.5
	height = height or 0.7
	local pieces = {
		{ "Head", Vector3.new(0.15, 2.7, 2.7), CFrame.new(0, y, 0) * UP, brim, CYL, FABRIC },
		{ "Head", Vector3.new(height, 1.4, 1.4), CFrame.new(0, y + height / 2, 0) * UP, crown, CYL, FABRIC },
	}
	if band then
		table.insert(pieces, { "Head", Vector3.new(0.22, 1.45, 1.45), CFrame.new(0, y + 0.15, 0) * UP, band, CYL, FABRIC })
	end
	return pieces
end

local function sword(hand, handle, length)
	return {
		{ hand, Vector3.new(0.9, 0.28, 0.28), CFrame.new(0, -0.15, -0.1) * FORWARD, handle, CYL },
		{ hand, Vector3.new(0.08, 0.7, 0.7), CFrame.new(0, -0.15, -0.6) * FORWARD, rgb(200, 170, 60), CYL, METAL },
		{ hand, Vector3.new(0.08, 0.25, length), CFrame.new(0, -0.15, -0.65 - length / 2), STEEL, nil, METAL },
	}
end

local function sheath(x, color, tilt)
	return { "LowerTorso", Vector3.new(0.26, 0.26, 3.2), CFrame.new(x, -0.1, 0.3) * CFrame.Angles(math.rad(tilt), 0, 0), color }
end

local function staff(hand, colors, length)
	local pieces = {}
	local segment = length / #colors
	for i, color in colors do
		local y = -length / 2 + (i - 0.5) * segment
		table.insert(pieces, { hand, Vector3.new(segment, 0.22, 0.22), CFrame.new(0, y, 0) * UP, color, CYL })
	end
	return pieces
end

local function join(...)
	local all = {}
	for _, list in { ... } do
		for _, piece in list do
			table.insert(all, piece)
		end
	end
	return all
end

local GEAR = {
	Marine = join(hat(rgb(245, 245, 250), rgb(245, 245, 250), rgb(30, 60, 140), 0.6), {
		{ "UpperTorso", Vector3.new(2.3, 3, 0.15), CFrame.new(0, -0.4, 0.6), rgb(250, 250, 252), nil, FABRIC },
		{ "UpperTorso", Vector3.new(0.9, 0.9, 0.06), CFrame.new(0, -0.3, 0.69), rgb(40, 70, 150) },
	}),
	Luffy = hat(rgb(240, 210, 110), rgb(240, 210, 110), rgb(200, 30, 30)),
	Zoro = join(sword("RightHand", BLACK, 3.4), {
		sheath(-1.05, rgb(240, 240, 240), 55),
		sheath(-0.85, rgb(170, 30, 30), 65),
		{ "LeftUpperArm", Vector3.new(1.1, 0.35, 1.1), CFrame.new(0, 0.2, 0), rgb(30, 30, 30), nil, FABRIC },
	}),
	Nami = staff("RightHand", { rgb(40, 90, 200), rgb(130, 200, 255), rgb(40, 90, 200) }, 5),
	Sanji = {
		{ "UpperTorso", Vector3.new(2.08, 1.62, 1.08), CFrame.new(), BLACK, nil, FABRIC },
		{ "UpperTorso", Vector3.new(0.28, 1.1, 0.06), CFrame.new(0, 0.05, -0.57), rgb(30, 50, 120) },
		{ "RightFoot", Vector3.new(1.05, 0.45, 1.25), CFrame.new(0, -0.05, -0.1), BLACK },
		{ "LeftFoot", Vector3.new(1.05, 0.45, 1.25), CFrame.new(0, -0.05, -0.1), BLACK },
	},
	Ace = join(hat(rgb(240, 120, 30), rgb(240, 120, 30), rgb(180, 30, 30)), {
		{ "Head", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.25, 0.75, -0.72), rgb(220, 40, 40), BALL },
		{ "Head", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.25, 0.75, -0.72), rgb(40, 100, 220), BALL },
	}),
	Robin = hat(rgb(120, 70, 170), rgb(120, 70, 170), rgb(210, 180, 240)),
	Chopper = join(hat(rgb(240, 120, 170), rgb(240, 120, 170), nil, 1.3), {
		{ "Head", Vector3.new(0.9, 0.12, 0.06), CFrame.new(0, 1.15, -0.72) * CFrame.Angles(0, 0, math.rad(45)), rgb(250, 250, 250) },
		{ "Head", Vector3.new(0.9, 0.12, 0.06), CFrame.new(0, 1.15, -0.72) * CFrame.Angles(0, 0, math.rad(-45)), rgb(250, 250, 250) },
		{ "Head", Vector3.new(1.2, 0.2, 0.2), CFrame.new(-0.9, 0.6, 0) * CFrame.Angles(0, 0, math.rad(-50)), rgb(130, 85, 45), CYL },
		{ "Head", Vector3.new(1.2, 0.2, 0.2), CFrame.new(0.9, 0.6, 0) * CFrame.Angles(0, 0, math.rad(50)), rgb(130, 85, 45), CYL },
	}),
	Usopp = {
		{ "Head", Vector3.new(1.3, 0.3, 0.3), CFrame.new(0, -0.05, -1.15) * FORWARD, SKIN, CYL },
		{ "Head", Vector3.new(0.42, 0.42, 0.42), CFrame.new(-0.27, 0.42, -0.58), rgb(255, 210, 80), BALL, NEON },
		{ "Head", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0.27, 0.42, -0.58), rgb(255, 210, 80), BALL, NEON },
		{ "LeftHand", Vector3.new(0.9, 0.2, 0.2), CFrame.new(0, -0.1, 0) * UP, rgb(110, 70, 40), CYL },
		{ "LeftHand", Vector3.new(0.7, 0.16, 0.16), CFrame.new(-0.2, 0.55, 0) * CFrame.Angles(0, 0, math.rad(115)), rgb(110, 70, 40), CYL },
		{ "LeftHand", Vector3.new(0.7, 0.16, 0.16), CFrame.new(0.2, 0.55, 0) * CFrame.Angles(0, 0, math.rad(65)), rgb(110, 70, 40), CYL },
	},
	Franky = {
		{ "Head", Vector3.new(1.0, 0.55, 1.5), CFrame.new(0, 0.75, -0.25), rgb(60, 150, 240) },
		{ "Head", Vector3.new(1.15, 0.25, 0.08), CFrame.new(0, 0.15, -0.62), BLACK },
		{ "RightLowerArm", Vector3.new(1.3, 1.4, 1.3), CFrame.new(0, -0.1, 0), rgb(60, 120, 210), nil, METAL },
		{ "LeftLowerArm", Vector3.new(1.3, 1.4, 1.3), CFrame.new(0, -0.1, 0), rgb(60, 120, 210), nil, METAL },
		{ "UpperTorso", Vector3.new(0.5, 0.5, 0.06), CFrame.new(-0.5, 0.3, -0.56), rgb(255, 220, 60), nil, NEON },
	},
	Brook = join({
		{ "Head", Vector3.new(2, 2, 2), CFrame.new(0, 1.05, 0.45), BLACK, BALL, FABRIC },
	}, hat(BLACK, BLACK, rgb(150, 60, 60), 1.2, 1.9), staff("RightHand", { BLACK, BLACK }, 4.2), {
		{ "RightHand", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 2.15, 0), rgb(220, 190, 80), BALL, METAL },
	}),
	Jinbe = {
		{ "UpperTorso", Vector3.new(2.12, 1.64, 1.12), CFrame.new(), rgb(40, 70, 110), nil, FABRIC },
		{ "LowerTorso", Vector3.new(2.15, 0.35, 1.15), CFrame.new(0, 0.05, 0), rgb(240, 140, 40), nil, FABRIC },
		{ "UpperTorso", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0.85, -0.45), rgb(230, 80, 80), BALL },
	},
	Law = join(hat(rgb(245, 245, 240), rgb(245, 245, 240), rgb(60, 60, 60), 0.9, 0.45), {
		{ "Head", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.4, 1.0, -0.55), BLACK, BALL },
		{ "Head", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.35, 1.05, -0.55), BLACK, BALL },
		{ "Head", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.6, 0.9, 0.2), BLACK, BALL },
		{ "UpperTorso", Vector3.new(0.32, 5.4, 0.32), CFrame.new(0.2, 0.2, 0.68) * CFrame.Angles(0, 0, math.rad(35)), BLACK },
		{ "UpperTorso", Vector3.new(0.3, 1.1, 0.3), CFrame.new(-1.67, 2.86, 0.68) * CFrame.Angles(0, 0, math.rad(35)), rgb(240, 240, 240) },
	}),
	Hancock = {
		{ "UpperTorso", Vector3.new(2.4, 3.4, 0.12), CFrame.new(0, -0.5, 0.62), rgb(200, 30, 60), nil, FABRIC },
		{ "Head", Vector3.new(0.3, 1.45, 1.45), CFrame.new(0, 0.62, 0) * UP, rgb(240, 200, 60), CYL, METAL },
		{ "Head", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0.9, -0.62), rgb(255, 90, 160), BALL, NEON },
	},
}

-- Replaces any gear on the character with this class's gear.
function Gear.apply(character, className)
	if not character then
		return
	end
	local old = character:FindFirstChild("PirateGear")
	if old then
		old:Destroy()
	end
	local pieces = GEAR[className]
	if not pieces then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "PirateGear"
	for _, piece in pieces do
		local attachName, size, offset, color, shape, material = piece[1], piece[2], piece[3], piece[4], piece[5], piece[6]
		local attach = character:FindFirstChild(attachName) or (R6[attachName] and character:FindFirstChild(R6[attachName]))
		if attach and attach:IsA("BasePart") then
			local p = Instance.new("Part")
			p.Name = attachName .. "Gear"
			p.Shape = shape or Enum.PartType.Block
			p.Size = size
			p.Color = color
			p.Material = material or Enum.Material.SmoothPlastic
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
			p.CFrame = attach.CFrame * offset
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = attach, p
			weld.Parent = p
			p.Parent = folder
		end
	end
	folder.Parent = character
end

return Gear
