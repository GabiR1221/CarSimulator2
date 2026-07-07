-- VehicleGarage Module in ReplicatedStorage.Modules
-- Server-side ownership, purchasing, and spawning. Only require this from server scripts.

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
local FRONT_BUMPER_SLOT = "FrontBumper"

local VehicleGarage = {}

local spawnedVehicles: {[Player]: Model} = {}
local spawnCooldowns: {[Player]: number} = {}
local buyCooldowns: {[Player]: number} = {}

local function getPlayerVehiclesFolder(player: Player): Folder?
	local data = player:FindFirstChild("Data")
	if not data then
		return nil
	end

	return data:FindFirstChild("Vehicles")
end

local function getPlayerVehicleValue(player: Player, vehicleId: string): BoolValue?
	local vehiclesFolder = getPlayerVehiclesFolder(player)
	if not vehiclesFolder then
		return nil
	end

	local owned = vehiclesFolder:FindFirstChild(vehicleId)
	if owned and owned:IsA("BoolValue") then
		return owned
	end

	return nil
end

local function getPlayerCustomizationsFolder(player: Player): Folder?
	local data = player:FindFirstChild("Data")
	if not data then
		return nil
	end

	return data:FindFirstChild("VehicleCustomizations")
end

local function getOrCreateVehicleCustomizationFolder(player: Player, vehicleId: string): Folder?
	local customizationsFolder = getPlayerCustomizationsFolder(player)
	if not customizationsFolder then
		return nil
	end

	local vehicleFolder = customizationsFolder:FindFirstChild(vehicleId)
	if not vehicleFolder then
		vehicleFolder = Instance.new("Folder")
		vehicleFolder.Name = vehicleId
		vehicleFolder.Parent = customizationsFolder
	end

	return vehicleFolder :: Folder
end

local function getEquippedCustomization(player: Player, vehicleId: string, slotName: string): string?
	local customizationsFolder = getPlayerCustomizationsFolder(player)
	local vehicleFolder = customizationsFolder and customizationsFolder:FindFirstChild(vehicleId)
	local equipped = vehicleFolder and vehicleFolder:FindFirstChild(slotName)
	if equipped and equipped:IsA("StringValue") and equipped.Value ~= "" then
		return equipped.Value
	end

	return nil
end

local function getCustomizationRoot(slotName: string): Folder?
	local root = ReplicatedStorage:FindFirstChild("VehicleCustomizations")
	if not root then
		return nil
	end

	local slotFolderName = slotName == FRONT_BUMPER_SLOT and "FrontBumpers" or slotName
	local slotFolder = root:FindFirstChild(slotFolderName)
	if slotFolder and slotFolder:IsA("Folder") then
		return slotFolder
	end

	return nil
end

local function getCustomizationTemplate(slotName: string, itemId: string): Instance?
	local slotFolder = getCustomizationRoot(slotName)
	return slotFolder and slotFolder:FindFirstChild(itemId) or nil
end

local function readDisplayName(instance: Instance): string
	local displayName = instance:FindFirstChild("DisplayName")
	if displayName and displayName:IsA("StringValue") and displayName.Value ~= "" then
		return displayName.Value
	end

	return instance.Name
end

local function readLayoutOrder(instance: Instance): number
	local layoutOrder = instance:FindFirstChild("LayoutOrder")
	if layoutOrder and (layoutOrder:IsA("NumberValue") or layoutOrder:IsA("IntValue")) then
		return layoutOrder.Value
	end

	return 0
end

local function customizationSupportsVehicle(instance: Instance, vehicleId: string): boolean
	local targetVehicle = instance:FindFirstChild("VehicleId")
	if targetVehicle and targetVehicle:IsA("StringValue") and targetVehicle.Value ~= "" then
		return targetVehicle.Value == vehicleId
	end

	return true
end

function VehicleGarage.playerOwns(player: Player, vehicleId: string): boolean
	local owned = getPlayerVehicleValue(player, vehicleId)
	return owned ~= nil and owned.Value == true
end

