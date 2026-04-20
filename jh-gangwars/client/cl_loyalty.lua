local QBCore = exports['qb-core']:GetCoreObject()
local isWhistling = false

local function TriggerLookoutAlert()
    if isWhistling then return end
    isWhistling = true
    
    local ped = QBCore.Functions.GetClosestPed()
    if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
        RequestAnimDict("rcmnigel1c")
        while not HasAnimDictLoaded("rcmnigel1c") do Wait(0) end
        TaskPlayAnim(ped, "rcmnigel1c", "hailing_whistle_waist_high", 8.0, -8.0, -1, 49, 0, false, false, false)
        PlaySoundFromEntity(-1, "Whistle_Wait", ped, "Speech_Menu_Sounds", 0, 0)
    end

    QBCore.Functions.Notify("The block is hot! A lookout just whistled.", "error")
    SetTimeout(60000, function() isWhistling = false end)
end

CreateThread(function()
    while true do
        Wait(5000)
        -- Query jh-streetstalk-dispatch for nearby AI patrols
        local cop, copVeh = exports['jh-streetstalk-dispatch']:GetClosestPatrol(60.0)
        if cop then
            TriggerLookoutAlert()
        end
    end
end)