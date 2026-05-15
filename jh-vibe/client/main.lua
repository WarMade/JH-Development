local QBCore = exports['qb-core']:GetCoreObject()
local workingPed = nil
local activeService = false
local motelBlips = {}

function ManageMotelBlips(state)
    if state then
        if #motelBlips > 0 then
            return
        end

        -- Create blips for all motel locations
        for _, v in pairs(Config.Motels or {}) do
            local blip = AddBlipForCoord(v.entry.x, v.entry.y, v.entry.z)
            SetBlipSprite(blip, Config.MotelBlip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.MotelBlip.scale)
            SetBlipColour(blip, Config.MotelBlip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.MotelBlip.label)
            EndTextCommandSetBlipName(blip)

            table.insert(motelBlips, blip)
        end
        QBCore.Functions.Notify("Motel locations marked on GPS", "primary")
    else
        -- Remove all blips
        for _, blip in pairs(motelBlips) do
            RemoveBlip(blip)
        end
        motelBlips = {}
    end
end

function EndInteraction()
    ManageMotelBlips(false) -- GPS CLEARED
    if workingPed and DoesEntityExist(workingPed) then
        SetEntityAsNoLongerNeeded(workingPed)
    end
    workingPed = nil
end

local function GetTargetModels()
    local models = {}

    for model, enabled in pairs(Config.Models or {}) do
        if enabled then
            models[#models + 1] = model
        end
    end

    return models
end

CreateThread(function()
    if GetResourceState('qb-target') ~= 'started' then
        return
    end

    exports['qb-target']:AddTargetModel(GetTargetModels(), {
        options = {
            {
                icon = "fas fa-walking",
                label = "Follow to Alley",
                canInteract = function(entity)
                    return not IsPedInAnyVehicle(PlayerPedId(), false) and not workingPed
                end,
                action = function(entity)
                    TaskFollowToOffsetOfEntity(entity, PlayerPedId(), 0.5, -0.5, 0.0, 1.0, -1, 1.0, true)
                    workingPed = entity
                    SetEntityAsMissionEntity(entity, true, true)
                    QBCore.Functions.Notify("She's following you.", "success")
                end,
            },
        },
        distance = 2.0
    })
end)

-- Weather & Nice Car Modifier for the Horn logic
function GetBeckonChance(veh)
    local chance = Config.BaseAcceptChance or 50

    if GetRainLevel() > 0.1 then
        chance = chance + 40 -- They want to get out of rain!
    end

    local vehClass = GetVehicleClass(veh)
    if vehClass == 7 or vehClass == 6 then
        chance = chance + (Config.NiceCarBonus or 25) -- Super/Sport bonus
    elseif vehClass == 11 or vehClass == 12 then
        chance = chance - (Config.CheapCarPenalty or 15) -- Utility/van penalty
    end

    return math.max(0, math.min(100, chance))
end

-- Horn Detection Loop
CreateThread(function()
    while true do
        local sleep = 500
        local playerPed = PlayerPedId()
        
        if IsPedInAnyVehicle(playerPed, false) and not workingPed then
            local veh = GetVehiclePedIsIn(playerPed, false)
            
            -- Check if player is blowing the horn
            if IsControlJustPressed(0, 86) then -- Horn Key (Default E/L3)
                local pos = GetEntityCoords(playerPed)
                local closestPed = QBCore.Functions.GetClosestPed(pos, {})
                local pedModel = GetEntityModel(closestPed)

                if closestPed ~= 0 and Config.InteractModels[pedModel] then
                    local dist = #(pos - GetEntityCoords(closestPed))
                    if dist < 10.0 then
                        AttemptBeckon(closestPed, veh)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function CheckForMotel()
    if not workingPed or not DoesEntityExist(workingPed) then
        return false
    end

    local pos = GetEntityCoords(PlayerPedId())
    for _, motel in pairs(Config.MotelLocations or {}) do
        if motel.coords and motel.interior and motel.interiorOffset and #(pos - motel.coords) < 5.0 then
            DoScreenFadeOut(500)
            while not IsScreenFadedOut() do
                Wait(50)
            end

            SetEntityCoords(PlayerPedId(), motel.interior.x, motel.interior.y, motel.interior.z, false, false, false, false)
            SetEntityCoords(workingPed, motel.interiorOffset.x, motel.interiorOffset.y, motel.interiorOffset.z, false, false, false, false)

            DoScreenFadeIn(500)
            QBCore.Functions.Notify("You made it to the motel.", "success")
            return true
        end
    end

    return false
end

CreateThread(function()
    while true do
        local sleep = 1000

        if workingPed and not activeService then
            local playerPed = PlayerPedId()
            local pos = GetEntityCoords(playerPed)

            for _, motel in pairs(Config.Motels or {}) do
                local dist = #(pos - motel.entry)
                if dist < 3.0 then
                    sleep = 0
                    DrawMarker(2, motel.entry.x, motel.entry.y, motel.entry.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 255, 255, 100, false, true, 2, false, "", "", false)

                    if IsControlJustPressed(0, 38) then
                        EnterMotelRoom(motel)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

function EnterMotelRoom(motel)
    local playerPed = PlayerPedId()
    local ped = workingPed

    if not ped or not DoesEntityExist(ped) or not motel or not motel.inside then
        return
    end

    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do
        Wait(50)
    end

    -- Teleport to Interior
    SetEntityCoords(playerPed, motel.inside.x, motel.inside.y, motel.inside.z, false, false, false, false)
    SetEntityHeading(playerPed, motel.inside.w)
    SetEntityCoords(ped, motel.inside.x + 1.0, motel.inside.y, motel.inside.z, false, false, false, false)

    Wait(500)
    DoScreenFadeIn(800)

    -- Open the "Premium" Interior Menu
    if GetResourceState('qb-menu') == 'started' then
        local menu = {
            { header = "Motel Service", isMenuHeader = true },
            { header = "Full Room Service ($200)", params = { event = "jh-vibe:client:StartInterior", args = motel } },
            { header = "Leave", params = { event = "jh-vibe:client:LeaveMotel", args = motel } }
        }
        exports['qb-menu']:openMenu(menu)
    end
end

function AttemptBeckon(ped, veh)
    if workingPed then return end
    local playerPed = PlayerPedId()
    
    -- 1. Walk to the vehicle
    TaskGoToEntity(ped, veh, -1, 1.0, 2.0, 1073741824, 0)
    QBCore.Functions.Notify("She's coming over to check you out...", "primary")
    
    local arrived = false
    local timeout = GetGameTimer() + 10000
    while not arrived and GetGameTimer() < timeout do
        Wait(500)
        if #(GetEntityCoords(ped) - GetEntityCoords(veh)) < 2.5 then
            arrived = true
        end
    end

    if not arrived then return end

    -- 2. Visual "Inspection" / Lean In
    TaskTurnPedToFaceEntity(ped, veh, 1000)
    Wait(1000)
    
    RequestAnimDict("amb@prop_human_bum_shopping_cart@male@idle_a")
    while not HasAnimDictLoaded("amb@prop_human_bum_shopping_cart@male@idle_a") do Wait(1) end
    TaskPlayAnim(ped, "amb@prop_human_bum_shopping_cart@male@idle_a", "idle_c", 8.0, -8.0, -1, 1, 0, false, false, false)
    
    PlayAmbientSpeech1(ped, "SEX_GENERIC_HI", "SPEECH_PARAMS_FORCE_NORMAL")
    Wait(3000)

    -- 3. Financial Check
    QBCore.Functions.TriggerCallback('jh-vibe:server:CheckPockets', function(hasMoney)
        StopAnimTask(ped, "amb@prop_human_bum_shopping_cart@male@idle_a", "idle_c", 1.0)
        
        if not hasMoney then
            -- BROKE RESPONSE
            PlayAmbientSpeech1(ped, "SEX_STREET_WALKER_REJECT", "SPEECH_PARAMS_FORCE_NORMAL")
            
            RequestAnimDict("anim@mp_player_intupperface_palm")
            while not HasAnimDictLoaded("anim@mp_player_intupperface_palm") do Wait(1) end
            TaskPlayAnim(ped, "anim@mp_player_intupperface_palm", "idle_a", 8.0, -8.0, 3000, 48, 0, false, false, false)
            
            QBCore.Functions.Notify("She laughs at your empty wallet.", "error")
            
            Wait(3000)
            TaskWanderStandard(ped, 10.0, 10)
            return
        end

        -- 4. If NOT broke, proceed to Car/Chance evaluation
        local chance = Config.BaseAcceptChance
        local vehClass = GetVehicleClass(veh)

        if vehClass == 7 or vehClass == 6 then
            chance = chance + Config.NiceCarBonus
        elseif vehClass == 20 or vehClass == 11 then
            chance = chance - Config.CheapCarPenalty
        end

        local roll = math.random(1, 100)
        if roll <= chance then
            -- SUCCESS LOGIC
            PlayAmbientSpeech1(ped, "SEX_STREET_WALKER_ACCEPT", "SPEECH_PARAMS_FORCE_NORMAL")
            QBCore.Functions.Notify("She likes the ride. She's in.", "success")
            
            RequestAnimDict("anim@mp_player_intupperthumbs_up")
            while not HasAnimDictLoaded("anim@mp_player_intupperthumbs_up") do Wait(1) end
            TaskPlayAnim(ped, "anim@mp_player_intupperthumbs_up", "exit", 8.0, -8.0, 2000, 48, 0, false, false, false)
            
            Wait(2000)
            TaskEnterVehicle(ped, veh, -1, 0, 1.0, 1, 0)
            workingPed = ped
            SetEntityAsMissionEntity(ped, true, true)
            ManageMotelBlips(true)
        else
            -- REJECTION LOGIC
            PlayAmbientSpeech1(ped, "SEX_STREET_WALKER_REJECT", "SPEECH_PARAMS_FORCE_NORMAL")
            
            RequestAnimDict("anim@mp_player_intupperfinger")
            while not HasAnimDictLoaded("anim@mp_player_intupperfinger") do Wait(1) end
            TaskPlayAnim(ped, "anim@mp_player_intupperfinger", "idle_a", 8.0, -8.0, 3000, 48, 0, false, false, false)
            
            QBCore.Functions.Notify("You're not her type.", "error")
            Wait(3000)
            TaskWanderStandard(ped, 10.0, 10)
        end
    end)
end

RegisterNetEvent('jh-vibe:client:Start', function(type)
    local service = Config.Services[type]
    local playerPed = PlayerPedId()

    if service.protection and Config.RequireProtection then
        local hasItem = QBCore.Functions.HasItem(Config.ProtectionItem or 'condom')
        if not hasItem then
            QBCore.Functions.Notify("She's not doing that without protection.", "error")
            return
        end
    end

    QBCore.Functions.TriggerCallback('jh-vibe:server:CanPay', function(canPay)
        if canPay then
            activeService = true
            StartVibeSequence(service, GetVehiclePedIsIn(playerPed, false))
        end
    end, service.price)
end)

function StartVibeSequence(service, veh)
    local playerPed = PlayerPedId()
    local ped = workingPed

    if not ped or not DoesEntityExist(ped) or veh == 0 then
        activeService = false
        workingPed = nil
        return
    end

    -- ROLL THE DICE: Is this a robbery?
    local robChance = Config.RobberyChance or 15
    if GetVehicleClass(veh) == Config.AntiRobClass then
        robChance = math.max(0, robChance - 15) -- Too scary/fast to rob
    end
    if IsPedArmed(playerPed, 7) then
        robChance = math.max(0, robChance - 15) -- Weapon out makes her think twice
    end

    local dice = math.random(1, 100)
    if dice <= robChance then
        InitiateRobbery(ped, veh)
        return
    end

    local endTime = GetGameTimer() + service.duration

    -- Cinematic Cam & Anim Logic (Keep from previous version)
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    local offset = GetOffsetFromEntityInWorldCoords(veh, 1.5, 2.0, 1.0)
    SetCamCoord(cam, offset.x, offset.y, offset.z)
    PointCamAtEntity(cam, veh, 0, 0, 0, true)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 2000, true, true)

    RequestAnimDict(service.animDict)
    while not HasAnimDictLoaded(service.animDict) do
        Wait(1)
    end

    TaskPlayAnim(playerPed, service.animDict, service.animPlayer, 8.0, -8.0, -1, 1, 0, false, false, false)
    TaskPlayAnim(ped, service.animDict, service.animPed, 8.0, -8.0, -1, 1, 0, false, false, false)

    -- SUGGESTION 1: POLICE HEAT LOOP
    CreateThread(function()
        while activeService and GetGameTimer() < endTime do
            Wait(2000)
            local pos = GetEntityCoords(veh)
            local players = GetActivePlayers()
            
            for _, player in ipairs(players) do
                local otherPed = GetPlayerPed(player)
                if #(pos - GetEntityCoords(otherPed)) < 25.0 then
                    TriggerServerEvent('jh-vibe:server:CheckForCops', pos)
                end
            end
            
            ApplyForceToEntity(veh, 1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
        end
    end)

    Wait(service.duration)

    RenderScriptCams(false, true, 2000, true, true)
    DestroyCam(cam, false)
    ClearPedTasks(playerPed)
    ClearPedTasks(ped)
    SetEntityHealth(playerPed, GetEntityHealth(playerPed) + (service.health or 0))
    TaskLeaveVehicle(ped, veh, 0)
    EndInteraction()
    activeService = false
end

function InitiateRobbery(ped, veh)
    activeService = false
    EndInteraction()

    TaskLeaveVehicle(ped, veh, 16)
    Wait(1000)

    local weapon = Config.RobberyWeapons[math.random(1, #Config.RobberyWeapons)]
    GiveWeaponToPed(ped, weapon, 1, false, true)
    SetCurrentPedWeapon(ped, weapon, true)

    TaskAimGunAtEntity(ped, PlayerPedId(), 10000, false)
    PlayAmbientSpeech1(ped, "GENERIC_HI_JACK_VEHICLE", "SPEECH_PARAMS_FORCE_NORMAL")
    QBCore.Functions.Notify("SHE'S GOT A GUN! SHE'S ROBBING YOU!", "error")

    TriggerServerEvent('jh-vibe:server:RobPlayer')

    SetTimeout(5000, function()
        TaskSmartFleePed(ped, PlayerPedId(), 500.0, -1, true, true)
        SetEntityAsNoLongerNeeded(ped)
    end)
end

RegisterNetEvent('jh-vibe:client:StartInterior', function(motel)
    local service = Config.InteriorServices['bed_sex']
    local playerPed = PlayerPedId()
    local ped = workingPed

    if not service or not motel or not motel.bed or not ped or not DoesEntityExist(ped) then
        return
    end

    QBCore.Functions.TriggerCallback('jh-vibe:server:CanPay', function(canPay)
        if canPay then
            activeService = true

            -- Setup Cinematic Cam (Interior)
            local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
            SetCamCoord(cam, motel.bed.x, motel.bed.y - 2.0, motel.bed.z + 1.0)
            PointCamAtCoord(cam, motel.bed.x, motel.bed.y, motel.bed.z)
            SetCamActive(cam, true)
            RenderScriptCams(true, true, 2000, true, true)

            -- Play Bed Anims
            RequestAnimDict(service.animDict)
            while not HasAnimDictLoaded(service.animDict) do Wait(1) end

            -- Position them on the bed
            SetEntityCoords(playerPed, motel.bed.x, motel.bed.y, motel.bed.z, false, false, false, false)
            SetEntityCoords(ped, motel.bed.x, motel.bed.y, motel.bed.z, false, false, false, false)

            TaskPlayAnim(playerPed, service.animDict, service.animPlayer, 8.0, -8.0, -1, 1, 0, false, false, false)
            TaskPlayAnim(ped, service.animDict, service.animPed, 8.0, -8.0, -1, 1, 0, false, false, false)

            Wait(service.duration)

            -- Completion Cleanup
            RenderScriptCams(false, true, 2000, true, true)
            DestroyCam(cam, false)
            ClearPedTasks(playerPed)
            ClearPedTasks(ped)
            activeService = false

            QBCore.Functions.Notify("A premium experience.", "success")
            TriggerEvent('jh-vibe:client:LeaveMotel', motel)
        end
    end, service.price)
end)

RegisterNetEvent('jh-vibe:client:LeaveMotel', function(motel)
    if not motel or not motel.entry then
        return
    end

    DoScreenFadeOut(800)
    Wait(1000)
    SetEntityCoords(PlayerPedId(), motel.entry.x, motel.entry.y, motel.entry.z, false, false, false, false)
    if workingPed and DoesEntityExist(workingPed) then
        SetEntityCoords(workingPed, motel.entry.x + 1.0, motel.entry.y, motel.entry.z, false, false, false, false)
        TaskWanderStandard(workingPed, 10.0, 10)
    end
    EndInteraction()
    DoScreenFadeIn(800)
end)

RegisterNetEvent('jh-vibe:client:PoliceAbort', function()
    if activeService and workingPed and DoesEntityExist(workingPed) then
        activeService = false
        RenderScriptCams(false, true, 1000, true, true)
        ClearPedTasks(workingPed)
        PlayAmbientSpeech1(workingPed, "GENERIC_FRIGHTENED_HIGH", "SPEECH_PARAMS_FORCE_NORMAL")
        TaskLeaveVehicle(workingPed, GetVehiclePedIsIn(PlayerPedId(), false), 4096)
        QBCore.Functions.Notify("COPS! SHE'S BOLTING!", "error")
        EndInteraction()
    end
end)