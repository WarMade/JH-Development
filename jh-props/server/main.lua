local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('jh-props:server:ProcessAction', function(netId, actionType, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local entity = NetworkGetEntityFromNetworkId(netId)

    if not Player or not DoesEntityExist(entity) then
        return
    end

    if actionType == "pickup" then
        local itemInfo = QBCore.Shared.Items[data]
        if not itemInfo then
            TriggerClientEvent('QBCore:Notify', src, "This prop does not match a valid QB inventory item.", "error")
            return
        end

        if Player.Functions.AddItem(data, 1) then
            TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "add")
            DeleteEntity(entity)
        else
            TriggerClientEvent('QBCore:Notify', src, "Your inventory is too full or heavy!", "error")
        end

    elseif actionType == "search" then
        local possibleLoot = Config.LootTable[data] or {}
        local validLoot = {}

        for _, itemName in ipairs(possibleLoot) do
            if QBCore.Shared.Items[itemName] then
                validLoot[#validLoot + 1] = itemName
            end
        end

        if #validLoot == 0 then
            TriggerClientEvent('QBCore:Notify', src, "Nothing useful was found.", "error")
            return
        end

        local randomItem = validLoot[math.random(1, #validLoot)]
        local amount = math.random(1, 3)
        local itemInfo = QBCore.Shared.Items[randomItem]

        if Player.Functions.AddItem(randomItem, amount) then
            TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "add")

            if Config.DeleteOnSearch then
                DeleteEntity(entity)
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "Your inventory is too full or heavy!", "error")
        end
    end
end)