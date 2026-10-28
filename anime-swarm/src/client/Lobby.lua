-- Spawn island UI: character select, upgrade shop, the gate's map select, gold counter,
-- hints and the voyage gate boarding banner. Maps are only chosen at a voyage gate.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)

local Lobby = {}
local ui = {}
local callbacks
local classCards = {}
local shopRows = {}
local mapCards = {}
local diffButtons = {}
local panels = {}
local lastPortalMessage = 0
local portal -- latest boarding info from the server while standing on a gate
local pickerOpened = false -- opened the map select once for this boarding
local selectedMap, selectedDifficulty = Config.Maps[1].key, 1
local meta = { gold = 0, levels = {}, costs = {}, progress = {}, class = Config.DEFAULT_CLASS }

local THEME_COLORS = {
	grass = Color3.fromRGB(80, 160, 70), marine = Color3.fromRGB(70, 110, 180), town = Color3.fromRGB(180, 140, 90),
	beach = Color3.fromRGB(220, 190, 120), ship = Color3.fromRGB(140, 95, 55), deepsea = Color3.fromRGB(40, 120, 190),
	snow = Color3.fromRGB(170, 200, 235), desert = Color3.fromRGB(220, 180, 100), jungle = Color3.fromRGB(40, 120, 60),
	sky = Color3.fromRGB(150, 185, 255), spooky = Color3.fromRGB(110, 60, 140), mangrove = Color3.fromRGB(120, 180, 90),
	prison = Color3.fromRGB(90, 85, 100), volcano = Color3.fromRGB(200, 70, 40), wano = Color3.fromRGB(230, 120, 170),
}
local THEME_ICONS = {
	grass = "🌾", marine = "⚓", town = "🏘️", beach = "🏖️", ship = "🚢", deepsea = "🐠", snow = "❄️", desert = "🏜️",
	jungle = "🌴", sky = "☁️", spooky = "👻", mangrove = "🌳", prison = "⛓️", volcano = "🌋", wano = "🌸",
}

local function isCaptain()
	return portal ~= nil and portal.captain and os.clock() - lastPortalMessage < 0.6
end

-- Building blocks -----------------------------------------------------------------------

local function panel(name, width, height, title, subtitle)
	local frame = Theme.panel({
		Name = name, Size = UDim2.fromOffset(width, height), Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2),
		Visible = false, ZIndex = 10,
	}, ui.root)
	panels[name:lower()] = { frame = frame, scale = Theme.new("UIScale", {}, frame), height = height, width = width }
	Theme.title({ Size = UDim2.new(1, -120, 0, 34), Position = UDim2.fromOffset(28, 22), Text = title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 }, frame)
	local sub = Theme.text({ Size = UDim2.new(1, -120, 0, 18), Position = UDim2.fromOffset(28, 58), Text = subtitle or "", TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, MaxSize = 15 }, frame)
	Theme.button({
		Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -60, 0, 20), Text = "X",
		BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 12,
	}, frame, function()
		Lobby.toggle(name:lower(), false)
	end)
	return frame, sub
end

local function scroller(parent, props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = 6
	props.ScrollBarImageColor3 = Theme.MUTED
	props.ScrollingDirection = Enum.ScrollingDirection.Y
	props.CanvasSize = UDim2.new()
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.ZIndex = 11
	local frame = Theme.new("ScrollingFrame", props, parent)
	Theme.padding(frame, 6)
	return frame
end

local function hover(button, scale)
	button.MouseEnter:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1.04 })
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
	end)
end

-- Character select ------------------------------------------------------------------

