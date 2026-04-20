local QBCore = exports['qb-core']:GetCoreObject()
local isRacing = false
local finishCoords = nil
local raceStake = 0
local raceDistance = 250 -- Default from your .ini file
local opponentPed, opponentVeh, finishBlip

-- Thread to detect burnout and challenge nearby AI
CreateThread(function()
    while true do
        local sleep = 500
        local playerPed = PlayerPedId()
        local playerVeh = GetVehiclePedIsIn(playerPed, false)

        -- Check if player is in a car and doing a burnout (L2 + R2 / LT + RT)
        if playerVeh ~= 0 and IsVehicleInBurnout(playerVeh) then
            sleep = 0
            local coords = GetEntityCoords(playerPed)
            
            -- Find the closest vehicle
            local targetVeh = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)
            
            if targetVeh ~= 0 and targetVeh ~= playerVeh then
                local opponent = GetPedInVehicleSeat(targetVeh, -1)
                
                -- Ensure it's an NPC and they aren't already racing
                if opponent ~= 0 and not IsPedAPlayer(opponent) and not isRacing then
                    Wait(500)
                    if IsVehicleInBurnout(playerVeh) then
                        -- GENERATE RANDOM AMOUNT [500 - 1000]
                        local randomWager = math.random(500, 1000)
                        
                        -- Start the race with the new random amount
                        StartAIRace(opponent, targetVeh, randomWager)
                        
                        -- Cooldown to prevent multiple races triggering at once
                        Wait(10000) 
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Race finish line detection loop
CreateThread(function()
    while true do
        local sleep = 1000
        if isRacing and finishCoords and DoesEntityExist(opponentVeh) then
            -- Continuously force the NPC to keep the gas floored
            SetVehicleForwardSpeed(opponentVeh, GetEntitySpeed(opponentVeh) + 0.2)
            -- (The above adds a tiny bit of acceleration every frame to simulate a "tuned" car)
        end
        if isRacing and finishCoords then
            sleep = 0
            
            -- Marker Type 4 is a "Checkered Flag" style cylinder in some versions, 
            -- or use Type 0/1 for a solid pillar of light.
            DrawMarker(4, finishCoords.x, finishCoords.y, finishCoords.z + 1.0, 0, 0, 0, 0, 0, 0, 4.0, 4.0, 4.0, 255, 255, 255, 200, true, false, 2, false, nil, nil, false)
            
            -- Also drawing a large circle on the ground for high-speed visibility
            DrawMarker(1, finishCoords.x, finishCoords.y, finishCoords.z - 1.0, 0, 0, 0, 0, 0, 0, 15.0, 15.0, 1.0, 255, 255, 255, 100, false, false, 2, false, nil, nil, false)

            local pCoords = GetEntityCoords(PlayerPedId())
            if #(pCoords - finishCoords) < 15.0 then
                isRacing = false
                TriggerServerEvent('jh-moneyraces:server:winRace', raceStake)
                CleanupRace() -- Function to remove blips
            end
        end
        Wait(sleep)
    end
end)

