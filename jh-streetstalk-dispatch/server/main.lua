-- Dispatch police units based on zone heat
RegisterNetEvent('jh-streetstalk:server:checkAreaHeat', function(zoneName)
    local zoneHeat = GetZoneHeat(zoneName) -- Replace with your existing heat variable

    if zoneHeat > 50 then
        local src = source
        local ped = GetPlayerPed(src)
        if ped and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            -- Dispatch 1 or 2 units based on Heat level
            TriggerClientEvent('jh-streetstalk:spawnResponse', src, coords, 'lspd')
            if zoneHeat > 80 then
                -- Dispatch a second unit for very high heat
                TriggerClientEvent('jh-streetstalk:spawnResponse', src, coords, 'bcso')
            end
        end
    end
end)
local ZoneHeat = {}

local function NormalizeZoneName(zoneName)
    zoneName = tostring(zoneName or '')
    if zoneName == '' then return '' end
    return string.upper(zoneName)
end

local function SyncZoneHeat(zoneName)
    GlobalState.zoneHeat = ZoneHeat
    GlobalState['zoneHeat:' .. zoneName] = ZoneHeat[zoneName]

    if Config.Zones and Config.Zones[zoneName] then
        Config.Zones[zoneName].heat = ZoneHeat[zoneName]
    end
end

function IncreaseHeat(zoneName, amount)
    zoneName = NormalizeZoneName(zoneName)
    amount = tonumber(amount) or 0
    if zoneName == '' or amount == 0 then return end

    ZoneHeat[zoneName] = (ZoneHeat[zoneName] or 0) + amount
    SyncZoneHeat(zoneName)

    if ZoneHeat[zoneName] > 80 then
        -- Logic to trigger a patrol
    end
end
exports('IncreaseHeat', IncreaseHeat)

-- STANDALONE EXPORT
-- Usage: exports['jh-streetstalk-dispatch']:AddZoneHeat('davis', 10)
function AddZoneHeat(zoneName, amount)
    zoneName = NormalizeZoneName(zoneName)
    amount = tonumber(amount) or 0
    if zoneName == '' or amount == 0 then return end

    ZoneHeat[zoneName] = (ZoneHeat[zoneName] or 0) + amount
    SyncZoneHeat(zoneName)

    print(('[jh-dispatch] Heat updated for %s by %s (total: %s)'):format(zoneName, amount, ZoneHeat[zoneName]))
end
exports('AddZoneHeat', AddZoneHeat)

RegisterNetEvent('jh-streetstalk-dispatch:server:addZoneHeat', function(zoneName, amount)
    AddZoneHeat(zoneName, amount)
end)

RegisterCommand('jh_testdispatch', function(src)
    if src <= 0 then
        print('[jh-dispatch] Use /jh_testdispatch in-game to confirm police spawning.')
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then
        print(('[jh-dispatch] Could not find player ped for %s'):format(src))
        return
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerClientEvent('jh-streetstalk-dispatch:client:spawnAI', src, {
        ped = GetHashKey('s_m_y_cop_01'),
        vehicle = GetHashKey('police'),
        spawn = vector4(coords.x + 18.0, coords.y + 18.0, coords.z, heading),
        target = coords,
        name = 'LSPD',
        district = 'LSPD'
    })

    print(('[jh-dispatch] Manual police spawn test sent to player %s'):format(src))
end, false)

-- Reset heat periodically
CreateThread(function()
    while true do
        Wait(300000) -- Every 5 mins
        for zoneName, heat in pairs(ZoneHeat) do
            if heat > 0 then
                ZoneHeat[zoneName] = math.max(heat - 5, 0)
                SyncZoneHeat(zoneName)
            end
        end
    end
end)

