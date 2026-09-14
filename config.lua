Config = {}
----------------------------------------------------------------
Config.Locale = 'de'
Config.Debug = false
Config.VersionChecker = true
----------------------------------------------------------------
-- No longer used. msk_core detects the framework (ESX, QBCore, Qbox or
-- STANDALONE) and this resource asks msk_core about it, so changing the value
-- here has no effect. Pin it in msk_core's config.lua instead.
--
-- The line is kept so that an existing config file does not break.
Config.Framework = 'AUTO'
----------------------------------------------------------------
-- !!! This function is clientside AND serverside !!!
Config.Notification = function(source, message, typ)
    if IsDuplicityVersion() then -- serverside
        MSK.Notification(source, { title = 'Engine', message = message, type = typ })
    else -- clientside
        MSK.Notification({ title = 'Engine', message = message, type = typ })
    end
end
----------------------------------------------------------------
Config.Command = {
    enable = true, -- If you set to false then the Hotkey won't work !!!
    command = 'engine'
}

Config.Hotkey = {
    enable = true, -- Set false if you don't want to use a Hotkey
    key = 'M'
}

Config.AdminCommand = {
    enable = true, -- Start/Stop Engine if you don't have a key for that vehicle
    command = 'adengine',
    groups = {'superadmin', 'admin'}
}

Config.EngineOnAtEnter = false -- Set to true to toggle the engine automatically on when entering a vehicle

-- Set to true to start the engine from the second seat (Co-Driver)
-- Someone has to be on the Driver Seat, otherwise it won't work!
-- If VehicleKeys is activated, the Co-Driver needs a key.
Config.EngineFromSecondSeat = false
----------------------------------------------------------------
-- Vehicle Key System - set true then only the Owner of the Vehicle or someone with a Key can start the Engine

-- msk_vehiclekeys: https://forum.cfx.re/t/esx-qbcore-msk-vehiclekeys-unique-items/5264475
-- vehicles_keys: https://forum.cfx.re/t/esx-qbcore-vehicles-keys-vehicles-lock-remote-control-ui-and-much-more/4857274
-- VehicleKeyChain: https://forum.cfx.re/t/release-vehicle-key-chain-v4-1-4-esx-qb/3319563

Config.VehicleKeys = {
    enable = true, -- Set true to enable this feature

    -- Supported Scripts: 'msk_vehiclekeys', 'VehicleKeyChain', 'vehicles_keys', 'okokGarage', 'wasabi_carlock', 'qs-vehiclekeys'
    script = 'msk_vehiclekeys',

    -- For uniqueItems in ox_inventory, qs-inventory or core_inventory
    item = 'keys', -- Item in your inventory for vehicle keys
}
----------------------------------------------------------------
Config.VehicleClamp = GetResourceState('VehicleClamp') ~= 'missing'
----------------------------------------------------------------
Config.SaveSteeringAngle = true
Config.SaveAngleOnExit = 75 -- default: F - 75 (Exit Vehicle)
----------------------------------------------------------------
-- With this feature you can set vehicles and plates for which you don't need a key to start the engine
-- either exact plates or just a string that should be in the vehicles plate e.g. "ESX" will ignore te plate "ESX1234" too
Config.Whitelist = {
    classes = {

    },
    vehicles = {
        -- Please use `` and NOT '' or ""
        `caddy`, `caddy2`, `caddy3`, `airtug`, `docktug`, `forklift`, `mower`, `tractor2`, 
    },
    plates = {
        "ESX", "MSK", "Test", 
    },
}

Config.Blacklist = {
    classes = {
        13, 21, 
    },
    vehicles = {
        -- Please use `` and NOT '' or ""
        `bmx`, `cruiser`, `fixter`, `scorcher`, `tribike`, `tribike2`, `tribike3`, 
    },
    plates = {
        "ESX2", "MSK2", "Test2", 
    },
}
----------------------------------------------------------------
Config.EnableLockpick = true -- Set false if you want to deactivate this feature

Config.progressBar = function(time, message)
    -- The table form waits until the bar has run out. The callers wait on
    -- their own, so the bar runs in its own thread.
    CreateThread(function()
        MSK.Progress.Start({ duration = time, text = message })
    end)
end

