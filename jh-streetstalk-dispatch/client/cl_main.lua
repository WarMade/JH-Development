Config.Zones = Config.Zones or {}

-- AT THE TOP OF THE FILE
AddZoneHeat = function(zone, amount)
    zone = string.upper(tostring(zone or ''))
    amount = tonumber(amount) or 0
    if zone == '' then return end

    Config.Zones[zone] = Config.Zones[zone] or { heat = 0 }
    Config.Zones[zone].heat = (tonumber(Config.Zones[zone].heat) or 0) + amount

    TriggerServerEvent('jh-streetstalk-dispatch:server:addZoneHeat', zone, amount)
    print("Export Called: Heat Added")
end

exports('AddZoneHeat', AddZoneHeat)

AddStateBagChangeHandler('zoneHeat', 'global', function(_bagName, _key, value, _unused, _replicated)
    if type(value) ~= 'table' then return end

    for zoneName, heat in pairs(value) do
        Config.Zones[zoneName] = Config.Zones[zoneName] or {}
        Config.Zones[zoneName].heat = heat
    end
end)
