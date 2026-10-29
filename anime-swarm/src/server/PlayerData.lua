-- Saves gold, unlocked pirates, upgrades, training, gear, map progress, purchases, lifetime
-- stats, daily rewards and quests, redeemed codes, achievements, settings and the tutorial.
-- Safety rules:
--   * every write uses UpdateAsync with a session lock, so two servers never overwrite each other
--   * failed loads are retried; if a save still can't be read, this session never saves for that
--     player (saving defaults would wipe their real data)
--   * everyone autosaves every couple of minutes and when the server shuts down
--   * changes ask for a save (requestSave); several in a row become one write, and only one
--     write per player runs at a time, staying under Roblox's DataStore limits
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)

local store
pcall(function()
	store = DataStoreService:GetDataStore("AnimeSwarm_v1")
end)

local PlayerData = {}
local cache = {}
local LOCK_TIMEOUT = 600 -- seconds before a crashed server's lock is ignored
local AUTOSAVE_EVERY = 120
local MAX_RECEIPTS = 100
local SAVE_GAP = 8 -- seconds between requested saves for one player
local STATS = {
	"kills", "wins", "runs", "gold", "bosses", "minibosses", "chests", "pickups", "revives", "wave", "level",
	"endless", "raids", "rebirths",
}
local QUEST_BY_ID = {}
for _, q in Config.QUESTS do
	QUEST_BY_ID[q.id] = q
end
local saving, dirty, lastSave = {}, {}, {}

local function key(player)
	return "p_" .. player.UserId
end

local function num(v)
	if type(v) == "number" then
		return v
	end
	return type(v) == "string" and tonumber(v) or nil
end

local function fresh()
	return {
		gold = 0, meta = {}, progress = {}, mastery = {}, training = {}, items = {}, equipped = {},
		gearLevels = {}, gearCopies = {}, classes = { [Config.DEFAULT_CLASS] = true }, revives = 0, boosts = {}, receipts = {},
		stats = {}, daily = { day = 0, streak = 0 }, quests = { day = 0, list = {} }, codes = {}, badges = {},
		settings = { music = 0.5, sfx = 0.8, numbers = true, shake = true, low = false }, tutorial = false,
	}
end

