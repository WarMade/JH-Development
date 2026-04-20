local QBCore = exports['qb-core']:GetCoreObject()
local MySQL = exports['oxmysql']
local npcData = {}
local netIdToDealer = {} -- New fallback tracker

local function SaveNPC(dealerID)
    local data = npcData[dealerID]
    if not data then return end

    local inventoryString = json.encode(data.inventory or {})
    local uncollectedCash = math.floor(data.uncollected or 0)
    local reputation = math.floor(data.reputation or 0)

    MySQL.query('INSERT INTO dealer_data (dealerid, inventory, uncollected, reputation) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE inventory = ?, uncollected = ?, reputation = ?', 
    {
        dealerID,
        inventoryString,
        uncollectedCash,
        reputation,
        inventoryString,
        uncollectedCash,
        reputation
    })
end

local function StartProcessing(dealerID)
    CreateThread(function()
        while npcData[dealerID] and npcData[dealerID].bulk_stock > 0 do
            local npc = npcData[dealerID]
            local itemCfg = Config.Items[npc.item]
            Wait(itemCfg.time)
            if npcData[dealerID] then
                npcData[dealerID].bulk_stock = npcData[dealerID].bulk_stock - 1
                local selected = type(itemCfg.baggy) == "table" and itemCfg.baggy[math.random(1, #itemCfg.baggy)] or itemCfg.baggy
                npcData[dealerID].current_strain = selected
                npcData[dealerID].baggy_stock = npcData[dealerID].baggy_stock + itemCfg.ratio
                SaveNPC(dealerID)
            end
        end
    end)
end

local function StartSaleLoop(dealerID)
    CreateThread(function()
        while npcData[dealerID] do
            Wait(math.random(60000, 120000))
            local npc = npcData[dealerID]
            if npc and npc.baggy_stock > 0 then
                local baggy = type(Config.Items[npc.item].baggy) == "table" and (npc.current_strain or Config.Items[npc.item].baggy[1]) or Config.Items[npc.item].baggy
                local price = math.random(Config.SellItems[baggy].minPrice, Config.SellItems[baggy].maxPrice)
                npc.baggy_stock = npc.baggy_stock - 1
                npc.uncollected = npc.uncollected + price
                SaveNPC(dealerID)
                print("[JH-GANGWARS] Passive sale for ID: "..dealerID)
            end
        end
    end)
end

local function ProcessBrickBreakdown(dealerID)
    local d = npcData[dealerID]
    if not d or not d.inventory then return end

    for itemName, stock in pairs(d.inventory) do
        local itemCfg = Config.Items[itemName]

        if itemCfg and itemCfg.type == 'unit' and (stock.baggy_stock or 0) <= 2 then
            for masterName, masterStock in pairs(d.inventory) do
                local brickCfg = Config.Items[masterName]

                if brickCfg and brickCfg.type == 'brick' and (masterStock.bulk_stock or 0) > 0 then
                    local validChildren = brickCfg.strains or (brickCfg.baggy and { brickCfg.baggy }) or {}
                    local isValidChild = false

                    for _, childName in ipairs(validChildren) do
                        if childName == itemName then
                            isValidChild = true
                            break
                        end
                    end

                    if isValidChild and #validChildren > 0 then
                        local randomChoice = validChildren[math.random(#validChildren)]
                        local ratio = brickCfg.ratio or 10

                        masterStock.bulk_stock = masterStock.bulk_stock - 1
                        d.inventory[randomChoice] = d.inventory[randomChoice] or { baggy_stock = 0, bulk_stock = 0 }
                        d.inventory[randomChoice].baggy_stock = (d.inventory[randomChoice].baggy_stock or 0) + ratio

                        SaveNPC(dealerID)
                        print(string.format("^2[DEALER-PROCESS]^7 %s processed 1x %s into %s", dealerID, masterName, randomChoice))
                        break
                    end
                end
            end
        end
    end
end

local function TriggerPoliceAlert(dealerID)
    -- We need to find the NPC entity to get their coordinates
    -- Since we store netIdToDealer, we can reverse look it up
    local targetNetId = nil
    for netId, id in pairs(netIdToDealer) do
        if id == dealerID then
            targetNetId = netId
            break
        end
    end

    if targetNetId then
        local entity = NetworkGetEntityFromNetworkId(targetNetId)
        if DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)
            local _ = coords
            
            -- EXAMPLE: Using qb-dispatch
            -- TriggerClientEvent('qb-dispatch:client:AddCall', -1, "10-13", "Drug Trafficking", {
            --     {icon = "fas fa-cannabis", info = "Drug Sale in Progress"},
            -- }, {coords.x, coords.y, coords.z}, "police", 3000, 11, 5)

            -- GENERIC QB-CORE ALERT (Works if you have no custom dispatch)
            TriggerClientEvent('QBCore:Notify', -1, Config.DispatchMessage, "police", 10000)
            -- You can also trigger a blip on the map for all cops here
        end
    end
end

-- Helper to calculate the multiplier (e.g., 500 Rep = 1.25x price)
local function GetRepMultiplier(rep)
    local levels = math.floor((rep or 0) / 100)
    return 1.0 + (levels * Config.Reputation.PriceMultiplier)
end

local function NotifyRepMilestone(dealerID, oldRep, newRep)
    local milestones = {100, 250, 500, 750, 1000}
    local targetNetId = nil

    for netId, id in pairs(netIdToDealer) do
        if id == dealerID then
            targetNetId = netId
            break
        end
    end

    if not targetNetId then return end

    local entity = NetworkGetEntityFromNetworkId(targetNetId)
    if not DoesEntityExist(entity) then return end

    local ownerCID = Entity(entity).state.ownerCID
    if not ownerCID then return end

    local Player = QBCore.Functions.GetPlayerByCitizenId(ownerCID)
    if not Player then return end

    for _, milestone in ipairs(milestones) do
        -- Check if we just crossed a threshold
        if oldRep < milestone and newRep >= milestone then
            local msg = string.format("Dealer %s is gaining heat! Street Cred reached %s. Prices have increased.", dealerID, milestone)
            TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, msg, "success", 10000)
            break -- Only notify for one milestone at a time
        end
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.PassiveSaleInterval)
        
        for id, d in pairs(npcData) do
            ProcessBrickBreakdown(id)

            -- Initialize Rep if missing
            d.reputation = d.reputation or 0
            d.inventory = d.inventory or {}
            
            -- Calculate adjusted sale chance based on Rep
            local repBonusChance = math.floor(d.reputation / 100) * Config.Reputation.SaleChanceBonus
            local finalChance = math.min(100, Config.PassiveSaleChance + repBonusChance)

            if math.random(1, 100) <= finalChance then
                local availableStrains = {}
                for itemName, stock in pairs(d.inventory) do
                    if Config.SellItems[itemName] and (stock.baggy_stock or 0) > 0 then
                        table.insert(availableStrains, itemName)
                    end
                end

                if #availableStrains > 0 then
                    local selectedItem = availableStrains[math.random(#availableStrains)]
                    local sellCfg = Config.SellItems[selectedItem]
                    
                    -- Calculate Earnings with Rep Multiplier
                    local multiplier = GetRepMultiplier(d.reputation)
                    local amountSold = math.random(1, 3)
                    if amountSold > d.inventory[selectedItem].baggy_stock then
                        amountSold = d.inventory[selectedItem].baggy_stock
                    end

                    local basePrice = math.random(sellCfg.minPrice, sellCfg.maxPrice)
                    local bossBonus = 1.0

                    local totalEarnings = math.floor((amountSold * basePrice) * multiplier)

                    -- Update Data
                    d.inventory[selectedItem].baggy_stock = d.inventory[selectedItem].baggy_stock - amountSold
                    d.uncollected = (d.uncollected or 0) + totalEarnings

                    local targetNetId = nil
                    for netId, dealerRef in pairs(netIdToDealer) do
                        if dealerRef == id then
                            targetNetId = netId
                            break
                        end
                    end

                    if targetNetId then
                        local entity = NetworkGetEntityFromNetworkId(targetNetId)
                        if DoesEntityExist(entity) then
                            local coords = GetEntityCoords(entity)
                            local zone = GetNameOfZone(coords.x, coords.y, coords.z)
                            local ownerCID = Entity(entity).state.ownerCID
                            local Player = ownerCID and QBCore.Functions.GetPlayerByCitizenId(ownerCID) or nil
                            local playerGang = Player and Player.PlayerData and Player.PlayerData.gang and Player.PlayerData.gang.name or nil
                            bossBonus = tonumber(Entity(entity).state.bossBonus) or 1.0

                            totalEarnings = math.floor(totalEarnings * bossBonus)

                            if zone and GetResourceState('jh-streetstalk-dispatch') == 'started' then
                                local currentOwner = nil
                                if GetResourceState('jh-turf-war') == 'started' then
                                    currentOwner = exports['jh-turf-war']:GetZoneOwner(zone)
                                end

                                if currentOwner == playerGang and playerGang then
                                    -- Ownership Bonus: Less heat, more reputation
                                    exports['jh-streetstalk-dispatch']:AddZoneHeat(zone, 2)
                                    d.reputation = math.min(Config.Reputation.MaxRep, (d.reputation or 0) + 5)
                                else
                                    -- Rival Turf: Massive heat spike and lower reputation gain
                                    exports['jh-streetstalk-dispatch']:AddZoneHeat(zone, 15)
                                    if Player then
                                        TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, "Selling on rival turf is attracting unwanted attention!", "error")
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Gain Rep
                    local oldRep = d.reputation
                    if d.reputation < Config.Reputation.MaxRep then
                        d.reputation = math.min(Config.Reputation.MaxRep, d.reputation + Config.Reputation.BonusPerSale)
                        NotifyRepMilestone(id, oldRep, d.reputation)
                    end

                    -- Chance for Police Alert
                    if math.random(1, 100) <= Config.PoliceCallChance then
                        d.reputation = math.max(0, d.reputation - Config.Reputation.LossOnPolice)
                        TriggerPoliceAlert(id)
                    end

                    SaveNPC(id)
                    print(string.format("^2[PASSIVE-SALE]^7 Dealer %s sold %sx %s for $%s | Rep: %s", id, amountSold, selectedItem, totalEarnings, d.reputation))
                end
            end
        end
    end
end)

RegisterNetEvent('jh-gangwars:server:RequestDealerID', function(netId)
    local src = source
    local dealerID = "DLR_" .. math.random(1111, 9999) .. "_" .. netId
    
    -- Initialize the RAM immediately so it's ready before the player even clicks "Give"
    npcData[dealerID] = {
        inventory = {},
        uncollected = 0,
        reputation = 0
    }
    
    -- Send it back to the client so they can store it on the entity
    TriggerClientEvent('jh-gangwars:client:ReceiveDealerID', src, netId, dealerID)
    
    -- Save a blank entry to SQL just in case
    SaveNPC(dealerID)
end)

RegisterNetEvent('jh-gangwars:server:ActivateCorner', function(netId, dealerID)
    local src = source
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not dealerID or dealerID == "" then return end
    if not DoesEntityExist(entity) then return end

    -- Link the NPC to the Player's Corner Session
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    netIdToDealer[netId] = dealerID

    -- We set metadata/state so standard QB scripts can recognize them
    Entity(entity).state:set('isCornerDealer', true, true)
    Entity(entity).state:set('ownerCID', Player.PlayerData.citizenid, true)
    Entity(entity).state:set('isSelling', true, true)
    Entity(entity).state:set('isCornerSelling', true, true)

    -- Initialize local table with defaults immediately
    npcData[dealerID] = npcData[dealerID] or { inventory = {}, uncollected = 0, reputation = 0 }

    MySQL.single('SELECT inventory, uncollected, reputation FROM dealer_data WHERE dealerid = ?', {dealerID}, function(result)
        if result then
            npcData[dealerID].inventory = result.inventory and json.decode(result.inventory) or {}
            npcData[dealerID].uncollected = result.uncollected or 0
            npcData[dealerID].reputation = result.reputation or 0
            print("^2[DATABASE]^7 Loaded data for Dealer: " .. dealerID)
        else
            SaveNPC(dealerID)
            print("^3[DATABASE]^7 Created new record for Dealer: " .. dealerID)
        end
    end)

    -- Trigger the standard QB Corner initialization
    TriggerClientEvent('qb-drugs:client:setCornerStatus', src, true)
end)

-- Only works if qb-drugs is started before jh-gangwars
local QBDrugsConfig = nil
pcall(function()
    QBDrugsConfig = exports['qb-drugs']:GetConfig()
end)

-- A common way to check valid drugs
local function IsValidDrug(itemName)
    if not itemName then return false end

    -- Check if it's in our custom gangwars sell list
    if Config.SellItems[itemName] then return true end

    -- Check against the naming patterns (weed, coke, etc)
    for _, pattern in ipairs(Config.DrugItemPatterns or {}) do
        if string.find(itemName:lower(), pattern, 1, true) then return true end
    end

    return Config.ManualDrugList and Config.ManualDrugList[itemName] == true or false
end

RegisterNetEvent('jh-gangwars:server:ViewDealerStock', function(dealerID)
    local src = source
    local npc = npcData[dealerID]

    if not npc then
        -- Fallback: Check Database if RAM is empty
        MySQL.single('SELECT * FROM dealer_data WHERE dealerid = ?', {dealerID}, function(result)
            if result then
                local stockMsg = string.format(
                    "Item: %s | Units: %s | Bricks: %s",
                    result.item,
                    result.baggy_stock,
                    result.bulk_stock
                )
                TriggerClientEvent('QBCore:Notify', src, stockMsg, "primary", 7000)
            else
                TriggerClientEvent('QBCore:Notify', src, "No data found for this dealer.", "error")
            end
        end)
        return
    end

    -- Format the message for the player
    local itemLabel = Config.Items[npc.item] and npc.item or "None"
    local msg = string.format(
        "Status: %s<br>Units: %s<br>Bricks: %s<br>Pending Profit: $%s",
        itemLabel,
        npc.baggy_stock,
        npc.bulk_stock,
        math.floor(npc.uncollected or 0)
    )

    TriggerClientEvent('QBCore:Notify', src, msg, "primary", 10000)
end)

RegisterNetEvent('jh-gangwars:server:GiveStock', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local dealerID = data.dealerID or netIdToDealer[data.netId] -- Use the fallback we built

    if not dealerID or not npcData[dealerID] then
        TriggerClientEvent('QBCore:Notify', src, "System Error: NPC not initialized.", "error")
        return
    end

    local itemName = data.item
    local amount = tonumber(data.amount)
    local npc = npcData[dealerID]

    -- Validate that the item is a supported drug item
    if not Config.Items[itemName] or not IsValidDrug(itemName) then
        print("^1[ERROR]^7 Item " .. tostring(itemName) .. " is not a valid drug for gangwars!")
        TriggerClientEvent('QBCore:Notify', src, "That item cannot be supplied to this dealer.", "error")
        return
    end

    -- Attempt to remove from player
    if Player.Functions.RemoveItem(itemName, amount) then
        -- CRITICAL: Initialize the specific drug slot if it's the first time
        if not npc.inventory[itemName] then
            npc.inventory[itemName] = { baggy_stock = 0, bulk_stock = 0 }
        end

        -- Add to NPC inventory based on item type
        if Config.Items[itemName].type == 'brick' then
            npc.inventory[itemName].bulk_stock = npc.inventory[itemName].bulk_stock + amount
        else
            npc.inventory[itemName].baggy_stock = npc.inventory[itemName].baggy_stock + amount
        end

        -- Save to SQL and update client
        SaveNPC(dealerID)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "remove")
        TriggerClientEvent('QBCore:Notify', src, "Successfully supplied " .. amount .. "x " .. itemName, "success")
        
        -- Debug Log (Check your server console)
        print(string.format("^2[SUPPLY]^7 Dealer %s now has %s %s", dealerID, npc.inventory[itemName].baggy_stock, itemName))
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough of this item.", "error")
    end
end)

