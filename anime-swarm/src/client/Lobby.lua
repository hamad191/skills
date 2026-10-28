-- Spawn island UI: character select, upgrade shop, adventure map select, gold counter,
-- hints and the voyage gate boarding banner.
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
	snow = Color3.fromRGB(190, 215, 240), desert = Color3.fromRGB(220, 180, 100), jungle = Color3.fromRGB(40, 120, 60),
	sky = Color3.fromRGB(170, 200, 255), spooky = Color3.fromRGB(110, 60, 140), mangrove = Color3.fromRGB(120, 180, 90),
	prison = Color3.fromRGB(90, 85, 100), volcano = Color3.fromRGB(200, 70, 40), wano = Color3.fromRGB(230, 120, 170),
}
local LOCKED = Color3.fromRGB(55, 58, 75)

local function closeButton(panel, name)
	Theme.button({
		Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -52, 0, 12), Text = "X",
		BackgroundColor3 = Theme.BAD, ZIndex = panel.ZIndex + 2,
	}, panel, function()
		Lobby.toggle(name, false)
	end)
end

local function panel(name, width, height, title)
	local frame = Theme.panel({
		Name = name, Size = UDim2.fromOffset(width, height), Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2),
		Visible = false, ZIndex = 10,
	}, ui.root)
	panels[name:lower()] = { frame = frame, scale = Theme.new("UIScale", {}, frame), height = height, width = width }
	Theme.title({ Size = UDim2.new(1, -120, 0, 50), Position = UDim2.fromOffset(24, 14), Text = title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 }, frame)
	closeButton(frame, name:lower())
	return frame
end

