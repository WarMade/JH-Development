local CurrentEvents = 0

-- [[ INITIALIZATION WITH FAIL-SAFE ]]
Citizen.CreateThread(function()
    -- Wait until Config is actually loaded into memory
    while Config == nil or Config.Relationships == nil do 
        Citizen.Wait(100) 
    end

    for _, data in ipairs(Config.Relationships) do
        SetRelationshipBetweenGroups(data[3], data[1], data[2])
        SetRelationshipBetweenGroups(data[3], data[2], data[1])
    end
    print("^2[LivelyWorld] Relationships Initialized.^7")
end)

-- [[ MAIN NPC INTELLIGENCE LOOP ]]
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local pCoords = GetEntityCoords(playerPed)
        local peds = GetGamePool('CPed')
        local sleep = 1500

        for i=1, #peds do
            local ped = peds[i]
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                if #(pCoords - GetEntityCoords(ped)) < 10.0 then
                    sleep = 500 
                    if not GetPedConfigFlag(ped, 140, true) then
                        SetPedConfigFlag(ped, 140, true) 
                        SetPedConfigFlag(ped, 281, true) 
                        SetBlockingOfNonTemporaryEvents(ped, false)
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- [[ SCENARIO HANDLER ]]
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.EventFrequency or 60000)
        if CurrentEvents < (Config.MaxConcurrentEvents or 3) then
            if math.random(1, 100) <= (Config.EventChance or 30) then
                TriggerScenario(GetEntityCoords(PlayerPedId()))
            end
        end
    end
end)

function TriggerScenario(coords)
    local scenarioId = math.random(1, 14)
    CurrentEvents = CurrentEvents + 1
    
    if scenarioId == 1 then SpawnMedicalScene(coords)
    elseif scenarioId == 2 then SpawnBrokenDownVehicle(coords)
    elseif scenarioId == 3 then SpawnPoliceChase(coords)
    elseif scenarioId == 4 then SpawnStreetRace(coords)
    elseif scenarioId == 5 then SpawnBankHeist(coords)
    elseif scenarioId == 6 then SpawnRoadWork(coords)
    elseif scenarioId == 7 then SpawnDrunkDriver(coords)
    elseif scenarioId == 8 then SpawnPublicArgument(coords)
    elseif scenarioId == 9 then SpawnFenderBender(coords)
    elseif scenarioId == 10 then SpawnMovingScene(coords)
    elseif scenarioId == 11 then SpawnDogWalker(coords)
    elseif scenarioId == 12 then SpawnAirPatrol(coords)
    elseif scenarioId == 13 then SpawnHighAltitudeFlight(coords)
    elseif scenarioId == 14 then SpawnWildlife(coords)
    else CurrentEvents = CurrentEvents - 1 end
end

-- [[ SCENARIO FUNCTIONS ]]