RegisterNetEvent('jh-gangwars:server:LootDealer', function(dealerID)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local npc = npcData[dealerID]

    if not npc then return end

    local lootList = {}
    local totalCash = math.floor(npc.uncollected or 0)
    local foundSomething = false

    -- 1. Gather all Drugs from Inventory
    for itemName, stock in pairs(npc.inventory) do
        local itemLabel = QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label or itemName
        
        -- Collect Baggies
        if stock.baggy_stock > 0 then
            Player.Functions.AddItem(itemName, stock.baggy_stock)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "add")
            table.insert(lootList, stock.baggy_stock .. "x " .. itemLabel)
            foundSomething = true
        end

        -- Collect Bricks
        if stock.bulk_stock > 0 then
            Player.Functions.AddItem(itemName, stock.bulk_stock)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "add")
            table.insert(lootList, stock.bulk_stock .. "x " .. itemLabel)
            foundSomething = true
        end
    end

    -- 2. Handle Cash
    if totalCash > 0 then
        Player.Functions.AddMoney('cash', totalCash, "looted-dealer")
        table.insert(lootList, "$" .. totalCash .. " Cash")
        foundSomething = true
    end

    -- 3. Send the Summary Notification
    if foundSomething then
        -- Combine the table into a string: "10x Weed, 1x Coke Brick, $500 Cash"
        local summary = table.concat(lootList, ", ")
        TriggerClientEvent('QBCore:Notify', src, "You found: " .. summary, "success", 10000)
        
        -- Wipe the data so it can't be looted again
        npcData[dealerID] = nil
        MySQL.query('DELETE FROM dealer_data WHERE dealerid = ?', {dealerID})
    else
        TriggerClientEvent('QBCore:Notify', src, "The pockets were empty.", "error")
    end
