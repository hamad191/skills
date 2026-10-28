-- Spawn island UI: character select, training, gear, upgrades shop, Robux store, the gate's
-- map select, gold counter, hints and the voyage gate boarding banner. NPC prompts open these
-- menus too (see SwarmClient). Maps are only chosen at a voyage gate.
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
	Theme.divider({ Size = UDim2.new(1, -40, 0, 2), Position = UDim2.fromOffset(20, 82), ZIndex = 11 }, frame)
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
		CellSize = UDim2.fromOffset(190, 254), CellPadding = UDim2.fromOffset(14, 14),
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
		-- a WANTED poster for every pirate (the Marine gets a recruitment poster)
		local card = Theme.parchment({ Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 12 }, grid, "TextButton")
		local stroke = card:FindFirstChildOfClass("UIStroke")
		local scale = Theme.new("UIScale", {}, card)
		hover(card, scale)
		local marine = name == Config.DEFAULT_CLASS
		Theme.title({
			Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 6), Text = marine and "RECRUIT" or "WANTED",
			TextColor3 = Theme.INK, TextStrokeTransparency = 1, ZIndex = 13,
		}, card)
		local portrait = Theme.new("Frame", { Size = UDim2.fromOffset(112, 86), Position = UDim2.new(0.5, -56, 0, 36), BackgroundColor3 = class.color, ZIndex = 13 }, card)
		Theme.stroke(portrait, Theme.INK, 3, 0)
		Theme.gradient(portrait, Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140), 135)
		Theme.text({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Text = class.icon, ZIndex = 14 }, portrait)
		Theme.title({
			Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 126), Text = name:upper(),
			TextColor3 = Theme.INK, TextStrokeTransparency = 1, ZIndex = 13, MaxSize = 22,
		}, card)
		Theme.text({ Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 150), Text = class.title, TextColor3 = Color3.fromRGB(120, 85, 50), Font = Theme.BOLD, ZIndex = 13, MaxSize = 13 }, card)
		local perk = Theme.text({
			Size = UDim2.new(1, -30, 0, 20), Position = UDim2.fromOffset(15, 168), Text = class.perk, TextColor3 = Color3.fromRGB(40, 110, 60),
			Font = Theme.BOLD, BackgroundTransparency = 0.75, BackgroundColor3 = Color3.fromRGB(80, 170, 100), ZIndex = 13, MaxSize = 12,
		}, card)
		Theme.corner(perk, 6)

		-- the character's 6 skill icons
		local row = Theme.new("Frame", { Size = UDim2.new(1, -20, 0, 25), Position = UDim2.fromOffset(10, 194), BackgroundTransparency = 1, ZIndex = 13 }, card)
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }, row)
		for _, key in class.skills do
			local w = Config.Weapons[key]
			Theme.icon({ Size = UDim2.fromOffset(24, 24), ZIndex = 14 }, row, w.icon, w.color, 7)
		end
		-- bounty line: the unlock price, or that they're in your crew
		local bounty = Theme.title({
			Size = UDim2.new(1, -16, 0, 22), Position = UDim2.new(0, 8, 1, -28), Text = "", TextColor3 = Theme.INK,
			TextStrokeTransparency = 1, ZIndex = 13, MaxSize = 17,
		}, card)

		local selected = Theme.chip({ Size = UDim2.fromOffset(96, 22), Position = UDim2.new(1, -104, 0, 40), Text = "✓ SAILING", Visible = false, ZIndex = 15, MaxSize = 11, BackgroundTransparency = 0.05, TextColor3 = Theme.DARK_TEXT }, card, Theme.GOLD)
		local lock = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 25, 10), BackgroundTransparency = 0.45, ZIndex = 16, Visible = false }, card)
		Theme.corner(lock, 6)
		Theme.text({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 56), Text = "🔒", ZIndex = 17 }, lock)
		local price = Theme.chip({ Size = UDim2.new(1, -30, 0, 30), Position = UDim2.new(0, 15, 0, 112), Text = "", ZIndex = 17, MaxSize = 14, BackgroundTransparency = 0.1 }, lock, Theme.PANEL)
		card.MouseEnter:Connect(function()
			Lobby.showSkills(name)
		end)
		card.MouseLeave:Connect(function()
			Lobby.showSkills(meta.class)
		end)
		card.Activated:Connect(function()
			if (meta.classes or {})[name] then
				callbacks.selectClass(name)
			elseif meta.gold >= class.cost then
				callbacks.unlockClass(name)
			end
		end)
		classCards[name] = { stroke = stroke, selected = selected, color = class.color, lock = lock, price = price, cost = class.cost, bounty = bounty }
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
		local busy = Theme.chip({ Size = UDim2.fromOffset(70, 20), Position = UDim2.new(1, -78, 0, 46), Text = "IN USE", Visible = false, ZIndex = 15, MaxSize = 11 }, card, Theme.BAD)
		card.Activated:Connect(function()
			selectedMap = map.key
			Lobby.refreshVoyage()
		end)
		mapCards[map.key] = { stroke = stroke, pips = pipFrames, lock = lock, busy = busy }
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
		local busy = portal and portal.busy and portal.busy[selectedMap]
		if isCaptain() and not busy and Config.unlocked(meta.progress, map, selectedDifficulty) then
			callbacks.voyage(selectedMap, selectedDifficulty)
			Lobby.toggle("voyage", false)
		end
	end)
