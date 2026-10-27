-- In-run HUD: XP bar, adventure timer, kills, health, skill slots,
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

local CARD_W, CARD_H, CARD_GAP = 230, 300, 22

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

-- Top bar: XP, level, adventure + timer, kills ----------------------------------

local function buildTop(root)
	local _, xpFill, xpText = Theme.bar({
		Size = UDim2.new(1, -150, 0, 20), Position = UDim2.new(0, 80, 0, 12),
	}, root, Color3.fromRGB(110, 220, 255), Color3.fromRGB(40, 110, 255))
	ui.xpFill, ui.xpText = xpFill, xpText

	local badge = Theme.new("Frame", {
		Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0, 16, 0, -6), BackgroundColor3 = Theme.GOLD,
	}, root)
	Theme.corner(badge, 28)
	Theme.stroke(badge, Color3.fromRGB(80, 50, 0), 3)
	Theme.gradient(badge, Color3.fromRGB(255, 240, 160), Color3.fromRGB(230, 150, 20))
	Theme.title({ Size = UDim2.new(1, 0, 0.35, 0), Position = UDim2.fromScale(0, 0.1), Text = "LV", TextColor3 = Theme.DARK_TEXT, TextStrokeTransparency = 1 }, badge)
	ui.level = Theme.title({ Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.42), Text = "1", TextColor3 = Color3.new(1, 1, 1) }, badge)

	local pill = Theme.panel({ Size = UDim2.fromOffset(260, 64), Position = UDim2.new(0.5, -130, 0, 42) }, root)
	ui.adventure = Theme.title({ Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 6), Text = "" }, pill)
	ui.timer = Theme.text({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 28), Text = "", MaxSize = 30 }, pill)

	local kills = Theme.panel({ Size = UDim2.fromOffset(140, 44), Position = UDim2.new(1, -156, 0, 46) }, root)
	ui.kills = Theme.title({ Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5), Text = "💀 0", TextColor3 = Theme.TEXT }, kills)
end

-- Health bar ------------------------------------------------------------------------

