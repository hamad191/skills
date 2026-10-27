local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Skills = require(RS.Shared.SkillConfig)
local useSkill = RS:WaitForChild("UseSkill")
local waveInfo = RS:WaitForChild("WaveInfo")
local buyDamage = RS:WaitForChild("BuyDamage")

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven }

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.Size, banner.Position = UDim2.new(0, 360, 0, 50), UDim2.new(0.5, -180, 0, 10)
banner.BackgroundTransparency, banner.TextColor3 = 0.4, Color3.new(1, 1, 1)
banner.TextScaled, banner.Font = true, Enum.Font.GothamBold
banner.Parent = gui
waveInfo.OnClientEvent:Connect(function(wave, text)
	banner.Text = ("Wave %d - %s"):format(wave, text)
end)

local buttons, readyAt = {}, {}
for i, s in Skills do
	local b = Instance.new("TextButton")
	b.Size, b.Position = UDim2.new(0, 110, 0, 60), UDim2.new(0.5, -420 + (i - 1) * 120, 1, -80)
	b.BackgroundColor3, b.TextColor3 = s.color, Color3.new(0, 0, 0)
	b.TextWrapped, b.Font = true, Enum.Font.GothamBold
	b.Text = ("[%d] %s"):format(i, s.name)
	b.Parent = gui
	buttons[i], readyAt[i] = b, 0
end

local function cast(i)
	local s = Skills[i]
	if not s or os.clock() < readyAt[i] then return end
	readyAt[i] = os.clock() + s.cooldown
	useSkill:FireServer(i)
	task.spawn(function()
		while os.clock() < readyAt[i] do
			buttons[i].Text = ("%.1fs"):format(readyAt[i] - os.clock())
			task.wait(0.1)
		end
		buttons[i].Text = ("[%d] %s"):format(i, s.name)
	end)
end

for i, b in buttons do b.Activated:Connect(function() cast(i) end) end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	for i, key in KEYS do
		if input.KeyCode == key then cast(i) end
	end
	if input.KeyCode == Enum.KeyCode.U then buyDamage:FireServer() end -- upgrade damage
end)
