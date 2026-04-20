local currentPatrol = nil

-- Call this when a player enters a "Stalking" zone or territory
function StartAmbientPatrol(zoneCoords)
    if currentPatrol then return end -- Don't stack patrols

    local vehModel = `police`
    local pedModel = `s_m_y_cop_01`
    
    -- Basic model loading omitted for brevity
    
    local spawnCoords = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 150.0, 0.0) -- Spawn out of sight
    local vehicle = CreateVehicle(vehModel, spawnCoords, 0.0, true, false)
    local pilot = CreatePedInsideVehicle(vehicle, 4, pedModel, -1, true, false)

    -- The "Natural" Secret: Wander Task
    -- 262144 is the driving style for "Normal/Avoid Cops" (Natural driving)
    TaskVehicleDriveWander(pilot, vehicle, 20.0, 262144) 
    
    currentPatrol = {veh = vehicle, ped = pilot}
end

-- Call this to clean up the patrol when the player leaves the zone
function StopAmbientPatrol()
    if not currentPatrol then return end

    if DoesEntityExist(currentPatrol.ped) then
        DeleteEntity(currentPatrol.ped)
    end
    if DoesEntityExist(currentPatrol.veh) then
        DeleteEntity(currentPatrol.veh)
    end

    currentPatrol = nil
end