local function buildHealth(root)
	local frame
	frame, ui.hpFill, ui.hpText = Theme.bar({
		Size = UDim2.fromOffset(420, 28), Position = UDim2.new(0.5, -210, 1, -52),
	}, root, Color3.fromRGB(255, 110, 110), Color3.fromRGB(190, 20, 40))
	ui.health = frame
	ui.down = Theme.title({
		Size = UDim2.fromOffset(600, 44), Position = UDim2.new(0.5, -300, 1, -110), Visible = false,
		Text = "KNOCKED OUT! Your crew fights on...", TextColor3 = Theme.BAD,
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

-- Skill and passive slots (left side) -----------------------------------------------

local function buildSlots(root)
	local column = Theme.new("Frame", {
		Size = UDim2.fromOffset(220, 420), Position = UDim2.new(0, 14, 0.5, -190), BackgroundTransparency = 1,
	}, root)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, column)
	ui.weaponSlots, ui.passiveSlots = {}, {}

	local order = 0
	local function header(text)
		order += 1
		Theme.title({ Size = UDim2.new(1, 0, 0, 24), Text = text, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order }, column)
	end
	local function slot()
		order += 1
		local frame = Theme.new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.CARD, BackgroundTransparency = 0.15, LayoutOrder = order }, column)
		Theme.corner(frame, 8)
		Theme.stroke(frame, Color3.new(0, 0, 0), 1, 0.6)
		local stripe = Theme.new("Frame", { Size = UDim2.new(0, 6, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = Theme.MUTED, BorderSizePixel = 0 }, frame)
		Theme.corner(stripe, 3)
		local name = Theme.text({ Size = UDim2.new(1, -70, 1, -10), Position = UDim2.fromOffset(16, 5), TextXAlignment = Enum.TextXAlignment.Left, MaxSize = 16 }, frame)
		local level = Theme.title({ Size = UDim2.new(0, 50, 1, -12), Position = UDim2.new(1, -56, 0, 6), TextXAlignment = Enum.TextXAlignment.Right, MaxSize = 18 }, frame)
		return { stripe = stripe, name = name, level = level }
	end

	header("SKILLS")
	for i = 1, Config.WEAPON_SLOTS do
		ui.weaponSlots[i] = slot()
	end
	header("PASSIVES")
	for i = 1, Config.PASSIVE_SLOTS do
		ui.passiveSlots[i] = slot()
	end
end

local function fillSlot(slot, info, isWeapon)
	if not info then
		slot.stripe.BackgroundColor3 = Color3.fromRGB(70, 75, 100)
		slot.name.Text = "Empty"
		slot.name.TextColor3 = Theme.MUTED
		slot.level.Text = ""
		return
	end
	slot.stripe.BackgroundColor3 = info.color or Color3.fromRGB(200, 210, 230)
	slot.name.Text = info.name
	slot.name.TextColor3 = Theme.TEXT
	if info.evo then
		slot.level.Text = "EVO"
		slot.level.TextColor3 = Color3.fromRGB(255, 120, 255)
	else
		local max = isWeapon and Config.WEAPON_MAX or Config.PASSIVE_MAX
		slot.level.Text = info.level >= max and "MAX" or "Lv" .. info.level
		slot.level.TextColor3 = info.level >= max and Theme.GOLD or Theme.TEXT
	end
end

-- Level-up cards ----------------------------------------------------------------------

local function buildLevelUp(gui)
	local overlay = Theme.new("Frame", {
		Name = "LevelUp", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, Visible = false, ZIndex = 20,
	}, gui)
	ui.levelOverlay = overlay
	ui.levelTitle = Theme.title({
		Size = UDim2.fromOffset(600, 70), Position = UDim2.new(0.5, -300, 0.5, -250), Text = "LEVEL UP!", ZIndex = 21,
	}, overlay)
	Theme.text({
		Size = UDim2.fromOffset(600, 26), Position = UDim2.new(0.5, -300, 0.5, -180), ZIndex = 21,
		Text = "Choose a power  -  press 1, 2 or 3", TextColor3 = Theme.MUTED, MaxSize = 22,
	}, overlay)

	local width = Config.CHOICES * CARD_W + (Config.CHOICES - 1) * CARD_GAP
	local row = Theme.new("Frame", {
		Size = UDim2.fromOffset(width, CARD_H), Position = UDim2.new(0.5, -width / 2, 0.5, -140),
		BackgroundTransparency = 1, ZIndex = 21,
	}, overlay)
	for i = 1, Config.CHOICES do
		local x = (i - 1) * (CARD_W + CARD_GAP)
		local button = Theme.new("TextButton", {
			Size = UDim2.fromOffset(CARD_W, CARD_H), Position = UDim2.fromOffset(x, 0), Text = "",
			AutoButtonColor = false, BackgroundColor3 = Theme.CARD, ZIndex = 22,
		}, row)
		Theme.corner(button, 16)
		local stroke = Theme.stroke(button, Theme.GOLD, 3)
		Theme.gradient(button, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 155, 185))
		local scale = Theme.new("UIScale", {}, button)

		local header = Theme.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.GOLD, ZIndex = 23 }, button)
		Theme.corner(header, 16)
		Theme.new("Frame", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16), BackgroundColor3 = Theme.GOLD, BorderSizePixel = 0, ZIndex = 23, Name = "Square" }, header)
		local tag = Theme.title({ Size = UDim2.new(1, -50, 1, -12), Position = UDim2.fromOffset(12, 6), TextColor3 = Theme.DARK_TEXT, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24 }, header)
		Theme.title({ Size = UDim2.new(0, 34, 1, -12), Position = UDim2.new(1, -42, 0, 6), Text = "[" .. i .. "]", TextColor3 = Theme.DARK_TEXT, TextStrokeTransparency = 1, ZIndex = 24 }, header)

		local icon = Theme.new("Frame", { Size = UDim2.fromOffset(86, 86), Position = UDim2.new(0.5, -43, 0, 54), BackgroundColor3 = Theme.GOLD, ZIndex = 23 }, button)
		Theme.corner(icon, 43)
		Theme.stroke(icon, Color3.new(1, 1, 1), 3, 0.2)
		Theme.gradient(icon, Color3.fromRGB(255, 255, 255), Color3.fromRGB(110, 110, 130))
		local iconText = Theme.title({ Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), TextColor3 = Color3.new(1, 1, 1), ZIndex = 24 }, icon)

		local title = Theme.title({ Size = UDim2.new(1, -20, 0, 46), Position = UDim2.fromOffset(10, 148), TextWrapped = true, ZIndex = 23, MaxSize = 26 }, button)
		local desc = Theme.text({ Size = UDim2.new(1, -24, 0, 64), Position = UDim2.fromOffset(12, 196), TextWrapped = true, TextColor3 = Theme.TEXT, ZIndex = 23, MaxSize = 18 }, button)
		local pips = Theme.new("Frame", { Size = UDim2.new(1, -40, 0, 14), Position = UDim2.new(0, 20, 1, -30), BackgroundTransparency = 1, ZIndex = 23 }, button)
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }, pips)

		button.MouseEnter:Connect(function()
			Theme.tween(scale, 0.12, { Scale = 1.06 })
			Theme.tween(stroke, 0.12, { Thickness = 5 })
		end)
		button.MouseLeave:Connect(function()
			Theme.tween(scale, 0.12, { Scale = 1 })
			Theme.tween(stroke, 0.12, { Thickness = 3 })
		end)
		button.Activated:Connect(function()
			Hud.choose(i)
		end)
		cards[i] = {
			button = button, stroke = stroke, header = header, tag = tag, icon = icon, iconText = iconText,
			title = title, desc = desc, pips = pips, x = x,
		}
	end

	ui.reroll = Theme.button({
		Size = UDim2.fromOffset(220, 48), Position = UDim2.new(0.5, -110, 0.5, 180), Text = "REROLL (R)",
		BackgroundColor3 = Color3.fromRGB(70, 90, 170), ZIndex = 22,
	}, overlay, function()
		Hud.reroll()
	end)
