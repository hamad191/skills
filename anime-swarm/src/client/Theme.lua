-- Shared look for every menu: "Grand Line" pirate style. Deep-sea navy panels with gold rope
-- trim and corner rivets, glossy chunky buttons, parchment for wanted posters, and cartoon
-- fonts (Luckiest Guy titles, Fredoka One labels). Colors, fonts and small UI builders.
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.BG = Color3.fromRGB(7, 17, 30)
Theme.PANEL = Color3.fromRGB(15, 33, 54)
Theme.CARD = Color3.fromRGB(23, 47, 74)
Theme.CARD_LIGHT = Color3.fromRGB(36, 66, 100)
Theme.LINE = Color3.fromRGB(255, 255, 255)
Theme.ACCENT = Color3.fromRGB(226, 72, 64) -- straw-hat red
Theme.GOLD = Color3.fromRGB(255, 200, 70)
Theme.TRIM = Color3.fromRGB(214, 168, 88) -- rope gold
Theme.TEXT = Color3.fromRGB(252, 246, 230)
Theme.MUTED = Color3.fromRGB(165, 184, 206)
Theme.GOOD = Color3.fromRGB(64, 200, 120)
Theme.BAD = Color3.fromRGB(255, 84, 96)
Theme.DARK_TEXT = Color3.fromRGB(14, 16, 26)
Theme.LOCKED = Color3.fromRGB(60, 70, 88)
Theme.PARCHMENT = Color3.fromRGB(240, 222, 180)
Theme.INK = Color3.fromRGB(70, 42, 20)
Theme.SEA = Color3.fromRGB(40, 140, 210)
Theme.TITLE_FONT = Enum.Font.LuckiestGuy
Theme.BOLD = Enum.Font.FredokaOne
Theme.FONT = Enum.Font.GothamMedium

function Theme.new(class, props, parent)
	local obj = Instance.new(class)
	for k, v in props do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

function Theme.tween(obj, time, goal, style, direction)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(obj, info, goal)
	t:Play()
	return t
end

function Theme.corner(parent, radius)
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

function Theme.stroke(parent, color, thickness, transparency)
	return Theme.new("UIStroke", {
		Color = color or Theme.LINE, Thickness = thickness or 1, Transparency = transparency or 0.85,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- Vertical gradient that tints whatever color the parent has.
function Theme.gradient(parent, top, bottom, rotation)
	return Theme.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 }, parent)
end

function Theme.padding(parent, px)
	return Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
	}, parent)
end

-- Little gold rivets in the corners of a panel, like a ship's chest.
function Theme.rivets(frame, inset, zIndex)
	inset = inset or 7
	for _, pos in {
		UDim2.fromOffset(inset, inset), UDim2.new(1, -inset - 6, 0, inset),
		UDim2.new(0, inset, 1, -inset - 6), UDim2.new(1, -inset - 6, 1, -inset - 6),
	} do
		local rivet = Theme.new("Frame", {
			Name = "Rivet", Size = UDim2.fromOffset(6, 6), Position = pos, BackgroundColor3 = Theme.TRIM,
			ZIndex = zIndex or 2, BorderSizePixel = 0,
		}, frame)
		Theme.corner(rivet, 3)
	end
end

-- Deep-sea panel with a gold rope border, an inner hairline and corner rivets.
function Theme.panel(props, parent)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.PANEL
	props.BackgroundTransparency = props.BackgroundTransparency or 0.04
	local frame = Theme.new("Frame", props, parent)
	Theme.corner(frame, 16)
	Theme.stroke(frame, Theme.TRIM, 2, 0.15)
	Theme.gradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 165, 190))
	local inner = Theme.new("Frame", {
		Name = "Inlay", Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5),
		BackgroundTransparency = 1, ZIndex = props.ZIndex or 1,
	}, frame)
	Theme.corner(inner, 12)
	Theme.stroke(inner, Theme.TRIM, 1, 0.7)
	Theme.rivets(frame, 4, (props.ZIndex or 1) + 1)
	return frame
end

-- Rounded card used inside panels.
function Theme.card(props, parent)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.CARD
	local frame = Theme.new("Frame", props, parent)
	Theme.corner(frame, 12)
	Theme.stroke(frame, Theme.TRIM, 1, 0.75)
	Theme.gradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 200, 215))
	return frame
end

-- A parchment card (wanted posters, the results scroll).
function Theme.parchment(props, parent, class)
	props.BackgroundColor3 = Theme.PARCHMENT
	local frame = Theme.new(class or "Frame", props, parent)
	Theme.corner(frame, 6)
	Theme.stroke(frame, Theme.INK, 2, 0.35)
	Theme.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 235)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 190, 150)),
		}),
		Rotation = 90,
	}, frame)
	return frame
end

-- A gold divider that fades out at both ends.
function Theme.divider(props, parent)
	props.BackgroundColor3 = Theme.TRIM
	props.BorderSizePixel = 0
	local line = Theme.new("Frame", props, parent)
	Theme.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2),
			NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1),
		}),
	}, line)
	return line