function VehicleGarage.grantVehicle(player: Player, vehicleId: string): boolean
	if not VehicleCatalog.getEntry(vehicleId) then
		return false
	end

	local vehiclesFolder = getPlayerVehiclesFolder(player)
	if not vehiclesFolder then
		return false
	end

	local owned = vehiclesFolder:FindFirstChild(vehicleId)
	if not owned then
		owned = Instance.new("BoolValue")
		owned.Name = vehicleId
		owned.Parent = vehiclesFolder
	end

	owned.Value = true
	return true
end

local function getCurrencyValue(player: Player, currencyKey: string): NumberValue?
	local data = player:FindFirstChild("Data")
	if not data then
		return nil
	end

	local playerData = data:FindFirstChild("PlayerData")
	if not playerData then
		return nil
	end

	local currency = playerData:FindFirstChild(currencyKey)
	if currency and (currency:IsA("NumberValue") or currency:IsA("IntValue")) then
		return currency
	end

	return nil
end

local function buildMenuEntry(player: Player, entry)
	local owned = VehicleGarage.playerOwns(player, entry.id)
	return {
		id = entry.id,
		displayName = entry.displayName,
		price = entry.price,
		currency = entry.currency,
		currencyName = VehicleCatalog.getCurrencyName(entry.currency),
		owned = owned,
		layoutOrder = entry.layoutOrder,
	}
end

local function ensureVehicleRecords(player: Player)
	local vehiclesFolder = getPlayerVehiclesFolder(player)
	if not vehiclesFolder then
		return
	end

	for _, entry in VehicleCatalog.getEntries() do
		if vehiclesFolder:FindFirstChild(entry.id) then
			continue
		end

		local owned = Instance.new("BoolValue")
		owned.Name = entry.id
		owned.Value = entry.defaultOwned
		owned.Parent = vehiclesFolder
	end
end

function VehicleGarage.getMenuData(player: Player, selectedVehicleId: string?)
	ensureVehicleRecords(player)

	local catalog = {}

	for _, entry in VehicleCatalog.getEntries() do
		table.insert(catalog, buildMenuEntry(player, entry))
	end

	local ownedIds = {}
	for _, entry in catalog do
		if entry.owned then
			table.insert(ownedIds, entry.id)
		end
	end

	return {
		catalog = catalog,
		owned = ownedIds,
		customizations = VehicleGarage.getCustomizationMenuData(player, selectedVehicleId),
	}
end

function VehicleGarage.buyVehicle(player: Player, vehicleId: string)
	if type(vehicleId) ~= "string" or vehicleId == "" then
		return {success = false, reason = "Invalid vehicle"}
	end

	ensureVehicleRecords(player)

	local now = os.clock()
	if buyCooldowns[player] and now - buyCooldowns[player] < BUY_COOLDOWN then
		return {success = false, reason = "Please wait"}
	end

	local entry = VehicleCatalog.getEntry(vehicleId)
	if not entry then
		return {success = false, reason = "Vehicle not found"}
	end

	if VehicleGarage.playerOwns(player, vehicleId) then
		return {success = false, reason = "Already owned"}
	end

	local currency = getCurrencyValue(player, entry.currency)
	if not currency then
		return {success = false, reason = "Currency unavailable"}
	end

	if currency.Value < entry.price then
		return {
			success = false,
			reason = `Not enough {VehicleCatalog.getCurrencyName(entry.currency)}`,
		}
	end

	currency.Value -= entry.price
	VehicleGarage.grantVehicle(player, vehicleId)
	buyCooldowns[player] = now

	return {
		success = true,
		reason = "Purchased",
		menu = VehicleGarage.getMenuData(player),
	}
end

local function getSpawnFolder(): Folder
	local folder = Workspace:FindFirstChild("PlayerVehicles")
	if folder then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = "PlayerVehicles"
	folder.Parent = Workspace
	return folder
end