local function scroller(parent, props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = 8
	props.ScrollingDirection = Enum.ScrollingDirection.Y
	props.CanvasSize = UDim2.new()
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.ZIndex = 11
	return Theme.new("ScrollingFrame", props, parent)
end

local function isCaptain()
	return portal ~= nil and portal.captain and os.clock() - lastPortalMessage < 0.6
end

-- Character select ------------------------------------------------------------------

local function buildCrew()
	local frame = panel("Crew", 740, 600, "CHOOSE YOUR PIRATE")
	local grid = scroller(frame, { Size = UDim2.new(1, -40, 0, 430), Position = UDim2.fromOffset(20, 76) })
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(160, 196), CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	Theme.new("UIPadding", { PaddingTop = UDim.new(0, 10) }, grid)
	local details = Theme.new("Frame", { Size = UDim2.new(1, -40, 0, 74), Position = UDim2.new(0, 20, 1, -88), BackgroundColor3 = Theme.CARD, ZIndex = 11 }, frame)
	Theme.corner(details, 12)
	ui.detailsTitle = Theme.title({ Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, details)
	ui.detailsSkills = Theme.text({
		Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 32), TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true, TextColor3 = Theme.TEXT, ZIndex = 12, MaxSize = 16,
	}, details)

	for i, name in Config.CLASS_ORDER do
		local class = Config.Classes[name]
		local skill = Config.Weapons[class.weapon]
		local card = Theme.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.CARD, LayoutOrder = i, ZIndex = 12 }, grid)
		Theme.corner(card, 14)
		local stroke = Theme.stroke(card, class.color, 2, 0.4)
		Theme.gradient(card, Color3.new(1, 1, 1), Color3.fromRGB(150, 155, 185))
		local scale = Theme.new("UIScale", {}, card)

		local portrait = Theme.new("Frame", { Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, -40, 0, 10), BackgroundColor3 = class.color, ZIndex = 13 }, card)
		Theme.corner(portrait, 40)
		Theme.stroke(portrait, Color3.new(1, 1, 1), 3, 0.1)
		Theme.gradient(portrait, Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 120))
		Theme.title({ Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), Text = name:sub(1, 1), TextColor3 = Color3.new(1, 1, 1), ZIndex = 14 }, portrait)

		Theme.title({ Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 96), Text = name:upper(), TextColor3 = Theme.TEXT, ZIndex = 13 }, card)
		Theme.text({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 122), Text = class.title, TextColor3 = Theme.MUTED, ZIndex = 13, MaxSize = 15 }, card)
		Theme.text({ Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 142), Text = skill.icon .. " " .. skill.name, TextColor3 = skill.color:Lerp(Color3.new(1, 1, 1), 0.3), ZIndex = 13, MaxSize = 16 }, card)
		Theme.text({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 166), Text = class.perk, TextColor3 = Theme.GOOD, ZIndex = 13, MaxSize = 14 }, card)
		local selected = Theme.title({
			Size = UDim2.fromOffset(110, 22), Position = UDim2.new(0.5, -55, 0, 2), Text = "SELECTED",
			BackgroundTransparency = 0, BackgroundColor3 = Theme.GOLD, TextColor3 = Theme.DARK_TEXT,
			TextStrokeTransparency = 1, Visible = false, ZIndex = 15,
		}, card)
		Theme.corner(selected, 8)

		card.MouseEnter:Connect(function()
			Theme.tween(scale, 0.12, { Scale = 1.05 })
			Lobby.showSkills(name)
		end)
		card.MouseLeave:Connect(function()
			Theme.tween(scale, 0.12, { Scale = 1 })
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
	local frame = panel("Shop", 600, 560, "PERMANENT UPGRADES")
	Theme.text({ Size = UDim2.new(1, -48, 0, 20), Position = UDim2.fromOffset(24, 62), Text = "Spend gold from adventures. Upgrades last forever.", TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, MaxSize = 17 }, frame)

	for i, name in Config.META_ORDER do
		local m = Config.Meta[name]
		local row = Theme.new("Frame", {
			Size = UDim2.new(1, -40, 0, 68), Position = UDim2.fromOffset(20, 92 + (i - 1) * 76),
			BackgroundColor3 = Theme.CARD, ZIndex = 11,
		}, frame)
		Theme.corner(row, 12)
		Theme.stroke(row, Color3.new(0, 0, 0), 1, 0.6)
		Theme.title({ Size = UDim2.new(0, 240, 0, 26), Position = UDim2.fromOffset(14, 8), Text = m.name:upper(), TextColor3 = Theme.TEXT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, row)
		Theme.text({ Size = UDim2.new(0, 240, 0, 18), Position = UDim2.fromOffset(14, 36), Text = m.desc .. " per level", TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, MaxSize = 16 }, row)
		local pips = Theme.new("Frame", { Size = UDim2.fromOffset(150, 12), Position = UDim2.new(1, -330, 0.5, -6), BackgroundTransparency = 1, ZIndex = 12 }, row)
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), VerticalAlignment = Enum.VerticalAlignment.Center }, pips)
		local pipFrames = {}
		for p = 1, m.max do
			local pip = Theme.new("Frame", { Size = UDim2.fromOffset(math.floor(150 / m.max) - 3, 12), BackgroundColor3 = Color3.fromRGB(60, 65, 95), ZIndex = 13 }, pips)
			Theme.corner(pip, 4)
			pipFrames[p] = pip
		end
		local buy = Theme.button({
			Size = UDim2.fromOffset(150, 46), Position = UDim2.new(1, -164, 0.5, -23), Text = "",
			BackgroundColor3 = Color3.fromRGB(60, 170, 90), ZIndex = 12,
		}, row, function()
			callbacks.buy(name)
		end)
		shopRows[name] = { pips = pipFrames, buy = buy }
	end
end

-- Adventure map select -------------------------------------------------------------------

