-- VehicleMenuClient LocalScript in StarterPlayerScripts
-- Dynamic vehicle menu and customization UI.

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
local backFrame = vehiclesFrame:FindFirstChild("Back")
local backButton = backFrame and backFrame:FindFirstChild("Click", true)
local rootColorsFrame = vehiclesFrame:FindFirstChild("ColorsFrame")

local SECTION_BUTTONS = {Exterior = "ExteriorButton", Interior = "InteriorButton", Wheels = "WheelsButton"}
local DEFAULT_SLOT_BUTTONS = {FrontBumper = "FrontBumpersButton", BackBumper = "BackBumpersButton", Tire = "TiresButton", Rim = "RimsButton", Dashboard = "DashboardButton"}
local DEFAULT_TEMPLATES = {FrontBumper = "ExampleFrontBumperButton", BackBumper = "ExampleBackBumperButton", Tire = "ExampleTiresButton", Rim = "ExampleRimsButton", Dashboard = "ExampleDashboardButton"}

local activeTab: "Owned" | "Dealership" | nil = nil
local currentView = "Root"
local selectedVehicle = nil
local selectedSectionName: string? = nil
local selectedSlotName: string? = nil
local menuData = {catalog = {}, owned = {}, customizations = {sections = {}, equipped = {}, colors = {}}}
local isRefreshing = false
local isActionLocked = false

ownedTemplate.Visible = false
dealershipTemplate.Visible = false
ownedFrame.Visible = false
dealershipFrame.Visible = false
if infoPanel then infoPanel.Visible = false end
if mainCustomizeFrame then mainCustomizeFrame.Visible = false end
if backFrame then backFrame.Visible = false end
if rootColorsFrame and rootColorsFrame:IsA("GuiObject") then rootColorsFrame.Visible = false end

for _, child in vehiclesFrame:GetChildren() do
	if child:IsA("GuiObject") and (child.Name:match("CustomizeFrame$") or child.Name:match("Frame$")) and child ~= ownedFrame and child ~= dealershipFrame and child ~= infoPanel and child ~= mainCustomizeFrame and child ~= backFrame and child ~= firstButtons then
		child.Visible = false
		local template = child:FindFirstChildWhichIsA("GuiButton")
		if template and template.Name:match("^Example") then template.Visible = false end
	end
end

local function getLabel(button: Instance): TextLabel?
	local label = button:FindFirstChild("ExampleLabel", true) or button:FindFirstChildWhichIsA("TextLabel", true)
	return label and label:IsA("TextLabel") and label or nil
end

local function getOrCreateButtonLabel(button: GuiButton): TextLabel?
	local label = getLabel(button)
	if label then return label end
	if not button:IsA("ImageButton") then return nil end
	label = Instance.new("TextLabel")
	label.Name = "GeneratedLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = button
	return label
end

local function clearGeneratedButtons(container: Instance, template: Instance?)
	for _, child in container:GetChildren() do
		if child:IsA("GuiButton") and child ~= template and not child:GetAttribute("StaticCustomizeButton") then child:Destroy() end
	end
end

local function setStatus(message: string?)
	local status = vehiclesFrame:FindFirstChild("Status")
	if status and status:IsA("TextLabel") then status.Text = message or "" end
end

local function formatPrice(entry)
	return entry.owned and "Owned" or `{Utilities.Short.en(entry.price)} {entry.currencyName}`
end

local function refreshMenuData(selectedVehicleId: string?): boolean
	if isRefreshing then return false end
	isRefreshing = true
	local success, result = pcall(function() return getMenuDataRemote:InvokeServer(selectedVehicleId) end)
	isRefreshing = false
	if not success or type(result) ~= "table" then setStatus("Could not load vehicles"); return false end
	menuData = result
	return true
end

local function showGuiWithAncestors(guiObject: GuiObject)
	local current: Instance? = guiObject
	while current and current ~= vehiclesFrame do
		if current:IsA("GuiObject") then current.Visible = true end
		current = current.Parent
	end
end

