local QBCore = exports['qb-core']:GetCoreObject()

-- Prevents the script from crashing if it tries to access an entity that
-- was deleted or moved out of scope during a search/interaction
local function SafeGetNetID(entity)
    if not DoesEntityExist(entity) then return nil end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId == 0 then return nil end
    return netId
end

local function SpawnPedWithOffset(model, coords, heading)
    if not model or not coords then return nil end

    local spawnX = coords.x + math.random(-2, 2)
    local spawnY = coords.y + math.random(-2, 2)
    local ped = CreatePed(4, model, spawnX, spawnY, coords.z, heading or 0.0, true, false)

    return ped
end

local isWhistling = false

local function GetGangAuthority(ped, npcGang)
    local playerData = QBCore.Functions.GetPlayerData()
    local playerGang = playerData and playerData.gang and playerData.gang.name or nil
    local playerRank = playerData and playerData.gang and playerData.gang.grade and playerData.gang.grade.level or 0

    if playerGang ~= npcGang then
        return "RIVAL"
    end

    if playerRank >= 4 then
        return "BOSS"
    elseif playerRank >= 2 then
        return "MEMBER"
    else
        return "PROSPECT"
    end
end

local function ApplyGangAuthorityEffects(npc, applyZoneBonus)
    if not npc or not DoesEntityExist(npc) then return end

    local dealerModel = GetEntityModel(npc)
    local dealerGang = Config.GangModels[dealerModel]
    local authority = GetGangAuthority(npc, dealerGang)
    local state = Entity(npc).state

    if authority == "BOSS" then
        state:set('loyalty', 100, true)
        state:set('bossBonus', 1.15, true)

        if applyZoneBonus then
            TriggerEvent('chat:addMessage', { args = { "DEALER", "Anything for you, Boss. The streets are ours." } })

            if GetResourceState('jh-streetstalk-dispatch') == 'started' then
                local coords = GetEntityCoords(npc)
                local currentZone = GetNameOfZone(coords.x, coords.y, coords.z)
                if currentZone then
                    exports['jh-streetstalk-dispatch']:AddZoneHeat(currentZone, -10)
                end
            end
        end
    elseif authority == "MEMBER" then
        state:set('loyalty', 75, true)
        state:set('bossBonus', 1.05, true)
    elseif authority == "PROSPECT" then
        state:set('loyalty', 50, true)
        state:set('bossBonus', 1.0, true)
    else
        state:set('loyalty', 0, true)
        state:set('bossBonus', 1.0, true)
    end
end

local function SetGangRelationship(ped, gangName)
    if not ped or ped == 0 or not DoesEntityExist(ped) or not gangName then return end

    local playerData = QBCore.Functions.GetPlayerData()
    local playerGang = playerData and playerData.gang and playerData.gang.name or nil
    local groupName = "GANG_" .. gangName:upper()
    local groupHash = GetHashKey(groupName)
    local playerGroup = GetHashKey("PLAYER")

    AddRelationshipGroup(groupName)
    SetPedRelationshipGroupHash(ped, groupHash)

    if playerGang == gangName then
        SetRelationshipBetweenGroups(0, groupHash, playerGroup)
        SetRelationshipBetweenGroups(0, playerGroup, groupHash)
        SetCanAttackFriendly(ped, false, false)
        SetPedCanRagdollFromPlayerImpact(ped, false)
    else
        SetRelationshipBetweenGroups(5, groupHash, playerGroup)
        SetRelationshipBetweenGroups(5, playerGroup, groupHash)
        SetCanAttackFriendly(ped, true, false)
    end
end

local function TriggerLookoutAlert()
    if isWhistling then return end
    isWhistling = true
    
    local ped = QBCore.Functions.GetClosestPed()
    if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
        RequestAnimDict("rcmnigel1c")
        while not HasAnimDictLoaded("rcmnigel1c") do Wait(0) end
        TaskPlayAnim(ped, "rcmnigel1c", "hailing_whistle_waist_high", 8.0, -8.0, -1, 49, 0, false, false, false)
        PlaySoundFromEntity(-1, "Whistle_Wait", ped, "Speech_Menu_Sounds", false, false)
    end

    QBCore.Functions.Notify("The block is hot! A lookout just whistled.", "error")
    SetTimeout(60000, function() isWhistling = false end) -- 1 minute cooldown
end

