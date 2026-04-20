local QBCore = exports['qb-core']:GetCoreObject()
local currentTurf = nil
local CurrentOwners = {}
local TurfBlips = {} -- Tracks radius blips
local IconBlips = {} -- Tracks center icons
local GangModelMap = {}
local SpawnedZoneGuards = {}
local DeathLootHandled = false
local searchTimers = {}
local pendingDespawn = {}

local GangBlipStyles = {
    families = { iconSprite = 1, radiusAlpha = 120 },
    ballas = { iconSprite = 2, radiusAlpha = 110 },
    vagos = { iconSprite = 3, radiusAlpha = 115 },
    marabunta = { iconSprite = 4, radiusAlpha = 130 },
    aztecas = { iconSprite = 5, radiusAlpha = 100 },
    lostmc = { iconSprite = 6, radiusAlpha = 125 },
    kkangpae = { iconSprite = 7, radiusAlpha = 105 },
    armenian = { iconSprite = 8, radiusAlpha = 100 },
    madrazo = { iconSprite = 9, radiusAlpha = 120 },
    triads = { iconSprite = 10, radiusAlpha = 115 },
}

local function GetGangBlipStyle(gang)
    return GangBlipStyles[gang] or { iconSprite = 84, radiusAlpha = 128 }
end

local function GetGangBlipSprite(gang)
    return GetGangBlipStyle(gang).iconSprite
end

local function SafeSetPedComponent(ped, slotId, drawableId, textureId, paletteId)
    if type(slotId) ~= 'number' or slotId < 0 or slotId > 11 then
        print(("^3[jh-turf-war] Ignored invalid clothing slotId: %s^0"):format(tostring(slotId)))
        return false
    end

    local maxDrawable = GetNumberOfPedDrawableVariations(ped, slotId)
    if maxDrawable <= 0 then
        return false
    end

    local safeDrawable = math.max(0, math.min(drawableId or 0, maxDrawable - 1))
    local maxTexture = GetNumberOfPedTextureVariations(ped, slotId, safeDrawable)
    local safeTexture = maxTexture > 0 and math.max(0, math.min(textureId or 0, maxTexture - 1)) or 0

    SetPedComponentVariation(ped, slotId, safeDrawable, safeTexture, paletteId or 0)
    return true
end

local function SafeSetPedProp(ped, propId, drawableId, textureId)
    if type(propId) ~= 'number' or propId < 0 or propId > 7 then
        print(("^3[jh-turf-war] Ignored invalid prop slotId: %s^0"):format(tostring(propId)))
        return false
    end

    if drawableId == nil or drawableId < 0 then
        ClearPedProp(ped, propId)
        return true
    end

    local maxDrawable = GetNumberOfPedPropDrawableVariations(ped, propId)
    if maxDrawable <= 0 then
        ClearPedProp(ped, propId)
        return false
    end

    local safeDrawable = math.max(0, math.min(drawableId, maxDrawable - 1))
    local maxTexture = GetNumberOfPedPropTextureVariations(ped, propId, safeDrawable)
    local safeTexture = maxTexture > 0 and math.max(0, math.min(textureId or 0, maxTexture - 1)) or 0

    ClearPedProp(ped, propId)
    SetPedPropIndex(ped, propId, safeDrawable, safeTexture, true)
    return true
end

local function ApplyGangAppearance(ped, gang)
    local gangData = Config.Gangs[gang]
    if not gangData then
        return
    end

    if gangData.components then
        for slotId, variation in pairs(gangData.components) do
            local componentSlot = tonumber(slotId)
            local drawableId = type(variation) == 'table' and (variation.drawable or variation[1]) or 0
            local textureId = type(variation) == 'table' and (variation.texture or variation[2]) or 0
            local paletteId = type(variation) == 'table' and (variation.palette or variation[3]) or 0
            SafeSetPedComponent(ped, componentSlot, drawableId, textureId, paletteId)
        end
    end

    if gangData.props then
        for propId, variation in pairs(gangData.props) do
            local propSlot = tonumber(propId)
            local drawableId = type(variation) == 'table' and (variation.drawable or variation[1]) or -1
            local textureId = type(variation) == 'table' and (variation.texture or variation[2]) or 0
            SafeSetPedProp(ped, propSlot, drawableId, textureId)
        end
    end
