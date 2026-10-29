-- Daily login rewards, daily quests, codes, achievements (Roblox badges when their IDs are set)
-- and the first-time guide. Stats from adventures come in through Rewards.stat / Rewards.best.
local BadgeService = game:GetService("BadgeService")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Leaderboards = require(script.Parent.Leaderboards)

local Rewards = {}
local remotes
local onChanged = function(_player) end
local TUTORIAL_GOLD = 1000

local function tell(player, text, color)
	remotes.Announce:FireClient(player, text, color)
end

-- Achievements --------------------------------------------------------------------------------

-- Earns an achievement once: a toast in game, plus the Roblox badge if its ID is set.
function Rewards.achieve(player, key)
	local badge = Config.BADGES[key]
	if not badge or not PlayerData.earn(player, key) then
		return
	end
	tell(player, "🏅 Achievement: " .. badge.name, Config.RARITIES.Legendary)
	if remotes.Sound then
		remotes.Sound:FireClient(player, "Victory")
	end
	PlayerData.requestSave(player)
	if badge.id > 0 then
		task.spawn(function()
			local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badge.id)
			if not ok then
				warn("Couldn't award badge " .. key .. ": " .. tostring(err))
			end
		end)
	end
end

-- Stats ----------------------------------------------------------------------------------------

local KILL_BADGES = { { 1000, "Kills1000" }, { 10000, "Kills10000" } }

-- Adds to a lifetime stat and today's quests (kills, wins, chests...).
function Rewards.stat(player, stat, amount)
	PlayerData.addStat(player, stat, amount)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if stat == "kills" then
		for _, badge in KILL_BADGES do
			if (data.stats.kills or 0) >= badge[1] then
				Rewards.achieve(player, badge[2])
			end
		end
	elseif stat == "revives" then
		Rewards.achieve(player, "Lifesaver")
	end
	Leaderboards.update(player, data.stats)
end

-- Records a best-in-one-run value (wave, level).
function Rewards.best(player, stat, value)
	PlayerData.bestStat(player, stat, value)
end

-- What the client shows in the REWARDS menu and the guide.
function Rewards.snapshot(player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	local quests = {}
	for i, q in PlayerData.quests(player) do
		local def = PlayerData.questDef(q.id)
		quests[i] = { text = def.text, goal = def.goal, gold = def.gold, progress = q.progress, claimed = q.claimed }
	end
	return {
		daily = PlayerData.daily(player), quests = quests, tutorial = data.tutorial, stats = data.stats,
		badges = data.badges, settings = data.settings,
	}
end

-- Requests -------------------------------------------------------------------------------------

local function handle(player, action, arg)
	if action == "daily" then
		local reward = PlayerData.claimDaily(player)
		if reward then
			tell(player, string.format("📅 Daily reward: +%s gold%s", reward.gold, reward.revives and " and a revive" or ""), Config.RARITIES.Legendary)
			remotes.Sound:FireClient(player, "Coins")
		end
		return reward ~= nil
	elseif action == "quest" and typeof(arg) == "number" then
		local gold = PlayerData.claimQuest(player, math.floor(arg))
		if gold then
			tell(player, string.format("📜 Quest complete: +%s gold", gold), Config.RARITIES.Epic)
			remotes.Sound:FireClient(player, "Coins")
		end
		return gold ~= nil
	elseif action == "code" and typeof(arg) == "string" and #arg <= 40 then
		local reward, why = PlayerData.redeem(player, arg)
		if reward then
			tell(player, string.format("🎟️ Code redeemed: +%s gold%s", reward.gold or 0, reward.revives and " and a revive" or ""), Config.RARITIES.Legendary)
			remotes.Sound:FireClient(player, "Coins")
		else
			tell(player, why, Config.RARITIES.Mythic)
		end
		return reward ~= nil
	elseif action == "tutorial" then
		if PlayerData.finishTutorial(player) then
			local data = PlayerData.get(player)
			data.gold += TUTORIAL_GOLD
			tell(player, string.format("🎓 Guide complete! Welcome gift: +%d gold", TUTORIAL_GOLD), Config.RARITIES.Legendary)
			return true
		end
	end
	return false
end

function Rewards.init(r, changed)
	remotes = r
	onChanged = changed
	remotes.Rewards.OnServerEvent:Connect(function(player, action, arg)
		if typeof(action) == "string" and handle(player, action, arg) then
			PlayerData.requestSave(player)
			onChanged(player)
		end
	end)
	remotes.Settings.OnServerEvent:Connect(function(player, settings)
		PlayerData.setSettings(player, settings)
		PlayerData.requestSave(player)
	end)
end

-- On join: the welcome achievement, and a nudge if today's reward is waiting.
function Rewards.welcome(player)
	Rewards.achieve(player, "Welcome")
	if PlayerData.daily(player).canClaim then
		task.delay(4, function()
			if player.Parent then
				tell(player, "📅 Your daily reward is ready! Open REWARDS to claim it.", Config.RARITIES.Legendary)
			end
		end)
	end
end

return Rewards
