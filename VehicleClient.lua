-- VehicleController LocalScript in StarterPlayerScripts
--[[
	Drives any registered vehicle the local player sits in.
	Place this once in StarterPlayerScripts; do not copy per vehicle.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vehicle = require(ReplicatedStorage.Modules.Vehicle)

local player = Players.LocalPlayer

local connections: {RBXScriptConnection} = {}
local currentSeat: VehicleSeat? = nil
local activeCharacter: Model? = nil

local function disconnectSignals()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function clearVehicleState()
	disconnectSignals()
	currentSeat = nil
end

local function applySteer(steerAttachments: {Attachment}, steerFloat: number, turnSpeed: number, tweenTime: number)
	local orientation = Vector3.new(0, -steerFloat * turnSpeed, 90)
	local tweenInfo = TweenInfo.new(tweenTime)

	for _, attachment in steerAttachments do
		TweenService:Create(attachment, tweenInfo, {Orientation = orientation}):Play()
	end
end

local function applyThrottle(
	driveWheels: {{part: BasePart, constraint: CylindricalConstraint}},
	seat: VehicleSeat,
	throttleFloat: number,
	idleTorque: number
)
	local referenceWheel = driveWheels[1].part
	local wheelRadius = referenceWheel.Size.Y / 2
	if wheelRadius <= 0 then
		return
	end

	local torque = math.abs(throttleFloat) * seat.Torque
	if torque == 0 then
		torque = idleTorque
	end

	local angularVelocity = math.sign(throttleFloat) * (seat.MaxSpeed / wheelRadius)

	for _, wheelData in driveWheels do
		wheelData.constraint.MotorMaxTorque = torque
		wheelData.constraint.AngularVelocity = angularVelocity
	end
end

local function bindVehicleSeat(seatPart: VehicleSeat)
	local vehicleModel = Vehicle.getVehicleModel(seatPart)
	if not vehicleModel then
		return
	end

	local components, errorMessage = Vehicle.getDriveComponents(vehicleModel)
	if not components then
		warn(`Vehicle setup error for {vehicleModel:GetFullName()}: {errorMessage}`)
		return
	end

	currentSeat = seatPart

	table.insert(connections, seatPart:GetPropertyChangedSignal("SteerFloat"):Connect(function()
		if currentSeat ~= seatPart then
			return
		end

		applySteer(
			components.steerAttachments,
			seatPart.SteerFloat,
			seatPart.TurnSpeed,
			components.config.steerTween
		)
	end))

	table.insert(connections, seatPart:GetPropertyChangedSignal("ThrottleFloat"):Connect(function()
		if currentSeat ~= seatPart then
			return
		end

		applyThrottle(
			components.driveWheels,
			seatPart,
			seatPart.ThrottleFloat,
			components.config.idleTorque
		)
	end))

	applySteer(
		components.steerAttachments,
		seatPart.SteerFloat,
		seatPart.TurnSpeed,
		components.config.steerTween
	)
	applyThrottle(
		components.driveWheels,
		seatPart,
		seatPart.ThrottleFloat,
		components.config.idleTorque
	)
end

local function onHumanoidSeated(active: boolean, seatPart: BasePart?)
	if not active or not seatPart then
		if currentSeat and activeCharacter then
			Vehicle.placeCharacterAtExit(activeCharacter, currentSeat)
		end
		clearVehicleState()
		return
	end

	if not Vehicle.isVehicleSeat(seatPart) then
		clearVehicleState()
		return
	end

	disconnectSignals()
	bindVehicleSeat(seatPart)
end

local function bindCharacter(character: Model)
	activeCharacter = character
	clearVehicleState()

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Seated:Connect(onHumanoidSeated)
end

if player.Character then
	bindCharacter(player.Character)
end

player.CharacterAdded:Connect(bindCharacter)
