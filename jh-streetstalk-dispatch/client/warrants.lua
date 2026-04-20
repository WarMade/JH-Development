-- client/warrants.lua

local hasWarrant = false
local warrantActive = false
local playerTicketCount = 0

RegisterNetEvent('jh-streetstalk-dispatch:client:syncWarrant', function(state)
    hasWarrant = state
end)

exports('HasWarrant', function()
    return hasWarrant
end)

RegisterNetEvent('jh-streetstalk-dispatch:client:updateTicketCount', function(count)
    playerTicketCount = tonumber(count) or 0
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('jh-streetstalk-dispatch:server:requestTicketCount')

    if exports['qb-target'] then
        exports['qb-target']:AddBoxZone("LSPD_FrontDesk", vector3(441.8, -982.0, 30.7), 2, 2, {
            name = "LSPD_FrontDesk",
            heading = 180,
            debugPoly = false,
        }, {
            options = {
                {
                    type = "server",
                    event = "jh-streetstalk:server:payAllTickets",
                    icon = "fas@file-invoice-dollar",
                    label = "Pay Outstanding Warrants (LSPD)",
                    canInteract = function()
                        return playerTicketCount > 0
                    end,
                },
            },
            distance = 2.0
        })
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if hasWarrant and not warrantActive then
            local cop, copVeh = exports['jh-streetstalk-dispatch']:GetClosestPatrol(60.0)
            if cop and copVeh then
                TriggerWarrantPursuit(cop, copVeh)
            end
        end
    end
end)

function TriggerWarrantPursuit(cop, copVeh)
    if warrantActive or not DoesEntityExist(cop) or not DoesEntityExist(copVeh) then
        return
    end

    warrantActive = true
    PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true) -- "ALPR Alert" sound
    SendNotify("ALPR ALERT: Your vehicle has been flagged for outstanding warrants!", "error")
    
    -- No talking. No lights. Just the PIT.
    SetVehicleSiren(copVeh, true)
    TaskVehicleMission(cop, copVeh, GetVehiclePedIsIn(PlayerPedId(), false), 6, 100.0, 786463, 5.0, 10.0, true)

    CreateThread(function()
        Wait(15000)
        warrantActive = false
    end)
end