-- Ambient patrol detection loop
CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds for nearby AI Cops
        
        -- Calls the export from jh-streetstalk-dispatch
        local cop, copVeh = exports['jh-streetstalk-dispatch']:GetClosestPatrol(60.0)
        
        if cop then
            TriggerLookoutAlert()
        end
    end
end)

RegisterNetEvent('jh-gangwars:client:TryRecruit', function(data)
    local entity = data.entity
    if not NetworkGetEntityIsNetworked(entity) then NetworkRegisterEntityAsNetworked(entity) end
    SetEntityAsMissionEntity(entity, true, true)
    
    local netId = NetworkGetNetworkIdFromEntity(entity)
    
    -- ASK THE SERVER TO CREATE THE ID (This fixes the sync error)
    TriggerServerEvent('jh-gangwars:server:RequestDealerID', netId)
    
    -- The rest of your movement/group logic...
    local group = GetPedGroupIndex(PlayerPedId())
    if group == 0 then
        group = CreateGroup(0)
        SetPedAsGroupLeader(PlayerPedId(), group)
    end

    SetPedAsGroupMember(entity, group)
    SetPedNeverLeavesGroup(entity, true)
    SetBlockingOfNonTemporaryEvents(entity, true)

    local state = Entity(entity).state
    state:set('isFollowing', true, true)
    state:set('isBodyguard', true, true)
    state:set('isDealer', false, true)

    local gangName = Config.GangModels[GetEntityModel(entity)]
    if gangName then
        SetGangRelationship(entity, gangName)
    end
end)