Config.LockpickHotkey = {
    enable = false, -- Set to true if you want to use a Hotkey
    command = 'lockpickvehicle',
    key = 'N'
}

Config.PoliceAlert = {'police', 'sheriff', 'fib'}

Config.SafetyStages = {
    -- Do NOT rename the stages! Only change the options!
    -- On deafult 'stage_1' is installed on every owned vehicle

    ['stage_1'] = {
        item = 'vehicle_alarm_1', -- Usable Item to set the stage to the vehicle
        alarm = true, -- Acustic alarm
        ownerAlert = false, -- Notify Owner
        policeAlert = false, -- Notify Police
        liveCoords = false, -- Owner gets live coords (Blip)
    },
    ['stage_2'] = {
        item = 'vehicle_alarm_2', -- Usable Item to set the stage to the vehicle
        alarm = true, -- Acustic alarm
        ownerAlert = true, -- Notify Owner
        policeAlert = false, -- Notify Police
        liveCoords = false, -- Owner gets live coords (Blip)
    },
    ['stage_3'] = {
        item = 'vehicle_alarm_3', -- Usable Item to set the stage to the vehicle
        alarm = true, -- Acustic alarm
        ownerAlert = true, -- Notify Owner
        policeAlert = true, -- Notify Police
        liveCoords = false, -- Owner gets live coords (Blip)
    },
    ['stage_4'] = {
        item = 'vehicle_alarm_4', -- Usable Item to set the stage to the vehicle
        alarm = true, -- Acustic alarm
        ownerAlert = true, -- Notify Owner
        policeAlert = true, -- Notify Police
        liveCoords = true, -- Owner gets live coords (Blip)
    },
}

Config.LockpickSettings = {
    item = 'lockpick', -- Set the usable item that you want to use
    removeItem = true, -- Set true if you like to remove item after failing lockpicking

    startEngine = true, -- Set true if you want to start the engine after successfull lockpicking
    startEngineBypass = false, -- Set true if you want to start the engine always even if the player hasn't found the key

    -- If you set to 'skillbar' then there won't be a progressbar'
    -- If you set to 'progressbar' then there won't be a skillbar
    action = 'skillbar', -- Set to 'skillbar' or 'progressbar'

    -- If Config.VehicleKeys is activated then the player is always searching for the key
    enableSearchKey = true, -- Set false if you dont want this
    searchKey = 66 -- default: 66% // Probability to find the key
}

Config.LockpickProgessbar = {
    time = 10, -- In seconds // Time how long does it takes
    lockpick = 66, -- default: 66% // Probability successfully lockpick the vehicle
}

Config.LockpickSkillbar = {
    type = 'ox_lib', -- 'ox_lib' or 'qb-skillbar'

    -- This is only if you set to 'ox_lib'
    inputs = {'w', 'a', 's', 'd'},
    difficulty = {
        -- Presets:
        -- 'easy' -> { areaSize: 50, speedMultiplier: 1 }
        -- 'medium' -> { areaSize: 40, speedMultiplier: 1.5 }
        -- 'hard' -> { areaSize: 25, speedMultiplier: 1.75 }
        -- You can also use your own type:
        -- Example: {areaSize = 60, speedMultiplier = 1}

        ['1'] = 'easy', -- 'easy', 'medium', 'hard'
        ['2'] = 'easy', -- 'easy', 'medium', 'hard'
        ['3'] = {areaSize = 60, speedMultiplier = 1}, -- 'easy', 'medium', 'hard'
        ['4'] = 'easy', -- 'easy', 'medium', 'hard'
    }
}

Config.Animation = {
    lockpick = { -- Animation for lockpicking
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        anim = 'machinic_loop_mechandplayer'
    },  
    searchKey = { -- Animation for search key
        dict = 'veh@plane@velum@front@ds@base',
        anim = 'hotwire',
        time = 8, -- in seconds // How long does it take to search for the key
        enableProgressbar = true
    },
    hotwire = { -- Animation for hotwire
        dict = 'veh@forklift@base',
        anim = 'hotwire',
        action = 'skillbar', -- Set to 'skillbar' or 'progressbar'
        time = 15, -- in seconds // How long does it take to hotwire the vehicle // Only for 'progressbar'
    }
}
----------------------------------------------------------------
exports('Config', function()
    return Config
end)