local function buildCrew()
	local frame = panel("Crew", 860, 640, "CHOOSE YOUR PIRATE", #Config.CLASS_ORDER .. " pirates  -  each with 6 skills and their own gear")
	local grid = scroller(frame, { Size = UDim2.new(1, -40, 0, 452), Position = UDim2.fromOffset(20, 88) })
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(190, 244), CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	local details = Theme.card({ Size = UDim2.new(1, -40, 0, 76), Position = UDim2.new(0, 20, 1, -92), ZIndex = 11 }, frame)
	ui.detailsIcon = select(2, Theme.icon({ Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(12, 12), ZIndex = 12 }, details, "", Theme.ACCENT, 14))
	ui.detailsTile = ui.detailsIcon.Parent
	ui.detailsTitle = Theme.title({ Size = UDim2.new(1, -90, 0, 22), Position = UDim2.fromOffset(78, 12), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, details)
	ui.detailsSkills = Theme.text({
		Size = UDim2.new(1, -90, 0, 30), Position = UDim2.fromOffset(78, 36), TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true, TextColor3 = Theme.MUTED, ZIndex = 12, MaxSize = 14,
	}, details)

	for i, name in Config.CLASS_ORDER do
		local class = Config.Classes[name]
		local card = Theme.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.CARD, LayoutOrder = i, ZIndex = 12 }, grid)
		Theme.corner(card, 16)
		local stroke = Theme.stroke(card, class.color, 1.5, 0.55)
		Theme.gradient(card, Color3.new(1, 1, 1), Color3.fromRGB(165, 170, 200))
		local scale = Theme.new("UIScale", {}, card)
		hover(card, scale)

		Theme.icon({ Size = UDim2.fromOffset(84, 84), Position = UDim2.new(0.5, -42, 0, 16), ZIndex = 13 }, card, class.icon, class.color, 42)
		Theme.title({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 108), Text = name:upper(), ZIndex = 13, MaxSize = 22 }, card)
		Theme.text({ Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 134), Text = class.title, TextColor3 = Theme.MUTED, ZIndex = 13, MaxSize = 14 }, card)
		Theme.chip({ Size = UDim2.new(1, -36, 0, 24), Position = UDim2.fromOffset(18, 158), Text = class.perk, ZIndex = 13, MaxSize = 12 }, card, Theme.GOOD)

		-- the character's 6 skill icons
		local row = Theme.new("Frame", { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 198), BackgroundTransparency = 1, ZIndex = 13 }, card)
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }, row)
		for _, key in class.skills do
			local w = Config.Weapons[key]
			Theme.icon({ Size = UDim2.fromOffset(25, 25), ZIndex = 14 }, row, w.icon, w.color, 7)
		end

		local selected = Theme.chip({ Size = UDim2.fromOffset(92, 22), Position = UDim2.fromOffset(10, 10), Text = "✓ SELECTED", Visible = false, ZIndex = 15, MaxSize = 11 }, card, Theme.GOLD)
		card.MouseEnter:Connect(function()
			Lobby.showSkills(name)
		end)
		card.MouseLeave:Connect(function()
			Lobby.showSkills(meta.class)
		end)
		card.Activated:Connect(function()
			callbacks.selectClass(name)
		end)
		classCards[name] = { stroke = stroke, selected = selected, color = class.color }
	end
end

-- Upgrade shop --------------------------------------------------------------------------

local function buildShop()
	local frame = panel("Shop", 660, 620, "UPGRADES", "Spend gold from adventures. Upgrades last forever.")
	for i, name in Config.META_ORDER do
		local m = Config.Meta[name]
		local row = Theme.card({ Size = UDim2.new(1, -48, 0, 74), Position = UDim2.fromOffset(24, 92 + (i - 1) * 84), ZIndex = 11 }, frame)
		Theme.icon({ Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(12, 12), ZIndex = 12 }, row, m.icon, Theme.ACCENT, 14)
		Theme.title({ Size = UDim2.new(0, 220, 0, 22), Position = UDim2.fromOffset(76, 14), Text = m.name:upper(), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, MaxSize = 20 }, row)
		Theme.text({ Size = UDim2.new(0, 220, 0, 16), Position = UDim2.fromOffset(76, 42), Text = m.desc .. " per level", TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, MaxSize = 14 }, row)
		local pips = Theme.new("Frame", { Size = UDim2.fromOffset(140, 8), Position = UDim2.new(1, -310, 0.5, -4), BackgroundTransparency = 1, ZIndex = 12 }, row)
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), VerticalAlignment = Enum.VerticalAlignment.Center }, pips)
		local pipFrames = {}
		for p = 1, m.max do
			local pip = Theme.new("Frame", { Size = UDim2.fromOffset(math.floor(140 / m.max) - 3, 8), BackgroundColor3 = Theme.LINE, BackgroundTransparency = 0.88, ZIndex = 13 }, pips)
			Theme.corner(pip, 4)
			pipFrames[p] = pip
		end
		local buy = Theme.button({
			Size = UDim2.fromOffset(140, 46), Position = UDim2.new(1, -154, 0.5, -23), Text = "",
			BackgroundColor3 = Theme.GOOD, ZIndex = 12,
		}, row, function()
			callbacks.buy(name)
		end)
		shopRows[name] = { pips = pipFrames, buy = buy }
	end
