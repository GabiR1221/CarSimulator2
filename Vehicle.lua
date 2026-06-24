-- Vehicle Module in ReplicatedStorage.Modules
--[[
	Shared vehicle utilities for server and client.

	Studio setup (per vehicle model):
	1. Tag the model with CollectionService tag "Vehicle" OR set Attribute IsVehicle = true
	2. Set Model.PrimaryPart
	3. Add a VehicleSeat anywhere under the model
	4. On PrimaryPart: AttachmentFL and AttachmentFR (steering)
	5. Drive wheels (default WheelBL, WheelBR) each with a CylindricalConstraint motor
	6. Optional: ExitAttachment on the seat for spawn position on exit

	Optional attributes on the model:
	- VehicleDriveWheels (string): "WheelBL,WheelBR"
	- VehicleSteerAttachments (string): "AttachmentFL,AttachmentFR"
	- VehicleIdleTorque (number): default 2000
	- VehicleSteerTween (number): default 0.4
]]

local CollectionService = game:GetService("CollectionService")

local VEHICLE_TAG = "Vehicle"

local DEFAULTS = {
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
	return model:FindFirstChild("WheelBL") ~= nil and model:FindFirstChild("WheelBR") ~= nil
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

	return {
		driveWheels = driveWheelNames,
		steerAttachments = steerAttachmentNames,
		idleTorque = vehicleModel:GetAttribute("VehicleIdleTorque") or DEFAULTS.idleTorque,
		steerTween = vehicleModel:GetAttribute("VehicleSteerTween") or DEFAULTS.steerTween,
	}
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
		local wheel = vehicleModel:FindFirstChild(wheelName, true)
		if not wheel or not wheel:IsA("BasePart") then
			return nil, `Missing drive wheel '{wheelName}'`
		end

		local constraint = wheel:FindFirstChildOfClass("CylindricalConstraint")
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
