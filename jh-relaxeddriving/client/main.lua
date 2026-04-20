local QBCore = exports['qb-core']:GetCoreObject()
local isRelaxed = false
local playerPed = PlayerPedId()

-- Wait for player to load
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerPed = PlayerPedId()
    print('^2[qb-relaxeddriving] ^7Relaxed Driving Style loaded')
end)

-- Main loop
CreateThread(function()
    while true do
        Wait(500)

        if not Config.EnableScript then goto continue end

        playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == playerPed then
            local vehClass = GetVehicleClass(vehicle)

            -- Check if vehicle class is allowed
            local allowed = #Config.AllowedClasses == 0
            for _, class in ipairs(Config.AllowedClasses) do
                if vehClass == class then
                    allowed = true
                    break
                end
            end

            if allowed then
                -- Apply relaxed driving style
                SetDriveTaskDrivingStyle(playerPed, Config.DrivingStyle)
                SetDriverAggressiveness(playerPed, Config.DriverAggressiveness)

                -- Optional: relaxed ped config flag (helps with one-hand lean)
                SetPedConfigFlag(playerPed, 424, true)  -- relaxed driving flag
            end
        else
            -- Reset when not driving
            if isRelaxed then
                SetDriverAggressiveness(playerPed, 0.5)
                SetPedConfigFlag(playerPed, 424, false)
                isRelaxed = false
            end
        end

        ::continue::
    end
end)

-- Optional hotkey toggle
if Config.ToggleKey then
    RegisterCommand('relaxeddrive', function()
        Config.EnableScript = not Config.EnableScript
        QBCore.Functions.Notify('Relaxed Driving Style: ' .. (Config.EnableScript and '^2ENABLED' or '^1DISABLED'), 'primary')
    end, false)

    RegisterKeyMapping('relaxeddrive', 'Toggle Relaxed Driving Style', 'keyboard', 'F10')
end