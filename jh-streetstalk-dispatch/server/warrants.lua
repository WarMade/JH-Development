-- server/warrants.lua

local Warrants = {}

local function GetPlayerBySrc(src)
    if Framework and Framework.Functions and Framework.Functions.GetPlayer then
        return Framework.Functions.GetPlayer(src)
    end
    return nil
end

local function GetCitizenId(src)
    local Player = GetPlayerBySrc(src)
    if Player and Player.PlayerData and Player.PlayerData.citizenid then
        return Player.PlayerData.citizenid
    end

    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:find('license:') or id:find('steam:') or id:find('xbl:') or id:find('discord:') then
            return id
        end
    end

    return tostring(src)
end

-- Function to check if player has an active warrant
exports('HasActiveWarrant', function(citizenid)
    if not UnpaidTickets[citizenid] then return false end
    return #UnpaidTickets[citizenid] >= 3
end)

RegisterNetEvent('jh-streetstalk-dispatch:server:requestTicketCount', function()
    local src = source
    local citizenid = GetCitizenId(src)
    local count = UnpaidTickets[citizenid] and #UnpaidTickets[citizenid] or 0
    TriggerClientEvent('jh-streetstalk-dispatch:client:updateTicketCount', src, count)
end)

RegisterNetEvent('jh-streetstalk:server:payAllTickets', function()
    local src = source
    local citizenid = GetCitizenId(src)
    local tickets = UnpaidTickets[citizenid]
    if not tickets or #tickets == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'No outstanding warrants to pay.', 'error')
        return
    end

    local total = 0
    for _, ticket in ipairs(tickets) do
        total = total + (tonumber(ticket.amount) or 0)
    end

    local Player = GetPlayerBySrc(src)
    if Player and Player.Functions and Player.Functions.RemoveMoney then
        local success = Player.Functions.RemoveMoney('bank', total, 'warrant-payment')
        if success then
            UnpaidTickets[citizenid] = {}
            TriggerClientEvent('QBCore:Notify', src, ('Paid $%s in outstanding warrants.'):format(total), 'success')
            TriggerClientEvent('jh-streetstalk-dispatch:client:updateTicketCount', src, 0)
            return
        end
    elseif Player and Player.PlayerData and Player.PlayerData.money and Player.PlayerData.money.bank then
        if Player.PlayerData.money.bank >= total then
            Player.PlayerData.money.bank = Player.PlayerData.money.bank - total
            UnpaidTickets[citizenid] = {}
            TriggerClientEvent('QBCore:Notify', src, ('Paid $%s in outstanding warrants.'):format(total), 'success')
            TriggerClientEvent('jh-streetstalk-dispatch:client:updateTicketCount', src, 0)
            return
        end
    end

    TriggerClientEvent('QBCore:Notify', src, "You don't have enough money!", 'error')
end)

-- Periodically sync "Flagged" players to the client
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        for _, src in pairs(GetPlayers()) do
            local citizenid = GetCitizenId(src)
            local isWanted = UnpaidTickets[citizenid] and #UnpaidTickets[citizenid] >= 3 or false
            TriggerClientEvent('jh-streetstalk-dispatch:client:syncWarrant', src, isWanted)
        end
    end
end)