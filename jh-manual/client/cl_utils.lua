-- Utility functions for manual transmission

-- Vehicle data caching system
local cachedVehicleData = {
    maxGears = 6,
    topSpeed = 0.0,
    handle = nil
}

AddEventHandler('baseevents:enteredVehicle', function(veh, seat, name, class)
    if seat == -1 then
        cachedVehicleData.handle = veh
        cachedVehicleData.maxGears = GetVehicleHandlingInt(veh, "CHandlingData", "nInitialDriveGears")
        cachedVehicleData.topSpeed = GetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDriveMaxFlatVel")
        
        -- Initialize the UI with vehicle data
        if Config.Settings.UseNUI then
            SendNUIMessage({ action = "initHUD", gears = cachedVehicleData.maxGears, topSpeed = cachedVehicleData.topSpeed })
        end
        
        TriggerEvent('jh-manual:client:Notify', "Vehicle loaded: " .. cachedVehicleData.maxGears .. " gears")
    end
end)

AddEventHandler('baseevents:leftVehicle', function(veh, seat, name, class)
    if seat == -1 then
        cachedVehicleData.handle = nil
        cachedVehicleData.maxGears = 6
        cachedVehicleData.topSpeed = 0.0
    end
end)

function GetCachedMaxGears()
    return cachedVehicleData.maxGears or 6
end

function GetCachedTopSpeed()
    return cachedVehicleData.topSpeed or 0.0
end

function GetCachedVehicleHandle()
    return cachedVehicleData.handle
end

function SetCurrentGearValue(gear)
    gear = tonumber(gear) or 1
    currentGear = math.floor(gear)
    CurrentGear = currentGear
end

function GetCurrentGearValue()
    return CurrentGear or currentGear or 1
end

function SetNeutralState(value)
    isNeutral = value == true
    Neutral = isNeutral
end

local rawInputHeldState = {}

function IsRawInputButtonPressed(buttonId)
    if not Config.RawInput or not Config.RawInput.Enabled or not buttonId then return false end

    local resourceName = Config.RawInput.Resource or 'RawInput'
    if GetResourceState(resourceName) ~= 'started' then return false end

    local ok, result = pcall(function()
        return exports[resourceName]:IsButtonPressed(buttonId)
    end)
    if ok and type(result) == 'boolean' then
        return result
    end

    ok, result = pcall(function()
        return exports[resourceName]:GetButtonState(buttonId)
    end)
    if ok then
        if type(result) == 'table' then
            return result.pressed == true or result.down == true
        elseif type(result) == 'boolean' then
            return result
        end
    end

    return false
end

function IsRawInputButtonJustPressed(buttonId)
    if not Config.RawInput or not Config.RawInput.Enabled or not buttonId then return false end

    local resourceName = Config.RawInput.Resource or 'RawInput'
    if GetResourceState(resourceName) ~= 'started' then return false end

    local ok, result = pcall(function()
        return exports[resourceName]:IsButtonJustPressed(buttonId)
    end)
    if ok and type(result) == 'boolean' then
        return result
    end

    local pressed = IsRawInputButtonPressed(buttonId)
    local wasPressed = rawInputHeldState[buttonId] == true
    rawInputHeldState[buttonId] = pressed

    return pressed and not wasPressed
end

function MaxSpeedForGear(gear)
    return Config.MaxSpeedPerGear[gear] or 0.0
end

function GetSpeedInMs(veh)
    -- GetEntitySpeed returns speed in m/s
    return GetEntitySpeed(veh)
end

function GetSpeedInKmh(veh)
    -- Convert m/s to km/h
    return GetEntitySpeed(veh) * 3.6
end

