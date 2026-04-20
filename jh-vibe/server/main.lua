local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('jh-vibe:server:CanPay', function(source, cb, price)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.Functions.GetMoney('cash') >= price then
        Player.Functions.RemoveMoney('cash', price)
        cb(true)
    else
        TriggerClientEvent('QBCore:Notify', source, "Not enough cash", "error")
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('jh-vibe:server:CheckPockets', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local cash = Player.PlayerData.money['cash']
    
    -- If they have less than the cheapest service ($50)
    if cash < 50 then
        cb(false)
    else
        cb(true)
    end
end)

-- Handle Cleanup Loot
RegisterNetEvent('jh-vibe:server:CompleteService', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if math.random(1, 100) > 80 then
        Player.Functions.AddItem('wallet', 1)
        TriggerClientEvent('QBCore:Notify', src, "You found a wallet left in the seat.", "success")
    end
end)

-- Rob Player Event
RegisterNetEvent('jh-vibe:server:RobPlayer', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cash = Player.PlayerData.money['cash']
    
    if cash > 0 then
        local robberyAmount = math.random(100, 500)
        if robberyAmount > cash then robberyAmount = cash end
        
        Player.Functions.RemoveMoney('cash', robberyAmount)
        TriggerClientEvent('QBCore:Notify', src, "She made off with $" .. robberyAmount, "error")
    else
        TriggerClientEvent('QBCore:Notify', src, "You're broke! She's pissed!", "error")
    end
end)

-- Police Detection Logic
RegisterNetEvent('jh-vibe:server:CheckForCops', function(coords)
    local src = source
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
            local copPed = GetPlayerPed(v.PlayerData.source)
            if #(coords - GetEntityCoords(copPed)) < 30.0 then
                TriggerClientEvent('jh-vibe:client:PoliceAbort', src)
                TriggerClientEvent('QBCore:Notify', v.PlayerData.source, "You spotted suspicious activity in a vehicle!", "primary")
            end
        end
    end
end)