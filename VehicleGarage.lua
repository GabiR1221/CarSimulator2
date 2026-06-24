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

function VehicleGarage.getMenuData(player: Player)
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
