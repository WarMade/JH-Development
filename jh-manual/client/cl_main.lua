currentGear = currentGear or 1
CurrentGear = currentGear
isNeutral = isNeutral or false
Neutral = isNeutral
clutchActive = clutchActive or false
isStalled = isStalled or false
launchControlActive = launchControlActive or false
isShifting = isShifting or false

-- Main transmission loop
CreateThread(function()
    while true do
        local sleep = 1000 -- Default sleep for optimization
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            -- Only run high-frequency logic if NOT in auto mode
            if Config.Settings.DefaultMode ~= "auto" then
                sleep = 10 -- Switch to high-performance polling

                -- Force the vehicle's automatic brain to stay in our selected gear
                SetVehicleHighGear(veh, currentGear)

                -- Neutral removes drive force
                if isNeutral then
                    SetVehicleCheatPowerIncrease(veh, 0.0)
                else
                    SetVehicleCheatPowerIncrease(veh, 1.0)
                end
            else
                -- In Auto Mode: reset the car to default GTA behavior
                SetVehicleHighGear(veh, -1)
                SetVehicleCheatPowerIncrease(veh, 1.0)
            end
        end

        Wait(sleep)
    end
end)

-- Clutch Control Thread
CreateThread(function()
    while true do
        local sleep = 100
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Config.Settings.DefaultMode ~= "auto" then
            sleep = 0
            
            local clutchPressed = IsControlPressed(0, 21)
            if Config.RawInput.Enabled and Config.RawInput.Buttons.Clutch then
                clutchPressed = clutchPressed or IsRawInputButtonPressed(Config.RawInput.Buttons.Clutch)
            end

            if clutchPressed then
                clutchActive = true
                SetVehicleCheatPowerIncrease(veh, 0.0) -- Disconnect engine power
            else
                clutchActive = false
                SetVehicleCheatPowerIncrease(veh, 1.0) -- Restore power
            end
        end
        Wait(sleep)
    end
end)

-- Stalling Logic Thread
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Config.Settings.DefaultMode ~= "auto" and not IsVehicleStopped(veh) then
            sleep = 10 -- High frequency for physics
            
            local rpm = GetVehicleCurrentRpm(veh)
            local speed = GetEntitySpeed(veh) * 2.23694 -- MPH
            local clutchHeld = clutchActive

            -- STALLING LOGIC
            -- Condition: In gear, speed near zero, RPM dropping, and clutch NOT pressed
            if currentGear > 0 and speed < 1.5 and rpm < 0.15 and not clutchHeld then
                if not isStalled then
                    isStalled = true
                    SetVehicleEngineOn(veh, false, true, true)
                    
                    -- Dynamic Feedback (JH Standard)
                    PlaySoundFromEntity(-1, "Engine_Stall", veh, "DLC_PILOT_ENGINE_FAILURE_SOUNDS", false, false)
                    TriggerEvent('jh-manual:client:Notify', "Engine Stalled - Press Clutch & Start", "error")
                    
                    -- Trigger NUI Alert
                    if Config.Settings.UseNUI then
                        SendNUIMessage({ action = "stallAlert", status = true })
                    end
                end
            end

            -- RECOVERY LOGIC
            if isStalled and clutchHeld and IsControlPressed(0, 18) then -- Enter/Input to restart
                isStalled = false
                SetVehicleEngineOn(veh, true, false, true)
                if Config.Settings.UseNUI then
                    SendNUIMessage({ action = "stallAlert", status = false })
                end
            end
        end
        Wait(sleep)
    end
end)

-- Over-Revving Protection Thread
CreateThread(function()
    while true do
        local sleep = 100
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Config.Settings.DefaultMode ~= "auto" then
            if Config.Settings.MoneyShiftDamage and currentGear > 0 and not isNeutral then
                local speed = GetEntitySpeed(veh)
                local maxSpeed = MaxSpeedForGear(currentGear)
                
                if speed > maxSpeed + 10.0 then -- Allow 10 m/s buffer
                    ApplyOverRevvingDamage(veh)
                end
            end
        end
        Wait(sleep)
    end
end)

