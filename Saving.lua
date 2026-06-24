--Saving Module in DatastoreModule
local DS = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")

local SavingFunctions = {}

SavingFunctions.SaveData = function(Player, AutoSave)
	local Folder = Player.Data
		
	if Player:FindFirstChild("Loaded") == nil or Player.Loaded.Value == false then
		return
	end
	
	Player.Loaded.Value = false
	
	local Save = {}
		
	for FolderName,FolderInfo in require(script.Parent.Values).SaveValues do
		Save[FolderName] = {}
		
		for _,Info in FolderInfo do
			Save[FolderName][Info.ID] = Folder[FolderName][Info.Name].Value
		end
	end
	
	Save["Pets"] = {}
	for _,Pet in Folder.Pets:GetChildren() do
		Save["Pets"][tonumber(Pet.Name)] = {
			PetName = Pet.PetName.Value,
			Equipped = Pet.Equipped.Value,
		}
	end
	
	Save["AutoDelete"] = {}
	for _,Pet in Folder.AutoDelete:GetChildren() do
		if Pet.Value then
			Save["AutoDelete"][Pet.Name] = true
		end
	end

	Save["Vehicles"] = {}
	for _, vehicle in Folder.Vehicles:GetChildren() do
		if vehicle.Value then
			Save["Vehicles"][vehicle.Name] = true
		end
	end
	
	if AutoSave then
		Save.SessionId = game.JobId
		Save.LastInGame = os.time()
	end
	
	local suc,er = pcall(function()
		DS:GetDataStore(RS["Game Settings"].DataSave.Value):SetAsync(Player.UserId, Save)
	end)
	
	if er then warn("error with saving data for "..Player.Name.." : "..er) end
end

return SavingFunctions
