-- In-run HUD: status bar (level, XP, map, timer, kills), wave tracker and wave banners, boss
-- health bar, combo counter, arrows to off-screen chests and bosses, a red flash when you get
-- hurt, crewmates' health, skill action bar, health, level-up cards, announcements and the
-- results screen (with damage per skill).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local Sounds = require(script.Parent.Sounds)
local Effects = require(script.Parent.Effects)

local Hud = {}
local ui = {}
local cards = {}
local callbacks
local player = Players.LocalPlayer

local SKILL_TILE, PASSIVE_TILE, GAP = 52, 42, 6
local CARD_W, CARD_H, CARD_GAP = 240, 330, 22
local EVO_COLOR = Color3.fromRGB(255, 120, 255)
local FUSION_COLOR = Color3.fromRGB(110, 230, 255)

local function initials(name)
	local letters = ""
	for word in name:gmatch("[%a]+") do
		letters ..= word:sub(1, 1):upper()
		if #letters == 2 then
			break
		end
	end
	return letters
end

-- Status bar: level, XP, map, timer, kills ----------------------------------------------

local function buildStatus(root)
	local bar = Theme.panel({ Size = UDim2.fromOffset(460, 72), Position = UDim2.new(0.5, -230, 0, 10) }, root)
	local badge = Theme.new("Frame", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(10, 8), BackgroundColor3 = Theme.ACCENT, ZIndex = 2 }, bar)
	Theme.corner(badge, 26)
	Theme.gradient(badge, Color3.fromRGB(255, 150, 130), Color3.fromRGB(170, 30, 40), 135)
	Theme.stroke(badge, Theme.GOLD, 2.5, 0)
	Theme.text({ Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.12), Text = "LV", Font = Theme.BOLD, ZIndex = 3 }, badge)
	ui.level = Theme.title({ Size = UDim2.new(1, -8, 0.5, 0), Position = UDim2.new(0, 4, 0.4, 0), Text = "1", ZIndex = 3 }, badge)

	ui.adventure = Theme.text({ Size = UDim2.fromOffset(250, 16), Position = UDim2.fromOffset(74, 10), Font = Theme.BOLD, TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, bar)
	ui.timer = Theme.title({ Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(74, 26), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, bar)
	ui.kills = Theme.chip({ Size = UDim2.fromOffset(104, 32), Position = UDim2.new(1, -116, 0, 14), Text = "💀 0", ZIndex = 2 }, bar, Theme.BAD)

	local xp, fill = Theme.bar({ Size = UDim2.new(1, -84, 0, 7), Position = UDim2.new(0, 74, 1, -14), ZIndex = 2 }, bar,
		Color3.fromRGB(120, 235, 255), Color3.fromRGB(40, 140, 230))
	xp:FindFirstChildOfClass("TextLabel").Visible = false
	ui.xpFill = fill
end

-- Wave tracker: "WAVE 3 / 10" with a bar that fills as the wave goes on ---------------------

local function buildWaveTracker(root)
	local tracker = Theme.panel({ Size = UDim2.fromOffset(300, 40), Position = UDim2.new(0.5, -150, 0, 88), Visible = false }, root)
	ui.waveTracker = tracker
	ui.waveIcon = Theme.text({ Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(10, 4), Text = "🌊", ZIndex = 3 }, tracker)
	ui.waveText = Theme.title({ Size = UDim2.new(1, -140, 0, 24), Position = UDim2.fromOffset(44, 5), Text = "WAVE 1", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, MaxSize = 20 }, tracker)
	ui.waveNext = Theme.text({ Size = UDim2.fromOffset(90, 18), Position = UDim2.new(1, -100, 0, 8), Font = Theme.BOLD, TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, MaxSize = 14 }, tracker)
	local bar, fill = Theme.bar({ Size = UDim2.new(1, -24, 0, 5), Position = UDim2.new(0, 12, 1, -9), ZIndex = 3 }, tracker,
		Color3.fromRGB(110, 210, 255), Color3.fromRGB(30, 120, 220))
	bar:FindFirstChildOfClass("TextLabel").Visible = false
	ui.waveFill = fill
end

-- Wave banner: a big ribbon that slams in at the start of every wave --------------------------

local function buildWaveBanner(gui)
	local group = Theme.new("CanvasGroup", {
		Name = "WaveBanner", Size = UDim2.fromOffset(680, 150), Position = UDim2.new(0.5, -340, 0.36, 0),
		BackgroundTransparency = 1, Visible = false, ZIndex = 18,
	}, gui)
	ui.waveBanner = group
	ui.waveBannerScale = Theme.new("UIScale", {}, group)
	ui.waveTails = {}
	for _, side in { -1, 1 } do
		local tail = Theme.new("Frame", {
			Size = UDim2.fromOffset(40, 40), Position = side < 0 and UDim2.fromOffset(4, 55) or UDim2.new(1, -44, 0, 55),
			Rotation = 45, BackgroundColor3 = Theme.ACCENT, ZIndex = 17,
		}, group)
		Theme.gradient(tail, Color3.fromRGB(200, 200, 200), Color3.fromRGB(110, 110, 110))
		table.insert(ui.waveTails, tail)
	end
	local ribbon = Theme.new("Frame", {
		Size = UDim2.new(1, -40, 0, 70), Position = UDim2.fromOffset(20, 40), BackgroundColor3 = Theme.ACCENT, ZIndex = 18,
	}, group)
	ui.waveRibbon = ribbon
	Theme.corner(ribbon, 10)
	Theme.stroke(ribbon, Theme.GOLD, 3, 0)
	Theme.gradient(ribbon, Color3.fromRGB(255, 255, 255), Color3.fromRGB(130, 130, 130))
	ui.waveNumber = Theme.title({
		Size = UDim2.new(1, 0, 0, 56), Text = "WAVE 1", TextColor3 = Theme.GOLD, TextStrokeTransparency = 0, ZIndex = 20,
	}, group)
	ui.waveTitle = Theme.title({ Size = UDim2.new(1, -80, 0, 36), Position = UDim2.fromOffset(40, 58), Text = "", ZIndex = 20, TextStrokeTransparency = 0 }, group)
	ui.waveSub = Theme.text({
		Size = UDim2.new(1, -80, 0, 22), Position = UDim2.fromOffset(40, 118), Text = "", Font = Theme.BOLD, ZIndex = 20,
		TextStrokeTransparency = 0.3, MaxSize = 18,
	}, group)
end

-- Boss health bar (top of the screen while a Vice Admiral or the boss is near) ----------------

local function buildBossBar(root)
	local panel = Theme.panel({ Size = UDim2.fromOffset(620, 62), Position = UDim2.new(0.5, -310, 0, 136), Visible = false }, root)
	ui.bossBar = panel
	Theme.icon({ Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(10, 9), ZIndex = 3 }, panel, "☠️", Color3.fromRGB(150, 20, 30), 22)
	ui.bossName = Theme.title({ Size = UDim2.new(1, -150, 0, 22), Position = UDim2.fromOffset(64, 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, MaxSize = 20 }, panel)
	ui.bossPercent = Theme.title({ Size = UDim2.fromOffset(70, 22), Position = UDim2.new(1, -80, 0, 6), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, MaxSize = 18, TextColor3 = Theme.GOLD }, panel)
	local bar, fill = Theme.bar({ Size = UDim2.new(1, -76, 0, 16), Position = UDim2.fromOffset(64, 34), ZIndex = 3 }, panel,
		Color3.fromRGB(255, 90, 80), Color3.fromRGB(170, 20, 40))
	bar:FindFirstChildOfClass("TextLabel").Visible = false
	-- a pale "lag" bar shows the chunk just lost
	ui.bossLag = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 230, 200), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 3 }, bar)
	Theme.corner(ui.bossLag, 8)
	fill.ZIndex = 4
	ui.bossFill = fill
	ui.bossShown, ui.bossLagRatio = 1, 1
