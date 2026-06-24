--RobuxHandler Script in ServerScriptService
--// Services
local MarketPlaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Variables

local GamepassFolder = ReplicatedStorage.Gamepasses

function GetGamepassFromID(ID)
	for _, Gamepass in GamepassFolder:GetChildren() do
		if Gamepass.Value == ID then
			return Gamepass
		end
	end
	return nil
end

MarketPlaceService.PromptGamePassPurchaseFinished:Connect(function(Player, Gamepass, Succes)
	if not Succes then return end

	local GamepassType = GetGamepassFromID(Gamepass)
	if GamepassType == nil then return end -- Gamepass does not exist in the game!	

	local GP = Player.Data.Gamepasses:FindFirstChild(GamepassType.Name)
	if not GP then warn("Gamepass: "..GamepassType.Name.." does not exist in Player.Data.Gamepasses! Edit Datastore.Datastore.Values to add it!") return end

	GP.Value = true
end)

local function GetPet(SelectedEgg)
	local TotalWeight = 0
	for _,v in SelectedEgg:GetChildren() do
		TotalWeight += v.Value
	end

	local Chance = Random.new():NextNumber(0.0001,TotalWeight)
	local Counter = 0

	for _,v in SelectedEgg:GetChildren() do
		Counter += v.Value
		if Counter >= Chance then
			return v.Name
		end
	end
end

local function GetRobuxEgg(Player, Egg)
	local EggInfo = ReplicatedStorage.Eggs[Egg]
	local ChosenPet = GetPet(EggInfo.Pets)
	if ChosenPet ~= nil then
		Player.NonSaveValues.IsOpeningEgg.Value = true
		coroutine.wrap(function()
			task.wait(3)
			Player.NonSaveValues.IsOpeningEgg.Value = false
		end)()
		ReplicatedStorage.Remotes.Egg:InvokeClient(Player, Egg, ChosenPet, 0)
		return ChosenPet
	end
end

function RandomID(Folder)
	local Chance = math.random(1,10000)
	if Folder:FindFirstChild(Chance) then
		return RandomID(Folder) -- reroll if exists
	end
	return Chance
end


MarketPlaceService.ProcessReceipt = function(ReceiptInfo)
	local Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)

	for _, EggInfo in ReplicatedStorage.Eggs:GetChildren() do
		if not EggInfo:FindFirstChild("ProductId") then continue end

		if tonumber(EggInfo.ProductId.Value) == ReceiptInfo.ProductId then
			local PetChosen = GetRobuxEgg(Player, EggInfo.Name)	-- this selects a random pet from the egg

			--// Create Pet
			local NewPet = game.ReplicatedStorage.Assets.PetTemplate:Clone()
			NewPet.Name = RandomID(Player.Data.Pets)
			NewPet.PetName.Value = PetChosen
			NewPet.Parent = Player.Data.Pets

			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end	
end
