-- The first-time guide: a glowing trail and tips that walk a new player through talking to an
-- NPC, boarding a voyage gate and their first adventure. Finishing it pays a welcome gift.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local Sounds = require(script.Parent.Sounds)

local Tutorial = {}
local player = Players.LocalPlayer
local ui = {}
local step -- nil = not running
local onFinish
local tipToken

local RUN_TIPS = {
	{ "⚔️ Your skills fire on their own - just keep moving!", 6 },
	{ "💨 Press SHIFT (or DASH) to dash: you're untouchable for a moment.", 6 },
	{ "🔵 Walk over blue XP orbs to level up, then pick a card.", 8 },
	{ "🔴 Red circles and strips are attacks coming. Step out of them!", 7 },
	{ "🌊 Survive the waves, then take down the boss!", 6 },
}

-- Guide trail -----------------------------------------------------------------------------------

local marker = Instance.new("Part")
marker.Name = "GuideMarker"
marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch = true, false, false, false
marker.Transparency = 1
marker.Size = Vector3.one
local targetAttachment = Instance.new("Attachment")
targetAttachment.Parent = marker
local beam = Instance.new("Beam")
beam.Attachment1 = targetAttachment
beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
beam.Transparency = NumberSequence.new(0.2, 0.7)
beam.Width0, beam.Width1 = 0.6, 0.6
beam.FaceCamera = true
beam.LightEmission = 1
beam.Segments = 20
beam.Parent = marker
local arrow = Instance.new("BillboardGui")
arrow.Size = UDim2.fromOffset(60, 60)
arrow.AlwaysOnTop = true
arrow.StudsOffset = Vector3.new(0, 7, 0)
arrow.Parent = marker
local arrowText = Instance.new("TextLabel")
arrowText.Size = UDim2.fromScale(1, 1)
arrowText.BackgroundTransparency = 1
arrowText.Text = "⬇️"
arrowText.TextScaled = true
arrowText.Parent = arrow
local fromAttachment

local function pointTo(pos)
	if not pos then
		marker.Parent = nil
		return
	end
	marker.Position = pos
	marker.Parent = workspace
end

local function npcSpot(index)
	local npc = Config.NPCS[index]
	local folder = workspace:FindFirstChild("IslandNPCs")
	local stall = folder and folder:FindFirstChild(npc.name .. " Stall")
	local body = stall and stall:FindFirstChild(npc.name)
	local root = body and body:FindFirstChild("HumanoidRootPart")
	return root and root.Position or npc.position + Vector3.new(0, 3, 0)
end

-- Tip panel -------------------------------------------------------------------------------------

local function showTip(text)
	ui.text.Text = text
	ui.panel.Visible = true
	ui.scale.Scale = 0.85
	Theme.tween(ui.scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	Sounds.play("Pickup")
end

local function setStep(n)
	step = n
	if n == 1 then
		showTip("👋 Welcome aboard, recruit! Talk to " .. Config.NPCS[1].name .. " (follow the golden trail, press E).")
		pointTo(npcSpot(1))
	elseif n == 2 then
		showTip("⛵ Now step onto a voyage gate to start your first adventure!")
		pointTo(Config.GATES[2] + Vector3.new(0, 4, 0))
	elseif n == 3 then
		pointTo(nil)
		local token = {}
		tipToken = token
		task.spawn(function()
			for _, tip in RUN_TIPS do
				if tipToken ~= token then
					return
				end
				showTip(tip[1])
				task.wait(tip[2])
			end
			if tipToken == token then
				ui.panel.Visible = false
			end
		end)
	end
end

function Tutorial.init(root, finish)
	onFinish = finish
	local panel = Theme.panel({ Size = UDim2.fromOffset(620, 58), Position = UDim2.new(0.5, -310, 1, -214), Visible = false, ZIndex = 25 }, root)
	ui.panel = panel
	ui.scale = Theme.new("UIScale", {}, panel)
	Theme.text({ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(12, 9), Text = "🎓", ZIndex = 26 }, panel)
	ui.text = Theme.text({ Size = UDim2.new(1, -120, 1, -16), Position = UDim2.fromOffset(58, 8), Font = Theme.BOLD, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 17 }, panel)
	Theme.button({ Size = UDim2.fromOffset(48, 30), Position = UDim2.new(1, -58, 0.5, -15), Text = "SKIP", BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 26 }, panel, function()
		Tutorial.finish()
	end)

	RunService.Heartbeat:Connect(function()
		if not marker.Parent then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (not fromAttachment or fromAttachment.Parent ~= root) then
			fromAttachment = Instance.new("Attachment")
			fromAttachment.Name = "GuideFrom"
			fromAttachment.Parent = root
			beam.Attachment0 = fromAttachment
		end
		arrow.StudsOffset = Vector3.new(0, 7 + math.sin(os.clock() * 4) * 0.8, 0)
	end)
end

-- Starts the guide if this player hasn't finished it.
function Tutorial.start(done)
	if done or step then
		return
	end
	setStep(1)
end

-- Progress events from the rest of the client.
function Tutorial.talked()
	if step == 1 then
		setStep(2)
	end
end

function Tutorial.phase(phase)
	if not step then
		return
	end
	if phase == "Run" and step < 3 then
		setStep(3)
	elseif (phase == "Results" or phase == "Lobby") and step == 3 then
		Tutorial.finish()
	end
end

function Tutorial.finish()
	if not step then
		return
	end
	step = nil
	tipToken = nil
	ui.panel.Visible = false
	pointTo(nil)
	onFinish()
end

return Tutorial