end

-- Combo counter -----------------------------------------------------------------------------

local COMBO_TIME = 4
local COMBO_TIERS = {
	{ 200, "LEGENDARY!", Color3.fromRGB(255, 80, 200) },
	{ 100, "UNSTOPPABLE!", Color3.fromRGB(255, 70, 70) },
	{ 50, "RAMPAGE!", Color3.fromRGB(255, 150, 40) },
	{ 20, "ON FIRE!", Color3.fromRGB(255, 220, 70) },
	{ 0, "COMBO", Theme.TEXT },
}

local function buildCombo(root)
	local frame = Theme.new("Frame", { Size = UDim2.fromOffset(190, 110), Position = UDim2.new(1, -210, 0.36, 0), BackgroundTransparency = 1, Visible = false }, root)
	ui.combo = frame
	ui.comboScale = Theme.new("UIScale", {}, frame)
	ui.comboCount = Theme.title({ Size = UDim2.new(1, 0, 0, 58), Text = "x0", TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0, ZIndex = 3 }, frame)
	ui.comboLabel = Theme.title({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 58), Text = "COMBO", TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0, ZIndex = 3, MaxSize = 22 }, frame)
	local bar, fill = Theme.bar({ Size = UDim2.new(0.7, 0, 0, 6), Position = UDim2.new(0.3, 0, 0, 90), ZIndex = 3 }, frame,
		Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 120, 40))
	bar:FindFirstChildOfClass("TextLabel").Visible = false
	ui.comboFill = fill
	ui.comboValue, ui.comboUntil, ui.lastKills = 0, 0, 0
end

-- Screen-space layer: arrows to off-screen chests and bosses, and the hurt flash --------------
-- Lives in its own unscaled ScreenGui so it lines up with the camera's pixels.

local MARKERS = 6

local function buildScreenLayer()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SwarmMarkers"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	ui.screenLayer = gui

	-- red edges that flash when you're hurt and pulse when you're low
	ui.vignette = {}
	for _, edge in {
		{ UDim2.new(1, 0, 0, 140), UDim2.fromScale(0, 0), 90 },
		{ UDim2.new(1, 0, 0, 140), UDim2.new(0, 0, 1, -140), 270 },
		{ UDim2.new(0, 160, 1, 0), UDim2.fromScale(0, 0), 0 },
		{ UDim2.new(0, 160, 1, 0), UDim2.new(1, -160, 0, 0), 180 },
	} do
		local f = Theme.new("Frame", { Size = edge[1], Position = edge[2], BackgroundColor3 = Color3.fromRGB(220, 20, 30), BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
		Theme.new("UIGradient", { Transparency = NumberSequence.new(0, 1), Rotation = edge[3] }, f)
		table.insert(ui.vignette, f)
	end

	ui.markers = {}
	for i = 1, MARKERS do
		local m = Theme.new("Frame", { Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.PANEL, BackgroundTransparency = 0.15, Visible = false, ZIndex = 2 }, gui)
		Theme.corner(m, 24)
		local stroke = Theme.stroke(m, Theme.GOLD, 2, 0)
		local icon = Theme.text({ Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.12), Text = "", ZIndex = 3 }, m)
		local dist = Theme.text({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -4), Text = "", Font = Theme.BOLD, ZIndex = 3, MaxSize = 12, TextStrokeTransparency = 0.3 }, m)
		local arrow = Theme.text({ Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Text = "▲", TextColor3 = Theme.GOLD, Font = Theme.BOLD, ZIndex = 3, TextStrokeTransparency = 0.4 }, m)
		ui.markers[i] = { frame = m, icon = icon, dist = dist, arrow = arrow, stroke = stroke }
	end
end

local function flashHurt(amount)
	Effects.shake(math.clamp(amount * 6, 0.25, 1.2), 0.25)
	for _, f in ui.vignette do
		f.BackgroundTransparency = math.clamp(0.75 - amount * 2, 0.2, 0.7)
		Theme.tween(f, 0.5, { BackgroundTransparency = 1 })
	end
end

-- Skill action bar and health ------------------------------------------------------------

local function makeTile(parent, size, x, y)
	local tile, label = Theme.icon({ Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(x, y), ZIndex = 2 }, parent, "", Theme.CARD)
	local level = Theme.text({
		Size = UDim2.fromOffset(size * 0.62, 15), Position = UDim2.new(1, -size * 0.62 + 2, 1, -13), Font = Theme.BOLD,
		BackgroundTransparency = 0.15, BackgroundColor3 = Theme.BG, ZIndex = 4, MaxSize = 12,
	}, tile)
	Theme.corner(level, 6)
	local slot = { tile = tile, icon = label, level = level }
	tile.MouseEnter:Connect(function()
		if slot.tip then
			ui.tooltip.Text = slot.tip
			ui.tooltip.Visible = true
		end
	end)
	tile.MouseLeave:Connect(function()
		ui.tooltip.Visible = false
	end)
	return slot
