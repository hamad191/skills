-- Each map has its own mood: time of day, haze, color tint and weather (snow on Snowcap Island, ash
-- on Burning Isle, cherry blossoms in Blossom Land, bubbles at Bubble Grove...). Back on the island it all
-- fades back to a sunny afternoon. Purely visual and local to this player.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Effects = require(script.Parent.Effects)

local Ambience = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- clock = time of day, haze/density = atmosphere, tint = color correction, weather = particles
local MOODS = {
	island = { clock = 14.5, brightness = 2.5, density = 0.25, haze = 1, air = Color3.fromRGB(199, 199, 199), tint = Color3.new(1, 1, 1), saturation = 0.05 },
	grass = { clock = 13, brightness = 2.6, density = 0.25, haze = 1, air = Color3.fromRGB(200, 215, 200), tint = Color3.new(1, 1, 1), saturation = 0.1 },
	marine = { clock = 11, brightness = 2.8, density = 0.2, haze = 0.5, air = Color3.fromRGB(205, 220, 240), tint = Color3.fromRGB(235, 242, 255), saturation = 0 },
	town = { clock = 16.5, brightness = 2.4, density = 0.3, haze = 1.5, air = Color3.fromRGB(230, 200, 170), tint = Color3.fromRGB(255, 240, 225), saturation = 0.05 },
	beach = { clock = 12, brightness = 3, density = 0.2, haze = 0.8, air = Color3.fromRGB(210, 230, 245), tint = Color3.fromRGB(255, 250, 235), saturation = 0.15 },
	ship = { clock = 17.5, brightness = 2.2, density = 0.3, haze = 1.5, air = Color3.fromRGB(240, 190, 150), tint = Color3.fromRGB(255, 230, 210), saturation = 0.1 },
	deepsea = { clock = 12, brightness = 1.6, density = 0.45, haze = 2, air = Color3.fromRGB(60, 130, 200), tint = Color3.fromRGB(190, 225, 255), saturation = 0, weather = "bubbles" },
	snow = { clock = 10, brightness = 2.4, density = 0.4, haze = 2.5, air = Color3.fromRGB(225, 235, 250), tint = Color3.fromRGB(235, 245, 255), saturation = -0.15, weather = "snow" },
	desert = { clock = 13, brightness = 3.2, density = 0.35, haze = 2.5, air = Color3.fromRGB(240, 200, 140), tint = Color3.fromRGB(255, 235, 200), saturation = 0.1, weather = "dust" },
	jungle = { clock = 15, brightness = 2.2, density = 0.35, haze = 1.5, air = Color3.fromRGB(170, 210, 160), tint = Color3.fromRGB(235, 255, 230), saturation = 0.15, weather = "leaves" },
	sky = { clock = 12, brightness = 3.4, density = 0.15, haze = 0.3, air = Color3.fromRGB(230, 240, 255), tint = Color3.fromRGB(255, 255, 255), saturation = 0.1 },
	spooky = { clock = 0.5, brightness = 1.2, density = 0.45, haze = 2, air = Color3.fromRGB(120, 90, 150), tint = Color3.fromRGB(215, 200, 255), saturation = -0.2, weather = "mist" },
	mangrove = { clock = 14, brightness = 2.5, density = 0.3, haze = 1.2, air = Color3.fromRGB(200, 230, 210), tint = Color3.fromRGB(240, 255, 245), saturation = 0.1, weather = "bubbles" },
	prison = { clock = 20, brightness = 1.4, density = 0.4, haze = 2, air = Color3.fromRGB(150, 110, 110), tint = Color3.fromRGB(255, 220, 210), saturation = -0.15 },
	volcano = { clock = 18.5, brightness = 2, density = 0.45, haze = 2.5, air = Color3.fromRGB(200, 110, 80), tint = Color3.fromRGB(255, 215, 195), saturation = 0.05, weather = "ash" },
	wano = { clock = 16, brightness = 2.4, density = 0.3, haze = 1.5, air = Color3.fromRGB(240, 200, 215), tint = Color3.fromRGB(255, 240, 245), saturation = 0.15, weather = "petals" },
}

