--RemoteHandler Script in ServerScriptService
--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Variables
local GameSettings = ReplicatedStorage["Game Settings"]
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage.Modules

local Multipliers = require(Modules.Multipliers)
local PetMultipliers = require(Modules.PetMultipliers)

local Cooldowns = {}

--// Script

Players.PlayerAdded:Connect(function(Player)
	Cooldowns[Player.Name] = false

	local PetFolder = Instance.new("Folder")
	PetFolder.Name = Player.Name
	PetFolder.Parent = workspace.PlayerPets

	repeat wait() until Player:FindFirstChild("Loaded") and Player.Loaded.Value or Player.Parent == nil
	if Player.Parent == nil then return end

	LoadEquipped(Player)
end)

Players.PlayerRemoving:Connect(function(Player)
	Cooldowns[Player.Name] = nil
	workspace.PlayerPets[Player.Name]:Destroy()
end)

-- Clicker
Remotes.Clicker.OnServerEvent:Connect(function(Player)
	if GameSettings.GameType.Value ~= "Clicker" then return end

	if Cooldowns[Player.Name] == false then
		Cooldowns[Player.Name] = true
		Player.Data.PlayerData.Currency.Value += 1 * Multipliers.CurrencyMultiplier(Player)
		Player.Data.PlayerData.TotalCurrency.Value += 1 * Multipliers.CurrencyMultiplier(Player)
		task.wait(0.08)
		Cooldowns[Player.Name] = false
	end
end)

-- Music
Remotes.Setting.OnServerEvent:Connect(function(Player, SettingName, Toggled)
	Player.Data.PlayerData[SettingName].Value = Toggled
end)

-- Rebirth
function Rebirth(Player) -- this will run the action when you passed all requirements for rebirthing
	Player.Data.PlayerData.Currency.Value = 0
	Player.Data.PlayerData.Rebirth.Value += 1
	Player.Data.PlayerData.Currency2.Value += 10 -- gems
end

Remotes.Rebirth.OnServerEvent:Connect(function(Player)
	if Cooldowns[Player.Name] == false then
		Cooldowns[Player.Name] = true	
		if GameSettings.RebirthType.Value == "Linear" then
			if Player.Data.PlayerData.Currency.Value >= GameSettings.RebirthBasePrice.Value * (Player.Data.PlayerData.Rebirth.Value + 1) then
				Rebirth(Player)
			end
		else
			if Player.Data.PlayerData.Currency.Value >= GameSettings.RebirthBasePrice.Value * (GameSettings.RebirthMultiplier.Value + 1.25) ^ Player.Data.PlayerData.Rebirth.Value then
				Rebirth(Player)
			end
		end
		task.wait(0.08)
		Cooldowns[Player.Name] = false
	end
end)

-- Pet
function LoadEquipped(Player)
	local EquippedPets = PetMultipliers.Multipliers[Player.Name]

	for PetId, Value in EquippedPets do
		local PetModel = workspace.PlayerPets[Player.Name]:FindFirstChild(PetId)

		if not PetModel then
			local PetInstance = Player.Data.Pets[PetId]
			local NewPet = ReplicatedStorage.Pets[PetInstance.PetName.Value]:Clone()
			NewPet.Name = PetId

			for _, Part in NewPet:GetChildren() do
				if Part:IsA("BasePart") then
					Part.Anchored = true
				end
			end

			local Billboard = script.BillboardGui:Clone()
			Billboard.PetName.Text = PetInstance.PetName.Value
			Billboard.PetRarity.Text = ReplicatedStorage.Pets[PetInstance.PetName.Value].Settings.Rarity.Value
			Billboard.StudsOffset = Vector3.new(0, NewPet.MainPart.Size.Y, 0)
			Billboard.Parent = NewPet

			NewPet:PivotTo(Player.Character.HumanoidRootPart.CFrame)			
			NewPet.Parent = workspace.PlayerPets[Player.Name]
		end
	end

	for _,PlayerPet in workspace.PlayerPets[Player.Name]:GetChildren() do
		if not EquippedPets[tonumber(PlayerPet.Name)] then
			PlayerPet:Destroy()
		end
	end
end

function EquipPet(Player, Pet)
	if Pet.Equipped.Value then return end -- Already equipped
	if Multipliers.GetMaxPetsEquipped(Player) <= Player.NonSaveValues.PetsEquipped.Value then return end -- Too many pets equipped
	Pet.Equipped.Value = true
	PetMultipliers.AddPet(Player.Name, Pet)
	Player.NonSaveValues.PetsEquipped.Value = PetMultipliers.GetPetsEquipped(Player.Name)
end

function UnequipPet(Player, Pet)
	if not Pet.Equipped.Value then return end -- Already unequipped
	Pet.Equipped.Value = false
	PetMultipliers.RemovePet(Player.Name, tonumber(Pet.Name))
	Player.NonSaveValues.PetsEquipped.Value = PetMultipliers.GetPetsEquipped(Player.Name)
end

function EquipAction(Player, Pet) -- this is the action for equipping a pet
	if Pet.Equipped.Value then
		UnequipPet(Player, Pet)
	else
		EquipPet(Player, Pet)
	end
end

function DeleteAction(Player, Pet) -- this is the action for deleting a pet
	if Pet.Equipped.Value then UnequipPet(Player, Pet) end -- unequip if it's equipped
	Pet:Destroy()
end

