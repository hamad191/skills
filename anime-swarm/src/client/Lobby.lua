-- Spawn island UI: character select, upgrade shop, gold counter, hints and the portal boarding banner.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)

local Lobby = {}
local ui = {}
local callbacks
local classCards = {}
local shopRows = {}
local panels = {}
local lastPortalMessage = 0
local meta = { gold = 0, levels = {}, costs = {}, class = Config.DEFAULT_CLASS }

local function closeButton(panel, name)
	Theme.button({
		Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -52, 0, 12), Text = "X",
		BackgroundColor3 = Theme.BAD, ZIndex = panel.ZIndex + 2,
	}, panel, function()
		Lobby.toggle(name, false)
	end)
end

-- Character select ------------------------------------------------------------------

local function buildCrew(root)
	local panel = Theme.panel({
		Name = "Crew", Size = UDim2.fromOffset(740, 600), Position = UDim2.new(0.5, -370, 0.5, -300),
		Visible = false, ZIndex = 10,
	}, root)
	panels.crew = { frame = panel, scale = Theme.new("UIScale", {}, panel) }
	Theme.title({ Size = UDim2.new(1, -120, 0, 50), Position = UDim2.fromOffset(24, 14), Text = "CHOOSE YOUR PIRATE", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 }, panel)
	closeButton(panel, "crew")

	local grid = Theme.new("Frame", { Size = UDim2.new(1, -40, 0, 430), Position = UDim2.fromOffset(20, 76), BackgroundTransparency = 1, ZIndex = 11 }, panel)
	local details = Theme.new("Frame", { Size = UDim2.new(1, -40, 0, 74), Position = UDim2.new(0, 20, 1, -88), BackgroundColor3 = Theme.CARD, ZIndex = 11 }, panel)
	Theme.corner(details, 12)
	ui.detailsTitle = Theme.title({ Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, details)
	ui.detailsSkills = Theme.text({
		Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 32), TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true, TextColor3 = Theme.TEXT, ZIndex = 12, MaxSize = 16,
	}, details)
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(166, 206), CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	for i, name in Config.CLASS_ORDER do
		local class = Config.Classes[name]
		local skill = Config.Weapons[class.weapon]
		local card = Theme.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.CARD, LayoutOrder = i, ZIndex = 12 }, grid)
		Theme.corner(card, 14)
		local stroke = Theme.stroke(card, class.color, 2, 0.4)
		Theme.gradient(card, Color3.new(1, 1, 1), Color3.fromRGB(150, 155, 185))
		local scale = Theme.new("UIScale", {}, card)

		local portrait = Theme.new("Frame", { Size = UDim2.fromOffset(84, 84), Position = UDim2.new(0.5, -42, 0, 12), BackgroundColor3 = class.color, ZIndex = 13 }, card)
		Theme.corner(portrait, 42)
		Theme.stroke(portrait, Color3.new(1, 1, 1), 3, 0.1)
		Theme.gradient(portrait, Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 120))
		Theme.title({ Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), Text = name:sub(1, 1), TextColor3 = Color3.new(1, 1, 1), ZIndex = 14 }, portrait)

		Theme.title({ Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 102), Text = name:upper(), TextColor3 = Theme.TEXT, ZIndex = 13 }, card)
		Theme.text({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 130), Text = class.title, TextColor3 = Theme.MUTED, ZIndex = 13, MaxSize = 16 }, card)
		Theme.text({ Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 152), Text = skill.name, TextColor3 = skill.color:Lerp(Color3.new(1, 1, 1), 0.3), ZIndex = 13, MaxSize = 17 }, card)
		Theme.text({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 176), Text = class.perk, TextColor3 = Theme.GOOD, ZIndex = 13, MaxSize = 15 }, card)
		local selected = Theme.title({
			Size = UDim2.fromOffset(110, 22), Position = UDim2.new(0.5, -55, 0, -8), Text = "SELECTED",
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

local function buildShop(root)
	local panel = Theme.panel({
		Name = "Shop", Size = UDim2.fromOffset(600, 560), Position = UDim2.new(0.5, -300, 0.5, -280),
		Visible = false, ZIndex = 10,
	}, root)
	panels.shop = { frame = panel, scale = Theme.new("UIScale", {}, panel) }
	Theme.title({ Size = UDim2.new(1, -120, 0, 50), Position = UDim2.fromOffset(24, 14), Text = "PERMANENT UPGRADES", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 }, panel)
	Theme.text({ Size = UDim2.new(1, -48, 0, 20), Position = UDim2.fromOffset(24, 62), Text = "Spend gold from adventures. Upgrades last forever.", TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, MaxSize = 17 }, panel)
	closeButton(panel, "shop")

	for i, name in Config.META_ORDER do
		local m = Config.Meta[name]
		local row = Theme.new("Frame", {
			Size = UDim2.new(1, -40, 0, 68), Position = UDim2.fromOffset(20, 92 + (i - 1) * 76),
			BackgroundColor3 = Theme.CARD, ZIndex = 11,
		}, panel)
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

-- Portal banner, hint, gold and menu buttons ---------------------------------------------

local function buildHud(root)
	local gold = Theme.panel({ Size = UDim2.fromOffset(190, 48), Position = UDim2.new(1, -206, 0, 14) }, root)
	ui.gold = Theme.title({ Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6), Text = "💰 0" }, gold)

	local menu = Theme.new("Frame", { Size = UDim2.fromOffset(170, 190), Position = UDim2.new(0, 16, 0.5, -95), BackgroundTransparency = 1 }, root)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, menu)
	Theme.button({ Size = UDim2.fromOffset(170, 64), Text = "👒 CREW", BackgroundColor3 = Color3.fromRGB(200, 60, 60), LayoutOrder = 1 }, menu, function()
		Lobby.toggle("crew")
	end)
	ui.crewName = Theme.text({ Size = UDim2.new(1, 0, 0, 20), Text = "", TextColor3 = Theme.MUTED, MaxSize = 16, LayoutOrder = 2 }, menu)
	Theme.button({ Size = UDim2.fromOffset(170, 64), Text = "💰 SHOP", BackgroundColor3 = Color3.fromRGB(220, 160, 30), LayoutOrder = 3 }, menu, function()
		Lobby.toggle("shop")
	end)

	ui.hint = Theme.panel({ Size = UDim2.fromOffset(560, 50), Position = UDim2.new(0.5, -280, 1, -74) }, root)
	Theme.text({ Size = UDim2.new(1, -24, 1, -14), Position = UDim2.fromOffset(12, 7), Text = "Pick a pirate in CREW, then walk into a portal to set sail!", MaxSize = 20 }, ui.hint)

	local banner = Theme.panel({ Size = UDim2.fromOffset(460, 110), Position = UDim2.new(0.5, -230, 0, 20), Visible = false }, root)
	ui.banner = banner
	ui.bannerStroke = banner:FindFirstChildOfClass("UIStroke")
	ui.bannerScale = Theme.new("UIScale", {}, banner)
	ui.bannerName = Theme.title({ Size = UDim2.new(1, -24, 0, 38), Position = UDim2.fromOffset(12, 8), Text = "" }, banner)
	ui.bannerStars = Theme.title({ Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 46), Text = "", TextColor3 = Theme.GOLD }, banner)
	ui.bannerStatus = Theme.text({ Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(12, 72), Text = "", MaxSize = 22 }, banner)