end

local function GetGangAuthority(ped, npcGang)
    local playerData = QBCore.Functions.GetPlayerData()
    local playerGang = (playerData.gang and playerData.gang.name) or "none"
    local playerRank = (((playerData.gang or {}).grade or {}).level) or 0

    if playerGang ~= npcGang then
        return "RIVAL"
    end

    if playerRank >= 4 or (playerData.gang and playerData.gang.isboss) then
        return "BOSS"
    elseif playerRank >= 2 then
        return "MEMBER"
    else
        return "PROSPECT"
    end
end

local function SetGangRelationship(ped, zoneOwnerGang)
    if not DoesEntityExist(ped) or not zoneOwnerGang or not Config.Gangs[zoneOwnerGang] then
        return
    end

    local playerData = QBCore.Functions.GetPlayerData()
    local metadata = (playerData and playerData.metadata) or {}
    local isPlayerDown = IsEntityDead(PlayerPedId()) or metadata["isdead"] or metadata["inlaststand"]

    if isPlayerDown then
        SetBlockingOfNonTemporaryEvents(ped, true)
        StopPedSpeaking(ped, true)
        ClearPedTasks(ped)
        SetPedAsEnemy(ped, false)
        SetRelationshipBetweenGroups(0, GetPedRelationshipGroupHash(ped), GetHashKey("PLAYER"))
        SetRelationshipBetweenGroups(0, GetHashKey("PLAYER"), GetPedRelationshipGroupHash(ped))
        return
    end

    local authority = GetGangAuthority(ped, zoneOwnerGang)

    if authority == "BOSS" then
        local pedState = Entity(ped).state

        if not pedState.hasGreetedBoss then
            pedState:set('hasGreetedBoss', true, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            StopPedSpeaking(ped, true)
            ClearPedTasks(ped)
            TaskTurnPedToFaceEntity(ped, PlayerPedId(), 1000)
            PlayAmbientSpeech1(ped, "GREET_GANG_MEMBER", "SPEECH_PARAMS_FORCE_NORMAL")

            local animDict = "anim@mp_player_intincasino@b_idles@nod"
            local animName = "nod_loop_a"
            RequestAnimDict(animDict)

            Citizen.CreateThread(function()
                local timeoutAt = GetGameTimer() + 2000
                while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeoutAt do
                    Citizen.Wait(10)
                end

                if DoesEntityExist(ped) and HasAnimDictLoaded(animDict) and not IsEntityPlayingAnim(ped, animDict, animName, 3) then
                    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, 2000, 0, 0, false, false, false)
                end
            end)
        end
        return
    elseif authority == "MEMBER" or authority == "PROSPECT" then
        SetBlockingOfNonTemporaryEvents(ped, true)
        StopPedSpeaking(ped, true)
        ClearPedTasks(ped)
        SetPedAsEnemy(ped, false)
        SetRelationshipBetweenGroups(0, GetPedRelationshipGroupHash(ped), GetHashKey("PLAYER"))
        SetRelationshipBetweenGroups(0, GetHashKey("PLAYER"), GetPedRelationshipGroupHash(ped))
        return
    elseif authority == "RIVAL" then
        SetBlockingOfNonTemporaryEvents(ped, false)
        StopPedSpeaking(ped, false)
        SetPedAsEnemy(ped, true)
        TaskCombatPed(ped, PlayerPedId(), 0, 16)
        return
    end
end

local function GetGuardModelList(turf, ownerGang)
    if turf.guards and #turf.guards > 0 then
        return turf.guards
    end

    local gangData = Config.Gangs[ownerGang]
    return (gangData and gangData.models) or {}
end

local function ClearZoneGuards(turfId)
    if not SpawnedZoneGuards[turfId] then
        return
    end

    for _, ped in ipairs(SpawnedZoneGuards[turfId]) do
        searchTimers[ped] = nil
        pendingDespawn[ped] = nil

        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end

    SpawnedZoneGuards[turfId] = nil
end

