-- Fame: leaderboards on the island (all-time top 10s saved in OrderedDataStores), the player
-- list's leaderstats, and a title over everyone's head from their all-time bounty.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)

local Leaderboards = {}
local stores = {} -- [stat] = OrderedDataStore
local boards = {} -- [stat] = { rows = { TextLabel } }
local names = {} -- [userId] = name
local lastSubmit = {}
local SUBMIT_EVERY = 120
local REFRESH_EVERY = 120
local ROWS = 10

for _, lb in Config.LEADERBOARDS do
	pcall(function()
		stores[lb.stat] = DataStoreService:GetOrderedDataStore("AnimeSwarm_LB_" .. lb.stat)
	end)
end

local function comma(n)
	local s = tostring(math.floor(n))
	repeat
		local count
		s, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return s
end

local function short(n)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return comma(n)
end

-- Boards ---------------------------------------------------------------------------------------

local function makePart(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanTouch = true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.fromRGB(252, 246, 230)
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function buildBoard(lb, spot, folder)
	local params = RaycastParams.new()
	local hit = workspace:Raycast(spot + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), params)
	local y = hit and hit.Position.Y or spot.Y
	local base = Vector3.new(spot.X, y, spot.Z)
	local face = Vector3.new(Config.LEADERBOARD_FACE.X, y, Config.LEADERBOARD_FACE.Z)
	local cf = CFrame.lookAt(base, face)
	local model = Instance.new("Model")
	model.Name = "Leaderboard_" .. lb.stat
	local wood, gold = Color3.fromRGB(95, 60, 32), Color3.fromRGB(214, 168, 88)
	for _, x in { -5.2, 5.2 } do
		makePart({ Size = Vector3.new(0.8, 14, 0.8), CFrame = cf * CFrame.new(x, 7, 0.4), Color = wood, Material = Enum.Material.Wood }, model)
	end
	local board = makePart({ Name = "Board", Size = Vector3.new(10, 11, 0.5), CFrame = cf * CFrame.new(0, 7.5, 0), Color = Color3.fromRGB(16, 34, 56), Material = Enum.Material.SmoothPlastic }, model)
	makePart({ Size = Vector3.new(10.6, 0.4, 0.7), CFrame = cf * CFrame.new(0, 13.2, 0), Color = gold, Material = Enum.Material.Metal }, model)
	makePart({ Size = Vector3.new(10.6, 0.4, 0.7), CFrame = cf * CFrame.new(0, 1.8, 0), Color = gold, Material = Enum.Material.Metal }, model)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 440)
	gui.LightInfluence = 0
	gui.Parent = board
	label(gui, { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 8), Text = lb.icon .. " " .. lb.title, Font = Enum.Font.LuckiestGuy, TextColor3 = Color3.fromRGB(255, 200, 70) })
	local rows = {}
	for i = 1, ROWS do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -24, 0, 34)
		row.Position = UDim2.fromOffset(12, 62 + (i - 1) * 37)
		row.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(28, 54, 84) or Color3.fromRGB(22, 44, 70)
		row.BorderSizePixel = 0
		row.Parent = gui
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local medal = i == 1 and "🥇" or i == 2 and "🥈" or i == 3 and "🥉" or "#" .. i
		label(row, { Size = UDim2.new(0, 46, 1, -6), Position = UDim2.fromOffset(4, 3), Text = medal })
		local name = label(row, { Size = UDim2.new(1, -170, 1, -8), Position = UDim2.fromOffset(54, 4), Text = "-", TextXAlignment = Enum.TextXAlignment.Left })
		local value = label(row, { Size = UDim2.new(0, 110, 1, -8), Position = UDim2.new(1, -116, 0, 4), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 200, 70) })
		rows[i] = { name = name, value = value }
	end
	boards[lb.stat] = { rows = rows }
	model.Parent = folder
end

