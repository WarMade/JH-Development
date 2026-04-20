local QBCore = exports['qb-core']:GetCoreObject()

-- Notify challenger that the request was sent
RegisterNetEvent('jh-moneyraces:server:startRace', function(targetId, amount)
    local src = source
    local Target = QBCore.Functions.GetPlayer(targetId)

    if Target then
        TriggerClientEvent('QBCore:Notify', src, "Challenge sent to ID " .. targetId, "primary")
        TriggerClientEvent('jh-moneyraces:client:receiveChallenge', targetId, src, amount)
    else
        TriggerClientEvent('QBCore:Notify', src, "Player not found", "error")
    end
end)

-- Notify challenger if the race is accepted
RegisterNetEvent('jh-moneyraces:server:acceptRace', function(challengerId, amount, finishLine)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Challenger = QBCore.Functions.GetPlayer(challengerId)

    if Player and Challenger then
        if Player.Functions.GetMoney('cash') >= amount and Challenger.Functions.GetMoney('cash') >= amount then
            Player.Functions.RemoveMoney('cash', amount, "money-race-stake")
            Challenger.Functions.RemoveMoney('cash', amount, "money-race-stake")

            TriggerClientEvent('QBCore:Notify', challengerId, "Challenge Accepted! Get ready.", "success")
            TriggerClientEvent('jh-moneyraces:client:startRace', src, finishLine, amount)
            TriggerClientEvent('jh-moneyraces:client:startRace', challengerId, finishLine, amount)
        else
            TriggerClientEvent('QBCore:Notify', src, "Not enough cash to accept the race.", "error")
        end
    end
end)

-- NEW: Notify challenger if the race is declined/timed out
RegisterNetEvent('jh-moneyraces:server:declineRace', function(challengerId)
    TriggerClientEvent('QBCore:Notify', challengerId, "The player declined or ignored your challenge.", "error")
end)

-- Server side: Deduct the random wager for AI races
RegisterNetEvent('jh-moneyraces:server:startAIRace', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player.Functions.GetMoney('cash') >= amount then
        Player.Functions.RemoveMoney('cash', amount, "ai-race-wager")
        TriggerClientEvent('QBCore:Notify', src, "Wagered $"..amount.." against the local.", "primary")
    else
        -- If they don't have enough, we tell the client to stop the race
        TriggerClientEvent('jh-moneyraces:client:stopRace', src)
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough cash to race this guy!", "error")
    end
end)

-- Server side: Payout for winning against AI
-- Note: You get your stake (amount) + the AI's matching stake (amount)
RegisterNetEvent('jh-moneyraces:server:winRace', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local payout = amount * 2

    if Player then
        Player.Functions.AddMoney('cash', payout, "won-ai-race")
        TriggerClientEvent('QBCore:Notify', src, "You won the sprint! Collected $"..payout, "success")
    end
end)