local function hideCustomizationFrames()
	if mainCustomizeFrame then mainCustomizeFrame.Visible = false end
	if rootColorsFrame and rootColorsFrame:IsA("GuiObject") then rootColorsFrame.Visible = false end
	for _, section in menuData.customizations.sections or {} do
		local sectionFrame = vehiclesFrame:FindFirstChild(section.frame, true)
		if sectionFrame and sectionFrame:IsA("GuiObject") then sectionFrame.Visible = false end
		for _, slot in section.slots do
			local slotFrame = vehiclesFrame:FindFirstChild(slot.frame, true)
			if slotFrame and slotFrame:IsA("GuiObject") then slotFrame.Visible = false end
		end
	end
end

local function showView(view: string)
	currentView = view
	ownedFrame.Visible = view == "Owned"
	dealershipFrame.Visible = view == "Dealership"
	if infoPanel then infoPanel.Visible = view == "Info" end
	hideCustomizationFrames()
	if view == "MainCustomize" and mainCustomizeFrame then mainCustomizeFrame.Visible = true end
	if view == "Section" and selectedSectionName then
		local section = menuData.customizations.sections[selectedSectionName]
		local frame = section and vehiclesFrame:FindFirstChild(section.frame, true)
		if frame and frame:IsA("GuiObject") then showGuiWithAncestors(frame) end
	end
	if view == "Slot" and selectedSectionName and selectedSlotName then
		local slot = menuData.customizations.sections[selectedSectionName].slots[selectedSlotName]
		local frame = slot and vehiclesFrame:FindFirstChild(slot.frame, true)
		if frame and frame:IsA("GuiObject") then showGuiWithAncestors(frame) end
	end
	if backFrame then backFrame.Visible = view ~= "Root" end
end

local function getColorFromButton(button: GuiButton): Color3
	local attr = button:GetAttribute("Color")
	if typeof(attr) == "Color3" then return attr end
	if button:IsA("TextButton") and button.BackgroundColor3 then return button.BackgroundColor3 end
	if button:IsA("ImageButton") then return button.BackgroundColor3 end
	return Color3.new(1, 1, 1)
end

local function findColorsFrame(container: Instance): Instance?
	local colorsFrame = container:FindFirstChild("ColorsFrame", true)
	if colorsFrame then return colorsFrame end
	local parent = container.Parent
	while parent and parent ~= vehiclesFrame do
		colorsFrame = parent:FindFirstChild("ColorsFrame", true)
		if colorsFrame then return colorsFrame end
		parent = parent.Parent
	end
	return rootColorsFrame
end

local function bindColorsFrame(container: Instance, slotName: string)
	local colorsFrame = findColorsFrame(container)
	if not colorsFrame or not colorsFrame:IsA("GuiObject") then setStatus("Add a ColorsFrame inside this customization frame"); return end
	colorsFrame.Visible = true
	for _, button in colorsFrame:GetDescendants() do
		if button:IsA("GuiButton") and not button:GetAttribute(`ColorBound_{slotName}`) then
			button:SetAttribute(`ColorBound_{slotName}`, true)
			button.MouseButton1Click:Connect(function()
				if isActionLocked or not selectedVehicle then return end
				isActionLocked = true
				Utilities.Audio.PlayAudio("Click")
				local ok, result = pcall(function() return customizeRemote:InvokeServer(selectedVehicle.id, slotName, nil, getColorFromButton(button)) end)
				isActionLocked = false
				if ok and type(result) == "table" and result.success then menuData.customizations = result.customizations or menuData.customizations; setStatus("Color changed") else setStatus(ok and type(result) == "table" and result.reason or "Could not change color") end
			end)
		end
	end
end