RegisterNetEvent('jh-streetstalk-dispatch:server:requestPatrol', function(zoneName, playerCoords)
    local src = source
    
    -- Standalone Jurisdiction Logic
    local district = "LSPD"
    if playerCoords and playerCoords.y and playerCoords.y > 2000 then district = "BCSO" end
    
    local data = Config.Districts[district]
    local pedModel = data.peds[math.random(#data.peds)]
    local vehicleModel = data.vehicles[math.random(#data.vehicles)]

    TriggerClientEvent('jh-streetstalk-dispatch:client:spawnAI', src, {
        ped = pedModel,
        vehicle = vehicleModel,
        spawn = data.spawnPoints[1],
        target = playerCoords,
        name = data.name,
        district = district
    })
end)

RegisterNetEvent('jh-streetstalk-dispatch:server:requestTrooperInterception', function(playerCoords, playerHeading)
    local src = source
    if not playerCoords or not playerHeading then
        return
    end

    local data = Config.Districts['STATE']
    local pedModel = data.peds[math.random(#data.peds)]
    local vehicleModel = data.vehicles[math.random(#data.vehicles)]
    local rad = math.rad(playerHeading)
    local spawnAhead = vector3(
        playerCoords.x + math.sin(rad) * 500.0,
        playerCoords.y + math.cos(rad) * 500.0,
        playerCoords.z
    )

    TriggerClientEvent('jh-streetstalk-dispatch:client:spawnAI', src, {
        ped = pedModel,
        vehicle = vehicleModel,
        spawn = vector4(spawnAhead.x, spawnAhead.y, spawnAhead.z, playerHeading),
        target = playerCoords,
        name = "State Trooper",
        district = 'STATE'
    })
end)

UnpaidTickets = {}

local function GetCitizenId(src)
    if Framework and Framework.Functions and Framework.Functions.GetPlayer then
        local Player = Framework.Functions.GetPlayer(src)
        if Player and Player.PlayerData then
            return Player.PlayerData.citizenid
        end
    end

    for _, id in ipairs(GetNumPlayerIdentifiers(src) > 0 and GetPlayerIdentifiers(src) or {}) do
        if id:find('license:') or id:find('steam:') or id:find('xbl:') or id:find('discord:') then
            return id
        end
    end

    return tostring(src)
end

RegisterNetEvent('jh-streetstalk:server:issueTicket', function(district, amountOrType)
    local src = source
    local citizenid = GetCitizenId(src)
    local amount = tonumber(amountOrType)
    local violationType = nil

    if not amount then
        violationType = tostring(amountOrType)
        if Config.Fines and Config.Fines[violationType] then
            amount = Config.Fines[violationType].amount
        end
    end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    if not UnpaidTickets[citizenid] then
        UnpaidTickets[citizenid] = {}
    end

    table.insert(UnpaidTickets[citizenid], {
        amount = amount,
        station = district,
        violation = violationType
    })

    TriggerClientEvent('jh-streetstalk-dispatch:client:updateTicketCount', src, #UnpaidTickets[citizenid])
    print(('[jh-dispatch] Ticket issued to %s: $%s at %s'):format(citizenid, amount, district))
end)

-- Payment logic (Triggered by a qb-target at the station)
RegisterNetEvent('jh-streetstalk:server:payTicket', function(ticketIndex)
    local src = source
    local citizenid = GetCitizenId(src)
    local playerTickets = UnpaidTickets[citizenid]
    if not playerTickets or not playerTickets[ticketIndex] then
        return
    end

    local ticket = playerTickets[ticketIndex]
    local Player = nil
    if Framework and Framework.Functions and Framework.Functions.GetPlayer then
        Player = Framework.Functions.GetPlayer(src)
    end

    if Player and Player.Functions and Player.Functions.RemoveMoney then
        local success = Player.Functions.RemoveMoney('bank', ticket.amount, 'ticket-payment')
        if success then
            table.remove(playerTickets, ticketIndex)
            TriggerClientEvent('QBCore:Notify', src, 'Ticket paid. Your record is clear.', 'success')
            return
        end
    elseif Player and Player.PlayerData and Player.PlayerData.money and Player.PlayerData.money.bank then
        if Player.PlayerData.money.bank >= ticket.amount then
            Player.PlayerData.money.bank = Player.PlayerData.money.bank - ticket.amount
            table.remove(playerTickets, ticketIndex)
            TriggerClientEvent('QBCore:Notify', src, 'Ticket paid. Your record is clear.', 'success')
            return
        end
    end

    TriggerClientEvent('QBCore:Notify', src, "You don't have enough money!", 'error')
end)