local function prepareVehicleModel(model: Model, owner: Player, vehicleId: string)
	model:SetAttribute("VehicleId", vehicleId)
	model:SetAttribute("OwnerUserId", owner.UserId)

	if not Vehicle.isRegisteredVehicle(model) then
		model:SetAttribute("IsVehicle", true)
	end

	if not CollectionService:HasTag(model, VEHICLE_TAG) then
		CollectionService:AddTag(model, VEHICLE_TAG)
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end

	Vehicle.setupWheelVisuals(model)

	local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
	if seat then
		seat:SetAttribute("OwnerUserId", owner.UserId)
	end
end

local function getSpawnCFrame(character: Model): CFrame?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flatLook.Magnitude < 0.01 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end

	local targetPosition = root.Position + flatLook * SPAWN_DISTANCE + Vector3.new(0, 2, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}

	local result = Workspace:Raycast(targetPosition + Vector3.new(0, 10, 0), Vector3.new(0, -50, 0), rayParams)
	if result then
		targetPosition = result.Position + Vector3.new(0, 2, 0)
	end

	return CFrame.lookAt(targetPosition, targetPosition + flatLook)
end

function VehicleGarage.getCustomizationMenuData(player: Player, vehicleId: string?)
	local result = {
		frontBumpers = {},
		equipped = {},
	}

	if vehicleId and type(vehicleId) == "string" then
		local equipped = getEquippedCustomization(player, vehicleId, FRONT_BUMPER_SLOT)
		if equipped then
			result.equipped[FRONT_BUMPER_SLOT] = equipped
		end
	end

	local slotFolder = getCustomizationRoot(FRONT_BUMPER_SLOT)
	if not slotFolder then
		return result
	end

	for _, item in slotFolder:GetChildren() do
		if not (item:IsA("BasePart") or item:IsA("Model") or item:IsA("Folder")) then
			continue
		end

		if vehicleId and not customizationSupportsVehicle(item, vehicleId) then
			continue
		end

		table.insert(result.frontBumpers, {
			id = item.Name,
			displayName = readDisplayName(item),
			layoutOrder = readLayoutOrder(item),
			equipped = vehicleId ~= nil and getEquippedCustomization(player, vehicleId, FRONT_BUMPER_SLOT) == item.Name or false,
		})
	end

	table.sort(result.frontBumpers, function(a, b)
		if a.layoutOrder ~= b.layoutOrder then
			return a.layoutOrder < b.layoutOrder
		end
		return a.displayName < b.displayName
	end)

	return result
end

function VehicleGarage.equipCustomization(player: Player, vehicleId: string, slotName: string, itemId: string?)
	if type(vehicleId) ~= "string" or vehicleId == "" then
		return {success = false, reason = "Invalid vehicle"}
	end

	if slotName ~= FRONT_BUMPER_SLOT then
		return {success = false, reason = "Invalid customization slot"}
	end

	if not VehicleGarage.playerOwns(player, vehicleId) then
		return {success = false, reason = "You do not own this vehicle"}
	end

	local vehicleFolder = getOrCreateVehicleCustomizationFolder(player, vehicleId)
	if not vehicleFolder then
		return {success = false, reason = "Customization data unavailable"}
	end

	local equipped = vehicleFolder:FindFirstChild(slotName)
	if not equipped then
		equipped = Instance.new("StringValue")
		equipped.Name = slotName
		equipped.Parent = vehicleFolder
	end

	if itemId == nil or itemId == "" then
		equipped.Value = ""
		return {success = true, reason = "Unequipped", customizations = VehicleGarage.getCustomizationMenuData(player, vehicleId)}
	end

	if type(itemId) ~= "string" then
		return {success = false, reason = "Invalid part"}
	end

	local template = getCustomizationTemplate(slotName, itemId)
	if not template or not customizationSupportsVehicle(template, vehicleId) then
		return {success = false, reason = "Part not found"}
	end

	equipped.Value = itemId
	return {success = true, reason = "Equipped", customizations = VehicleGarage.getCustomizationMenuData(player, vehicleId)}
end

