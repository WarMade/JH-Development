-- Standalone Bridge
Framework = nil

-- Compatibility: Detect if QBCore exists, otherwise stay standalone
if GetResourceState('qb-core') == 'started' then
    Framework = exports['qb-core']:GetCoreObject()
end

-- Helper for Notifications
function SendNotify(msg, type)
    if Framework then
        TriggerEvent('QBCore:Notify', msg, type)
    else
        -- Default GTA notification for Standalone
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

-- Helper for Player Data (For Jurisdictions)
function GetPlayerJob()
    if Framework then
        local pData = Framework.Functions.GetPlayerData()
        return pData.job.name
    end
    return "citizen" -- Default
end