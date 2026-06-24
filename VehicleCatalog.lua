-- VehicleCatalog Module in ReplicatedStorage.Modules
--[[
	Authoritative vehicle shop catalog. Configure entries in ReplicatedStorage.Vehicles.

	Per entry folder (example: ReplicatedStorage.Vehicles.PickupTruck):
	- DisplayName (StringValue): shown in the menu
	- Price (NumberValue): purchase cost
	- Currency (StringValue): "Currency" or "Currency2"
	- LayoutOrder (IntValue, optional): list sorting
	- DefaultOwned (BoolValue, optional): granted on first join

	Matching drivable model template:
	ReplicatedStorage.VehicleModels.PickupTruck
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VALID_CURRENCIES = {
	Currency = true,
	Currency2 = true,
}

local VehicleCatalog = {}

local cachedEntries = nil

local function readBoolValue(folder: Instance, name: string): boolean
	local valueObject = folder:FindFirstChild(name)
	return valueObject and valueObject:IsA("BoolValue") and valueObject.Value or false
end

local function readStringValue(folder: Instance, name: string, default: string): string
	local valueObject = folder:FindFirstChild(name)
	if valueObject and valueObject:IsA("StringValue") and valueObject.Value ~= "" then
		return valueObject.Value
	end
	return default
end

local function readNumberValue(folder: Instance, name: string, default: number): number
	local valueObject = folder:FindFirstChild(name)
	if valueObject and (valueObject:IsA("NumberValue") or valueObject:IsA("IntValue")) then
		return valueObject.Value
	end
	return default
end

local function buildEntries()
	local catalogFolder = ReplicatedStorage:FindFirstChild("Vehicles")
	local modelsFolder = ReplicatedStorage:FindFirstChild("VehicleModels")
	local entries = {}

	if not catalogFolder then
		warn("VehicleCatalog: ReplicatedStorage.Vehicles is missing")
		return entries
	end

	if not modelsFolder then
		warn("VehicleCatalog: ReplicatedStorage.VehicleModels is missing")
	end

	for _, entryFolder in catalogFolder:GetChildren() do
		if not entryFolder:IsA("Folder") then
			continue
		end

		local vehicleId = entryFolder.Name
		local modelTemplate = modelsFolder and modelsFolder:FindFirstChild(vehicleId)

		if not modelTemplate or not modelTemplate:IsA("Model") then
			warn(`VehicleCatalog: Missing model template for '{vehicleId}' in ReplicatedStorage.VehicleModels`)
			continue
		end

		local currency = readStringValue(entryFolder, "Currency", "Currency")
		if not VALID_CURRENCIES[currency] then
			warn(`VehicleCatalog: Invalid currency '{currency}' on '{vehicleId}', defaulting to Currency`)
			currency = "Currency"
		end

		table.insert(entries, {
			id = vehicleId,
			displayName = readStringValue(entryFolder, "DisplayName", vehicleId),
			price = math.max(0, readNumberValue(entryFolder, "Price", 0)),
			currency = currency,
			layoutOrder = readNumberValue(entryFolder, "LayoutOrder", 0),
			defaultOwned = readBoolValue(entryFolder, "DefaultOwned"),
		})
	end

	table.sort(entries, function(a, b)
		if a.layoutOrder ~= b.layoutOrder then
			return a.layoutOrder < b.layoutOrder
		end
		return a.displayName < b.displayName
	end)

	return entries
end

function VehicleCatalog.getEntries()
	if not cachedEntries then
		cachedEntries = buildEntries()
	end
	return cachedEntries
end

function VehicleCatalog.refresh()
	cachedEntries = buildEntries()
	return cachedEntries
end

function VehicleCatalog.getEntry(vehicleId: string)
	for _, entry in VehicleCatalog.getEntries() do
		if entry.id == vehicleId then
			return entry
		end
	end
	return nil
end

function VehicleCatalog.getModelTemplate(vehicleId: string): Model?
	local modelsFolder = ReplicatedStorage:FindFirstChild("VehicleModels")
	if not modelsFolder then
		return nil
	end

	local model = modelsFolder:FindFirstChild(vehicleId)
	if model and model:IsA("Model") then
		return model
	end

	return nil
end

function VehicleCatalog.getCurrencyName(currencyKey: string): string
	local gameSettings = ReplicatedStorage:FindFirstChild("Game Settings")
	if not gameSettings then
		return currencyKey
	end

	if currencyKey == "Currency2" then
		local currency2Name = gameSettings:FindFirstChild("Currency2Name")
		if currency2Name and currency2Name:IsA("StringValue") then
			return currency2Name.Value
		end
		return "Gems"
	end

	local currencyName = gameSettings:FindFirstChild("CurrencyName")
	if currencyName and currencyName:IsA("StringValue") then
		return currencyName.Value
	end

	return "Cash"
end

return VehicleCatalog
