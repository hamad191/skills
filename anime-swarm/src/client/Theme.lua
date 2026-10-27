-- Shared look for every menu: colors, fonts and small UI builders.
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.BG = Color3.fromRGB(14, 18, 36)
Theme.PANEL = Color3.fromRGB(26, 32, 60)
Theme.CARD = Color3.fromRGB(38, 46, 84)
Theme.STROKE = Color3.fromRGB(95, 115, 190)
Theme.GOLD = Color3.fromRGB(255, 205, 60)
Theme.TEXT = Color3.fromRGB(242, 245, 255)
Theme.MUTED = Color3.fromRGB(160, 172, 210)
Theme.GOOD = Color3.fromRGB(90, 220, 120)
Theme.BAD = Color3.fromRGB(240, 70, 70)
Theme.DARK_TEXT = Color3.fromRGB(20, 22, 35)
Theme.TITLE_FONT = Enum.Font.LuckiestGuy
Theme.FONT = Enum.Font.FredokaOne

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
		Color = color or Theme.STROKE, Thickness = thickness or 2, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- Vertical gradient that tints whatever color the parent has.
function Theme.gradient(parent, top, bottom, rotation)
	return Theme.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 }, parent)
end

function Theme.panel(props, parent)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.PANEL
	local frame = Theme.new("Frame", props, parent)
	Theme.corner(frame, 16)
	Theme.stroke(frame, Theme.STROKE, 2, 0.35)
	Theme.gradient(frame, Color3.new(1, 1, 1), Color3.fromRGB(150, 160, 190))
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
	props.Font = Theme.TITLE_FONT
	props.TextColor3 = props.TextColor3 or Theme.GOLD
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0
	props.TextStrokeColor3 = props.TextStrokeColor3 or Color3.fromRGB(30, 15, 0)
	return Theme.text(props, parent)
end

-- Rounded button that grows on hover and squishes when pressed.
function Theme.button(props, parent, onClick)
	props.AutoButtonColor = false
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.CARD
	props.Font = props.Font or Theme.TITLE_FONT
	props.TextColor3 = props.TextColor3 or Theme.TEXT
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local button = Theme.new("TextButton", props, parent)
	Theme.corner(button, 12)
	local stroke = Theme.stroke(button, Color3.new(1, 1, 1), 2, 0.75)
	Theme.gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(170, 175, 200))
	Theme.new("UITextSizeConstraint", { MaxTextSize = 26 }, button)
	local scale = Theme.new("UIScale", {}, button)
	button.MouseEnter:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1.05 })
		Theme.tween(stroke, 0.12, { Transparency = 0.2 })
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
		Theme.tween(stroke, 0.12, { Transparency = 0.75 })
	end)
	button.MouseButton1Down:Connect(function()
		Theme.tween(scale, 0.06, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		Theme.tween(scale, 0.1, { Scale = 1.05 })
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- Rounded progress bar. Returns the frame, its fill and a centered label.
function Theme.bar(props, parent, top, bottom)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.BG
	props.BackgroundTransparency = props.BackgroundTransparency or 0.15
	local frame = Theme.new("Frame", props, parent)
	Theme.corner(frame, 10)
	Theme.stroke(frame, Color3.new(0, 0, 0), 2, 0.4)
	local fill = Theme.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, frame)
	Theme.corner(fill, 10)
	Theme.gradient(fill, top, bottom)
	local label = Theme.text({ Size = UDim2.fromScale(1, 1), ZIndex = (props.ZIndex or 1) + 1, TextStrokeTransparency = 0.3, MaxSize = 18 }, frame)
	return frame, fill, label
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