end

local function buildActionBar(root)
	local width = Config.WEAPON_SLOTS_MAX * (SKILL_TILE + GAP) + Config.PASSIVE_SLOTS * (PASSIVE_TILE + GAP) + 34
	local bar = Theme.panel({ Size = UDim2.fromOffset(width, 74), Position = UDim2.new(0.5, -width / 2, 1, -132) }, root)
	ui.weaponSlots, ui.passiveSlots = {}, {}
	local x = 12
	for i = 1, Config.WEAPON_SLOTS_MAX do
		ui.weaponSlots[i] = makeTile(bar, SKILL_TILE, x, 11)
		x += SKILL_TILE + GAP
	end
	Theme.new("Frame", { Size = UDim2.fromOffset(2, 44), Position = UDim2.fromOffset(x + 2, 15), BackgroundColor3 = Theme.LINE, BackgroundTransparency = 0.85, BorderSizePixel = 0 }, bar)
	x += 12
	for i = 1, Config.PASSIVE_SLOTS do
		ui.passiveSlots[i] = makeTile(bar, PASSIVE_TILE, x, 16)
		x += PASSIVE_TILE + GAP
	end
	ui.tooltip = Theme.chip({
		Size = UDim2.fromOffset(320, 28), Position = UDim2.new(0.5, -160, 0, -36), Visible = false, ZIndex = 5,
		BackgroundTransparency = 0.1, TextColor3 = Theme.TEXT, MaxSize = 15,
	}, bar, Theme.PANEL)
end

local function buildHealth(root)
	local panel = Theme.panel({ Size = UDim2.fromOffset(480, 40), Position = UDim2.new(0.5, -240, 1, -52) }, root)
	Theme.icon({ Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(7, 6), ZIndex = 2 }, panel, "❤️", Theme.BAD, 8)
	local _, fill, text = Theme.bar({ Size = UDim2.new(1, -140, 0, 18), Position = UDim2.fromOffset(44, 11), ZIndex = 2 }, panel,
		Color3.fromRGB(255, 120, 130), Color3.fromRGB(220, 40, 70))
	ui.hpFill, ui.hpText = fill, text

	-- dash: Shift / L2 / the on-screen button; the dark overlay drains as it recharges
	local dash = Theme.new("TextButton", {
		Size = UDim2.fromOffset(84, 28), Position = UDim2.new(1, -90, 0, 6), Text = UIS.TouchEnabled and not UIS.KeyboardEnabled and "💨 DASH" or "💨 SHIFT", Font = Theme.BOLD,
		TextScaled = true, TextColor3 = Theme.TEXT, BackgroundColor3 = Theme.ACCENT, AutoButtonColor = false, ZIndex = 2,
	}, panel)
	Theme.corner(dash, 8)
	Theme.padding(dash, 5)
	ui.dashShade = Theme.new("Frame", {
		Size = UDim2.new(0, 0, 1, 10), Position = UDim2.fromOffset(-5, -5), BackgroundColor3 = Theme.BG,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 3,
	}, dash)
	Theme.corner(ui.dashShade, 8)
	dash.Activated:Connect(function()
		callbacks.dash()
	end)

	local function bind(character)
		local hum = character:WaitForChild("Humanoid")
		local last = hum.Health
		local function update()
			local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			Theme.tween(ui.hpFill, 0.15, { Size = UDim2.fromScale(ratio, 1) })
			ui.hpText.Text = string.format("%d / %d", math.ceil(hum.Health), math.floor(hum.MaxHealth))
			if hum.Health < last - 0.5 and ui.root.Visible then
				flashHurt((last - hum.Health) / math.max(hum.MaxHealth, 1))
			end
			last = hum.Health
			ui.lowHealth = ratio < 0.3 and hum.Health > 0
		end
		hum.HealthChanged:Connect(update)
		hum:GetPropertyChangedSignal("MaxHealth"):Connect(update)
		update()
	end
	player.CharacterAdded:Connect(bind)
	if player.Character then
		task.spawn(bind, player.Character)
	end
end

local function fillSlot(slot, info, max, locked)
	slot.tip = nil
	slot.level.Visible = false
	if locked then
		slot.tile.BackgroundColor3 = Theme.LOCKED
		slot.icon.Text = "🔒"
		slot.icon.TextTransparency = 0.4
		slot.tip = "Locked  -  buy more Skill Slots in the Shop"
		return
	end
	slot.icon.TextTransparency = 0
	if not info then
		slot.tile.BackgroundColor3 = Theme.CARD
		slot.icon.Text = ""
		return
	end
	slot.tile.BackgroundColor3 = info.color or Color3.fromRGB(120, 130, 170)
	slot.icon.Text = info.icon or initials(info.name)
	slot.level.Visible = true
	if info.fused then
		slot.level.Text, slot.level.TextColor3 = "FUSE", FUSION_COLOR
	elseif info.evo then
		slot.level.Text, slot.level.TextColor3 = "EVO", EVO_COLOR
	else
		local maxed = info.level >= max
		slot.level.Text = maxed and "MAX" or tostring(info.level)
		slot.level.TextColor3 = maxed and Theme.GOLD or Theme.TEXT
	end
	slot.tip = info.name .. (info.fused and "  (fused)" or info.evo and "  (evolved)" or "  -  level " .. info.level)
end

-- Leave button and the knocked-out panel ---------------------------------------------------

