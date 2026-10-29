-- Procedural animation for everything that isn't a player, no animation assets needed:
--   * enemies walk (legs and arms swing with their speed), aim their guns, carry bombs, and
--     swing, cast or shoot when the server says they attack (attributes Pose / PoseAt)
--   * island NPCs breathe, turn their head toward you, wave when you walk up, and play their
--     own idle (Captain Grey stands calm, Granny Doc sips sake, Hammond hammers, Roxie smokes, Bingo laughs)
-- Also shows NPC speech bubbles.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Rigs = {}
local player = Players.LocalPlayer
local rad, sin, clamp = math.rad, math.sin, math.clamp
local Angles = CFrame.Angles

local POSE_TIME = { swing = 0.35, cast = 0.5, shoot = 0.25 }

local function envelope(t, peak)
	if t < peak then
		return t / peak
	end
	return 1 - (t - peak) / (1 - peak)
end

-- Enemies -------------------------------------------------------------------------------------

local mobs = {} -- [model] = state

local function mobState(model)
	local torso = model:FindFirstChild("Torso")
	if not torso then
		return nil
	end
	local motors = {}
	for _, name in { "LeftHip", "RightHip", "LeftShoulder", "RightShoulder", "Neck" } do
		local m = torso:FindFirstChild(name)
		if not m then
			return nil -- not a jointed enemy (e.g. a treasure chest)
		end
		motors[name] = m
	end
	return {
		torso = torso, motors = motors, last = torso.Position, speed = 0, t = math.random() * 6,
		scale = model:GetAttribute("Scale") or 1, style = model:GetAttribute("Style") or "march",
	}
end

local function animateMob(model, st, dt, now)
	local pos = st.torso.Position
	local moved = Vector3.new(pos.X - st.last.X, 0, pos.Z - st.last.Z).Magnitude
	st.last = pos
	local v = dt > 0 and math.min(moved / dt, 80) or 0
	st.speed += (v - st.speed) * math.min(1, dt * 8)
	local s = st.scale
	st.t += dt * clamp(st.speed / s, 0, 30) * 0.55
	local amp = clamp(st.speed / (6 * s), 0, 1) * 0.75
	local swing = sin(st.t) * amp
	local m = st.motors

	m.LeftHip.Transform = Angles(swing, 0, 0)
	m.RightHip.Transform = Angles(-swing, 0, 0)
	m.Neck.Transform = Angles(sin(st.t * 2) * 0.05, 0, 0)

	local left, right
	if st.style == "aim" then
		right = Angles(rad(90), 0, 0)
		left = Angles(rad(75), 0, rad(25))
	elseif st.style == "carry" then
		right = Angles(rad(60), 0, 0)
		left = Angles(rad(60), 0, rad(20))
	else
		right = Angles(swing * 0.8, 0, 0)
		left = Angles(-swing * 0.8, 0, 0)
	end

	-- attack poses on top
	local poseAt = model:GetAttribute("PoseAt")
	local poseName = model:GetAttribute("Pose")
	local duration = POSE_TIME[poseName]
	if poseAt and duration then
		-- the server's clock differs from ours: time the pose from when we first saw it
		if st.poseAt ~= poseAt then
			st.poseAt, st.poseStart = poseAt, now
		end
		local t = (now - st.poseStart) / duration
		if t < 1 then
			local k = envelope(t, 0.3)
			if poseName == "swing" then
				right = Angles(rad(160 - 150 * t) * k, 0, 0)
			elseif poseName == "cast" then
				right = Angles(rad(150) * k, 0, rad(20) * k)
				left = Angles(rad(150) * k, 0, rad(-20) * k)
			elseif poseName == "shoot" then
				right = right * Angles(rad(25) * k, 0, 0)
			end
		end
	end
	m.LeftShoulder.Transform = left
	m.RightShoulder.Transform = right
end

-- Island NPCs ---------------------------------------------------------------------------------

local npcs = {} -- [model] = state

local function motor(model, partName, motorName)
	local p = model:FindFirstChild(partName)
	return p and p:FindFirstChild(motorName)
end

