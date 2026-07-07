-- Vehicle Module in ReplicatedStorage.Modules
--[[
	Shared vehicle utilities for server and client.

	Studio setup (per vehicle model):
	1. Tag the model with CollectionService tag "Vehicle" OR set Attribute IsVehicle = true
	2. Set Model.PrimaryPart
	3. Add a VehicleSeat anywhere under the model
	4. On PrimaryPart: AttachmentFL and AttachmentFR (steering)
	5. Each wheel can be either a BasePart named WheelBL/WheelBR/etc. or a Folder
	   named WheelBL/WheelBR/etc. or WheelsBL/WheelsBR/etc. containing the
	   physical wheel BasePart.
	6. Optional: add cosmetic MeshParts/BaseParts named VisualWheel inside a wheel
	   folder; they are welded to the physical wheel as non-colliding visuals.
	7. Optional: ExitAttachment on the seat for spawn position on exit

	Optional attributes on the model:
	- VehicleWheels (string): "WheelFL,WheelFR,WheelBL,WheelBR"
	- VehicleDriveWheels (string): "WheelBL,WheelBR"
	- VehicleSteerAttachments (string): "AttachmentFL,AttachmentFR"
	- VehicleIdleTorque (number): default 2000
	- VehicleSteerTween (number): default 0.4
]]


local CollectionService = game:GetService("CollectionService")

local VEHICLE_TAG = "Vehicle"

local DEFAULTS = {
	wheels = {"WheelFL", "WheelFR", "WheelBL", "WheelBR"},
	driveWheels = {"WheelBL", "WheelBR"},
	steerAttachments = {"AttachmentFL", "AttachmentFR"},
	idleTorque = 2000,
	steerTween = 0.4,
}

local Vehicle = {}

local function splitNames(value: string?): {string}
	if not value or value == "" then
		return {}
	end

	local names = {}
	for name in string.gmatch(value, "[^,%s]+") do
		table.insert(names, name)
	end
	return names
end

function Vehicle.isRegisteredVehicle(model: Model): boolean
	if not model or not model:IsA("Model") then
		return false
	end

	if CollectionService:HasTag(model, VEHICLE_TAG) then
		return true
	end

	if model:GetAttribute("IsVehicle") == true then
		return true
	end

	-- Legacy support: models that already use the standard wheel layout.
	return model:FindFirstChild("WheelBL", true) ~= nil and model:FindFirstChild("WheelBR", true) ~= nil
end

function Vehicle.getVehicleModel(seatPart: Instance): Model?
	if not seatPart or not seatPart:IsA("VehicleSeat") then
		return nil
	end

	local current = seatPart.Parent
	while current do
		if current:IsA("Model") and current.PrimaryPart and Vehicle.isRegisteredVehicle(current) then
			return current
		end
		current = current.Parent
	end

	return nil
end

function Vehicle.isVehicleSeat(seatPart: Instance): boolean
	return Vehicle.getVehicleModel(seatPart) ~= nil
end

function Vehicle.getConfig(vehicleModel: Model)
	local driveWheelNames = splitNames(vehicleModel:GetAttribute("VehicleDriveWheels"))
	if #driveWheelNames == 0 then
		driveWheelNames = DEFAULTS.driveWheels
	end

	local steerAttachmentNames = splitNames(vehicleModel:GetAttribute("VehicleSteerAttachments"))
	if #steerAttachmentNames == 0 then
		steerAttachmentNames = DEFAULTS.steerAttachments
	end

	local wheelNames = splitNames(vehicleModel:GetAttribute("VehicleWheels"))
	if #wheelNames == 0 then
		wheelNames = DEFAULTS.wheels
	end

	return {
		wheels = wheelNames,
		driveWheels = driveWheelNames,
		steerAttachments = steerAttachmentNames,
		idleTorque = vehicleModel:GetAttribute("VehicleIdleTorque") or DEFAULTS.idleTorque,
		steerTween = vehicleModel:GetAttribute("VehicleSteerTween") or DEFAULTS.steerTween,
	}
