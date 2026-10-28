-- Shared look for every menu: a modern dark glass style. Colors, fonts and small UI builders.
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.BG = Color3.fromRGB(11, 13, 22)
Theme.PANEL = Color3.fromRGB(20, 24, 40)
Theme.CARD = Color3.fromRGB(31, 36, 58)
Theme.CARD_LIGHT = Color3.fromRGB(44, 51, 80)
Theme.LINE = Color3.fromRGB(255, 255, 255)
Theme.ACCENT = Color3.fromRGB(99, 132, 255)
Theme.GOLD = Color3.fromRGB(255, 196, 64)
Theme.TEXT = Color3.fromRGB(236, 240, 255)
Theme.MUTED = Color3.fromRGB(138, 148, 184)
Theme.GOOD = Color3.fromRGB(70, 214, 140)
Theme.BAD = Color3.fromRGB(255, 84, 104)
Theme.DARK_TEXT = Color3.fromRGB(14, 16, 26)
Theme.LOCKED = Color3.fromRGB(52, 56, 76)
Theme.TITLE_FONT = Enum.Font.GothamBlack
Theme.BOLD = Enum.Font.GothamBold
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

-- Frosted dark panel with a hairline border.
function Theme.panel(props, parent)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.PANEL
	props.BackgroundTransparency = props.BackgroundTransparency or 0.06
	local frame = Theme.new("Frame", props, parent)
	Theme.corner(frame, 18)
	Theme.stroke(frame, Theme.LINE, 1, 0.86)
	Theme.gradient(frame, Color3.new(1, 1, 1), Color3.fromRGB(180, 186, 210))
	return frame
end

-- Rounded card used inside panels.
function Theme.card(props, parent)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.CARD
	local frame = Theme.new("Frame", props, parent)
	Theme.corner(frame, 12)
	Theme.stroke(frame, Theme.LINE, 1, 0.9)
	return frame
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

function Theme.title(props, parent)
	props.Font = props.Font or Theme.TITLE_FONT
	props.TextStrokeTransparency = props.TextStrokeTransparency or 1
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
	Theme.stroke(tile, Theme.LINE, 1, 0.75)
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
	Theme.corner(button, 12)
	Theme.stroke(button, Theme.LINE, 1, 0.82)
	Theme.gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(200, 205, 225))
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
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(255, 255, 255)
	props.BackgroundTransparency = props.BackgroundTransparency or 0.9
	local frame = Theme.new("Frame", props, parent)
	Theme.corner(frame, 8)
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