local function buildCrewControls(root)
	local confirmUntil = 0
	ui.leave = Theme.button({
		Size = UDim2.fromOffset(150, 38), Position = UDim2.fromOffset(16, 16), Text = "🏳️  LEAVE",
		BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 2,
	}, root, function()
		if os.clock() < confirmUntil then
			callbacks.leave()
		else
			-- ask twice so nobody leaves by accident
			confirmUntil = os.clock() + 3
			ui.leave.Text = "TAP AGAIN"
			ui.leave.BackgroundColor3 = Theme.BAD
			task.delay(3, function()
				ui.leave.Text = "🏳️  LEAVE"
				ui.leave.BackgroundColor3 = Theme.CARD_LIGHT
			end)
		end
	end)

	Theme.button({ Size = UDim2.fromOffset(44, 38), Position = UDim2.fromOffset(174, 16), Text = "⚙️", BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 2 }, root, function()
		callbacks.settings()
	end)

	-- crewmates' health, under the leave button
	ui.crewList = Theme.new("Frame", { Size = UDim2.fromOffset(210, 200), Position = UDim2.fromOffset(16, 64), BackgroundTransparency = 1 }, root)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, ui.crewList)
	ui.crewRows = {}

	local down = Theme.panel({ Size = UDim2.fromOffset(440, 118), Position = UDim2.new(0.5, -220, 1, -262), Visible = false, ZIndex = 5 }, root)
	ui.down = down
	Theme.title({ Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 10), Text = "KNOCKED OUT", TextColor3 = Theme.BAD, ZIndex = 6 }, down)
	Theme.button({ Size = UDim2.fromOffset(38, 32), Position = UDim2.fromOffset(12, 42), Text = "◀", BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 6 }, down, function()
		callbacks.spectate(-1)
	end)
	ui.watching = Theme.text({ Size = UDim2.new(1, -124, 0, 32), Position = UDim2.fromOffset(62, 42), Text = "", Font = Theme.BOLD, ZIndex = 6, MaxSize = 16 }, down)
	Theme.button({ Size = UDim2.fromOffset(38, 32), Position = UDim2.new(1, -50, 0, 42), Text = "▶", BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 6 }, down, function()
		callbacks.spectate(1)
	end)
	ui.revive = Theme.button({
		Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 80), Text = "💖  REVIVE",
		BackgroundColor3 = Color3.fromRGB(230, 70, 130), ZIndex = 6,
	}, down, function()
		callbacks.revive(ui.revives or 0)
	end)
end

-- Level-up cards ----------------------------------------------------------------------

local function setPips(container, level, max, color)
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if not level or not max then
		return
	end
	local width = math.floor((CARD_W - 60) / max) - 4
	for i = 1, max do
		local pip = Theme.new("Frame", {
			Size = UDim2.fromOffset(width, 6), ZIndex = 24,
			BackgroundColor3 = i <= level and color or Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = i <= level and 0 or 0.88,
		}, container)
		Theme.corner(pip, 3)
	end
end

local function buildLevelUp(gui)
	local overlay = Theme.new("Frame", {
		Name = "LevelUp", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.BG,
		BackgroundTransparency = 0.35, Visible = false, ZIndex = 20,
	}, gui)
	ui.levelOverlay = overlay
	ui.levelTitle = Theme.title({ Size = UDim2.fromOffset(600, 54), Position = UDim2.new(0.5, -300, 0.5, -262), Text = "LEVEL UP", ZIndex = 21 }, overlay)
	Theme.text({
		Size = UDim2.fromOffset(600, 22), Position = UDim2.new(0.5, -300, 0.5, -206), ZIndex = 21,
		Text = "Choose a power  -  press 1, 2 or 3", TextColor3 = Theme.MUTED, MaxSize = 18,
	}, overlay)

	local width = Config.CHOICES * CARD_W + (Config.CHOICES - 1) * CARD_GAP
	local row = Theme.new("Frame", {
		Size = UDim2.fromOffset(width, CARD_H), Position = UDim2.new(0.5, -width / 2, 0.5, -170),
		BackgroundTransparency = 1, ZIndex = 21,
	}, overlay)
	for i = 1, Config.CHOICES do
		local x = (i - 1) * (CARD_W + CARD_GAP)
		local button = Theme.new("TextButton", {
			Size = UDim2.fromOffset(CARD_W, CARD_H), Position = UDim2.fromOffset(x, 0), Text = "",
			AutoButtonColor = false, BackgroundColor3 = Theme.CARD, ZIndex = 22,
		}, row)
		Theme.corner(button, 18)
		local stroke = Theme.stroke(button, Theme.ACCENT, 2, 0.5)
		Theme.gradient(button, Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 165, 195))
		local accent = Theme.new("Frame", { Size = UDim2.new(1, -36, 0, 4), Position = UDim2.fromOffset(18, 0), BorderSizePixel = 0, ZIndex = 23 }, button)
		Theme.corner(accent, 2)
		local tag = Theme.chip({ Size = UDim2.fromOffset(130, 24), Position = UDim2.fromOffset(14, 16), ZIndex = 23, MaxSize = 13 }, button)
		Theme.chip({ Size = UDim2.fromOffset(26, 24), Position = UDim2.new(1, -40, 0, 16), Text = tostring(i), ZIndex = 23, MaxSize = 13 }, button, Theme.LINE)
		local icon, iconText = Theme.icon({ Size = UDim2.fromOffset(92, 92), Position = UDim2.new(0.5, -46, 0, 54), ZIndex = 23 }, button, "", Theme.ACCENT, 22)
		local title = Theme.title({ Size = UDim2.new(1, -28, 0, 44), Position = UDim2.fromOffset(14, 158), TextWrapped = true, ZIndex = 23, MaxSize = 22 }, button)
		local desc = Theme.text({ Size = UDim2.new(1, -32, 0, 72), Position = UDim2.fromOffset(16, 206), TextWrapped = true, TextColor3 = Theme.MUTED, ZIndex = 23, MaxSize = 16 }, button)
		local pips = Theme.new("Frame", { Size = UDim2.new(1, -40, 0, 6), Position = UDim2.new(0, 20, 1, -26), BackgroundTransparency = 1, ZIndex = 23 }, button)
		-- a shine sweeps across each card as it appears
		local shine = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, ZIndex = 25 }, button)
		Theme.corner(shine, 18)
		local shineGradient = Theme.new("UIGradient", {
			Rotation = 25, Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1),
			}),
		}, shine)
		Theme.rivets(button, 8, 24)
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }, pips)

		button.MouseEnter:Connect(function()
			Theme.tween(button, 0.15, { Position = UDim2.fromOffset(x, -8) })
			Theme.tween(stroke, 0.15, { Transparency = 0, Thickness = 3 })
		end)
		button.MouseLeave:Connect(function()
			Theme.tween(button, 0.15, { Position = UDim2.fromOffset(x, 0) })
			Theme.tween(stroke, 0.15, { Transparency = 0.5, Thickness = 2 })
		end)
		button.Activated:Connect(function()
			Hud.choose(i)
		end)
		cards[i] = { button = button, stroke = stroke, accent = accent, tag = tag, icon = icon, iconText = iconText, title = title, desc = desc, pips = pips, x = x, shine = shineGradient }
	end

	ui.reroll = Theme.button({
		Size = UDim2.fromOffset(220, 46), Position = UDim2.new(0.5, -110, 0.5, 180), Text = "🎲  REROLL  (R)",
		BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 22,
	}, overlay, function()
		Hud.reroll()
	end)