local function npcState(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return {
		root = root, style = model:GetAttribute("Style"), yaw = 0, near = false, waveStart = -10,
		phase = math.random() * 5, lastStrike = 0,
		waist = motor(model, "UpperTorso", "Waist"), neck = motor(model, "Head", "Neck"),
		rs = motor(model, "RightUpperArm", "RightShoulder"), ls = motor(model, "LeftUpperArm", "LeftShoulder"),
		re = motor(model, "RightLowerArm", "RightElbow"), le = motor(model, "LeftLowerArm", "LeftElbow"),
		sparks = model.Parent and model.Parent:FindFirstChild("Anvil") and model.Parent.Anvil:FindFirstChild("Sparks"),
	}
end

local function set(m, cf)
	if m then
		m.Transform = cf
	end
end

-- A gesture every `every` seconds lasting `length`: returns 0..1..0 while it plays, else 0.
local function every(now, phase, period, length)
	local t = (now + phase) % period
	if t > length then
		return 0
	end
	return envelope(t / length, 0.25)
end

local function animateNpc(model, st, dt, now)
	local character = player.Character
	local me = character and character:FindFirstChild("HumanoidRootPart")
	local rel = me and st.root.CFrame:PointToObjectSpace(me.Position)
	local dist = rel and Vector3.new(rel.X, 0, rel.Z).Magnitude or math.huge

	-- wave once each time you walk up
	local near = dist < 14
	if near and not st.near then
		st.waveStart = now
	end
	st.near = near

	-- turn the head toward you
	local targetYaw = dist < 30 and clamp(math.atan2(-rel.X, -rel.Z), -1, 1) or 0
	st.yaw += (targetYaw - st.yaw) * math.min(1, dt * 5)

	local breathe = sin(now * 1.6 + st.phase) * 0.03
	local waist, neckPitch = Angles(breathe, 0, 0), 0
	local rs, ls, re, le = CFrame.identity, CFrame.identity, CFrame.identity, CFrame.identity

	if st.style == "swordsman" then
		-- calm, hands behind the back, a slow nod now and then
		rs, ls = Angles(rad(-20), 0, rad(8)), Angles(rad(-20), 0, rad(-8))
		re, le = Angles(rad(35), 0, 0), Angles(rad(35), 0, 0)
		neckPitch = every(now, st.phase, 7, 1.2) * 0.25
	elseif st.style == "sip" then
		local k = every(now, st.phase, 5, 1.6)
		rs = Angles(rad(100) * k, 0, rad(-25) * k)
		re = Angles(rad(70) * k, 0, 0)
		ls, le = Angles(0, 0, rad(-25)), Angles(rad(60), 0, 0)
		neckPitch = -0.25 * k
	elseif st.style == "hammer" then
		-- raise slowly, strike fast, sparks fly from the anvil
		local p = (now + st.phase) % 0.9 / 0.9
		local raise = p < 0.7 and p / 0.7 or 1 - (p - 0.7) / 0.3
		rs = Angles(rad(40 + 110 * raise), 0, 0)
		re = Angles(rad(20 * raise), 0, 0)
		waist = waist * Angles(rad(-6) * raise, 0, 0)
		if p > 0.97 and now - st.lastStrike > 0.5 then
			st.lastStrike = now
			if st.sparks then
				st.sparks:Emit(10)
			end
		end
		neckPitch = 0.2
	elseif st.style == "smoke" then
		local k = every(now, st.phase, 6, 1.8)
		ls = Angles(rad(105) * k, 0, rad(25) * k)
		le = Angles(rad(80) * k, 0, 0)
		rs, re = Angles(0, 0, rad(25)), Angles(rad(60), 0, 0)
		waist = waist * Angles(0, sin(now * 0.8) * 0.06, 0)
	elseif st.style == "pray" then
		-- palms together, a slow bow now and then
		local k = every(now, st.phase, 6, 2.4)
		rs, ls = Angles(rad(55), 0, rad(-28)), Angles(rad(55), 0, rad(28))
		re, le = Angles(rad(70), 0, 0), Angles(rad(70), 0, 0)
		waist = waist * Angles(rad(22) * k, 0, 0)
		neckPitch = 0.25 * k
	elseif st.style == "laugh" then
		-- hands on hips, then a big "Gya-ha-ha!" every few seconds
		local k = every(now, st.phase, 4, 1.6)
		rs = Angles(0, 0, rad(30 + 90 * k))
		ls = Angles(0, 0, rad(-30 - 90 * k))
		re, le = Angles(rad(70 * (1 - k)), 0, 0), Angles(rad(70 * (1 - k)), 0, 0)
		waist = waist * Angles(rad(-12) * k + sin(now * 25) * 0.06 * k, 0, 0)
		neckPitch = -0.35 * k
	end

	-- the greeting wave wins over the idle for the right arm
	local w = now - st.waveStart
	if w < 1.6 then
		local k = envelope(w / 1.6, 0.2)
		rs = rs:Lerp(Angles(0, 0, rad(150)), k)
		re = re:Lerp(Angles(0, 0, sin(w * 12) * 0.5), k)
	end

	set(st.waist, waist)
	set(st.neck, Angles(neckPitch, st.yaw, 0))
	set(st.rs, rs)
	set(st.ls, ls)
	set(st.re, re)
	set(st.le, le)
end

-- Speech bubbles ------------------------------------------------------------------------------

-- Shows `text` in a bubble above an NPC for a few seconds (only this player sees it).
function Rigs.speak(anchor, text)
	if not anchor or not text then
		return
	end
	local model = anchor:FindFirstAncestorOfClass("Model")
	local head = model and model:FindFirstChild("Head") or anchor
	local old = head:FindFirstChild("SpeechBubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpeechBubble"
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Parent = head
	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.new(1, 0, 1, -12)
	bubble.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
	bubble.TextColor3 = Color3.fromRGB(40, 30, 20)
	bubble.Font = Enum.Font.FredokaOne
	bubble.TextScaled = true
	bubble.TextWrapped = true
	bubble.Text = text
	bubble.Parent = gui
	Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 14)
	local pad = Instance.new("UIPadding", bubble)
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 6), UDim.new(0, 6)
	local stroke = Instance.new("UIStroke", bubble)
	stroke.Color, stroke.Thickness = Color3.fromRGB(60, 40, 20), 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local tail = Instance.new("Frame")
	tail.Size = UDim2.fromOffset(14, 14)
	tail.Position = UDim2.new(0.5, -7, 1, -19)
	tail.Rotation = 45
	tail.BackgroundColor3 = bubble.BackgroundColor3
	tail.BorderSizePixel = 0
	tail.Parent = gui
	local scale = Instance.new("UIScale", bubble)
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Debris:AddItem(gui, 3.5)
	-- they wave while talking
	local st = model and npcs[model]
	if st then
		st.waveStart = os.clock()
	end