end)

-- HELPER: Is this item a drug?
local function IsItemADrug(itemName)
    if not itemName then return false end

    local discovery = Config.DrugDiscovery or {}
    if discovery.ExplicitWhitelist and discovery.ExplicitWhitelist[itemName] then return true end
    
    local nameLower = itemName:lower()
    for _, pattern in ipairs(discovery.NamePatterns or {}) do
        if string.find(nameLower, pattern, 1, true) then return true end
    end
    return false
end

RegisterNetEvent('jh-gangwars:server:UnifiedSearch', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local entity = NetworkGetEntityFromNetworkId(netId)

    if not Player then return end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    local state = Entity(entity).state
    local lootSummary = {}

    -- A. JH-GANGWARS DEALER RECOVERY (The high-tier stuff)
    if state.dealerID and npcData[state.dealerID] then
        local data = npcData[state.dealerID]
        for itemName, stock in pairs(data.inventory or {}) do
            local total = (stock.baggy_stock or 0) + (stock.bulk_stock or 0)
            if total > 0 then
                if Player.Functions.AddItem(itemName, total) then
                    local itemInfo = QBCore.Shared.Items[itemName]
                    table.insert(lootSummary, total .. "x " .. itemName)
                    if itemInfo then
                        TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "add")
                    end
                end
            end
        end

        -- Reset Dealer
        MySQL.query('DELETE FROM dealer_data WHERE dealerid = ?', {state.dealerID})
        npcData[state.dealerID] = nil
    end

    -- B. QB-DRUGS CORNER COMPATIBILITY (The stolen goods)
    if state.isCornerSelling and Player.PlayerData and Player.PlayerData.items then
        -- Instead of guessing, scan the player's inventory for any drug
        -- they are carrying and give back a stolen portion of that.
        for _, item in pairs(Player.PlayerData.items) do
            if item and item.name and IsItemADrug(item.name) then
                local recoveryAmount = math.random(1, 2)
                if Player.Functions.AddItem(item.name, recoveryAmount) then
                    local itemInfo = QBCore.Shared.Items[item.name]
                    table.insert(lootSummary, recoveryAmount .. "x " .. item.name)
                    if itemInfo then
                        TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "add")
                    end
                end
                break -- Only recover one type of drug per search for balance
            end
        end
    end

    -- C. FINAL NOTIFICATION
    if #lootSummary > 0 then
        TriggerClientEvent('QBCore:Notify', src, "Recovered: " .. table.concat(lootSummary, ", "), "success")
        state:set('dealerID', nil, true)
        state:set('isCornerSelling', false, true)
    else
        TriggerClientEvent('QBCore:Notify', src, "Nothing of value found.", "error")
    end
