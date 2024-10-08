if Config.Framework == 'AUTO' then
	if GetResourceState('es_extended') ~= 'missing' then
        ESX = exports["es_extended"]:getSharedObject()
    elseif GetResourceState('qb-core') ~= 'missing' then
        QBCore = exports['qb-core']:GetCoreObject()
    end
elseif Config.Framework == 'ESX' then
	ESX = exports["es_extended"]:getSharedObject()
elseif Config.Framework == 'QBCore' then
	QBCore = exports['qb-core']:GetCoreObject()
else
	-- Add your own code here
end

currentVehicle = {}
isInVehicle, isEnteringVehicle, disabledDrive = false, false, false

if Config.Command.enable then
	RegisterCommand(Config.Command.command, function(source, args, rawCommand)
		toggleEngine()
	end)

	if Config.Hotkey.enable then
		RegisterKeyMapping(Config.Command.command, 'Toggle Engine', 'keyboard', Config.Hotkey.key)
	end
end

toggleEngine = function(bypass)
	local playerPed = PlayerPedId()
	local canToggleEngine = true

	if not IsPedInAnyVehicle(playerPed) then return end
	local vehicle = GetVehiclePedIsIn(playerPed)

	if not Config.EngineFromSecondSeat and GetPedInVehicleSeat(vehicle, -1) ~= playerPed then return end

	if Config.EngineFromSecondSeat then
		if playerPed ~= GetPedInVehicleSeat(vehicle, -1) and playerPed ~= GetPedInVehicleSeat(vehicle, 0) then
			return
		end

		if IsVehicleSeatFree(vehicle, -1) then return end
	end

	if GetVehicleDamaged(vehicle) then 
		return Config.Notification(nil, Translation[Config.Locale]['veh_is_damaged'], 'error')
	end
	
	if not bypass then
		local isBlacklisted = IsVehicleBlacklisted(vehicle)

		if isBlacklisted then
			return -- Just return without any info
		end

		local isWhitelisted = IsVehicleWhitelisted(vehicle)

		if not isWhitelisted then
			canToggleEngine = getIsKeyOwner(vehicle)
		end
	end
	
	if not canToggleEngine then 
		return Config.Notification(nil, Translation[Config.Locale]['key_nokey'], 'error')
	end

	local isEngineOn = GetIsVehicleEngineRunning(vehicle)
	SetEngineState(vehicle, not isEngineOn, true)
	
	if isEngineOn then
		CreateThread(disableDrive)
		Config.Notification(nil, Translation[Config.Locale]['engine_stop'], 'success')
	else
		disabledDrive = false
		Config.Notification(nil, Translation[Config.Locale]['engine_start'], 'success')
	end

	TriggerEvent('msk_enginetoggle:toggledEngine', vehicle, not isEngineOn)
	TriggerServerEvent('msk_enginetoggle:toggledEngine', VehToNet(vehicle), not isEngineOn)
end
exports('toggleEngine', toggleEngine)
RegisterNetEvent('msk_enginetoggle:toggleEngine', toggleEngine)

AddEventHandler('msk_enginetoggle:enteringVehicle', function(vehicle, plate, seat, netId, isEngineOn, isDamaged)
	logging('debug', 'enteringVehicle', vehicle, plate, seat, netId, isEngineOn, isDamaged)
	local playerPed = PlayerPedId()
	local vehicleModel = GetEntityModel(vehicle)

	if seat == -1 and not isEngineOn then
		if not Config.EngineOnAtEnter then
			SetEngineState(vehicle, false, true)
			CreateThread(disableDrive)
		end
	elseif seat == -1 and isEngineOn and (IsThisModelAHeli(vehicleModel) or IsThisModelAPlane(vehicleModel)) then
		SetEngineState(vehicle, true, true)
		SetHeliBladesFullSpeed(vehicle)
	end
end)

AddEventHandler('msk_enginetoggle:enteredVehicle', function(vehicle, plate, seat, netId, isEngineOn, isDamaged)
	logging('debug', 'enteredVehicle', vehicle, plate, seat, netId, isEngineOn, isDamaged)
	local playerPed = PlayerPedId()
	local vehicleModel = GetEntityModel(vehicle)

	if seat == -1 and not isEngineOn then
		if not Config.EngineOnAtEnter then
			SetEngineState(vehicle, false, true)
			CreateThread(disableDrive)
		else
			SetEngineState(vehicle, true, true)
		end
	elseif seat == -1 and isEngineOn and (IsThisModelAHeli(vehicleModel) or IsThisModelAPlane(vehicleModel)) then
		SetEngineState(vehicle, true, true)
		SetHeliBladesFullSpeed(vehicle)
	end
end)