end

-- Map select (only from a voyage gate) ---------------------------------------------------

local function buildVoyage()
	local frame, sub = panel("Voyage", 900, 640, "CHOOSE AN ADVENTURE")
	ui.voyageHint = sub

	local grid = scroller(frame, { Size = UDim2.fromOffset(580, 520), Position = UDim2.fromOffset(16, 96) })
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(134, 96), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, map in Config.Maps do
		local color = THEME_COLORS[map.theme]
		local card = Theme.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.CARD, LayoutOrder = i, ZIndex = 12 }, grid)
		Theme.corner(card, 12)
		local stroke = Theme.stroke(card, Theme.LINE, 1, 0.88)
		local band = Theme.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = color, ZIndex = 12 }, card)
		Theme.corner(band, 12)
		Theme.gradient(band, Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 140))
		Theme.text({ Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -38, 0, 4), Text = THEME_ICONS[map.theme], ZIndex = 13 }, band)
		Theme.chip({ Size = UDim2.fromOffset(28, 22), Position = UDim2.fromOffset(8, 9), Text = tostring(i), ZIndex = 13, MaxSize = 12, BackgroundTransparency = 0.3 }, band, Theme.BG)
		Theme.title({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 44), Text = map.name, TextWrapped = true, ZIndex = 13, MaxSize = 15 }, card)
		local pips = Theme.new("Frame", { Size = UDim2.new(1, -16, 0, 6), Position = UDim2.new(0, 8, 1, -14), BackgroundTransparency = 1, ZIndex = 13 }, card)
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }, pips)
		local pipFrames = {}
		for d = 1, #Config.Difficulties do
			local pip = Theme.new("Frame", { Size = UDim2.fromOffset(20, 6), ZIndex = 14 }, pips)
			Theme.corner(pip, 3)
			pipFrames[d] = pip
		end
		local lock = Theme.text({ Size = UDim2.fromScale(1, 1), Text = "🔒", BackgroundTransparency = 0.3, BackgroundColor3 = Theme.BG, ZIndex = 16, Visible = false, MaxSize = 28 }, card)
		Theme.corner(lock, 12)
		card.Activated:Connect(function()
			selectedMap = map.key
			Lobby.refreshVoyage()
		end)
		mapCards[map.key] = { stroke = stroke, pips = pipFrames, lock = lock }
	end

	local side = Theme.card({ Size = UDim2.fromOffset(284, 520), Position = UDim2.fromOffset(604, 96), ZIndex = 11 }, frame)
	ui.mapName = Theme.title({ Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 14), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, MaxSize = 22 }, side)
	ui.mapBoss = Theme.chip({ Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 52), ZIndex = 12, MaxSize = 13 }, side, Theme.BAD)
	ui.mapInfo = Theme.text({ Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 86), TextColor3 = Theme.MUTED, ZIndex = 12, MaxSize = 13 }, side)
	for d, diff in Config.Difficulties do
		diffButtons[d] = Theme.button({
			Size = UDim2.new(1, -24, 0, 48), Position = UDim2.fromOffset(12, 112 + (d - 1) * 56), Text = "",
			BackgroundColor3 = diff.color, ZIndex = 12,
		}, side, function()
			selectedDifficulty = d
			Lobby.refreshVoyage()
		end)
	end
	ui.sail = Theme.button({
		Size = UDim2.new(1, -24, 0, 54), Position = UDim2.new(0, 12, 1, -66), Text = "⛵  SET SAIL",
		BackgroundColor3 = Theme.GOOD, ZIndex = 12,
	}, side, function()
		local map = Config.MapByKey[selectedMap]
		if isCaptain() and Config.unlocked(meta.progress, map, selectedDifficulty) then
			callbacks.voyage(selectedMap, selectedDifficulty)
			Lobby.toggle("voyage", false)
		end
	end)