local function SpawnZoneGuards(turf, ownerGang)
    if not turf or not turf.id or SpawnedZoneGuards[turf.id] then
        return
    end

    local guardList = GetGuardModelList(turf, ownerGang)
    if #guardList == 0 then
        return
    end

    SpawnedZoneGuards[turf.id] = {}
    local coords = turf.coords
    local radius = math.max(6.0, math.min((turf.radius or 20.0) * 0.35, 18.0))

    for i = 1, #guardList do
        local modelRef = guardList[i]
        local model = type(modelRef) == "string" and GetHashKey(modelRef) or modelRef
        RequestModel(model)

        local timeoutAt = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < timeoutAt do
            Citizen.Wait(0)
        end

        if HasModelLoaded(model) then
            local angle = ((i - 1) / #guardList) * 360.0
            local spawnX = coords.x + (math.cos(math.rad(angle)) * radius)
            local spawnY = coords.y + (math.sin(math.rad(angle)) * radius)
            local spawnZ = coords.z
            local heading = GetHeadingFromVector_2d(coords.x - spawnX, coords.y - spawnY)
            local foundGround, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, coords.z + 50.0, false)
            local ped = CreatePed(4, model, spawnX, spawnY, foundGround and groundZ or spawnZ, heading, true, false)

            SetEntityAsMissionEntity(ped, true, true)
            SetEntityVisible(ped, true, false)
            PlaceObjectOnGroundProperly(ped)
            SetEntityInvincible(ped, false)
            FreezeEntityPosition(ped, false)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedRelationshipGroupHash(ped, GetHashKey(ownerGang))
            SetPedCombatAttributes(ped, 46, true)
            SetPedCombatAttributes(ped, 5, true)
            SetPedAccuracy(ped, math.random(35, 60))
            ApplyGangAppearance(ped, ownerGang)
            Entity(ped).state:set('isTurfGuard', true, true)
            Entity(ped).state:set('turfGang', ownerGang, true)

            if not HasPedGotWeapon(ped, GetHashKey("WEAPON_PISTOL"), false) then
                GiveWeaponToPed(ped, GetHashKey("WEAPON_PISTOL"), 250, false, true)
                SetPedDropsWeaponsWhenDead(ped, false)
            end

            SetGangRelationship(ped, ownerGang)
            table.insert(SpawnedZoneGuards[turf.id], ped)
            SetModelAsNoLongerNeeded(model)
            Citizen.Wait(100)
        end
    end
end

local function RefreshZoneGuards()
    for _, turf in pairs(Config.Territories) do
        local ownerGang = CurrentOwners[turf.id] or turf.owner

        if turf._spawnOwner ~= ownerGang then
            ClearZoneGuards(turf.id)
            turf._spawnOwner = ownerGang
        end

        if not SpawnedZoneGuards[turf.id] then
            SpawnZoneGuards(turf, ownerGang)
        end
    end
end

-- 1. RELATIONSHIP SETUP
Citizen.CreateThread(function()
    for gang, data in pairs(Config.Gangs) do
        AddRelationshipGroup(gang)
        for _, modelHash in ipairs(data.models) do
            if GangModelMap[modelHash] == nil then
                GangModelMap[modelHash] = gang
            end
        end
    end

    for gang, _ in pairs(Config.Gangs) do
        local gangHash = GetHashKey(gang)
        for target, _ in pairs(Config.Gangs) do
            if gang ~= target then
                SetRelationshipBetweenGroups(5, gangHash, GetHashKey(target))
            end
        end
        SetRelationshipBetweenGroups(5, gangHash, GetHashKey("PLAYER"))
    end
end)

-- 2. BLIP SYSTEM
local function RebuildTerritoryBlip(turfId, owner)
    for _, turf in pairs(Config.Territories) do
        if turf.id == turfId then
            if TurfBlips[turf.id] then
                RemoveBlip(TurfBlips[turf.id])
                TurfBlips[turf.id] = nil
            end

            if IconBlips[turf.id] then
                RemoveBlip(IconBlips[turf.id])
                IconBlips[turf.id] = nil
            end

            local zoneCoords = turf.coords
            local zoneRadius = turf.radius
            local zoneOwner = owner or turf.owner
            local gangData = Config.Gangs[zoneOwner]
            local color = gangData and gangData.color or 1
            local style = GetGangBlipStyle(zoneOwner)

            local blip = AddBlipForRadius(zoneCoords.x, zoneCoords.y, zoneCoords.z, zoneRadius)
            SetBlipColour(blip, color)
            SetBlipAlpha(blip, 128)
            SetBlipAsShortRange(blip, true)
            SetBlipHighDetail(blip, true)
            TurfBlips[turf.id] = blip

            local icon = AddBlipForCoord(zoneCoords.x, zoneCoords.y, zoneCoords.z)
            SetBlipSprite(icon, style.iconSprite)
            SetBlipScale(icon, 0.6)
            SetBlipAsShortRange(icon, true)
            SetBlipColour(icon, color)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Turf: " .. turf.label)
            EndTextCommandSetBlipName(icon)
            IconBlips[turf.id] = icon
            return
        end
    end