end

-- Announcements and results -------------------------------------------------------------

local function buildBanners(gui)
	local banner = Theme.panel({ Size = UDim2.fromOffset(600, 64), Position = UDim2.new(0.5, -300, 0, 206), Visible = false, ZIndex = 15 }, gui)
	ui.announce = banner
	ui.announceBar = Theme.new("Frame", { Size = UDim2.new(0, 6, 1, -20), Position = UDim2.fromOffset(12, 10), BorderSizePixel = 0, ZIndex = 16 }, banner)
	Theme.corner(ui.announceBar, 3)
	ui.announceText = Theme.title({ Size = UDim2.new(1, -50, 1, -18), Position = UDim2.fromOffset(30, 9), ZIndex = 16 }, banner)

	local overlay = Theme.new("Frame", {
		Name = "Results", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.BG,
		BackgroundTransparency = 0.35, Visible = false, ZIndex = 30,
	}, gui)
	ui.results = overlay
	local card = Theme.panel({ Size = UDim2.fromOffset(500, 620), Position = UDim2.new(0.5, -250, 0.5, -310), ZIndex = 31 }, overlay)
	ui.resultScale = Theme.new("UIScale", {}, card)
	local tile, icon = Theme.icon({ Size = UDim2.fromOffset(72, 72), Position = UDim2.new(0.5, -36, 0, 22), ZIndex = 32 }, card, "🏆", Theme.GOLD, 20)
	ui.resultTile, ui.resultIcon = tile, icon
	ui.resultTitle = Theme.title({ Size = UDim2.new(1, -40, 0, 46), Position = UDim2.fromOffset(20, 102), ZIndex = 32 }, card)
	ui.resultAdventure = Theme.chip({ Size = UDim2.fromOffset(300, 26), Position = UDim2.new(0.5, -150, 0, 152), ZIndex = 32, MaxSize = 14 }, card)
	ui.resultRows = {}
	for i, name in { "Time", "Level", "Defeated" } do
		local stat = Theme.card({ Size = UDim2.fromOffset(142, 74), Position = UDim2.fromOffset(20 + (i - 1) * 154, 194), ZIndex = 32 }, card)
		ui.resultRows[i] = Theme.title({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 10), ZIndex = 33 }, stat)
		Theme.text({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 46), Text = name, TextColor3 = Theme.MUTED, ZIndex = 33, MaxSize = 14 }, stat)
	end
	ui.resultGold = Theme.title({ Size = UDim2.new(1, -40, 0, 46), Position = UDim2.fromOffset(20, 282), TextColor3 = Theme.GOLD, ZIndex = 32 }, card)
	ui.resultUnlocked = Theme.chip({ Size = UDim2.fromOffset(460, 28), Position = UDim2.new(0.5, -230, 0, 334), ZIndex = 32, MaxSize = 14 }, card, Theme.GOOD)
	ui.resultUnlocked.TextWrapped = true
	Theme.divider({ Size = UDim2.new(1, -60, 0, 2), Position = UDim2.fromOffset(30, 374), ZIndex = 32 }, card)
	Theme.title({ Size = UDim2.new(1, -40, 0, 20), Position = UDim2.fromOffset(20, 382), Text = "DAMAGE BY SKILL", TextColor3 = Theme.GOLD, ZIndex = 32, MaxSize = 18 }, card)
	ui.damageRows = {}
	for i = 1, 6 do
		local row = Theme.new("Frame", { Size = UDim2.new(1, -60, 0, 26), Position = UDim2.fromOffset(30, 408 + (i - 1) * 30), BackgroundTransparency = 1, ZIndex = 32 }, card)
		local icon = Theme.text({ Size = UDim2.fromOffset(26, 26), Text = "", ZIndex = 33 }, row)
		local name = Theme.text({ Size = UDim2.new(0.45, -32, 1, 0), Position = UDim2.fromOffset(32, 0), Font = Theme.BOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33, MaxSize = 14 }, row)
		local bar = Theme.new("Frame", { Size = UDim2.new(0.55, -70, 0, 12), Position = UDim2.new(0.45, 0, 0.5, -6), BackgroundColor3 = Theme.BG, BackgroundTransparency = 0.3, ZIndex = 33 }, row)
		Theme.corner(bar, 6)
		local fill = Theme.new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, ZIndex = 34 }, bar)
		Theme.corner(fill, 6)
		local amount = Theme.text({ Size = UDim2.fromOffset(64, 26), Position = UDim2.new(1, -64, 0, 0), Font = Theme.BOLD, TextColor3 = Theme.GOLD, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 33, MaxSize = 14 }, row)
		ui.damageRows[i] = { row = row, icon = icon, name = name, fill = fill, amount = amount }
	end
	Theme.text({
		Size = UDim2.new(1, -40, 0, 18), Position = UDim2.new(0, 20, 1, -36), ZIndex = 32,
		Text = "Sailing back to the island...", TextColor3 = Theme.MUTED, MaxSize = 15,
	}, card)
end

-- Count a label up from 0 to `value`.
local function countUp(label, value, format)
	local number = Instance.new("NumberValue")
	number.Changed:Connect(function(v)
		label.Text = format(v)
	end)
	label.Text = format(0)
	Theme.tween(number, 1.2, { Value = value })
	task.delay(1.3, function()
		number:Destroy()
	end)
end

-- Blurs the world behind full-screen menus.
local blur = Instance.new("BlurEffect")
blur.Size = 0
local function setBlur(on)
	blur.Parent = workspace.CurrentCamera
	Theme.tween(blur, 0.25, { Size = on and 14 or 0 })
end

-- Public -----------------------------------------------------------------------------------

