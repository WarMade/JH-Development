local QBCore = exports['qb-core']:GetCoreObject()
local isBusy = false
local spawnedProp = nil
local scavengerPed = nil
local scavengerBlip = nil
local hasSilasContact = false
local currentXP = 0
local currentLevel = 1
local smellLevel = 0
local isSmelly = false
local flyEffect = nil
local currentScavengerLoc = nil
local SpawnScavenger

local function SetSmellyState(state)
    isSmelly = state and true or false
    LocalPlayer.state:set("isSmelly", isSmelly, true)
end

local function PlayTrashSound(entity)
    PlaySoundFromEntity(-1, "collect_box_check", entity, "DLC_BATTLE_SOUNDS", false, 0)
end

local function AttachProp()
    local ped = PlayerPedId()
    local propData = Config.Props[1]
    RequestModel(propData.model)
    while not HasModelLoaded(propData.model) do Wait(10) end
    spawnedProp = CreateObject(propData.model, 0, 0, 0, true, true, true)
    AttachEntityToEntity(spawnedProp, ped, GetPedBoneIndex(ped, propData.bone), propData.pos.x, propData.pos.y, propData.pos.z, propData.rot.x, propData.rot.y, propData.rot.z, true, true, false, true, 1, true)
end

local function RemoveProp()
    if spawnedProp then DeleteEntity(spawnedProp) spawnedProp = nil end
end

local function PlayBulletproofAnim(ped, animData)
    ClearPedTasksImmediately(ped)
    RequestAnimDict(animData.dict)

    local timeout = 0
    while not HasAnimDictLoaded(animData.dict) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
        RequestAnimDict(animData.dict)
    end

    if not HasAnimDictLoaded(animData.dict) then
        print("^1[Error]^7 Animation dictionary " .. animData.dict .. " failed to load.")
        return false
    end

    TaskPlayAnim(ped, animData.dict, animData.anim, 8.0, 8.0, -1, 49, 0, false, false, false)
    RemoveAnimDict(animData.dict)
    return true
end

local function RefreshScavengingLevel()
    local maxLevel = (Config.Experience and Config.Experience.MaxLevel) or 10
    local derivedLevel = math.floor(currentXP / 100) + 1
    currentLevel = math.min(maxLevel, math.max(1, math.max(currentLevel or 1, derivedLevel)))
end

local function LoadScavengingProgress()
    if not Config.Experience or not Config.Experience.Enabled then return end

    QBCore.Functions.TriggerCallback('jh-dumpster:server:getXP', function(savedData)
        if type(savedData) == 'table' then
            currentXP = tonumber(savedData.xp) or 0
            currentLevel = tonumber(savedData.level) or 1
        else
            currentXP = tonumber(savedData) or 0
            currentLevel = 1
        end

        RefreshScavengingLevel()
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetSmellyState(false)
    LoadScavengingProgress()

    CreateThread(function()
        Wait(1500)
        if SpawnScavenger then
            SpawnScavenger()
        end
    end)
end)

CreateThread(function()
    Wait(2000)
    SetSmellyState(false)
    LoadScavengingProgress()
end)

local function GetReactionProfile(playerCoords)
    local profile = {
        Chance = Config.Reactions.Chance or 30,
        AggroChance = Config.Reactions.AggroChance or 10,
        Radius = Config.Reactions.Radius or 15.0,
        Voices = Config.Reactions.Voices or {},
        Notify = "The local is getting aggressive!",
        Weapons = {"WEAPON_UNARMED"},
        Type = "default"
    }

    for _, area in ipairs(Config.Reactions.Areas or {}) do
        if area.Coords and #(playerCoords - area.Coords) <= (area.Radius or profile.Radius) then
            profile.Chance = area.Chance or profile.Chance
            profile.AggroChance = area.AggroChance or profile.AggroChance
            profile.Radius = area.Radius or profile.Radius
            profile.Voices = area.Voices or profile.Voices
            profile.Notify = area.Notify or profile.Notify
            profile.Weapons = area.Weapons or profile.Weapons
            profile.Type = area.Type or profile.Type
            break
        end
    end

    return profile