end

-- Training (Rayleigh: skills, Dr. Kureha: passives) ------------------------------------------

local trainTab = "skills"

local function buildTrain()
	local frame, sub = panel("Train", 780, 640, "TRAINING")
	ui.trainHint = sub
	ui.trainTabs = {}
	for i, tab in { { "skills", "⚔️  SKILLS  -  Rayleigh" }, { "passives", "💊  PASSIVES  -  Dr. Kureha" } } do
		ui.trainTabs[tab[1]] = Theme.button({
			Size = UDim2.fromOffset(250, 38), Position = UDim2.fromOffset(28 + (i - 1) * 262, 88), Text = tab[2],
			BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 12,
		}, frame, function()
			trainTab = tab[1]
			Lobby.refreshTrain()
		end)
	end
	ui.trainList = scroller(frame, { Size = UDim2.new(1, -40, 1, -156), Position = UDim2.fromOffset(20, 138) })
	Theme.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, ui.trainList)
end

local function trainRow(order, icon, color, name, effect, level, max, cost, onTrain)
	local row = Theme.card({ Size = UDim2.new(1, -12, 0, 72), LayoutOrder = order, ZIndex = 12 }, ui.trainList)
	Theme.icon({ Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(11, 11), ZIndex = 13 }, row, icon, color, 14)
	Theme.title({ Size = UDim2.new(0, 300, 0, 22), Position = UDim2.fromOffset(74, 12), Text = name, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, MaxSize = 18 }, row)
	Theme.text({ Size = UDim2.new(0, 330, 0, 16), Position = UDim2.fromOffset(74, 40), Text = effect, TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, MaxSize = 13 }, row)
	local pips = Theme.new("Frame", { Size = UDim2.fromOffset(130, 8), Position = UDim2.new(1, -300, 0.5, -4), BackgroundTransparency = 1, ZIndex = 13 }, row)
	Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3) }, pips)
	for i = 1, max do
		local pip = Theme.new("Frame", {
			Size = UDim2.fromOffset(math.floor(130 / max) - 3, 8), BackgroundColor3 = i <= level and Theme.GOLD or Theme.LINE,
			BackgroundTransparency = i <= level and 0 or 0.88, ZIndex = 14,
		}, pips)
		Theme.corner(pip, 4)
	end
	local maxed = level >= max
	Theme.button({
		Size = UDim2.fromOffset(140, 44), Position = UDim2.new(1, -152, 0.5, -22),
		Text = maxed and "MAXED" or "💰 " .. Theme.comma(cost),
		BackgroundColor3 = maxed and Theme.LOCKED or meta.gold >= cost and Theme.GOOD or Color3.fromRGB(150, 60, 70), ZIndex = 13,
	}, row, not maxed and onTrain or nil)
end

