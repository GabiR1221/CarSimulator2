--Values Module in DatastoreModule
return {
	["Folders"] = {
		"PlayerData",
		"NonSaveValues",
		"Gamepasses",
		"Pets",
		"Vehicles",
		"AutoDelete",
	},
	
	["SaveValues"] = {
		["PlayerData"] = {
			{Name = "Currency", Value = 0, ID = 1, Type = "NumberValue"},
			{Name = "Music", Value = 0, ID = 2, Type = "BoolValue"},
			{Name = "Rebirth", Value = 0, ID = 3, Type = "NumberValue"},
			{Name = "ShowOtherPets", Value = 0, ID = 4, Type = "BoolValue"},
			{Name = "BestZone", Value = 0, ID = 5, Type = "IntValue"},
			{Name = "Currency2", Value = 0, ID = 6, Type = "NumberValue"},
			
			--// Statistics
			{Name = "EggsHatched", Value = 0, ID = 9, Type = "IntValue"},
			{Name = "TotalCurrency", Value = 0, ID = 10, Type = "IntValue"},

			--// Gem Upgrades
			{Name = "GemUpgrade1", Value = 0, ID = 7, Type = "IntValue"},
			{Name = "GemUpgrade2", Value = 0, ID = 8, Type = "IntValue"},
		},
		
		["Gamepasses"] = {
			{Name = "DoubleCurrency", Value = false, ID = 1, Type = "BoolValue"},
			{Name = "MoreStorage1", Value = false, ID = 2, Type = "BoolValue"}, -- dont worry about this if u have the gamepasses disabled, as it will do nothing :)
			{Name = "MoreStorage2", Value = false, ID = 3, Type = "BoolValue"},
			{Name = "MorePets1", Value = false, ID = 4, Type = "BoolValue"},
			{Name = "TripleEgg", Value = false, ID = 5, Type = "BoolValue"},
			{Name = "Lucky", Value = false, ID = 6, Type = "BoolValue"},
			{Name = "AutoEgg", Value = false, ID = 7, Type = "BoolValue"},
			{Name = "MorePets2", Value = false, ID = 8, Type = "BoolValue"},
		}
	},
	
	["NonSaveValues"] = {
		{Name = "IsOpeningEgg", Value = false, Type = "BoolValue"},
		{Name = "PetsEquipped", Value = 0, Type = "IntValue"},
		{Name = "IsTrading", Value = false, Type = "BoolValue"},
		{Name = "IsReady", Value = false, Type = "BoolValue"},
	},
}