function Leaderboards.build()
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = workspace
	for i, lb in Config.LEADERBOARDS do
		local spot = Config.LEADERBOARD_SPOTS[i]
		if spot then
			buildBoard(lb, spot, folder)
		end
	end
end

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or "Pirate"
	return names[userId]
end

function Leaderboards.refresh()
	for stat, board in boards do
		local store = stores[stat]
		local ok, pages = false, nil
		if store then
			ok, pages = pcall(store.GetSortedAsync, store, false, ROWS)
		end
		local entries = ok and pages:GetCurrentPage() or {}
		for i, row in board.rows do
			local entry = entries[i]
			if entry then
				row.name.Text = nameOf(tonumber(entry.key) or 0)
				row.value.Text = short(entry.value)
			else
				row.name.Text = ok and "-" or (i == 1 and "Loading..." or "-")
				row.value.Text = ""
			end
		end
	end
end

-- Saves a player's all-time stats to the boards (at most every couple of minutes).
function Leaderboards.submit(player, stats, force)
	local now = os.clock()
	if not force and now - (lastSubmit[player] or 0) < SUBMIT_EVERY then
		return
	end
	lastSubmit[player] = now
	local userId = player.UserId
	task.spawn(function()
		for stat, store in stores do
			local value = math.floor(stats[stat] or 0)
			if value > 0 then
				-- never lower a saved score (e.g. if this visit's save failed to load)
				pcall(store.UpdateAsync, store, tostring(userId), function(old)
					return math.max(tonumber(old) or 0, value)
				end)
			end
		end
	end)
end

-- Player list and titles -----------------------------------------------------------------------

function Leaderboards.titleFor(bounty)
	local best = Config.TITLES[1]
	for _, t in Config.TITLES do
		if bounty >= t.bounty then
			best = t
		end
	end
	return best
end

function Leaderboards.setup(player, stats)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local bounty = Instance.new("IntValue")
	bounty.Name = "💰 Bounty"
	bounty.Parent = folder
	local kills = Instance.new("IntValue")
	kills.Name = "☠️ Kills"
	kills.Parent = folder
	folder.Parent = player
	Leaderboards.update(player, stats)
end

function Leaderboards.update(player, stats)
	local folder = player:FindFirstChild("leaderstats")
	if folder then
		folder["💰 Bounty"].Value = math.floor(stats.gold or 0)
		folder["☠️ Kills"].Value = math.floor(stats.kills or 0)
	end
	Leaderboards.submit(player, stats)
end

-- A title and bounty over the character's head ("Supernova  💰 52.3K").
function Leaderboards.tag(character, stats)
	local head = character:WaitForChild("Head", 5)
	if not head then
		return
	end
	local old = head:FindFirstChild("TitleTag")
	if old then
		old:Destroy()
	end
	local bounty = stats.gold or 0
	local title = Leaderboards.titleFor(bounty)
	local tag = Instance.new("BillboardGui")
	tag.Name = "TitleTag"
	tag.Size = UDim2.fromOffset(160, 40)
	tag.StudsOffset = Vector3.new(0, 5, 0) -- above the name and the VIP tag
	tag.MaxDistance = 70
	tag.LightInfluence = 0
	tag.Parent = head
	label(tag, { Size = UDim2.new(1, 0, 0.55, 0), Text = title.title, Font = Enum.Font.LuckiestGuy, TextColor3 = title.color, TextStrokeTransparency = 0.2 })
	label(tag, { Size = UDim2.new(1, 0, 0.45, 0), Position = UDim2.fromScale(0, 0.55), Text = "💰 " .. short(bounty), TextColor3 = Color3.fromRGB(255, 220, 120), TextStrokeTransparency = 0.3 })
end

function Leaderboards.release(player)
	lastSubmit[player] = nil
end

task.spawn(function()
	task.wait(5)
	while true do
		Leaderboards.refresh()
		task.wait(REFRESH_EVERY)
	end
end)

return Leaderboards
