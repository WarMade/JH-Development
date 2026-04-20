if not ActivePatrols then ActivePatrols = {} end
local activePatrols = ActivePatrols

local MAX_AMBIENT_PATROLS = 2
local SPAWN_CHECK_INTERVAL = 15000
local DESPAWN_DISTANCE = 400.0
local MIN_SPAWN_DISTANCE = 120.0
local MAX_SPAWN_DISTANCE = 220.0

local function GetCurrentJurisdiction(coords)
    if not coords then
        return "LSPD"
    end

    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    if Config.Highways and Config.Highways[streetHash] then
        return "STATE"
    end

    if coords.y > 2000 then
        return "BCSO"
    end

    return "LSPD"
end

local function GetDistrictAtCoords(coords)
    return GetCurrentJurisdiction(coords)
end

-- Ensure it is NOT local so other client scripts and exports can use it
function GetClosestPatrol(radius)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestVeh = nil
    local minDist = radius or 60.0

    for _, patrol in ipairs(activePatrols or {}) do
        if patrol and DoesEntityExist(patrol.veh) and DoesEntityExist(patrol.ped) and not patrol.isChasing then
            local dist = #(coords - GetEntityCoords(patrol.veh))
            if dist < minDist then
                minDist = dist
                closestPed = patrol.ped
                closestVeh = patrol.veh
            end
        end
    end
    
    return closestPed, closestVeh
end

local function CleanupAmbientPatrols(playerCoords)
    for i = #activePatrols, 1, -1 do
        local patrol = activePatrols[i]

        if not patrol or not DoesEntityExist(patrol.veh) or not DoesEntityExist(patrol.ped) then
            table.remove(activePatrols, i)
        else
            local patrolCoords = GetEntityCoords(patrol.veh)
            if #(playerCoords - patrolCoords) > DESPAWN_DISTANCE then
                SetEntityAsMissionEntity(patrol.ped, true, true)
                SetEntityAsMissionEntity(patrol.veh, true, true)
                DeleteEntity(patrol.ped)
                DeleteEntity(patrol.veh)
                table.remove(activePatrols, i)
            end
        end
    end
end

local function CountNearbyPatrols(playerCoords, district, radius)
    local count = 0

    for _, patrol in ipairs(activePatrols) do
        if DoesEntityExist(patrol.veh) and DoesEntityExist(patrol.ped) and patrol.district == district then
            local patrolCoords = GetEntityCoords(patrol.veh)
            if #(playerCoords - patrolCoords) <= radius then
                count = count + 1
            end
        end
    end

    return count
end

local function FindNaturalSpawnPoint(playerCoords)
    for _ = 1, 16 do
        local angle = math.rad(math.random(0, 359))
        local distance = math.random(MIN_SPAWN_DISTANCE, MAX_SPAWN_DISTANCE)

        local candidate = vector3(
            playerCoords.x + (math.cos(angle) * distance),
            playerCoords.y + (math.sin(angle) * distance),
            playerCoords.z
        )

        local found, roadCoords, roadHeading = GetClosestVehicleNodeWithHeading(candidate.x, candidate.y, candidate.z, 1, 3.0, 0)
        if found then
            local spawnCoords = vector3(roadCoords.x, roadCoords.y, roadCoords.z)
            local roadDistance = #(playerCoords - spawnCoords)

            if roadDistance >= MIN_SPAWN_DISTANCE and roadDistance <= (MAX_SPAWN_DISTANCE + 40.0) then
                return vector4(spawnCoords.x, spawnCoords.y, spawnCoords.z, roadHeading)
            end
        end
    end

    return nil
end

function SpawnAmbientUnit(district)
    local data = Config.Districts[district] or Config.Districts["LSPD"]
    local pModel = data.peds[math.random(#data.peds)]
    local vModel = data.vehicles[math.random(#data.vehicles)]

    -- FIND A NATURAL ROAD POSITION NEAR PLAYER
    local playerCoords = GetEntityCoords(PlayerPedId())
    local ret, spawnPos, spawnHeading = GetClosestVehicleNodeWithHeading(
        playerCoords.x + math.random(-150, 150),
        playerCoords.y + math.random(-150, 150),
        playerCoords.z,
        1, 3, 0
    )

    if ret then
        local ped, veh = SpawnPoliceUnit(pModel, vModel, vector4(spawnPos.x, spawnPos.y, spawnPos.z, spawnHeading))
        if not ped or not veh then return end

        SetPedRandomComponentVariation(ped, 0)
        SetPedRandomProps(ped)

        -- Make them drive naturally
        TaskVehicleDriveWander(ped, veh, 18.0, 786603)

        table.insert(activePatrols, {ped = ped, veh = veh, district = district, model = vModel, isChasing = false, stage = 'search'})
    end
end

CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        -- Clean up distant patrols
        for i = #activePatrols, 1, -1 do
            local patrol = activePatrols[i]
            if DoesEntityExist(patrol.veh) then
                if #(coords - GetEntityCoords(patrol.veh)) > 400.0 then
                    DeleteEntity(patrol.ped)
                    DeleteEntity(patrol.veh)
                    table.remove(activePatrols, i)
                end
            else
                table.remove(activePatrols, i)
            end
        end

        -- Maintain 2 ambient patrols near the player
        if #activePatrols < 2 then
            SpawnAmbientUnit(GetCurrentJurisdiction(coords))
        end

        Wait(15000)
    end
end)