function Lobby.refreshTrain()
	for _, child in ui.trainList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for tab, button in ui.trainTabs do
		button.BackgroundColor3 = tab == trainTab and Theme.ACCENT or Theme.CARD_LIGHT
	end
	local mastery, training = meta.mastery or {}, meta.training or {}
	if trainTab == "skills" then
		local class = Config.Classes[meta.class] or Config.Classes[Config.DEFAULT_CLASS]
		ui.trainHint.Text = "Permanently power up " .. (meta.class or "your pirate") .. "'s skills. Switch pirates in CREW to train others."
		for i, key in class.skills do
			local w = Config.Weapons[key]
			local level = mastery[key] or 0
			local effect = string.format("+%d%% damage, -%d%% cooldown per level  (now +%d%% / -%d%%)",
				Config.MASTERY.damage * 100, Config.MASTERY.cooldown * 100, Config.MASTERY.damage * 100 * level, Config.MASTERY.cooldown * 100 * level)
			trainRow(i, w.icon, w.color, w.name, effect, level, Config.MASTERY.max, Config.trainCost("skill", level), function()
				callbacks.train("skill", key)
			end)
		end
	else
		ui.trainHint.Text = "Make every passive stronger, forever. Each level adds 15% to that passive's effect."
		local order = 0
		for key, p in Config.Passives do
			order += 1
			local level = training[key] or 0
			local effect = string.format("%s per level  -  boosted +%d%%", p.desc, Config.TRAINING.boost * 100 * level)
			trainRow(order, p.icon, Theme.ACCENT, p.name, effect, level, Config.TRAINING.max, Config.trainCost("passive", level), function()
				callbacks.train("passive", key)
			end)
		end
	end
end

-- Gear (Tom the Shipwright) ----------------------------------------------------------------

local gearTab = "weapon"

local function buildGear()
	local frame = panel("Gear", 840, 640, "GEAR", "One weapon, outfit and charm. Drops give spare copies: upgrade with a copy + gold.")
	ui.equippedCards = {}
	for i, slot in Config.GEAR_SLOTS do
		local card = Theme.card({ Size = UDim2.fromOffset(256, 80), Position = UDim2.fromOffset(28 + (i - 1) * 268, 88), ZIndex = 11 }, frame)
		local tile, icon = Theme.icon({ Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(12, 12), ZIndex = 12 }, card, "", Theme.CARD_LIGHT, 14)
		local name = Theme.title({ Size = UDim2.new(1, -86, 0, 20), Position = UDim2.fromOffset(78, 14), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, MaxSize = 17 }, card)
		local stats = Theme.text({ Size = UDim2.new(1, -86, 0, 30), Position = UDim2.fromOffset(78, 38), TextWrapped = true, TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, MaxSize = 12 }, card)
		ui.equippedCards[slot] = { tile = tile, icon = icon, name = name, stats = stats }
	end
	ui.gearTabs = {}
	for i, slot in Config.GEAR_SLOTS do
		ui.gearTabs[slot] = Theme.button({
			Size = UDim2.fromOffset(180, 36), Position = UDim2.fromOffset(28 + (i - 1) * 192, 182),
			Text = Config.GEAR_SLOT_ICONS[slot] .. "  " .. Config.GEAR_SLOT_NAMES[slot]:upper(), BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 12,
		}, frame, function()
			gearTab = slot
			Lobby.refreshGear()
		end)
	end
	ui.gearList = scroller(frame, { Size = UDim2.new(1, -40, 1, -250), Position = UDim2.fromOffset(20, 230) })
	Theme.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, ui.gearList)
end