end

local function IsPolicePed(ped)
    return GetPedType(ped) == 6
end

local function CanPedReact(foundPed, playerPed, profile, dist)
    if foundPed == playerPed or foundPed == scavengerPed or IsPedAPlayer(foundPed) or not IsPedHuman(foundPed) or IsPedDeadOrDying(foundPed, true) or dist > profile.Radius then
        return false
    end

    if profile.Type == "police" then
        return IsPolicePed(foundPed)
    elseif profile.Type == "gang" then
        return not IsPolicePed(foundPed)
    end

    return true
end

local function GetAreaNameFromCoords(playerCoords)
    for areaName, data in pairs(Config.AreaLoot or {}) do
        if data.coords and data.radius and #(playerCoords - data.coords) < data.radius then
            return areaName
        end
    end

    return 'Default'
end

local function TriggerPoliceAlert(areaName)
    if not Config.Police or not Config.Police.Enabled then return end

    local chance = (Config.Police.AreaChance and Config.Police.AreaChance[areaName]) or (Config.Police.AreaChance and Config.Police.AreaChance['Default']) or 0.0
    if math.random() <= chance then
        if Config.Police.AlertScript == "ps-dispatch" and GetResourceState('ps-dispatch') == 'started' then
            exports['ps-dispatch']:SuspiciousActivity()
        elseif Config.Police.AlertScript == "qb-default" then
            TriggerServerEvent('police:server:policeAlert', 'Suspicious person rummaging through bins')
        end
    end
end

