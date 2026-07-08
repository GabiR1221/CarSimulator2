--Saving Module in DatastoreModule
local DS = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")

local SavingFunctions = {}

SavingFunctions.SaveData = function(Player, AutoSave)
	local Folder = Player.Data

	if Player:FindFirstChild("Loaded") == nil or Player.Loaded.Value == false then
		return
	end

	local wasLoaded = Player.Loaded.Value
	if AutoSave then
		Player.Loaded.Value = false
	end

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
	if Folder:FindFirstChild("Vehicles") then
		for _, vehicle in Folder.Vehicles:GetChildren() do
			if vehicle:IsA("BoolValue") then
				Save["Vehicles"][vehicle.Name] = vehicle.Value == true
			end
		end
	end

	Save["VehicleCustomizations"] = {}
	if Folder:FindFirstChild("VehicleCustomizations") then
		for _, vehicleFolder in Folder.VehicleCustomizations:GetChildren() do
			if vehicleFolder:IsA("Folder") then
				Save["VehicleCustomizations"][vehicleFolder.Name] = {}
				for _, equipped in vehicleFolder:GetChildren() do
					if equipped:IsA("StringValue") and equipped.Value ~= "" then
						Save["VehicleCustomizations"][vehicleFolder.Name][equipped.Name] = equipped.Value
					end
				end
			end
		end
	end

	Save["VehicleCustomizations"] = {}
	for _, vehicleFolder in Folder.VehicleCustomizations:GetChildren() do
		Save["VehicleCustomizations"][vehicleFolder.Name] = {}
		for _, value in vehicleFolder:GetChildren() do
			if value:IsA("StringValue") and value.Value ~= "" then
				Save["VehicleCustomizations"][vehicleFolder.Name][value.Name] = value.Value
			end
		end
	end

	if AutoSave then
		Save.SessionId = game.JobId
		Save.LastInGame = os.time()
	end

	local suc,er = pcall(function()
		DS:GetDataStore(RS["Game Settings"].DataSave.Value):SetAsync(Player.UserId, Save)
	end)

	if er then
		warn("error with saving data for "..Player.Name.." : "..er)
		if AutoSave and Player.Parent then
			Player.Loaded.Value = wasLoaded
		end
	end
end

return SavingFunctions
