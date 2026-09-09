-- Which table holds owned vehicles is a property of the framework, so that is
-- the one thing still worth asking msk_core about. Qbox uses the same
-- player_vehicles layout as QBCore, verified against qbx_vehicles/vehicles.sql.
--
-- The framework detection that used to sit here is gone: msk_core has done it
-- already, and this file's own copy knew nothing about Qbox.
local vehicleTables = {
    ESX    = { table = 'owned_vehicles',  owner = 'owner'     },
    QBCore = { table = 'player_vehicles', owner = 'citizenid' },
    Qbox   = { table = 'player_vehicles', owner = 'citizenid' },
}

local vehicleTable = vehicleTables[MSK.Bridge.Framework.Type]

VEHICLE_TABLE_NAME = vehicleTable and vehicleTable.table or ''
OWNER_COLUMN_NAME = vehicleTable and vehicleTable.owner or ''

if Config.EnableLockpick then
    alterDatabase = function()        
        MySQL.query.await(("ALTER TABLE %s ADD COLUMN IF NOT EXISTS `alarmStage` varchar(50) NOT NULL DEFAULT 'stage_1';"):format(VEHICLE_TABLE_NAME))
    end
    alterDatabase()

    -- MSK.RegisterItem covers ESX, QBCore and Qbox in a single call.
    MSK.RegisterItem(Config.LockpickSettings.item, function(source)
        TriggerClientEvent('msk_enginetoggle:toggleLockpick', source)
    end)

    for stage, data in pairs(Config.SafetyStages) do
        MSK.RegisterItem(data.item, function(source)
            TriggerClientEvent('msk_enginetoggle:installAlarmStage', source, stage)
        end)
    end
end

HasPlayerJob = function(Player)
    for i=1, #Config.PoliceAlert do
        if Config.PoliceAlert[i] == GetPlayerJob(Player) then
            return true
        end
    end
    return false
end

-- Als gestohlen markierte Fahrzeuge (plate -> true). Wird nur bei aktivem LiveCoords-Blip gesetzt
-- und dient dazu, die DB-Query in enteredVehicle auf die wenigen relevanten Fälle zu beschränken.
StolenVehicles = {}

-- Anti-Spam Cooldowns pro Spieler und Aktion
local cooldowns = {}

isOnCooldown = function(src, key, ms)
    local now = GetGameTimer()
    cooldowns[src] = cooldowns[src] or {}

    if cooldowns[src][key] and now < cooldowns[src][key] then
        return true
    end

    cooldowns[src][key] = now + ms
    return false
end

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)

-- Prüft serverseitig, ob der Spieler wirklich in der Nähe der Entity ist. Verhindert Remote-Aufrufe
-- (z.B. Keys/Alarme für Fahrzeuge am anderen Ende der Map).
isPlayerNearEntity = function(src, entity, maxDist)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local pedCoords = GetEntityCoords(ped)
    local entityCoords = GetEntityCoords(entity)
    return #(pedCoords - entityCoords) <= (maxDist or 10.0)
end

-- Serverinterne Ermittlung von Owner + Stage. Der Owner-Identifier verlässt damit nie den Client.
getAlarmData = function(plate)
    if VEHICLE_TABLE_NAME == '' or OWNER_COLUMN_NAME == '' then return nil, 'stage_1' end

    local result = MySQL.query.await(('SELECT %s, alarmStage FROM %s WHERE plate = @plate'):format(OWNER_COLUMN_NAME, VEHICLE_TABLE_NAME), {
        ['@plate'] = MSK.String.Trim(plate)
    })

    if result and result[1] then
        return result[1][OWNER_COLUMN_NAME], result[1].alarmStage
    end
    return nil, 'stage_1'
end

-- Der Client-Callback gibt ausschließlich die Stage zurück (für den akustischen Alarm), niemals den Owner.
MSK.Register('msk_enginetoggle:getAlarmStage', function(source, plate)
    local _, stage = getAlarmData(plate)
    return stage
end)

RegisterNetEvent('msk_enginetoggle:removeLockpickItem', function()
    if not Config.LockpickSettings.removeItem then return end
    local src = source
    local Player = GetPlayerFromId(src)

    if not Player then return end

    Player.RemoveItem(Config.LockpickSettings.item, 1)
end)