function Lobby.refreshGear()
	local items, equipped = meta.items or {}, meta.equipped or {}
	for slot, card in ui.equippedCards do
		local item = equipped[slot] and Config.GearById[equipped[slot]]
		card.icon.Text = item and item.icon or Config.GEAR_SLOT_ICONS[slot]
		card.tile.BackgroundColor3 = item and Config.RARITIES[item.rarity] or Theme.CARD_LIGHT
		card.name.Text = item and item.name or "No " .. Config.GEAR_SLOT_NAMES[slot]:lower()
		local level = item and (meta.gearLevels or {})[item.id] or 0
		card.name.Text = item and item.name .. (level > 0 and "  +" .. level or "") or card.name.Text
		card.stats.Text = item and Config.describeBonus(Config.gearStats(item, level)) or "Pick one below"
	end
	for slot, button in ui.gearTabs do
		button.BackgroundColor3 = slot == gearTab and Theme.ACCENT or Theme.CARD_LIGHT
	end
	for _, child in ui.gearList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	for _, item in Config.GEAR_ITEMS do
		if item.slot == gearTab then
			order += 1
			local color = Config.RARITIES[item.rarity]
			local row = Theme.card({ Size = UDim2.new(1, -12, 0, 72), LayoutOrder = order, ZIndex = 12 }, ui.gearList)
			Theme.icon({ Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(11, 11), ZIndex = 13 }, row, item.icon, color, 14)
			local owned = items[item.id] == true
			local level = (meta.gearLevels or {})[item.id] or 0
			local copies = (meta.gearCopies or {})[item.id] or 0
			Theme.title({ Size = UDim2.new(0, 260, 0, 22), Position = UDim2.fromOffset(74, 12), Text = item.name .. (level > 0 and "  +" .. level or ""), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, MaxSize = 18 }, row)
			Theme.chip({ Size = UDim2.fromOffset(96, 20), Position = UDim2.fromOffset(74, 40), Text = item.rarity:upper(), ZIndex = 13, MaxSize = 11 }, row, color)
			Theme.text({
				Size = UDim2.new(0, 230, 0, 34), Position = UDim2.fromOffset(178, 34), TextWrapped = true, TextColor3 = Theme.MUTED,
				Text = Config.describeBonus(Config.gearStats(item, level)) .. (owned and string.format("\nSpare copies: %d", copies) or ""),
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, MaxSize = 12,
			}, row)
			local text, color2, action
			if equipped[item.slot] == item.id then
				text, color2, action = "✓ EQUIPPED", Theme.ACCENT, "equip"
			elseif owned then
				text, color2, action = "EQUIP", Theme.GOOD, "equip"
			elseif item.cost > 0 then
				text, color2, action = "💰 " .. Theme.comma(item.cost), meta.gold >= item.cost and Theme.GOOD or Color3.fromRGB(150, 60, 70), "buy"
			else
				text, color2 = "☠️ BOSS DROP", Theme.LOCKED
			end
			Theme.button({ Size = UDim2.fromOffset(118, 44), Position = UDim2.new(1, -130, 0.5, -22), Text = text, BackgroundColor3 = color2, ZIndex = 13 }, row,
				action and function()
					callbacks.gear(action, item.id)
				end or nil)
			if owned then
				-- upgrading costs one spare copy (from drops) plus gold
				local cost = Config.gearUpgradeCost(item, level)
				local maxed = level >= Config.GEAR_UPGRADE.max
				local ready = not maxed and copies >= 1 and meta.gold >= cost
				Theme.button({
					Size = UDim2.fromOffset(136, 44), Position = UDim2.new(1, -274, 0.5, -22),
					Text = maxed and "MAX +10" or copies < 1 and "⬆ NEED A COPY" or "⬆ 💰 " .. Theme.comma(cost),
					BackgroundColor3 = ready and Color3.fromRGB(230, 150, 40) or Theme.LOCKED, ZIndex = 13,
				}, row, ready and function()
					callbacks.gear("upgrade", item.id)
				end or nil)
			end
		end
	end
end

-- Robux store (Buggy) --------------------------------------------------------------------

