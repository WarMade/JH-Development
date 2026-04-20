-- Cleanup patrol if too far from player
CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds (0.00ms impact)
        if currentPatrol and DoesEntityExist(currentPatrol.veh) and DoesEntityExist(currentPatrol.ped) then
            local pCoords = GetEntityCoords(PlayerPedId())
            local cCoords = GetEntityCoords(currentPatrol.veh)
            if #(pCoords - cCoords) > 300.0 then
                DeleteEntity(currentPatrol.ped)
                DeleteEntity(currentPatrol.veh)
                currentPatrol = nil
            end
        end
    end
end)
-- Respond to dispatch alerts: send patrol to crime scene and engage player
RegisterNetEvent('jh-streetstalk:dispatchAlert', function(targetCoords)
    if currentPatrol and DoesEntityExist(currentPatrol.ped) then
        local pilot = currentPatrol.ped
        local vehicle = currentPatrol.veh

        -- 1. Turn on Sirens
        SetVehicleSiren(vehicle, true)
        SetVehicleHasMutedSirens(vehicle, false)

        -- 2. Switch from "Wander" to "Chase"
        TaskVehicleDriveToCoord(pilot, vehicle, targetCoords.x, targetCoords.y, targetCoords.z, 30.0, 0, GetEntityModel(vehicle), 786603, 10.0, true)
        
        -- 3. Once close, engage combat
        CreateThread(function()
            while true do
                if not DoesEntityExist(pilot) then break end
                local dist = #(GetEntityCoords(pilot) - vector3(targetCoords.x, targetCoords.y, targetCoords.z))
                if dist < 20.0 then
                    TaskCombatPed(pilot, PlayerPedId(), 0, 16)
                    break
                end
                Wait(1000)
            end
        end)
    end
end)
-- Robust police unit spawn logic for 'jh-streetstalk:spawnResponse' event
local activeUnits = {}

RegisterNetEvent('jh-streetstalk:spawnResponse', function(coords, type)
    local model = (type == 'bcso') and `sheriff` or `police2`
    local pedModel = `s_m_y_cop_01`

    -- Load Models
    RequestModel(model)
    RequestModel(pedModel)
    local timeout = 0
    while (not HasModelLoaded(model) or not HasModelLoaded(pedModel)) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    if not HasModelLoaded(model) or not HasModelLoaded(pedModel) then
        print("Failed to load police models.")
        return
    end

    -- Spawn Vehicle
    local vehicle = CreateVehicle(model, coords.x + 10.0, coords.y + 10.0, coords.z, coords.w, true, false)
    NetworkRegisterEntityAsNetworked(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)

    -- Spawn Ped
    local pilot = CreatePedInsideVehicle(vehicle, 4, pedModel, -1, true, false)
    NetworkRegisterEntityAsNetworked(pilot)
    SetEntityAsMissionEntity(pilot, true, true)
    SetPedAsCop(pilot, true)

    -- AI Behavior Settings
    SetVehicleSiren(vehicle, true)
    SetDriverAbility(pilot, 1.0)
    SetDriverAggressiveness(pilot, 1.0)
    SetPedRelationshipGroupHash(pilot, `HATES_PLAYER`)
    TaskVehicleChase(pilot, PlayerPedId())

    table.insert(activeUnits, {veh = vehicle, ped = pilot})
end)
ActivePatrols = ActivePatrols or {}
local activePatrols = ActivePatrols

local function GetCurrentTerritory(coords)
    if not coords then return "unknown" end
    return GetNameOfZone(coords.x, coords.y, coords.z) or "unknown"
end

local function ResolveModel(model)
    return type(model) == 'number' and model or GetHashKey(model)
end

local function GetFallbackVehicleModel(vehicleName)
    local safeModel = ResolveModel((Config and Config.SafeVehicleModel) or 'police')
    if Config and Config.ForceSafeUnitModels then
        return safeModel
    end

    local model = ResolveModel(vehicleName)
    if IsModelInCdimage(model) and IsModelAVehicle(model) and not IsThisModelABike(model) then
        return model
    end

    return safeModel
end

local function GetFallbackPedModel(modelName)
    local safeModel = ResolveModel((Config and Config.SafePedModel) or 's_m_y_cop_01')
    if Config and Config.ForceSafeUnitModels then
        return safeModel
    end

    local model = ResolveModel(modelName)
    if IsModelInCdimage(model) and IsModelValid(model) and IsModelAPed(model) then
        return model
    end

    return safeModel
end

