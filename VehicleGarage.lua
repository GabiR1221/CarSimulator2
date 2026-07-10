-- VehicleGarage Module in ReplicatedStorage.Modules
-- Server-side ownership, purchasing, spawning, and vehicle customizations. Only require this from server scripts.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vehicle = require(ReplicatedStorage.Modules.Vehicle)
local VehicleCatalog = require(ReplicatedStorage.Modules.VehicleCatalog)

local VEHICLE_TAG = "Vehicle"
local SPAWN_DISTANCE = 10
local SPAWN_COOLDOWN = 1.5
local BUY_COOLDOWN = 0.5

local CUSTOMIZATION_SECTIONS = {
	Exterior = {
		frame = "ExteriorCustomizeFrame",
		slots = {
			FrontBumper = {folder = "FrontBumpers", frame = "FrontBumpersFrame", mode = "ReplaceAndColor", attachment = "FrontBumperAttachment"},
			BackBumper = {folder = "BackBumpers", frame = "BackBumpersFrame", mode = "ReplaceAndColor", attachment = "BackBumperAttachment"},
		},
	},
	Interior = {
		frame = "InteriorCustomizeFrame",
		slots = {
			Dashboard = {folder = "Dashboard", frame = "DashboardFrame", mode = "ColorOnly", interior = true, targetNames = {"Dashboard", "Dash"}, targetPrefixes = {"dashboard"}},
		},
	},
	Wheels = {
		frame = "WheelsCustomizeFrame",
		slots = {
			Tire = {folder = "Tire", frame = "TiresFrame", mode = "ReplaceAndColor", wheelPartName = "Tire"},
			Rim = {folder = "Rim", frame = "RimsFrame", mode = "ReplaceAndColor", wheelPartName = "Rim"},
		},
	},
}

local VehicleGarage = {}
local spawnedVehicles: {[Player]: Model} = {}
local spawnCooldowns: {[Player]: number} = {}
local buyCooldowns: {[Player]: number} = {}

local function getPlayerVehiclesFolder(player: Player): Folder?
	local data = player:FindFirstChild("Data")
	return data and data:FindFirstChild("Vehicles") or nil
end

local function getPlayerVehicleValue(player: Player, vehicleId: string): BoolValue?
	local vehiclesFolder = getPlayerVehiclesFolder(player)
	local owned = vehiclesFolder and vehiclesFolder:FindFirstChild(vehicleId)
	return owned and owned:IsA("BoolValue") and owned or nil
end

local function getPlayerCustomizationsFolder(player: Player): Folder?
	local data = player:FindFirstChild("Data")
	return data and data:FindFirstChild("VehicleCustomizations") or nil
end

local function getOrCreateVehicleCustomizationFolder(player: Player, vehicleId: string): Folder?
	local customizationsFolder = getPlayerCustomizationsFolder(player)
	if not customizationsFolder then return nil end
	local vehicleFolder = customizationsFolder:FindFirstChild(vehicleId)
	if not vehicleFolder then
		vehicleFolder = Instance.new("Folder")
		vehicleFolder.Name = vehicleId
		vehicleFolder.Parent = customizationsFolder
	end
	return vehicleFolder :: Folder
end

local function getSlotConfig(slotName: string)
	for sectionName, section in CUSTOMIZATION_SECTIONS do
		local slot = section.slots[slotName]
		if slot then return sectionName, section, slot end
	end
	return nil, nil, nil
end

local function getEquippedValue(player: Player, vehicleId: string, valueName: string): string?
	local customizationsFolder = getPlayerCustomizationsFolder(player)
	local vehicleFolder = customizationsFolder and customizationsFolder:FindFirstChild(vehicleId)
	local equipped = vehicleFolder and vehicleFolder:FindFirstChild(valueName)
	if equipped and equipped:IsA("StringValue") and equipped.Value ~= "" then return equipped.Value end
	return nil
end

local function getCustomizationRoot(sectionName: string, slotName: string): Folder?
	local _, _, slot = getSlotConfig(slotName)
	local root = ReplicatedStorage:FindFirstChild("VehicleCustomizations")
	local sectionFolder = root and root:FindFirstChild(sectionName)
	local slotFolder = sectionFolder and sectionFolder:FindFirstChild(slot.folder)
	return slotFolder and slotFolder:IsA("Folder") and slotFolder or nil