local WEATHER = {
	snow = { texture = SPARK, color = Color3.fromRGB(255, 255, 255), size = 0.5, rate = 120, speed = { 6, 10 }, accel = Vector3.new(2, -2, 0), down = true },
	ash = { texture = SMOKE, color = Color3.fromRGB(90, 80, 80), size = 0.6, rate = 70, speed = { 4, 7 }, accel = Vector3.new(1, -1, 0), down = true, embers = true },
	petals = { texture = SPARK, color = Color3.fromRGB(255, 170, 200), size = 0.5, rate = 50, speed = { 3, 6 }, accel = Vector3.new(3, -1, 1), down = true },
	leaves = { texture = SPARK, color = Color3.fromRGB(120, 190, 90), size = 0.45, rate = 30, speed = { 3, 5 }, accel = Vector3.new(2, -1, 0), down = true },
	dust = { texture = SMOKE, color = Color3.fromRGB(230, 200, 150), size = 2.5, rate = 25, speed = { 8, 12 }, accel = Vector3.new(10, 0, 0) },
	bubbles = { texture = SPARK, color = Color3.fromRGB(200, 240, 255), size = 0.6, rate = 40, speed = { 3, 5 }, accel = Vector3.new(0, 3, 0) },
	mist = { texture = SMOKE, color = Color3.fromRGB(170, 150, 200), size = 6, rate = 15, speed = { 1, 2 }, accel = Vector3.new(1, 0, 0) },
}

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Parent = Lighting
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "MapTint"
tint.Parent = Lighting

-- weather: an emitter on a big flat part that follows the camera
local cloud = Instance.new("Part")
cloud.Name = "Weather"
cloud.Anchored, cloud.CanCollide, cloud.CanQuery, cloud.CanTouch, cloud.CastShadow = true, false, false, false, false
cloud.Transparency = 1
cloud.Size = Vector3.new(140, 1, 140)
local emitter = Instance.new("ParticleEmitter")
emitter.Enabled = false
emitter.Parent = cloud
local current

local function setWeather(name)
	local w = WEATHER[name]
	if not w or Effects.settings.low then
		emitter.Enabled = false
		cloud.Parent = nil
		return
	end
	emitter.Texture = w.texture
	emitter.Color = ColorSequence.new(w.color)
	emitter.Size = NumberSequence.new(w.size)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Rate = w.rate
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(w.speed[1], w.speed[2])
	emitter.Acceleration = w.accel
	emitter.EmissionDirection = w.down and Enum.NormalId.Bottom or Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.LightEmission = w.embers and 0.6 or 0
	emitter.Enabled = true
	cloud.Parent = workspace
end

-- Changes the mood to a map theme ("snow", "volcano"...) or "island".
function Ambience.set(theme)
	if current == theme then
		return
	end
	current = theme
	local mood = MOODS[theme] or MOODS.island
	local info = TweenInfo.new(2)
	TweenService:Create(Lighting, info, { ClockTime = mood.clock, Brightness = mood.brightness }):Play()
	TweenService:Create(atmosphere, info, { Density = mood.density, Haze = mood.haze, Color = mood.air }):Play()
	TweenService:Create(tint, info, { TintColor = mood.tint, Saturation = mood.saturation }):Play()
	setWeather(mood.weather)
end

RunService.RenderStepped:Connect(function()
	if cloud.Parent then
		local cam = workspace.CurrentCamera.CFrame.Position
		-- bubbles and dust rise from below; everything else falls from above
		local w = WEATHER[(MOODS[current] or MOODS.island).weather]
		cloud.Position = cam + Vector3.new(0, w and not w.down and -20 or 35, 0)
	end
end)

return Ambience