local function TriggerNPCReaction(playerPed)
    if not Config.Reactions or not Config.Reactions.Enabled then return end

    local pos = GetEntityCoords(playerPed)
    local profile = GetReactionProfile(pos)
    local handle, ped = FindFirstPed()
    local success
    local foundPed = nil
    local closestDist = profile.Radius + 0.01

    repeat
        if ped and ped ~= 0 then
            local pedPos = GetEntityCoords(ped)
            local dist = #(pos - pedPos)

            if CanPedReact(ped, playerPed, profile, dist) and dist < closestDist then
                closestDist = dist
                foundPed = ped
            end
        end

        success, ped = FindNextPed(handle)
    until not success

    EndFindPed(handle)

    if foundPed and math.random(1, 100) <= profile.Chance then
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.05)
        TaskTurnPedToFaceEntity(foundPed, playerPed, 2000)

        local speechList = profile.Voices or Config.Reactions.Voices
        if speechList and #speechList > 0 then
            local speech = speechList[math.random(1, #speechList)]
            PlayAmbientSpeech1(foundPed, speech, "SPEECH_PARAMS_FORCE_SHOUT")
        end

        if math.random(1, 100) <= profile.AggroChance then
            Wait(1500)

            local weaponHash = nil
            if profile.Type == "police" and profile.Weapons and #profile.Weapons > 0 then
                weaponHash = GetHashKey(profile.Weapons[math.random(1, #profile.Weapons)])
            elseif math.random(1, 2) == 1 then
                weaponHash = GetHashKey("WEAPON_KNIFE")
            end

            if weaponHash then
                GiveWeaponToPed(foundPed, weaponHash, 12, false, true)
                SetCurrentPedWeapon(foundPed, weaponHash, true)
            else
                SetCurrentPedWeapon(foundPed, GetHashKey("WEAPON_UNARMED"), true)
            end

            SetPedAsEnemy(foundPed, true)
            SetPedCombatAttributes(foundPed, 46, true)
            SetPedFleeAttributes(foundPed, 0, false)
            SetPedRelationshipGroupHash(foundPed, GetHashKey("HATES_PLAYER"))
            TaskCombatPed(foundPed, playerPed, 0, 16)
            QBCore.Functions.Notify(profile.Notify or "A local is defending their territory!", "error")
        end
    end
end

-- THE OVERRIDER (Fixed duplicates and added priority)
CreateThread(function()
    Wait(2000)
    local genericLabels = {"Search Dumpster", "Search", "Dive", "Dumpster Diving"}
    exports['qb-target']:RemoveTargetModel(Config.DumpsterModels, genericLabels)
    exports['qb-target']:AddTargetModel(Config.DumpsterModels, {
        options = {{
            num = 1,
            type = "client",
            event = "jh-dumpster:client:startSearch",
            icon = "fas fa-dumpster",
            label = "Search Dumpster (Pro)",
        }},
        distance = 1.5
    })
end)

local scavengerLocationIndex = nil

local function RemoveScavenger()
    if scavengerBlip and DoesBlipExist(scavengerBlip) then
        RemoveBlip(scavengerBlip)
        scavengerBlip = nil
    end

    if scavengerPed and DoesEntityExist(scavengerPed) then
        exports['qb-target']:RemoveTargetEntity(scavengerPed, {"Talk to Silas", "Sell Scavenged Goods", "Hand Over Money Bag"})
        DeleteEntity(scavengerPed)
        scavengerPed = nil
    end
end

local function GetNextScavengerLocation()
    local locations = Config.Scavenger.Locations
    if #locations == 1 then
        scavengerLocationIndex = 1
        return locations[1]
    end

    local newIndex
    repeat
        newIndex = math.random(1, #locations)
    until newIndex ~= scavengerLocationIndex

    scavengerLocationIndex = newIndex
    return locations[newIndex]
end

RegisterNetEvent('jh-dumpsterdiving:client:openSilasMenu', function()
    if GetResourceState('qb-menu') == 'started' then
        exports['qb-menu']:openMenu({
            {
                header = "Old Man Silas",
                isMenuHeader = true
            },
            {
                header = "Sell Scavenged Goods",
                txt = "Unload the valuables you found.",
                params = {
                    event = 'jh-dumpster:client:sellToScavenger'
                }
            },
            {
                header = "Hand Over Money Bag",
                txt = "Let Silas crack it open.",
                params = {
                    event = 'jh-dumpster:client:crackBag'
                }
            }
        })
    else
        TriggerEvent('jh-dumpster:client:sellToScavenger')
    end
end)

RegisterNetEvent('jh-dumpsterdiving:client:updateScavengerLoc', function(loc)
    currentScavengerLoc = loc
    RemoveScavenger()

    if SpawnScavenger and currentScavengerLoc then
        SpawnScavenger()
    end
end)

SpawnScavenger = function()
    if not Config.Scavenger or not currentScavengerLoc then
        return
    end

    RemoveScavenger()

    local loc = currentScavengerLoc
    local model = Config.Scavenger.Model

    scavengerBlip = AddBlipForCoord(loc.x, loc.y, loc.z)
    SetBlipSprite(scavengerBlip, Config.Scavenger.Blip.Sprite)
    SetBlipDisplay(scavengerBlip, 4)
    SetBlipScale(scavengerBlip, Config.Scavenger.Blip.Scale)
    SetBlipAsShortRange(scavengerBlip, false)
    SetBlipColour(scavengerBlip, Config.Scavenger.Blip.Color)
    SetBlipSecondaryColour(scavengerBlip, 255, 0, 0)
    SetBlipFlashes(scavengerBlip, true)
    SetBlipFlashInterval(scavengerBlip, 750)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Scavenger.Blip.Label)
    EndTextCommandSetBlipName(scavengerBlip)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    scavengerPed = CreatePed(0, model, loc.x, loc.y, loc.z - 1.0, loc.w, false, false)
    SetEntityAsMissionEntity(scavengerPed, true, true)
    SetEntityInvincible(scavengerPed, true)
    SetBlockingOfNonTemporaryEvents(scavengerPed, true)
    FreezeEntityPosition(scavengerPed, true)
    TaskStartScenarioInPlace(scavengerPed, "WORLD_HUMAN_SMOKING", 0, true)

    exports['qb-target']:AddTargetEntity(scavengerPed, {
        options = {
            {
                type = "client",
                event = "jh-dumpsterdiving:client:openSilasMenu",
                icon = "fas fa-hands-helping",
                label = "Talk to Silas",
                action = function()
                    if isSmelly then
                        QBCore.Functions.Notify("Silas: 'Smell that? That's the scent of hard work, kid.'", "primary")
                    end
                    TriggerEvent('jh-dumpsterdiving:client:openSilasMenu')
                end,
            },
        },
        distance = 2.0
    })

    SetModelAsNoLongerNeeded(model)
end


AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(1500)
        if SpawnScavenger then
            SpawnScavenger()
        end
    end)
end)

CreateThread(function()
    while true do
        local sleep = 1500
        if LocalPlayer.state.isDiving then
            sleep = 0
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 22, true)
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()

        if LocalPlayer.state.isDiving then
            smellLevel = smellLevel + 5
            if smellLevel > 100 then smellLevel = 100 end
        end

        if IsEntityInWater(ped) or IsPedSwimming(ped) then
            if smellLevel > 0 then
                smellLevel = smellLevel - 2
                if smellLevel < 0 then smellLevel = 0 end
                if smellLevel < 10 and isSmelly then SetSmellyState(false) end
            end
        end

        if smellLevel >= 50 and not isSmelly then
            SetSmellyState(true)
            QBCore.Functions.Notify("You're starting to smell pretty bad...", "error")
        end

        Wait(5000)
    end
end)

CreateThread(function()
    while true do
        local sleep = 2000
        if isSmelly then
            sleep = 5000
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local handle, npc = FindFirstPed()
            local success

            repeat
                if npc and npc ~= 0 then
                    local npcCoords = GetEntityCoords(npc)
                    if npc ~= ped and not IsPedAPlayer(npc) and IsPedHuman(npc) and not IsPedDeadOrDying(npc, true) and #(coords - npcCoords) < 3.0 then
                        TaskTurnPedToFaceEntity(npc, ped, 1000)
                        PlayAmbientSpeech1(npc, "GENERIC_CURSE_MED", "SPEECH_PARAMS_FORCE")
                        TaskSmartFleePed(npc, ped, 10.0, -1, false, false)
                        break
                    end
                end
                success, npc = FindNextPed(handle)
            until not success

            EndFindPed(handle)
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if smellLevel > 75 and not flyEffect then
            RequestNamedPtfxAsset("core")
            while not HasNamedPtfxAssetLoaded("core") do Wait(0) end
            UseParticleFxAssetNextCall("core")
            flyEffect = StartParticleFxLoopedOnEntity("ent_amb_fly_drift", PlayerPedId(), 0.0, 0.0, 0.8, 0.0, 0.0, 0.0, 1.2, false, false, false)
        elseif smellLevel <= 75 and flyEffect then
            StopParticleFxLooped(flyEffect, false)
            flyEffect = nil
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RemoveScavenger()
end)

RegisterNetEvent('jh-dumpster:client:startSearch', function(data)
    local ped = PlayerPedId()
    local entity = data and data.entity

    if LocalPlayer.state.isDiving or isBusy then return end
    if not entity or entity == 0 then return end
    if IsPedInAnyVehicle(ped, false) then return end

    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        Wait(100)
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)

    QBCore.Functions.TriggerCallback('jh-dumpster:server:checkDumpster', function(isAvailable)
        if not isAvailable then
            QBCore.Functions.Notify("There is nothing left in here.", "error")
            return
        end

        local skillWidth = 12
        local skillDuration = 3000

        if Config.Experience and Config.Experience.Enabled then
            skillWidth = math.floor(skillWidth + (currentLevel * (Config.Experience.SkillBonus or 1.5)))
        end

        local randomAnim = Config.Animations[math.random(1, #Config.Animations)]
        local entityCoords = GetEntityCoords(entity)
        TaskTurnPedToFaceCoord(ped, entityCoords.x, entityCoords.y, entityCoords.z, 500)
        Wait(500)

        if not PlayBulletproofAnim(ped, randomAnim) then
            QBCore.Functions.Notify("Something went wrong with your character's movement.", "error")
            return
        end

        LocalPlayer.state:set("isDiving", true, true)
        local areaName = GetAreaNameFromCoords(GetEntityCoords(ped))

        TriggerServerEvent('jh-dumpster:server:beginSearch', netId)
        isBusy = true

        if Config.Effects and Config.Effects.Enabled then
            RequestNamedPtfxAsset(Config.Effects.Dict)
            while not HasNamedPtfxAssetLoaded(Config.Effects.Dict) do Wait(0) end

            local fxCoords = GetEntityCoords(entity)
            UseParticleFxAssetNextCall(Config.Effects.Dict)
            local dust = StartParticleFxLoopedAtCoord(Config.Effects.Name, fxCoords.x, fxCoords.y, fxCoords.z, 0.0, 0.0, 0.0, Config.Effects.Scale, false, false, false, false)

            SetTimeout(Config.SearchTime, function()
                StopParticleFxLooped(dust, false)
            end)
        end

        TriggerPoliceAlert(areaName)
        TriggerNPCReaction(ped)
        PlayTrashSound(entity)

        exports[Config.Skillbar]:GetSkillbarObject().Start({
            duration = skillDuration,
            pos = 20,
            width = skillWidth
        }, function()
            AttachProp()
            QBCore.Functions.Progressbar("scavenge", "Diving...", Config.SearchTime, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true
            }, {}, {}, {}, function()
                isBusy = false
                RemoveProp()

                if Config.Experience and Config.Experience.Enabled then
                    local previousLevel = currentLevel
                    currentXP = currentXP + (Config.Experience.XPPerDive or 15)
                    RefreshScavengingLevel()

                    if currentLevel > previousLevel then
                        QBCore.Functions.Notify("Scavenging Level Up: " .. currentLevel, "success")
                    end
                end

                TriggerServerEvent('jh-dumpster:server:processProLoot', netId, GetEntityCoords(ped), currentLevel)
                LocalPlayer.state:set("isDiving", false, true)
                ClearPedTasks(ped)
            end, function()
                isBusy = false
                RemoveProp()
                LocalPlayer.state:set("isDiving", false, true)
                ClearPedTasks(ped)
            end)
        end, function()
            isBusy = false
            LocalPlayer.state:set("isDiving", false, true)
            ClearPedTasks(ped)
            QBCore.Functions.Notify("You messed up the search.", "error")
        end)
    end, netId)
end)

RegisterNetEvent('jh-dumpster:client:sellToScavenger', function()
    local items = {}

    for item, price in pairs(Config.Scavenger.BuyRates) do
        local hasItem = QBCore.Functions.HasItem(item)
        if hasItem then
            table.insert(items, { item = item, price = price })
        end
    end

    if #items == 0 then
        QBCore.Functions.Notify("Silas looks at you: 'You got nothin' I want, kid.'", "error")
        return
    end

    if not hasSilasContact then
        TriggerServerEvent('jh-dumpster:server:addSilasContact')
        hasSilasContact = true
    end

    TriggerServerEvent('jh-dumpster:server:sellScavenge', items)
end)

RegisterNetEvent('jh-dumpster:client:crackBag', function()
    local ped = PlayerPedId()

    if not QBCore.Functions.HasItem('moneybag') then
        QBCore.Functions.Notify("You don't have a money bag, kid.", "error")
        return
    end

    RequestAnimDict("mp_common")
    while not HasAnimDictLoaded("mp_common") do Wait(10) end
    TaskPlayAnim(ped, "mp_common", "givetake2_a", 8.0, 8.0, 2000, 0, 1, false, false, false)

    QBCore.Functions.Progressbar("cracking_bag", "Silas is checking the bag...", 3000, false, true, {
        disableMovement = true,
        disableCombat = true,
        disableCarMovement = true,
        disableMouse = false
    }, {}, {}, {}, function()
        ClearPedTasks(ped)
        TriggerServerEvent('jh-dumpster:server:crackMoneyBag')
    end, function()
        ClearPedTasks(ped)
    end)
end)