Remotes.Pet.OnServerEvent:Connect(function(Player, Action, Parameter)
	if type(Parameter) ~= "table" then -- so if this condition is true, then Parameter should be the id of the pet
		local Pet = Player.Data.Pets[Parameter]

		if Action == "Equip" then
			EquipAction(Player, Pet)
		elseif Action == "Delete" then
			DeleteAction(Player, Pet)
		end

		LoadEquipped(Player)
	else -- there are multiple ids
		if Action == "Equip" then -- equip all pets
			for _,PetId in Parameter do
				local Pet = Player.Data.Pets[PetId]
				EquipAction(Player, Pet)
			end

		elseif Action == "Delete" then -- delete all pets
			for _,PetId in Parameter do
				local Pet = Player.Data.Pets[PetId]
				DeleteAction(Player, Pet)				
			end
		end

		LoadEquipped(Player)
	end
end)

-- Egg
function RandomID(Folder)
	local Chance = math.random(1,10000)
	if Folder:FindFirstChild(Chance) then
		return RandomID(Folder) -- reroll if exists
	end
	return Chance
end

function ChooseRandomPet(Egg, LuckMultiplier)
	local EggInfo = ReplicatedStorage.Eggs[Egg]
	local Pets, TotalWeight = {}, 0

	for _, Pet in EggInfo.Pets:GetChildren() do
		table.insert(Pets, {Pet.Name, Pet.Value})
	end

	table.sort(Pets, function(a,b)
		return a[2] > b[2]
	end)

	local BaseChance = Pets[1][2] -- this is the most common pet

	for _,v in Pets do
		local Chance = math.min(v[2] * LuckMultiplier, BaseChance) -- so if the easiest pet is 70%, all pets will go towards 70% 
		TotalWeight += Chance
		v[2] = Chance
	end

	local Chance = Random.new():NextNumber(0,TotalWeight)

	local Counter = 0
	for _,v in Pets do	
		Counter += v[2]

		if Counter >= Chance then
			return v[1]
		end
	end
end

Remotes.Egg.OnServerInvoke = function(Player, Egg, Amount)
	if Player.NonSaveValues.IsOpeningEgg.Value then return end -- cooldown
	if #Player.Data.Pets:GetChildren() + Amount > Multipliers.GetMaxPetsStorage(Player) then return end -- max storage

	local EggInfo = ReplicatedStorage.Eggs:FindFirstChild(Egg)

	if not EggInfo then print(Egg.." does not exist!") return end -- egg does not exist!
	if EggInfo:FindFirstChild("ProductId") then return end -- robux egg

	if Amount == 3 and ReplicatedStorage.Gamepasses:FindFirstChild("TripleEgg") and not Player.Data.Gamepasses.TripleEgg.Value then
		return -- if this is true, it means the player is trying to open a triple egg while there is a gamepass which they don't own
	end

	if Player.Data.PlayerData.Currency.Value >= EggInfo.Cost.Value * Amount then
		Player.Data.PlayerData.Currency.Value -= EggInfo.Cost.Value * Amount
		Player.Data.PlayerData.EggsHatched.Value += Amount
		Player.NonSaveValues.IsOpeningEgg.Value = true

		coroutine.wrap(function()
			task.wait(3)
			Player.NonSaveValues.IsOpeningEgg.Value = false
		end)()

		local Results = {}

		local LuckMultiplier = Multipliers.GetLuckMultiplier(Player)

		for i = 1, Amount do
			local PetName = ChooseRandomPet(Egg, LuckMultiplier) 

			if not Player.Data.AutoDelete[PetName].Value then -- auto delete
				local NewPet = game.ReplicatedStorage.Assets.PetTemplate:Clone()
				NewPet.Name = RandomID(Player.Data.Pets)
				NewPet.PetName.Value = PetName
				NewPet.Parent = Player.Data.Pets
			end

			Results[i] = PetName
		end

		return Results
	end
end

--// Auto Delete
Remotes.AutoDelete.OnServerInvoke = function(Player, Pet)
	Player.Data.AutoDelete[Pet].Value = not Player.Data.AutoDelete[Pet].Value
	return Player.Data.AutoDelete[Pet].Value
end

--// Area
Remotes.Area.OnServerEvent:Connect(function(Player)
	if Cooldowns[Player.Name] == true then return end
	Cooldowns[Player.Name] = true

	coroutine.wrap(function()
		task.wait(0.08)
		Cooldowns[Player.Name] = false
	end)()

	local NextArea = ReplicatedStorage.Areas:FindFirstChild(Player.Data.PlayerData.BestZone.Value + 1)
	if not NextArea then return end


	if Player.Data.PlayerData.Currency.Value < NextArea.Cost.Value then return end

	if NextArea.Cost.Value == -1 then return end -- max area

	Player.Data.PlayerData.Currency.Value -= NextArea.Cost.Value
	Player.Data.PlayerData.BestZone.Value = tonumber(NextArea.Name)
end)

--// Gemshop
Remotes.GemUpgrade.OnServerEvent:Connect(function(Player, Upgrade)
	if not ReplicatedStorage.GemShop:FindFirstChild(Upgrade) then return end

	local GemUpg = ReplicatedStorage.GemShop[Upgrade]
	local UpgradeTier = Player.Data.PlayerData["GemUpgrade"..Upgrade]

	if UpgradeTier.Value >= GemUpg.Max.Value then return end -- max

	local Cost = GemUpg.Price
	local Price

	if Cost.Exponential.Value then
		Price = Cost.DefaultPrice.Value * Cost.IncreasePer.Value ^ UpgradeTier.Value
	else
		Price = Cost.DefaultPrice.Value + Cost.IncreasePer.Value * (UpgradeTier.Value+1)
	end

	if Player.Data.PlayerData.Currency2.Value >= Price then
		Player.Data.PlayerData.Currency2.Value -= Price
		UpgradeTier.Value += 1
	end
end)