local function getAttachmentHolder(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function applyFrontBumper(vehicle: Model, player: Player, vehicleId: string)
	local itemId = getEquippedCustomization(player, vehicleId, FRONT_BUMPER_SLOT)
	if not itemId then
		return
	end

	local template = getCustomizationTemplate(FRONT_BUMPER_SLOT, itemId)
	if not template then
		warn(`VehicleGarage: Missing front bumper customization '{itemId}'`)
		return
	end

	local mainPart = vehicle:FindFirstChild("MainPart", true)
	if not mainPart or not mainPart:IsA("BasePart") then
		warn(`VehicleGarage: Vehicle '{vehicleId}' is missing a MainPart for front bumper customization`)
		return
	end

	local vehicleAttachment = mainPart:FindFirstChild("FrontBumperAttachment")
	if not vehicleAttachment or not vehicleAttachment:IsA("Attachment") then
		warn(`VehicleGarage: Vehicle '{vehicleId}' MainPart is missing FrontBumperAttachment`)
		return
	end

	local clone = template:Clone()
	clone.Name = itemId
	clone.Parent = vehicle

	local holder = getAttachmentHolder(clone)
	if not holder then
		clone:Destroy()
		return
	end

	local partAttachment = clone:FindFirstChild("Attachment", true)
	if not partAttachment or not partAttachment:IsA("Attachment") then
		warn(`VehicleGarage: Front bumper '{itemId}' is missing an Attachment`)
		clone:Destroy()
		return
	end

	local targetCFrame = vehicleAttachment.WorldCFrame * partAttachment.CFrame:Inverse()
	if clone:IsA("Model") then
		clone:PivotTo(targetCFrame)
	elseif clone:IsA("BasePart") then
		clone.CFrame = targetCFrame
	else
		holder.CFrame = targetCFrame
	end

	local partsToWeld = {}
	if clone:IsA("BasePart") then
		table.insert(partsToWeld, clone)
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(partsToWeld, descendant)
		end
	end

	for _, part in partsToWeld do
		part.Anchored = false
		part.CanCollide = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = mainPart
		weld.Part1 = part
		weld.Parent = part
	end
end

function VehicleGarage.despawnVehicle(player: Player)
	local current = spawnedVehicles[player]
	if current and current.Parent then
		current:Destroy()
	end
	spawnedVehicles[player] = nil
end

function VehicleGarage.spawnVehicle(player: Player, vehicleId: string)
	if type(vehicleId) ~= "string" or vehicleId == "" then
		return {success = false, reason = "Invalid vehicle"}
	end

	local now = os.clock()
	if spawnCooldowns[player] and now - spawnCooldowns[player] < SPAWN_COOLDOWN then
		return {success = false, reason = "Please wait"}
	end

	if not VehicleGarage.playerOwns(player, vehicleId) then
		return {success = false, reason = "You do not own this vehicle"}
	end

	local character = player.Character
	if not character then
		return {success = false, reason = "Character not found"}
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return {success = false, reason = "Cannot spawn right now"}
	end

	if humanoid.SeatPart then
		return {success = false, reason = "Leave your current seat first"}
	end

	local template = VehicleCatalog.getModelTemplate(vehicleId)
	if not template then
		return {success = false, reason = "Vehicle model missing"}
	end

	local spawnCFrame = getSpawnCFrame(character)
	if not spawnCFrame then
		return {success = false, reason = "Could not find spawn position"}
	end

	VehicleGarage.despawnVehicle(player)

	local vehicle = template:Clone()
	vehicle.Name = `{player.Name}_{vehicleId}`
	prepareVehicleModel(vehicle, player, vehicleId)
	vehicle:PivotTo(spawnCFrame)
	applyFrontBumper(vehicle, player, vehicleId)
	vehicle.Parent = getSpawnFolder()

	spawnedVehicles[player] = vehicle
	spawnCooldowns[player] = now

	return {
		success = true,
		reason = "Spawned",
		vehicleId = vehicleId,
	}
end

function VehicleGarage.cleanupPlayer(player: Player)
	VehicleGarage.despawnVehicle(player)
	spawnCooldowns[player] = nil
	buyCooldowns[player] = nil
end

Players.PlayerRemoving:Connect(VehicleGarage.cleanupPlayer)

return VehicleGarage
