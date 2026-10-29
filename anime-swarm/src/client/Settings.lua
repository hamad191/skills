-- The settings menu (⚙️): music and effects volume, damage numbers, camera shake and a low
-- graphics mode for phones. Saved with the player's data; works on the island and in adventures.
local Theme = require(script.Parent.Theme)
local Sounds = require(script.Parent.Sounds)
local Effects = require(script.Parent.Effects)

local Settings = {}
local values = { music = 0.5, sfx = 0.8, numbers = true, shake = true, low = false }
local ui = {}
local onChange
local sendAt -- debounce: the server hears about changes once things settle

local function apply()
	Sounds.setVolume(values.music, values.sfx)
	Effects.settings.numbers = values.numbers
	Effects.settings.shake = values.shake
	Effects.settings.low = values.low
end

local function refresh()
	for key, row in ui.rows or {} do
		local v = values[key]
		if type(v) == "number" then
			row.value.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
		else
			row.toggle.Text = v and "ON" or "OFF"
			row.toggle.BackgroundColor3 = v and Theme.GOOD or Theme.LOCKED
		end
	end
end

local function changed()
	apply()
	refresh()
	local token = {}
	sendAt = token
	task.delay(1, function()
		if sendAt == token and onChange then
			onChange(table.clone(values))
		end
	end)
end

function Settings.init(root, change)
	onChange = change
	local frame = Theme.panel({
		Name = "Settings", Size = UDim2.fromOffset(460, 420), Position = UDim2.new(0.5, -230, 0.5, -210), Visible = false, ZIndex = 40,
	}, root)
	ui.frame = frame
	ui.scale = Theme.new("UIScale", {}, frame)
	Theme.title({ Size = UDim2.new(1, -100, 0, 34), Position = UDim2.fromOffset(26, 20), Text = "⚙️ SETTINGS", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41 }, frame)
	Theme.divider({ Size = UDim2.new(1, -40, 0, 2), Position = UDim2.fromOffset(20, 66), ZIndex = 41 }, frame)
	Theme.button({ Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -60, 0, 18), Text = "X", BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 42 }, frame, function()
		Settings.toggle(false)
	end)
	ui.rows = {}
	local rows = {
		{ "music", "🎵 Music" }, { "sfx", "🔊 Sound effects" }, { "numbers", "🔢 Damage numbers" },
		{ "shake", "📳 Camera shake" }, { "low", "🥔 Low graphics (fewer particles)" },
	}
	for i, row in rows do
		local key = row[1]
		local card = Theme.card({ Size = UDim2.new(1, -40, 0, 56), Position = UDim2.fromOffset(20, 80 + (i - 1) * 64), ZIndex = 41 }, frame)
		Theme.text({ Size = UDim2.new(1, -200, 1, -16), Position = UDim2.fromOffset(14, 8), Text = row[2], Font = Theme.BOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42, MaxSize = 18 }, card)
		local entry = {}
		if type(values[key]) == "number" then
			Theme.button({ Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -170, 0, 8), Text = "-", BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 42 }, card, function()
				values[key] = math.max(0, values[key] - 0.1)
				changed()
			end)
			entry.value = Theme.title({ Size = UDim2.fromOffset(70, 30), Position = UDim2.new(1, -125, 0, 13), Text = "", ZIndex = 42, MaxSize = 20 }, card)
			Theme.button({ Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -50, 0, 8), Text = "+", BackgroundColor3 = Theme.CARD_LIGHT, ZIndex = 42 }, card, function()
				values[key] = math.min(1, values[key] + 0.1)
				changed()
			end)
		else
			entry.toggle = Theme.button({ Size = UDim2.fromOffset(96, 40), Position = UDim2.new(1, -108, 0, 8), Text = "", ZIndex = 42 }, card, function()
				values[key] = not values[key]
				changed()
			end)
		end
		ui.rows[key] = entry
	end
	apply()
	refresh()
end

-- Applies settings loaded from the save.
function Settings.load(saved)
	if type(saved) ~= "table" then
		return
	end
	for key, v in saved do
		if values[key] ~= nil and type(v) == type(values[key]) then
			values[key] = v
		end
	end
	apply()
	refresh()
end

function Settings.toggle(open)
	if open == nil then
		open = not ui.frame.Visible
	end
	if open and not ui.frame.Visible then
		ui.scale.Scale = 0.9
		Theme.tween(ui.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	ui.frame.Visible = open
end

return Settings