end)

-- Helper function to find what drug the ped "stole" from the player
local function GetStolenItemFromPed(Player)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then
        return "weed_skunk"
    end

    -- We check the player's inventory for anything matching our drug patterns
    for _, itemData in pairs(Player.PlayerData.items) do
        local itemName = itemData and itemData.name
        if itemName then
            if Config.ManualDrugList and Config.ManualDrugList[itemName] then
                return itemName
            end

            for _, pattern in ipairs(Config.DrugItemPatterns or {}) do
                if string.find(itemName:lower(), pattern, 1, true) then
                    return itemName -- Return the first drug found in player inventory
                end
            end
        end
    end

    -- Fallback to a default if the player somehow has no drugs
    return "weed_skunk"
end

RegisterNetEvent('jh-gangwars:server:LootQBCorner', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local entity = NetworkGetEntityFromNetworkId(netId)
    
    if not Player then return end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if not Entity(entity).state.isCornerSelling then return end

    -- Dynamic Item Selection
    local drugToRecover = GetStolenItemFromPed(Player)
    local recoveryAmount = math.random(1, 3) -- Amount typically stolen in qb-drugs
    local cashRecovered = math.random(100, 500)

    -- 1. Recover the Product
    if Player.Functions.AddItem(drugToRecover, recoveryAmount) then
        local itemInfo = QBCore.Shared.Items[drugToRecover]
        local label = itemInfo and itemInfo.label or drugToRecover
        if itemInfo then
            TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "add")
        end
        TriggerClientEvent('QBCore:Notify', src, "Recovered: " .. recoveryAmount .. "x " .. label, "success")
    end

    -- 2. Recover the Cash
    Player.Functions.AddMoney('cash', cashRecovered, "looted-stolen-goods")
    
    -- Cleanup
    Entity(entity).state:set('isCornerSelling', false, true)
    Entity(entity).state:set('isSelling', false, true)