AddEventHandler('msk_enginetoggle:exitedVehicle', function(vehicle, plate, seat, netId, isEngineOn, isDamaged)
	logging('debug', 'exitedVehicle', vehicle, plate, seat, netId, isEngineOn, isDamaged)
	if not vehicle or not DoesEntityExist(vehicle) then return end
	local playerPed = PlayerPedId()
	local vehicleModel = GetEntityModel(vehicle)

	if seat == -1 and not isEngineOn then
		SetEngineState(vehicle, false, true)
	end
end)

CreateThread(function()
	while true do
		local sleep = 500
		local playerPed = PlayerPedId()
		local vehiclePool = GetGamePool('CVehicle')

		for i = 1, #vehiclePool do
			local vehicle = vehiclePool[i]

			if DoesEntityExist(vehicle) and not GetVehicleDamaged(vehicle) and IsVehicleSeatFree(vehicle, -1) and (not IsPedInAnyVehicle(playerPed, false) or (IsPedInAnyVehicle(playerPed, false) and vehicle ~= GetVehiclePedIsIn(playerPed, false))) then
				local vehicleModel = GetEntityModel(vehicle)

				if IsThisModelACar(vehicleModel) then
					local steeringAngle = GetSteeringAngle(vehicle)

					if steeringAngle and steeringAngle ~= GetVehicleSteeringAngle(vehicle) then
						SetSteeringAngle(vehicle, steeringAngle)
					end
				end

				if IsThisModelAHeli(vehicleModel) or IsThisModelAPlane(vehicleModel) then
					if GetEngineState(vehicle) then
						SetEngineState(vehicle, true, true)
						SetHeliBladesFullSpeed(vehicle)
					end
				end
			end
		end

		Wait(sleep)
	end
end)

