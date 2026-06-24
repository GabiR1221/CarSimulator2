--Client Script in StarterPlayerScripts
--[[
	This script handles the client. 
	
	Contents:
	- ClickButton
	- Overlay (Currency counter)
	- Popups
	- Close Buttons of Frames
	- Buttons on the side
	- Settings
	- Rebirth
	- Shop
	- Pet Inventory
	- Egg Preview (Frame that shows the price etc)
	- Egg Hatching
	- Pet Follow
	- Areas
	- Trading
	- Gem Shop
	- Codes
	- Stats
	- Functions
	
	Only edit if you know what you're doing!
]]

--// Services
local MarketPlaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--// Loading
local Player = Players.LocalPlayer
repeat wait() until Player:FindFirstChild("Loaded") and Player.Loaded.Value or Player.Parent == nil

if Player.Parent == nil then return end

--// Variables
local Data = Player.Data
local PlayerData = Data.PlayerData

local GameSettings = ReplicatedStorage["Game Settings"]
local Modules = ReplicatedStorage.Modules

local PetMultipliers = require(Modules.PetMultipliers)
local Multipliers = require(Modules.Multipliers)
local Utilities = require(Modules.Utilities)

local UI = Player.PlayerGui:WaitForChild("GameUI")
local Frames = UI.Frames

local Remotes = ReplicatedStorage.Remotes

--// Clicker
if GameSettings.GameType.Value == "Clicker" then
	Utilities.ButtonAnimations.Create(UI.Clicker)

	UI.Clicker.Click.MouseButton1Click:Connect(function()
		Remotes.Clicker:FireServer()
		Utilities.Audio.PlayAudio("Click")
	end)

	if GameSettings.ClickingAnywhere.Value then
		UserInputService.InputBegan:Connect(function(Input, Processed)
			if Processed then return end
			if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end -- not a left mouse click
			Remotes.Clicker:FireServer()
			Utilities.Audio.PlayAudio("Click")
		end)
	end
end

--// Overlay
local CurrencySide = UI[GameSettings.CurrencySide.Value]
CurrencySide.CurrencyLabel.Amount.Text = Utilities.Short.en(PlayerData.Currency.Value)
PlayerData.Currency.Changed:Connect(function()
	CurrencySide.CurrencyLabel.Amount.Text = Utilities.Short.en(PlayerData.Currency.Value)
end)

CurrencySide.CurrencyLabel2.Amount.Text = Utilities.Short.en(PlayerData.Currency2.Value)
PlayerData.Currency2.Changed:Connect(function()
	CurrencySide.CurrencyLabel2.Amount.Text = Utilities.Short.en(PlayerData.Currency2.Value)
end)


