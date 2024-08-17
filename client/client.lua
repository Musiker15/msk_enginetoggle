if Config.Framework == 'ESX' then
	ESX = exports["es_extended"]:getSharedObject()
elseif Config.Framework == 'QBCore' then
	QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'Standalone' then
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
	local currVehicle = GetVehiclePedIsIn(playerPed)

	if not Config.EngineFromSecondSeat and GetPedInVehicleSeat(currVehicle, -1) ~= playerPed then return end

	if Config.EngineFromSecondSeat then
		if playerPed ~= GetPedInVehicleSeat(currVehicle, -1) and playerPed ~= GetPedInVehicleSeat(currVehicle, 0) then
			return
		end

		if IsVehicleSeatFree(currVehicle, -1) then return end
	end
	
	if not bypass then
		canToggleEngine = getIsVehicleOrKeyOwner(currVehicle)
	end
	
	if not canToggleEngine then 
		return Config.Notification(nil, Translation[Config.Locale]['key_nokey'], 'error')
	end

	if GetVehicleDamaged(currVehicle) then return end
	local isEngineOn = GetIsVehicleEngineRunning(currVehicle)

	SetEngineState(currVehicle, not isEngineOn, true)
	SetVehicleKeepEngineOnWhenAbandoned(currVehicle, not isEngineOn)
	
	if isEngineOn then
		CreateThread(disableDrive)
		Config.Notification(nil, Translation[Config.Locale]['engine_stop'], 'success')
	else
		disabledDrive = false
		Config.Notification(nil, Translation[Config.Locale]['engine_start'], 'success')
	end
end
exports('toggleEngine', toggleEngine)
RegisterNetEvent('msk_enginetoggle:toggleEngine', toggleEngine)

AddEventHandler('msk_enginetoggle:enteringVehicle', function(vehicle, plate, seat, netId, isEngineOn, isDamaged)
	logging('enteringVehicle', vehicle, plate, seat, netId, isEngineOn, isDamaged)
	local playerPed = PlayerPedId()
	local vehicleModel = GetEntityModel(vehicle)

	if seat == -1 and not isEngineOn then
		logging('SetVehicleUndriveable')

		if not Config.EngineOnAtEnter then
			SetEngineState(vehicle, false, true)
			SetVehicleKeepEngineOnWhenAbandoned(vehicle, false)
		end
	elseif seat == -1 and isEngineOn and (IsThisModelAHeli(vehicleModel) or IsThisModelAPlane(vehicleModel)) then
		SetEngineState(vehicle, true, true)
		SetVehicleKeepEngineOnWhenAbandoned(vehicle, true)
		SetHeliBladesFullSpeed(vehicle)
	end
end)

AddEventHandler('msk_enginetoggle:enteredVehicle', function(vehicle, plate, seat, netId, isEngineOn, isDamaged)
	logging('enteredVehicle', vehicle, plate, seat, netId, isEngineOn, isDamaged)
	local playerPed = PlayerPedId()
	local vehicleModel = GetEntityModel(vehicle)

	if seat == -1 and not isEngineOn then
		logging('SetVehicleUndriveable')

		if not Config.EngineOnAtEnter then
			SetEngineState(vehicle, false, true)
			SetVehicleKeepEngineOnWhenAbandoned(vehicle, false)
			CreateThread(disableDrive)
		else
			SetEngineState(vehicle, true, true)
			SetVehicleKeepEngineOnWhenAbandoned(vehicle, true)
		end
	elseif seat == -1 and isEngineOn and (IsThisModelAHeli(vehicleModel) or IsThisModelAPlane(vehicleModel)) then
		SetEngineState(vehicle, true, true)
		SetVehicleKeepEngineOnWhenAbandoned(vehicle, true)
		SetHeliBladesFullSpeed(vehicle)
	end
end)

AddEventHandler('msk_enginetoggle:exitedVehicle', function(vehicle, plate, seat, netId, isEngineOn, isDamaged)
	logging('exitedVehicle', vehicle, plate, seat, netId, isEngineOn, isDamaged)
	local playerPed = PlayerPedId()
	local vehicleModel = GetEntityModel(vehicle)

	if seat == -1 and not isEngineOn then
		logging('SetVehicleUndriveable')
		SetEngineState(vehicle, false, true)
		SetVehicleKeepEngineOnWhenAbandoned(vehicle, false)
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

				if (IsThisModelAHeli(vehicleModel) or IsThisModelAPlane(vehicleModel)) then
					if GetEngineState(vehicle) then
						SetEngineState(vehicle, true, true)
						SetVehicleKeepEngineOnWhenAbandoned(vehicle, true)
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
                TriggerServerEvent('msk_enginetoggle:enteredVehicle', currentVehicle.plate, currentVehicle.seat, currentVehicle.netId,currentVehicle.isEngineOn, currentVehicle.isDamaged)
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
	if not DoesEntityExist(vehicle) then return end
	logging('SetEngineState', vehicle, state)

	currentVehicle.isEngineOn = state
	Entity(vehicle).state:set('isEngineOn', state, true)

	if not engine then return end
	SetVehicleEngineOn(vehicle, state, false, true)
	SetVehicleUndriveable(vehicle, not state)
end
exports('SetEngineState', SetEngineState)

GetEngineState = function(vehicle)
	if not vehicle then vehicle = GetVehiclePedIsIn(PlayerPedId()) end
	if not DoesEntityExist(vehicle) then return end

	if Entity(vehicle).state.isEngineOn == nil then
		SetEngineState(vehicle, GetIsVehicleEngineRunning(vehicle), false)
	end
	return Entity(vehicle).state.isEngineOn
end
exports('GetEngineState', GetEngineState)
exports('getEngineState', GetEngineState) -- Support for old versions

SetVehicleDamaged = function(vehicle, state)
	if not DoesEntityExist(vehicle) then return end
	logging('SetVehicleDamaged', vehicle, state)

	currentVehicle.isDamaged = state
	Entity(vehicle).state:set('isDamaged', state, true)
end
exports('SetVehicleDamaged', SetVehicleDamaged)
exports('setVehicleDamaged', SetVehicleDamaged) -- Support for old versions
RegisterNetEvent('msk_enginetoggle:setVehicleDamaged', SetVehicleDamaged)

GetVehicleDamaged = function(vehicle)
	if not vehicle then vehicle = GetVehiclePedIsIn(PlayerPedId()) end
	if not DoesEntityExist(vehicle) then return end

	if Entity(vehicle).state.isDamaged == nil then
		SetVehicleDamaged(vehicle, false)
	end
	return Entity(vehicle).state.isDamaged
end
exports('GetVehicleDamaged', GetVehicleDamaged)
exports('getVehicleDamaged', GetVehicleDamaged) -- Support for old versions

GetPedVehicleSeat = function(playerPed, vehicle)
	if not playerPed then playerPed = PlayerPedId() end
	if not vehicle then vehicle = GetVehiclePedIsIn(playerPed) end
	if not DoesEntityExist(vehicle) then return end

    for i = -1, 16 do
        if (GetPedInVehicleSeat(vehicle, i) == playerPed) then 
			return i 
		end
    end	
    return -1
end

disableDrive = function()
	if disabledDrive then return end
	disabledDrive = true

	while isInVehicle and disabledDrive and GetPedVehicleSeat() == -1 and not currentVehicle.isEngineOn do
		local sleep = 1

		DisableControlAction(0, 71, true) -- W
		DisableControlAction(0, 72, true) -- S

		Wait(sleep)
	end

	disabledDrive = false
end

logging = function(...)
	if not Config.Debug then return end
	print('[^3DEBUG^0]', ...)
end