RegisterNetEvent('jh-gangwars:client:RecruitGuard', function(data)
    TriggerEvent('jh-gangwars:client:TryRecruit', data)

    local ped = data.entity
    if not ped or not DoesEntityExist(ped) then return end

    local state = Entity(ped).state
    state:set('isBodyguard', true, true)
    state:set('isFollowing', true, true)
    state:set('isDealer', false, true)

    TaskFollowToOffsetOfEntity(ped, PlayerPedId(), 0.0, -1.5, 0.0, 1.0, -1, 10.0, true)
    SetPedCombatAttributes(ped, 46, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    QBCore.Functions.Notify("Bodyguard is now backing you up.", "success")
end)

RegisterNetEvent('jh-gangwars:client:StopFollowing', function(data)
    local entity = data and data.entity or data
    if not entity or not DoesEntityExist(entity) then return end

    local state = Entity(entity).state
    state:set('isFollowing', false, true)
    state:set('isBodyguard', false, true)

    ClearPedTasks(entity)
    RemovePedFromGroup(entity)
    TaskWanderStandard(entity, 10.0, 10)
    QBCore.Functions.Notify("Bodyguard dismissed.", "primary")
end)

RegisterNetEvent('jh-gangwars:client:SetCorner', function(data)
    local ped = data.entity
    if not ped or not DoesEntityExist(ped) then return end

    ClearPedTasks(ped)

    Entity(ped).state:set('isBodyguard', false, true)
    Entity(ped).state:set('isFollowing', false, true)
    Entity(ped).state:set('isDealer', true, true)

    SetEntityHeading(ped, GetEntityHeading(PlayerPedId()))
    SetBlockingOfNonTemporaryEvents(ped, true)

    QBCore.Functions.Notify("Corner set. They are ready for supplies.", "primary")
    TriggerEvent('jh-gangwars:client:SetToSell', data)
end)

RegisterNetEvent('jh-gangwars:client:SupplyDealer', function(data)
    local entity = data.entity
    if not entity or not DoesEntityExist(entity) then return end

    local state = Entity(entity).state
    local dealerID = state.dealerID or ("DLR_" .. math.random(1111, 9999))
    state:set('dealerID', dealerID, true)
    ApplyGangAuthorityEffects(entity, false)

    local menu = {
        { header = "Supply Dealer", isMenuHeader = true }
    }

    local playerItems = QBCore.Functions.GetPlayerData().items or {}
    local drugConfig = Config.Drugs or Config.Items or {}

    for drugName, info in pairs(drugConfig) do
        local ownedAmount = 0

        for _, invItem in pairs(playerItems) do
            if invItem and invItem.name == drugName then
                ownedAmount = invItem.amount or 0
                break
            end
        end

        if ownedAmount > 0 then
            local sharedItem = QBCore.Shared.Items[drugName]
            local label = (info and info.label) or (sharedItem and sharedItem.label) or drugName

            table.insert(menu, {
                header = "Give " .. label,
                txt = "Available: " .. ownedAmount .. " | Hand over stock to sell on this corner",
                params = {
                    event = "jh-gangwars:client:ProcessSupply",
                    args = {
                        item = drugName,
                        entity = entity,
                        dealerID = dealerID
                    }
                }
            })
        end
    end

    if #menu == 1 then
        QBCore.Functions.Notify("You have no valid drug stock to supply.", "error")
        return
    end

    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('jh-gangwars:client:ProcessSupply', function(data)
    local entity = data.entity
    if not entity or not DoesEntityExist(entity) then return end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId == 0 then
        NetworkRegisterEntityAsNetworked(entity)
        netId = NetworkGetNetworkIdFromEntity(entity)
    end

    local dialog = exports['qb-input']:ShowInput({
        header = "Amount to Supply",
        submitText = "Give",
        inputs = {{ text = "Amount", name = "amount", type = "number", isRequired = true }}
    })

    if dialog and tonumber(dialog.amount) and tonumber(dialog.amount) > 0 then
        TriggerServerEvent('jh-gangwars:server:GiveStock', {
            dealerID = data.dealerID,
            netId = netId,
            item = data.item,
            amount = tonumber(dialog.amount)
        })
    end
end)

-- New event to receive the ID from the server
RegisterNetEvent('jh-gangwars:client:ReceiveDealerID', function(netId, dealerID)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        Entity(entity).state:set('dealerID', dealerID, true)
        QBCore.Functions.Notify("Dealer assigned ID: " .. dealerID, "success")
    end
end)

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler('dealerID', nil, function(bagName, key, value, _unused, replicated)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    
    -- This ensures that even if the ped was spawned by another player, 
    -- your client now knows this ped is a dealer.
    if value then
        SetEntityAsMissionEntity(entity, true, true)
        SetBlockingOfNonTemporaryEvents(entity, true)

        local gangName = Config.GangModels[GetEntityModel(entity)]
        if gangName then
            SetGangRelationship(entity, gangName)
        end
    end
end)

local function IsGangModelWhitelisted(entity)
    local model = GetEntityModel(entity)

    if Config.GangModels and Config.GangModels[model] then
        return true
    end

    for modelName, allowed in pairs(Config.GangModels or {}) do
        if allowed and type(modelName) == 'string' and model == GetHashKey(modelName) then
            return true
        end
    end

    return false
end

local function IsPedInGang(entity)
    if not DoesEntityExist(entity) then return false end
    local model = GetEntityModel(entity)

    for gangName, data in pairs(Config.Gangs) do
        for _, gangModel in pairs(data.models) do
            if model == GetHashKey(gangModel) then
                return true
            end
        end
    end
    return false
end

RegisterNetEvent('jh-gangwars:client:GiveItems', function(data)
    local entity = data.entity
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local dealerID = Entity(entity).state.dealerID

    local playerItems = QBCore.Functions.GetPlayerData().items
    local menu = {{ header = "Supply Dealer", isMenuHeader = true }}
    
    for slot, item in pairs(playerItems) do
        -- Only show items that are defined in our Drug Config
        if item and Config.Items[item.name] then
            table.insert(menu, { 
                header = item.label, 
                txt = "Current: " .. item.amount, 
                params = { 
                    event = "jh-gangwars:client:InputAmount", 
                    args = { 
                        item = item.name, -- This must match the key in Config.Items
                        dealerID = dealerID,
                        netId = netId
                    } 
                } 
            })
        end
    end
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('jh-gangwars:client:GiveDrugsToGuard', function(data)
    local entity = data.entity
    if not entity or not DoesEntityExist(entity) then return end

    local state = Entity(entity).state
    if not state.isFollowing and not state.isDealer then
        QBCore.Functions.Notify("This NPC is not assigned to you.", "error")
        return
    end

    TriggerEvent('jh-gangwars:client:SupplyDealer', data)
end)

RegisterNetEvent('jh-gangwars:client:InputAmount', function(data)
    local dialog = exports['qb-input']:ShowInput({ 
        header = "Amount to Supply", 
        submitText = "Give", 
        inputs = {{ text = "Amount", name = "amount", type = "number", isRequired = true }} 
    })
    
    if dialog then 
        TriggerServerEvent('jh-gangwars:server:GiveStock', { 
            dealerID = data.dealerID, 
            netId = data.netId, -- Pass the fallback
            item = data.item, 
            amount = tonumber(dialog.amount) 
        }) 
    end
end)

RegisterNetEvent('jh-gangwars:client:SetToSell', function(data)
    local entity = data.entity
    
    if not entity or not DoesEntityExist(entity) then 
        print("Error: Entity not found in data table!")
        return 
    end

    if not IsEntityAPed(entity) then 
        return 
    end

    if IsEntityDead(entity) or IsPedRagdoll(entity) then
        QBCore.Functions.Notify("This dealer is incapacitated.", "error")
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId == 0 then 
        NetworkRegisterEntityAsNetworked(entity)
        netId = NetworkGetNetworkIdFromEntity(entity)
    end
    
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetEntityAsMissionEntity(entity, true, true)

    -- Tell the QB-Drugs flow we are now on a corner
    LocalPlayer.state:set('inv_busy', true, true)

    local state = Entity(entity).state
    state:set('isFollowing', false, true)
    state:set('isBodyguard', false, true)
    state:set('isCornerDealer', true, true)
    state:set('isCornerSelling', true, true)
    state:set('isDealer', true, true)
    
    local dealerID = state.dealerID or ("DLR_" .. math.random(1000, 9999))
    state:set('dealerID', dealerID, true)
    state:set('isSelling', true, true)

    ClearPedTasks(entity)
    TaskStartScenarioInPlace(entity, "WORLD_HUMAN_STAND_MOBILE", 0, true)

    local pedModel = GetEntityModel(entity)
    local gangType = Config.GangModels[pedModel]
    local blipColor = Config.Gangs[gangType] and Config.Gangs[gangType].color or 1

    local blip = AddBlipForEntity(entity)
    SetBlipSprite(blip, 280) -- Small house/dealer icon
    SetBlipColour(blip, blipColor)

    ApplyGangAuthorityEffects(entity, true)
    
    TriggerServerEvent('jh-gangwars:server:ActivateCorner', netId, dealerID)
    QBCore.Functions.Notify("Corner active. Dealer ID: " .. dealerID, "success")
end)

RegisterNetEvent('jh-gangwars:client:OpenDealerShop', function(data)
    local dealerID = Entity(data.entity).state.dealerID
    if not dealerID then QBCore.Functions.Notify("Dealer not ready.", "error") return end
    QBCore.Functions.TriggerCallback('jh-gangwars:server:GetDealerShopMenu', function(menu)
        if menu then exports['qb-menu']:openMenu(menu) end
    end, dealerID)
end)

RegisterNetEvent('jh-gangwars:client:SearchDealer', function(entity, dealerID)
    local ped = PlayerPedId()
    
    -- Immersive searching animation
    TaskStartScenarioInPlace(ped, "CODE_HUMAN_MEDIC_TEND_TO_DEAD", 0, true)
    
    QBCore.Functions.Progressbar("search_dealer", "Emptying Pockets...", 5000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        ClearPedTasks(ped)
        TriggerServerEvent('jh-gangwars:server:LootDealer', dealerID)
        
        -- Optional: Delete the entity or remove the state so they can't be looted twice
        Entity(entity).state:set('dealerID', nil, true) 
    end, function() -- Cancel
        ClearPedTasks(ped)
    end)
end)

RegisterNetEvent('jh-gangwars:client:BuyDrugInput', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = "Buy " .. data.label,
        submitText = "Purchase",
        inputs = {
            {
                text = "Quantity (Max: " .. data.maxStock .. ")", 
                name = "amount", 
                type = "number", 
                isRequired = true
            }
        }
    })
    
    if dialog and tonumber(dialog.amount) > 0 then
        TriggerServerEvent('jh-gangwars:server:ExecutePurchase', {
            dealerID = data.dealerID,
            item = data.item,
            amount = tonumber(dialog.amount),
            price = data.price
        })
    end
end)

RegisterNetEvent('jh-gangwars:client:ViewDetailedStock', function(dealerID)
    local ped = PlayerPedId()
    
    -- Animation: Looking at a phone/tablet
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_TOURIST_MAP", 0, true)
    
    QBCore.Functions.Progressbar("checking_ledger", "Reading Dealer Ledger...", 1500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        ClearPedTasks(ped)
        QBCore.Functions.TriggerCallback('jh-gangwars:server:GetDetailedInventory', function(menu)
            if menu then
                exports['qb-menu']:openMenu(menu)
            end
        end, dealerID)
    end, function() -- Cancel
        ClearPedTasks(ped)
    end)
end)

RegisterNetEvent('jh-gangwars:client:CollectCash', function(data)
    local dealerID = type(data) == 'table' and data.dealerID or data
    if dealerID then
        TriggerServerEvent('jh-gangwars:server:CollectMoney', dealerID)
    end
end)

RegisterNetEvent('jh-gangwars:client:CheckDealerStats', function(data)
    if not data or not data.dealerID then return end

    QBCore.Functions.TriggerCallback('jh-gangwars:server:GetDealerFullStats', function(stats)
        if not stats then return end

        local menu = {
            {
                header = "Dealer Status: " .. data.dealerID,
                isMenuHeader = true
            },
            {
                header = "📊 Street Cred",
                txt = "Reputation: " .. (stats.reputation or 0) .. " / 1000",
                icon = "fas fa-star"
            },
            {
                header = "💰 Uncollected Cash",
                txt = "Amount: $" .. math.floor(stats.uncollected or 0),
                params = {
                    event = "jh-gangwars:client:CollectCash",
                    args = { dealerID = data.dealerID }
                }
            }
        }

        for itemName, stock in pairs(stats.inventory or {}) do
            local sharedItem = QBCore.Shared.Items[itemName]
            local label = sharedItem and sharedItem.label or itemName
            table.insert(menu, {
                header = label,
                txt = "Baggies: " .. (stock.baggy_stock or 0) .. " | Bricks: " .. (stock.bulk_stock or 0),
                icon = "fas fa-box"
            })
        end

        exports['qb-menu']:openMenu(menu)
    end, data.dealerID)
end)

local function GetClosestRandomPed(coords)
    local handle, ped = FindFirstPed()
    local success = true
    local closestPed = nil
    local playerPed = PlayerPedId()

    repeat
        if ped ~= 0 and ped ~= playerPed then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(coords - pedCoords)
            local state = Entity(ped).state

            if distance < 15.0 and distance > 2.0 and not IsPedAPlayer(ped) and not IsEntityDead(ped) and not state.isDealer and not state.isBodyguard then
                closestPed = ped
                break
            end
        end

        success, ped = FindNextPed(handle)
    until not success

    EndFindPed(handle)
    return closestPed
end

local function ExecuteDealerSale(dealer, buyer)
    if not DoesEntityExist(dealer) or not DoesEntityExist(buyer) then return end

    TaskGoToEntity(buyer, dealer, -1, 1.2, 1.0, 1073741824, 0)

    local arrived = false
    local timer = 0
    while not arrived and timer < 100 do
        if not DoesEntityExist(dealer) or not DoesEntityExist(buyer) then return end
        if #(GetEntityCoords(buyer) - GetEntityCoords(dealer)) < 2.0 then
            arrived = true
        end
        Wait(100)
        timer = timer + 1
    end

    if arrived then
        RequestAnimDict("mp_safehouselow")
        while not HasAnimDictLoaded("mp_safehouselow") do Wait(0) end

        TaskPlayAnim(dealer, "mp_safehouselow", "package_dropoff", 8.0, -8.0, 2000, 0, 0, false, false, false)
        TaskPlayAnim(buyer, "mp_safehouselow", "package_dropoff", 8.0, -8.0, 2000, 0, 0, false, false, false)

        Wait(2000)

        PlayAmbientSpeech1(dealer, "DEALER_REACHED_CASH_LIMIT", "SPEECH_PARAMS_FORCE_NORMAL")

        if GetResourceState('jh-streetstalk-dispatch') == 'started' then
            local dealerCoords = GetEntityCoords(dealer)
            local currentZone = GetNameOfZone(dealerCoords.x, dealerCoords.y, dealerCoords.z)
            exports['jh-streetstalk-dispatch']:AddZoneHeat(currentZone, 2) -- Minor heat increase for a street sale
        end

        TaskWanderStandard(buyer, 10.0, 10)
        TriggerServerEvent('jh-gangwars:server:DealerEarnedMoney')
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(math.random(30000, 60000)) -- Dealers look for a buyer every 30-60 seconds

        for _, ped in ipairs(GetGamePool('CPed')) do
            if Entity(ped).state.isDealer and not IsEntityDead(ped) then
                local dealerCoords = GetEntityCoords(ped)
                local buyer = GetClosestRandomPed(dealerCoords)

                if buyer then
                    ExecuteDealerSale(ped, buyer)
                end
            end
        end
    end
end)