function SpawnPoliceChase(pos)
    local copVehHash = Config.PoliceCars[math.random(#Config.PoliceCars)]
    local suspectVehHash = `suburban`
    LoadModels({copVehHash, suspectVehHash, `s_m_y_cop_01`, `a_m_y_hippy_01`})
    local ret, spawnPos, heading = GetClosestVehicleNodeWithHeading(pos.x + 50, pos.y + 50, pos.z, 1, 3.0, 0)
    if ret then
        CreateEventBlip(spawnPos)
        local suspectVeh = CreateVehicle(suspectVehHash, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
        local suspect = CreatePedInsideVehicle(suspectVeh, 4, `a_m_y_hippy_01`, -1, true, false)
        local copVeh = CreateVehicle(copVehHash, spawnPos.x - 10.0, spawnPos.y - 10.0, spawnPos.z, heading, true, false)
        local cop = CreatePedInsideVehicle(copVeh, 4, `s_m_y_cop_01`, -1, true, false)
        SetVehicleSiren(copVeh, true)
        TaskVehicleMissionPedTarget(cop, copVeh, suspectVeh, 8, 40.0, 786603, 0.0, 0.0, true)
        TaskVehicleDriveWander(suspect, suspectVeh, 50.0, 786603)
        RegisterCleanup({suspectVeh, suspect, copVeh, cop})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnBankHeist(pos)
    local closestBank = nil
    for _, bankPos in ipairs(Config.Banks) do
        if #(pos - bankPos) < 150.0 then closestBank = bankPos break end
    end
    if closestBank then
        CreateEventBlip(closestBank)
        LoadModels({`mp_m_fibsec_01`, `police`, `s_m_y_cop_01`, `suburban`})
        local robberVeh = CreateVehicle(`suburban`, closestBank.x, closestBank.y, closestBank.z, 0.0, true, false)
        local robber = CreatePedInsideVehicle(robberVeh, 4, `mp_m_fibsec_01`, -1, true, false)
        local copVeh = CreateVehicle(`police`, closestBank.x - 10, closestBank.y - 10, closestBank.z, 0.0, true, false)
        local cop = CreatePedInsideVehicle(copVeh, 4, `s_m_y_cop_01`, -1, true, false)
        SetVehicleSiren(copVeh, true)
        TaskVehicleMissionPedTarget(cop, copVeh, robberVeh, 8, 40.0, 786603, 0.0, 0.0, true)
        TaskVehicleDriveWander(robber, robberVeh, 50.0, 786603)
        RegisterCleanup({robberVeh, robber, copVeh, cop})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnMedicalScene(pos)
    local medicModel, victimModel, ambModel = `s_m_m_doctor_01`, `a_m_m_prolhost_01`, `ambulance`
    LoadModels({medicModel, victimModel, ambModel})
    local success, spawnPos = GetSafeCoordForPed(pos.x + 30, pos.y + 30, pos.z, true, 1)
    if success then
        CreateEventBlip(spawnPos)
        local amb = CreateVehicle(ambModel, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
        local victim = CreatePed(4, victimModel, spawnPos.x + 2.0, spawnPos.y + 2.0, spawnPos.z, 0.0, true, false)
        local medic = CreatePed(4, medicModel, spawnPos.x + 1.0, spawnPos.y + 1.0, spawnPos.z, 0.0, true, false)
        SetVehicleSiren(amb, true)
        SetEntityHealth(victim, 0)
        SetPedToRagdoll(victim, 1000, 1000, 0, false, false, false)
        TaskGoToEntity(medic, victim, -1, 1.0, 1.0, 1073741824, 0)
        Citizen.SetTimeout(5000, function() if DoesEntityExist(medic) then TaskStartScenarioInPlace(medic, "CODE_HUMAN_MEDIC_TEND_TO_VICTIM", 0, true) end end)
        RegisterCleanup({amb, victim, medic})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnBrokenDownVehicle(pos)
    local vHash = `regina`
    LoadModels({vHash, `a_m_y_beach_01`})
    local ret, outPos, outHeading = GetClosestVehicleNodeWithHeading(pos.x + 40, pos.y + 40, pos.z, 1, 3.0, 0)
    if ret then
        CreateEventBlip(outPos)
        local veh = CreateVehicle(vHash, outPos.x, outPos.y, outPos.z, outHeading, true, false)
        SetVehicleDoorOpen(veh, 4, false, false)
        local driver = CreatePed(4, `a_m_y_beach_01`, outPos.x + 2.0, outPos.y, outPos.z, 0.0, true, false)
        TaskStartScenarioInPlace(driver, "WORLD_HUMAN_STAND_MOBILE", 0, true)
        RegisterCleanup({veh, driver})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnStreetRace(pos)
    local carModel = Config.RaceCars[math.random(#Config.RaceCars)]
    LoadModels({carModel, `a_m_y_beach_01`})
    local ret, s1, h1 = GetClosestVehicleNodeWithHeading(pos.x + 40, pos.y + 40, pos.z, 1, 3.0, 0)
    if ret then
        CreateEventBlip(s1)
        local v1 = CreateVehicle(carModel, s1.x, s1.y, s1.z, h1, true, false)
        local d1 = CreatePedInsideVehicle(v1, 4, `a_m_y_beach_01`, -1, true, false)
        TaskVehicleDriveWander(d1, v1, 70.0, 786603)
        RegisterCleanup({v1, d1})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnRoadWork(pos)
    local vehHash = Config.WorkVehicles[math.random(#Config.WorkVehicles)]
    LoadModels({vehHash, `s_m_m_construct_01`, `prop_mp_cone_01`})
    
    local ret, outPos, outHeading = GetClosestVehicleNodeWithHeading(pos.x + 45, pos.y + 45, pos.z, 1, 3.0, 0)
    if ret then
        CreateEventBlip(outPos)
        local truck = CreateVehicle(vehHash, outPos.x, outPos.y, outPos.z, outHeading, true, false)
        SetVehicleIndicatorLights(truck, 0, true)
        SetVehicleIndicatorLights(truck, 1, true)

        local cone = CreateObject(`prop_mp_cone_01`, outPos.x + 2, outPos.y + 2, outPos.z - 1.0, true, true, false)
        
        local worker = CreatePed(4, `s_m_m_construct_01`, outPos.x + 3.0, outPos.y, outPos.z, outHeading, true, false)
        TaskStartScenarioInPlace(worker, "WORLD_HUMAN_HAMMERING", 0, true)
        
        RegisterCleanup({truck, worker, cone})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnDrunkDriver(pos)
    local vHash = Config.DrunkCars[math.random(#Config.DrunkCars)]
    LoadModels({vHash, `a_m_m_paparazzi_01`})

    local ret, outPos, outHeading = GetClosestVehicleNodeWithHeading(pos.x + 60, pos.y + 60, pos.z, 1, 3.0, 0)
    if ret then
        CreateEventBlip(outPos)
        local veh = CreateVehicle(vHash, outPos.x, outPos.y, outPos.z, outHeading, true, false)
        local driver = CreatePedInsideVehicle(veh, 4, `a_m_m_paparazzi_01`, -1, true, false)
        
        TaskVehicleDriveWander(driver, veh, 25.0, 1074528293)
        SetVehicleDamage(veh, 0.0, 0.0, 0.3, 500.0, 200.0, true)
        
        Citizen.CreateThread(function()
            for i=1, 5 do
                if DoesEntityExist(veh) then SoundVehicleHornThisFrame(veh) end
                Citizen.Wait(math.random(1000, 3000))
            end
        end)
        
        RegisterCleanup({veh, driver})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnPublicArgument(pos)
    local m1, m2 = `a_m_m_acult_01`, `a_m_y_smartcas_01`
    LoadModels({m1, m2})
    
    local success, sPos = GetSafeCoordForPed(pos.x + 20, pos.y + 20, pos.z, true, 1)
    if success then
        CreateEventBlip(sPos)
        local ped1 = CreatePed(4, m1, sPos.x, sPos.y, sPos.z, 0.0, true, false)
        local ped2 = CreatePed(4, m2, sPos.x + 1.2, sPos.y + 1.2, sPos.z, 0.0, true, false)
        
        TaskTurnPedToFaceEntity(ped1, ped2, -1)
        TaskTurnPedToFaceEntity(ped2, ped1, -1)
        
        PlayAmbientSpeech1(ped1, "GENERIC_CURSE_HIGH", "SPEECH_PARAMS_FORCE_NORMAL")
        TaskStartScenarioInPlace(ped2, "WORLD_HUMAN_YOGA", 0, true)
        
        Citizen.SetTimeout(10000, function()
            if DoesEntityExist(ped1) then TaskCombatPed(ped1, ped2, 0, 16) end
        end)

        RegisterCleanup({ped1, ped2})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnFenderBender(pos)
    local v1, v2 = `regina`, `stanier`
    LoadModels({v1, v2, `s_m_m_ups_01`, `a_m_y_vinewood_01`})
    
    local ret, outPos, outHeading = GetClosestVehicleNodeWithHeading(pos.x + 35, pos.y + 35, pos.z, 1, 3.0, 0)
    if ret then
        CreateEventBlip(outPos)
        local veh1 = CreateVehicle(v1, outPos.x, outPos.y, outPos.z, outHeading, true, false)
        local veh2 = CreateVehicle(v2, outPos.x + 4.5, outPos.y + 1.0, outPos.z, outHeading - 15.0, true, false)
        
        SetVehicleDamage(veh1, 0.0, 0.7, 0.1, 1000.0, 500.0, true)
        SetVehicleDoorBroken(veh2, 0, true)

        local d1 = CreatePed(4, `s_m_m_ups_01`, outPos.x + 2.0, outPos.y + 2.0, outPos.z, 0.0, true, false)
        local d2 = CreatePed(4, `a_m_y_vinewood_01`, outPos.x + 3.0, outPos.y + 3.0, outPos.z, 0.0, true, false)
        
        TaskTurnPedToFaceEntity(d1, d2, -1)
        TaskTurnPedToFaceEntity(d2, d1, -1)
        PlayAmbientSpeech1(d1, "GENERIC_CURSE_MED", "SPEECH_PARAMS_FORCE_NORMAL")
        
        RegisterCleanup({veh1, veh2, d1, d2})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnMovingScene(pos)
    local vanHash = Config.MovingVans[math.random(#Config.MovingVans)]
    LoadModels({vanHash, `s_m_m_cntrybar_01`, `prop_cardbox_01`})
    
    local success, sPos = GetSafeCoordForPed(pos.x + 25, pos.y + 25, pos.z, true, 1)
    if success then
        CreateEventBlip(sPos)
        local van = CreateVehicle(vanHash, sPos.x, sPos.y, sPos.z, math.random(0, 360) + 0.0, true, false)
        SetVehicleDoorOpen(van, 5, false, false)

        local mover = CreatePed(4, `s_m_m_cntrybar_01`, sPos.x - 3.0, sPos.y - 3.0, sPos.z, 0.0, true, false)
        TaskStartScenarioInPlace(mover, "WORLD_HUMAN_GARDENER_PLANT", 0, true)
        
        RegisterCleanup({van, mover})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnDogWalker(pos)
    local dogModel = math.random(1, 2) == 1 and `a_c_shepherd` or `a_c_rottweiler`
    LoadModels({`s_m_y_cop_01`, dogModel})
    
    local success, sPos = GetSafeCoordForPed(pos.x + 20, pos.y + 20, pos.z, true, 1)
    if success then
        CreateEventBlip(sPos)
        local walker = CreatePed(4, `s_m_y_cop_01`, sPos.x, sPos.y, sPos.z, 0.0, true, false)
        local dog = CreatePed(28, dogModel, sPos.x + 1.0, sPos.y + 1.0, sPos.z, 0.0, true, false)
        
        TaskFollowToOffsetOfEntity(dog, walker, 0.5, 0.5, 0.0, 1.0, -1, 1.0, true)
        TaskWanderStandard(walker, 10.0, 10)
        
        RegisterCleanup({walker, dog})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnDrugDeal(pos)
    LoadModels({`g_m_y_mexgoon_02`, `a_m_y_business_02`})

    local success, sPos = GetSafeCoordForPed(pos.x + 18, pos.y - 18, pos.z, true, 1)
    if success then
        CreateEventBlip(sPos)
        local dealer = CreatePed(4, `g_m_y_mexgoon_02`, sPos.x, sPos.y, sPos.z, 0.0, true, false)
        local buyer = CreatePed(4, `a_m_y_business_02`, sPos.x + 1.2, sPos.y + 0.8, sPos.z, 0.0, true, false)

        TaskTurnPedToFaceEntity(dealer, buyer, -1)
        TaskTurnPedToFaceEntity(buyer, dealer, -1)
        PlayAmbientSpeech1(dealer, "GENERIC_HI", "SPEECH_PARAMS_FORCE_NORMAL")

        Citizen.SetTimeout(4000, function()
            if DoesEntityExist(dealer) and DoesEntityExist(buyer) then
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local dealCoords = GetEntityCoords(dealer)

                if #(playerCoords - dealCoords) < 25.0 then
                    TaskSmartFleePed(dealer, playerPed, 120.0, -1, false, false)
                    TaskSmartFleePed(buyer, playerPed, 120.0, -1, false, false)
                else
                    TaskWanderStandard(dealer, 10.0, 10)
                    TaskWanderStandard(buyer, 10.0, 10)
                end
            end
        end)

        RegisterCleanup({dealer, buyer})
    else CurrentEvents = CurrentEvents - 1 end
end

function SpawnAirPatrol(pos)
    local model = Config.HeliModels[math.random(#Config.HeliModels)]
    LoadModels({model, `s_m_y_cop_01`})

    CreateEventBlip(vector3(pos.x, pos.y, pos.z + 150.0))
    local heli = CreateVehicle(model, pos.x, pos.y, pos.z + 150.0, 0.0, true, false)
    local pilot = CreatePedInsideVehicle(heli, 4, `s_m_y_cop_01`, -1, true, false)

    SetVehicleSiren(heli, true)
    SetVehicleSearchlight(heli, true, false)
    TaskVehicleChase(pilot, PlayerPedId())
    SetDriveTaskDrivingStyle(pilot, 786468)

    Citizen.SetTimeout(Config.DespawnTime, function()
        if DoesEntityExist(pilot) and DoesEntityExist(heli) then
            TaskVehicleDriveWander(pilot, heli, 50.0, 786468)
        end
        RegisterCleanup({heli, pilot})
    end)
end

function SpawnHighAltitudeFlight(pos)
    local model = Config.PlaneModels[math.random(#Config.PlaneModels)]
    LoadModels({model, `s_m_m_pilot_01`})

    CreateEventBlip(vector3(pos.x, pos.y, pos.z + 400.0))
    local plane = CreateVehicle(model, pos.x - 500.0, pos.y - 500.0, pos.z + 400.0, 45.0, true, false)
    local pilot = CreatePedInsideVehicle(plane, 4, `s_m_m_pilot_01`, -1, true, false)

    ControlLandingGear(plane, 3)
    SetPlaneMinHeightAboveTerrain(plane, 100)
    TaskVehicleDriveToCoord(pilot, plane, pos.x + 1000.0, pos.y + 1000.0, pos.z + 400.0, 60.0, 0, model, 786468, 10.0, 20.0)

    RegisterCleanup({plane, pilot})
end

function SpawnWildlife(pos)
    local model = Config.Animals[math.random(#Config.Animals)]
    LoadModels({model})

    local success, sPos = GetSafeCoordForPed(pos.x + 40, pos.y + 40, pos.z, true, 1)
    if success then
        CreateEventBlip(sPos)
        local group = {}
        for i = 1, math.random(2, 4) do
            local animal = CreatePed(28, model, sPos.x + i, sPos.y + i, sPos.z, 0.0, true, false)
            TaskWanderStandard(animal, 10.0, 10)
            table.insert(group, animal)
        end
        RegisterCleanup(group)
    else
        CurrentEvents = CurrentEvents - 1
    end
end

-- [[ UTILITIES ]]
function CreateEventBlip(pos)
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Ambient Event")
    EndTextCommandSetBlipName(blip)

    Citizen.SetTimeout(Config.DespawnTime, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)

    return blip
end

function LoadModels(models)
    for _, model in ipairs(models) do
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(0) end
    end
end

function RegisterCleanup(entities)
    Citizen.CreateThread(function()
        Citizen.Wait(Config.DespawnTime)
        for _, entity in ipairs(entities) do
            if DoesEntityExist(entity) then SetEntityAsNoLongerNeeded(entity) end
        end
        CurrentEvents = CurrentEvents - 1
    end)
end

-- Force Event for Testing
RegisterNetEvent('lively_world:forceEvent')
AddEventHandler('lively_world:forceEvent', function(type)
    local coords = GetEntityCoords(PlayerPedId())

    if type == "heist" then
        CurrentEvents = CurrentEvents + 1
        SpawnBankHeist(coords)
    elseif type == "race" then
        CurrentEvents = CurrentEvents + 1
        SpawnStreetRace(coords)
    elseif type == "medical" then
        CurrentEvents = CurrentEvents + 1
        SpawnMedicalScene(coords)
    elseif type == "police" then
        CurrentEvents = CurrentEvents + 1
        SpawnPoliceChase(coords)
    elseif type == "broken" then
        CurrentEvents = CurrentEvents + 1
        SpawnBrokenDownVehicle(coords)
    elseif type == "work" or type == "construction" then
        CurrentEvents = CurrentEvents + 1
        SpawnRoadWork(coords)
    elseif type == "drunk" then
        CurrentEvents = CurrentEvents + 1
        SpawnDrunkDriver(coords)
    elseif type == "argument" or type == "fight" then
        CurrentEvents = CurrentEvents + 1
        SpawnPublicArgument(coords)
    elseif type == "accident" then
        CurrentEvents = CurrentEvents + 1
        SpawnFenderBender(coords)
    elseif type == "moving" then
        CurrentEvents = CurrentEvents + 1
        SpawnMovingScene(coords)
    elseif type == "dog" then
        CurrentEvents = CurrentEvents + 1
        SpawnDogWalker(coords)
    elseif type == "drugdeal" then
        CurrentEvents = CurrentEvents + 1
        SpawnDrugDeal(coords)
    elseif type == "heli" then
        CurrentEvents = CurrentEvents + 1
        SpawnAirPatrol(coords)
    elseif type == "plane" then
        CurrentEvents = CurrentEvents + 1
        SpawnHighAltitudeFlight(coords)
    elseif type == "wildlife" then
        CurrentEvents = CurrentEvents + 1
        SpawnWildlife(coords)
    else
        TriggerScenario(coords)
    end
end)