-- Notifications, TextUI and progress bars use the table forms of msk_core 4.1.0.
-- An older msk_core shows broken notifications, so say it loudly on start.
MSK.Check.Dependency('msk_core', '4.1.0', true)

local AUTHOR = "MSK-Scripts"
local NAME   = "VERSIONS"
local FILE   = "EngineToggle.json"

local RESOURCE_NAME = "msk_enginetoggle"
local NAME_COLORED  = "[^2"..GetCurrentResourceName().."^0]"
local GITHUB_API    = "https://raw.githubusercontent.com/%s/%s/main/%s"
local DOWNLOAD  = "https://github.com/%s/%s/releases/latest"

local PrintKeyScripts = function()
    local VehicleScript = ("^3[%s]^0"):format(Config.VehicleKeys.script)

    if Config.VehicleKeys.enable then
        if (GetResourceState(Config.VehicleKeys.script) == "started") then
            print(("%s Script %s was found and is running!"):format(NAME_COLORED, VehicleScript))
        elseif (GetResourceState(Config.VehicleKeys.script) == "stopped") then
            print(("%s Script %s was found but is stopped, please start the Script!"):format(NAME_COLORED, VehicleScript))
        elseif (GetResourceState(Config.VehicleKeys.script) == "missing") then
            print(("%s Script %s was not found, please make sure that the Script is started!"):format(NAME_COLORED, VehicleScript))
        end
    end
end

VersionChecker = function()
    SetTimeout(1000, function()
        if RESOURCE_NAME ~= GetCurrentResourceName() then
            CreateThread(function()
                while true do
                    print(("%s [^3WARNING^0] ^3This resource should not be renamed! This can lead to errors. Please rename it to '%s'"):format(NAME_COLORED, RESOURCE_NAME))
                    Wait(5000)
                end
            end)
        end

        PerformHttpRequest(GITHUB_API:format(AUTHOR, NAME, FILE), function(status, response, headers)
            if status ~= 200 then
                return print(("%s [^1ERROR^0] ^1Version Check failed! Http Error: %s^0"):format(NAME_COLORED, status))
            end

            local response = json.decode(response)
            local latestVersion = response[1].version
            local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
            
            if currentVersion == latestVersion then
                if Config.VersionChecker then
                    print(("%s ^2✓ Resource is Up to Date^0 - ^5Current Version: ^2%s^0"):format(NAME_COLORED, currentVersion))
                    PrintKeyScripts()
                end
                return 
            end

            local cV = MSK.String.Split(currentVersion, '.')
            local lV = MSK.String.Split(latestVersion, '.')

            for i = 1, #cV do
                local current, latest = tonumber(cV[i]), tonumber(lV[i])
        
                if current ~= latest then
                    if current < latest then
                        print(("%s [^3Update Available^0] ^3An Update is available for %s! ^0[^5Current Version: ^1%s^0 - ^5Latest Version: ^2%s^0]\r\n%s ^5Download:^4 %s ^0"):format(NAME_COLORED, RESOURCE_NAME, currentVersion, latestVersion, NAME_COLORED, DOWNLOAD:format(AUTHOR, RESOURCE_NAME)))
                        
                        for i = 1, #response do 
                            if response[i].version == currentVersion then break end

                            if response[i].changelogs then
                                print(("%s [^3Changelogs v%s^0]"):format(NAME_COLORED, response[i].version))
                
                                for k = 1, #response[i].changelogs do
                                    print(('%s %s'):format(NAME_COLORED, response[i].changelogs[k]))
                                end
                            end
                        end
            
                        break
                    else 
                        if Config.VersionChecker then 
                            print(("%s ^3Beta Version detected! ^0[^5Current Version: ^3%s^0 - ^5Latest Version: ^2%s^0] - ^3You can ignore this message!^0"):format(NAME_COLORED, currentVersion, latestVersion))
                        end

                        break 
                    end
                end
            end

            PrintKeyScripts()
        end)
    end)
end
VersionChecker()