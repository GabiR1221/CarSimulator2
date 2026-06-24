--MultipliersModule in replicated in Modules folder
-- In this module you can find things like Rebirth Multiplier. By using code such as Multipliers.RebirthMultiplier(Player) returns a number which is that player's multiplier. Useful if you have multipliers in multiple scripts

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSettings = ReplicatedStorage["Game Settings"]

local PetMultipliers = require(ReplicatedStorage.Modules.PetMultipliers)

local Multipliers = {}

function Multipliers.RebirthMultiplier(Player)
	local Multi = 1
	
	if GameSettings.RebirthType.Value == "Linear" then
		Multi *= (Player.Data.PlayerData.Rebirth.Value * GameSettings.RebirthMultiplier.Value + 1) -- so multi = RebirthMulti + 1
	else
		Multi *= (GameSettings.RebirthMultiplier.Value + 0.5) ^ Player.Data.PlayerData.Rebirth.Value
	end
	
	return Multi	
end

function Multipliers.CurrencyMultiplier(Player)
	local Multi = GameSettings.CurrencyMultiplier.Value
	Multi *= (Player.Data.Gamepasses.DoubleCurrency.Value and 2 or 1)
	Multi *= Multipliers.RebirthMultiplier(Player)
	Multi *= PetMultipliers.ReadPlayerMultiplier(Player.Name)
	
	local R = ReplicatedStorage.GemShop["2"].Reward
	if R.Exponential.Value then
		Multi *= R.DefaultReward.Value + R.IncreasePer.Value ^ Player.Data.PlayerData.GemUpgrade2.Value
	else
		Multi *= R.DefaultReward.Value + R.IncreasePer.Value * Player.Data.PlayerData.GemUpgrade2.Value
	end
	
	return Multi
end

function Multipliers.GetMaxPetsEquipped(Player)
	return 5
		+ (Player.Data.Gamepasses["MorePets1"].Value and 3 or 0)
		+ (Player.Data.Gamepasses["MorePets2"].Value and 10 or 0)
end

function Multipliers.GetMaxPetsStorage(Player)
	return 50 + (Player.Data.Gamepasses["MoreStorage1"].Value and 50 or 0) + (Player.Data.Gamepasses["MoreStorage2"].Value and 250 or 0)
end

function Multipliers.GetLuckMultiplier(Player)
	return 1 * (Player.Data.Gamepasses.Lucky.Value and 2 or 1)
end

return Multipliers