-- Engine Braking Thread
CreateThread(function()
    while true do
        local sleep = 100
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Config.Settings.DefaultMode ~= "auto" then
            -- Engine braking: Apply resistance when in gear, clutch not held, throttle not pressed
            if Config.EngineBraking.Enabled and currentGear > 0 and not clutchActive and not isNeutral and GetControlNormal(0, 71) < 0.1 then
                local rpm = GetVehicleCurrentRpm(veh)
                local currentSpeed = GetEntitySpeed(veh)
                
                -- Calculate compression braking based on RPM and gear
                local compressionFactor = (rpm - Config.EngineBraking.MinRpmThreshold) * Config.EngineBraking.BrakingStrength
                
                if compressionFactor > 0 then
                    -- Apply gradual speed reduction
                    SetVehicleForwardSpeed(veh, currentSpeed - compressionFactor)
                end
            end
        end
        Wait(sleep)
    end
end)

-- Camera Shake & Immersion Thread
CreateThread(function()
    while true do
        local sleep = 100
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Config.Settings.DefaultMode ~= "auto" and Config.CameraShake.Enabled then
            sleep = 50 -- Higher frequency for smooth camera effects
            
            local rpm = GetVehicleCurrentRpm(veh)
            
            -- High RPM vibration (engine spinning hard)
            if rpm > 0.9 then
                ShakeGameplayCam("VIBRATION_SHAKE", rpm * Config.CameraShake.HighRpmShake)
            -- Near-stall or stalled shudder
            elseif isStalled or (rpm < 0.2 and currentGear > 0) then
                ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", Config.CameraShake.StallShake)
            else
                -- Smooth idle vibration if in gear
                if currentGear > 0 and not isNeutral and rpm > 0.3 then
                    ShakeGameplayCam("VIBRATION_SHAKE", rpm * Config.CameraShake.IdleShake)
                else
                    StopGameplayCamShaking(false)
                end
            end
        else
            StopGameplayCamShaking(false)
        end
        Wait(sleep)
    end
end)

-- Launch Control Thread (Anti-wheelspin acceleration)
CreateThread(function()
    while true do
        local sleep = 100
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Config.Settings.DefaultMode ~= "auto" and Config.LaunchControl.Enabled then
            sleep = 50 -- High frequency for launch control
            
            local throttleInput = GetControlNormal(0, 71) -- Throttle input
            local isLaunchGear = false
            
            -- Check if current gear is in launch control allowed gears
            for _, gear in ipairs(Config.LaunchControl.EnabledGears) do
                if currentGear == gear then
                    isLaunchGear = true
                    break
                end
            end
            
            -- Activate launch control on hard throttle in low gears while speed is low
            if isLaunchGear and throttleInput > Config.LaunchControl.ThrottleThreshold and GetEntitySpeed(veh) < 5.0 and clutchActive then
                launchControlActive = true
                
                -- Cap RPM to prevent wheelspin
                local currentRpm = GetVehicleCurrentRpm(veh)
                if currentRpm > Config.LaunchControl.MaxLaunchRpm then
                    SetVehicleCurrentRpm(veh, Config.LaunchControl.MaxLaunchRpm)
                end
                
                -- Anti-lag pops/backfires
                if Config.LaunchControl.AntiLagEnabled and math.random() < Config.LaunchControl.AntiLagChance then
                    local exhaustBone = GetEntityBoneIndexByName(veh, "exhaust")
                    if exhaustBone ~= -1 then
                        local exhaustCoords = GetWorldPositionOfEntityBone(veh, exhaustBone)
                        -- Silent explosion for visual/particle effect only
                        AddExplosion(exhaustCoords.x, exhaustCoords.y, exhaustCoords.z, 61, 0.0, true, false, 0.0)
                    end
                end
            else
                launchControlActive = false
            end
        else
            launchControlActive = false
        end
        Wait(sleep)
    end
end)