-- VehicleController LocalScript in StarterPlayerScripts
--[[
	Drives any registered vehicle the local player sits in.
	Place this once in StarterPlayerScripts; do not copy per vehicle.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Vehicle = require(ReplicatedStorage.Modules.Vehicle)

local player = Players.LocalPlayer

local connections: {RBXScriptConnection} = {}
local visualWheelConnection: RBXScriptConnection? = nil
local activeWheelVisuals = {}
local currentSeat: VehicleSeat? = nil
local activeCharacter: Model? = nil

local function getVisualWheelTuningOffset(visualPart: BasePart): CFrame
	-- Optional per-mesh tuning attributes, in degrees.
	-- Add these Attributes to a VisualWheel if the imported mesh faces sideways/backward:
	-- VisualWheelOffsetX, VisualWheelOffsetY, VisualWheelOffsetZ
	local offsetX = tonumber(visualPart:GetAttribute("VisualWheelOffsetX")) or 0
	local offsetY = tonumber(visualPart:GetAttribute("VisualWheelOffsetY")) or 0
	local offsetZ = tonumber(visualPart:GetAttribute("VisualWheelOffsetZ")) or 0

	return CFrame.Angles(
		math.rad(offsetX),
		math.rad(offsetY),
		math.rad(offsetZ)
	)
end

local function buildActiveWheelVisuals(vehicleModel: Model)
	local wheelVisuals = Vehicle.getWheelVisuals(vehicleModel)
	local activeVisuals = {}

	for _, wheelVisual in wheelVisuals do
		local physicalWheel = wheelVisual.physicalWheel
		local visualPart = wheelVisual.visualPart
		if physicalWheel.Parent and visualPart.Parent then
			table.insert(activeVisuals, {
				physicalWheel = physicalWheel,
				visualPart = visualPart,
				welds = wheelVisual.welds,
				visualOffset = physicalWheel.CFrame:ToObjectSpace(visualPart.CFrame) * getVisualWheelTuningOffset(visualPart),
			})
		end
	end

	return activeVisuals
end

local function setVisualWheelWeldsEnabled(enabled: boolean)
	for _, wheelVisual in activeWheelVisuals do
		for _, weld in wheelVisual.welds do
			if weld.Parent then
				weld.Enabled = enabled
			end
		end
	end
end

local function snapVisualWheelsToPhysicalWheels()
	for _, wheelVisual in activeWheelVisuals do
		local physicalWheel = wheelVisual.physicalWheel
		local visualPart = wheelVisual.visualPart
		if physicalWheel.Parent and visualPart.Parent then
			visualPart.CFrame = physicalWheel.CFrame * wheelVisual.visualOffset
		end
	end
end

local function stopVisualWheelSync()
	if visualWheelConnection then
		visualWheelConnection:Disconnect()
		visualWheelConnection = nil
	end

	snapVisualWheelsToPhysicalWheels()
	setVisualWheelWeldsEnabled(true)
	table.clear(activeWheelVisuals)
end

local function disconnectSignals()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	stopVisualWheelSync()
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

local function startVisualWheelSync(vehicleModel: Model, seatPart: VehicleSeat)
	stopVisualWheelSync()

	activeWheelVisuals = buildActiveWheelVisuals(vehicleModel)
	if #activeWheelVisuals == 0 then
		return
	end

	snapVisualWheelsToPhysicalWheels()
	setVisualWheelWeldsEnabled(false)

	visualWheelConnection = RunService.RenderStepped:Connect(function()
		if currentSeat ~= seatPart or not seatPart.Occupant then
			stopVisualWheelSync()
			return
		end

		snapVisualWheelsToPhysicalWheels()
	end)
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
	startVisualWheelSync(vehicleModel, seatPart)

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