end

-- Public ----------------------------------------------------------------------------------

function Lobby.init(gui, cb)
	callbacks = cb
	local root = Theme.new("Frame", { Name = "Lobby", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	ui.root = root
	buildHud(root)
	buildCrew(root)
	buildShop(root)
	Lobby.setMeta(meta)

	RunService.Heartbeat:Connect(function()
		local boarding = os.clock() - lastPortalMessage < 0.6
		if ui.banner.Visible ~= boarding then
			ui.banner.Visible = boarding
			if boarding then
				ui.bannerScale.Scale = 0.7
				Theme.tween(ui.bannerScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		ui.hint.Visible = not boarding
	end)
end

function Lobby.setVisible(visible)
	ui.root.Visible = visible
	if not visible then
		Lobby.toggle("crew", false)
		Lobby.toggle("shop", false)
	end
end

-- Opens or closes a panel (only one at a time).
function Lobby.toggle(name, open)
	local panel = panels[name]
	if open == nil then
		open = not panel.frame.Visible
	end
	if open then
		for other, p in panels do
			if other ~= name then
				p.frame.Visible = false
			end
		end
		panel.scale.Scale = 0.85
		Theme.tween(panel.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	panel.frame.Visible = open
end

-- Lists a character's 6 skills under the character cards.
function Lobby.showSkills(name)
	local class = Config.Classes[name]
	if not class then
		return
	end
	local names = {}
	for _, key in class.skills do
		table.insert(names, Config.Weapons[key].name)
	end
	ui.detailsTitle.Text = name:upper() .. "'S 6 SKILLS"
	ui.detailsTitle.TextColor3 = class.color:Lerp(Color3.new(1, 1, 1), 0.3)
	ui.detailsSkills.Text = table.concat(names, "  -  ")
end

function Lobby.setMeta(data)
	meta = data
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
end

function Lobby.portal(info)
	lastPortalMessage = os.clock()
	ui.bannerName.Text = "⛵ " .. info.name:upper()
	ui.bannerName.TextColor3 = info.color
	ui.bannerStroke.Color = info.color
	ui.bannerStroke.Transparency = 0
	ui.bannerStars.Text = string.rep("★", info.stars) .. "  " .. info.difficulty:upper()
	ui.bannerStatus.Text = info.text
	-- close menus so the player can see the countdown
	Lobby.toggle("crew", false)
	Lobby.toggle("shop", false)
end

return Lobby
