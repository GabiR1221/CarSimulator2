--Datastore Module in ServerScriptService in Datastore folder
local LoadingFunctions = require(script.Loading)
local SavingFunctions = require(script.Saving)

local Datastore = {
	LoadData = function(Player)
		LoadingFunctions.LoadData(Player)
		
		return true
	end,
	
	SaveData = function(Player, AutoSave)
		SavingFunctions.SaveData(Player, AutoSave)
		
		return true
	end,
}

return Datastore