local function populateSlot(sectionName: string, slotName: string)
	local section = menuData.customizations.sections[sectionName]
	local slot = section and section.slots[slotName]
	if not slot then return end
	local frame = vehiclesFrame:FindFirstChild(slot.frame, true)
	if not frame then return end
	local template = frame:FindFirstChild(DEFAULT_TEMPLATES[slotName] or `Example{slotName}Button`) or frame:FindFirstChildWhichIsA("GuiButton")
	if template and template:IsA("GuiObject") then template.Visible = false end
	clearGeneratedButtons(frame, template)
	if slot.mode == "ColorOnly" then
		bindColorsFrame(frame, slotName)
		setStatus("Pick a color for this customization")
		return
	end
	if #(slot.items or {}) == 0 then
		setStatus(`No {slot.displayName or slotName} options found in ReplicatedStorage.VehicleCustomizations`)
	end
	for _, entry in slot.items or {} do
		local button = template and template:Clone() or Instance.new("TextButton")
		button.Name = entry.id
		button.Visible = true
		button.LayoutOrder = entry.layoutOrder or 0
		local label = getOrCreateButtonLabel(button)
		if label then label.Text = `{entry.displayName}\n{entry.equipped and "Equipped" or "Equip"}` elseif button:IsA("TextButton") then button.Text = `{entry.displayName} - {entry.equipped and "Equipped" or "Equip"}` end
		button.MouseButton1Click:Connect(function()
			if isActionLocked or not selectedVehicle then return end
			isActionLocked = true
			Utilities.Audio.PlayAudio("Click")
			local ok, result = pcall(function() return customizeRemote:InvokeServer(selectedVehicle.id, slotName, entry.id, nil) end)
			isActionLocked = false
			if ok and type(result) == "table" and result.success then menuData.customizations = result.customizations or menuData.customizations; setStatus(`Equipped {entry.displayName}`); populateSlot(sectionName, slotName) else setStatus(ok and type(result) == "table" and result.reason or "Could not equip part") end
		end)
		button.Parent = frame
	end
	bindColorsFrame(frame, slotName)
end

local function populateSection(sectionName: string)
	local section = menuData.customizations.sections[sectionName]
	if not section then return end
	local frame = vehiclesFrame:FindFirstChild(section.frame, true)
	if not frame then return end
	for slotName, slot in section.slots do
		local button = frame:FindFirstChild(DEFAULT_SLOT_BUTTONS[slotName] or `{slotName}Button`, true)
		if button and button:IsA("GuiButton") then
			button.Visible = true
			if button:GetAttribute("SlotBound") then continue end
			button:SetAttribute("SlotBound", true)
			button.MouseButton1Click:Connect(function()
				Utilities.Audio.PlayAudio("Click")
				if refreshMenuData(selectedVehicle and selectedVehicle.id or nil) then
					selectedSectionName = sectionName
					selectedSlotName = slotName
					showView("Slot")
					populateSlot(sectionName, slotName)
				end
			end)
		end
	end
end

local function populateMainCustomize()
	if not mainCustomizeFrame then return end
	for sectionName, section in menuData.customizations.sections or {} do
		local button = mainCustomizeFrame:FindFirstChild(SECTION_BUTTONS[sectionName] or `{sectionName}Button`, true)
		if button and button:IsA("GuiButton") then
			local hasAvailableSlot = false
			for _, slot in section.slots do
				if slot.available ~= false then hasAvailableSlot = true; break end
			end
			button.Visible = hasAvailableSlot
			if button:GetAttribute("SectionBound") then continue end
			button:SetAttribute("SectionBound", true)
			button.MouseButton1Click:Connect(function()
				Utilities.Audio.PlayAudio("Click")
				if refreshMenuData(selectedVehicle and selectedVehicle.id or nil) then selectedSectionName = sectionName; populateSection(sectionName) end
				showView("Section")
			end)
		end
	end
end

local function populateOwnedList()
	clearGeneratedButtons(ownedFrame, ownedTemplate)
	local count = 0
	for _, entry in menuData.catalog do
		if not entry.owned then continue end
		count += 1
		local button = ownedTemplate:Clone(); button.Name = entry.id; button.Visible = true; button.LayoutOrder = entry.layoutOrder or 0
		local label = getLabel(button); if label then label.Text = `{entry.displayName}\nTap for options` end
		button.MouseButton1Click:Connect(function() Utilities.Audio.PlayAudio("Click"); selectedVehicle = entry; setStatus(`Selected {entry.displayName}`); showView("Info") end)
		button.Parent = ownedFrame
	end
	if count == 0 then setStatus("You do not own any vehicles yet") end
end

