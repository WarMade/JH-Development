local isPulledOver = false
local currentViolation = nil
local lastChatter = 0

local function CheckTrafficViolations(playerPed, veh)
    if not DoesEntityExist(veh) then
        return nil
    end

    local speed = GetEntitySpeed(veh)
    local mph = speed * 2.236936
    local vehCoords = GetEntityCoords(veh)
    local relativeSpeed = GetEntitySpeedVector(veh, true)

    if not IsVehicleOnAllWheels(veh) and speed > 5.0 then
        return 'wheelie'
    elseif GetVehicleWheelieState(veh) == 129 then
        return 'drifting'
    elseif not IsPointOnRoad(vehCoords.x, vehCoords.y, vehCoords.z, veh) and speed > 2.0 then
        return 'sidewalk'
    elseif mph > 55.0 then
        return 'speeding'
    elseif HasEntityCollidedWithAnything(veh) then
        return 'collision'
    elseif relativeSpeed.y < -4.0 then
        return 'wrong_way'
    end

    return nil
end

local function AlertPlayer(cop)
    local now = GetGameTimer()
    if now - lastChatter < 20000 then
        return
    end

    local chatterChance = Config.ChatterProbability or 0.65
    if math.random() > chatterChance then
        return
    end

    lastChatter = now
    PlaySoundFrontend(-1, "Event_Message_In_Area", "GTAO_FM_Events_Soundset", true)

    if cop then
        PlayAmbientSpeech1(cop, "CHAT_STATE", "SPEECH_PARAMS_FORCE_SHOUT_CLEAR")
    end

    SendNotify("DISPATCH: Unit flagging vehicle for traffic violation...", "primary")
end

CreateThread(function()
    while true do
        Wait(1000)
        local playerPed = PlayerPedId()
        local veh = GetVehiclePedIsIn(playerPed, false)
        
        if not isPulledOver and veh ~= 0 and GetPedInVehicleSeat(veh, -1) == playerPed then
            local cop, copVeh = exports['jh-streetstalk-dispatch']:GetClosestPatrol(60.0)
            
            if cop and copVeh then
                local violation = CheckTrafficViolations(playerPed, veh)
                if violation then
                    AlertPlayer(cop)
                    Wait(2500)
                    if not isPulledOver then
                        InitiatePullOver(cop, copVeh, violation)
                    end
                end
            end
        end
    end
end)

function InitiatePullOver(cop, copVeh, violation)
    if isPulledOver then
        return
    end

    if not DoesEntityExist(cop) or not DoesEntityExist(copVeh) then
        return
    end

    isPulledOver = true
    currentViolation = violation

    -- STAGE 1: Observation
    SetVehicleSiren(copVeh, true)
    Wait(350)
    SetVehicleSiren(copVeh, false)
    TaskVehicleFollow(cop, copVeh, GetVehiclePedIsIn(PlayerPedId(), false), 15.0, 786603, 10.0)
    SendNotify("DISPATCH: Unit observing suspicious driving behavior...", "primary")

    Wait(3000)

    if not DoesEntityExist(cop) or not DoesEntityExist(copVeh) then
        isPulledOver = false
        return
    end

    -- STAGE 2: Actual stop
    SetVehicleSiren(copVeh, true)
    TaskVehicleMission(cop, copVeh, GetVehiclePedIsIn(PlayerPedId(), false), 8, 30.0, 786603, 5.0, 10.0, true)

    local notice = "POLICE: 'Pull over to the side of the road immediately!'"
    if violation and Config.Fines and Config.Fines[violation] then
        notice = string.format("POLICE: 'Pull over - %s detected!'", Config.Fines[violation].label)
    end
    SendNotify(notice, "primary")

    CreateThread(function()
        while isPulledOver do
            Wait(1000)
            local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
            if playerVeh ~= 0 and GetEntitySpeed(playerVeh) < 1.0 then
                InitiateTicketSequence(cop, copVeh, violation)
                break
            end
        end
    end)
end

function TriggerPullOver(cop, copVeh, violation)
    InitiatePullOver(cop, copVeh, violation)
end

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

function InitiateTicketSequence(cop, copVeh)
    if not DoesEntityExist(cop) or not DoesEntityExist(copVeh) then
        isPulledOver = false
        return
    end

    TaskLeaveVehicle(cop, copVeh, 0)
    TaskChatToPed(cop, PlayerPedId(), 16, 0.0, 0.0, 0.0, 0.0, 0.0)

    Wait(4000)

    local district = GetCurrentDistrict()
    local violation = currentViolation or 'speeding'
    local ticketAmount = math.random(150, 500)
    local ticketLabel = 'speeding'

    if Config.Fines and Config.Fines[violation] then
        ticketAmount = Config.Fines[violation].amount
        ticketLabel = Config.Fines[violation].label
    end

    -- Trigger server to record the fine
    TriggerServerEvent('jh-streetstalk:server:issueTicket', district, ticketAmount)
    
    SendNotify("You've been cited for "..ticketLabel..". Ticket: $"..ticketAmount..". Pay it at the "..district.." station.", "error")
    currentViolation = nil
    
    -- Cop returns to car and resumes patrol
    TaskEnterVehicle(cop, copVeh, -1, -1, 1.0, 1, 0)
    SetVehicleSiren(copVeh, false)
    TaskVehicleDriveWander(cop, copVeh, 20.0, 786603)
    isPulledOver = false
end