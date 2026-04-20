local QBCore = exports['qb-core']:GetCoreObject()
local dumpsterCache = {}
local activeSearches = {}
local lastSellAttempt = {}
local SearchedDumpsters = {} -- This table resets every time the server restarts
local GlobalJackpotChance = 1 -- 1% chance for a moneybag globally

local JunkItems = {
    "old_shoe", "empty_can", "plastic_bag", "broken_bottle",
    "used_bandage", "old_newspaper", "rusty_nail", "torn_rag"
}

local function GetRandomJunk()
    return JunkItems[math.random(1, #JunkItems)]
end

local function GetLootTableByArea(playerCoords)
    for zoneName, data in pairs(Config.AreaLoot) do
        if data.coords and #(playerCoords - data.coords) < data.radius then return data.loot, data.label end
    end
    return Config.AreaLoot['Default'].loot, "City Streets"
end

local function GetMysqlGlobal()
    return rawget(_G, 'MySQL')
end

local function LogSecurityEvent(src, reason, details)
    local playerName = GetPlayerName(src) or 'unknown'
    local license = 'unknown'

    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(identifier, 1, 8) == 'license:' then
            license = identifier
            break
        end
    end

    print(('[jh-dumpster][SECURITY] %s | src=%s | name=%s | license=%s | %s'):format(
        tostring(reason or 'Unknown event'),
        tostring(src),
        tostring(playerName),
        tostring(license),
        tostring(details or 'no extra details')
    ))
end

local function FetchScavengeProgress(citizenid)
    local mysqlGlobal = GetMysqlGlobal()

    if mysqlGlobal and mysqlGlobal.Sync and mysqlGlobal.Sync.fetchAll then
        local result = mysqlGlobal.Sync.fetchAll('SELECT scavenge_xp, scavenge_level FROM players WHERE citizenid = ?', { citizenid })
        if result and result[1] then
            return tonumber(result[1].scavenge_xp) or 0, tonumber(result[1].scavenge_level) or 1
        end
    elseif mysqlGlobal and mysqlGlobal.Sync and mysqlGlobal.Sync.fetchScalar then
        local xp = mysqlGlobal.Sync.fetchScalar('SELECT scavenge_xp FROM players WHERE citizenid = ?', { citizenid }) or 0
        local level = mysqlGlobal.Sync.fetchScalar('SELECT scavenge_level FROM players WHERE citizenid = ?', { citizenid }) or 1
        return tonumber(xp) or 0, tonumber(level) or 1
    end

    if GetResourceState('oxmysql') == 'started' then
        local result = exports.oxmysql:singleSync('SELECT scavenge_xp, scavenge_level FROM players WHERE citizenid = ?', { citizenid })
        if result then
            return tonumber(result.scavenge_xp) or 0, tonumber(result.scavenge_level) or 1
        end
    end

    return 0, 1
end

local function SaveScavengeProgress(citizenid, newXP, newLevel)
    local mysqlGlobal = GetMysqlGlobal()

    if mysqlGlobal and mysqlGlobal.Async and mysqlGlobal.Async.execute then
        mysqlGlobal.Async.execute('UPDATE players SET scavenge_xp = ?, scavenge_level = ? WHERE citizenid = ?', { newXP, newLevel, citizenid })
        return
    end

    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:update('UPDATE players SET scavenge_xp = ?, scavenge_level = ? WHERE citizenid = ?', { newXP, newLevel, citizenid })
    end
end

local function NormalizeCoords(coords)
    if type(coords) == 'vector3' or type(coords) == 'vector4' then
        return vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    end

    if type(coords) == 'table' and coords.x and coords.y and coords.z then
        return vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    end

    return nil
end

local function CalculateLevelFromXP(xp)
    local maxLevel = (Config.Experience and Config.Experience.MaxLevel) or 10
    return math.min(maxLevel, math.max(1, math.floor((tonumber(xp) or 0) / 100) + 1))
end

local function IsAllowedDumpsterModel(model)
    if not model or model == 0 then return false end

    for _, allowedModel in ipairs(Config.DumpsterModels or {}) do
        local allowedHash

        if type(allowedModel) == 'number' then
            allowedHash = allowedModel
        else
            allowedHash = GetHashKey(tostring(allowedModel))
        end

        if model == allowedHash then
            return true
        end
    end

    return false
end

local function GetDumpsterEntity(netId)
    local numericNetId = tonumber(netId)
    if not numericNetId then return nil, nil end

    local entity = NetworkGetEntityFromNetworkId(numericNetId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil, nil
    end

    return entity, numericNetId
end

local currentSilasLocation = nil

local function BroadcastScavengerLocation(target)
    if currentSilasLocation then
        TriggerClientEvent('jh-dumpsterdiving:client:updateScavengerLoc', target or -1, currentSilasLocation)
    end
end

local function PickNewSilasLocation()
    if not Config.Scavenger or not Config.Scavenger.Locations or #Config.Scavenger.Locations == 0 then
        return
    end

    currentSilasLocation = Config.Scavenger.Locations[math.random(1, #Config.Scavenger.Locations)]
    BroadcastScavengerLocation()
    print("^3[JH-DUMPSTER]^7 Silas has moved to a new shady spot.")
end

local mysqlGlobal = GetMysqlGlobal()
if mysqlGlobal and mysqlGlobal.ready then
    mysqlGlobal.ready(function()
        PickNewSilasLocation()
    end)
else
    CreateThread(function()
        Wait(500)
        PickNewSilasLocation()
    end)
end

CreateThread(function()
    while true do
        Wait(((Config.Scavenger and Config.Scavenger.RelocateMinutes) or 30) * 60000)
        PickNewSilasLocation()
    end
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    BroadcastScavengerLocation(src)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(1000)
        BroadcastScavengerLocation()
    end)
end)

-- XP DATABASE SYSTEM
QBCore.Functions.CreateCallback('jh-dumpster:server:getXP', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local xp, level = FetchScavengeProgress(Player.PlayerData.citizenid)
        cb({ xp = xp, level = level })
    else
        cb({ xp = 0, level = 1 })
    end
end)

QBCore.Functions.CreateCallback('jh-dumpster:server:checkDumpster', function(source, cb, netId)
    if SearchedDumpsters[netId] then
        cb(false) -- Already searched
    else
        cb(true)  -- Good to go
    end
end)

RegisterNetEvent('jh-dumpster:server:saveXP', function(xp)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local currentXP = FetchScavengeProgress(Player.PlayerData.citizenid)
    local safeXP = math.max(0, math.floor(tonumber(xp) or currentXP or 0))
    local maxGain = ((Config.Experience and Config.Experience.XPPerDive) or 15) * 5

    if safeXP > ((currentXP or 0) + maxGain) then
        LogSecurityEvent(src, 'Blocked saveXP spike', ('client=%s current=%s'):format(tostring(safeXP), tostring(currentXP)))
        safeXP = (currentXP or 0) + ((Config.Experience and Config.Experience.XPPerDive) or 15)
    end

    SaveScavengeProgress(Player.PlayerData.citizenid, safeXP, CalculateLevelFromXP(safeXP))
end)

RegisterNetEvent('jh-dumpster:server:beginSearch', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    local dumpsterEntity, numericNetId = GetDumpsterEntity(netId)
    if not dumpsterEntity then
        LogSecurityEvent(src, 'Rejected beginSearch', 'invalid or missing dumpster netId')
        return
    end

    if not IsAllowedDumpsterModel(GetEntityModel(dumpsterEntity)) then
        LogSecurityEvent(src, 'Rejected beginSearch', 'entity model not allowed for scavenging')
        return
    end

    local playerCoords = GetEntityCoords(ped)
    local dumpsterCoords = GetEntityCoords(dumpsterEntity)
    local distanceToDumpster = #(playerCoords - dumpsterCoords)

    if distanceToDumpster > 4.0 then
        LogSecurityEvent(src, 'Rejected beginSearch', ('player too far from dumpster: %.2f'):format(distanceToDumpster))
        return
    end

    if dumpsterCache[numericNetId] and dumpsterCache[numericNetId] > os.time() then
        LogSecurityEvent(src, 'Rejected beginSearch', 'attempted to search a dumpster still on cooldown')
        return
    end

    activeSearches[src] = {
        netId = numericNetId,
        startedAt = GetGameTimer(),
        expiresAt = GetGameTimer() + math.max((Config.SearchTime or 7000) + 15000, 10000)
    }
end)

RegisterNetEvent('jh-dumpster:server:processProLoot', function(netId, clientCoords, playerLevel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Check if this specific dumpster has already been searched
    if SearchedDumpsters[netId] then
        TriggerClientEvent('QBCore:Notify', src, "This dumpster has already been picked clean.", "error")
        return
    end

    -- Mark it as searched immediately to prevent double-looting during the process
    SearchedDumpsters[netId] = true

    -- [Insert your existing Loot Logic here]
    -- Example:
    local item = "plastic"
    Player.Functions.AddItem(item, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "add")
    TriggerClientEvent('QBCore:Notify', src, "You found some scrap.", "success")
end)

-- LOOT & PHONE CONTACT LOGIC
local function AddSilasContactToPhone(citizenid, contactName, contactNumber, cb)
    local mysqlGlobal = rawget(_G, 'MySQL')

    if mysqlGlobal and mysqlGlobal.Async then
        mysqlGlobal.Async.fetchAll('SELECT * FROM phone_contacts WHERE citizenid = ? AND number = ?', {
            citizenid,
            contactNumber
        }, function(result)
            if not result[1] then
                mysqlGlobal.Async.insert('INSERT INTO phone_contacts (citizenid, name, number) VALUES (?, ?, ?)', {
                    citizenid,
                    contactName,
                    contactNumber
                })
                cb(true)
            else
                cb(false)
            end
        end)
        return
    end

    if GetResourceState('oxmysql') == 'started' then
        local result = exports.oxmysql:querySync('SELECT * FROM phone_contacts WHERE citizenid = ? AND number = ?', {
            citizenid,
            contactNumber
        })

        if not result or not result[1] then
            exports.oxmysql:insertSync('INSERT INTO phone_contacts (citizenid, name, number) VALUES (?, ?, ?)', {
                citizenid,
                contactName,
                contactNumber
            })
            cb(true)
        else
            cb(false)
        end
        return
    end

    cb(nil)
end

RegisterNetEvent('jh-dumpster:server:addSilasContact', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local contactName = Config.Scavenger.ContactName
    local contactNumber = Config.Scavenger.Phone

    AddSilasContactToPhone(citizenid, contactName, contactNumber, function(added)
        if added == true then
            SetTimeout(5000, function()
                local mailData = {
                    sender = "Old Man Silas",
                    subject = "The Junk Trade",
                    message = "Listen kid, I added my burner to your phone. If you find high-end tech or shiny jewelry in those bins, you bring 'em to me. I pay better than those suit-and-tie pawn shops. <br><br>I move around a lot to keep the cops off my back. Just look for the package icon on your GPS.<br><br>- Silas",
                    button = {}
                }

                TriggerClientEvent('qb-phone:client:GetRelevantMail', src, mailData)
                TriggerClientEvent('QBCore:Notify', src, "You received an encrypted email", "primary")
            end)
        elseif added == nil then
            TriggerClientEvent('QBCore:Notify', src, "Silas gives you his burner, but no phone database was found.", "error")
        end
    end)
end)

-- SELL LOGIC (HARDENED)
RegisterNetEvent('jh-dumpster:server:sellScavenge', function(itemsToSell)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = GetGameTimer()
    if lastSellAttempt[src] and (now - lastSellAttempt[src]) < 1500 then
        LogSecurityEvent(src, 'Rejected sellScavenge', 'sell spam detected')
        return
    end
    lastSellAttempt[src] = now

    local totalWorth = 0
    local totalWeight = QBCore.Player.GetTotalWeight(Player.PlayerData.items)
    local maxWeight = QBCore.Config.Player.MaxWeight
    local processedItems = {}

    if totalWeight >= maxWeight then
        TriggerClientEvent('QBCore:Notify', src, "Your pockets are too full to carry Silas's payment!", "error")
        return
    end

    for _, data in ipairs(itemsToSell or {}) do
        if type(data) ~= 'table' or type(data.item) ~= 'string' then
            LogSecurityEvent(src, 'Rejected sale entry', 'invalid sale payload structure')
        elseif processedItems[data.item] then
            LogSecurityEvent(src, 'Rejected sale entry', 'duplicate item entry detected: ' .. data.item)
        else
            processedItems[data.item] = true

            local serverPrice = Config.Scavenger.BuyRates[data.item]
            local itemData = serverPrice and Player.Functions.GetItemByName(data.item)

            if not serverPrice then
                LogSecurityEvent(src, 'Rejected sale entry', 'attempted to sell non-whitelisted item: ' .. data.item)
            else
                if tonumber(data.price) and tonumber(data.price) ~= tonumber(serverPrice) then
                    LogSecurityEvent(src, 'Blocked client price mismatch', ('%s | client=%s | server=%s'):format(data.item, tostring(data.price), tostring(serverPrice)))
                end

                if itemData and itemData.amount > 0 then
                    if Player.Functions.RemoveItem(data.item, itemData.amount) then
                        totalWorth = totalWorth + (serverPrice * itemData.amount)
                        if QBCore.Shared.Items[data.item] then
                            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[data.item], "remove")
                        end
                    end
                end
            end
        end
    end

    if totalWorth > 0 then
        local info = { worth = totalWorth }
        if Player.Functions.AddItem('markedbills', 1, false, info) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['markedbills'], "add")
            TriggerClientEvent('QBCore:Notify', src, "Silas: 'Good haul. Here's your cut.'", "success")
        end
    end
end)

RegisterNetEvent('jh-dumpster:server:crackMoneyBag', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local item = Player.Functions.GetItemByName('moneybag')
    if not item or item.amount < 1 then
        TriggerClientEvent('QBCore:Notify', src, "You don't have a money bag, kid.", "error")
        return
    end

    local xp, savedLevel = FetchScavengeProgress(Player.PlayerData.citizenid)
    local level = math.max(1, tonumber(savedLevel) or CalculateLevelFromXP(xp))
    if level > 10 then level = 10 end

    local minAmount = 100 * level
    local maxAmount = 1000 * level
    local randomPayout = math.random(minAmount, maxAmount)

    if Player.Functions.RemoveItem('moneybag', 1) then
        Player.Functions.AddMoney('cash', randomPayout)

        if QBCore.Shared.Items['moneybag'] then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['moneybag'], "remove")
        end

        TriggerClientEvent('QBCore:Notify', src, "Silas cracked the bag and found $" .. randomPayout, "success")
    end
end)

AddEventHandler('playerDropped', function()
    activeSearches[source] = nil
    lastSellAttempt[source] = nil
end)