end

-- Main loop -----------------------------------------------------------------------------------

local MOB_RANGE = 240 -- only animate what this player can actually see
local NPC_RANGE = 160

-- Stepped runs after Roblox's Animator, so these poses aren't overwritten.
RunService.Stepped:Connect(function(_, dt)
	local now = os.clock()
	local focus = workspace.CurrentCamera.Focus.Position
	local folder = workspace:FindFirstChild("Enemies")
	if folder then
		for _, model in folder:GetChildren() do
			local st = mobs[model]
			if st == nil then
				st = mobState(model) or false
				mobs[model] = st
			end
			if st then
				local pos = st.torso.Position
				if (pos - focus).Magnitude <= MOB_RANGE * st.scale then
					animateMob(model, st, dt, now)
				else
					st.last = pos -- keep the speed estimate fresh for when it comes into view
				end
			end
		end
	end
	for model in mobs do
		if not model.Parent then
			mobs[model] = nil
		end
	end

	for _, model in CollectionService:GetTagged("IslandNPC") do
		local st = npcs[model]
		if not st then
			st = npcState(model)
			npcs[model] = st
		end
		if st and (st.root.Position - focus).Magnitude <= NPC_RANGE then
			animateNpc(model, st, dt, now)
		end
	end
	for model in npcs do
		if not model.Parent then
			npcs[model] = nil
		end
	end
end)

return Rigs