RegisterCommand(Config.LocateCommand, function()
    local peds = GetGamePool('CPed')
    for _, ped in ipairs(peds) do
        if Entity(ped).state.isSelling then
            local coords = GetEntityCoords(ped)
            SetNewWaypoint(coords.x, coords.y)
            QBCore.Functions.Notify("Dealer marked.", "success")
            return
        end
    end
    QBCore.Functions.Notify("GPS updated with nearest dealer location.", "primary")
end, false)

exports['qb-target']:AddGlobalPed({ options = {
    {
        type = "client",
        event = "jh-gangwars:client:RecruitGuard",
        icon = "fas fa-user-plus",
        label = "Recruit Bodyguard",
        canInteract = function(entity)
            if GetEntityType(entity) ~= 1 then return false end

            local isGuard = Entity(entity).state.isBodyguard or false
            local isDealer = Entity(entity).state.isDealer or false
            local inGang = IsPedInGang(entity)

            print(string.format("Targeting ID: %s | InGang: %s", tostring(entity), tostring(inGang)))

            return not isGuard and not isDealer and inGang
        end,
    },
    {
        type = "client",
        event = "jh-gangwars:client:StopFollowing",
        icon = "fas fa-hand-paper",
        label = "Stop Following",
        canInteract = function(entity)
            return Entity(entity).state.isBodyguard
        end,
    },
    {
        type = "client",
        event = "jh-gangwars:client:SetCorner",
        icon = "fas fa-street-view",
        label = "Set Corner",
        canInteract = function(entity)
            return Entity(entity).state.isBodyguard
        end,
    },
    {
        type = "client",
        event = "jh-gangwars:client:SupplyDealer",
        icon = "fas fa-box",
        label = "Supply Drugs",
        canInteract = function(entity)
            return Entity(entity).state.isDealer
        end,
    },
    {
        type = "client",
        icon = "fas fa-hand-holding-usd",
        label = "Collect Profits",
        action = function(entity)
            local dealerID = Entity(entity).state.dealerID -- This pulls the ID from the ped
            
            print("DEBUG: Clicking Collect. Ped ID is: " .. tostring(dealerID))
            
            if dealerID then
                TriggerServerEvent('jh-gangwars:server:CollectMoney', dealerID)
            else
                QBCore.Functions.Notify("This dealer's brain is not synced. Set Corner again.", "error")
            end
        end
    },
    {
        type = "client",
        icon = "fas fa-hands",
        label = "Search Body",
        action = function(entity)
            local state = Entity(entity).state
            -- Check which system this ped belongs to
            if state.dealerID then
                -- Our custom jh-gangwars logic
                TriggerServerEvent('jh-gangwars:server:LootStolenItems', state.dealerID)
            elseif state.isCornerSelling then
                -- Standard qb-drugs compatibility logic
                TriggerServerEvent('jh-gangwars:server:LootQBCorner', NetworkGetNetworkIdFromEntity(entity))
            else
                -- Generic search for non-drug peds
                QBCore.Functions.Notify("Nothing of interest found.", "error")
            end
        end,
        canInteract = function(entity)
            -- Only show if dead/down AND is a known drug ped
            local state = Entity(entity).state
            local isDrugPed = state.dealerID or state.isCornerSelling
            return (IsEntityDead(entity) or IsPedRagdoll(entity)) and isDrugPed
        end,
    },
    {
    type = "client",
    event = "jh-gangwars:client:OpenDealerShop",
    icon = "fas fa-pills",
    label = "Buy Drugs",
    canInteract = function(entity)
        -- Fallback: If state is true OR the ped has the dealer scenario active
        return Entity(entity).state.isSelling or IsEntityPlayingAnim(entity, "WORLD_HUMAN_STAND_MOBILE", "base", 3)
    end
},
{
    type = "client",
    icon = "fas fa-clipboard-list",
    label = "Check Inventory",
    action = function(entity)
        local dealerID = Entity(entity).state.dealerID
        if dealerID then
            TriggerEvent('jh-gangwars:client:ViewDetailedStock', dealerID)
        else
            QBCore.Functions.Notify("No data found for this ped.", "error")
        end
    end
},
}, distance = 2.0 })