end

-- Gold, side menu, hint and the gate banner ----------------------------------------------

local function navButton(parent, icon, label, color, order, onClick)
	local button = Theme.button({ Size = UDim2.fromOffset(92, 92), Text = "", BackgroundColor3 = color, LayoutOrder = order }, parent, onClick)
	Theme.text({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 4), Text = icon, ZIndex = 3 }, button)
	Theme.title({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -26), Text = label, ZIndex = 3, MaxSize = 15 }, button)
	return button
end

local function buildHud()
	local gold = Theme.panel({ Size = UDim2.fromOffset(200, 50), Position = UDim2.new(1, -216, 0, 14) }, ui.root)
	Theme.icon({ Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(8, 8), ZIndex = 2 }, gold, "💰", Theme.GOLD, 10)
	ui.gold = Theme.title({ Size = UDim2.new(1, -60, 1, -18), Position = UDim2.fromOffset(50, 9), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, gold)

	local nav = Theme.panel({ Size = UDim2.fromOffset(116, 220), Position = UDim2.new(0, 16, 0.5, -130) }, ui.root)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, nav)
	navButton(nav, "👒", "CREW", Color3.fromRGB(220, 70, 90), 1, function()
		Lobby.toggle("crew")
	end)
	navButton(nav, "🛒", "SHOP", Color3.fromRGB(230, 160, 40), 2, function()
		Lobby.toggle("shop")
	end)
	local playing = Theme.panel({ Size = UDim2.fromOffset(200, 44), Position = UDim2.new(0, 16, 0.5, 100) }, ui.root)
	local tile, icon = Theme.icon({ Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(6, 6), ZIndex = 2 }, playing, "", Theme.ACCENT, 16)
	ui.playingTile, ui.playingIcon = tile, icon
	ui.crewName = Theme.text({ Size = UDim2.new(1, -54, 1, -14), Position = UDim2.fromOffset(46, 7), Font = Theme.BOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, MaxSize = 16 }, playing)

	ui.hint = Theme.panel({ Size = UDim2.fromOffset(560, 46), Position = UDim2.new(0.5, -280, 1, -66) }, ui.root)
	Theme.text({ Size = UDim2.new(1, -28, 1, -16), Position = UDim2.fromOffset(14, 8), Text = "⛵  Step onto a voyage gate to choose your adventure", Font = Theme.BOLD, MaxSize = 17 }, ui.hint)

	local banner = Theme.panel({ Size = UDim2.fromOffset(500, 132), Position = UDim2.new(0.5, -250, 0, 20), Visible = false }, ui.root)
	ui.banner = banner
	ui.bannerBar = Theme.new("Frame", { Size = UDim2.new(0, 6, 1, -24), Position = UDim2.fromOffset(12, 12), BorderSizePixel = 0, ZIndex = 2 }, banner)
	Theme.corner(ui.bannerBar, 3)
	ui.bannerScale = Theme.new("UIScale", {}, banner)
	ui.bannerName = Theme.title({ Size = UDim2.new(1, -48, 0, 28), Position = UDim2.fromOffset(30, 12), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, banner)
	ui.bannerCaptain = Theme.chip({ Size = UDim2.fromOffset(220, 24), Position = UDim2.fromOffset(30, 46), ZIndex = 2, MaxSize = 13 }, banner, Theme.GOLD)
	ui.bannerStatus = Theme.text({ Size = UDim2.new(1, -48, 0, 22), Position = UDim2.fromOffset(30, 76), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, MaxSize = 17 }, banner)
	ui.bannerPick = Theme.button({
		Size = UDim2.fromOffset(150, 34), Position = UDim2.new(1, -166, 0, 42), Text = "🗺️ CHOOSE MAP",
		BackgroundColor3 = Theme.ACCENT, Visible = false, ZIndex = 2,
	}, banner, function()
		Lobby.toggle("voyage", true)
	end)
end

-- Public ----------------------------------------------------------------------------------

function Lobby.init(gui, cb)
	callbacks = cb
	ui.root = Theme.new("Frame", { Name = "Lobby", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	buildHud()
	buildCrew()
	buildShop()
	buildVoyage()
	Lobby.setMeta(meta)

	RunService.Heartbeat:Connect(function()
		local boarding = os.clock() - lastPortalMessage < 0.6
		if ui.banner.Visible ~= boarding then
			ui.banner.Visible = boarding
			if boarding then
				ui.bannerScale.Scale = 0.8
				Theme.tween(ui.bannerScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			else
				-- stepped off the gate: the map select is only for gates
				pickerOpened = false
				portal = nil
				Lobby.toggle("voyage", false)
			end
		end
		ui.hint.Visible = not boarding
	end)
end

function Lobby.setVisible(visible)
	ui.root.Visible = visible
	if not visible then
		for name in panels do
			Lobby.toggle(name, false)
		end
	end
end

-- Opens or closes a panel (only one at a time). Big panels shrink to fit small screens.
function Lobby.toggle(name, open)
	local p = panels[name]
	if open == nil then
		open = not p.frame.Visible
	end
	if open and not p.frame.Visible then
		for other, q in panels do
			if other ~= name then
				q.frame.Visible = false
			end
		end
		local viewport = workspace.CurrentCamera.ViewportSize
		local fit = math.min(1, (viewport.Y - 90) / p.height, (viewport.X - 40) / p.width)
		p.scale.Scale = fit * 0.9
		Theme.tween(p.scale, 0.25, { Scale = fit }, Enum.EasingStyle.Back)
		if name == "voyage" then
			Lobby.refreshVoyage()
		end
	end
	p.frame.Visible = open
end

-- Lists a character's 6 skills under the character cards.
function Lobby.showSkills(name)
	local class = Config.Classes[name]
	if not class then
		return
	end
	local names = {}
	for _, key in class.skills do
		local w = Config.Weapons[key]
		table.insert(names, w.icon .. " " .. w.name)
	end
	ui.detailsIcon.Text = class.icon
	ui.detailsTile.BackgroundColor3 = class.color
	ui.detailsTitle.Text = name:upper() .. "  -  " .. class.title:upper()
	ui.detailsSkills.Text = table.concat(names, "    ")
end

-- Redraws the map select: unlocks, cleared difficulties, the selected map and difficulty.
function Lobby.refreshVoyage()
	local progress = meta.progress or {}
	for _, map in Config.Maps do
		local card = mapCards[map.key]
		card.lock.Visible = not Config.unlocked(progress, map, 1)
		for d, pip in card.pips do
			local cleared = (progress[map.key] or 0) >= d
			pip.BackgroundColor3 = cleared and Config.Difficulties[d].color or Theme.LINE
			pip.BackgroundTransparency = cleared and 0 or 0.85
		end
		local chosen = map.key == selectedMap
		card.stroke.Color = chosen and Theme.GOLD or Theme.LINE
		card.stroke.Thickness = chosen and 2.5 or 1
		card.stroke.Transparency = chosen and 0 or 0.88
	end

	local map = Config.MapByKey[selectedMap]
	ui.mapName.Text = map.index .. ".  " .. map.name:upper()
	ui.mapBoss.Text = "☠️  Boss: " .. map.boss
	ui.mapInfo.Text = string.format("Enemy power x%.1f   -   Gold x%.1f", map.hp, map.gold)
	if not Config.unlocked(progress, map, selectedDifficulty) then
		selectedDifficulty = 1
	end
	for d, button in diffButtons do
		local diff = Config.Difficulties[d]
		local open = Config.unlocked(progress, map, d)
		local cleared = (progress[map.key] or 0) >= d
		button.BackgroundColor3 = open and diff.color or Theme.LOCKED
		button.Text = (open and "" or "🔒  ") .. diff.name:upper()
			.. string.format("   +%d%% gold", math.floor((diff.gold - 1) * 100 + 0.5)) .. (cleared and "   ✓" or "")
		local stroke = button:FindFirstChildOfClass("UIStroke")
		stroke.Color = d == selectedDifficulty and Theme.GOLD or Theme.LINE
		stroke.Thickness = d == selectedDifficulty and 2.5 or 1
		stroke.Transparency = d == selectedDifficulty and 0 or 0.82
	end

	if not Config.unlocked(progress, map, selectedDifficulty) then
		ui.sail.Text = map.index > 1 and (progress[Config.Maps[map.index - 1].key] or 0) < 1
			and "🔒  CLEAR " .. Config.Maps[map.index - 1].name:upper() .. " FIRST" or "🔒  LOCKED"
		ui.sail.BackgroundColor3 = Theme.LOCKED
	elseif isCaptain() then
		ui.sail.Text = "⛵  SET SAIL"
		ui.sail.BackgroundColor3 = Theme.GOOD
	else
		ui.sail.Text = "ONLY THE CAPTAIN CHOOSES"
		ui.sail.BackgroundColor3 = Theme.LOCKED
	end
	ui.voyageHint.Text = isCaptain() and "You are the captain! Pick a map and difficulty, then set sail."
		or "Clear a difficulty to unlock the next one. Clear a map on Easy to unlock the next map."
end

function Lobby.setMeta(data)
	meta = data
	meta.progress = meta.progress or {}
	local class = Config.Classes[data.class] or Config.Classes[Config.DEFAULT_CLASS]
	Lobby.showSkills(data.class)
	ui.gold.Text = Theme.comma(data.gold)
	ui.crewName.Text = "Playing as " .. (data.class or "")
	ui.playingIcon.Text = class.icon
	ui.playingTile.BackgroundColor3 = class.color
	for name, card in classCards do
		local chosen = name == data.class
		card.selected.Visible = chosen
		card.stroke.Color = chosen and Theme.GOLD or card.color
		card.stroke.Thickness = chosen and 3 or 1.5
		card.stroke.Transparency = chosen and 0 or 0.55
	end
	for name, row in shopRows do
		local level = data.levels[name] or 0
		for i, pip in row.pips do
			pip.BackgroundColor3 = i <= level and Theme.GOLD or Theme.LINE
			pip.BackgroundTransparency = i <= level and 0 or 0.88
		end
		local cost = data.costs[name]
		if not cost then
			row.buy.Text = "MAXED"
			row.buy.BackgroundColor3 = Theme.LOCKED
		else
			row.buy.Text = "💰 " .. Theme.comma(cost)
			row.buy.BackgroundColor3 = data.gold >= cost and Theme.GOOD or Color3.fromRGB(150, 60, 70)
		end
	end
	Lobby.refreshVoyage()
end

-- Called while standing on a voyage gate.
function Lobby.portal(info)
	local wasCaptain = isCaptain()
	portal = info
	lastPortalMessage = os.clock()
	ui.bannerName.Text = "⛵  VOYAGE GATE " .. info.gate
	ui.bannerBar.BackgroundColor3 = info.color
	ui.banner:FindFirstChildOfClass("UIStroke").Color = info.color
	ui.bannerCaptain.Text = info.captain and "👑 You are the captain" or ("👑 Captain: " .. (info.captainName or "?"))
	ui.bannerStatus.Text = info.text
	ui.bannerPick.Visible = info.captain
	panels.crew.frame.Visible = false
	panels.shop.frame.Visible = false
	-- the captain gets the map select once per boarding
	if info.captain and not info.map and not pickerOpened then
		pickerOpened = true
		Lobby.toggle("voyage", true)
	end
	if wasCaptain ~= isCaptain() then
		Lobby.refreshVoyage()
	end
end

return Lobby