end

local function setPips(container, level, max, color)
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if not level or not max then
		return
	end
	for i = 1, max do
		local pip = Theme.new("Frame", {
			Size = UDim2.fromOffset(14, 14), ZIndex = 24,
			BackgroundColor3 = i <= level and color or Color3.fromRGB(60, 65, 90),
		}, container)
		Theme.corner(pip, 7)
		Theme.stroke(pip, Color3.new(0, 0, 0), 1, 0.4)
	end
end

-- Announcements and results -------------------------------------------------------------

local function buildBanners(gui)
	ui.announce = Theme.title({
		Size = UDim2.fromOffset(800, 70), Position = UDim2.new(0.5, -400, 0.25, 0), Text = "", Visible = false, ZIndex = 15,
	}, gui)
	ui.announceScale = Theme.new("UIScale", {}, ui.announce)

	local overlay = Theme.new("Frame", {
		Name = "Results", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4, Visible = false, ZIndex = 30,
	}, gui)
	ui.results = overlay
	local card = Theme.panel({ Size = UDim2.fromOffset(460, 380), Position = UDim2.new(0.5, -230, 0.5, -190), ZIndex = 31 }, overlay)
	ui.resultScale = Theme.new("UIScale", {}, card)
	ui.resultTitle = Theme.title({ Size = UDim2.new(1, -40, 0, 70), Position = UDim2.fromOffset(20, 18), ZIndex = 32 }, card)
	ui.resultAdventure = Theme.text({ Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(20, 88), ZIndex = 32, MaxSize = 22 }, card)
	ui.resultRows = {}
	for i, name in { "Time survived", "Level reached", "Enemies defeated" } do
		local y = 128 + (i - 1) * 42
		local row = Theme.new("Frame", { Size = UDim2.new(1, -40, 0, 36), Position = UDim2.fromOffset(20, y), BackgroundColor3 = Theme.CARD, ZIndex = 32 }, card)
		Theme.corner(row, 10)
		Theme.text({ Size = UDim2.new(0.6, -12, 1, -12), Position = UDim2.fromOffset(12, 6), Text = name, TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33 }, row)
		ui.resultRows[i] = Theme.title({ Size = UDim2.new(0.4, -12, 1, -10), Position = UDim2.new(0.6, 0, 0, 5), TextColor3 = Theme.TEXT, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 33 }, row)
	end
	ui.resultGold = Theme.title({ Size = UDim2.new(1, -40, 0, 52), Position = UDim2.fromOffset(20, 262), ZIndex = 32 }, card)
	Theme.text({
		Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 330), ZIndex = 32,
		Text = "Returning to the island...", TextColor3 = Theme.MUTED, MaxSize = 18,
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

-- Public -----------------------------------------------------------------------------------

function Hud.init(gui, cb)
	callbacks = cb
	local root = Theme.new("Frame", { Name = "RunHud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
	ui.root = root
	buildTop(root)
	buildHealth(root)
	buildSlots(root)
	buildLevelUp(gui)
	buildBanners(gui)
	Hud.setStats({ level = 1, xp = 0, need = 1, kills = 0, weapons = {}, passives = {} })
end

function Hud.setVisible(visible)
	ui.root.Visible = visible
	if not visible then
		ui.levelOverlay.Visible = false
	end
end

function Hud.setState(state)
	ui.adventure.Text = (state.adventure or ""):upper()
	ui.adventure.TextColor3 = state.color or Theme.GOLD
	ui.timer.Text = state.text or ""
	ui.timer.TextColor3 = state.text == "FINAL BOSS!" and Theme.BAD or Theme.TEXT
	ui.down.Visible = state.down == true
end

function Hud.setStats(st)
	Theme.tween(ui.xpFill, 0.2, { Size = UDim2.fromScale(math.clamp(st.xp / st.need, 0, 1), 1) })
	ui.xpText.Text = string.format("%d / %d XP", st.xp, st.need)
	ui.level.Text = tostring(st.level)
	ui.kills.Text = "💀 " .. Theme.comma(st.kills)
	for i, slot in ui.weaponSlots do
		fillSlot(slot, st.weapons[i], true)
	end
	for i, slot in ui.passiveSlots do
		fillSlot(slot, st.passives[i], false)
	end
end

function Hud.showLevelUp(list, rerolls)
	if not list then
		ui.levelOverlay.Visible = false
		return
	end
	for i, card in cards do
		local c = list[i]
		card.button.Visible = c ~= nil
		if c then
			local tint = c.tag == "EVOLUTION" and Color3.fromRGB(255, 120, 255) or c.color
			card.tag.Text = c.tag or ""
			card.header.BackgroundColor3 = tint
			card.header.Square.BackgroundColor3 = tint
			card.stroke.Color = tint
			card.icon.BackgroundColor3 = c.color
			card.iconText.Text = initials(c.title)
			card.title.Text = c.title
			card.title.TextColor3 = tint:Lerp(Color3.new(1, 1, 1), 0.35)
			card.desc.Text = c.text
			setPips(card.pips, c.level, c.max, c.color)
			-- slide each card up into place
			card.button.Position = UDim2.fromOffset(card.x, 80)
			Theme.tween(card.button, 0.35 + i * 0.06, { Position = UDim2.fromOffset(card.x, 0) }, Enum.EasingStyle.Back)
		end
	end
	ui.reroll.Text = string.format("REROLL (R)  x%d", rerolls or 0)
	ui.reroll.Visible = (rerolls or 0) > 0
	ui.levelOverlay.Visible = true
end

function Hud.choose(i)
	if ui.levelOverlay.Visible and cards[i] and cards[i].button.Visible then
		ui.levelOverlay.Visible = false -- the server sends the next offer, if any
		callbacks.choose(i)
	end
end

function Hud.reroll()
	if ui.levelOverlay.Visible and ui.reroll.Visible then
		callbacks.reroll()
	end
end

function Hud.announce(text, color)
	ui.announce.Text = text:upper()
	ui.announce.TextColor3 = color or Theme.GOLD
	ui.announce.TextTransparency = 0
	ui.announce.TextStrokeTransparency = 0
	ui.announce.Visible = true
	ui.announceScale.Scale = 0.5
	Theme.tween(ui.announceScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.5, function()
		Theme.tween(ui.announce, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
end

function Hud.showResults(r)
	local victory = r.result == "Victory"
	ui.resultTitle.Text = victory and "VICTORY!" or "DEFEATED"
	ui.resultTitle.TextColor3 = victory and Theme.GOLD or Theme.BAD
	ui.resultAdventure.Text = r.adventure or ""
	ui.resultAdventure.TextColor3 = r.color or Theme.TEXT
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
		return "+" .. Theme.comma(v) .. " GOLD"
	end)
	ui.results.Visible = true
	ui.resultScale.Scale = 0.6
	Theme.tween(ui.resultScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(Config.RESULTS_TIME, function()
		ui.results.Visible = false
	end)
end

return Hud
