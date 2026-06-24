--Loading Module in DatastoreModule
--// Configure

local LoadingFunctions = {}
local Values = require(script.Parent.Values)
local DS = game:GetService("DataStoreService")

local RS = game:GetService("ReplicatedStorage")
local PlayerData = DS:GetDataStore(RS["Game Settings"].DataSave.Value)

local MPS = game:GetService("MarketplaceService")

local PetMultipliers = require(RS.Modules.PetMultipliers)
local VehicleCatalog = require(RS.Modules.VehicleCatalog)

local function CreateFolder(Player,FolderName)
	local NewFolder = Instance.new("Folder")
	NewFolder.Name = FolderName
	NewFolder.Parent = Player
	return NewFolder
end

--// Module

LoadingFunctions.LoadData = function(Player)
	local MainFolder = CreateFolder(Player,"Data")
	local Datastore

	local suc,er = pcall(function()
		Datastore = PlayerData:GetAsync(Player.UserId)
	end)

	if er then warn(er) Player:Kick("Failed to load. Make sure to allow API Services in studio & publish your games in order to make datastores work") return end

	if Datastore and Datastore.SessionId and game.JobId ~= Datastore.SessionId and os.time() - Datastore.LastInGame < 60 and not game:GetService("RunService"):IsStudio() then Player:Kick("Session Locked") end

	for _,FolderName in Values.Folders do
		if FolderName ~= "NonSaveValues" then
			CreateFolder(MainFolder,FolderName)
		else
			CreateFolder(Player,FolderName)
		end
	end

	--// Create all the non save values

	for _,Info in Values.NonSaveValues do
		local NewInstance = Instance.new(Info.Type)
		NewInstance.Name = Info.Name
		NewInstance.Value = Info.Value
		NewInstance.Parent = Player.NonSaveValues
	end

	--// Create all the save values

	for FolderName,FolderInfo in Values.SaveValues do	
		for _,Info in FolderInfo do
			local NewInstance = Instance.new(Info.Type)
			NewInstance.Name = Info.Name
			NewInstance.Value = Info.Value
			NewInstance.Parent = MainFolder[FolderName]

			if Datastore and Datastore[FolderName] then
				if Datastore[FolderName][Info.ID] ~= nil and Datastore[FolderName][Info.ID] ~= Info.Value then
					NewInstance.Value = Datastore[FolderName][Info.ID]
				end
			end
		end		
	end

	--// Check Gamepasses

	for _,Gamepass in MainFolder.Gamepasses:GetChildren() do
		if Gamepass.Value then continue end -- only check if you DONT have it
		
		if RS.Gamepasses:FindFirstChild(Gamepass.Name) == nil then continue end
		
		local GPId = RS.Gamepasses[Gamepass.Name].Value
		Gamepass.Value = MPS:UserOwnsGamePassAsync(Player.UserId, GPId)
	end
	
	--// Pets	
	PetMultipliers.AddPlayer(Player.Name)

	if Datastore and Datastore.Pets then
		for PetId, PetInfo in Datastore.Pets do
			local NewPet = RS.Assets.PetTemplate:Clone()
			NewPet.Name = PetId
			NewPet.Equipped.Value = PetInfo.Equipped
			NewPet.PetName.Value = PetInfo.PetName
			NewPet.Parent = MainFolder.Pets
			
			if PetInfo.Equipped then
				PetMultipliers.AddPet(Player.Name, NewPet)
			end
		end
	end
	
	--// Vehicles
	for _, entry in VehicleCatalog.getEntries() do
		local owned = MainFolder.Vehicles:FindFirstChild(entry.id)
		if not owned then
			owned = Instance.new("BoolValue")
			owned.Name = entry.id
			owned.Parent = MainFolder.Vehicles
		end

		if Datastore and Datastore.Vehicles and Datastore.Vehicles[entry.id] then
			owned.Value = Datastore.Vehicles[entry.id] == true
		elseif entry.defaultOwned then
			owned.Value = true
		else
			owned.Value = false
		end
	end

	--// Auto Delete
	for _, Pet in RS.Pets:GetChildren() do
		local AutoDelete = Instance.new("BoolValue")
		
		if Datastore and Datastore.AutoDelete and Datastore.AutoDelete[Pet.Name] then
			AutoDelete.Value = Datastore.AutoDelete[Pet.Name]
		end
		
		AutoDelete.Name = Pet.Name
		AutoDelete.Parent = MainFolder.AutoDelete
	end
	
	Player.NonSaveValues.PetsEquipped.Value = PetMultipliers.GetPetsEquipped(Player.Name)
end

return LoadingFunctions