end

local function getWheelContainerNames(wheelName: string): {string}
	local names = {wheelName}

	local wheelSuffix = string.match(wheelName, "^Wheel(.+)$")
	if wheelSuffix then
		table.insert(names, `Wheels{wheelSuffix}`)
	end

	return names
end

local function findWheelContainer(vehicleModel: Model, wheelName: string): Instance?
	for _, containerName in getWheelContainerNames(wheelName) do
		local directChild = vehicleModel:FindFirstChild(containerName)
		if directChild then
			return directChild
		end
	end

	for _, containerName in getWheelContainerNames(wheelName) do
		local descendant = vehicleModel:FindFirstChild(containerName, true)
		if descendant then
			return descendant
		end
	end

	local physicalWheel = vehicleModel:FindFirstChild(wheelName, true)
	if physicalWheel and physicalWheel:IsA("BasePart") then
		local parent = physicalWheel.Parent
		if parent and table.find(getWheelContainerNames(wheelName), parent.Name) then
			return parent
		end
	end

	return physicalWheel
end

local function getPhysicalWheelNames(container: Instance, wheelName: string): {string}
	local names = {wheelName}

	local containerSuffix = string.match(container.Name, "^Wheels(.+)$")
	if containerSuffix then
		table.insert(names, `Wheel{containerSuffix}`)
	end

	return names
end

local function resolvePhysicalWheel(container: Instance, wheelName: string): BasePart?
	if container:IsA("BasePart") then
		return container
	end

	for _, physicalWheelName in getPhysicalWheelNames(container, wheelName) do
		local namedWheel = container:FindFirstChild(physicalWheelName)
		if namedWheel and namedWheel:IsA("BasePart") then
			return namedWheel
		end
	end

	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:FindFirstChildOfClass("CylindricalConstraint") then
			return descendant
		end
	end

	for _, physicalWheelName in getPhysicalWheelNames(container, wheelName) do
		local namedWheel = container:FindFirstChild(physicalWheelName, true)
		if namedWheel and namedWheel:IsA("BasePart") then
			return namedWheel
		end
	end

	return nil
end

local function getWheelConstraint(container: Instance, physicalWheel: BasePart): CylindricalConstraint?
	local constraint = physicalWheel:FindFirstChildOfClass("CylindricalConstraint")
	if constraint then
		return constraint
	end

	if container ~= physicalWheel then
		return container:FindFirstChildWhichIsA("CylindricalConstraint", true)
	end

	return nil
end

function Vehicle.getWheel(vehicleModel: Model, wheelName: string): (BasePart?, Instance?)
	local container = findWheelContainer(vehicleModel, wheelName)
	if not container then
		return nil, nil
	end

	return resolvePhysicalWheel(container, wheelName), container
end

local function isVisualWheelPart(part: BasePart, physicalWheel: BasePart): boolean
	if part == physicalWheel or part:IsDescendantOf(physicalWheel) then
		return false
	end

	if part.Name == "VisualWheel" then
		return true
	end

	if part:GetAttribute("IsWheelVisual") == true then
		return true
	end

	return part:FindFirstChildOfClass("WeldConstraint") ~= nil
end

local function getVisualWheelParts(container: Instance, physicalWheel: BasePart): {BasePart}
	local visualParts = {}

	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") and isVisualWheelPart(descendant, physicalWheel) then
			table.insert(visualParts, descendant)
		end
	end

	return visualParts
end

local function getVisualWheelWelds(visualPart: BasePart, physicalWheel: BasePart): {WeldConstraint}
	local welds = {}

	for _, descendant in visualPart:GetDescendants() do
		if not descendant:IsA("WeldConstraint") then
			continue
		end

		if descendant.Part0 == physicalWheel or descendant.Part1 == physicalWheel then
			table.insert(welds, descendant)
		end
	end

	return welds
end

