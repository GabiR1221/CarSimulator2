--PetMultipliersModule in replicated in Modules folder
--// Change individual pet multipliers in ReplicatedStorage>Pets>Your Pet Name>Settings>Multiplier

local PetMultipliers = {
	Multipliers = {}
}

function PetMultipliers.ReadPlayerMultiplier(PlayerName)
	local Count = 0
	for PetID, PetValue in PetMultipliers.Multipliers[PlayerName] do
		Count += PetValue
	end
	return math.max(Count, 1)
end

function PetMultipliers.GetPetsEquipped(PlayerName)
	local AmountofPetsEquipped = 0
	for _,v in PetMultipliers.Multipliers[PlayerName] do
		AmountofPetsEquipped += 1
	end
	return AmountofPetsEquipped
end

function PetMultipliers.AddPlayer(PlayerName)
	PetMultipliers.Multipliers[PlayerName] = {}
end

function PetMultipliers.AddPet(PlayerName, PetInstance)
	local PetModel = game.ReplicatedStorage.Pets[PetInstance.PetName.Value]
	PetMultipliers.Multipliers[PlayerName][tonumber(PetInstance.Name)] = PetModel.Settings.Multiplier.Value
end

function PetMultipliers.RemovePet(PlayerName, PetID)
	PetMultipliers.Multipliers[PlayerName][PetID] = nil
end

return PetMultipliers