end

-- Text label. Pass MaxSize to cap scaled text.
function Theme.text(props, parent)
	local maxSize = props.MaxSize
	props.MaxSize = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Theme.TEXT
	props.Font = props.Font or Theme.FONT
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local label = Theme.new("TextLabel", props, parent)
	if maxSize then
		Theme.new("UITextSizeConstraint", { MaxTextSize = maxSize }, label)
	end
	return label
end

-- Cartoon title text with a dark outline.
function Theme.title(props, parent)
	props.Font = props.Font or Theme.TITLE_FONT
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.35
	props.TextStrokeColor3 = props.TextStrokeColor3 or Color3.fromRGB(5, 10, 20)
	return Theme.text(props, parent)
end

-- Small rounded label ("chip"), e.g. tags and counters.
function Theme.chip(props, parent, color)
	color = color or Theme.ACCENT
	props.BackgroundTransparency = props.BackgroundTransparency or 0.8
	props.BackgroundColor3 = color
	props.TextColor3 = props.TextColor3 or color:Lerp(Color3.new(1, 1, 1), 0.45)
	props.Font = props.Font or Theme.BOLD
	local chip = Theme.text(props, parent)
	Theme.corner(chip, 8)
	Theme.padding(chip, 4)
	return chip
end

-- Rounded square with a colored gradient and an emoji icon in the middle.
function Theme.icon(props, parent, icon, color, radius)
	props.BackgroundColor3 = color or Theme.ACCENT
	local tile = Theme.new("Frame", props, parent)
	Theme.corner(tile, radius or 10)
	Theme.gradient(tile, Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 140), 135)
	Theme.stroke(tile, Theme.TRIM, 1.5, 0.45)
	local label = Theme.text({
		Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.14, 0.14), Text = icon or "",
		ZIndex = (props.ZIndex or 1) + 1, Font = Theme.TITLE_FONT,
	}, tile)
	return tile, label
end

-- Button with a hover glow and a press squish. The glow is an overlay, so callers can
-- recolor the button at any time.
function Theme.button(props, parent, onClick)
	props.AutoButtonColor = false
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.ACCENT
	props.Font = props.Font or Theme.BOLD
	props.TextColor3 = props.TextColor3 or Theme.TEXT
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local button = Theme.new("TextButton", props, parent)
	if button.TextStrokeTransparency == 1 then
		button.TextStrokeTransparency = 0.55
	end
	Theme.corner(button, 12)
	Theme.stroke(button, Color3.fromRGB(10, 20, 35), 2, 0.35)
	-- glossy: a bright top half and a darker bottom half
	Theme.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.48, Color3.fromRGB(235, 235, 235)),
			ColorSequenceKeypoint.new(0.52, Color3.fromRGB(205, 205, 205)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(165, 165, 165)),
		}),
		Rotation = 90,
	}, button)
	Theme.new("UITextSizeConstraint", { MaxTextSize = 22 }, button)
	Theme.padding(button, 6)
	local glow = Theme.new("Frame", {
		Name = "Glow", Size = UDim2.new(1, 12, 1, 12), Position = UDim2.fromOffset(-6, -6),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = (props.ZIndex or 1) + 1,
	}, button)
	Theme.corner(glow, 12)
	local scale = Theme.new("UIScale", {}, button)
	button.MouseEnter:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1.03 })
		Theme.tween(glow, 0.12, { BackgroundTransparency = 0.88 })
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
		Theme.tween(glow, 0.12, { BackgroundTransparency = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Theme.tween(scale, 0.06, { Scale = 0.97 })
	end)
	button.MouseButton1Up:Connect(function()
		Theme.tween(scale, 0.1, { Scale = 1.03 })
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- Slim rounded progress bar. Returns the frame, its fill and a centered label.
function Theme.bar(props, parent, top, bottom)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(4, 10, 20)
	props.BackgroundTransparency = props.BackgroundTransparency or 0.35
	local frame = Theme.new("Frame", props, parent)
	Theme.corner(frame, 8)
	Theme.stroke(frame, Theme.TRIM, 1, 0.6)
	local fill = Theme.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = (props.ZIndex or 1) }, frame)
	Theme.corner(fill, 8)
	Theme.gradient(fill, top, bottom, 0)
	local label = Theme.text({
		Size = UDim2.fromScale(1, 1), ZIndex = (props.ZIndex or 1) + 1, Font = Theme.BOLD, MaxSize = 15,
		TextStrokeTransparency = 0.6,
	}, frame)
	return frame, fill, label
end

-- Scales a full-screen root frame so the whole UI fits any screen. Layouts are designed for
-- 1280x720; smaller screens (phones) shrink everything evenly.
function Theme.autoScale(root)
	local scale = Theme.new("UIScale", {}, root)
	local function update()
		local view = workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(view.X / 1280, view.Y / 720), 0.45, 1)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	update()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return scale
end

function Theme.comma(n)
	local s = tostring(math.floor(n))
	repeat
		local count
		s, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return s
end

return Theme
