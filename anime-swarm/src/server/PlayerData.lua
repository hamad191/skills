-- Saves gold and permanent upgrades between runs.
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)

local store
pcall(function()
	store = DataStoreService:GetDataStore("AnimeSwarm_v1")
end)

local PlayerData = {}
local cache = {}

local function key(player)
	return "p_" .. player.UserId
end

function PlayerData.load(player)
	local data = { gold = 0, meta = {} }
	local saved
	if store then
		local ok, result = pcall(store.GetAsync, store, key(player))
		if ok and type(result) == "table" then
			saved = result
		end
	end
	data.gold = saved and tonumber(saved.gold) or 0
	for name in Config.Meta do
		data.meta[name] = saved and saved.meta and tonumber(saved.meta[name]) or 0
	end
	cache[player] = data
	return data
end

function PlayerData.get(player)
	return cache[player]
end

function PlayerData.save(player)
	local data = cache[player]
	if store and data then
		pcall(store.SetAsync, store, key(player), data)
	end
end

function PlayerData.release(player)
	PlayerData.save(player)
	cache[player] = nil
end

function PlayerData.metaCost(name, level)
	local meta = Config.Meta[name]
	return math.floor(meta.cost * (meta.growth or Config.META_GROWTH) ^ level)
end

function PlayerData.buy(player, name)
	local data, meta = cache[player], Config.Meta[name]
	if not data or not meta then
		return false
	end
	local level = data.meta[name]
	local cost = PlayerData.metaCost(name, level)
	if level >= meta.max or data.gold < cost then
		return false
	end
	data.gold -= cost
	data.meta[name] = level + 1
	return true
end

game:BindToClose(function()
	for player in cache do
		PlayerData.save(player)
	end
end)

return PlayerData