end)

RegisterNetEvent('jh-gangwars:server:LootStolenItems', function(dealerID)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local data = npcData[dealerID]

    if not Player then return end

    if not data or not data.inventory then 
        TriggerClientEvent('QBCore:Notify', src, "The stash is empty.", "error")
        return 
    end

    local recoveredString = ""
    
    -- This part is already dynamic!
    -- It loops through data.inventory which is populated when you supply the ped.
    for itemName, stock in pairs(data.inventory) do
        local amount = (stock.baggy_stock or 0) + (stock.bulk_stock or 0)
        
        if amount > 0 then
            -- It uses itemName directly from the stored dealer inventory,
            -- so if you gave them coke_brick or meth_baggy, it returns those exact items.
            if Player.Functions.AddItem(itemName, amount) then
                local itemInfo = QBCore.Shared.Items[itemName]
                local label = itemInfo and itemInfo.label or itemName
                recoveredString = recoveredString .. amount .. "x " .. label .. ", "
                if itemInfo then
                    TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "add")
                end
            end
        end
    end

    -- Recover the cash the NPC made while the player was away
    if (data.uncollected or 0) > 0 then
        Player.Functions.AddMoney('cash', math.floor(data.uncollected), "looted-dealer")
        recoveredString = recoveredString .. "$" .. math.floor(data.uncollected) .. " Cash"
    end

    if recoveredString ~= "" then
        TriggerClientEvent('QBCore:Notify', src, "Recovered: " .. recoveredString, "success")
        -- Wipe the dealer from DB so they don't 'respawn' with items
        npcData[dealerID] = nil
        MySQL.query('DELETE FROM dealer_data WHERE dealerid = ?', {dealerID})
    end