local function populateDealershipList()
	clearGeneratedButtons(dealershipFrame, dealershipTemplate)
	if #menuData.catalog == 0 then setStatus("No vehicles are configured yet") return end
	for _, entry in menuData.catalog do
		local button = dealershipTemplate:Clone(); button.Name = entry.id; button.Visible = true; button.LayoutOrder = entry.layoutOrder or 0
		local label = getLabel(button); if label then label.Text = entry.owned and `{entry.displayName}\nOwned` or `{entry.displayName}\n{formatPrice(entry)}` end
		button.MouseButton1Click:Connect(function()
			if entry.owned then setStatus("You already own this vehicle"); Utilities.Audio.PlayAudio("Click"); return end
			if isActionLocked then return end
			isActionLocked = true; Utilities.Audio.PlayAudio("Click")
			local ok, result = pcall(function() return buyRemote:InvokeServer(entry.id) end)
			isActionLocked = false
			if ok and type(result) == "table" and result.success then menuData = result.menu or menuData; setStatus(`Purchased {entry.displayName}`); populateDealershipList() else setStatus(ok and type(result) == "table" and result.reason or "Purchase failed") end
		end)
		button.Parent = dealershipFrame
	end
end

local function renderActiveTab()
	if activeTab == "Owned" then populateOwnedList() elseif activeTab == "Dealership" then populateDealershipList() end
end

local function setActiveTab(tab: "Owned" | "Dealership" | nil)
	activeTab = tab; selectedVehicle = nil; selectedSectionName = nil; selectedSlotName = nil; setStatus(nil); showView(tab or "Root"); if tab ~= nil then renderActiveTab() end
end

local function openTab(tab: "Owned" | "Dealership") if refreshMenuData() then setActiveTab(tab) end end
ownedButton.MouseButton1Click:Connect(function() Utilities.Audio.PlayAudio("Click"); openTab("Owned") end)
dealershipButton.MouseButton1Click:Connect(function() Utilities.Audio.PlayAudio("Click"); openTab("Dealership") end)

if teleportButton and teleportButton:IsA("GuiButton") then
	teleportButton.MouseButton1Click:Connect(function()
		if isActionLocked or not selectedVehicle then return end
		isActionLocked = true; Utilities.Audio.PlayAudio("Click")
		local ok, result = pcall(function() return spawnRemote:InvokeServer(selectedVehicle.id) end)
		isActionLocked = false
		if ok and type(result) == "table" and result.success then setStatus(`Spawned {selectedVehicle.displayName}`) else setStatus(ok and type(result) == "table" and result.reason or "Could not spawn vehicle") end
	end)
end

if customizeButton and customizeButton:IsA("GuiButton") then
	customizeButton.MouseButton1Click:Connect(function() Utilities.Audio.PlayAudio("Click"); if refreshMenuData(selectedVehicle and selectedVehicle.id or nil) then populateMainCustomize() end; showView("MainCustomize") end)
end

if backButton and backButton:IsA("GuiButton") then
	backButton.MouseButton1Click:Connect(function()
		Utilities.Audio.PlayAudio("Click")
		if currentView == "Slot" then showView("Section") elseif currentView == "Section" then showView("MainCustomize") elseif currentView == "MainCustomize" then showView("Info") elseif currentView == "Info" then setActiveTab("Owned") elseif currentView == "Owned" or currentView == "Dealership" then setActiveTab(nil) else setActiveTab(nil) end
	end)
end

vehiclesFrame:GetPropertyChangedSignal("Visible"):Connect(function() if vehiclesFrame.Visible then setActiveTab(nil); refreshMenuData() else setActiveTab(nil) end end)

local vehiclesFolder = player:WaitForChild("Data"):WaitForChild("Vehicles")
local function onOwnedChanged() if vehiclesFrame.Visible and activeTab ~= nil and refreshMenuData() then renderActiveTab() end end
vehiclesFolder.ChildAdded:Connect(function(child) if child:IsA("BoolValue") then child.Changed:Connect(onOwnedChanged) end; onOwnedChanged() end)
for _, ownedValue in vehiclesFolder:GetChildren() do if ownedValue:IsA("BoolValue") then ownedValue.Changed:Connect(onOwnedChanged) end end