local function buildStore()
	local frame = panel("Store", 840, 640, "STORE", "Support the game and get perks. Game passes are forever; products are used up.")
	Theme.title({ Size = UDim2.fromOffset(300, 22), Position = UDim2.fromOffset(28, 90), Text = "GAME PASSES", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.GOLD, ZIndex = 11, MaxSize = 18 }, frame)
	ui.passButtons = {}
	for i, key in Config.PASS_ORDER do
		local pass = Config.GAME_PASSES[key]
		local card = Theme.card({ Size = UDim2.fromOffset(188, 196), Position = UDim2.fromOffset(28 + (i - 1) * 198, 120), ZIndex = 11 }, frame)
		Theme.icon({ Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0.5, -30, 0, 12), ZIndex = 12 }, card, pass.icon, Theme.GOLD, 16)
		Theme.title({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 78), Text = pass.name, ZIndex = 12, MaxSize = 18 }, card)
		Theme.text({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 102), Text = pass.desc, TextWrapped = true, TextColor3 = Theme.MUTED, ZIndex = 12, MaxSize = 13 }, card)
		ui.passButtons[key] = Theme.button({ Size = UDim2.new(1, -20, 0, 36), Position = UDim2.new(0, 10, 1, -46), Text = "", ZIndex = 12 }, card, function()
			callbacks.buyPass(key)
		end)
	end
	Theme.title({ Size = UDim2.fromOffset(300, 22), Position = UDim2.fromOffset(28, 330), Text = "PRODUCTS", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.GOLD, ZIndex = 11, MaxSize = 18 }, frame)
	ui.productButtons, ui.productNotes = {}, {}
	for i, key in Config.PRODUCT_ORDER do
		local product = Config.PRODUCTS[key]
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local card = Theme.card({ Size = UDim2.fromOffset(254, 116), Position = UDim2.fromOffset(28 + col * 264, 360 + row * 126), ZIndex = 11 }, frame)
		Theme.icon({ Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(12, 12), ZIndex = 12 }, card, product.icon, Theme.ACCENT, 14)
		Theme.title({ Size = UDim2.new(1, -84, 0, 20), Position = UDim2.fromOffset(72, 12), Text = product.name, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, MaxSize = 16 }, card)
		ui.productNotes[key] = Theme.text({ Size = UDim2.new(1, -84, 0, 30), Position = UDim2.fromOffset(72, 34), Text = product.desc, TextWrapped = true, TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, MaxSize = 12 }, card)
		ui.productButtons[key] = Theme.button({ Size = UDim2.new(1, -24, 0, 34), Position = UDim2.new(0, 12, 1, -44), Text = "", ZIndex = 12 }, card, function()
			callbacks.buyProduct(key)
		end)
	end
end

-- prices: [kind .. key] = Robux price, filled in by Lobby.setPrice
local prices = {}

function Lobby.setPrice(kind, key, robux)
	prices[kind .. key] = robux
	Lobby.refreshStore()
end

function Lobby.refreshStore()
	local owned = {}
	for _, key in meta.passes or {} do
		owned[key] = true
	end
	for key, button in ui.passButtons do
		local pass = Config.GAME_PASSES[key]
		if owned[key] then
			button.Text, button.BackgroundColor3 = "✓ OWNED", Theme.ACCENT
		elseif pass.id == 0 then
			button.Text, button.BackgroundColor3 = "NOT SET UP", Theme.LOCKED
		else
			button.Text, button.BackgroundColor3 = prices["pass" .. key] and "R$ " .. prices["pass" .. key] or "BUY", Theme.GOOD
		end
	end
	for key, button in ui.productButtons do
		local product = Config.PRODUCTS[key]
		if product.id == 0 then
			button.Text, button.BackgroundColor3 = "NOT SET UP", Theme.LOCKED
		else
			button.Text, button.BackgroundColor3 = prices["product" .. key] and "R$ " .. prices["product" .. key] or "BUY", Theme.GOOD
		end
		local note = product.desc
		if product.boost and (meta.boosts or {})[product.boost] and meta.boosts[product.boost] > 0 then
			note = string.format("Active: %d min left", math.ceil(meta.boosts[product.boost] / 60))
		elseif product.revive then
			note = product.desc .. string.format("  (you have %d)", meta.revives or 0)
		end
		ui.productNotes[key].Text = note
	end
end

-- Gold, side menu, hint and the gate banner ----------------------------------------------

local function navButton(parent, icon, label, color, order, onClick)
	local button = Theme.button({ Size = UDim2.fromOffset(78, 78), Text = "", BackgroundColor3 = color, LayoutOrder = order }, parent, onClick)
	Theme.text({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 2), Text = icon, ZIndex = 3 }, button)
	Theme.title({ Size = UDim2.new(1, 0, 0, 15), Position = UDim2.new(0, 0, 1, -22), Text = label, ZIndex = 3, MaxSize = 13 }, button)
	return button
end