local function GetDistrictLabel(district)
    local data = Config.Districts and Config.Districts[district or '']
    return (data and data.name) or district or 'Dispatch'
end

local function ShowDispatchChatter(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
end

local function PlayDispatchChatter(stage, patrol)
    local chatterSet = Config.DispatchChatter and Config.DispatchChatter[stage]
    if not chatterSet or #chatterSet == 0 then return end
    if math.random() > (Config.ChatterProbability or 0.65) then return end

    local now = GetGameTimer()
    if patrol and patrol.lastChatterAt and (now - patrol.lastChatterAt) < 5000 then
        return
    end

    if patrol then
        patrol.lastChatterAt = now
    end

    local message = chatterSet[math.random(#chatterSet)]
    message = message:gsub('{district}', GetDistrictLabel(patrol and patrol.district))
    ShowDispatchChatter(message)
end

local function GetPlayerDetectionRange(playerPed, currentHeat)
    local speedBonus = GetEntitySpeed(playerPed) * 3.0
    local vehicleBonus = IsPedInAnyVehicle(playerPed, false) and 10.0 or 0.0
    local heatBonus = math.max(currentHeat - (Config.HeatLevelPatrol or 40), 0) * 0.45
    local baseRange = Config.BaseDetectionRange or 22.0
    local maxRange = Config.MaxDetectionRange or 85.0

    return math.min(baseRange + speedBonus + vehicleBonus + heatBonus, maxRange)
end

local function SendPatrolToSearch(patrol, targetCoords, vehicleModel)
    if not targetCoords or not DoesEntityExist(patrol.ped) or not DoesEntityExist(patrol.veh) then return end

    local now = GetGameTimer()
    if patrol.lastSearchUpdate and (now - patrol.lastSearchUpdate) < (Config.SearchUpdateInterval or 4000) then
        return
    end

    patrol.lastSearchUpdate = now
    TaskVehicleDriveToCoord(patrol.ped, patrol.veh, targetCoords.x, targetCoords.y, targetCoords.z, 22.0, 0, ResolveModel(vehicleModel), 786603, 5.0, 20.0)
end

local function CanPatrolIdentifyPlayer(patrol, playerPed, playerCoords, currentHeat)
    if not DoesEntityExist(patrol.ped) or not DoesEntityExist(patrol.veh) then return false end

    local patrolCoords = GetEntityCoords(patrol.veh)
    local dist = #(playerCoords - patrolCoords)
    local detectionRange = GetPlayerDetectionRange(playerPed, currentHeat)
    local hasLOS = HasEntityClearLosToEntity(patrol.ped, playerPed, 17)

    if dist <= 12.0 then
        return true
    end

    if dist <= detectionRange and hasLOS then
        return true
    end

    return false
end

local function StartWarningPhase(patrol, playerCoords)
    patrol.stage = 'warning'
    patrol.stageStartedAt = GetGameTimer()
    patrol.lastKnownCoords = playerCoords

    SetVehicleSiren(patrol.veh, true)
    TaskVehicleDriveToCoord(patrol.ped, patrol.veh, playerCoords.x, playerCoords.y, playerCoords.z, 18.0, 0, ResolveModel(patrol.model), 786603, 6.0, 20.0)
    PlayDispatchChatter('warning', patrol)
end

local function StartStopPhase(patrol, playerPed)
    patrol.stage = 'attempt_stop'
    patrol.stageStartedAt = GetGameTimer()

    SetVehicleSiren(patrol.veh, true)
    TaskVehicleEscort(patrol.ped, patrol.veh, GetVehiclePedIsIn(playerPed, false), -1, 20.0, 786603, 10.0, 8.0, 0)
    PlayDispatchChatter('attempt_stop', patrol)
end

local function StartCompliancePhase(patrol, playerCoords)
    patrol.stage = 'holding'
    patrol.stageStartedAt = GetGameTimer()
    patrol.lastKnownCoords = playerCoords

    SendPatrolToSearch(patrol, playerCoords, patrol.model)
    PlayDispatchChatter('compliant', patrol)
end

function SpawnPoliceUnit(modelName, vehicleName, coords)
    if not coords then return end

    local requestedVehicle = ResolveModel(vehicleName)
    local requestedPed = ResolveModel(modelName)
    local vModel = GetFallbackVehicleModel(vehicleName)
    local pModel = GetFallbackPedModel(modelName)

    if Config and Config.ForceSafeUnitModels then
        print('^2[jh-dispatch] Safe emergency spawn mode active.^7')
    elseif requestedVehicle ~= vModel then
        print(('^3[jh-dispatch] Fallback vehicle used for %s^7'):format(tostring(vehicleName)))
    end

    if (not Config or not Config.ForceSafeUnitModels) and requestedPed ~= pModel then
        print(('^3[jh-dispatch] Fallback ped used for %s^7'):format(tostring(modelName)))
    end

    -- 1. Force Load Models
    local safeCopModel = GetHashKey('s_m_y_cop_01')
    RequestModel(vModel)
    RequestModel(pModel)
    RequestModel(safeCopModel)
    local timeout = 0
    while not HasModelLoaded(vModel) or not HasModelLoaded(pModel) or not HasModelLoaded(safeCopModel) do
        Wait(10)
        timeout = timeout + 1
        if timeout > 500 then
            print('^1[jh-dispatch] FAILED TO LOAD MODELS^7')
            return
        end
    end

    -- 2. Create Vehicle & Ensure Physics
    local veh = CreateVehicle(vModel, coords.x, coords.y, coords.z, coords.w or 0.0, true, false)
    if not DoesEntityExist(veh) then
        print('^1[jh-dispatch] ERROR: Vehicle failed to spawn!^7')
        return
    end

    SetVehicleHasBeenOwnedByPlayer(veh, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetEntityInvincible(veh, false)
    SetVehicleEngineOn(veh, true, true, false)
    FreezeEntityPosition(veh, false)

    -- 3. Create Driver with a guaranteed visible fallback
    print("Current Ped Count in Pool: " .. #GetGamePool('CPed'))
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    local driverPos = GetOffsetFromEntityInWorldCoords(veh, -2.0, 0.0, 0.5)
    local ped = CreatePed(6, pModel, driverPos.x, driverPos.y, driverPos.z, coords.w or 0.0, true, true)

    if not DoesEntityExist(ped) and pModel ~= safeCopModel then
        print(('^3[jh-dispatch] Retrying spawn with safe cop model for %s^7'):format(tostring(modelName)))
        ped = CreatePed(6, safeCopModel, driverPos.x, driverPos.y, driverPos.z, coords.w or 0.0, true, true)
        pModel = safeCopModel
        Wait(100)
    end

    if DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        SetEntityCollision(ped, true, true)
        SetEntityInvincible(ped, false)
        SetPedDefaultComponentVariation(ped)
        SetPedAsCop(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedKeepTask(ped, true)
        SetPedRelationshipGroupHash(ped, GetHashKey('COP'))
        SetPedCombatAttributes(ped, 46, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCanRagdoll(ped, false)

        if IsThisModelABike(vModel) then
            SetPedCanBeKnockedOffVehicle(ped, 1)
        end

        SetPedIntoVehicle(ped, veh, -1)
        Wait(100)

        if GetPedInVehicleSeat(veh, -1) ~= ped then
            TaskWarpPedIntoVehicle(ped, veh, -1)
            Wait(150)
        end
    end

    if (not DoesEntityExist(ped)) or GetPedInVehicleSeat(veh, -1) == 0 then
        local backupPed = CreateRandomPedAsDriver(veh, true)
        if DoesEntityExist(backupPed) then
            ped = backupPed
            SetEntityVisible(ped, true, false)
            ResetEntityAlpha(ped)
            SetEntityCollision(ped, true, true)
        end
    end

    if DoesEntityExist(ped) then
        print(('[jh-dispatch] Police ped spawned: %s seat:%s'):format(tostring(ped), tostring(GetPedInVehicleSeat(veh, -1))))

        -- Start in search mode and escalate to pursuit only after identification
        SetVehicleSiren(veh, false)
        SetVehicleHasMutedSirens(veh, false)
    else
        print(('^1[jh-dispatch] ERROR: Ped failed to spawn for model %s in vehicle %s^7'):format(tostring(modelName), tostring(vehicleName)))
    end

    SetModelAsNoLongerNeeded(vModel)
    SetModelAsNoLongerNeeded(pModel)

    return ped, veh
end

-- Listen for high heat in global state
AddStateBagChangeHandler('zoneHeat', 'global', function(_bagName, _key, value, _unused, _replicated)
    if type(value) ~= 'table' then return end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local zoneName = GetCurrentTerritory(playerCoords)
    local currentHeat = value[zoneName] or 0
    if currentHeat < 50 then return end

    -- Trigger patrol if zone heat is high
    TriggerServerEvent('jh-streetstalk-dispatch:server:requestPatrol', zoneName, playerCoords)
end)

RegisterNetEvent('jh-streetstalk-dispatch:client:spawnAI', function(data)
    print(('[jh-dispatch] spawnAI received for district %s'):format(data.district or data.name or 'unknown'))

    local pedModel = data.ped or data.model
    local ped, veh = SpawnPoliceUnit(pedModel, data.vehicle, data.spawn)
    if not ped or not veh then return end

    -- Give AI the PIT and Aggressive Chase attributes
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 1.0)

    if data.target then
        SendPatrolToSearch({ ped = ped, veh = veh }, data.target, data.vehicle)
    end

    table.insert(activePatrols, {
        ped = ped,
        veh = veh,
        district = data.district or data.name,
        model = data.vehicle,
        isChasing = false,
        stage = 'search',
        lastKnownCoords = data.target,
        lastSeenAt = GetGameTimer(),
        stageStartedAt = GetGameTimer()
    })
end)

CreateThread(function()
    while true do
        Wait(1000)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local currentTerritory = GetCurrentTerritory(playerCoords)
        local zoneHeat = GlobalState.zoneHeat or {}
        local currentHeat = zoneHeat[currentTerritory] or 0

        for i, patrol in ipairs(activePatrols) do
            if DoesEntityExist(patrol.veh) and DoesEntityExist(patrol.ped) then
                local dist = #(playerCoords - GetEntityCoords(patrol.veh))

                if currentHeat >= (Config.HeatLevelPatrol or 40) and dist < 120.0 then
                    patrol.lastKnownCoords = playerCoords
                end

                if patrol.isChasing then
                    if HasEntityClearLosToEntity(patrol.ped, playerPed, 17) then
                        patrol.lastSeenAt = GetGameTimer()
                    elseif patrol.lastKnownCoords and (GetGameTimer() - (patrol.lastSeenAt or 0)) > (Config.ForgetTargetTime or 12000) then
                        patrol.isChasing = false
                        patrol.stage = 'search'
                        SendPatrolToSearch(patrol, patrol.lastKnownCoords, patrol.model)
                        PlayDispatchChatter('search', patrol)
                    end
                elseif currentHeat >= (Config.HeatLevelPatrol or 40) then
                    local now = GetGameTimer()
                    local playerSpeed = GetEntitySpeed(playerPed)

                    if CanPatrolIdentifyPlayer(patrol, playerPed, playerCoords, currentHeat) then
                        patrol.lastKnownCoords = playerCoords
                        patrol.lastSeenAt = now

                        if patrol.stage == 'search' then
                            StartWarningPhase(patrol, playerCoords)
                        elseif patrol.stage == 'warning' then
                            SendPatrolToSearch(patrol, playerCoords, patrol.model)
                            if (now - (patrol.stageStartedAt or now)) > (Config.WarningDuration or 5000) then
                                StartStopPhase(patrol, playerPed)
                            end
                        elseif patrol.stage == 'attempt_stop' then
                            if playerSpeed <= (Config.ComplianceSpeed or 8.0) then
                                StartCompliancePhase(patrol, playerCoords)
                            elseif (now - (patrol.stageStartedAt or now)) > (Config.StopDuration or 7000) then
                                patrol.isChasing = true
                                patrol.stage = 'chase'
                                StartActiveChase(patrol)
                            end
                        elseif patrol.stage == 'holding' and playerSpeed > ((Config.ComplianceSpeed or 8.0) * 1.5) then
                            StartStopPhase(patrol, playerPed)
                        end
                    elseif patrol.lastKnownCoords then
                        patrol.stage = patrol.stage == 'chase' and 'chase' or 'search'
                        SendPatrolToSearch(patrol, patrol.lastKnownCoords, patrol.model)
                    end
                end
            else
                table.remove(activePatrols, i)
            end
        end
    end
end)

function StartActiveChase(patrol)
    if not patrol or not DoesEntityExist(patrol.ped) or not DoesEntityExist(patrol.veh) then return end
    SetVehicleSiren(patrol.veh, true)
    TaskVehicleMission(patrol.ped, patrol.veh, PlayerPedId(), 6, 100.0, 786463, 5.0, 10.0, true)
    PlayDispatchChatter('chase', patrol)
end

CreateThread(function()
    while true do
        Wait(0)
        -- Allow the game to spawn ambient police peds/cars
        SetPedDensityMultiplierThisFrame(1.0)
        SetVehicleDensityMultiplierThisFrame(1.0)

        -- Specifically allow police scenarios (cops standing at stations, etc.)
        SetScenarioPedDensityMultiplierThisFrame(1.0, 1.0)
    end
end)