local function buildVoyage()
	local frame = panel("Voyage", 880, 600, "CHOOSE AN ADVENTURE")
	ui.voyageHint = Theme.text({ Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(24, 62), TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, MaxSize = 17 }, frame)

	local grid = scroller(frame, { Size = UDim2.fromOffset(560, 490), Position = UDim2.fromOffset(16, 92) })
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(128, 88), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	Theme.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }, grid)
	for i, map in Config.Maps do
		local card = Theme.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = THEME_COLORS[map.theme], LayoutOrder = i, ZIndex = 12 }, grid)
		Theme.corner(card, 10)
		local stroke = Theme.stroke(card, Color3.new(0, 0, 0), 2, 0.5)
		Theme.gradient(card, Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 130))
		Theme.title({ Size = UDim2.fromOffset(28, 20), Position = UDim2.fromOffset(6, 4), Text = tostring(i), TextColor3 = Theme.GOLD, ZIndex = 13, TextXAlignment = Enum.TextXAlignment.Left }, card)
		Theme.title({ Size = UDim2.new(1, -12, 0, 40), Position = UDim2.fromOffset(6, 22), Text = map.name:upper(), TextWrapped = true, TextColor3 = Theme.TEXT, ZIndex = 13, MaxSize = 18 }, card)
		local pips = Theme.new("Frame", { Size = UDim2.new(1, -12, 0, 12), Position = UDim2.new(0, 6, 1, -18), BackgroundTransparency = 1, ZIndex = 13 }, card)
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }, pips)
		local pipFrames = {}
		for d = 1, #Config.Difficulties do
			local pip = Theme.new("Frame", { Size = UDim2.fromOffset(18, 10), BackgroundColor3 = Color3.fromRGB(40, 40, 55), ZIndex = 14 }, pips)
			Theme.corner(pip, 4)
			pipFrames[d] = pip
		end
		local lock = Theme.text({ Size = UDim2.fromScale(1, 1), Text = "🔒", BackgroundTransparency = 0.35, BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 16, Visible = false, MaxSize = 32 }, card)
		Theme.corner(lock, 10)
		card.Activated:Connect(function()
			selectedMap = map.key
			Lobby.refreshVoyage()
		end)
		mapCards[map.key] = { card = card, stroke = stroke, pips = pipFrames, lock = lock }
	end

	local side = Theme.new("Frame", { Size = UDim2.fromOffset(276, 490), Position = UDim2.fromOffset(588, 92), BackgroundColor3 = Theme.CARD, ZIndex = 11 }, frame)
	Theme.corner(side, 12)
	ui.mapName = Theme.title({ Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 10), TextWrapped = true, ZIndex = 12 }, side)
	ui.mapBoss = Theme.text({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 48), TextColor3 = Theme.BAD, ZIndex = 12, MaxSize = 16 }, side)
	ui.mapInfo = Theme.text({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 70), TextColor3 = Theme.MUTED, ZIndex = 12, MaxSize = 15 }, side)
	for d, diff in Config.Difficulties do
		diffButtons[d] = Theme.button({
			Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 98 + (d - 1) * 56), Text = "",
			BackgroundColor3 = diff.color, ZIndex = 12,
		}, side, function()
			selectedDifficulty = d
			Lobby.refreshVoyage()
		end)
	end
	ui.sail = Theme.button({
		Size = UDim2.new(1, -20, 0, 56), Position = UDim2.new(0, 10, 1, -66), Text = "SET SAIL!",
		BackgroundColor3 = Color3.fromRGB(60, 170, 90), ZIndex = 12,
	}, side, function()
		local map = Config.MapByKey[selectedMap]
		if isCaptain() and Config.unlocked(meta.progress, map, selectedDifficulty) then
			callbacks.voyage(selectedMap, selectedDifficulty)
			Lobby.toggle("voyage", false)
		end
	end)
end

-- Portal banner, hint, gold and menu buttons ---------------------------------------------