local function buildHud()
	local gold = Theme.panel({ Size = UDim2.fromOffset(230, 56), Position = UDim2.new(1, -246, 0, 14) }, ui.root)
	Theme.icon({ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(9, 8), ZIndex = 2 }, gold, "💰", Theme.GOLD, 20)
	ui.gold = Theme.title({ Size = UDim2.new(1, -70, 1, -20), Position = UDim2.fromOffset(58, 10), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.GOLD, ZIndex = 2 }, gold)

	local navPanel = Theme.panel({ Size = UDim2.fromOffset(100, 460), Position = UDim2.new(0, 16, 0.5, -250) }, ui.root)
	local nav = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, navPanel)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, nav)
	for i, item in {
		{ "👒", "CREW", Color3.fromRGB(220, 70, 90), "crew" },
		{ "⚔️", "TRAIN", Color3.fromRGB(99, 132, 255), "train" },
		{ "🛡️", "GEAR", Color3.fromRGB(70, 170, 140), "gear" },
		{ "🛒", "SHOP", Color3.fromRGB(230, 160, 40), "shop" },
		{ "💎", "STORE", Color3.fromRGB(200, 80, 220), "store" },
	} do
		navButton(nav, item[1], item[2], item[3], i, function()
			Lobby.toggle(item[4])
		end)
	end
	local playing = Theme.panel({ Size = UDim2.fromOffset(220, 48), Position = UDim2.new(0, 16, 0.5, 220) }, ui.root)
	local tile, icon = Theme.icon({ Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(8, 7), ZIndex = 2 }, playing, "", Theme.ACCENT, 17)
	ui.playingTile, ui.playingIcon = tile, icon
	ui.crewName = Theme.text({ Size = UDim2.new(1, -60, 1, -16), Position = UDim2.fromOffset(50, 8), Font = Theme.BOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, MaxSize = 16 }, playing)

	ui.saveWarning = Theme.chip({
		Size = UDim2.fromOffset(560, 32), Position = UDim2.new(0.5, -280, 0, 76), Visible = false, MaxSize = 14,
		Text = "⚠️  Your save couldn't load, so progress won't save this visit. Rejoin to try again.",
	}, ui.root, Theme.BAD)
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
	buildTrain()
	buildGear()
	buildShop()
	buildStore()
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
		p.scale.Scale = 0.9
		Theme.tween(p.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		if name == "voyage" then
			Lobby.refreshVoyage()
		elseif name == "train" then
			Lobby.refreshTrain()
		elseif name == "gear" then
			Lobby.refreshGear()
		elseif name == "store" then
			Lobby.refreshStore()
		end
	end
	p.frame.Visible = open
end

-- Opens a menu from an NPC (tab: which tab of the training menu).
function Lobby.open(name, tab)
	if not panels[name] or not ui.root.Visible then
		return
	end
	if name == "train" and tab then
		trainTab = tab
	end
	Lobby.toggle(name, true)
	if name == "train" then
		Lobby.refreshTrain()
	end
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
		card.busy.Visible = portal ~= nil and portal.busy ~= nil and portal.busy[map.key] == true
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
	elseif portal and portal.busy and portal.busy[map.key] then
		ui.sail.Text = "ANOTHER CREW IS HERE"
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
		local unlocked = (data.classes or {})[name] == true
		card.lock.Visible = not unlocked
		card.price.Text = "💰 " .. Theme.comma(card.cost) .. (data.gold >= card.cost and "  -  RECRUIT" or "")
		card.price.TextColor3 = data.gold >= card.cost and Theme.GOOD or Theme.GOLD
		card.bounty.Text = unlocked and "IN YOUR CREW" or "BOUNTY  💰 " .. Theme.comma(card.cost)
		card.selected.Visible = chosen
		card.stroke.Color = chosen and Theme.GOLD or Theme.INK
		card.stroke.Thickness = chosen and 4 or 2
		card.stroke.Transparency = chosen and 0 or 0.35
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
	ui.saveWarning.Visible = data.loadFailed == true
	Lobby.refreshVoyage()
	if panels.train.frame.Visible then
		Lobby.refreshTrain()
	end
	if panels.gear.frame.Visible then
		Lobby.refreshGear()
	end
	Lobby.refreshStore()
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
	for name, p in panels do
		if name ~= "voyage" then
			p.frame.Visible = false
		end
	end
	-- the captain gets the map select once per boarding
	if info.captain and not info.map and not pickerOpened then
		pickerOpened = true
		Lobby.toggle("voyage", true)
	end
	if wasCaptain ~= isCaptain() or panels.voyage.frame.Visible then
		Lobby.refreshVoyage() -- keeps captain status and busy maps current
	end
end

return Lobby