end)

-- Helper function to keep code clean
function ExecuteGiveStock(src, Player, data)
    local npc = npcData[data.dealerID]
    local itemName = data.item
    
    if Player.Functions.RemoveItem(itemName, data.amount) then
        if not npc.inventory[itemName] then npc.inventory[itemName] = { baggy_stock = 0, bulk_stock = 0 } end
        
        if Config.Items[itemName].type == 'brick' then
            npc.inventory[itemName].bulk_stock = npc.inventory[itemName].bulk_stock + data.amount
        else
            npc.inventory[itemName].baggy_stock = npc.inventory[itemName].baggy_stock + data.amount
        end
        SaveNPC(data.dealerID)
        TriggerClientEvent('QBCore:Notify', src, "Supplied " .. data.amount .. "x " .. itemName, "success")
    end
end

-- [[ AUTO-RECOVERY LOGIC ]]
-- This checks RAM first, then SQL if the server "forgot" the dealer
local function GetDealerData(dealerID, cb)
    if npcData[dealerID] then
        cb(npcData[dealerID])
    else
        MySQL.single('SELECT * FROM dealer_data WHERE dealerid = ?', {dealerID}, function(result)
            if result then
                npcData[dealerID] = {
                    inventory = result.inventory and json.decode(result.inventory) or {},
                    uncollected = result.uncollected or 0,
                    reputation = result.reputation or 0
                }
                cb(npcData[dealerID])
            else
                cb(nil)
            end
        end)
    end
end