end

function CreateTerritoryBlips()
    for _, turf in pairs(Config.Territories) do
        RebuildTerritoryBlip(turf.id, CurrentOwners[turf.id] or turf.owner)
    end
end

function RefreshBlipColors(previousOwners)
    for turfId, owner in pairs(CurrentOwners) do
        if not previousOwners or previousOwners[turfId] ~= owner or not TurfBlips[turfId] then
            RebuildTerritoryBlip(turfId, owner)
        end
    end
end

-- 3. SYNC LOGIC
RegisterNetEvent('turf-war:client:SyncOwners', function(data)
    local previousOwners = CurrentOwners
    CurrentOwners = data
    RefreshBlipColors(previousOwners)
    RefreshZoneGuards()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SyncPlayer()
    TriggerServerEvent('turf-war:server:RequestSync')
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', SyncPlayer)

function SyncPlayer()
    local pData = QBCore.Functions.GetPlayerData()
    local pPed = PlayerPedId()

    for gang, _ in pairs(Config.Gangs) do
        SetRelationshipBetweenGroups(5, GetHashKey(gang), GetHashKey("PLAYER"))
    end

    if pData.gang and Config.Gangs[pData.gang.name] then
        SetPedRelationshipGroupHash(pPed, GetHashKey(pData.gang.name))
        SetRelationshipBetweenGroups(1, GetHashKey(pData.gang.name), GetHashKey("PLAYER"))
    else
        SetPedRelationshipGroupHash(pPed, GetHashKey("PLAYER"))
    end
end

-- Initialize Blips on start
Citizen.CreateThread(function()
    CreateTerritoryBlips()
    RefreshZoneGuards()
    TriggerServerEvent('turf-war:server:RequestSync')
end)

local function GetActiveTurfData()
    if not currentTurf then
        return nil
    end

    if type(currentTurf) == "table" and currentTurf.id then
        return currentTurf
    end

    currentTurf = nil
    return nil
end

local function WasKilledByRivalGuard(ownerGang)
    local killer = GetPedSourceOfDeath(PlayerPedId())
    if killer == 0 or not DoesEntityExist(killer) or not IsEntityAPed(killer) or IsPedAPlayer(killer) then
        return false
    end

    local killerGang = GangModelMap[GetEntityModel(killer)]
    local killerGroup = GetPedRelationshipGroupHash(killer)
    return killerGang == ownerGang or killerGroup == GetHashKey(ownerGang)
end

RegisterNetEvent('jh-turf-war:client:EnemiesStandDown', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local currentZone = GetZoneAtCoords(playerCoords.x, playerCoords.y, playerCoords.z)

    if currentZone and currentZone ~= 0 then
        if GetResourceState('jh-streetstalk-dispatch') == 'started' then
            exports['jh-streetstalk-dispatch']:AddZoneHeat(currentZone, -100)
        end
    end

    local peds = GetGamePool('CPed')

    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsEntityDead(ped) then
            local dist = #(playerCoords - GetEntityCoords(ped))

            if dist < 50.0 then
                ClearPedTasksImmediately(ped)
                ClearPedSecondaryTask(ped)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedAsEnemy(ped, false)
                SetRelationshipBetweenGroups(0, GetPedRelationshipGroupHash(ped), GetHashKey("PLAYER"))
                SetRelationshipBetweenGroups(0, GetHashKey("PLAYER"), GetPedRelationshipGroupHash(ped))

                local randomAction = math.random(1, 3)
                if randomAction == 1 then
                    TaskWanderStandard(ped, 10.0, 10)
                elseif randomAction == 2 then
                    local wanderCoords = GetOffsetFromEntityInWorldCoords(ped, math.random(-10, 10), math.random(-10, 10), 0.0)
                    TaskGoStraightToCoord(ped, wanderCoords.x, wanderCoords.y, wanderCoords.z, 1.0, -1, 0.0, 0.0)
                else
                    TaskStandStill(ped, 10000)
                end

                ClearPedBloodDamage(ped)
            end
        end
    end
end)

Citizen.CreateThread(function()
    local isDead = false

    while true do
        Citizen.Wait(1000)

        local playerPed = PlayerPedId()
        local playerData = QBCore.Functions.GetPlayerData()
        local metadata = (playerData and playerData.metadata) or {}
        local isPlayerDown = IsEntityDead(playerPed) or metadata["isdead"] or metadata["inlaststand"]

        if isPlayerDown then
            if not isDead then
                isDead = true
                TriggerEvent('jh-turf-war:client:EnemiesStandDown')
            end
        elseif not IsEntityDead(playerPed) and not metadata["isdead"] then
            if isDead then
                isDead = false
                -- This ensures the turf script releases control of your ped
                SetBlockingOfNonTemporaryEvents(playerPed, false)
            end
        end
    end
end)

-- 4. CAPTURE LOGIC
function CaptureLoop()
    Citizen.CreateThread(function()
        local progress = 0
        local dispatchTriggered = false
        local activeTurfId = currentTurf and currentTurf.id

        while currentTurf do
            Citizen.Wait(1000)

            local turfData = GetActiveTurfData()
            if not turfData then
                return
            end

            local zoneLabel = turfData.label or turfData.id
            local pData = QBCore.Functions.GetPlayerData()
            local metadata = (pData and pData.metadata) or {}
            local isPlayerDown = IsEntityDead(PlayerPedId()) or metadata["isdead"] or metadata["inlaststand"]
            local pGang = (pData.gang and pData.gang.name) or "none"
            local owner = CurrentOwners[turfData.id] or turfData.owner or "none"
            activeTurfId = turfData.id

            if not isPlayerDown and pGang ~= "none" and pGang ~= owner then
                if not dispatchTriggered then
                    TriggerServerEvent('turf-war:server:CaptureStarted', turfData.id)
                    dispatchTriggered = true
                end

                progress = progress + 1
                if progress % 10 == 0 then
                    QBCore.Functions.Notify("Taking " .. zoneLabel .. " from the " .. owner:upper() .. ": " .. progress .. "/" .. Config.CaptureTime .. "s", "primary")
                end

                if progress >= Config.CaptureTime then
                    TriggerServerEvent('turf-war:server:CaptureTurf', turfData.id)
                    progress = 0
                    dispatchTriggered = false
                    break
                end
            else
                if dispatchTriggered and activeTurfId then
                    TriggerServerEvent('turf-war:server:CaptureEnded', activeTurfId)
                    dispatchTriggered = false
                end
                progress = 0
            end
        end

        if dispatchTriggered and activeTurfId then
            TriggerServerEvent('turf-war:server:CaptureEnded', activeTurfId)
        end
    end)
end

-- 5. ZONE & NPC SETUP
Citizen.CreateThread(function()
    ---@diagnostic disable-next-line: undefined-global
    local hasCircleZone = CircleZone and CircleZone.Create

    if not hasCircleZone then
        print("^1[jh-turf-war] CircleZone is missing. Make sure PolyZone is installed and started before this resource.^0")
        return
    end

    for _, turf in pairs(Config.Territories) do
        ---@diagnostic disable-next-line: undefined-global
        local zone = CircleZone:Create(turf.coords, turf.radius, {
            name = turf.id,
            useZ = true,
            debugPoly = Config.Debug
        })

        zone:onPlayerInOut(function(isInside)
            currentTurf = isInside and turf or nil
            if isInside then CaptureLoop() end
        end)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local playerPed = PlayerPedId()
        local pCoords = GetEntityCoords(playerPed)
        local playerData = QBCore.Functions.GetPlayerData()
        local metadata = (playerData and playerData.metadata) or {}
        local isPlayerDown = IsEntityDead(playerPed) or metadata["isdead"] or metadata["inlaststand"]

        for _, ped in ipairs(GetGamePool('CPed')) do
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsEntityDead(ped) and Entity(ped).state.isTurfGuard then
                local turfGang = Entity(ped).state.turfGang or GangModelMap[GetEntityModel(ped)]
                local eCoords = GetEntityCoords(ped)
                local dist = #(pCoords - eCoords)
                local despawnDistance = Config.DeSpawnDistance or 120.0

                if dist > despawnDistance then
                    if not IsPedInCombat(ped, playerPed) and not searchTimers[ped] and not pendingDespawn[ped] then
                        local despawnToken = GetGameTimer()
                        pendingDespawn[ped] = despawnToken

                        SetTimeout(30000, function()
                            if DoesEntityExist(ped) and pendingDespawn[ped] == despawnToken then
                                local playerDistance = #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId()))
                                if playerDistance > despawnDistance and not IsPedInCombat(ped, PlayerPedId()) and not searchTimers[ped] then
                                    DeleteEntity(ped)
                                end
                                pendingDespawn[ped] = nil
                                searchTimers[ped] = nil
                            end
                        end)
                    end
                else
                    pendingDespawn[ped] = nil
                end

                if isPlayerDown then
                    searchTimers[ped] = nil
                elseif dist < 30.0 then
                    local forward = GetEntityForwardVector(ped)
                    local toPlayer = pCoords - eCoords
                    local toPlayerLength = #toPlayer
                    local isFacing = false

                    if toPlayerLength > 0.001 then
                        local dot = ((forward.x * toPlayer.x) + (forward.y * toPlayer.y) + (forward.z * toPlayer.z)) / toPlayerLength
                        isFacing = dot > math.cos(math.rad(90.0))
                    end

                    local canSpotPlayer = (dist < 30.0 and isFacing and HasEntityClearLosToEntity(ped, playerPed, 17)) or (dist < 5.0)

                    if canSpotPlayer then
                        if turfGang and GetGangAuthority(ped, turfGang) == "RIVAL" and not IsPedInCombat(ped, playerPed) then
                            PlayAmbientSpeech1(ped, "CHALLENGE_THREATEN", "SPEECH_PARAMS_FORCE_NORMAL")
                            TaskCombatPed(ped, playerPed, 0, 16)
                        end
                        searchTimers[ped] = nil
                    else
                        if IsPedInCombat(ped, playerPed) and not searchTimers[ped] then
                            searchTimers[ped] = GetGameTimer() + 15000
                            ClearPedTasks(ped)
                            TaskGoStraightToCoord(ped, pCoords.x, pCoords.y, pCoords.z, 1.0, -1, 0.0, 0.0)
                        end
                    end
                end

                if searchTimers[ped] and GetGameTimer() > searchTimers[ped] then
                    searchTimers[ped] = nil
                    ClearPedTasks(ped)
                    TaskWanderStandard(ped, 10.0, 10)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    PlayAmbientSpeech1(ped, "GENERIC_CURSE_HIGH", "SPEECH_PARAMS_FORCE_NORMAL")
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2500)
        local handle, ped = FindFirstPed()
        local success

        repeat
            if not IsPedAPlayer(ped) and not IsEntityDead(ped) then
                local model = GetEntityModel(ped)
                local foundGang = GangModelMap[model]

                if foundGang then
                    local groupHash = GetHashKey(foundGang)
                    if GetPedRelationshipGroupHash(ped) ~= groupHash then
                        SetPedRelationshipGroupHash(ped, groupHash)
                        SetPedCombatAttributes(ped, 46, true)
                        SetPedCombatAttributes(ped, 5, true)
                        SetPedAccuracy(ped, math.random(35, 60))
                        ApplyGangAppearance(ped, foundGang)

                        if not HasPedGotWeapon(ped, GetHashKey("WEAPON_PISTOL"), false) then
                            GiveWeaponToPed(ped, GetHashKey("WEAPON_PISTOL"), 250, false, true)
                            SetPedDropsWeaponsWhenDead(ped, false)
                        end
                    end

                    SetGangRelationship(ped, foundGang)
                end
            end
            success, ped = FindNextPed(handle)
        until not success
        EndFindPed(handle)
    end
end)