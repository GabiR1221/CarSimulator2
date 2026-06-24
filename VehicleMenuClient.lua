-- VehicleMenuClient LocalScript in StarterPlayerScripts
--[[
	Vehicles menu UI:
	- GameUI.Frames.Vehicles.FirstButtons (OwnedVehiclesButton, DealershipButton)
	- GameUI.Frames.Vehicles.OwnedVehiclesFrame (ExampleVehicleButton template)
	- GameUI.Frames.Vehicles.DealershipFrame (ExampleVehicleButton template)
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

local ui = player:WaitForChild("PlayerGui"):WaitForChild("GameUI")
local vehiclesFrame = ui:WaitForChild("Frames"):WaitForChild("Vehicles")
local firstButtons = vehiclesFrame:WaitForChild("FirstButtons")
local ownedFrame = vehiclesFrame:WaitForChild("OwnedVehiclesFrame")
local dealershipFrame = vehiclesFrame:WaitForChild("DealershipFrame")

local ownedButton = firstButtons:WaitForChild("OwnedVehiclesButton")
local dealershipButton = firstButtons:WaitForChild("DealershipButton")

local ownedTemplate = ownedFrame:WaitForChild("ExampleVehicleButton")
local dealershipTemplate = dealershipFrame:WaitForChild("ExampleVehicleButton")

local activeTab: "Owned" | "Dealership" | nil = nil
local menuData = {catalog = {}, owned = {}}
local isRefreshing = false
local isActionLocked = false

ownedTemplate.Visible = false
dealershipTemplate.Visible = false
ownedFrame.Visible = false
dealershipFrame.Visible = false

local function getLabel(button: Instance): TextLabel?
	local label = button:FindFirstChild("ExampleLabel", true)
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
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
	if entry.owned then
		return "Owned"
	end

	return `{Utilities.Short.en(entry.price)} {entry.currencyName}`
end

local function refreshMenuData(): boolean
	if isRefreshing then
		return false
	end

	isRefreshing = true
	local success, result = pcall(function()
		return getMenuDataRemote:InvokeServer()
	end)
	isRefreshing = false

	if not success or type(result) ~= "table" then
		setStatus("Could not load vehicles")
		return false
	end

	menuData = result
	return true
end

local function populateOwnedList()
	clearGeneratedButtons(ownedFrame, ownedTemplate)

	local ownedEntries = {}
	for _, entry in menuData.catalog do
		if entry.owned then
			table.insert(ownedEntries, entry)
		end
	end

	if #ownedEntries == 0 then
		setStatus("You do not own any vehicles yet")
		return
	end

	for _, entry in ownedEntries do
		local button = ownedTemplate:Clone()
		button.Name = entry.id
		button.Visible = true
		button.LayoutOrder = entry.layoutOrder or 0

		local label = getLabel(button)
		if label then
			label.Text = `{entry.displayName}\nTap to spawn`
		end

		button.MouseButton1Click:Connect(function()
			if isActionLocked then return end
			isActionLocked = true
			Utilities.Audio.PlayAudio("Click")

			local spawnSuccess, spawnResult = pcall(function()
				return spawnRemote:InvokeServer(entry.id)
			end)

			isActionLocked = false

			if spawnSuccess and type(spawnResult) == "table" then
				if spawnResult.success then
					setStatus(`Spawned {entry.displayName}`)
				else
					setStatus(spawnResult.reason or "Could not spawn vehicle")
				end
			else
				setStatus("Could not spawn vehicle")
			end
		end)

		button.Parent = ownedFrame
	end
end

local function populateDealershipList()
	clearGeneratedButtons(dealershipFrame, dealershipTemplate)

	if #menuData.catalog == 0 then
		setStatus("No vehicles are configured yet")
		return
	end

	for _, entry in menuData.catalog do
		local button = dealershipTemplate:Clone()
		button.Name = entry.id
		button.Visible = true
		button.LayoutOrder = entry.layoutOrder or 0

		local label = getLabel(button)
		if label then
			if entry.owned then
				label.Text = `{entry.displayName}\nOwned`
			else
				label.Text = `{entry.displayName}\n{formatPrice(entry)}`
			end
		end

		button.MouseButton1Click:Connect(function()
			if entry.owned then
				setStatus("You already own this vehicle")
				Utilities.Audio.PlayAudio("Click")
				return
			end

			if isActionLocked then return end
			isActionLocked = true
			Utilities.Audio.PlayAudio("Click")

			local buySuccess, buyResult = pcall(function()
				return buyRemote:InvokeServer(entry.id)
			end)

			isActionLocked = false

			if buySuccess and type(buyResult) == "table" then
				if buyResult.success then
					menuData = buyResult.menu or menuData
					setStatus(`Purchased {entry.displayName}`)
					populateDealershipList()
					if activeTab == "Owned" then
						populateOwnedList()
					end
				else
					setStatus(buyResult.reason or "Purchase failed")
				end
			else
				setStatus("Purchase failed")
			end
		end)

		button.Parent = dealershipFrame
	end
end

local function renderActiveTab()
	if activeTab == "Owned" then
		populateOwnedList()
	elseif activeTab == "Dealership" then
		populateDealershipList()
	end
end

local function setActiveTab(tab: "Owned" | "Dealership" | nil)
	activeTab = tab
	ownedFrame.Visible = tab == "Owned"
	dealershipFrame.Visible = tab == "Dealership"
	setStatus(nil)

	if tab ~= nil then
		renderActiveTab()
	end
end

local function openTab(tab: "Owned" | "Dealership")
	if not refreshMenuData() then
		return
	end

	setActiveTab(tab)
end

ownedButton.MouseButton1Click:Connect(function()
	Utilities.Audio.PlayAudio("Click")
	openTab("Owned")
end)

dealershipButton.MouseButton1Click:Connect(function()
	Utilities.Audio.PlayAudio("Click")
	openTab("Dealership")
end)

vehiclesFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if vehiclesFrame.Visible then
		setActiveTab(nil)
		refreshMenuData()
	else
		setActiveTab(nil)
	end
end)

local vehiclesFolder = player:WaitForChild("Data"):WaitForChild("Vehicles")
vehiclesFolder.ChildAdded:Connect(function()
	if vehiclesFrame.Visible and activeTab ~= nil and refreshMenuData() then
		renderActiveTab()
	end
end)

for _, ownedValue in vehiclesFolder:GetChildren() do
	if ownedValue:IsA("BoolValue") then
		ownedValue.Changed:Connect(function()
			if vehiclesFrame.Visible and activeTab ~= nil and refreshMenuData() then
				renderActiveTab()
			end
		end)
	end
end