--// Popups
local CurrencyOld = PlayerData.Currency.Value
PlayerData.Currency.Changed:Connect(function(NewValue)
	task.spawn(function()
		if NewValue > CurrencyOld then
			local NewPopup = script.Popup:Clone()
			NewPopup.Size = UDim2.new(0,0,0,0)
			NewPopup.Currency.Image = CurrencySide.CurrencyLabel.Currency.Image
			NewPopup.Amount.Text = "+"..Utilities.Short.en(NewValue - CurrencyOld)
			NewPopup.Position = UDim2.new(math.random(40, 60) / 100, 0, math.random(40, 60) / 100, 0) -- sets it in a random position in the middle square
			NewPopup.Parent = UI.Popups
			NewPopup:TweenSize(UDim2.new(0.176,0,0.105,0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.5)
			task.wait(1)
			NewPopup:TweenPosition(CurrencySide.Position, Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 2)
			NewPopup:TweenSize(UDim2.new(0.1,0,0.05,0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 2)
			task.wait(1.4)
			NewPopup:Destroy()
		end
	end)

	CurrencyOld = NewValue
end)

--// Frames
local BaseSize = {}
for _,Frame in Frames:GetChildren() do
	if not Frame:IsA("Frame") then continue end

	BaseSize[Frame.Name] = Frame.Size

	if Frame:FindFirstChild("Close") then
		Utilities.ButtonAnimations.Create(Frame.Close)
		Frame.Close.Click.MouseButton1Click:Connect(function()
			Utilities.ButtonHandler.OnClick(Frame, UDim2.new(0,0,0,0))
			Utilities.Audio.PlayAudio("Click")
		end)
	end
end

--// Buttons
local ButtonSide = UI[GameSettings.ButtonSide.Value]
for _,Button in ButtonSide.Buttons:GetChildren() do
	if not Button:IsA("Frame") then continue end
	Utilities.ButtonAnimations.Create(Button)
	Button.Click.MouseButton1Click:Connect(function()
		Utilities.ButtonHandler.OnClick(UI.Frames[Button.Name], BaseSize[Button.Name])
		Utilities.Audio.PlayAudio("Click")
	end)
end

--// Settings
local SettingsScroll = Frames.Settings.ObjectHolder

-- Music Setting
local MusicSetting = SettingsScroll.Music
Utilities.ButtonAnimations.Create(MusicSetting.Toggle.On)
Utilities.ButtonAnimations.Create(MusicSetting.Toggle.Off)

MusicSetting.Toggle.On.Click.MouseButton1Click:Connect(function()
	ReplicatedStorage.Remotes.Setting:FireServer("Music", true)
	Utilities.Audio.PlayAudio("Click")
end)

MusicSetting.Toggle.Off.Click.MouseButton1Click:Connect(function()
	ReplicatedStorage.Remotes.Setting:FireServer("Music", false)
	Utilities.Audio.PlayAudio("Click")
end)

SoundService.Music.PlaybackSpeed = PlayerData.Music.Value and 1 or 0
PlayerData.Music.Changed:Connect(function()
	SoundService.Music.PlaybackSpeed = PlayerData.Music.Value and 1 or 0
end)

-- ShowOtherPets
local ShowOtherPetsSetting = SettingsScroll.ShowOtherPets
Utilities.ButtonAnimations.Create(ShowOtherPetsSetting.Toggle.On)
Utilities.ButtonAnimations.Create(ShowOtherPetsSetting.Toggle.Off)

ShowOtherPetsSetting.Toggle.On.Click.MouseButton1Click:Connect(function()
	ReplicatedStorage.Remotes.Setting:FireServer("ShowOtherPets", true)
	Utilities.Audio.PlayAudio("Click")
end)

ShowOtherPetsSetting.Toggle.Off.Click.MouseButton1Click:Connect(function()
	ReplicatedStorage.Remotes.Setting:FireServer("ShowOtherPets", false)
	Utilities.Audio.PlayAudio("Click")
end)

--// Rebirth
local RebirthPrice, RebirthMulti = GameSettings.RebirthBasePrice.Value, GameSettings.RebirthMultiplier.Value

function UpdateRebirthInfo()
	Frames.Rebirth.Counter.Text = "You have "..Utilities.Short.en(PlayerData.Rebirth.Value).." Rebirths"
	if GameSettings.RebirthType.Value == "Linear" then
		Frames.Rebirth.Description.Text = "Buying a Rebirth will increase your "..GameSettings.CurrencyName.Value.." Multiplier with x"..RebirthMulti
		Frames.Rebirth.Cost.Text = "You need atleast "..Utilities.Short.en(RebirthPrice * (PlayerData.Rebirth.Value + 1)).." "..GameSettings.CurrencyName.Value
	elseif GameSettings.RebirthType.Value == "Exponential" then
		Frames.Rebirth.Description.Text = "Buying a Rebirth will increase your "..GameSettings.CurrencyName.Value.." Multiplier with ^"..(RebirthMulti+0.5)
		Frames.Rebirth.Cost.Text = "You need atleast "..Utilities.Short.en(RebirthPrice * ((RebirthMulti+1.25) ^ PlayerData.Rebirth.Value)).." "..GameSettings.CurrencyName.Value
	end
end

UpdateRebirthInfo()

PlayerData.Rebirth.Changed:Connect(function()
	UpdateRebirthInfo()
end)

Utilities.ButtonAnimations.Create(Frames.Rebirth.Buy)

Frames.Rebirth.Buy.Click.MouseButton1Click:Connect(function()
	Remotes.Rebirth:FireServer()
	Utilities.Audio.PlayAudio("Click")
end)

--// Shop
for _,Gamepass in ReplicatedStorage.Gamepasses:GetChildren() do
	local NewGamepass = script.GamepassTemplate:Clone()

	local GamepassInfo

	local Succes, Error = pcall(function()
		GamepassInfo = MarketPlaceService:GetProductInfo(Gamepass.Value, Enum.InfoType.GamePass)
	end)

	if Error then 
		warn("An error as occured while gathering gamepass data: "..Error) 
		NewGamepass:Destroy() continue 
	else
		NewGamepass.InnerPart.ImageLabel.Image = "rbxassetid://"..(GamepassInfo.IconImageAssetId or 666669321)
		NewGamepass.InnerPart.Description.Text = GamepassInfo.Description 
		NewGamepass.InnerPart.GPName.Text = GamepassInfo.Name
		NewGamepass.InnerPart.Price.Text = Data.Gamepasses[Gamepass.Name].Value and "Owned ✅" or "\u{E002}"..(GamepassInfo.PriceInRobux or 10000)

		Data.Gamepasses[Gamepass.Name].Changed:Connect(function()
			NewGamepass.InnerPart.Price.Text = Data.Gamepasses[Gamepass.Name].Value and "Owned ✅" or "\u{E002}"..GamepassInfo.PriceInRobux
		end)

		NewGamepass.InnerPart.Button.MouseButton1Click:Connect(function()
			MarketPlaceService:PromptGamePassPurchase(Player, Gamepass.Value)
			Utilities.Audio.PlayAudio("Click")
		end)

		NewGamepass.Parent = Frames.Shop.Gamepasses
	end
end

--// Pet Inventory
local PetInventory = {} -- all pets will be added in this table

local PetFrame = Frames.Pets
local SideFrame = PetFrame.SideFrame
PetFrame.SideFrameBlocker.Visible = true

local IsMultiDeleting = false
local SelectedForDelete = {}

function SortInventory(SortTable, ObjectHolder)
	local TableToSort = SortTable ~= nil and SortTable or PetInventory -- so it can differentiate between trade and normal inventories

	table.sort(TableToSort, function(a,b)
		if not a or not b then return end

		if a.Multiplier ~= b.Multiplier then
			return a.Multiplier > b.Multiplier
		else
			return a.ID > b.ID
		end
	end)

	for Order,PetInfo in TableToSort do
		if not Data.Pets:FindFirstChild(PetInfo.ID) then
			table.remove(TableToSort, Order)
			continue
		end

		if not ObjectHolder then
			PetFrame.MainFrame.ObjectHolder[PetInfo.ID].LayoutOrder = Order + (Data.Pets[PetInfo.ID].Equipped.Value and 0 or 1000) -- order + 1000 if equipped
		else
			ObjectHolder[PetInfo.ID].LayoutOrder = Order + (Data.Pets[PetInfo.ID].Equipped.Value and 0 or 1000) -- order + 1000 if equipped
		end
	end
end

local CurrentlySelected = 0

function AddPet(PetInstance, SortTable, Parent) -- Creates a pet slot
	task.wait(0.1)
	local NewPet = script.PetTemplate:Clone()

	local PetModel = ReplicatedStorage.Pets[PetInstance.PetName.Value]:Clone()
	PetModel.Parent = NewPet.Display

	local MainPart = PetModel:FindFirstChild("MainPart")
	local Pos

	if not MainPart then
		warn(PetModel.Name.." does not have a MainPart, please add one by calling one of the parts 'MainPart'")

		for _,v in PetModel:GetChildren() do -- this here chooses a random part of the pet instead of the mainpart.
			if v:IsA("BasePart") then
				Pos = v.Position
				break
			end
		end
	else
		Pos = MainPart.Position
	end

	local Pos = PetModel.MainPart.Position
	local Camera = Instance.new("Camera")
	NewPet.Display.CurrentCamera = Camera
	PetModel:PivotTo(PetModel:GetPivot() * CFrame.Angles(0, math.rad(180), 0))
	Camera.CFrame = CFrame.new(Vector3.new(Pos.X + PetModel:GetExtentsSize().X * 1.5, Pos.Y, Pos.Z + 1), Pos)

	if not Parent then -- normal pet
		NewPet.Equipped.Visible = PetInstance.Equipped.Value

		PetInstance.Equipped.Changed:Connect(function()
			NewPet.Equipped.Visible = PetInstance.Equipped.Value

			if CurrentlySelected == tonumber(PetInstance.Name) then
				UpdateSideFrame(PetInstance)
			end

			SortInventory()
		end)

		NewPet.Button.MouseButton1Click:Connect(function()
			if not IsMultiDeleting then
				UpdateSideFrame(PetInstance)
			else
				if not table.find(SelectedForDelete, tonumber(PetInstance.Name)) then
					table.insert(SelectedForDelete, tonumber(PetInstance.Name))
					NewPet.Delete.Visible = true
				else
					table.remove(SelectedForDelete, table.find(SelectedForDelete, tonumber(PetInstance.Name)))
					NewPet.Delete.Visible = false
				end
			end
			Utilities.Audio.PlayAudio("Click")
		end)
	end
	NewPet.Name = PetInstance.Name
	NewPet.Parent = Parent == nil and PetFrame.MainFrame.ObjectHolder or Parent

	if SortTable == nil then
		PetInventory[#PetInventory+1] = {ID = PetInstance.Name, Multiplier = ReplicatedStorage.Pets[PetInstance.PetName.Value].Settings.Multiplier.Value}
	else
		SortTable[#SortTable+1] = {ID = PetInstance.Name, Multiplier = ReplicatedStorage.Pets[PetInstance.PetName.Value].Settings.Multiplier.Value}
	end

	return NewPet
end

function UpdateSideFrame(PetInstance) -- PetInstance is the folder in Player.Pets
	CurrentlySelected = tonumber(PetInstance.Name)
	PetFrame.SideFrameBlocker.Visible = false

	SideFrame.Title.Text = PetInstance.PetName.Value
	SideFrame.Equip.Title.Text = PetInstance.Equipped.Value and "Unequip" or "Equip"
	SideFrame.Equip.BackgroundColor3 = PetInstance.Equipped.Value and Color3.fromRGB(36, 136, 2) or Color3.fromRGB(56, 218, 3) 

	if SideFrame.Display:FindFirstChild("PetModel") then
		SideFrame.Display.PetModel:Destroy()
	end

	local PetModel = ReplicatedStorage.Pets[PetInstance.PetName.Value]:Clone()
	PetModel.Name = "PetModel"
	PetModel.Parent = SideFrame.Display

	local Pos = PetModel.MainPart.Position
	local Camera = Instance.new("Camera")
	SideFrame.Display.CurrentCamera = Camera
	PetModel:PivotTo(PetModel:GetPivot() * CFrame.Angles(0, math.rad(180), 0))
	Camera.CFrame = CFrame.new(Vector3.new(Pos.X + PetModel:GetExtentsSize().X * 1.5, Pos.Y, Pos.Z + 1), Pos)

	SideFrame.Multiplier.Amount.Text = "x"..Utilities.Short.en(ReplicatedStorage.Pets[PetInstance.PetName.Value].Settings.Multiplier.Value)
end

for _,v in Data.Pets:GetChildren() do -- load pets on join
	coroutine.wrap(function()
		AddPet(v)
	end)()
end


function UpdateCounters()
	PetFrame.InventoryCounters.Storage.Text = #Player.Data.Pets:GetChildren().."/"..Multipliers.GetMaxPetsStorage(Player)
	PetFrame.InventoryCounters.Equipped.Text = Player.NonSaveValues.PetsEquipped.Value.."/"..Multipliers.GetMaxPetsEquipped(Player)
end

UpdateCounters()

coroutine.wrap(function()
	task.wait(0.5)
	SortInventory() -- made it wait 0.5 seconds before it sorted inventory because the pets are not yet loaded
end)()

function OnPetAdded(Child) -- this function is ran when a pet is added, which updates the counters & adds a new pet ui instance
	UpdateCounters()
	AddPet(Child)
	SortInventory()
end

function OnPetRemoved(Child)
	UpdateCounters()
	PetFrame.MainFrame.ObjectHolder[Child.Name]:Destroy()
	SortInventory()
end

Data.Pets.ChildAdded:Connect(OnPetAdded)
Data.Pets.ChildRemoved:Connect(OnPetRemoved)

Player.NonSaveValues.PetsEquipped.Changed:Connect(UpdateCounters) -- if player equips a pet

-- Pet Sideframe scripts
Utilities.ButtonAnimations.Create(SideFrame.Equip, 1.04)
Utilities.ButtonAnimations.Create(SideFrame.Delete, 1.04)

SideFrame.Equip.Click.MouseButton1Click:Connect(function()
	Remotes.Pet:FireServer("Equip", CurrentlySelected)
	Utilities.Audio.PlayAudio("Click")
end)

SideFrame.Delete.Click.MouseButton1Click:Connect(function()
	Remotes.Pet:FireServer("Delete", CurrentlySelected)
	PetFrame.SideFrameBlocker.Visible = true
	Utilities.Audio.PlayAudio("Click")
end)

-- Bottom Buttons
for _, Button in PetFrame.Buttons:GetChildren() do
	if not Button:IsA("Frame") then continue end
	Utilities.ButtonAnimations.Create(Button)
end

PetFrame.Buttons.MultiDelete.Click.MouseButton1Click:Connect(function()	
	IsMultiDeleting = not IsMultiDeleting

	if not IsMultiDeleting then
		PetFrame.Buttons.MultiDelete.Title.Text = "Multi Delete"
		Remotes.Pet:FireServer("Delete", SelectedForDelete)
		for _,v in SelectedForDelete do
			local PetFrame = PetFrame.MainFrame.ObjectHolder[v]
			PetFrame.Delete.Visible = false
		end
		SelectedForDelete = {}
	else
		PetFrame.Buttons.MultiDelete.Title.Text = "Confirm"
	end
	Utilities.Audio.PlayAudio("Click")
end)

PetFrame.Buttons.EquipBest.Click.MouseButton1Click:Connect(function()
	local EquipBest = {}

	for i = 1, Multipliers.GetMaxPetsEquipped(Player) do -- find best equips
		if not PetInventory[i] then break end
		table.insert(EquipBest, PetInventory[i].ID)
	end

	for _, Pet in Data.Pets:GetChildren() do
		local Pos = table.find(EquipBest, Pet.Name)
		if Pet.Equipped.Value and Pos ~= nil then -- pet is already equipped
			table.remove(EquipBest, Pos)
		elseif Pet.Equipped.Value and Pos == nil then -- pet is equipped but should be unequipped
			table.insert(EquipBest, 1, Pet.Name)
		end
	end

	Remotes.Pet:FireServer("Equip", EquipBest)	
	Utilities.Audio.PlayAudio("Click")
end)

--// Egg Preview
local PreviewFrame = UI.PreviewFrame
local DefaultSize = PreviewFrame.Size
local CurrentTarget = PreviewFrame.CurrentTarget
PreviewFrame.Size = UDim2.new(0.2,0,0.2,0)

function FindClosestEgg(EggsAvailable)
	local CurrentClosest, ClosestDistance = nil, 100

	for _,Egg in EggsAvailable do
		local EggModel = workspace.Map.Eggs[Egg]
		local mag = (EggModel:GetPivot().Position-Player.Character.HumanoidRootPart.Position).Magnitude
		if mag <= ClosestDistance then
			CurrentClosest = EggModel
			ClosestDistance = mag
		end
	end
	return CurrentClosest
end

local IsClosing = false -- so it doesnt ruin the animation

function FindEgg()
	if not Player.Character:FindFirstChild("HumanoidRootPart") or not Player.Character:FindFirstChild("Humanoid") or Player.Character.Humanoid.Health == 0 then return end

	local Camera = workspace.CurrentCamera
	local EggsAvailable = {}
	local CameraRatio = ((Camera.CFrame.Position - Camera.Focus.Position).Magnitude)/11

	for _,Egg in workspace.Map.Eggs:GetChildren() do
		if Egg == nil then continue end
		if not Egg:FindFirstChild("EggModel") then warn(Egg.Name.." does not have an EggModel") end

		local mag = (Egg:GetPivot().Position-Player.Character.HumanoidRootPart.Position).Magnitude
		if mag <= 12 then
			EggsAvailable[#EggsAvailable + 1] = Egg.Name
		end
	end

	local SetVisibility = #EggsAvailable >= 1 -- if its 0 then its already false

	if SetVisibility then -- a egg(s) is in distance
		local Egg = #EggsAvailable > 1 and FindClosestEgg(EggsAvailable) or workspace.Map.Eggs[EggsAvailable[1]]
		local WSP = workspace.CurrentCamera:WorldToScreenPoint(Egg:GetPivot().Position)
		PreviewFrame.Position = UDim2.new(0,WSP.X,0,WSP.Y)
		CurrentTarget.Value = Egg.Name
	else
		CurrentTarget.Value = "None"
	end

	if Player.NonSaveValues.IsOpeningEgg.Value then
		SetVisibility = false -- if you are opening an egg itll auto close the previewframe
	end

	--// Make the previewframe visible
	if SetVisibility and not PreviewFrame.Visible then
		PreviewFrame.Visible = true
		Utilities.Tween.Tween(PreviewFrame, {Speed = 0.15}, {Size = UDim2.new(DefaultSize.X.Scale/CameraRatio, DefaultSize.X.Offset, DefaultSize.Y.Scale/CameraRatio, DefaultSize.Y.Offset)})	
	elseif not SetVisibility and PreviewFrame.Visible and not IsClosing then -- set to invisible, while is visible & isnt closing
		IsClosing = true
		Utilities.Tween.Tween(PreviewFrame, {Speed = 0.15}, {Size = UDim2.new(0.2,0,0.2,0)})	
		task.wait(0.15)
		PreviewFrame.Visible = false
		IsClosing = false
	end
end

function UpdatePreviewFrame()
	if CurrentTarget.Value ~= "None" then
		local Egg = CurrentTarget.Value
		PreviewFrame.EggInfo.EggName.Text = Egg

		if not ReplicatedStorage.Eggs:FindFirstChild(Egg) then print(Egg.." does not have settings in ReplicatedStorage.Eggs!") return end

		local EggInfo = ReplicatedStorage.Eggs[Egg]

		local IsRobuxEgg = EggInfo:FindFirstChild("ProductId")
		if IsRobuxEgg then
			PreviewFrame.EggInfo.Price.Text = "Costs \u{E002}"..Utilities.Short.en(EggInfo.Cost.Value)
		else
			PreviewFrame.EggInfo.Price.Text = "Costs "..Utilities.Short.en(EggInfo.Cost.Value)
		end

		PreviewFrame.Buttons.Triple.Visible = not IsRobuxEgg
		PreviewFrame.Buttons.Auto.Visible = not IsRobuxEgg

		--// This part gets the pet chances
		local Pets, TotalWeight = {}, 0

		for _, Pet in EggInfo.Pets:GetChildren() do
			table.insert(Pets, {Pet.Name, Pet.Value})
		end

		table.sort(Pets, function(a,b)
			return a[2] > b[2]
		end)

		local BaseChance = Pets[1][2] -- this is the most common pet

		local LuckMultiplier = Multipliers.GetLuckMultiplier(Player)

		for _,v in Pets do
			local Chance = math.min(v[2] * LuckMultiplier, BaseChance) -- so if the easiest pet is 70%, all pets will go towards 70% 
			TotalWeight += Chance
			v[2] = Chance
		end

		for i = 1,9 do
			local PetInfo = Pets[i]
			local PetSlot = PreviewFrame.PetChances.List["Pet"..i]
			PetSlot.Visible = PetInfo ~= nil

			if PetInfo == nil then continue end

			PetSlot.Rarity.Text = ReplicatedStorage.Pets[PetInfo[1]].Settings.Rarity.Value
			PetSlot.Percentage.Text = Utilities.Short.en(100/TotalWeight * PetInfo[2]).."%"
			PetSlot.Delete.Visible = Data.AutoDelete[PetInfo[1]].Value
			PetSlot.PetName.Value = PetInfo[1]

			local PetModel = ReplicatedStorage.Pets[PetInfo[1]]:Clone()
			PetModel.Parent = PetSlot.Pet

			local Pos = PetModel.MainPart.Position
			local Camera = Instance.new("Camera")
			PetSlot.Pet.CurrentCamera = Camera
			PetModel:PivotTo(PetModel:GetPivot() * CFrame.Angles(0, math.rad(180), 0))
			Camera.CFrame = CFrame.new(Vector3.new(Pos.X + PetModel:GetExtentsSize().X * 1.5, Pos.Y, Pos.Z + 1), Pos)
		end
	end
end

CurrentTarget.Changed:Connect(UpdatePreviewFrame)

function AutoDelete()
	for _, Pet in PreviewFrame.PetChances.List:GetChildren() do
		if not Pet:IsA("Frame") then continue end
		Pet.Button.MouseButton1Click:Connect(function()
			local Result = Remotes.AutoDelete:InvokeServer(Pet.PetName.Value)
			Pet.Delete.Visible = Result
			Utilities.Audio.PlayAudio("Click")
		end)		
	end
end

AutoDelete()

--// Egg Hatching
local IsAutoOpening = false

function HatchEgg(Egg: string, Result: string, Offset:number)
	local OpeningTime = 3

	local NewViewport = script.EggViewport:Clone()
	NewViewport.Parent = UI.OpenEgg

	Player.CameraMinZoomDistance = 15
	Frames.Visible = false
	UI[GameSettings.ButtonSide.Value].Buttons.Visible = false

	local Clone = workspace.Map.Eggs[Egg].EggModel:Clone()
	Clone:ScaleTo(0.5)
	Clone.Parent = workspace

	local Rot, X, Y, Z = Instance.new("NumberValue"), Instance.new("NumberValue"), Instance.new("NumberValue"), Instance.new("NumberValue")
	Rot.Value = 30 Z.Value = -4 X.Value = 10

	local Camera = workspace.CurrentCamera
	local PL = Instance.new("PointLight")
	PL.Shadows = false PL.Range = 4 PL.Brightness *= 1.5
	PL.Parent = Clone.Egg

	Clone:PivotTo(Camera:GetRenderCFrame()*CFrame.new(X,Y,Z))
	local CameraConnection1 = RunService.Heartbeat:Connect(function()
		local X, Y, Z = X.Value, Y.Value, Z.Value
		Clone:PivotTo(Camera:GetRenderCFrame()*CFrame.new(X,Y,Z)*CFrame.Angles(0,0,math.rad(Rot.Value)))
	end)

	local CameraConnection2 = Camera:GetPropertyChangedSignal("CFrame"):Connect(function()
		local X, Y, Z = X.Value, Y.Value, Z.Value
		Clone:PivotTo(Camera:GetRenderCFrame()*CFrame.new(X,Y,Z)*CFrame.Angles(0,0,math.rad(Rot.Value)))
	end)

	local TweenIn = TweenService:Create(X, TweenInfo.new(OpeningTime*0.2, Enum.EasingStyle.Back), {Value = Offset})
	TweenIn:Play()

	local RotTweenIn = TweenService:Create(Rot, TweenInfo.new(OpeningTime*0.2, Enum.EasingStyle.Back), {Value = 0})
	RotTweenIn:Play()

	-- add an audio for the egg flying in
	TweenIn.Completed:Wait()

	local Eggdelay = 0.075
	for i = 1,(OpeningTime * 1.5) + 1 do
		local Tween = TweenService:Create(Rot, TweenInfo.new(Eggdelay, Enum.EasingStyle.Back), {Value = 6})
		Tween:Play()
		-- add an audio for rotating here
		Tween.Completed:Wait()

		local Tween = TweenService:Create(Rot, TweenInfo.new(Eggdelay, Enum.EasingStyle.Back), {Value = -6})
		-- add an audio for rotating here
		Tween:Play()
		Tween.Completed:Wait()

		Eggdelay -= .005
	end

	CameraConnection1:Disconnect()
	CameraConnection2:Disconnect()	
	Clone:Destroy()	

	-- Now we're going to show the pet

	local PetModel = game.ReplicatedStorage.Pets[Result]:Clone()
	PetModel:ScaleTo(0.6)
	PetModel.Parent = workspace

	NewViewport.Deleted.Visible = Data.AutoDelete[Result].Value
	NewViewport.PetName.Text = Result
	NewViewport.PetName.Visible = true
	NewViewport.PetRarity.Text = game.ReplicatedStorage.Pets[Result].Settings.Rarity.Value
	NewViewport.PetRarity.Visible = true

	local PL = Instance.new("PointLight")
	PL.Shadows = false PL.Range = 4 PL.Brightness *= 2
	PL.Parent = PetModel.MainPart

	X.Value = Offset Y.Value = 0 Z.Value = -4 Rot.Value = 175
	local CameraConnection1 = RunService.Heartbeat:Connect(function()
		local X, Y, Z = X.Value, Y.Value, Z.Value
		PetModel:PivotTo(Camera:GetRenderCFrame()*CFrame.new(X,Y,Z) * CFrame.Angles(0, math.rad(Rot.Value), 0))
	end)

	local CameraConnection2 = Camera:GetPropertyChangedSignal("CFrame"):Connect(function()
		local X, Y, Z = X.Value, Y.Value, Z.Value
		PetModel:PivotTo(Camera:GetRenderCFrame()*CFrame.new(X,Y,Z) * CFrame.Angles(0, math.rad(Rot.Value), 0))
	end)

	task.wait(OpeningTime*0.25)

	NewViewport:TweenPosition(UDim2.new(NewViewport.Position.X.Scale, 0, NewViewport.Position.Y.Scale + 10, 0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, OpeningTime * 0.1)
	TweenService:Create(Y, TweenInfo.new(OpeningTime*0.15, Enum.EasingStyle.Back), {Value = -5}):Play()
	NewViewport.Deleted.Visible = false
	NewViewport.PetName.Visible = false
	NewViewport.PetRarity.Visible = false
	task.wait(OpeningTime * 0.15)

	CameraConnection1:Disconnect()
	CameraConnection2:Disconnect()
	X:Destroy() Y:Destroy() Z:Destroy() Rot:Destroy()

	PetModel:Destroy()
	NewViewport:Destroy()

	Player.CameraMinZoomDistance = 0.5
	UI[GameSettings.ButtonSide.Value].Buttons.Visible = true
	Frames.Visible = true	
end

Remotes.Egg.OnClientInvoke = HatchEgg

function SingleEgg()
	local Egg = CurrentTarget.Value

	local EggInfo = ReplicatedStorage.Eggs[Egg]

	if not EggInfo:FindFirstChild("ProductId") then
		local Result = Remotes.Egg:InvokeServer(Egg, 1)

		if Result ~= nil then
			HatchEgg(Egg, Result[1], 0)
		end
	else
		MarketPlaceService:PromptProductPurchase(Player, EggInfo.ProductId.Value)
	end
end

function TripleEgg()
	local Egg = CurrentTarget.Value

	local Result = Remotes.Egg:InvokeServer(Egg, 3)

	if Result ~= nil then
		for i = 1,#Result do
			coroutine.wrap(function()
				local Position = (i - 2) * 3
				HatchEgg(Egg, Result[i], Position)
			end)()
		end
	end
end

local function ChooseEggAmount(Egg)
	local EggInfo = ReplicatedStorage.Eggs[Egg]

	local EggAmount = 1

	if ReplicatedStorage.Gamepasses:FindFirstChild("TripleEgg") and not Player.Data.Gamepasses.TripleEgg.Value then 
		return EggAmount
	end -- triple egg is a gamepass that the player doesn't own, so open 1 egg

	if PlayerData.Currency.Value >= EggInfo.Cost.Value * 3 then
		EggAmount = 3
	end

	return EggAmount
end

function AutoEgg()
	if IsAutoOpening then return end

	if ReplicatedStorage.Gamepasses:FindFirstChild("AutoEgg") and not Player.Data.Gamepasses.AutoEgg.Value then 
		MarketPlaceService:PromptGamePassPurchase(ReplicatedStorage.Gamepasses.AutoEgg.Value)
		return
	end

	local Egg = CurrentTarget.Value	
	IsAutoOpening = true

	while true do
		if Player.NonSaveValues.IsOpeningEgg.Value then task.wait(0.1) continue end -- player is already opening an egg

		if CurrentTarget.Value == "None" or CurrentTarget.Value ~= Egg then
			IsAutoOpening = false
			break
		end

		local Result = Remotes.Egg:InvokeServer(Egg, ChooseEggAmount(Egg))

		if Result == nil then
			IsAutoOpening = false
			break
		end

		if #Result > 1 then
			for i = 1,#Result do
				coroutine.wrap(function()
					local Position = (i - 2) * 3
					HatchEgg(Egg, Result[i], Position)
				end)()
			end
		else
			HatchEgg(Egg, Result[1], 0)
		end

		task.wait(0.1)
	end
end

PreviewFrame.Buttons.Single.Click.MouseButton1Click:Connect(SingleEgg)
PreviewFrame.Buttons.Triple.Click.MouseButton1Click:Connect(TripleEgg)
PreviewFrame.Buttons.Auto.Click.MouseButton1Click:Connect(AutoEgg)

UserInputService.InputBegan:Connect(function(Input)
	if UserInputService:GetFocusedTextBox() ~= nil then return end

	if Input.KeyCode == Enum.KeyCode.E then SingleEgg() end
	if Input.KeyCode == Enum.KeyCode.R then TripleEgg() end
	if Input.KeyCode == Enum.KeyCode.T then AutoEgg() end
end)

--// Pet Follow
-- Credits to azypro777 for helping out with this part!
local Spacing, PetSize, MaxClimbHeight = 5, 3, 6

local RayParams = RaycastParams.new()
local RayDirection = Vector3.new(0, -500, 0)

local TempPets = Instance.new("Folder")
TempPets.Name = "PlayerPets"
TempPets.Parent = ReplicatedStorage

local function RearrangeTables(Pets, Rows, MaxRowCapacity)
	table.clear(Rows)
	local AmountOfRows = math.ceil(#Pets / MaxRowCapacity)
	for i = 1, AmountOfRows do
		table.insert(Rows, {})
	end
	for i, v in Pets do
		local Row = Rows[math.ceil(i / MaxRowCapacity)]
		table.insert(Row, v)
	end
end

local function GetRowWidth(Row, Pet)
	if Pet ~= nil then
		local MainPart = Pet:FindFirstChild("MainPart")

		if not MainPart then print("A pet equipped does not have a part called 'MainPart'") return end

		Pet.PrimaryPart = MainPart

		local SpacingBetweenPets = Spacing - MainPart.Size.X
		local RowWidth = 0

		if #Row == 1 then
			return 0
		end

		for i, v in Row do
			if i ~= #Row then
				RowWidth += MainPart.Size.X + SpacingBetweenPets
			else
				RowWidth += MainPart.Size.X
			end
		end

		return RowWidth
	end
end

function PetMovement()
	if not PlayerData.ShowOtherPets.Value then -- Show pets is false
		-- put the pets in "TempPets"
		for _, PetFolder in workspace.PlayerPets:GetChildren() do
			if PetFolder.Name == Player.Name then continue end 
			PetFolder.Parent = TempPets
		end
	else
		for _,v in TempPets:GetChildren() do
			v.Parent = workspace.PlayerPets
		end
	end

	for _, PlayerPets in workspace.PlayerPets:GetChildren() do
		local Character = Players[PlayerPets.Name].Character or Players[PlayerPets.Name].CharacterAdded:Wait()
		local HumanoidRootPart = Character.HumanoidRootPart

		local Pets, Rows = {}, {}		
		for _,Pet in PlayerPets:GetChildren() do
			table.insert(Pets, Pet)
		end

		RayParams.FilterDescendantsInstances = {workspace.PlayerPets, Character}
		local MaxRowCapacity = math.ceil(math.sqrt(#Pets))
		RearrangeTables(Pets, Rows, MaxRowCapacity)

		for i, Pet in Pets do
			local RowIndex = math.ceil(i / MaxRowCapacity)
			local Row = Rows[RowIndex]
			local RowWidth = GetRowWidth(Row, Pet)

			local XOffset = #Row == 1 and 0 or RowWidth/2 - Pet.PrimaryPart.Size.X/2
			local X = (table.find(Row, Pet) - 1) * Spacing
			local Z = RowIndex * Spacing
			local Y = 0

			local RayResult = workspace:Blockcast(Pet.PrimaryPart.CFrame + Vector3.new(0, MaxClimbHeight, 0), Pet.PrimaryPart.Size, RayDirection, RayParams)

			if RayResult then
				Y = RayResult.Position.Y + Pet.PrimaryPart.Size.Y/2
			end

			local TargetCFrame = CFrame.new(HumanoidRootPart.CFrame.X, 0, HumanoidRootPart.CFrame.Z) * HumanoidRootPart.CFrame.Rotation * CFrame.new(X - XOffset, Y, Z)
			local LerpedCFrame = Pet:GetPivot():Lerp(TargetCFrame, 0.1)
			Pet:PivotTo(LerpedCFrame)
		end
	end
end

--// Areas
function AreaDetection()
	while task.wait(0.1) do
		local Door = workspace.Map.Doors:FindFirstChild(tostring(PlayerData.BestZone.Value + 1))
		if not Door then task.wait(1) continue end -- Either max area or something went wrong

		local BoundBox = workspace:GetPartBoundsInBox(Door.CFrame, Door.Size + Vector3.new(2,2,2))

		for _,Part in BoundBox do
			if Part.Parent == Player.Character then
				if not Frames.Area.Visible then
					Utilities.ButtonHandler.OnClick(Frames.Area, UDim2.new(0.262,0,0.391,0))

					if ReplicatedStorage.Areas[Door.Name].Cost.Value ~= -1 then
						Frames.Area.Cost.Text = Utilities.Short.en(ReplicatedStorage.Areas[Door.Name].Cost.Value).." "..GameSettings.CurrencyName.Value
					else
						Frames.Area.Cost.Text = "Maxed"
					end
				end
				break
			end
		end
	end
end

coroutine.wrap(AreaDetection)()

function UpdateAllDoors()
	for _,Door in workspace.Map.Doors:GetChildren() do
		local IsVisible = PlayerData.BestZone.Value < tonumber(Door.Name)
		Door.Transparency = IsVisible and 0.35 or 1
		Door.CanCollide = IsVisible

		for _, Object in Door:GetDescendants() do
			if Object:IsA("TextLabel") then
				Object.TextTransparency = IsVisible and 0 or 1
			elseif Object:IsA("UIStroke") then
				Object.Transparency = IsVisible and 0 or 1
			end
		end
	end
end

UpdateAllDoors()
workspace.Map.Doors.ChildAdded:Connect(UpdateAllDoors)
PlayerData.BestZone.Changed:Connect(UpdateAllDoors)

-- Area Frame
Utilities.ButtonAnimations.Create(Frames.Area.Buy)

Frames.Area.Buy.Click.MouseButton1Click:Connect(function()
	Remotes.Area:FireServer()
	Utilities.Audio.PlayAudio("Click")
	task.wait(0.05)

	if Frames.Area.Visible then
		Utilities.ButtonHandler.OnClick(Frames.Area, UDim2.new(0,0,0,0))
	end 
end)

--// Tradng
local PlayerTradeTemplate = Frames.Trading.PlayerList.ObjectHolder.Template
PlayerTradeTemplate.Parent = script
PlayerTradeTemplate.Name = "PlayerTradeTemplate" -- this moves the template from the ui to the script (easier for people to edit :) 
local SendDefaultColor = PlayerTradeTemplate.Send.BackgroundColor3 -- the color of the button's default (incase a player changes the ui of it)

local TradeFrame = Frames.Trading
local PlayerTrade = TradeFrame.PlayerTrade

local TradeInfo = {}

local function AddPlayerToList(TargetPlayer)
	if Player ~= TargetPlayer then
		local Template = PlayerTradeTemplate:Clone()
		Utilities.ButtonAnimations.Create(Template.Send)

		if TargetPlayer.DisplayName == TargetPlayer.Name then
			Template.Title.Text = TargetPlayer.Name
		else
			Template.Title.Text = TargetPlayer.DisplayName .. " (@".. TargetPlayer.Name .. ")"
		end
		Template.Send.Click.MouseButton1Click:Connect(function()
			if Template.Send.Title.Text ~= "Sent" then
				Template.Send.Title.Text = "Sent"
				Template.Send.BackgroundColor3 = Color3.fromRGB(67, 130, 88)
				Remotes.Trading.RequestTrade:InvokeServer(TargetPlayer.Name)
				task.wait(2)
				Template.Send.Title.Text = "Send" -- change this if u have a different default text, such as "Request" instead of "Send"
				Template.Send.BackgroundColor3 = SendDefaultColor
			end
		end)

		Template.Name = TargetPlayer.Name
		Template.Parent = TradeFrame.PlayerList.ObjectHolder
	end
end

for _, TargetPlayer in Players:GetChildren() do
	AddPlayerToList(TargetPlayer)
end

Players.PlayerAdded:Connect(AddPlayerToList)

Players.PlayerRemoving:Connect(function(TargetPlayer)
	if Frames.Trading.PlayerList.ObjectHolder:FindFirstChild(TargetPlayer.Name) then
		Frames.Trading.PlayerList.ObjectHolder[TargetPlayer.Name]:Destroy()
	end
end)

Remotes.Trading.RequestTrade.OnClientInvoke = function(OtherPlayer) -- function is ran when someone sent you a trade request
	local NewTemplate = UI.TradeRequest:Clone()
	NewTemplate.TextLabel.Text = OtherPlayer.." has sent you a trade request!"

	Utilities.ButtonAnimations.Create(NewTemplate.Accept)
	NewTemplate.Accept.Button.MouseButton1Click:Connect(function()
		Utilities.Audio.PlayAudio("Click", 1)
		local Accepted = Remotes.Trading.StartTrade:InvokeServer(OtherPlayer)
		if Accepted then
			StartTrade(OtherPlayer)
			NewTemplate:Destroy()
		end
	end)

	Utilities.ButtonAnimations.Create(NewTemplate.Cancel)
	NewTemplate.Cancel.Button.MouseButton1Click:Connect(function()
		Utilities.Audio.PlayAudio("Click", 1)
		NewTemplate:Destroy()
	end)

	NewTemplate.Visible = true
	NewTemplate.Name = OtherPlayer
	NewTemplate.Parent = UI

	task.wait(10)
	NewTemplate:Destroy()
end

function StartTrade(OtherPlayer)	
	if not TradeFrame.Visible then
		Utilities.ButtonHandler.OnClick(TradeFrame, UDim2.new(0.359, 0, 0.414, 0))
	end

	TradeFrame.PlayerList.Visible = false
	PlayerTrade.Visible = true

	PlayerTrade.OtherPlayer.PlayerName.Text = OtherPlayer
	TradeInfo.OtherPlayer = OtherPlayer

	PlayerTrade.OtherPlayer.ReadyCover.Visible = false

	--// Clear Inventories Before Loading!
	for _, Frame in PlayerTrade.LocalPlayer.Inventory:GetChildren() do if Frame:IsA("Frame") then Frame:Destroy() end end
	for _, Frame in PlayerTrade.OtherPlayer.Inventory:GetChildren() do if Frame:IsA("Frame") then Frame:Destroy() end end
	PlayerTrade.OtherPlayer.Currency.TextLabel.Text = "0"

	--// Load Inventories
	local function PetClicked(Pet) -- whenever a pet in the inventory is clicked
		Pet.Button.MouseButton1Click:Connect(function()
			local Result = Remotes.Trading.ChangeOffer:InvokeServer(OtherPlayer, {OfferType = "Pet", ID = tonumber(Pet.Name)})
			print(Result)

			if Result == "Max" then 
				-- Max Storage, create a popup here
			elseif Result == "Added" then
				Pet.Equipped.Visible = true
			elseif Result == "Removed" then
				Pet.Equipped.Visible = false
			end
		end)
	end

	local SortTable1 = {}

	local function PetInfo(Player, Pet)
		local HoverUI = PlayerTrade.HoverDisplay

		Pet.MouseEnter:Connect(function()
			Utilities.Dropdown.Hover(Pet, HoverUI, PlayerTrade)

			local PetInstance = Player.Data.Pets[Pet.Name]
			HoverUI.Multiplier.Text = "x"..Utilities.Short.en(ReplicatedStorage.Pets[PetInstance.PetName.Value].Settings.Multiplier.Value)
			HoverUI.Rarity.Text = ReplicatedStorage.Pets[PetInstance.PetName.Value].Settings.Rarity.Value
			HoverUI.PetName.Text = PetInstance.PetName.Value
			HoverUI.ID.Text = "ID: "..Pet.Name
		end)
	end

	for _,v in Data.Pets:GetChildren() do -- load pets
		coroutine.wrap(function()
			local Pet = AddPet(v, SortTable1, PlayerTrade.LocalPlayer.Inventory)
			PetClicked(Pet)
			PetInfo(Player, Pet)
		end)()
	end

	SortInventory(SortTable1, PlayerTrade.LocalPlayer.Inventory)

	local SortTable2 = {}
	for _,v in Players[OtherPlayer].Data.Pets:GetChildren() do -- load pets
		coroutine.wrap(function()
			local Pet = AddPet(v, SortTable2, PlayerTrade.OtherPlayer.Inventory)
			PetInfo(Players[OtherPlayer], Pet)
		end)()
	end

	SortInventory(SortTable2, PlayerTrade.OtherPlayer.Inventory)
end

Remotes.Trading.StartTrade.OnClientInvoke = StartTrade

Remotes.Trading.TradeAction.OnClientInvoke = function(Args) -- function is ran when u add pets to a trade, add currency etc
	if Args.Option == "Cancel" then
		if TradeFrame.Visible then
			Utilities.ButtonHandler.OnClick(TradeFrame, TradeFrame.Size) --// close the trade
			PlayerTrade.Visible = false
			TradeFrame.PlayerList.Visible = true
		end
	elseif Args.Option == "Ready" then
		PlayerTrade.OtherPlayer.ReadyCover.Visible = Args.Option == "Ready" 
	elseif Args.Option == "Countdown" then
		PlayerTrade.OtherPlayer.ReadyCover.Visible = true

		if Args.Count == 0 then --// end trade
			PlayerTrade.TradeCountdown.Visible = false			

			if TradeFrame.Visible then
				Utilities.ButtonHandler.OnClick(TradeFrame, TradeFrame.Size) --// close the trade
				PlayerTrade.Visible = false
				TradeFrame.PlayerList.Visible = true
			end
		else
			PlayerTrade.TradeCountdown.Visible = true

			for i = Args.Count * 10, 1, -1 do
				if not Player.NonSaveValues.IsReady.Value then
					PlayerTrade.TradeCountdown.Visible = false
					break
				end
				PlayerTrade.TradeCountdown.Text = (i/10).." Seconds Left.."

				task.wait(0.1)
			end	

			PlayerTrade.TradeCountdown.Text = "Processing..."			
		end
	elseif Args.Option == "CountdownEnded" then
		PlayerTrade.TradeCountdown.Visible = false
	end
end

Remotes.Trading.ChangeOffer.OnClientInvoke = function(Action, Args) -- function is ran when u add pets to a trade, add currency etc
	if Action == "PetAdded" then
		PlayerTrade.OtherPlayer.Inventory[Args].Equipped.Visible = true
	elseif Action == "PetRemoved" then
		PlayerTrade.OtherPlayer.Inventory[Args].Equipped.Visible = false
	elseif Action == "TradeTokens" then
		PlayerTrade.OtherPlayer.Currency.TextLabel.Text = Args
	end
end

--// Cancel and Decline Buttons!
Utilities.ButtonAnimations.Create(PlayerTrade.OtherPlayer.Cancel)
PlayerTrade.OtherPlayer.Cancel.Button.MouseButton1Click:Connect(function()
	Utilities.Audio.PlayAudio("Click", 1)
	local Succes = Remotes.Trading.TradeAction:InvokeServer(TradeInfo.OtherPlayer, {Option = "Cancel"})
	if Succes and TradeFrame.Visible then
		Utilities.ButtonHandler.OnClick(TradeFrame, UDim2.new(TradeFrame.Size))
		PlayerTrade.Visible = false
		TradeFrame.PlayerList.Visible = true
	end	
end)

Utilities.ButtonAnimations.Create(PlayerTrade.OtherPlayer.Accept)
PlayerTrade.OtherPlayer.Accept.Button.MouseButton1Click:Connect(function()
	Utilities.Audio.PlayAudio("Click", 1)
	Remotes.Trading.TradeAction:InvokeServer(TradeInfo.OtherPlayer, {Option = "Ready"})
end)

Player.NonSaveValues.IsReady.Changed:Connect(function(Visible)
	PlayerTrade.LocalPlayer.ReadyCover.Visible = Visible
end)

--// Gem Shop
local Gemshop = ReplicatedStorage.GemShop
local Defaultwalkspeed = Player.Character.Humanoid.WalkSpeed

local function GemRing()
	while task.wait(0.1) do
		if (Player.Character.HumanoidRootPart.Position - workspace.Map.Rings.GemShop.MainPart.Position).Magnitude < 10 then
			if not Frames.GemShop.Visible then
				Utilities.ButtonHandler.OnClick(Frames.GemShop, UDim2.new(0.359,0,0.414,0))
			end
		end

		if Player.Character then
			local Walkspeed = Defaultwalkspeed + Gemshop["1"].Reward.DefaultReward.Value + Gemshop["1"].Reward.IncreasePer.Value * (PlayerData.GemUpgrade1.Value+1)
			Player.Character.Humanoid.WalkSpeed = Walkspeed
		end
	end
end

coroutine.wrap(GemRing)()

local GemUpgradeTemplate = Frames.GemShop.Upgrades.Template
GemUpgradeTemplate.Parent = script
GemUpgradeTemplate.Name = "GemUpgradeTemplate" -- this moves the template from the ui to the script (easier for people to edit :) 

for _,v in Gemshop:GetChildren() do
	local i = v.Name
	local NewUpgrade = GemUpgradeTemplate:Clone()
	NewUpgrade.LayoutOrder = tonumber(i)
	NewUpgrade.Name = i
	NewUpgrade.Title.Text = v.UpgradeName.Value

	local function CalcReward(Reward)
		local R = v.Reward

		if R.Exponential.Value then
			return R.DefaultReward.Value + R.IncreasePer.Value ^ Reward
		else
			return R.DefaultReward.Value + R.IncreasePer.Value * Reward
		end
	end

	local function CalcCost()
		local C = v.Price

		if C.Exponential.Value then
			return C.DefaultPrice.Value * C.IncreasePer.Value ^ PlayerData["GemUpgrade"..i].Value
		else
			return C.DefaultPrice.Value + C.IncreasePer.Value * (PlayerData["GemUpgrade"..i].Value+1)
		end
	end

	local function Update()
		local O = v.Operator.Value
		local CurrentLevel = PlayerData["GemUpgrade"..i].Value

		if CurrentLevel < v.Max.Value then
			NewUpgrade.Description.Text = O..Utilities.Short.en(CalcReward(CurrentLevel)).." > "..O..Utilities.Short.en(CalcReward(CurrentLevel+1))
			NewUpgrade.Buy.Amount.Text = Utilities.Short.en(CalcCost())
		else
			NewUpgrade.Description.Text = O..Utilities.Short.en(CalcReward(CurrentLevel)).." > Max"
			NewUpgrade.Buy.Amount.Text = "Max"
		end
	end

	Update()
	PlayerData["GemUpgrade"..i].Changed:Connect(Update)

	NewUpgrade.Parent = Frames.GemShop.Upgrades

	NewUpgrade.Buy.Click.MouseButton1Click:Connect(function()
		Remotes.GemUpgrade:FireServer(i)
	end)
end

--// Codes
local CodesFrame = Frames.Codes

CodesFrame.Redeem.MouseButton1Click:Connect(function()
	Remotes.RedeemCode:FireServer()
end)

--// Stats
local StatsFrame = Frames.Stats
StatsFrame.TotalCurrency.Description.Text = "Check how much Total "..GameSettings.CurrencyName.Value.." you have!"
StatsFrame.TotalCurrency.Title.Text = "Total "..GameSettings.CurrencyName.Value

-- Total Currency
StatsFrame.TotalCurrency.Stat.Amount.Text = Utilities.Short.en(PlayerData.TotalCurrency.Value)
PlayerData.TotalCurrency.Changed:Connect(function()
	StatsFrame.TotalCurrency.Stat.Amount.Text = Utilities.Short.en(PlayerData.TotalCurrency.Value)
end)

-- Eggs Hatched
StatsFrame.EggsHatched.Stat.Amount.Text = Utilities.Short.en(PlayerData.EggsHatched.Value)
PlayerData.EggsHatched.Changed:Connect(function()
	StatsFrame.EggsHatched.Stat.Amount.Text = Utilities.Short.en(PlayerData.EggsHatched.Value)
end)

--// Functions
function RenderStepped()
	PetMovement()
	FindEgg()
end

RunService.RenderStepped:Connect(RenderStepped)
