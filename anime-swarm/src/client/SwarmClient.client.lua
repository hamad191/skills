-- Client entry point: builds the UI, connects it to the server's remotes, and handles dashing,
-- NPC prompts, Robux purchase prompts and watching teammates while knocked out.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")

local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = RS:WaitForChild("Remotes")
local player = Players.LocalPlayer
local Theme = require(script.Parent:WaitForChild("Theme"))
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
-- everything lives in one root that scales to fit the screen (phones included)
local root = Theme.new("Frame", { Name = "Root", BackgroundTransparency = 1 }, gui)
Theme.autoScale(root)

-- Dash ------------------------------------------------------------------------------------

local dashCooldown = Config.DASH.cooldown
local dashReadyAt = 0

local function dash()
	local character = player.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not body or not hum or hum.Health <= 0 or os.clock() < dashReadyAt then
		return
	end
	dashReadyAt = os.clock() + dashCooldown
	local dir = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection or body.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	-- a short, strong push in the move direction (the client owns its character's physics)
	local attachment = Instance.new("Attachment")
	attachment.Parent = body
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.MaxForce = math.huge
	push.VectorVelocity = dir * Config.DASH.speed
	push.Parent = body
	Debris:AddItem(push, Config.DASH.duration)
	Debris:AddItem(attachment, Config.DASH.duration)
	remotes.Dash:FireServer()
	Hud.dashUsed(dashCooldown)
end

-- Shift / gamepad L2, plus an on-screen button on touch devices
ContextActionService:BindAction("Dash", function(_, state)
	if state == Enum.UserInputState.Begin then
		dash()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL2)
ContextActionService:SetTitle("Dash", "DASH")

-- Watching teammates while knocked out ------------------------------------------------------

local crew = {} -- UserIds of this run's crew, from the latest State
local watchIndex = 0
local wasDown = false

local function standingCrew()
	local list = {}
	for _, userId in crew do
		local mate = Players:GetPlayerByUserId(userId)
		local hum = mate and mate ~= player and mate.Character and mate.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			table.insert(list, { player = mate, hum = hum })
		end
	end
	return list
end

local function spectate(step)
	local list = standingCrew()
	if #list == 0 then
		Hud.setWatching(nil)
		return
	end
	watchIndex = (watchIndex + step - 1) % #list + 1
	workspace.CurrentCamera.CameraSubject = list[watchIndex].hum
	Hud.setWatching(list[watchIndex].player.DisplayName)
end

local function stopSpectating()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		workspace.CurrentCamera.CameraSubject = hum
	end
end

-- Purchases -------------------------------------------------------------------------------

local function buyPass(key)
	local pass = Config.GAME_PASSES[key]
	if pass and pass.id > 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	end
end

local function buyProduct(key)
	local product = Config.PRODUCTS[key]
	if product and product.id > 0 then
		MarketplaceService:PromptProductPurchase(player, product.id)
	end
end

-- Robux prices shown in the store
for key, pass in Config.GAME_PASSES do
	if pass.id > 0 then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, pass.id, Enum.InfoType.GamePass)
			if ok and info and info.PriceInRobux then
				Lobby.setPrice("pass", key, info.PriceInRobux)
			end
		end)
	end
end
for key, product in Config.PRODUCTS do
	if product.id > 0 then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, product.id, Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then
				Lobby.setPrice("product", key, info.PriceInRobux)
			end
		end)
	end
end

-- UI --------------------------------------------------------------------------------------

Hud.init(root, {
	choose = function(i)
		remotes.Choose:FireServer(i)
	end,
	reroll = function()
		remotes.Reroll:FireServer()
	end,
	dash = dash,
	leave = function()
		remotes.Leave:FireServer()
	end,
	spectate = spectate,
	revive = function(owned)
		if owned > 0 then
			remotes.Revive:FireServer()
		else
			buyProduct("Revive")
		end
	end,
})
Lobby.init(root, {
	selectClass = function(name)
		remotes.SelectClass:FireServer(name)
	end,
	buy = function(name)
		remotes.BuyMeta:FireServer(name)
	end,
	voyage = function(mapKey, difficulty)
		remotes.Voyage:FireServer(mapKey, difficulty)
	end,
	train = function(kind, name)
		remotes.Train:FireServer(kind, name)
	end,
	gear = function(action, id)
		remotes.Gear:FireServer(action, id)
	end,
	buyPass = buyPass,
	buyProduct = buyProduct,
})

-- island NPCs open their menus
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local panel = prompt:GetAttribute("Panel")
	if panel then
		Lobby.open(panel, prompt:GetAttribute("Tab"))
	end
end)

remotes.Fx.OnClientEvent:Connect(function(list)
	for _, ev in list do
		Effects.play(ev)
	end
end)
remotes.Stats.OnClientEvent:Connect(Hud.setStats)
remotes.LevelUp.OnClientEvent:Connect(Hud.showLevelUp)
remotes.Announce.OnClientEvent:Connect(Hud.announce)
remotes.Results.OnClientEvent:Connect(Hud.showResults)
remotes.Portal.OnClientEvent:Connect(Lobby.portal)
remotes.Meta.OnClientEvent:Connect(function(data)
	dashCooldown = data.dashCooldown or Config.DASH.cooldown
	Hud.setRevives(data.revives or 0)
	Lobby.setMeta(data)
end)

remotes.State.OnClientEvent:Connect(function(state)
	local running = state.phase == "Run"
	if not running then
		Effects.clear()
	end
	crew = state.crew or crew
	local down = running and state.down == true
	if down and not wasDown then
		watchIndex = 0
		spectate(1)
	elseif down then
		-- keep watching someone who is still standing
		local subject = workspace.CurrentCamera.CameraSubject
		if not subject or not subject:IsA("Humanoid") or subject.Health <= 0 or subject.Parent == player.Character then
			spectate(1)
		end
	elseif wasDown then
		stopSpectating()
	end
	wasDown = down
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
