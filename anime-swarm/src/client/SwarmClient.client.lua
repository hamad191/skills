-- HUD, level-up cards, and the lobby (class select + permanent upgrades).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = RS:WaitForChild("Remotes")
local player = Players.LocalPlayer

local DARK = Color3.fromRGB(18, 18, 28)
local CARD = Color3.fromRGB(35, 35, 50)
local GOLD = Color3.fromRGB(255, 215, 0)
local SELECTED = Color3.fromRGB(60, 110, 200)

local function new(class, props, parent)
	local obj = Instance.new(class)
	for k, v in props do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

local function text(class, props, parent)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or Enum.Font.GothamBold
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	return new(class, props, parent)
end

local gui = new("ScreenGui", { Name = "SwarmUI", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

-- Run HUD -----------------------------------------------------------------
local timer = text("TextLabel", { Size = UDim2.new(0, 300, 0, 40), Position = UDim2.new(0.5, -150, 0, 30) }, gui)

local xpBack = new("Frame", {
	Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 6),
	BackgroundColor3 = DARK, Visible = false,
}, gui)
local xpFill = new("Frame", {
	Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(70, 160, 255), BorderSizePixel = 0,
}, xpBack)
local levelText = text("TextLabel", { Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2 }, xpBack)

local buildText = text("TextLabel", {
	Size = UDim2.new(0, 240, 0, 260), Position = UDim2.new(0, 10, 0, 80),
	TextScaled = false, TextSize = 14, Text = "", Visible = false,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	TextStrokeTransparency = 0.5,
}, gui)

remotes.Stats.OnClientEvent:Connect(function(st)
	xpFill.Size = UDim2.fromScale(math.clamp(st.xp / st.need, 0, 1), 1)
	levelText.Text = ("Level %d   |   Kills %d"):format(st.level, st.kills)
	buildText.Text = "WEAPONS\n" .. table.concat(st.weapons, "\n") .. "\n\nPASSIVES\n" .. table.concat(st.passives, "\n")
end)

-- Level-up cards ----------------------------------------------------------
local levelPanel = new("Frame", {
	Size = UDim2.new(0, 660, 0, 270), Position = UDim2.new(0.5, -330, 0.5, -135),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.1, Visible = false,
}, gui)
new("UICorner", {}, levelPanel)
text("TextLabel", { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 6), Text = "LEVEL UP!  Pick one (1 / 2 / 3)", TextColor3 = GOLD }, levelPanel)

local cards = {}
for i = 1, Config.CHOICES do
	local button = new("TextButton", {
		Size = UDim2.new(0, 200, 0, 160), Position = UDim2.new(0, 15 + (i - 1) * 215, 0, 50),
		Text = "", BackgroundColor3 = CARD,
	}, levelPanel)
	new("UICorner", {}, button)
	local title = text("TextLabel", { Size = UDim2.new(1, -10, 0, 44), Position = UDim2.new(0, 5, 0, 6) }, button)
	local body = text("TextLabel", {
		Size = UDim2.new(1, -14, 1, -60), Position = UDim2.new(0, 7, 0, 54),
		TextScaled = false, TextSize = 16, TextWrapped = true, Font = Enum.Font.Gotham,
	}, button)
	cards[i] = { button = button, title = title, body = body }
end

local rerollButton = text("TextButton", {
	Size = UDim2.new(0, 160, 0, 36), Position = UDim2.new(0.5, -80, 1, -46),
	BackgroundTransparency = 0, BackgroundColor3 = CARD, Text = "Reroll (R)",
}, levelPanel)
new("UICorner", {}, rerollButton)

local function choose(i)
	if levelPanel.Visible and cards[i].button.Visible then
		levelPanel.Visible = false -- the server sends the next offer, if any
		remotes.Choose:FireServer(i)
	end
end

local function reroll()
	if levelPanel.Visible and rerollButton.Visible then
		remotes.Reroll:FireServer()
	end
end

