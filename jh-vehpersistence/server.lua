local QBCore = exports['qb-core']:GetCoreObject()

-- Player requests their last 5 vehicles
RegisterNetEvent('vehicle_persistence:requestData')
AddEventHandler('vehicle_persistence:requestData', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    MySQL.query('SELECT plate, model, x, y, z, heading, properties FROM player_persistent_vehicles WHERE citizenid = ? ORDER BY last_updated DESC LIMIT 5', {citizenid}, function(result)
        if result and #result > 0 then
            for _, v in ipairs(result) do
                v.properties = json.decode(v.properties) or {}
            end
            TriggerClientEvent('vehicle_persistence:receiveData', src, result)
        end
    end)
end)

-- Save current last 5
RegisterNetEvent('vehicle_persistence:saveVehicles')
AddEventHandler('vehicle_persistence:saveVehicles', function(vehiclesData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    MySQL.query('DELETE FROM player_persistent_vehicles WHERE citizenid = ?', {citizenid})

    for _, data in ipairs(vehiclesData) do
        MySQL.insert('INSERT INTO player_persistent_vehicles (citizenid, plate, model, x, y, z, heading, properties) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            citizenid,
            data.plate,
            data.model,
            data.x,
            data.y,
            data.z,
            data.heading,
            json.encode(data.properties)
        })
    end
end)

-- Remove single vehicle (when garage deletes it)
RegisterNetEvent('vehicle_persistence:removeVehicle')
AddEventHandler('vehicle_persistence:removeVehicle', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not plate then return end

    MySQL.query('DELETE FROM player_persistent_vehicles WHERE citizenid = ? AND plate = ?', {Player.PlayerData.citizenid, plate})
end)

print('^2[vehicle_persistence_last5] ^7QBCore server-side persistence loaded')