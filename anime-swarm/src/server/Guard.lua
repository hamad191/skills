-- Light anti-cheat:
--   * movement: characters moving faster than their walk speed allows (with room for a dash)
--     are pulled back to their last good spot. Server teleports call Guard.allowTeleport first.
--   * requests: each player can only send each kind of request a few times a second.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)

local Guard = {}
local spots = {} -- [player] = { pos, time }
local freeUntil = {} -- [player] = os.clock() until which big moves are allowed (server teleports)
local dashedAt = {} -- [player] = os.clock() of their last dash
local buckets = {} -- [player] = { [key] = { tokens, time } }

-- The server is about to move this player (arena drop, revive, respawn).
function Guard.allowTeleport(player, seconds)
	freeUntil[player] = os.clock() + (seconds or 3)
	spots[player] = nil
end

function Guard.dashed(player)
	dashedAt[player] = os.clock()
end

-- Rate limit: true if `player` may send another `key` request (perSecond on average, bursts ok).
function Guard.allow(player, key, perSecond)
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local now = os.clock()
	local b = mine[key]
	if not b then
		b = { tokens = perSecond * 2, time = now }
		mine[key] = b
	end
	b.tokens = math.min(perSecond * 2, b.tokens + (now - b.time) * perSecond)
	b.time = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- Wraps a remote handler with a rate limit.
function Guard.limit(key, perSecond, handler)
	return function(player, ...)
		if Guard.allow(player, key, perSecond) then
			handler(player, ...)
		end
	end
end

local function check(player, now)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		spots[player] = nil
		return
	end
	local last = spots[player]
	if (freeUntil[player] or 0) > now or not last or last.root ~= root then
		spots[player] = { pos = root.Position, time = now, root = root } -- a new body starts fresh
		return
	end
	local rules = Config.MOVE_CHECK
	local dt = now - last.time
	local moved = Vector3.new(root.Position.X - last.pos.X, 0, root.Position.Z - last.pos.Z).Magnitude
	local allowed = hum.WalkSpeed * rules.slack * dt + rules.extra
	if now - (dashedAt[player] or 0) < dt + 0.5 then
		allowed += rules.dash
	end
	if moved > allowed and (last.strikes or 0) >= 1 then
		-- too fast twice in a row: back to the spot before it started
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(CFrame.new(last.good) * root.CFrame.Rotation)
		spots[player] = { pos = last.good, time = now, root = root, strikes = 0 }
	elseif moved > allowed then
		-- one fast burst can be a dash that reached the server late: allow it once
		spots[player] = { pos = root.Position, time = now, root = root, strikes = 1, good = last.pos }
	else
		spots[player] = { pos = root.Position, time = now, root = root, strikes = 0 }
	end
end

task.spawn(function()
	while true do
		task.wait(Config.MOVE_CHECK.every)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			check(player, now)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	spots[player], freeUntil[player], dashedAt[player], buckets[player] = nil, nil, nil, nil
end)

return Guard
