local QBCore = exports['qb-core']:GetCoreObject()

local function IsInBlacklistedZone(playerCoords)
    for _, zone in pairs(Config.BlacklistedZones) do
        local dist = #(playerCoords - zone.coords)
        if dist < zone.radius then return true end
    end
    return false
end

CreateThread(function()
    while true do
        Wait(Config.CheckInterval)
        local coords = GetEntityCoords(PlayerPedId())
        if not IsInBlacklistedZone(coords) then
            if math.random() < Config.EventChance then
                TriggerAmbientEvent(coords)
            end
        end
    end
end)

function TriggerAmbientEvent(coords)
    local eventType = Config.Events[math.random(#Config.Events)]
    -- Add scenario spawning logic here (from previous steps)
end

function Cleanup(entities, time)
    SetTimeout(time, function()
        for _, ent in pairs(entities) do
            if DoesEntityExist(ent) then DeleteEntity(ent) end
        end
    end)
end
