-- VehicleService Script in ServerScriptService
--[[
	Handles network ownership for every registered vehicle seat.
	One script covers all vehicles; add new cars in Studio only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vehicle = require(ReplicatedStorage.Modules.Vehicle)

local activeSeats: {[Player]: VehicleSeat} = {}

local function releaseOwnership(player: Player)
	local seat = activeSeats[player]
	if not seat then
		return
	end

	if seat.Parent then
		local rootPart = seat.AssemblyRootPart
		if rootPart and rootPart:GetNetworkOwner() == player then
			rootPart:SetNetworkOwner(nil)
		end
	end

	activeSeats[player] = nil
end

local function assignOwnership(player: Player, seat: VehicleSeat)
	releaseOwnership(player)

	local vehicleModel = Vehicle.getVehicleModel(seat)
	if vehicleModel then
		Vehicle.setupWheelVisuals(vehicleModel)
	end

	local rootPart = seat.AssemblyRootPart
	if not rootPart then
		return
	end

	local success, errorMessage = pcall(function()
		rootPart:SetNetworkOwner(player)
	end)

	if success then
		activeSeats[player] = seat
	else
		warn(`Failed to assign vehicle ownership to {player.Name}: {errorMessage}`)
	end
end

local function onHumanoidSeated(player: Player, humanoid: Humanoid, active: boolean, seatPart: BasePart?)
	if active and seatPart and Vehicle.isVehicleSeat(seatPart) then
		assignOwnership(player, seatPart)
		return
	end

	if activeSeats[player] then
		releaseOwnership(player)
	end
end

local function bindCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	humanoid.Seated:Connect(function(active, seatPart)
		onHumanoidSeated(player, humanoid, active, seatPart)
	end)

	humanoid.Died:Connect(function()
		releaseOwnership(player)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)

	if player.Character then
		bindCharacter(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(releaseOwnership)