-- THE FAIL-SAFE COLLECTION EVENT
RegisterNetEvent('jh-gangwars:server:CollectMoney', function(dealerData)
    local src = source
    local dealerID = type(dealerData) == 'table' and dealerData.dealerID or dealerData
    local territoryId = type(dealerData) == 'table' and (dealerData.territoryId or dealerData.zoneId) or dealerID
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- 1. SERVER CONSOLE LOG (Check your CMD window for this!)
    print("^3[DEBUG]^7 Collection event reached for ID: " .. tostring(dealerID))

    if not Player then 
        print("^1[ERROR]^7 Player object is nil for source: " .. tostring(src))
        return 
    end

    -- 2. RECOVERY: Check RAM first, then SQL
    local function processCollection(uncollectedAmount)
        local cash = math.floor(uncollectedAmount or 0)

        if cash > 0 then
            -- Fallback: Use 'cash' account instead of 'markedbills' item to prevent crashes
            Player.Functions.AddMoney('cash', cash, "dealer-payout")
            
            -- Reset data locally and in DB
            if npcData[dealerID] then npcData[dealerID].uncollected = 0 end
            MySQL.update('UPDATE dealer_data SET uncollected = 0 WHERE dealerid = ?', {dealerID})

            if territoryId then
                pcall(function()
                    exports['jh-streetstalk-dispatch']:AddZoneHeat(territoryId, 15)
                end)
                TriggerClientEvent('QBCore:Notify', src, "The pickup was successful, but the heat is rising...", "primary")
            end

            -- THE NOTIFICATION (Dual-method to ensure it shows up)
            TriggerClientEvent('QBCore:Notify', src, "Collected $"..cash.." from street sales.", "success")
            print("^2[SUCCESS]^7 Payout of $"..cash.." sent to " .. GetPlayerName(src))
        else
            TriggerClientEvent('QBCore:Notify', src, "This dealer has no cash yet.", "primary")
            print("^3[INFO]^7 Dealer "..dealerID.." has $0.")
        end
    end

    -- 3. LOGIC FLOW
    if npcData[dealerID] then
        processCollection(npcData[dealerID].uncollected)
    else
        -- ID isn't in RAM, try to pull it from the Database
        MySQL.single('SELECT uncollected FROM dealer_data WHERE dealerid = ?', {dealerID}, function(result)
            if result then
                processCollection(result.uncollected)
            else
                TriggerClientEvent('QBCore:Notify', src, "Sync Error: Dealer not found in database.", "error")
                print("^1[ERROR]^7 ID "..dealerID.." does not exist in the dealer_data table.")
            end
        end)
    end
end)

QBCore.Functions.CreateCallback('jh-gangwars:server:GetDealerShopMenu', function(source, cb, dealerID)
    local npc = npcData[dealerID]
    if not npc then cb(nil) return end

    local menu = {
        {
            header = "Dealer Inventory",
            isMenuHeader = true
        }
    }

    -- 1. Check for standard baggies/units in stock
    -- We assume your npcData now tracks multiple items or a main stock
    -- If you want the dealer to sell EVERYTHING they have:
    
    if npc.baggy_stock > 0 then
        local baggy = npc.item -- e.g., 'weed_skunk' or 'oxy'
        local itemLabel = Config.SellItems[baggy] and Config.SellItems[baggy].label or baggy
        local price = math.random(Config.SellItems[baggy].minPrice, Config.SellItems[baggy].maxPrice)

        table.insert(menu, {
            header = "Buy " .. itemLabel,
            txt = "Stock: " .. npc.baggy_stock .. " units | Price: $" .. price,
            params = {
                event = "jh-gangwars:client:BuyDrugInput",
                args = {
                    dealerID = dealerID,
                    item = baggy,
                    price = price,
                    label = itemLabel,
                    maxStock = npc.baggy_stock
                }
            }
        })
    end

    -- 2. Check for Bricks (If you want players to be able to buy whole bricks)
    if npc.bulk_stock > 0 then
        local brickItem = npc.item_brick or "weed_brick"
        local brickPrice = 2500 -- Set a fixed or random price for bricks
        
        table.insert(menu, {
            header = "Buy Wholesale Brick",
            txt = "Stock: " .. npc.bulk_stock .. " bricks | Price: $" .. brickPrice,
            params = {
                event = "jh-gangwars:client:BuyDrugInput",
                args = {
                    dealerID = dealerID,
                    item = brickItem,
                    price = brickPrice,
                    label = "Drug Brick",
                    maxStock = npc.bulk_stock
                }
            }
        })
    end

    if #menu <= 1 then
        TriggerClientEvent('QBCore:Notify', source, "This dealer is completely sold out.", "error")
        cb(nil)
    else
        cb(menu)
    end
end)

QBCore.Functions.CreateCallback('jh-gangwars:server:GetDealerFullStats', function(source, cb, dealerID)
    GetDealerData(dealerID, function(npc)
        if not npc then
            cb(nil)
            return
        end

        cb({
            inventory = npc.inventory or {},
            uncollected = npc.uncollected or 0,
            reputation = npc.reputation or 0
        })
    end)
end)

