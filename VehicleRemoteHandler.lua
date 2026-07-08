-- VehicleRemoteHandler Script in ServerScriptService
--[[
	Server authority for the vehicle garage menu.

	Required remotes in ReplicatedStorage.Remotes.Vehicles:
	- GetMenuData (RemoteFunction)
	- Buy (RemoteFunction)
	- Spawn (RemoteFunction)
	- Customize (RemoteFunction)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleGarage = require(ReplicatedStorage.Modules.VehicleGarage)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Vehicles")

local getMenuDataRemote = remotesFolder:WaitForChild("GetMenuData")
local buyRemote = remotesFolder:WaitForChild("Buy")
local spawnRemote = remotesFolder:WaitForChild("Spawn")
local customizeRemote = remotesFolder:WaitForChild("Customize")

local function isPlayerReady(player: Player): boolean
	return player:FindFirstChild("Loaded") ~= nil and player.Loaded.Value == true
end

getMenuDataRemote.OnServerInvoke = function(player, selectedVehicleId)
	if not isPlayerReady(player) then
		return {catalog = {}, owned = {}, customizations = {sections = {}, equipped = {}}}
	end

	return VehicleGarage.getMenuData(player, selectedVehicleId)
end

buyRemote.OnServerInvoke = function(player, vehicleId)
	if not isPlayerReady(player) then
		return {success = false, reason = "Still loading"}
	end

	return VehicleGarage.buyVehicle(player, vehicleId)
end

spawnRemote.OnServerInvoke = function(player, vehicleId)
	if not isPlayerReady(player) then
		return {success = false, reason = "Still loading"}
	end

	return VehicleGarage.spawnVehicle(player, vehicleId)
end

customizeRemote.OnServerInvoke = function(player, vehicleId, slotName, itemId, color)
	if not isPlayerReady(player) then
		return {success = false, reason = "Still loading"}
	end

	return VehicleGarage.equipCustomization(player, vehicleId, slotName, itemId, color)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		VehicleGarage.despawnVehicle(player)
	end)
end)