-- Copies only known fields from a saved table, checking every type.
local function clean(saved)
	local data = fresh()
	if type(saved) ~= "table" then
		return data
	end
	local function section(name)
		return type(saved[name]) == "table" and saved[name] or {}
	end
	data.gold = math.max(0, math.floor(num(saved.gold) or 0))
	data.revives = math.max(0, math.floor(num(saved.revives) or 0))
	for name, m in Config.Meta do
		data.meta[name] = math.clamp(math.floor(num(section("meta")[name]) or 0), 0, m.max)
	end
	for _, map in Config.Maps do
		local cleared = num(section("progress")[map.key])
		if cleared and cleared > 0 then
			data.progress[map.key] = math.clamp(math.floor(cleared), 0, #Config.Difficulties)
		end
	end
	for skill, level in section("mastery") do
		if Config.Weapons[skill] and num(level) then
			data.mastery[skill] = math.clamp(math.floor(num(level)), 0, Config.MASTERY.max)
		end
	end
	for passive, level in section("training") do
		if Config.Passives[passive] and num(level) then
			data.training[passive] = math.clamp(math.floor(num(level)), 0, Config.TRAINING.max)
		end
	end
	for id in section("items") do
		if Config.GearById[id] then
			data.items[id] = true
		end
	end
	for name in section("classes") do
		if Config.Classes[name] then
			data.classes[name] = true
		end
	end
	for id, level in section("gearLevels") do
		if data.items[id] and num(level) then
			data.gearLevels[id] = math.clamp(math.floor(num(level)), 0, Config.GEAR_UPGRADE.max)
		end
	end
	for id, copies in section("gearCopies") do
		if data.items[id] and num(copies) then
			data.gearCopies[id] = math.max(0, math.floor(num(copies)))
		end
	end
	for slot, id in section("equipped") do
		local item = Config.GearById[id]
		if item and item.slot == slot and data.items[id] then
			data.equipped[slot] = id
		end
	end
	for boost, untilTime in section("boosts") do
		if (boost == "xp" or boost == "gold") and num(untilTime) then
			data.boosts[boost] = num(untilTime)
		end
	end
	for _, stat in STATS do
		local value = num(section("stats")[stat])
		if value and value > 0 then
			data.stats[stat] = math.floor(value)
		end
	end
	local daily = section("daily")
	data.daily.day = math.floor(num(daily.day) or 0)
	data.daily.streak = math.clamp(math.floor(num(daily.streak) or 0), 0, 100000)
	local quests = section("quests")
	data.quests.day = math.floor(num(quests.day) or 0)
	for _, q in type(quests.list) == "table" and quests.list or {} do
		if type(q) == "table" and QUEST_BY_ID[q.id] and #data.quests.list < Config.QUESTS_PER_DAY then
			table.insert(data.quests.list, {
				id = q.id, progress = math.clamp(math.floor(num(q.progress) or 0), 0, QUEST_BY_ID[q.id].goal), claimed = q.claimed == true,
			})
		end
	end
	for code in section("codes") do
		if Config.CODES[code] then
			data.codes[code] = true
		end
	end
	for key in section("badges") do
		if Config.BADGES[key] then
			data.badges[key] = true
		end
	end
	local settings = section("settings")
	for _, key in { "music", "sfx" } do
		if num(settings[key]) then
			data.settings[key] = math.clamp(num(settings[key]), 0, 1)
		end
	end
	for _, key in { "numbers", "shake", "low" } do
		if type(settings[key]) == "boolean" then
			data.settings[key] = settings[key]
		end
	end
	data.tutorial = saved.tutorial == true
	-- keep the newest receipts so repeat deliveries of a purchase are ignored
	local receipts = {}
	for id, time in section("receipts") do
		table.insert(receipts, { id = id, time = num(time) or 0 })
	end
	table.sort(receipts, function(a, b)
		return a.time > b.time
	end)
	for i = 1, math.min(#receipts, MAX_RECEIPTS) do
		data.receipts[receipts[i].id] = receipts[i].time
	end
	return data
end

-- Loads a player's save and takes the session lock. Retries while another server still holds
-- the lock (they may be saving as the player teleports over) or the DataStore is busy.
function PlayerData.load(player)
	local data
	if store then
		local attempts = RunService:IsStudio() and 1 or 5
		for attempt = 1, attempts do
			local ok, result = pcall(store.UpdateAsync, store, key(player), function(old)
				if type(old) == "table" and old.lock and old.lock ~= game.JobId and os.time() - (num(old.lockTime) or 0) < LOCK_TIMEOUT then
					return nil -- another server still has this player
				end
				old = type(old) == "table" and old or {}
				old.lock, old.lockTime = game.JobId, os.time()
				return old
			end)
			if ok and type(result) == "table" and result.lock == game.JobId then
				data = clean(result)
				break
			end
			if not ok then
				warn("Couldn't load data for " .. player.Name .. ": " .. tostring(result))
			end
			if not player.Parent then
				return nil
			end
			if attempt < attempts then
				task.wait(attempt * 1.5)
			end
		end
	end
	if not data then
		data = fresh()
		data.loadFailed = store ~= nil -- never save over a save we couldn't read
	end
	cache[player] = data
	return data
end

function PlayerData.get(player)
	return cache[player]
end

-- Writes the player's data. release = true also frees the session lock (when they leave).
-- Returns true if the save went through.
function PlayerData.save(player, release)
	local data = cache[player]
	if not store or not data or data.loadFailed then
		return false
	end
	-- one write per player at a time: wait for a running one to finish
	while saving[player] do
		task.wait(0.1)
	end
	saving[player] = true
	dirty[player] = nil
	lastSave[player] = os.clock()
	local wrote = false
	local ok = pcall(store.UpdateAsync, store, key(player), function(old)
		if type(old) == "table" and old.lock and old.lock ~= game.JobId then
			return nil -- another server took this player over: don't overwrite them
		end
		local out = {}
		for k, v in data do
			out[k] = v
		end
		out.loadFailed = nil
		out.lock = not release and game.JobId or nil
		out.lockTime = os.time()
		wrote = true
		return out
	end)
	saving[player] = nil
	return ok and wrote
end

-- Asks for a save soon. Several changes in a row become one write.
function PlayerData.requestSave(player)
	if cache[player] and not cache[player].loadFailed then
		dirty[player] = true
	end
end

function PlayerData.release(player)
	PlayerData.save(player, true)
	cache[player] = nil
	dirty[player], lastSave[player] = nil, nil
end

-- Permanent upgrades ----------------------------------------------------------------------

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

-- Captain Grey's skill mastery ("skill") and Granny Doc's passive training ("passive").
function PlayerData.train(player, kind, name)
	local data = cache[player]
	local known = kind == "skill" and Config.Weapons[name] and not Config.Weapons[name].evolved
		or kind == "passive" and Config.Passives[name]
	if not data or not known then
		return false
	end
	local levels = kind == "skill" and data.mastery or data.training
	local max = kind == "skill" and Config.MASTERY.max or Config.TRAINING.max
	local level = levels[name] or 0
	local cost = Config.trainCost(kind, level)
	if level >= max or data.gold < cost then
		return false
	end
	data.gold -= cost
	levels[name] = level + 1
	return true
end

-- Pirates ---------------------------------------------------------------------------------

function PlayerData.hasClass(player, name)
	local data = cache[player]
	return data ~= nil and data.classes[name] == true
end

function PlayerData.unlockClass(player, name)
	local data, class = cache[player], Config.Classes[name]
	if not data or not class or data.classes[name] or data.gold < class.cost then
		return false
	end
	data.gold -= class.cost
	data.classes[name] = true
	return true
end

-- Gear ------------------------------------------------------------------------------------

function PlayerData.buyGear(player, id)
	local data, item = cache[player], Config.GearById[id]
	if not data or not item or item.cost <= 0 or data.items[id] or data.gold < item.cost then
		return false
	end
	data.gold -= item.cost
	data.items[id] = true
	data.equipped[item.slot] = data.equipped[item.slot] or id
	return true
end

function PlayerData.equipGear(player, id)
	local data, item = cache[player], Config.GearById[id]
	if not data or not item or not data.items[id] then
		return false
	end
	data.equipped[item.slot] = data.equipped[item.slot] ~= id and id or nil -- equipping again takes it off
	return true
end

-- Upgrades an owned item one level at Hammond's: costs one duplicate copy of it plus gold.
function PlayerData.upgradeGear(player, id)
	local data, item = cache[player], Config.GearById[id]
	if not data or not item or not data.items[id] then
		return false
	end
	local level = data.gearLevels[id] or 0
	local cost = Config.gearUpgradeCost(item, level)
	if level >= Config.GEAR_UPGRADE.max or (data.gearCopies[id] or 0) < 1 or data.gold < cost then
		return false
	end
	data.gold -= cost
	data.gearCopies[id] -= 1
	data.gearLevels[id] = level + 1
	return true
end

-- Gives a dropped item. Returns "new", "copy" (already owned: a spare copy to upgrade it with)
-- or "gold" (already owned and maxed: the caller pays out Config.DUPLICATE_GOLD).
function PlayerData.grantItem(player, id)
	local data = cache[player]
	if not data then
		return nil
	end
	if not data.items[id] then
		data.items[id] = true
		return "new"
	end
	-- copies beyond what reaching +10 needs are paid out as gold
	local needed = Config.GEAR_UPGRADE.max - (data.gearLevels[id] or 0)
	if (data.gearCopies[id] or 0) < needed then
		data.gearCopies[id] = (data.gearCopies[id] or 0) + 1
		return "copy"
	end
	return "gold"
end

-- All stat bonuses from the player's equipped gear.
function PlayerData.gearBonus(player)
	local bonus = {}
	local data = cache[player]
	for _, id in data and data.equipped or {} do
		for stat, value in Config.gearStats(Config.GearById[id], data.gearLevels[id]) do
			bonus[stat] = (bonus[stat] or 0) + value
		end
	end
	return bonus
end

-- Maps ------------------------------------------------------------------------------------

function PlayerData.unlocked(player, mapKey, difficulty)
	local data, map = cache[player], Config.MapByKey[mapKey]
	return data ~= nil and map ~= nil and Config.Difficulties[difficulty] ~= nil
		and Config.unlocked(data.progress, map, difficulty)
end

-- Records a cleared difficulty. Returns true if it was a new best for that map.
function PlayerData.recordClear(player, mapKey, difficulty)
	local data = cache[player]
	if data and difficulty > (data.progress[mapKey] or 0) then
		data.progress[mapKey] = difficulty
		return true
	end
	return false
end

-- Stats, quests and daily rewards -------------------------------------------------------------

function PlayerData.today()
	return math.floor(os.time() / 86400) -- days since 1970 (UTC)
end

-- Today's quests, picking new ones when the day changes.
function PlayerData.quests(player)
	local data = cache[player]
	if not data then
		return {}
	end
	local today = PlayerData.today()
	if data.quests.day ~= today then
		local pool = table.clone(Config.QUESTS)
		local list = {}
		for _ = 1, math.min(Config.QUESTS_PER_DAY, #pool) do
			local q = table.remove(pool, math.random(#pool))
			table.insert(list, { id = q.id, progress = 0, claimed = false })
		end
		data.quests = { day = today, list = list }
	end
	return data.quests.list
end

function PlayerData.questDef(id)
	return QUEST_BY_ID[id]
end

-- Adds to a lifetime stat (kills, wins...) and to today's quests that count it.
function PlayerData.addStat(player, stat, amount)
	local data = cache[player]
	if not data then
		return
	end
	data.stats[stat] = (data.stats[stat] or 0) + amount
	for _, q in PlayerData.quests(player) do
		local def = QUEST_BY_ID[q.id]
		if def.stat == stat and not def.max then
			q.progress = math.min(def.goal, q.progress + amount)
		end
	end
end

-- Records a best-in-one-run value (highest wave, highest level).
function PlayerData.bestStat(player, stat, value)
	local data = cache[player]
	if not data then
		return
	end
	data.stats[stat] = math.max(data.stats[stat] or 0, value)
	for _, q in PlayerData.quests(player) do
		local def = QUEST_BY_ID[q.id]
		if def.stat == stat and def.max then
			q.progress = math.min(def.goal, math.max(q.progress, value))
		end
	end
end

-- Pays out a finished quest. Returns the gold, or nil.
function PlayerData.claimQuest(player, index)
	local data = cache[player]
	local q = data and PlayerData.quests(player)[index]
	local def = q and QUEST_BY_ID[q.id]
	if not def or q.claimed or q.progress < def.goal then
		return nil
	end
	q.claimed = true
	data.gold += def.gold
	data.stats.gold = (data.stats.gold or 0) + def.gold
	return def.gold
end

-- The daily login reward: which day of the streak is next and whether it can be claimed today.
function PlayerData.daily(player)
	local data = cache[player]
	if not data then
		return { canClaim = false, streak = 0, index = 1 }
	end
	local today, d = PlayerData.today(), data.daily
	if d.day == today then
		return { canClaim = false, streak = d.streak, index = math.min(math.max(d.streak, 1), #Config.DAILY_REWARDS) }
	end
	local streak = d.day == today - 1 and d.streak + 1 or 1
	return { canClaim = true, streak = streak, index = math.min(streak, #Config.DAILY_REWARDS) }
end

function PlayerData.claimDaily(player)
	local data = cache[player]
	local info = PlayerData.daily(player)
	if not data or not info.canClaim then
		return nil
	end
	data.daily = { day = PlayerData.today(), streak = info.streak }
	local reward = Config.DAILY_REWARDS[info.index]
	data.gold += reward.gold
	data.stats.gold = (data.stats.gold or 0) + reward.gold
	data.revives += reward.revives or 0
	return reward
end

-- Redeems a code once. Returns the reward, or nil and why not.
function PlayerData.redeem(player, code)
	local data = cache[player]
	code = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.CODES[code]
	if not data or not reward then
		return nil, "That code doesn't exist (or has expired)."
	elseif data.codes[code] then
		return nil, "You already redeemed that code."
	end
	data.codes[code] = true
	data.gold += reward.gold or 0
	data.revives += reward.revives or 0
	return reward
end

-- Marks an achievement as earned. Returns true the first time.
function PlayerData.earn(player, key)
	local data = cache[player]
	if not data or data.badges[key] then
		return false
	end
	data.badges[key] = true
	return true
end

function PlayerData.setSettings(player, settings)
	local data = cache[player]
	if not data or type(settings) ~= "table" then
		return
	end
	for _, key in { "music", "sfx" } do
		if type(settings[key]) == "number" and settings[key] == settings[key] then
			data.settings[key] = math.clamp(settings[key], 0, 1)
		end
	end
	for _, key in { "numbers", "shake", "low" } do
		if type(settings[key]) == "boolean" then
			data.settings[key] = settings[key]
		end
	end
end

-- Rebirth ------------------------------------------------------------------------------------

function PlayerData.rebirthCost(rebirths)
	return math.floor(Config.REBIRTH.cost * Config.REBIRTH.growth ^ rebirths)
end

-- Starts over for a permanent bonus: resets gold, shop upgrades and training. Returns the new
-- rebirth count, or nil if the player can't afford it.
function PlayerData.rebirth(player)
	local data = cache[player]
	if not data then
		return nil
	end
	local count = data.stats.rebirths or 0
	if count >= Config.REBIRTH.max or data.gold < PlayerData.rebirthCost(count) then
		return nil
	end
	data.gold = 0
	for name in Config.Meta do
		data.meta[name] = 0
	end
	data.mastery, data.training = {}, {}
	data.stats.rebirths = count + 1
	return count + 1
end

-- Finishes the first-time guide. Returns true the first time.
function PlayerData.finishTutorial(player)
	local data = cache[player]
	if not data or data.tutorial then
		return false
	end
	data.tutorial = true
	return true
end

function PlayerData.boostActive(player, boost)
	local data = cache[player]
	return data ~= nil and (data.boosts[boost] or 0) > os.time()
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_EVERY)
		for player in cache do
			task.spawn(PlayerData.save, player)
		end
	end
end)

-- requested saves, at most one every SAVE_GAP seconds per player
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for player in dirty do
			if not saving[player] and now - (lastSave[player] or 0) >= SAVE_GAP then
				task.spawn(PlayerData.save, player)
			end
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in cache do
		pending += 1
		task.spawn(function()
			PlayerData.save(player, true)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end)

return PlayerData
