-- Queues visual effects and sends them to clients once per frame.
-- The server only decides what happened; clients draw it (see client/Effects.lua).
-- Each player only gets the effects happening near them: a crew on another map, or players on
-- the island, never receive this arena's lasers and damage numbers.
local Players = game:GetService("Players")

local Fx = {}
local queue = {}
local remote
local RANGE = 650 -- arenas are 1200 studs apart, so this never reaches another map

function Fx.init(r)
	remote = r
end

function Fx.emit(kind, data)
	data.k = kind
	table.insert(queue, data)
end

-- Where an effect happens (nil = send it to everyone, e.g. "this bullet is gone").
local function where(ev)
	if ev.pos then
		return ev.pos
	elseif ev.o then
		return ev.o
	end
	local character = ev.p and ev.p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	local hit = ev.hits and ev.hits[1]
	return hit and hit[1]
end

function Fx.flush()
	if #queue == 0 then
		return
	end
	local players = Players:GetPlayers()
	local spots = {}
	for _, player in players do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		spots[player] = root and root.Position
	end
	local batches = {}
	for _, ev in queue do
		local pos = where(ev)
		for _, player in players do
			local spot = spots[player]
			if not pos or not spot or (spot - pos).Magnitude <= RANGE then
				local batch = batches[player]
				if not batch then
					batch = {}
					batches[player] = batch
				end
				table.insert(batch, ev)
			end
		end
	end
	for player, batch in batches do
		remote:FireClient(player, batch)
	end
	queue = {}
end

return Fx