-- Credits to ESX Legacy (https://github.com/esx-framework/esx_core/blob/main/%5Bcore%5D/es_extended/client/modules/actions.lua)
CreateThread(function()
	while true do
		local sleep = 200
		local playerPed = PlayerPedId()

		if not isInVehicle and not IsPlayerDead(PlayerId()) then
			if DoesEntityExist(GetVehiclePedIsTryingToEnter(playerPed)) and not isEnteringVehicle then
				local vehicle = GetVehiclePedIsTryingToEnter(playerPed)
                local plate = GetVehicleNumberPlateText(vehicle)
                local seat = GetSeatPedIsTryingToEnter(playerPed)
				local netId = VehToNet(vehicle)
				local isEngineOn = GetEngineState(vehicle)
				local isDamaged = GetVehicleDamaged(vehicle)
				isEnteringVehicle = true
				TriggerEvent('msk_enginetoggle:enteringVehicle', vehicle, plate, seat, netId, isEngineOn, isDamaged)
                TriggerServerEvent('msk_enginetoggle:enteringVehicle', plate, seat, netId, isEngineOn, isDamaged)
			elseif not DoesEntityExist(GetVehiclePedIsTryingToEnter(playerPed)) and not IsPedInAnyVehicle(playerPed, true) and isEnteringVehicle then
				TriggerEvent('msk_enginetoggle:enteringVehicleAborted')
                TriggerServerEvent('msk_enginetoggle:enteringVehicleAborted')
                isEnteringVehicle = false
			elseif IsPedInAnyVehicle(playerPed, false) then
				isEnteringVehicle = false
                isInVehicle = true
				currentVehicle.vehicle = GetVehiclePedIsIn(playerPed)
				currentVehicle.plate = GetVehicleNumberPlateText(currentVehicle.vehicle)
				currentVehicle.seat = GetPedVehicleSeat(playerPed, currentVehicle.vehicle)
				currentVehicle.netId = VehToNet(currentVehicle.vehicle)
				currentVehicle.isEngineOn = GetEngineState(currentVehicle.vehicle)
				currentVehicle.isDamaged = GetVehicleDamaged(currentVehicle.vehicle)
				TriggerEvent('msk_enginetoggle:enteredVehicle', currentVehicle.vehicle, currentVehicle.plate, currentVehicle.seat, currentVehicle.netId, currentVehicle.isEngineOn, currentVehicle.isDamaged)
                TriggerServerEvent('msk_enginetoggle:enteredVehicle', currentVehicle.plate, currentVehicle.seat, currentVehicle.netId, currentVehicle.isEngineOn, currentVehicle.isDamaged)
			end
		elseif isInVehicle then
			if not IsPedInAnyVehicle(playerPed, false) or IsPlayerDead(PlayerId()) then
				isInVehicle = false
				TriggerEvent('msk_enginetoggle:exitedVehicle', currentVehicle.vehicle, currentVehicle.plate, currentVehicle.seat, currentVehicle.netId, currentVehicle.isEngineOn, currentVehicle.isDamaged)
                TriggerServerEvent('msk_enginetoggle:exitedVehicle', currentVehicle.plate, currentVehicle.seat, currentVehicle.netId, currentVehicle.isEngineOn, currentVehicle.isDamaged)
				currentVehicle = {}
			end
		end

		Wait(sleep)
	end
end)

SetEngineState = function(vehicle, state, engine)
	assert(vehicle and DoesEntityExist(vehicle), 'Parameter "vehicle" is nil or the Vehicle does not exist on function SetEngineState')
	logging('debug', 'SetEngineState', vehicle, state)

	currentVehicle.isEngineOn = state
	Entity(vehicle).state:set('isEngineOn', state, true)

	SetVehicleUndriveable(vehicle, not state)
	SetVehicleKeepEngineOnWhenAbandoned(vehicle, state)

	if state then
		SetSteeringAngle(vehicle, 0.0)
	end

	if not engine then return end
	SetVehicleEngineOn(vehicle, state, false, true)
end
exports('SetEngineState', SetEngineState) -- Do not use this Export if you don't know what you are doing!!!
RegisterNetEvent('msk_enginetoggle:setEngineState', SetEngineState) -- Do not use this Event if you don't know what you are doing!!!

GetEngineState = function(vehicle)
	if not vehicle then vehicle = GetVehiclePedIsIn(PlayerPedId()) end
	assert(vehicle and DoesEntityExist(vehicle), 'Parameter "vehicle" is nil or the Vehicle does not exist on function GetEngineState')

	if Entity(vehicle).state.isEngineOn == nil then
		SetEngineState(vehicle, GetIsVehicleEngineRunning(vehicle), false)
	end
	return Entity(vehicle).state.isEngineOn
end
exports('GetEngineState', GetEngineState)
exports('getEngineState', GetEngineState) -- Support for old versions

SetVehicleDamaged = function(vehicle, state)
	assert(vehicle and DoesEntityExist(vehicle), 'Parameter "vehicle" is nil or the Vehicle does not exist on function SetVehicleDamaged')

	currentVehicle.isDamaged = state
	Entity(vehicle).state:set('isDamaged', state, true)

	if state then 
		SetEngineState(vehicle, false, true) 

		local playerPed = PlayerPedId()
		if IsPedInAnyVehicle(playerPed) then
			if vehicle == GetVehiclePedIsIn(playerPed) then
				CreateThread(disableDrive)
			end
		end
	end
end
exports('SetVehicleDamaged', SetVehicleDamaged)
exports('setVehicleDamaged', SetVehicleDamaged) -- Support for old versions
RegisterNetEvent('msk_enginetoggle:setVehicleDamaged', SetVehicleDamaged)

GetVehicleDamaged = function(vehicle)
	if not vehicle then vehicle = GetVehiclePedIsIn(PlayerPedId()) end
	assert(vehicle and DoesEntityExist(vehicle), 'Parameter "vehicle" is nil or the Vehicle does not exist on function GetVehicleDamaged')

	if Entity(vehicle).state.isDamaged == nil then
		SetVehicleDamaged(vehicle, false)
	end
	return Entity(vehicle).state.isDamaged
end
exports('GetVehicleDamaged', GetVehicleDamaged)
exports('getVehicleDamaged', GetVehicleDamaged) -- Support for old versions

disableDrive = function()
	if disabledDrive then return end
	disabledDrive = true

	while isInVehicle and disabledDrive and GetPedVehicleSeat() == -1 and not currentVehicle.isEngineOn do
		local sleep = 1

		DisableControlAction(0, 71, true) -- W (accelerate)
		DisableControlAction(0, 72, true) -- S (brake/reverse)

		if currentVehicle.vehicle and DoesEntityExist(currentVehicle.vehicle) then 
			SetVehicleUndriveable(currentVehicle.vehicle, true) 
		end

		Wait(sleep)
	end

	disabledDrive = false
end

logging = function(code, ...)
    if not Config.Debug then return end
    MSK.Logging(code, ...)
end