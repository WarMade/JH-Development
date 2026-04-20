local lastGear = -1
local lastRpm = 0.0
local lastStallState = false

CreateThread(function()
    while true do
        local sleep = 250 -- Slow update for UI to save resources
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Config.Settings.UseNUI then
            sleep = 100 -- Faster update when driving
            
            local rpm = GetVehicleCurrentRpm(veh)
            local gearDisplay = currentGear
            
            -- Convert gear display (0=R, 1=N, 2+=gear number)
            if currentGear == 0 then
                gearDisplay = "R"
            elseif currentGear == 1 then
                gearDisplay = "N"
            else
                gearDisplay = currentGear - 1
            end
            
            -- Only send update if gear or RPM changed significantly or stall state changed
            if currentGear ~= lastGear or math.abs(rpm - lastRpm) > 0.05 or isStalled ~= lastStallState then
                lastGear = currentGear
                lastRpm = rpm
                lastStallState = isStalled
                
                SendNUIMessage({
                    action = "updateHUD",
                    gear = gearDisplay,
                    rpm = rpm,
                    speed = GetEntitySpeed(veh),
                    speedMph = GetEntitySpeed(veh) * 2.23694,
                    isStalled = isStalled,
                    isNeutral = isNeutral,
                    clutchActive = clutchActive,
                    isShifting = isShifting
                })
            end
        else
            -- Hide UI if not in vehicle or NUI disabled
            if lastGear ~= -1 then
                SendNUIMessage({ action = "hideHUD" })
                lastGear = -1
                lastRpm = 0.0
                lastStallState = false
            end
        end
        Wait(sleep)
    end
end)

-- Listen for events from server or other scripts
RegisterNetEvent('jh-manual:client:GearChanged', function(newGear)
    -- UI already handles this, but can add custom logic here
    TriggerEvent('jh-manual:client:Notify', "Gear: " .. newGear)
end)

RegisterNetEvent('jh-manual:client:Notify', function(message, notificationType)
    notificationType = notificationType or "info"
    
    -- Send to NUI for dashboard notification
    if Config.Settings.UseNUI then
        SendNUIMessage({
            action = "notify",
            message = message,
            type = notificationType
        })
    end
    
    -- Also use FiveM native notification as fallback
    TriggerEvent('chat:addMessage', {
        args = {"Manual Transmission", message},
        color = {255, 0, 0}
    })
end)