RegisterNetEvent('msk_enginetoggle:saveAlarmStage', function(plate, stage)
    local playerId = source

    -- Stage gegen die Config validieren, sonst könnte ein Client eine beliebige Zeichenkette in die DB schreiben
    if not Config.SafetyStages[stage] then return end

    local Player = GetPlayerFromId(playerId)
    if not Player then return end
	local identifier = GetPlayerIdentifier(Player)

    local result = MySQL.query.await(('SELECT * FROM %s WHERE %s = @owner AND plate = @plate'):format(VEHICLE_TABLE_NAME, OWNER_COLUMN_NAME), {
		['@owner'] = identifier,
		['@plate'] = MSK.String.Trim(plate)
	})

	if result and result[1] and result[1][OWNER_COLUMN_NAME] == identifier then
		MySQL.update(('UPDATE %s SET alarmStage = @alarmStage WHERE %s = @owner AND plate = @plate'):format(VEHICLE_TABLE_NAME, OWNER_COLUMN_NAME), {
            ['@alarmStage'] = stage,
            ['@owner'] = identifier,
            ['@plate'] = MSK.String.Trim(plate),
        })
    else
        Config.Notification(playerId, Translation[Config.Locale]['not_vehicle_owner'], 'error')
	end
end)

-- Interne Alert-Funktionen (keine offenen NetEvents mehr!). Owner und Koordinaten werden
-- ausschließlich serverseitig aus triggerAlarm ermittelt und sind damit nicht mehr spoofbar.
notifyOwner = function(owner, coords)
    local Player = GetPlayerFromIdentifier(owner)
    if not Player then return end

    local playerId = Player.source
    if not playerId then return end
    Config.Notification(playerId, Translation[Config.Locale]['stole_vehicle'])
    TriggerClientEvent('msk_enginetoggle:showBlipCoords', playerId, coords)
end

notifyPolice = function(coords)
    -- One list on every framework, and every entry carries .source and .job.
    for _, Player in pairs(MSK.GetPlayers() or {}) do
        if HasPlayerJob(Player) then
            Config.Notification(Player.source, Translation[Config.Locale]['stole_vehicle_police'])
            TriggerClientEvent('msk_enginetoggle:showBlipCoords', Player.source, coords)
        end
    end
end

sendLiveCoords = function(owner, netId, coords)
    local Player = GetPlayerFromIdentifier(owner)
    if not Player then return end

    local playerId = Player.source
    if not playerId then return end
    TriggerClientEvent('msk_enginetoggle:showVehicleBlip', playerId, netId, coords)
end

-- Zentrale, serverseitig validierte Alarm-Auslösung. Der Client sendet nur die netId; Plate, Owner,
-- Stage und Koordinaten ermittelt der Server selbst aus der Entity. Nähe- und Cooldown-Check gegen Spam.
RegisterNetEvent('msk_enginetoggle:triggerAlarm', function(netId)
    local src = source
    local entity = netId and NetworkGetEntityFromNetworkId(netId)

    if not isPlayerNearEntity(src, entity, 10.0) then return end
    if isOnCooldown(src, 'triggerAlarm', 5000) then return end

    local plate = GetVehicleNumberPlateText(entity)
    local owner, stage = getAlarmData(plate)
    local alarmStage = Config.SafetyStages[stage] or Config.SafetyStages['stage_1']
    local coords = GetEntityCoords(entity)

    if alarmStage.ownerAlert and owner then
        notifyOwner(owner, coords)
    end

    if alarmStage.policeAlert then
        notifyPolice(coords)
    end

    if alarmStage.liveCoords and owner then
        StolenVehicles[MSK.String.Trim(plate)] = true
        sendLiveCoords(owner, netId, coords)
    end
end)

-- Serverseitig validierte Schlüsselsuche: prüft Nähe + Cooldown, würfelt den Fund selbst und vergibt
-- den TempKey. Ersetzt das alte clientseitige math.random und den offenen addTempKey-Event.
MSK.Register('msk_enginetoggle:searchKey', function(source, netId)
    local src = source
    local entity = netId and NetworkGetEntityFromNetworkId(netId)

    if not isPlayerNearEntity(src, entity, 10.0) then return false end
    if isOnCooldown(src, 'searchKey', 3000) then return false end

    if math.random(100) > Config.LockpickSettings.searchKey then
        return false
    end

    if Config.VehicleKeys.enable and GetResourceState(Config.VehicleKeys.script) == 'started' then
        local plate = GetVehicleNumberPlateText(entity)
        local model = GetEntityModel(entity)
        giveTempKey(src, plate, model)
    end

    return true
end)