local QBCore = exports['qb-core']:GetCoreObject()
local TurfState = {}
local ActiveCaptures = {}
local LootCooldowns = {}

local function FindPriorityDrugItem(Player, excludedSlots)
    local items = (Player.PlayerData and Player.PlayerData.items) or {}
    local priorityList = (Config.DeathLoot and Config.DeathLoot.DrugPriority) or {}

    for _, itemName in ipairs(priorityList) do
        for slot, item in pairs(items) do
            if item and item.name == itemName and (item.amount or 0) > 0 and not excludedSlots[slot] then
                return slot, item
            end
        end
    end

    return nil, nil
end

local function StealDeathLoot(Player)
    local cfg = Config.DeathLoot or {}
    local stolen = {}
    local excludedSlots = {}
    local maxStacks = cfg.MaxDrugStacks or 2
    local maxPerStack = cfg.MaxItemsPerStack or 5

    for _ = 1, maxStacks do
        local slot, item = FindPriorityDrugItem(Player, excludedSlots)
        if not slot or not item then
            break
        end

        excludedSlots[slot] = true
        local amount = math.max(1, math.min(item.amount or 1, maxPerStack))
        local removed = Player.Functions.RemoveItem(item.name, amount, slot, 'turf-war-ped-loot')

        if removed then
            table.insert(stolen, string.format('%sx %s', amount, item.label or item.name))
        end
    end

    local cash = ((Player.PlayerData or {}).money or {}).cash or 0
    if cash > 0 then
        local cashPercent = cfg.CashPercent or 0.15
        local cashMin = cfg.CashMin or 50
        local cashMax = cfg.CashMax or 350
        local stolenCash = math.floor(cash * cashPercent)
        stolenCash = math.max(cashMin, stolenCash)
        stolenCash = math.min(cash, math.min(cashMax, stolenCash))

        if stolenCash > 0 then
            Player.Functions.RemoveMoney('cash', stolenCash, 'turf-war-ped-loot')
            table.insert(stolen, string.format('$%s cash', stolenCash))
        end
    end

    return stolen
end

-- Set Initial Owners
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, v in pairs(Config.Territories) do TurfState[v.id] = v.owner end
end)

RegisterNetEvent('turf-war:server:RequestSync', function()
    TriggerClientEvent('turf-war:client:SyncOwners', source, TurfState)
end)

RegisterNetEvent('turf-war:server:CaptureStarted', function(turfId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.gang then return end

    local gangName = Player.PlayerData.gang.name
    if not turfId or not gangName or gangName == "none" then return end
    if TurfState[turfId] == gangName or ActiveCaptures[turfId] then return end

    ActiveCaptures[turfId] = true

    local zone = turfId
    exports['jh-streetstalk-dispatch']:AddZoneHeat(zone, 60)
end)

RegisterNetEvent('turf-war:server:CaptureEnded', function(turfId)
    if turfId then
        ActiveCaptures[turfId] = nil
    end
end)

RegisterNetEvent('turf-war:server:CaptureTurf', function(turfId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.gang then return end

    local newOwner = Player.PlayerData.gang.name
    local gangLabel = Player.PlayerData.gang.label
    if not newOwner or newOwner == "none" then return end

    local oldOwner = TurfState[turfId]
    if oldOwner == newOwner then
        ActiveCaptures[turfId] = nil
        return
    end

    TurfState[turfId] = newOwner
    ActiveCaptures[turfId] = nil

    -- Global Announcement
    local msg = string.format("The %s have painted %s in their colors!", gangLabel, turfId:gsub("_", " "):upper())
    TriggerClientEvent('chat:addMessage', -1, {
        template = '<div style="padding: 0.5vw; margin: 0.5vw; background-color: rgba(0, 0, 0, 0.7); border-left: 4px solid #ff0000; border-radius: 3px;"><b>TURF WAR:</b> {0}</div>',
        args = { msg }
    })

    -- Triggered when a gang successfully takes over a zone
    TriggerClientEvent('jh-turf-war:client:ZoneCaptured', -1, turfId, newOwner)
    TriggerClientEvent('turf-war:client:SyncOwners', -1, TurfState)
end)

RegisterNetEvent('turf-war:server:PedLootPlayer', function(turfId, ownerGang)
    if Config.DeathLoot and Config.DeathLoot.Enabled == false then
        return
    end

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not turfId then return end

    local cooldownSeconds = (Config.DeathLoot and Config.DeathLoot.CooldownSeconds) or 30
    if LootCooldowns[src] and LootCooldowns[src] > os.time() then
        return
    end

    local playerGang = (((Player.PlayerData or {}).gang) or {}).name or 'none'
    local turfOwner = TurfState[turfId] or ownerGang
    if not turfOwner or turfOwner == 'none' or turfOwner == playerGang then
        return
    end

    LootCooldowns[src] = os.time() + cooldownSeconds

    local stolen = StealDeathLoot(Player)
    local turfLabel = turfId:gsub('_', ' '):upper()

    if #stolen > 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Enemy guards looted ' .. table.concat(stolen, ', ') .. ' after you went down in ' .. turfLabel, 'error', 9000)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Enemy guards searched you in ' .. turfLabel .. ', but found nothing worth taking.', 'primary', 7000)
    end
end)