-- Function to create a finish line blip
function CreateFinishBlip(coords)
    -- Remove old blip if it exists
    if finishBlip then RemoveBlip(finishBlip) end

    finishBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(finishBlip, 491) -- 491 is the Race Finish/Checkered Flag
    SetBlipDisplay(finishBlip, 4)
    SetBlipScale(finishBlip, 1.2)
    SetBlipColour(finishBlip, 5) -- Yellow (to match your theme)
    SetBlipAsShortRange(finishBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Finish Line")
    EndTextCommandSetBlipName(finishBlip)
    SetBlipRoute(finishBlip, true) -- Draws the path on the GPS
end

-- Function to start an AI race
function StartAIRace(aiPed, aiVeh, amount)
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    if playerVeh == 0 then return end

    -- 1. Setup Finish Line (250m)
    local raceDistance = 250.0
    local coords = GetEntityCoords(playerVeh)
    local forward = GetEntityForwardVector(playerVeh)
    finishCoords = vector3(coords.x + (forward.x * raceDistance), coords.y + (forward.y * raceDistance), coords.z)

    -- 2. "Unlock" the AI Vehicle's Potential
    SetVehicleModKit(aiVeh, 0)
    SetVehicleMod(aiVeh, 11, 3, false) -- Max Engine
    SetVehicleMod(aiVeh, 13, 2, false) -- Max Transmission
    SetVehicleCheatPowerIncrease(aiVeh, 2.0) -- Doubled torque for that "top speed" feel
    
    -- 3. NPC Burnout Phase
    -- We force the NPC to hold the brake and gas for 2 seconds before taking off
    QBCore.Functions.Notify("The local is warming up his tires...", "primary")
    TaskVehicleTempAction(aiPed, aiVeh, 23, 2000) -- Action 23 is a burnout/handbrake rev
    Wait(2000)

    -- 4. The High-Speed Takeoff
    SetEntityAsMissionEntity(aiPed, true, true)
    SetBlockingOfNonTemporaryEvents(aiPed, true)
    SetPedFleeAttributes(aiPed, 0, false)
    
    -- Driving Style 786603 + Custom Speed
    -- We use 150.0 m/s (roughly 335 mph) as the target so the AI never "throttles back"
    TaskVehicleDriveToCoord(aiPed, aiVeh, finishCoords.x, finishCoords.y, finishCoords.z, 150.0, 1, GetEntityModel(aiVeh), 786603, 1.0, true)
    
    -- Force the engine to redline
    SetVehicleHighGear(aiVeh, GetVehicleHandlingInt(aiVeh, "CHandlingData", "nInitialDriveGears"))
    
    raceStake = amount
    isRacing = true
    
    TriggerServerEvent('jh-moneyraces:server:startAIRace', amount)
    CreateFinishBlip(finishCoords)
    QBCore.Functions.Notify("GO!", "success")

    -- MONITOR AI WIN CONDITION
    CreateThread(function()
        while isRacing do
            local aiCoords = GetEntityCoords(aiPed)
            local aiDist = #(aiCoords - finishCoords)

            if aiDist < 15.0 then
                -- THE AI WON
                isRacing = false
                finishCoords = nil
                ClearGpsMultiRoute()
                QBCore.Functions.Notify("You lost the illegal street race.", "error")
                PlayAmbientSpeech1(aiPed, "GENERIC_INSULT_HIGH", "SPEECH_PARAMS_FORCE")
                break
            end
            Wait(500)
        end
    end)
end


function RunRaceLogic(finishLine, amount)
    isRacing = true
    finishBlip = AddBlipForCoord(finishLine.x, finishLine.y, finishLine.z)
    SetBlipRoute(finishBlip, true)

    CreateThread(function()
        while isRacing do
            local sleep = 0
            local pCoords = GetEntityCoords(PlayerPedId())
            local aiCoords = GetEntityCoords(opponentPed)
            
            -- Check Player Win
            if #(pCoords - finishLine) < 10.0 then
                isRacing = false
                TriggerServerEvent('jh-illegalraces:server:winRace', amount)
                CleanupRace()
            end

            -- Check AI Win [cite: 37]
            if #(aiCoords - finishLine) < 10.0 then
                isRacing = false
                QBCore.Functions.Notify("The illegal street race was lost.", "error")
                PlayAmbientSpeech1(opponentPed, "GENERIC_INSULT_HIGH", "SPEECH_PARAMS_FORCE") -- From DLL [cite: 34]
                CleanupRace()
            end
            Wait(sleep)
        end
    end)
end

function CleanupRace()
    isRacing = false
    if finishBlip then 
        RemoveBlip(finishBlip) 
        finishBlip = nil 
    end
    if opponentVeh then SetDriveTaskStopAtTrafficLights(opponentVeh, true) end -- Reset behavior
    finishCoords = nil
    ClearGpsMultiRoute()
end

RegisterCommand('streetrace', function(source, args)
    local amount = tonumber(args[1]) or 100
    StartIllegalRace(amount)
end)