QBCore.Functions.CreateCallback('jh-gangwars:server:GetDetailedInventory', function(source, cb, dealerID)
    local src = source
    local npc = npcData[dealerID]

    if not npc then 
        cb(nil) 
        return 
    end

    local menu = {
        {
            header = "Dealer Ledger: " .. dealerID,
            isMenuHeader = true,
            icon = "fas fa-file-invoice-dollar"
        }
    }

    local hasStock = false

    -- Iterate through the inventory table we built in V11
    for itemName, stock in pairs(npc.inventory) do
        if stock.baggy_stock > 0 or stock.bulk_stock > 0 then
            hasStock = true
            local itemLabel = Config.SellItems[itemName] and Config.SellItems[itemName].label or itemName
            
            -- Format the description based on what they have
            local stockText = ""
            if stock.baggy_stock > 0 then stockText = stockText .. "Units: " .. stock.baggy_stock .. " | " end
            if stock.bulk_stock > 0 then stockText = stockText .. "Bricks: " .. stock.bulk_stock end

            table.insert(menu, {
                header = itemLabel,
                txt = stockText,
                icon = "fas fa-pills",
                isMenuHeader = true -- This makes it look like an info card rather than a button
            })
        end
    end

    -- Add a footer for the uncollected cash
    table.insert(menu, {
        header = "Total Uncollected Profits",
        txt = "$" .. math.floor(npc.uncollected or 0),
        icon = "fas fa-money-bill-wave",
        isMenuHeader = true
    })

    if not hasStock and (npc.uncollected or 0) <= 0 then
        cb({{ header = "Inventory Empty", txt = "This dealer has no product and no cash.", isMenuHeader = true }})
    else
        cb(menu)
    end
end)

RegisterNetEvent('jh-gangwars:server:DealerEarnedMoney', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local commission = math.random(150, 300)
    Player.Functions.AddMoney('cash', commission, "dealer-commission")
    TriggerClientEvent('QBCore:Notify', src, "Your dealer just moved some weight. +$" .. commission, "success")
end)

RegisterNetEvent('jh-gangwars:server:ExecutePurchase', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local npc = npcData[data.dealerID]

    -- 1. Validate Dealer and Stock
    if not npc or npc.baggy_stock < data.amount then
        TriggerClientEvent('QBCore:Notify', src, "Dealer doesn't have enough stock!", "error")
        return
    end

    -- 2. Calculate Total Cost
    local totalCost = math.floor(data.price * data.amount)

    -- 3. Check Player Money (Cash)
    if Player.Functions.GetMoney('cash') >= totalCost then
        -- Remove money from player
        Player.Functions.RemoveMoney('cash', totalCost, "bought-drugs-from-dealer")
        
        -- Update Dealer Stock & Profits
        npc.baggy_stock = npc.baggy_stock - data.amount
        npc.uncollected = npc.uncollected + totalCost
        
        -- Give Item to player
        Player.Functions.AddItem(data.item, data.amount)
        
        -- Sync to Database
        SaveNPC(data.dealerID)

        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local zone = GetNameOfZone(playerCoords.x, playerCoords.y, playerCoords.z)

        if GetResourceState('jh-streetstalk-dispatch') == 'started' then
            -- Adds 5 heat to the current zone.
            -- Once heat reaches Config.HeatLevelPatrol (40), AI patrols will spawn.
            exports['jh-streetstalk-dispatch']:AddZoneHeat(zone, 5)
        end
        
        -- Notifications
        TriggerClientEvent('QBCore:Notify', src, "Bought " .. data.amount .. "x units for $" .. totalCost, "success")
        print("^2[PURCHASE]^7 " .. GetPlayerName(src) .. " bought from " .. data.dealerID .. ". Profit logged: $" .. totalCost)
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough cash!", "error")
    end
end)

-- Initialize the dealer in RAM
RegisterNetEvent('jh-gangwars:server:InitDealer', function(dealerID)
    if not npcData[dealerID] then
        npcData[dealerID] = {
            item = "weed_brick",
            bulk_stock = 0,
            baggy_stock = 0,
            uncollected = 0,
            current_strain = nil
        }
        print("[JH-GANGWARS] Initialized Dealer Memory: " .. dealerID)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    print("^3[JH-GANGWARS]^7 Saving all dealer data before resource stop...")
    for dealerID, _ in pairs(npcData) do
        SaveNPC(dealerID)
    end
end)