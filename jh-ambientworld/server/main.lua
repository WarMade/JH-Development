local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('jh-ambientworld:server:PoliceAlert', function(title, coords)
    if Config.UseDispatch then
        exports['ps-dispatch']:CustomAlert({
            coords = coords,
            message = title,
            dispatchCode = "10-13",
            description = "Automated AI Detection: " .. title,
            radius = 0, sprite = 648, color = 1, scale = 1.0, length = 3000,
        })
    end
end)