local function GetAvailableVehicleSeat(vehicle)
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for i = 0, maxSeats - 1 do
        if IsVehicleSeatFree(vehicle, i) then
            return i
        end
    end
    return nil
end

local function GetBodyguardThreat(playerPed)
    local aimed, target = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if aimed and target and IsEntityAPed(target) and not IsEntityDead(target) and GetPedGroupIndex(target) ~= GetPedGroupIndex(playerPed) then
        return target
    end

    for _, hostile in ipairs(GetGamePool('CPed')) do
        if hostile ~= playerPed and not IsEntityDead(hostile) and GetPedGroupIndex(hostile) ~= GetPedGroupIndex(playerPed) then
            if IsPedInCombat(hostile, playerPed) or HasEntityBeenDamagedByEntity(playerPed, hostile, true) then
                return hostile
            end
        end
    end

    return nil
end

local function EngageBodyguardCombat(ped, target, playerPed)
    if not DoesEntityExist(ped) or not DoesEntityExist(target) or IsEntityDead(ped) then return end

    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 5, true)
    SetPedFleeAttributes(ped, 0, false)

    if GetSelectedPedWeapon(ped) == GetHashKey("WEAPON_UNARMED") then
        GiveWeaponToPed(ped, GetHashKey("WEAPON_PISTOL"), 120, false, true)
    end

    if IsPedInAnyVehicle(ped, false) and IsPedInAnyVehicle(playerPed, false) then
        if GetVehiclePedIsIn(ped, false) == GetVehiclePedIsIn(playerPed, false) then
            SetCurrentPedWeapon(ped, GetHashKey("WEAPON_PISTOL"), true)
            TaskVehicleShootAtPed(ped, target, 20.0)
            return
        end
    end

    CreateThread(function()
        Wait(500)

        if DoesEntityExist(ped) and DoesEntityExist(target) and not IsEntityDead(ped) then
            FreezeEntityPosition(ped, false)
            TaskCombatPed(ped, target, 0, 16)
        end
    end)
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every second
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local threat = GetBodyguardThreat(playerPed)

        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)

            for _, ped in ipairs(GetGamePool('CPed')) do
                local state = Entity(ped).state

                if IsEntityDead(ped) and state.isBodyguard then
                    state:set('isBodyguard', false, true)
                    state:set('isDealer', false, true)
                    state:set('isFollowing', false, true)
                end

                if state.isBodyguard and not IsPedInAnyVehicle(ped, false) then
                    local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(ped))

                    if dist < 20.0 then
                        local seat = GetAvailableVehicleSeat(vehicle)
                        if seat then
                            TaskEnterVehicle(ped, vehicle, -1, seat, 1.5, 1, 0)
                        end
                    end
                end

                if state.isBodyguard and threat then
                    EngageBodyguardCombat(ped, threat, playerPed)
                end
            end
        else
            for _, ped in ipairs(GetGamePool('CPed')) do
                local state = Entity(ped).state

                if IsEntityDead(ped) and state.isBodyguard then
                    state:set('isBodyguard', false, true)
                    state:set('isDealer', false, true)
                    state:set('isFollowing', false, true)
                end

                if state.isBodyguard and IsPedInAnyVehicle(ped, false) then
                    TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
                    TaskFollowToOffsetOfEntity(ped, playerPed, 0.0, -1.5, 0.0, 1.0, -1, 10.0, true)
                end

                if state.isFollowing then
                    local dist = #(playerCoords - GetEntityCoords(ped))

                    if IsPedSprinting(playerPed) then
                        TaskFollowToOffsetOfEntity(ped, playerPed, 0.5, -1.0, 0.0, 6.0, -1, 5.0, true)
                    elseif IsPedRunning(playerPed) then
                        TaskFollowToOffsetOfEntity(ped, playerPed, 0.5, -1.0, 0.0, 4.0, -1, 5.0, true)
                    elseif dist > 12.0 then
                        TaskGoToEntity(ped, playerPed, -1, 1.0, 4.0, 1073741824, 0)
                    end

                    if threat then
                        EngageBodyguardCombat(ped, threat, playerPed)
                    end
                end
            end
        end
    end
end)