function ApplyOverRevvingDamage(veh)
    if not Config.Settings.MoneyShiftDamage then return end
    
    local health = GetVehicleEngineHealth(veh)
    SetVehicleEngineHealth(veh, health - Config.OverRevving.DamageAmount)
    SetVehicleEngineOn(veh, false, true, true) -- Kill engine immediately
    
    -- Add smoke effect
    SmashVehicleWindow(veh, 0)
    SmashVehicleWindow(veh, 1)
    
    TriggerEvent('jh-manual:client:Notify', "Engine over-revved! Damage taken!")
end

function TriggerEngineSmoke(veh)
    -- Add smoke effect when over-revving
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedOnEntity("exp_grd_bzgas_smoke", veh, 0.0, 0.0, 0.2, 0.0, 0.0, 0.0, 1.0, false, false, false)
end

function PerformRevBlip(veh)
    local rpm = GetVehicleCurrentRpm(veh)
    if rpm < 0.9 then
        -- Force a temporary RPM spike to match the lower gear
        SetVehicleCurrentRpm(veh, rpm + 0.15)
        
        -- Play rev sound for feedback
        PlaySoundFromEntity(-1, "BLIP", veh, "RESPAWN_CONTROLLER_SOUNDS", false, false)
    end
end

function CheckMoneyShift(veh, targetGear)
    if targetGear == 0 then return end -- Neutral/Reverse safety
    
    if not Config.Settings.MoneyShiftDamage then return end

    local currentSpeed = GetEntitySpeed(veh) -- Meters per second
    local maxGears = GetCachedMaxGears()
    local topSpeed = GetCachedTopSpeed()
    
    -- Calculate estimated max speed for the target gear
    -- Example: 2nd gear in a 6-speed car is roughly 33% of top speed
    local gearRatio = targetGear / maxGears
    local maxSafeSpeed = (topSpeed * gearRatio) * 1.2 -- 20% buffer for "redline"

    if currentSpeed > maxSafeSpeed then
        -- CATASTROPHIC FAILURE
        local damage = (currentSpeed - maxSafeSpeed) * Config.DamageMult
        local currentHealth = GetVehicleEngineHealth(veh)
        
        SetVehicleEngineHealth(veh, currentHealth - (damage * 10))
        
        -- Physical Feedback: Lock wheels for a split second
        SetVehicleForwardSpeed(veh, currentSpeed * 0.8)
        SetVehicleWheelsCanBreak(veh, true)
        
        -- Visuals & Audio
        PlaySoundFromEntity(-1, "Vehicle_Damage_Glass_Break", veh, "FAMOUS_STUNT_SOUNDSET", false, false)
        SmashVehicleWindow(veh, 0)
        SmashVehicleWindow(veh, 1)
        
        -- Try to trigger QB-Core stress if available
        TriggerServerEvent('hud:server:GainStress', 15)
        
        TriggerEvent('jh-manual:client:Notify', "TRANSMISSION BLOWN: MONEY SHIFT", "error")
    end
end

-- Exported functions for external scripts
function getCurrentGear()
    return GetCurrentGearValue()
end

function setCurrentGear(gear)
    SetCurrentGearValue(gear)
    TriggerEvent('jh-manual:client:GearChanged', currentGear)
end

function isClutchActive()
    return clutchActive
end

function isEngineStalled()
    return isStalled
end

function isInNeutral()
    return isNeutral
end

function setNeutral(value)
    SetNeutralState(value)
    TriggerEvent('jh-manual:client:Notify', value and "Neutral Engaged" or "Neutral Disengaged")
end

function isLaunchControlActive()
    return launchControlActive
end

function GetShiftDelay(veh)
    if not Config.ShiftDelay.Enabled then return 0 end
    
    local vehicleClass = GetVehicleClass(veh)
    
    -- Check if this class has a custom delay
    if Config.ShiftDelay.ByClass[vehicleClass] then
        return Config.ShiftDelay.ByClass[vehicleClass]
    end
    
    -- Return default delay
    return Config.ShiftDelay.DefaultDelay
end

function isCurrentlyShifting()
    return isShifting
end
