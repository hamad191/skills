-- Robux purchases: game passes (permanent perks) and developer products (gold, timed boosts,
-- revives). Paste your IDs into Config.GAME_PASSES / Config.PRODUCTS after creating them on the
-- Creator Dashboard; anything left at id = 0 shows as "not set up" and can't be bought.
-- Products are only granted once their purchase is saved, and each purchase is granted once.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local Monetization = {}
Monetization.onChanged = function(_player) end -- refresh the player's menus and perks
Monetization.onRevive = function(_player) end -- a revive was bought: use it now if knocked out

local owned = {} -- [player] = { [passKey] = true }
local productById = {}
for _, product in Config.PRODUCTS do
	if product.id > 0 then
		productById[product.id] = product
	end
end

function Monetization.owns(player, passKey)
	return owned[player] ~= nil and owned[player][passKey] == true
end

function Monetization.ownedList(player)
	local list = {}
	for passKey in owned[player] or {} do
		table.insert(list, passKey)
	end
	return list
end

function Monetization.load(player)
	owned[player] = {}
	for passKey, pass in Config.GAME_PASSES do
		if pass.id > 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and has then
				owned[player][passKey] = true
			end
		end
	end
end

function Monetization.release(player)
	owned[player] = nil
end

-- Stat bonuses from passes and active boosts (see Progression.bonus).
function Monetization.bonus(player)
	local bonus = {}
	for passKey in owned[player] or {} do
		for stat, value in Config.GAME_PASSES[passKey].bonus or {} do
			bonus[stat] = (bonus[stat] or 0) + value
		end
	end
	if PlayerData.boostActive(player, "xp") then
		bonus.xp = (bonus.xp or 0) + 1
	end
	return bonus
end

-- Gold multiplier: 2x Gold pass and 2x Gold boost each add another 100%.
function Monetization.goldMultiplier(player)
	return 1 + (Monetization.owns(player, "DoubleGold") and 1 or 0) + (PlayerData.boostActive(player, "gold") and 1 or 0)
end

function Monetization.dashCooldown(player)
	return Config.DASH.cooldown * (Monetization.owns(player, "SwiftDash") and Config.SWIFT_DASH or 1)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	for passKey, pass in Config.GAME_PASSES do
		if pass.id == passId then
			owned[player] = owned[player] or {}
			owned[player][passKey] = true
		end
	end
	Monetization.onChanged(player)
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local product = productById[receipt.ProductId]
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and PlayerData.get(player)
	if not product or not data or data.loadFailed then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later
	end
	if data.receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already delivered
	end

	local before = { gold = data.gold, revives = data.revives, xp = data.boosts.xp, goldBoost = data.boosts.gold }
	if product.gold then
		data.gold += product.gold
	end
	if product.boost then
		data.boosts[product.boost] = math.max(data.boosts[product.boost] or 0, os.time()) + product.minutes * 60
	end
	if product.revive then
		data.revives += 1
	end
	data.receipts[receipt.PurchaseId] = os.time()

	if not PlayerData.save(player) then
		-- couldn't save it: undo and let Roblox deliver it again later
		data.gold, data.revives, data.boosts.xp, data.boosts.gold = before.gold, before.revives, before.xp, before.goldBoost
		data.receipts[receipt.PurchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if product.revive then
		Monetization.onRevive(player)
	end
	Monetization.onChanged(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return Monetization
