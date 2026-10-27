-- Client entry point: builds the UI and connects it to the server's remotes.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local remotes = RS:WaitForChild("Remotes")
local player = Players.LocalPlayer
local Effects = require(script.Parent:WaitForChild("Effects"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Lobby = require(script.Parent:WaitForChild("Lobby"))

-- our own health bar replaces the default one
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SwarmUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

Hud.init(gui, {
	choose = function(i)
		remotes.Choose:FireServer(i)
	end,
	reroll = function()
		remotes.Reroll:FireServer()
	end,
})
Lobby.init(gui, {
	selectClass = function(name)
		remotes.SelectClass:FireServer(name)
	end,
	buy = function(name)
		remotes.BuyMeta:FireServer(name)
	end,
})

remotes.Fx.OnClientEvent:Connect(function(list)
	for _, ev in list do
		Effects.play(ev)
	end
end)
remotes.Stats.OnClientEvent:Connect(Hud.setStats)
remotes.LevelUp.OnClientEvent:Connect(Hud.showLevelUp)
remotes.Announce.OnClientEvent:Connect(Hud.announce)
remotes.Results.OnClientEvent:Connect(Hud.showResults)
remotes.Meta.OnClientEvent:Connect(Lobby.setMeta)
remotes.Portal.OnClientEvent:Connect(Lobby.portal)

remotes.State.OnClientEvent:Connect(function(state)
	local running = state.phase == "Run"
	if not running then
		Effects.clear()
	end
	Hud.setVisible(running)
	Hud.setState(state)
	Lobby.setVisible(state.phase == "Lobby")
end)

local KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }
UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if KEYS[input.KeyCode] then
		Hud.choose(KEYS[input.KeyCode])
	elseif input.KeyCode == Enum.KeyCode.R then
		Hud.reroll()
	end
end)

remotes.Meta:FireServer()