function Hud.init(gui, cb)
	callbacks = cb
	local root = Theme.new("Frame", { Name = "RunHud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
	ui.root = root
	buildStatus(root)
	buildWaveTracker(root)
	buildBossBar(root)
	buildCombo(root)
	buildActionBar(root)
	buildScreenLayer()
	buildHealth(root)
	buildCrewControls(root)
	buildLevelUp(gui)
	buildBanners(gui)
	buildWaveBanner(gui)
	RunService.RenderStepped:Connect(Hud.update)
	Hud.setStats({ level = 1, xp = 0, need = 1, kills = 0, weapons = {}, passives = {}, slots = Config.WEAPON_SLOTS_START })
end

function Hud.setVisible(visible)
	ui.root.Visible = visible
	ui.screenLayer.Enabled = visible
	if not visible then
		Hud.showLevelUp(nil)
		ui.waveBanner.Visible = false
		ui.comboValue, ui.comboUntil = 0, 0
		ui.combo.Visible = false
	end
end

function Hud.setState(state)
	ui.adventure.Text = (state.adventure or ""):upper()
	ui.adventure.TextColor3 = state.color or Theme.MUTED
	ui.timer.Text = state.text or ""
	ui.timer.TextColor3 = state.boss and Theme.BAD or Theme.TEXT
	ui.down.Visible = state.down == true

	ui.waveTracker.Visible = (state.wave or 0) > 0
	if state.boss then
		ui.waveIcon.Text = "☠️"
		ui.waveText.Text = "FINAL WAVE"
		ui.waveText.TextColor3 = Theme.BAD
		ui.waveNext.Text = "BOSS"
		ui.waveFill.Size = UDim2.fromScale(1, 1)
	elseif state.wave then
		ui.waveIcon.Text = "🌊"
		ui.waveText.Text = string.format("WAVE %d / %d", state.wave, state.waves or state.wave)
		ui.waveText.TextColor3 = Theme.TEXT
		local left = state.waveLeft or 0
		local label = state.wave < (state.waves or 0) and "next" or "boss"
		ui.waveNext.Text = string.format("%s %d:%02d", label, left // 60, math.floor(left % 60))
		-- the State comes once a second: glide the bar to where it will be by the next one
		local length = Config.WAVE_LENGTH
		ui.waveFill.Size = UDim2.fromScale(math.clamp(1 - left / length, 0, 1), 1)
		Theme.tween(ui.waveFill, 1, { Size = UDim2.fromScale(math.clamp(1 - (left - 1) / length, 0, 1), 1) }, Enum.EasingStyle.Linear)
	end
end

-- The big banner at the start of each wave (and when the boss arrives).
function Hud.showWave(info)
	Sounds.play(info.boss and "Boss" or "Wave")
	local color = info.color or Theme.ACCENT
	ui.waveNumber.Text = info.boss and "FINAL WAVE" or "WAVE " .. tostring(info.n)
	ui.waveTitle.Text = info.title or ""
	ui.waveSub.Text = info.sub or ""
	ui.waveSub.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.6)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
	ui.waveRibbon.BackgroundColor3 = dark
	for _, tail in ui.waveTails do
		tail.BackgroundColor3 = dark
	end
	ui.waveBanner.Visible = true
	ui.waveBanner.GroupTransparency = 1
	ui.waveBanner.Position = UDim2.new(0.5, -340, 0.36, 0)
	ui.waveBannerScale.Scale = 1.6
	Theme.tween(ui.waveBanner, 0.25, { GroupTransparency = 0 })
	Theme.tween(ui.waveBannerScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local token = {}
	ui.waveToken = token
	task.delay(2.6, function()
		if ui.waveToken ~= token then
			return
		end
		Theme.tween(ui.waveBanner, 0.4, { GroupTransparency = 1, Position = UDim2.new(0.5, -340, 0.36, -40) })
		task.delay(0.45, function()
			if ui.waveToken == token then
				ui.waveBanner.Visible = false
			end
		end)
	end)
end

-- Bosses near me: the highest tier first (the map's boss over a Vice Admiral), then the closest.
local function findBoss(me)
	local folder = workspace:FindFirstChild("Enemies")
	local best, bestTier, bestDist
	for _, model in folder and folder:GetChildren() or {} do
		local torso = model:GetAttribute("Boss") and model:FindFirstChild("Torso")
		if torso then
			local d = (torso.Position - me).Magnitude
			local tier = model:GetAttribute("BossTier") or 1
			if d < 700 and (not best or tier > bestTier or tier == bestTier and d < bestDist) then
				best, bestTier, bestDist = model, tier, d
			end
		end
	end
	return best
end

-- Things worth an arrow at the screen edge: treasure chests and bosses, closest first.
local function markerTargets(me)
	local found = {}
	local folder = workspace:FindFirstChild("Enemies")
	for _, model in folder and folder:GetChildren() or {} do
		local icon
		if model.Name == "TreasureChest" then
			icon = "🎁"
		elseif model:GetAttribute("Boss") then
			icon = "☠️"
		end
		local pos = icon and model:GetPivot().Position
		if pos and (pos - me).Magnitude < 400 then
			table.insert(found, { pos = pos, icon = icon, d = (pos - me).Magnitude })
		end
	end
	table.sort(found, function(a, b)
		return a.d < b.d
	end)
	return found
end

local function updateMarkers(me)
	local camera = workspace.CurrentCamera
	local view = camera.ViewportSize
	local center = view / 2
	local margin = 54
	local targets = markerTargets(me)
	for i, m in ui.markers do
		local t = targets[i]
		local shown = false
		if t then
			local vp = camera:WorldToViewportPoint(t.pos)
			local onScreen = vp.Z > 0 and vp.X > margin and vp.X < view.X - margin and vp.Y > margin and vp.Y < view.Y - margin
			if not onScreen then
				-- push the marker to the screen edge in the target's direction
				local d = Vector2.new(vp.X, vp.Y) - center
				if vp.Z < 0 then
					d = -d
				end
				if d.Magnitude < 1 then
					d = Vector2.new(0, -1)
				end
				local hx, hy = center.X - margin, center.Y - margin
				local scale = math.min(hx / math.max(math.abs(d.X), 0.001), hy / math.max(math.abs(d.Y), 0.001))
				local pos = center + d * scale
				local angle = math.atan2(d.Y, d.X)
				m.frame.Position = UDim2.fromOffset(pos.X, pos.Y)
				m.arrow.Position = UDim2.new(0.5, math.cos(angle) * 34, 0.5, math.sin(angle) * 34)
				m.arrow.Rotation = math.deg(angle) + 90
				m.icon.Text = t.icon
				m.dist.Text = string.format("%dm", math.floor(t.d))
				m.stroke.Color = t.icon == "🎁" and Theme.GOLD or Theme.BAD
				m.arrow.TextColor3 = m.stroke.Color
				shown = true
			end
		end
		m.frame.Visible = shown
	end
end

local bossCheckAt = 0

-- Crewmates' health bars (everyone in the run but you).
local function updateCrew()
	for userId, row in ui.crewRows do
		local mate = Players:GetPlayerByUserId(userId)
		local hum = mate and mate.Character and mate.Character:FindFirstChildOfClass("Humanoid")
		local ratio = hum and math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1) or 0
		row.fill.Size = UDim2.fromScale(ratio, 1)
		row.state.Text = ratio <= 0 and "💀" or ""
		row.frame.BackgroundTransparency = ratio <= 0 and 0.5 or 0.15
	end
end

-- Builds the crew list from the run's crew (UserIds).
function Hud.setCrew(crew)
	local wanted = {}
	for _, userId in crew or {} do
		if userId ~= player.UserId then
			wanted[userId] = true
		end
	end
	for userId, row in ui.crewRows do
		if not wanted[userId] then
			row.frame:Destroy()
			ui.crewRows[userId] = nil
		end
	end
	for userId in wanted do
		if not ui.crewRows[userId] then
			local mate = Players:GetPlayerByUserId(userId)
			local frame = Theme.card({ Size = UDim2.fromOffset(210, 34), BackgroundColor3 = Theme.PANEL, BackgroundTransparency = 0.15 }, ui.crewList)
			Theme.text({ Size = UDim2.new(1, -40, 0, 14), Position = UDim2.fromOffset(8, 3), Text = mate and mate.DisplayName or "Crewmate", Font = Theme.BOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, MaxSize = 13 }, frame)
			local bar, fill = Theme.bar({ Size = UDim2.new(1, -16, 0, 8), Position = UDim2.fromOffset(8, 21), ZIndex = 2 }, frame,
				Color3.fromRGB(120, 240, 140), Color3.fromRGB(40, 170, 80))
			bar:FindFirstChildOfClass("TextLabel").Visible = false
			local state = Theme.text({ Size = UDim2.fromOffset(24, 18), Position = UDim2.new(1, -30, 0, 1), Text = "", ZIndex = 3 }, frame)
			ui.crewRows[userId] = { frame = frame, fill = fill, state = state }
		end
	end
end

-- Every frame while the HUD is up: boss bar, combo timer, markers, low-health pulse.
function Hud.update(dt)
	if not ui.root.Visible then
		return
	end
	local now = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local me = root and root.Position or workspace.CurrentCamera.Focus.Position

	-- boss bar: smooth fill plus a pale bar that catches up slowly
	if now >= bossCheckAt then
		bossCheckAt = now + 0.25
		local boss = findBoss(me)
		if boss ~= ui.boss then
			ui.boss = boss
			local hp = boss and boss:GetAttribute("Hp") or 1
			ui.bossShown, ui.bossLagRatio = hp, hp
		end
	end
	local boss = ui.boss
	ui.bossBar.Visible = boss ~= nil and boss.Parent ~= nil
	if ui.bossBar.Visible then
		local ratio = math.clamp(boss:GetAttribute("Hp") or 1, 0, 1)
		ui.bossName.Text = string.upper(boss:GetAttribute("Boss") or "")
		ui.bossShown += (ratio - ui.bossShown) * math.min(1, dt * 12)
		ui.bossLagRatio += (ratio - ui.bossLagRatio) * math.min(1, dt * 2)
		ui.bossFill.Size = UDim2.fromScale(ui.bossShown, 1)
		ui.bossLag.Size = UDim2.fromScale(math.max(ui.bossLagRatio, ui.bossShown), 1)
		ui.bossPercent.Text = string.format("%d%%", math.ceil(ratio * 100))
	end

	-- combo: fades out when the kills stop
	if ui.comboValue > 0 then
		local left = ui.comboUntil - now
		if left <= 0 then
			ui.comboValue = 0
			ui.combo.Visible = false
		else
			ui.comboFill.Size = UDim2.fromScale(left / COMBO_TIME, 1)
		end
	end

	updateMarkers(me)
	updateCrew()

	-- low health: the edges pulse red
	if ui.lowHealth then
		local pulse = 0.55 + math.sin(now * 6) * 0.2
		for _, f in ui.vignette do
			if f.BackgroundTransparency > pulse then
				f.BackgroundTransparency = pulse
			end
		end
	end
end

-- Kill streaks: big numbers on the right, with a shout at 20, 50, 100 and 200.
local function addCombo(kills)
	local before = ui.comboValue
	ui.comboValue += kills
	ui.comboUntil = os.clock() + COMBO_TIME
	if ui.comboValue < 3 then
		return -- only show real streaks
	end
	for _, tier in COMBO_TIERS do
		if ui.comboValue >= tier[1] then
			ui.comboLabel.Text = tier[2]
			ui.comboLabel.TextColor3 = tier[3]
			ui.comboCount.TextColor3 = tier[3]:Lerp(Color3.new(1, 1, 1), 0.3)
			if before < tier[1] and tier[1] > 0 then
				Hud.announce(tier[2] .. "  " .. tier[1] .. " KILL COMBO", tier[3])
			end
			break
		end
	end
	ui.comboCount.Text = "x" .. ui.comboValue
	ui.combo.Visible = true
	ui.comboScale.Scale = 1.35
	Theme.tween(ui.comboScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end


-- Revives the player owns (from the store), shown on the knocked-out panel.
local function refreshRevive()
	if not ui.revive then
		return -- not built yet: Hud.init shows it
	end
	local count = ui.revives or 0
	if count > 0 then
		ui.revive.Text = string.format("💖  REVIVE  (%d left)", count)
	else
		ui.revive.Text = ui.revivePrice and string.format("💖  REVIVE NOW  R$ %d", ui.revivePrice) or "💖  BUY A REVIVE"
	end
end

function Hud.setRevives(count)
	ui.revives = count
	refreshRevive()
end

-- The Robux price of a revive, shown when the player has none left.
function Hud.setRevivePrice(price)
	ui.revivePrice = price
	refreshRevive()
end

function Hud.setWatching(name)
	ui.watching.Text = name and "Watching " .. name or "No crewmates standing"
end

-- Shows the dash recharging over `cooldown` seconds.
function Hud.dashUsed(cooldown)
	ui.dashShade.Size = UDim2.new(1, 10, 1, 10)
	Theme.tween(ui.dashShade, cooldown, { Size = UDim2.new(0, 0, 1, 10) }, Enum.EasingStyle.Linear)
end

function Hud.setStats(st)
	Theme.tween(ui.xpFill, 0.2, { Size = UDim2.fromScale(math.clamp(st.xp / st.need, 0, 1), 1) })
	ui.level.Text = tostring(st.level)
	ui.kills.Text = "💀 " .. Theme.comma(st.kills)
	if st.kills > ui.lastKills and ui.root.Visible then
		addCombo(st.kills - ui.lastKills)
	end
	ui.lastKills = st.kills
	local unlocked = st.slots or Config.WEAPON_SLOTS_START
	for i, slot in ui.weaponSlots do
		fillSlot(slot, st.weapons[i], Config.WEAPON_MAX, i > unlocked)
	end
	for i, slot in ui.passiveSlots do
		fillSlot(slot, st.passives[i], Config.PASSIVE_MAX, false)
	end
end

function Hud.showLevelUp(list, rerolls)
	if not list then
		if ui.levelOverlay.Visible then
			setBlur(false)
		end
		ui.levelOverlay.Visible = false
		return
	end
	for i, card in cards do
		local c = list[i]
		card.button.Visible = c ~= nil
		if c then
			local tint = c.tag == "EVOLUTION" and EVO_COLOR or c.tag == "FUSION" and FUSION_COLOR or c.color
			card.tag.Text = c.tag or ""
			card.tag.BackgroundColor3 = tint
			card.tag.TextColor3 = tint:Lerp(Color3.new(1, 1, 1), 0.5)
			card.accent.BackgroundColor3 = tint
			card.stroke.Color = tint
			card.icon.BackgroundColor3 = c.color
			card.iconText.Text = c.icon or initials(c.title)
			card.title.Text = c.title
			card.desc.Text = c.text
			setPips(card.pips, c.level, c.max, tint)
			-- cards rise into place one after another
			card.button.Position = UDim2.fromOffset(card.x, 70)
			Theme.tween(card.button, 0.35 + i * 0.06, { Position = UDim2.fromOffset(card.x, 0) }, Enum.EasingStyle.Back)
			card.shine.Offset = Vector2.new(-1, 0)
			task.delay(0.25 + i * 0.12, function()
				Theme.tween(card.shine, 0.6, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			end)
		end
	end
	ui.reroll.Text = string.format("🎲  REROLL (R)  x%d", rerolls or 0)
	ui.reroll.Visible = (rerolls or 0) > 0
	if not ui.levelOverlay.Visible then
		setBlur(true)
		Sounds.play("LevelUp")
	end
	ui.levelOverlay.Visible = true
end

function Hud.choose(i)
	if ui.levelOverlay.Visible and cards[i] and cards[i].button.Visible then
		ui.levelOverlay.Visible = false -- the server sends the next offer, if any
		setBlur(false)
		callbacks.choose(i)
	end
end

function Hud.reroll()
	if ui.levelOverlay.Visible and ui.reroll.Visible then
		callbacks.reroll()
	end
end

function Hud.announce(text, color)
	color = color or Theme.GOLD
	ui.announceText.Text = text:upper()
	ui.announceText.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
	ui.announceBar.BackgroundColor3 = color
	ui.announce:FindFirstChildOfClass("UIStroke").Color = color
	ui.announce.Position = UDim2.new(0.5, -300, 0, 176)
	ui.announce.Visible = true
	Theme.tween(ui.announce, 0.35, { Position = UDim2.new(0.5, -300, 0, 206) }, Enum.EasingStyle.Back)
	task.delay(2.8, function()
		ui.announce.Visible = false
	end)
end

function Hud.showResults(r)
	local victory = r.result == "Victory"
	ui.resultTitle.Text = victory and "VICTORY" or "DEFEATED"
	ui.resultTitle.TextColor3 = victory and Theme.GOLD or Theme.BAD
	ui.resultIcon.Text = victory and "🏆" or "☠️"
	ui.resultTile.BackgroundColor3 = victory and Theme.GOLD or Theme.BAD
	ui.resultAdventure.Text = r.adventure or ""
	ui.resultAdventure.BackgroundColor3 = r.color or Theme.ACCENT
	local notes = {}
	if r.firstClear then
		table.insert(notes, "⭐ First clear +" .. Theme.comma(r.firstClear))
	end
	if r.unlocked then
		table.insert(notes, "🔓 " .. r.unlocked)
	end
	if r.drop then
		table.insert(notes, r.drop)
	end
	ui.resultUnlocked.Text = table.concat(notes, "   ")
	ui.resultUnlocked.Visible = #notes > 0
	countUp(ui.resultRows[1], r.time, function(v)
		v = math.floor(v)
		return string.format("%d:%02d", v // 60, v % 60)
	end)
	countUp(ui.resultRows[2], r.level, function(v)
		return tostring(math.floor(v))
	end)
	countUp(ui.resultRows[3], r.kills, function(v)
		return Theme.comma(v)
	end)
	countUp(ui.resultGold, r.gold, function(v)
		return "+" .. Theme.comma(v) .. " 💰"
	end)
	local damage = r.damage or {}
	local top = damage[1] and damage[1].amount or 1
	for i, row in ui.damageRows do
		local d = damage[i]
		row.row.Visible = d ~= nil
		if d then
			row.icon.Text = d.icon or ""
			row.name.Text = d.name
			row.fill.BackgroundColor3 = d.color or Theme.ACCENT
			row.fill.Size = UDim2.fromScale(0, 1)
			Theme.tween(row.fill, 0.8 + i * 0.1, { Size = UDim2.fromScale(d.amount / top, 1) })
			row.amount.Text = d.amount >= 10000 and string.format("%.1fK", d.amount / 1000) or Theme.comma(d.amount)
		end
	end
	ui.results.Visible = true
	setBlur(true)
	ui.resultScale.Scale = 0.7
	Theme.tween(ui.resultScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(Config.RESULTS_TIME, function()
		ui.results.Visible = false
		setBlur(false)
	end)
end

return Hud