end

local function getCustomizationTemplate(sectionName: string, slotName: string, itemId: string): Instance?
	local slotFolder = getCustomizationRoot(sectionName, slotName)
	return slotFolder and slotFolder:FindFirstChild(itemId) or nil
end

local function readDisplayName(instance: Instance): string
	local displayName = instance:FindFirstChild("DisplayName")
	return displayName and displayName:IsA("StringValue") and displayName.Value ~= "" and displayName.Value or instance.Name
end

local function readLayoutOrder(instance: Instance): number
	local layoutOrder = instance:FindFirstChild("LayoutOrder")
	return layoutOrder and (layoutOrder:IsA("NumberValue") or layoutOrder:IsA("IntValue")) and layoutOrder.Value or 0
end

local METADATA_CHILDREN = {
	DisplayName = true,
	LayoutOrder = true,
	SupportedVehicles = true,
	VehicleId = true,
}

local function isCustomizationItem(instance: Instance): boolean
	if METADATA_CHILDREN[instance.Name] then return false end
	return instance:IsA("BasePart") or instance:IsA("Model") or instance:IsA("Folder")
end

local function vehicleIdMatches(configuredId: string, vehicleId: string): boolean
	return string.lower(configuredId) == string.lower(vehicleId)
end

local function customizationSupportsVehicle(instance: Instance, vehicleId: string): boolean
	local targetVehicle = instance:FindFirstChild("VehicleId")
	if targetVehicle and targetVehicle:IsA("StringValue") and targetVehicle.Value ~= "" then
		return vehicleIdMatches(targetVehicle.Value, vehicleId)
	end

	local supportedVehicles = instance:FindFirstChild("SupportedVehicles")
	if supportedVehicles and supportedVehicles:IsA("Folder") then
		local children = supportedVehicles:GetChildren()
		if #children == 0 then return true end
		for _, child in children do
			if vehicleIdMatches(child.Name, vehicleId) then return true end
			if child:IsA("StringValue") and child.Value ~= "" and vehicleIdMatches(child.Value, vehicleId) then return true end
		end
		return false
	end

	local supportedAttribute = instance:GetAttribute("SupportedVehicles")
	if typeof(supportedAttribute) == "string" and supportedAttribute ~= "" then
		for id in string.gmatch(supportedAttribute, "[^,%s]+") do
			if vehicleIdMatches(id, vehicleId) then return true end
		end
		return false
	end

	return true
end

local function colorToString(color: Color3): string
	return `{math.floor(color.R * 255 + 0.5)},{math.floor(color.G * 255 + 0.5)},{math.floor(color.B * 255 + 0.5)}`
end

local function stringToColor(value: string?): Color3?
	if not value then return nil end
	local r, g, b = string.match(value, "^(%d+),(%d+),(%d+)$")
	if not r then return nil end
	return Color3.fromRGB(math.clamp(tonumber(r) or 0, 0, 255), math.clamp(tonumber(g) or 0, 0, 255), math.clamp(tonumber(b) or 0, 0, 255))
end

