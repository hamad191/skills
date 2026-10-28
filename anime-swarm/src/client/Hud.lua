-- In-run HUD: status bar (level, XP, map, timer, kills), skill action bar, health,
-- level-up cards, boss announcements and the results screen.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)

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
	Theme.gradient(badge, Color3.fromRGB(170, 190, 255), Color3.fromRGB(90, 70, 220), 135)
	Theme.text({ Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.12), Text = "LV", Font = Theme.BOLD, ZIndex = 3 }, badge)
	ui.level = Theme.title({ Size = UDim2.new(1, -8, 0.5, 0), Position = UDim2.new(0, 4, 0.4, 0), Text = "1", ZIndex = 3 }, badge)

	ui.adventure = Theme.text({ Size = UDim2.fromOffset(250, 16), Position = UDim2.fromOffset(74, 10), Font = Theme.BOLD, TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, bar)
	ui.timer = Theme.title({ Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(74, 26), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, bar)
	ui.kills = Theme.chip({ Size = UDim2.fromOffset(104, 32), Position = UDim2.new(1, -116, 0, 14), Text = "💀 0", ZIndex = 2 }, bar, Theme.BAD)

	local xp, fill = Theme.bar({ Size = UDim2.new(1, -84, 0, 6), Position = UDim2.new(0, 74, 1, -12), ZIndex = 2 }, bar,
		Color3.fromRGB(110, 230, 255), Color3.fromRGB(99, 132, 255))
	xp:FindFirstChildOfClass("TextLabel").Visible = false
	ui.xpFill = fill
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
	local panel = Theme.panel({ Size = UDim2.fromOffset(400, 40), Position = UDim2.new(0.5, -200, 1, -52) }, root)
	Theme.icon({ Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(7, 6), ZIndex = 2 }, panel, "❤️", Theme.BAD, 8)
	local _, fill, text = Theme.bar({ Size = UDim2.new(1, -54, 0, 18), Position = UDim2.fromOffset(44, 11), ZIndex = 2 }, panel,
		Color3.fromRGB(255, 120, 130), Color3.fromRGB(220, 40, 70))
	ui.hpFill, ui.hpText = fill, text
	ui.down = Theme.title({
		Size = UDim2.fromOffset(600, 34), Position = UDim2.new(0.5, -300, 1, -176), Visible = false,
		Text = "KNOCKED OUT  -  your crew fights on", TextColor3 = Theme.BAD,
	}, root)

	local function bind(character)
		local hum = character:WaitForChild("Humanoid")
		local function update()
			local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			Theme.tween(ui.hpFill, 0.15, { Size = UDim2.fromScale(ratio, 1) })
			ui.hpText.Text = string.format("%d / %d", math.ceil(hum.Health), math.floor(hum.MaxHealth))
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
		cards[i] = { button = button, stroke = stroke, accent = accent, tag = tag, icon = icon, iconText = iconText, title = title, desc = desc, pips = pips, x = x }
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
	local banner = Theme.panel({ Size = UDim2.fromOffset(600, 64), Position = UDim2.new(0.5, -300, 0.2, 0), Visible = false, ZIndex = 15 }, gui)
	ui.announce = banner
	ui.announceBar = Theme.new("Frame", { Size = UDim2.new(0, 6, 1, -20), Position = UDim2.fromOffset(12, 10), BorderSizePixel = 0, ZIndex = 16 }, banner)
	Theme.corner(ui.announceBar, 3)
	ui.announceText = Theme.title({ Size = UDim2.new(1, -50, 1, -18), Position = UDim2.fromOffset(30, 9), ZIndex = 16 }, banner)

	local overlay = Theme.new("Frame", {
		Name = "Results", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.BG,
		BackgroundTransparency = 0.35, Visible = false, ZIndex = 30,
	}, gui)
	ui.results = overlay
	local card = Theme.panel({ Size = UDim2.fromOffset(500, 440), Position = UDim2.new(0.5, -250, 0.5, -220), ZIndex = 31 }, overlay)
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
	ui.resultUnlocked = Theme.chip({ Size = UDim2.fromOffset(440, 28), Position = UDim2.new(0.5, -220, 0, 338), ZIndex = 32, MaxSize = 14 }, card, Theme.GOOD)
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
	buildActionBar(root)
	buildHealth(root)
	buildLevelUp(gui)
	buildBanners(gui)
	Hud.setStats({ level = 1, xp = 0, need = 1, kills = 0, weapons = {}, passives = {}, slots = Config.WEAPON_SLOTS_START })
end

function Hud.setVisible(visible)
	ui.root.Visible = visible
	if not visible then
		Hud.showLevelUp(nil)
	end
end

function Hud.setState(state)
	ui.adventure.Text = (state.adventure or ""):upper()
	ui.adventure.TextColor3 = state.color or Theme.MUTED
	ui.timer.Text = state.text or ""
	ui.timer.TextColor3 = state.text == "FINAL BOSS!" and Theme.BAD or Theme.TEXT
	ui.down.Visible = state.down == true
end

function Hud.setStats(st)
	Theme.tween(ui.xpFill, 0.2, { Size = UDim2.fromScale(math.clamp(st.xp / st.need, 0, 1), 1) })
	ui.level.Text = tostring(st.level)
	ui.kills.Text = "💀 " .. Theme.comma(st.kills)
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
		end
	end
	ui.reroll.Text = string.format("🎲  REROLL (R)  x%d", rerolls or 0)
	ui.reroll.Visible = (rerolls or 0) > 0
	if not ui.levelOverlay.Visible then
		setBlur(true)
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
	ui.announce.Position = UDim2.new(0.5, -300, 0.2, -30)
	ui.announce.Visible = true
	Theme.tween(ui.announce, 0.35, { Position = UDim2.new(0.5, -300, 0.2, 0) }, Enum.EasingStyle.Back)
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
	ui.resultUnlocked.Text = r.unlocked and "🔓 " .. r.unlocked or ""
	ui.resultUnlocked.Visible = r.unlocked ~= nil
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