function Vehicle.setupWheelVisuals(vehicleModel: Model)
	local config = Vehicle.getConfig(vehicleModel)

	for _, wheelName in config.wheels do
		local physicalWheel, container = Vehicle.getWheel(vehicleModel, wheelName)
		if not physicalWheel or not container or container:IsA("BasePart") then
			continue
		end

		physicalWheel.Anchored = false

		for _, visualPart in getVisualWheelParts(container, physicalWheel) do
			visualPart.Anchored = false
			visualPart.CanCollide = false
			visualPart.CanTouch = false
			visualPart.CanQuery = false
			visualPart.Massless = true

			local welds = getVisualWheelWelds(visualPart, physicalWheel)
			if #welds == 0 then
				local weld = Instance.new("WeldConstraint")
				weld.Name = `VisualWheelWeld_{physicalWheel.Name}`
				weld.Part0 = physicalWheel
				weld.Part1 = visualPart
				weld.Parent = visualPart
				table.insert(welds, weld)
			end

			for _, weld in welds do
				weld.Enabled = true
			end
		end
	end
end

function Vehicle.getWheelVisuals(vehicleModel: Model)
	local config = Vehicle.getConfig(vehicleModel)
	local wheelVisuals = {}

	for _, wheelName in config.wheels do
		local physicalWheel, container = Vehicle.getWheel(vehicleModel, wheelName)
		if not physicalWheel or not container or container:IsA("BasePart") then
			continue
		end

		for _, visualPart in getVisualWheelParts(container, physicalWheel) do
			table.insert(wheelVisuals, {
				wheelName = wheelName,
				physicalWheel = physicalWheel,
				visualPart = visualPart,
				welds = getVisualWheelWelds(visualPart, physicalWheel),
			})
		end
	end

	return wheelVisuals
end

function Vehicle.getDriveComponents(vehicleModel: Model)
	local primaryPart = vehicleModel.PrimaryPart
	if not primaryPart then
		return nil, "Vehicle is missing PrimaryPart"
	end

	local config = Vehicle.getConfig(vehicleModel)

	local steerAttachments = {}
	for _, attachmentName in config.steerAttachments do
		local attachment = primaryPart:FindFirstChild(attachmentName)
		if not attachment or not attachment:IsA("Attachment") then
			return nil, `Missing steer attachment '{attachmentName}' on PrimaryPart`
		end
		table.insert(steerAttachments, attachment)
	end

	local driveWheels = {}
	for _, wheelName in config.driveWheels do
		local wheel, container = Vehicle.getWheel(vehicleModel, wheelName)
		if not wheel or not container then
			return nil, `Missing drive wheel '{wheelName}'`
		end

		local constraint = getWheelConstraint(container, wheel)
		if not constraint then
			return nil, `Drive wheel '{wheelName}' is missing a CylindricalConstraint`
		end

		table.insert(driveWheels, {
			part = wheel,
			constraint = constraint,
		})
	end

	if #driveWheels == 0 then
		return nil, "Vehicle has no drive wheels configured"
	end

	return {
		config = config,
		primaryPart = primaryPart,
		steerAttachments = steerAttachments,
		driveWheels = driveWheels,
		referenceWheel = driveWheels[1].part,
	}, nil
end

function Vehicle.getExitCFrame(seatPart: VehicleSeat): CFrame?
	local exitAttachment = seatPart:FindFirstChild("ExitAttachment")
	if exitAttachment and exitAttachment:IsA("Attachment") then
		return exitAttachment.WorldCFrame
	end

	local highestAttachment: Attachment? = nil
	local highestY = -math.huge

	for _, child in seatPart:GetChildren() do
		if child:IsA("Attachment") and child.WorldPosition.Y > highestY then
			highestY = child.WorldPosition.Y
			highestAttachment = child
		end
	end

	if highestAttachment then
		return highestAttachment.WorldCFrame
	end

	return seatPart.CFrame * CFrame.new(0, 3, 0)
end

function Vehicle.placeCharacterAtExit(character: Model, seatPart: VehicleSeat)
	local exitCFrame = Vehicle.getExitCFrame(seatPart)
	if exitCFrame then
		character:PivotTo(exitCFrame)
	end
end

return Vehicle
