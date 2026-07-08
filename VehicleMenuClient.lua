-- VehicleMenuClient LocalScript in StarterPlayerScripts
--[[
	Vehicles menu UI:
	- GameUI.Frames.Vehicles.FirstButtons (OwnedVehiclesButton, DealershipButton)
	- GameUI.Frames.Vehicles.OwnedVehiclesFrame (ExampleVehicleButton template)
	- GameUI.Frames.Vehicles.DealershipFrame (ExampleVehicleButton template)
	- Optional owned vehicle customization UI:
	  InfoPanel (TeleportButton, CustomizeButton), MainCustomizeFrame (PartsButton),
	  PartsCustomizeFrame (FrontBumpersButton), FrontBumpersFrame (ExampleFrontBumperButton), Back.Click
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Utilities = require(Modules.Utilities)

local player = Players.LocalPlayer
repeat task.wait() until player:FindFirstChild("Loaded") and player.Loaded.Value or player.Parent == nil
if player.Parent == nil then return end

local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Vehicles")
local getMenuDataRemote = remotes:WaitForChild("GetMenuData")
local buyRemote = remotes:WaitForChild("Buy")
local spawnRemote = remotes:WaitForChild("Spawn")
local customizeRemote = remotes:WaitForChild("Customize")

local ui = player:WaitForChild("PlayerGui"):WaitForChild("GameUI")
local vehiclesFrame = ui:WaitForChild("Frames"):WaitForChild("Vehicles")
local firstButtons = vehiclesFrame:WaitForChild("FirstButtons")
local ownedFrame = vehiclesFrame:WaitForChild("OwnedVehiclesFrame")
local dealershipFrame = vehiclesFrame:WaitForChild("DealershipFrame")

local ownedButton = firstButtons:WaitForChild("OwnedVehiclesButton")
local dealershipButton = firstButtons:WaitForChild("DealershipButton")

local ownedTemplate = ownedFrame:WaitForChild("ExampleVehicleButton")
local dealershipTemplate = dealershipFrame:WaitForChild("ExampleVehicleButton")

local infoPanel = vehiclesFrame:FindFirstChild("InfoPanel")
local teleportButton = infoPanel and infoPanel:FindFirstChild("TeleportButton", true)
local customizeButton = infoPanel and infoPanel:FindFirstChild("CustomizeButton", true)
local mainCustomizeFrame = vehiclesFrame:FindFirstChild("MainCustomizeFrame")
local partsButton = mainCustomizeFrame and mainCustomizeFrame:FindFirstChild("PartsButton", true)
local partsCustomizeFrame = vehiclesFrame:FindFirstChild("PartsCustomizeFrame")
local frontBumpersButton = partsCustomizeFrame and partsCustomizeFrame:FindFirstChild("FrontBumpersButton", true)
local frontBumpersFrame = vehiclesFrame:FindFirstChild("FrontBumpersFrame")
local frontBumperTemplate = frontBumpersFrame and frontBumpersFrame:FindFirstChild("ExampleFrontBumperButton")
local backFrame = vehiclesFrame:FindFirstChild("Back")
local backButton = backFrame and backFrame:FindFirstChild("Click", true)

local activeTab: "Owned" | "Dealership" | nil = nil
local currentView = "Root"
local selectedVehicle = nil
local menuData = {catalog = {}, owned = {}, customizations = {frontBumpers = {}, equipped = {}}}
local isRefreshing = false
local isActionLocked = false

ownedTemplate.Visible = false
dealershipTemplate.Visible = false
ownedFrame.Visible = false
dealershipFrame.Visible = false
if infoPanel then infoPanel.Visible = false end
if mainCustomizeFrame then mainCustomizeFrame.Visible = false end
if partsCustomizeFrame then partsCustomizeFrame.Visible = false end
if frontBumpersFrame then frontBumpersFrame.Visible = false end
if frontBumperTemplate and frontBumperTemplate:IsA("GuiObject") then frontBumperTemplate.Visible = false end
if backFrame then backFrame.Visible = false end

local function getLabel(button: Instance): TextLabel?
	local label = button:FindFirstChild("ExampleLabel", true) or button:FindFirstChildWhichIsA("TextLabel", true)
	return label and label:IsA("TextLabel") and label or nil
end

local function clearGeneratedButtons(container: Instance, template: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiButton") and child ~= template then
			child:Destroy()
		end
	end
end

local function setStatus(message: string?)
	local status = vehiclesFrame:FindFirstChild("Status")
	if status and status:IsA("TextLabel") then
		status.Text = message or ""
	end
end

local function formatPrice(entry)
	return entry.owned and "Owned" or `{Utilities.Short.en(entry.price)} {entry.currencyName}`
end

local function refreshMenuData(selectedVehicleId: string?): boolean
	if isRefreshing then return false end
	isRefreshing = true
	local success, result = pcall(function()
		return getMenuDataRemote:InvokeServer(selectedVehicleId)
	end)
	isRefreshing = false
	if not success or type(result) ~= "table" then
		setStatus("Could not load vehicles")
		return false
	end
	menuData = result
	return true
end

local function getCatalogEntry(vehicleId: string)
	for _, entry in menuData.catalog do
		if entry.id == vehicleId then return entry end
	end
	return nil
end

local function showView(view: string)
	currentView = view
	ownedFrame.Visible = view == "Owned"
	dealershipFrame.Visible = view == "Dealership"
	if infoPanel then infoPanel.Visible = view == "Info" end
	if mainCustomizeFrame then mainCustomizeFrame.Visible = view == "MainCustomize" end
	if partsCustomizeFrame then partsCustomizeFrame.Visible = view == "PartsCustomize" end
	if frontBumpersFrame then frontBumpersFrame.Visible = view == "FrontBumpers" end
	if backFrame then backFrame.Visible = view ~= "Root" end
end

local function populateFrontBumpers()
	if not frontBumpersFrame or not frontBumperTemplate then return end
	clearGeneratedButtons(frontBumpersFrame, frontBumperTemplate)
	local data = menuData.customizations or {}
	for _, entry in data.frontBumpers or {} do
		local button = frontBumperTemplate:Clone()
		button.Name = entry.id
		button.Visible = true
		button.LayoutOrder = entry.layoutOrder or 0
		local label = getLabel(button)
		if label then label.Text = `{entry.displayName}\n{entry.equipped and "Equipped" or "Equip"}` end
		button.MouseButton1Click:Connect(function()
			if isActionLocked or not selectedVehicle then return end
			isActionLocked = true
			Utilities.Audio.PlayAudio("Click")
			local ok, result = pcall(function()
				return customizeRemote:InvokeServer(selectedVehicle.id, "FrontBumper", entry.id)
			end)
			isActionLocked = false
			if ok and type(result) == "table" and result.success then
				menuData.customizations = result.customizations or menuData.customizations
				setStatus(`Equipped {entry.displayName}`)
				populateFrontBumpers()
			else
				setStatus(ok and type(result) == "table" and result.reason or "Could not equip part")
			end
		end)
		button.Parent = frontBumpersFrame
	end
end

local function populateOwnedList()
	clearGeneratedButtons(ownedFrame, ownedTemplate)
	local ownedEntries = {}
	for _, entry in menuData.catalog do
		if entry.owned then table.insert(ownedEntries, entry) end
	end
	if #ownedEntries == 0 then setStatus("You do not own any vehicles yet") return end
	for _, entry in ownedEntries do
		local button = ownedTemplate:Clone()
		button.Name = entry.id
		button.Visible = true
		button.LayoutOrder = entry.layoutOrder or 0
		local label = getLabel(button)
		if label then label.Text = `{entry.displayName}\nTap for options` end
		button.MouseButton1Click:Connect(function()
			Utilities.Audio.PlayAudio("Click")
			selectedVehicle = entry
			setStatus(`Selected {entry.displayName}`)
			showView("Info")
		end)
		button.Parent = ownedFrame
	end
end

local function populateDealershipList()
	clearGeneratedButtons(dealershipFrame, dealershipTemplate)
	if #menuData.catalog == 0 then setStatus("No vehicles are configured yet") return end
	for _, entry in menuData.catalog do
		local button = dealershipTemplate:Clone()
		button.Name = entry.id
		button.Visible = true
		button.LayoutOrder = entry.layoutOrder or 0
		local label = getLabel(button)
		if label then label.Text = entry.owned and `{entry.displayName}\nOwned` or `{entry.displayName}\n{formatPrice(entry)}` end
		button.MouseButton1Click:Connect(function()
			if entry.owned then setStatus("You already own this vehicle") Utilities.Audio.PlayAudio("Click") return end
			if isActionLocked then return end
			isActionLocked = true
			Utilities.Audio.PlayAudio("Click")
			local buySuccess, buyResult = pcall(function() return buyRemote:InvokeServer(entry.id) end)
			isActionLocked = false
			if buySuccess and type(buyResult) == "table" and buyResult.success then
				menuData = buyResult.menu or menuData
				setStatus(`Purchased {entry.displayName}`)
				populateDealershipList()
			else
				setStatus(buySuccess and type(buyResult) == "table" and buyResult.reason or "Purchase failed")
			end
		end)
		button.Parent = dealershipFrame
	end
end

local function renderActiveTab()
	if activeTab == "Owned" then populateOwnedList() elseif activeTab == "Dealership" then populateDealershipList() end
end

local function setActiveTab(tab: "Owned" | "Dealership" | nil)
	activeTab = tab
	selectedVehicle = nil
	setStatus(nil)
	showView(tab or "Root")
	if tab ~= nil then renderActiveTab() end
end

local function openTab(tab: "Owned" | "Dealership")
	if refreshMenuData() then setActiveTab(tab) end
end

ownedButton.MouseButton1Click:Connect(function() Utilities.Audio.PlayAudio("Click") openTab("Owned") end)
dealershipButton.MouseButton1Click:Connect(function() Utilities.Audio.PlayAudio("Click") openTab("Dealership") end)

if teleportButton and teleportButton:IsA("GuiButton") then
	teleportButton.MouseButton1Click:Connect(function()
		if isActionLocked or not selectedVehicle then return end
		isActionLocked = true
		Utilities.Audio.PlayAudio("Click")
		local spawnSuccess, spawnResult = pcall(function() return spawnRemote:InvokeServer(selectedVehicle.id) end)
		isActionLocked = false
		if spawnSuccess and type(spawnResult) == "table" and spawnResult.success then
			setStatus(`Spawned {selectedVehicle.displayName}`)
		else
			setStatus(spawnSuccess and type(spawnResult) == "table" and spawnResult.reason or "Could not spawn vehicle")
		end
	end)
end

if customizeButton and customizeButton:IsA("GuiButton") then
	customizeButton.MouseButton1Click:Connect(function() Utilities.Audio.PlayAudio("Click") showView("MainCustomize") end)
end
if partsButton and partsButton:IsA("GuiButton") then
	partsButton.MouseButton1Click:Connect(function() Utilities.Audio.PlayAudio("Click") showView("PartsCustomize") end)
end
if frontBumpersButton and frontBumpersButton:IsA("GuiButton") then
	frontBumpersButton.MouseButton1Click:Connect(function()
		Utilities.Audio.PlayAudio("Click")
		if refreshMenuData(selectedVehicle and selectedVehicle.id or nil) then populateFrontBumpers() end
		showView("FrontBumpers")
	end)
end
if backButton and backButton:IsA("GuiButton") then
	backButton.MouseButton1Click:Connect(function()
		Utilities.Audio.PlayAudio("Click")
		if currentView == "FrontBumpers" then showView("PartsCustomize")
		elseif currentView == "PartsCustomize" then showView("MainCustomize")
		elseif currentView == "MainCustomize" then showView("Info")
		elseif currentView == "Info" then setActiveTab("Owned")
		elseif currentView == "Owned" or currentView == "Dealership" then setActiveTab(nil)
		else setActiveTab(nil) end
	end)
end

vehiclesFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if vehiclesFrame.Visible then
		setActiveTab(nil)
		refreshMenuData()
	else
		setActiveTab(nil)
	end
end)

local vehiclesFolder = player:WaitForChild("Data"):WaitForChild("Vehicles")
vehiclesFolder.ChildAdded:Connect(function(child)
	if child:IsA("BoolValue") then
		child.Changed:Connect(function()
			if vehiclesFrame.Visible and activeTab ~= nil and refreshMenuData() then renderActiveTab() end
		end)
	end
	if vehiclesFrame.Visible and activeTab ~= nil and refreshMenuData() then renderActiveTab() end
end)

for _, ownedValue in vehiclesFolder:GetChildren() do
	if ownedValue:IsA("BoolValue") then
		ownedValue.Changed:Connect(function()
			if vehiclesFrame.Visible and activeTab ~= nil and refreshMenuData() then renderActiveTab() end
		end)
	end
end
