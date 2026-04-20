local function GetCurrentDistrict()
    local playerCoords = GetEntityCoords(PlayerPedId())
    if not playerCoords then
        return "LSPD"
    end

    if playerCoords.y > 2000 then
        return "BCSO"
    end

    return "LSPD"
end

local function CheckForWarrant()
    if exports['jh-streetstalk-dispatch'] then
        return exports['jh-streetstalk-dispatch']:HasWarrant()
    end
    return false
end

function InitiateTicketSequence(cop, copVeh, violationType)
    local fineData = Config.Fines and Config.Fines[violationType] or { label = "Unknown Violation", amount = 0 }
    
    -- AI walks to the window
    PlayAmbientSpeech1(cop, "GENERIC_HI", "SPEECH_PARAMS_FORCE")
    
    -- Show a NUI receipt or Notification
    SendNotify("CITATION ISSUED: " .. fineData.label, "error")
    SendNotify("Amount: $" .. fineData.amount, "primary")
    
    -- Increase Heat in the zone (so locals get nervous)
    TriggerServerEvent('jh-streetstalk:server:issueTicket', GetCurrentDistrict(), violationType)
    
    -- If the player has a warrant (3+ tickets), the cop won't leave.
    if CheckForWarrant() then
        TaskVehicleMission(cop, copVeh, PlayerPedId(), 6, 100.0, 786463, 5.0, 10.0, true)
    end
end