for i, card in cards do
	card.button.Activated:Connect(function()
		choose(i)
	end)
end
rerollButton.Activated:Connect(reroll)

remotes.LevelUp.OnClientEvent:Connect(function(list, rerolls)
	if not list then
		levelPanel.Visible = false
		return
	end
	for i, card in cards do
		local c = list[i]
		card.button.Visible = c ~= nil
		if c then
			card.title.Text = c.title
			card.title.TextColor3 = c.color
			card.body.Text = c.text
		end
	end
	rerollButton.Text = ("Reroll (R) x%d"):format(rerolls)
	rerollButton.Visible = rerolls > 0
	levelPanel.Visible = true
end)

local KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }
UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if KEYS[input.KeyCode] then
		choose(KEYS[input.KeyCode])
	elseif input.KeyCode == Enum.KeyCode.R then
		reroll()
	end
end)

-- Lobby: classes and permanent upgrades -----------------------------------
local lobby = new("Frame", {
	Size = UDim2.new(0, 340, 0, 470), Position = UDim2.new(1, -350, 0.5, -235),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.1,
}, gui)
new("UICorner", {}, lobby)
local goldText = text("TextLabel", { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 8), TextColor3 = GOLD, Text = "Gold: 0" }, lobby)

local function lobbyButton(y, onClick)
	local b = text("TextButton", {
		Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0, 10, 0, y),
		BackgroundTransparency = 0, BackgroundColor3 = CARD,
		TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.Gotham,
	}, lobby)
	new("UICorner", {}, b)
	b.Activated:Connect(onClick)
	return b
end

text("TextLabel", { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 0, 44), Text = "CHOOSE CLASS" }, lobby)
local classButtons = {}
for i, name in Config.CLASS_ORDER do
	local b = lobbyButton(70 + (i - 1) * 38, function()
		remotes.SelectClass:FireServer(name)
	end)
	b.Text = name .. ": " .. Config.Classes[name].desc
	classButtons[name] = b
end

local metaTop = 70 + #Config.CLASS_ORDER * 38 + 8
text("TextLabel", { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 0, metaTop), Text = "PERMANENT UPGRADES" }, lobby)
local metaButtons = {}
for i, name in Config.META_ORDER do
	metaButtons[name] = lobbyButton(metaTop + 26 + (i - 1) * 38, function()
		remotes.BuyMeta:FireServer(name)
	end)
end

remotes.Meta.OnClientEvent:Connect(function(data)
	goldText.Text = "Gold: " .. data.gold
	for name, b in classButtons do
		b.BackgroundColor3 = name == data.class and SELECTED or CARD
	end
	for name, b in metaButtons do
		local m = Config.Meta[name]
		local cost = data.costs[name]
		b.Text = ("%s %d/%d (%s)  -  %s"):format(m.name, data.levels[name], m.max, m.desc, cost and cost .. " gold" or "MAX")
	end
end)
remotes.Meta:FireServer()

-- Phase + results ---------------------------------------------------------
remotes.State.OnClientEvent:Connect(function(state)
	timer.Text = state.text
	local running = state.phase == "Run"
	lobby.Visible = not running
	xpBack.Visible = running
	buildText.Visible = running
end)

local results = text("TextLabel", {
	Size = UDim2.new(0, 440, 0, 130), Position = UDim2.new(0.5, -220, 0.3, 0),
	BackgroundTransparency = 0.15, BackgroundColor3 = DARK,
	TextScaled = false, TextSize = 22, TextWrapped = true, Visible = false,
}, gui)
remotes.Results.OnClientEvent:Connect(function(r)
	results.Text = ("%s\nSurvived %d:%02d  |  Level %d  |  %d kills\n+%d gold"):format(
		r.result:upper(), r.time // 60, r.time % 60, r.level, r.kills, r.gold
	)
	results.Visible = true
	task.delay(Config.RESULTS_TIME, function()
		results.Visible = false
	end)
end)
