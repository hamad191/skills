-- Procedural attack animations: bends R15 joints for a moment, no animation assets needed.
-- Runs on every client for every character, so everyone sees everyone's attacks.
local RunService = game:GetService("RunService")

local Animate = {}
local active = {} -- { motor, pose, start, duration, peak }
local lastPlayed = {} -- [character] = { [style] = os.clock() }

local rad = math.rad

-- Each joint: { part name, motor name, function(t, k) -> CFrame }.
-- t goes 0 -> 1 over the animation, k is an envelope that rises fast then falls back to 0.
local STYLES = {
	punch = {
		duration = 0.25, peak = 0.25,
		joints = {
			{ "RightUpperArm", "RightShoulder", function(_, k) return CFrame.Angles(rad(95) * k, 0, 0) end },
			{ "UpperTorso", "Waist", function(_, k) return CFrame.Angles(0, rad(-30) * k, 0) end },
		},
	},
	slash = {
		duration = 0.3, peak = 0.35,
		joints = {
			{ "RightUpperArm", "RightShoulder", function(_, k) return CFrame.Angles(rad(80) * k, 0, rad(40) * k) end },
			{ "LeftUpperArm", "LeftShoulder", function(_, k) return CFrame.Angles(rad(80) * k, 0, rad(-40) * k) end },
			{ "UpperTorso", "Waist", function(t, k) return CFrame.Angles(0, rad(60 - 120 * t) * k, 0) end },
		},
	},
	kick = {
		duration = 0.3, peak = 0.3,
		joints = {
			{ "RightUpperLeg", "RightHip", function(_, k) return CFrame.Angles(rad(100) * k, 0, 0) end },
			{ "UpperTorso", "Waist", function(_, k) return CFrame.Angles(rad(-15) * k, rad(-40) * k, 0) end },
			{ "LeftUpperArm", "LeftShoulder", function(_, k) return CFrame.Angles(0, 0, rad(-60) * k) end },
			{ "RightUpperArm", "RightShoulder", function(_, k) return CFrame.Angles(0, 0, rad(60) * k) end },
		},
	},
	throw = {
		duration = 0.3, peak = 0.4,
		joints = {
			{ "RightUpperArm", "RightShoulder", function(t, k) return CFrame.Angles(rad(-40 + 150 * t) * k, 0, 0) end },
			{ "UpperTorso", "Waist", function(_, k) return CFrame.Angles(0, rad(-35) * k, 0) end },
		},
	},
	cast = {
		duration = 0.4, peak = 0.3,
		joints = {
			{ "RightUpperArm", "RightShoulder", function(_, k) return CFrame.Angles(rad(165) * k, 0, 0) end },
			{ "LeftUpperArm", "LeftShoulder", function(_, k) return CFrame.Angles(rad(30) * k, 0, 0) end },
		},
	},
	cross = {
		duration = 0.45, peak = 0.3,
		joints = {
			{ "RightUpperArm", "RightShoulder", function(_, k) return CFrame.Angles(rad(90) * k, 0, rad(35) * k) end },
			{ "LeftUpperArm", "LeftShoulder", function(_, k) return CFrame.Angles(rad(90) * k, 0, rad(-35) * k) end },
		},
	},
}

local function envelope(t, peak)
	if t < peak then
		return t / peak
	end
	return 1 - (t - peak) / (1 - peak)
end

function Animate.play(player, styleName)
	local style = STYLES[styleName]
	local character = player and player.Character
	if not style or not character then
		return
	end
	local now = os.clock()
	local played = lastPlayed[character] or {}
	lastPlayed[character] = played
	if played[styleName] and now - played[styleName] < style.duration * 0.8 then
		return -- already mid-swing
	end
	played[styleName] = now
	for _, joint in style.joints do
		local part = character:FindFirstChild(joint[1])
		local motor = part and part:FindFirstChild(joint[2])
		if motor and motor:IsA("Motor6D") then -- R15 only; R6 rigs just skip the animation
			table.insert(active, { motor = motor, pose = joint[3], start = now, duration = style.duration, peak = style.peak })
		end
	end
end

-- Stepped runs after Roblox's Animator, so these poses win over walk/idle for their joints.
RunService.Stepped:Connect(function()
	local now = os.clock()
	for i = #active, 1, -1 do
		local a = active[i]
		local t = (now - a.start) / a.duration
		if t >= 1 or not a.motor.Parent then
			a.motor.Transform = CFrame.identity
			table.remove(active, i)
		else
			a.motor.Transform = a.pose(t, envelope(t, a.peak))
		end
	end
	for character in lastPlayed do
		if not character.Parent then
			lastPlayed[character] = nil
		end
	end
end)

return Animate