local function nameMatchesTarget(name: string, targets: {string}?, prefixes: {string}?): boolean
	local lowered = string.lower(name)
	if targets then
		for _, target in targets do
			if lowered == string.lower(target) then return true end
		end
	end
	if prefixes then
		for _, prefix in prefixes do
			if string.sub(lowered, 1, #prefix) == string.lower(prefix) then return true end
		end
	end
	return false
end

local function readCustomizationSlotName(instance: Instance): string?
	local slotName = instance:GetAttribute("CustomizationSlot")
	if typeof(slotName) == "string" and slotName ~= "" then return slotName end
	local slotValue = instance:FindFirstChild("CustomizationSlot")
	if slotValue and slotValue:IsA("StringValue") and slotValue.Value ~= "" then return slotValue.Value end
	return nil
end

local function applyColorToSlotTargets(vehicle: Model, slotName: string, slot, color: Color3)
	local searchRoot = slot.interior and (vehicle:FindFirstChild("interior") or vehicle:FindFirstChild("Interior")) or vehicle
	for _, descendant in (searchRoot or vehicle):GetDescendants() do
		if descendant:IsA("BasePart") and (readCustomizationSlotName(descendant) == slotName or nameMatchesTarget(descendant.Name, slot.targetNames, slot.targetPrefixes)) then
			descendant.Color = color
		end
	end
end

function VehicleGarage.playerOwns(player: Player, vehicleId: string): boolean
	local owned = getPlayerVehicleValue(player, vehicleId)
	return owned ~= nil and owned.Value == true
end

function VehicleGarage.grantVehicle(player: Player, vehicleId: string): boolean
	if not VehicleCatalog.getEntry(vehicleId) then return false end
	local vehiclesFolder = getPlayerVehiclesFolder(player)
	if not vehiclesFolder then return false end
	local owned = vehiclesFolder:FindFirstChild(vehicleId) or Instance.new("BoolValue")
	owned.Name = vehicleId
	owned.Value = true
	owned.Parent = vehiclesFolder
	return true
end

local function getCurrencyValue(player: Player, currencyKey: string): NumberValue?
	local data = player:FindFirstChild("Data")
	local playerData = data and data:FindFirstChild("PlayerData")
	local currency = playerData and playerData:FindFirstChild(currencyKey)
	return currency and (currency:IsA("NumberValue") or currency:IsA("IntValue")) and currency or nil
end

local function buildMenuEntry(player: Player, entry)
	return {id = entry.id, displayName = entry.displayName, price = entry.price, currency = entry.currency, currencyName = VehicleCatalog.getCurrencyName(entry.currency), owned = VehicleGarage.playerOwns(player, entry.id), layoutOrder = entry.layoutOrder}
end

local function ensureVehicleRecords(player: Player)
	local vehiclesFolder = getPlayerVehiclesFolder(player)
	if not vehiclesFolder then return end
	for _, entry in VehicleCatalog.getEntries() do
		if not vehiclesFolder:FindFirstChild(entry.id) then
			local owned = Instance.new("BoolValue")
			owned.Name = entry.id
			owned.Value = entry.defaultOwned
			owned.Parent = vehiclesFolder
		end
	end
end

function VehicleGarage.getCustomizationMenuData(player: Player, vehicleId: string?)
	local result = {sections = {}, equipped = {}, colors = {}}
	for sectionName, section in CUSTOMIZATION_SECTIONS do
		local sectionData = {displayName = sectionName, frame = section.frame, slots = {}}
		for slotName, slot in section.slots do
			local slotFolder = getCustomizationRoot(sectionName, slotName)
			local items = {}
			local slotAvailable = slotFolder ~= nil and (not vehicleId or customizationSupportsVehicle(slotFolder, vehicleId))
			if slotFolder then
				for _, item in slotFolder:GetChildren() do
					if slot.mode ~= "ColorOnly" and isCustomizationItem(item) then
						table.insert(items, {id = item.Name, displayName = readDisplayName(item), layoutOrder = readLayoutOrder(item), equipped = vehicleId ~= nil and getEquippedValue(player, vehicleId, slotName) == item.Name or false, supported = not vehicleId or customizationSupportsVehicle(item, vehicleId)})
					end
				end
			end
			table.sort(items, function(a, b) return a.layoutOrder ~= b.layoutOrder and a.layoutOrder < b.layoutOrder or a.displayName < b.displayName end)
			local colorValue = vehicleId and getEquippedValue(player, vehicleId, `{slotName}Color`) or nil
			sectionData.slots[slotName] = {displayName = slotName, frame = slot.frame, mode = slot.mode, items = items, color = colorValue, available = slotAvailable}
			if vehicleId then result.equipped[slotName] = getEquippedValue(player, vehicleId, slotName); result.colors[slotName] = colorValue end
		end
		result.sections[sectionName] = sectionData
	end
	return result
end

function VehicleGarage.getMenuData(player: Player, selectedVehicleId: string?)
	ensureVehicleRecords(player)
	local catalog = {}
	for _, entry in VehicleCatalog.getEntries() do table.insert(catalog, buildMenuEntry(player, entry)) end
	local ownedIds = {}
	for _, entry in catalog do if entry.owned then table.insert(ownedIds, entry.id) end end
	return {catalog = catalog, owned = ownedIds, customizations = VehicleGarage.getCustomizationMenuData(player, selectedVehicleId)}
end

function VehicleGarage.buyVehicle(player: Player, vehicleId: string)
	if type(vehicleId) ~= "string" or vehicleId == "" then return {success = false, reason = "Invalid vehicle"} end
	ensureVehicleRecords(player)
	local now = os.clock()
	if buyCooldowns[player] and now - buyCooldowns[player] < BUY_COOLDOWN then return {success = false, reason = "Please wait"} end
	local entry = VehicleCatalog.getEntry(vehicleId)
	if not entry then return {success = false, reason = "Vehicle not found"} end
	if VehicleGarage.playerOwns(player, vehicleId) then return {success = false, reason = "Already owned"} end
	local currency = getCurrencyValue(player, entry.currency)
	if not currency then return {success = false, reason = "Currency unavailable"} end
	if currency.Value < entry.price then return {success = false, reason = `Not enough {VehicleCatalog.getCurrencyName(entry.currency)}`} end
	currency.Value -= entry.price
	VehicleGarage.grantVehicle(player, vehicleId)
	buyCooldowns[player] = now
	return {success = true, reason = "Purchased", menu = VehicleGarage.getMenuData(player)}
end

local function getSpawnFolder(): Folder
	local folder = Workspace:FindFirstChild("PlayerVehicles") or Instance.new("Folder")
	folder.Name = "PlayerVehicles"
	folder.Parent = Workspace
	return folder
end

local function getSpawnCFrame(character: Model): CFrame?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	flatLook = flatLook.Magnitude < 0.01 and Vector3.new(0, 0, -1) or flatLook.Unit
	local targetPosition = root.Position + flatLook * SPAWN_DISTANCE + Vector3.new(0, 2, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}
	local result = Workspace:Raycast(targetPosition + Vector3.new(0, 10, 0), Vector3.new(0, -50, 0), rayParams)
	if result then targetPosition = result.Position + Vector3.new(0, 2, 0) end
	return CFrame.lookAt(targetPosition, targetPosition + flatLook)
end

local function prepareVehicleModel(model: Model, owner: Player, vehicleId: string)
	model:SetAttribute("VehicleId", vehicleId)
	model:SetAttribute("OwnerUserId", owner.UserId)
	if not Vehicle.isRegisteredVehicle(model) then model:SetAttribute("IsVehicle", true) end
	if not CollectionService:HasTag(model, VEHICLE_TAG) then CollectionService:AddTag(model, VEHICLE_TAG) end
	for _, descendant in model:GetDescendants() do if descendant:IsA("BasePart") then descendant.Anchored = false end end
	Vehicle.setupWheelVisuals(model)
	local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
	if seat then seat:SetAttribute("OwnerUserId", owner.UserId) end
end

function VehicleGarage.equipCustomization(player: Player, vehicleId: string, slotName: string, itemId: string?, color)
	if type(vehicleId) ~= "string" or vehicleId == "" then return {success = false, reason = "Invalid vehicle"} end
	local sectionName, _, slot = getSlotConfig(slotName)
	if not slot then return {success = false, reason = "Invalid customization slot"} end
	if not VehicleGarage.playerOwns(player, vehicleId) then return {success = false, reason = "You do not own this vehicle"} end
	local vehicleFolder = getOrCreateVehicleCustomizationFolder(player, vehicleId)
	if not vehicleFolder then return {success = false, reason = "Customization data unavailable"} end
	if color ~= nil then
		if typeof(color) ~= "Color3" then return {success = false, reason = "Invalid color"} end
		local colorValue = vehicleFolder:FindFirstChild(`{slotName}Color`) or Instance.new("StringValue")
		colorValue.Name = `{slotName}Color`; colorValue.Value = colorToString(color); colorValue.Parent = vehicleFolder
		local spawnedVehicle = spawnedVehicles[player]
		if spawnedVehicle and spawnedVehicle.Parent and slot.mode == "ColorOnly" then
			applyColorToSlotTargets(spawnedVehicle, slotName, slot, color)
		end
		return {success = true, reason = "Color changed", customizations = VehicleGarage.getCustomizationMenuData(player, vehicleId)}
	end
	if slot.mode == "ColorOnly" then
		return {success = false, reason = "This customization only supports color"}
	end
	local equipped = vehicleFolder:FindFirstChild(slotName) or Instance.new("StringValue")
	equipped.Name = slotName; equipped.Parent = vehicleFolder
	if itemId == nil or itemId == "" then equipped.Value = ""; return {success = true, reason = "Unequipped", customizations = VehicleGarage.getCustomizationMenuData(player, vehicleId)} end
	if type(itemId) ~= "string" then return {success = false, reason = "Invalid part"} end
	local template = getCustomizationTemplate(sectionName, slotName, itemId)
	if not template then return {success = false, reason = "Part not found"} end
	equipped.Value = itemId
	return {success = true, reason = "Equipped", customizations = VehicleGarage.getCustomizationMenuData(player, vehicleId)}
end

local function getBaseParts(root: Instance): {BasePart}
	local parts = {}
	if root:IsA("BasePart") then table.insert(parts, root) end
	for _, descendant in root:GetDescendants() do if descendant:IsA("BasePart") then table.insert(parts, descendant) end end
	return parts
end

local function applyColor(root: Instance, color: Color3?)
	if not color then return end
	for _, part in getBaseParts(root) do part.Color = color end
end

local function weldTo(part0: BasePart, clone: Instance)
	for _, part in getBaseParts(clone) do
		part.Anchored = false; part.CanCollide = false; part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part0; weld.Part1 = part; weld.Parent = part
	end
end

local function applyAttachmentCustomization(vehicle: Model, player: Player, vehicleId: string, sectionName: string, slotName: string, slot)
	local itemId = getEquippedValue(player, vehicleId, slotName)
	if not itemId then return end
	local template = getCustomizationTemplate(sectionName, slotName, itemId)
	if not template then return end
	local searchRoot = slot.interior and vehicle:FindFirstChild("interior") or vehicle
	local mainPart = vehicle:FindFirstChild("MainPart", true)
	local attachment = (searchRoot and searchRoot:FindFirstChild(slot.attachment, true)) or (mainPart and mainPart:FindFirstChild(slot.attachment))
	if not mainPart or not mainPart:IsA("BasePart") or not attachment or not attachment:IsA("Attachment") then warn(`VehicleGarage: '{vehicleId}' is missing {slot.attachment}`); return end
	local clone = template:Clone(); clone.Name = itemId; clone:SetAttribute("CustomizationSlot", slotName); clone.Parent = vehicle
	local partAttachment = clone:FindFirstChild("Attachment", true)
	if not partAttachment or not partAttachment:IsA("Attachment") then warn(`VehicleGarage: '{itemId}' is missing Attachment`); clone:Destroy(); return end
	local targetCFrame = attachment.WorldCFrame * partAttachment.CFrame:Inverse()
	if clone:IsA("Model") then clone:PivotTo(targetCFrame) elseif clone:IsA("BasePart") then clone.CFrame = targetCFrame end
	applyColor(clone, stringToColor(getEquippedValue(player, vehicleId, `{slotName}Color`)))
	weldTo(mainPart, clone)
end

local function replaceVisualWheelPart(visualWheel: Instance, slotName: string, template: Instance, color: Color3?)
	local oldPart = visualWheel:FindFirstChild(slotName)
	local pivotPart = oldPart and oldPart:IsA("BasePart") and oldPart or visualWheel:FindFirstChildWhichIsA("BasePart", true)
	local pivot = pivotPart and pivotPart.CFrame or CFrame.new()
	if oldPart then oldPart:Destroy() end
	local clone = template:Clone(); clone.Name = slotName; clone.Parent = visualWheel
	if clone:IsA("Model") and clone.PrimaryPart then clone:PivotTo(pivot) elseif clone:IsA("BasePart") then clone.CFrame = pivot end
	applyColor(clone, color)
	local rim = visualWheel:FindFirstChild("Rim")
	local weldPart = rim and rim:IsA("BasePart") and rim or visualWheel:FindFirstChildWhichIsA("BasePart", true)
	if weldPart then weldTo(weldPart, clone) end
end

local function applyExistingWheelColor(vehicle: Model, wheelPartName: string, color: Color3?)
	if not color then return end
	for _, descendant in vehicle:GetDescendants() do
		if descendant.Name == "VisualWheel" and (descendant:IsA("Model") or descendant:IsA("Folder")) then
			local wheelPart = descendant:FindFirstChild(wheelPartName)
			if wheelPart then applyColor(wheelPart, color) end
		end
	end
end

local function applyWheelCustomization(vehicle: Model, player: Player, vehicleId: string, sectionName: string, slotName: string, slot)
	local color = stringToColor(getEquippedValue(player, vehicleId, `{slotName}Color`))
	local itemId = getEquippedValue(player, vehicleId, slotName)
	if not itemId then
		applyExistingWheelColor(vehicle, slot.wheelPartName, color)
		return
	end
	local template = getCustomizationTemplate(sectionName, slotName, itemId)
	if not template then
		applyExistingWheelColor(vehicle, slot.wheelPartName, color)
		return
	end
	for _, descendant in vehicle:GetDescendants() do
		if descendant.Name == "VisualWheel" and (descendant:IsA("Model") or descendant:IsA("Folder")) then replaceVisualWheelPart(descendant, slot.wheelPartName, template, color) end
	end
end

local function applyColorOnlySlots(vehicle: Model, player: Player, vehicleId: string)
	for sectionName, section in CUSTOMIZATION_SECTIONS do
		for slotName, slot in section.slots do
			if slot.mode ~= "ColorOnly" then continue end
			local color = stringToColor(getEquippedValue(player, vehicleId, `{slotName}Color`))
			if not color then continue end
			applyColorToSlotTargets(vehicle, slotName, slot, color)
		end
	end
	for _, descendant in vehicle:GetDescendants() do
		local slotName = readCustomizationSlotName(descendant)
		if slotName and descendant:IsA("BasePart") then descendant.Color = stringToColor(getEquippedValue(player, vehicleId, `{slotName}Color`)) or descendant.Color end
	end
end

local function applyCustomizations(vehicle: Model, player: Player, vehicleId: string)
	for sectionName, section in CUSTOMIZATION_SECTIONS do
		for slotName, slot in section.slots do
			if slot.mode == "ColorOnly" then continue elseif sectionName == "Wheels" then applyWheelCustomization(vehicle, player, vehicleId, sectionName, slotName, slot) else applyAttachmentCustomization(vehicle, player, vehicleId, sectionName, slotName, slot) end
		end
	end
	applyColorOnlySlots(vehicle, player, vehicleId)
	Vehicle.setupWheelVisuals(vehicle)
end

function VehicleGarage.despawnVehicle(player: Player)
	local current = spawnedVehicles[player]
	if current and current.Parent then current:Destroy() end
	spawnedVehicles[player] = nil
end

function VehicleGarage.spawnVehicle(player: Player, vehicleId: string)
	if type(vehicleId) ~= "string" or vehicleId == "" then return {success = false, reason = "Invalid vehicle"} end
	local now = os.clock()
	if spawnCooldowns[player] and now - spawnCooldowns[player] < SPAWN_COOLDOWN then return {success = false, reason = "Please wait"} end
	if not VehicleGarage.playerOwns(player, vehicleId) then return {success = false, reason = "You do not own this vehicle"} end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return {success = false, reason = "Cannot spawn right now"} end
	if humanoid.SeatPart then return {success = false, reason = "Leave your current seat first"} end
	local template = VehicleCatalog.getModelTemplate(vehicleId)
	if not template then return {success = false, reason = "Vehicle model missing"} end
	local spawnCFrame = getSpawnCFrame(character)
	if not spawnCFrame then return {success = false, reason = "Could not find spawn position"} end
	VehicleGarage.despawnVehicle(player)
	local vehicle = template:Clone()
	vehicle.Name = `{player.Name}_{vehicleId}`
	prepareVehicleModel(vehicle, player, vehicleId)
	vehicle:PivotTo(spawnCFrame)
	applyCustomizations(vehicle, player, vehicleId)
	vehicle.Parent = getSpawnFolder()
	spawnedVehicles[player] = vehicle
	spawnCooldowns[player] = now
	return {success = true, reason = "Spawned", vehicleId = vehicleId}
end

function VehicleGarage.cleanupPlayer(player: Player)
	VehicleGarage.despawnVehicle(player)
	spawnCooldowns[player] = nil
	buyCooldowns[player] = nil
end

Players.PlayerRemoving:Connect(VehicleGarage.cleanupPlayer)

return VehicleGarage