local function buildHud()
	local gold = Theme.panel({ Size = UDim2.fromOffset(190, 48), Position = UDim2.new(1, -206, 0, 14) }, ui.root)
	ui.gold = Theme.title({ Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6), Text = "💰 0" }, gold)

	local menu = Theme.new("Frame", { Size = UDim2.fromOffset(170, 260), Position = UDim2.new(0, 16, 0.5, -130), BackgroundTransparency = 1 }, ui.root)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, menu)
	Theme.button({ Size = UDim2.fromOffset(170, 60), Text = "👒 CREW", BackgroundColor3 = Color3.fromRGB(200, 60, 60), LayoutOrder = 1 }, menu, function()
		Lobby.toggle("crew")
	end)
	ui.crewName = Theme.text({ Size = UDim2.new(1, 0, 0, 20), Text = "", TextColor3 = Theme.MUTED, MaxSize = 16, LayoutOrder = 2 }, menu)
	Theme.button({ Size = UDim2.fromOffset(170, 60), Text = "🗺️ MAPS", BackgroundColor3 = Color3.fromRGB(60, 120, 210), LayoutOrder = 3 }, menu, function()
		Lobby.toggle("voyage")
	end)
	Theme.button({ Size = UDim2.fromOffset(170, 60), Text = "💰 SHOP", BackgroundColor3 = Color3.fromRGB(220, 160, 30), LayoutOrder = 4 }, menu, function()
		Lobby.toggle("shop")
	end)

	ui.hint = Theme.panel({ Size = UDim2.fromOffset(600, 50), Position = UDim2.new(0.5, -300, 1, -74) }, ui.root)
	Theme.text({ Size = UDim2.new(1, -24, 1, -14), Position = UDim2.fromOffset(12, 7), Text = "Pick a pirate in CREW, then step onto a voyage gate to choose an adventure!", MaxSize = 19 }, ui.hint)

	local banner = Theme.panel({ Size = UDim2.fromOffset(480, 130), Position = UDim2.new(0.5, -240, 0, 20), Visible = false }, ui.root)
	ui.banner = banner
	ui.bannerStroke = banner:FindFirstChildOfClass("UIStroke")
	ui.bannerScale = Theme.new("UIScale", {}, banner)
	ui.bannerName = Theme.title({ Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 8), Text = "" }, banner)
	ui.bannerCaptain = Theme.text({ Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 44), Text = "", TextColor3 = Theme.GOLD, MaxSize = 17 }, banner)
	ui.bannerStatus = Theme.text({ Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 66), Text = "", MaxSize = 20 }, banner)
	ui.bannerPick = Theme.button({
		Size = UDim2.fromOffset(180, 30), Position = UDim2.new(0.5, -90, 1, -36), Text = "CHOOSE MAP",
		BackgroundColor3 = Color3.fromRGB(60, 120, 210), Visible = false,
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
				ui.bannerScale.Scale = 0.7
				Theme.tween(ui.bannerScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			else
				pickerOpened = false
				portal = nil
				Lobby.refreshVoyage()
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
		p.scale.Scale = fit * 0.85
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
	ui.detailsTitle.Text = name:upper() .. "'S 6 SKILLS"
	ui.detailsTitle.TextColor3 = class.color:Lerp(Color3.new(1, 1, 1), 0.3)
	ui.detailsSkills.Text = table.concat(names, "   ")
end

-- Redraws the map select: unlocks, cleared difficulties, the selected map and difficulty.
function Lobby.refreshVoyage()
	local progress = meta.progress or {}
	for _, map in Config.Maps do
		local card = mapCards[map.key]
		local open = Config.unlocked(progress, map, 1)
		card.lock.Visible = not open
		for d, pip in card.pips do
			pip.BackgroundColor3 = (progress[map.key] or 0) >= d and Config.Difficulties[d].color or Color3.fromRGB(40, 40, 55)
		end
		local chosen = map.key == selectedMap
		card.stroke.Color = chosen and Theme.GOLD or Color3.new(0, 0, 0)
		card.stroke.Thickness = chosen and 4 or 2
		card.stroke.Transparency = chosen and 0 or 0.5
	end

	local map = Config.MapByKey[selectedMap]
	ui.mapName.Text = map.index .. ". " .. map.name:upper()
	ui.mapBoss.Text = "Boss: " .. map.boss
	ui.mapInfo.Text = string.format("Enemy power x%.1f   |   Gold x%.1f", map.hp, map.gold)
	if not Config.unlocked(progress, map, selectedDifficulty) then
		selectedDifficulty = 1
	end
	for d, button in diffButtons do
		local diff = Config.Difficulties[d]
		local open = Config.unlocked(progress, map, d)
		local cleared = (progress[map.key] or 0) >= d
		button.BackgroundColor3 = open and diff.color or LOCKED
		button.Text = (open and "" or "🔒 ") .. diff.name:upper()
			.. string.format("  (+%d%% gold)", math.floor((diff.gold - 1) * 100 + 0.5)) .. (cleared and "  ✓" or "")
		button:FindFirstChildOfClass("UIStroke").Color = d == selectedDifficulty and Theme.GOLD or Color3.new(1, 1, 1)
		button:FindFirstChildOfClass("UIStroke").Transparency = d == selectedDifficulty and 0 or 0.75
	end

	local open = Config.unlocked(progress, map, selectedDifficulty)
	if not open then
		ui.sail.Text = map.index > 1 and (progress[Config.Maps[map.index - 1].key] or 0) < 1
			and "CLEAR " .. Config.Maps[map.index - 1].name:upper() .. " FIRST" or "LOCKED"
		ui.sail.BackgroundColor3 = LOCKED
	elseif isCaptain() then
		ui.sail.Text = "SET SAIL!"
		ui.sail.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
	else
		ui.sail.Text = portal and "ONLY THE CAPTAIN CHOOSES" or "STAND ON A GATE TO SAIL"
		ui.sail.BackgroundColor3 = LOCKED
	end
	ui.voyageHint.Text = isCaptain() and "You are the captain! Pick a map and difficulty, then set sail."
		or "Clear a difficulty to unlock the next one. Clear a map on Easy to unlock the next map."
end

function Lobby.setMeta(data)
	meta = data
	meta.progress = meta.progress or {}
	Lobby.showSkills(data.class)
	ui.gold.Text = "💰 " .. Theme.comma(data.gold)
	ui.crewName.Text = data.class and "Playing as " .. data.class or ""
	for name, card in classCards do
		local chosen = name == data.class
		card.selected.Visible = chosen
		card.stroke.Color = chosen and Theme.GOLD or card.color
		card.stroke.Thickness = chosen and 4 or 2
		card.stroke.Transparency = chosen and 0 or 0.4
	end
	for name, row in shopRows do
		local level = data.levels[name] or 0
		for i, pip in row.pips do
			pip.BackgroundColor3 = i <= level and Theme.GOLD or Color3.fromRGB(60, 65, 95)
		end
		local cost = data.costs[name]
		if not cost then
			row.buy.Text = "MAXED"
			row.buy.BackgroundColor3 = Color3.fromRGB(90, 95, 120)
		else
			row.buy.Text = "💰 " .. Theme.comma(cost)
			row.buy.BackgroundColor3 = data.gold >= cost and Color3.fromRGB(60, 170, 90) or Color3.fromRGB(150, 60, 60)
		end
	end
	Lobby.refreshVoyage()
end

-- Called while standing on a voyage gate.
function Lobby.portal(info)
	local wasCaptain = isCaptain()
	portal = info
	lastPortalMessage = os.clock()
	ui.bannerName.Text = "⛵ VOYAGE GATE " .. info.gate
	ui.bannerName.TextColor3 = info.color
	ui.bannerStroke.Color = info.color
	ui.bannerStroke.Transparency = 0
	ui.bannerCaptain.Text = info.captain and "You are the captain!" or ("Captain: " .. (info.captainName or "?"))
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
