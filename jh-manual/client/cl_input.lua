-- Shift input handling

local lastShiftTime = 0
local shiftCooldown = 100 -- ms between shifts
local menuOpen = false

-- Register Key Mappings (Shows up in GTA Settings -> Key Bindings -> FiveM)
RegisterCommand('+shiftup', function()
    if not IsPedInAnyVehicle(PlayerPedId(), false) then return end
    HandleShift("UP")
end, false)

RegisterCommand('-shiftup', function() end, false)

RegisterCommand('+shiftdown', function()
    if not IsPedInAnyVehicle(PlayerPedId(), false) then return end
    HandleShift("DOWN")
end, false)

RegisterCommand('-shiftdown', function() end, false)

RegisterCommand('jh_manual_menu', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        ToggleMenu()
    end
end, false)

RegisterKeyMapping('+shiftup', Config.Controls.ShiftUp.desc, 'keyboard', Config.Controls.ShiftUp.key)
RegisterKeyMapping('+shiftdown', Config.Controls.ShiftDown.desc, 'keyboard', Config.Controls.ShiftDown.key)
RegisterKeyMapping('jh_manual_menu', Config.Controls.Menu.desc, 'keyboard', Config.Controls.Menu.key)

function HandleShift(direction)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    if isShifting then return end
    if GetGameTimer() - lastShiftTime < shiftCooldown then return end

    local maxGears = GetCachedMaxGears()

    if direction == "UP" then
        if currentGear < maxGears then
            if Config.Settings.ClutchRequired and not clutchActive then
                TriggerEvent('jh-manual:client:Notify', "Clutch required to shift!")
                return
            end

            local currentSpeed = GetEntitySpeed(veh)
            local maxSpeedForNewGear = MaxSpeedForGear(currentGear + 1)

            if Config.Settings.MoneyShiftDamage and currentSpeed > maxSpeedForNewGear then
                local health = GetVehicleEngineHealth(veh)
                SetVehicleEngineHealth(veh, health - Config.OverRevving.DamageAmount)
                SetVehicleEngineOn(veh, false, true, true)
                TriggerEvent('jh-manual:client:Notify', "Over-revved! Engine damaged!")
                lastShiftTime = GetGameTimer()
                return
            end

            PerformShift(veh, currentGear + 1)
            lastShiftTime = GetGameTimer()
        end
    elseif direction == "DOWN" then
        if currentGear > 1 then
            if Config.Settings.ClutchRequired and not clutchActive then
                TriggerEvent('jh-manual:client:Notify', "Clutch required to shift!")
                return
            end

            local newGear = currentGear - 1
            PerformRevBlip(veh)
            CheckMoneyShift(veh, newGear)

            if GetVehicleEngineHealth(veh) > 0 then
                PerformShift(veh, newGear)
            end

            lastShiftTime = GetGameTimer()
        end
    end
end

function HandleDirectGearSelect(targetGear)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    if isShifting or targetGear == currentGear then return end
    if GetGameTimer() - lastShiftTime < shiftCooldown then return end

    local maxGears = GetCachedMaxGears()
    if targetGear < 0 or targetGear > maxGears then return end

    if targetGear > 0 and Config.Settings.ClutchRequired and not clutchActive then
        TriggerEvent('jh-manual:client:Notify', "Clutch required to shift!")
        return
    end

    if targetGear == 0 then
        SetCurrentGearValue(0)
        TriggerEvent('jh-manual:client:GearChanged', currentGear)
        lastShiftTime = GetGameTimer()
        return
    end

    if targetGear < currentGear then
        PerformRevBlip(veh)
        CheckMoneyShift(veh, targetGear)
        if GetVehicleEngineHealth(veh) <= 0 then
            lastShiftTime = GetGameTimer()
            return
        end
    end

    PerformShift(veh, targetGear)
    lastShiftTime = GetGameTimer()
end

function HandleNeutralToggle()
    SetNeutralState(not isNeutral)
    TriggerEvent('jh-manual:client:Notify', isNeutral and "Neutral Engaged" or "Neutral Disengaged")
    lastShiftTime = GetGameTimer()
end

function PerformShift(veh, newGear)
    isShifting = true
    SetNeutralState(false)

    SetVehicleCheatPowerIncrease(veh, 0.0)

    local shiftDelay = GetShiftDelay(veh)
    Wait(shiftDelay)

    SetVehicleCheatPowerIncrease(veh, 1.0)

    SetCurrentGearValue(newGear)
    TriggerEvent('jh-manual:client:GearChanged', currentGear)

    isShifting = false
end

function ToggleMenu()
    menuOpen = not menuOpen
    SetNuiFocus(menuOpen, menuOpen)
    SendNUIMessage({
        action = "toggleMenu",
        status = menuOpen,
        currentMode = Config.Settings.DefaultMode
    })
end

RegisterNUICallback('changeMode', function(data, cb)
    if data and data.mode then
        Config.Settings.DefaultMode = data.mode
        TriggerEvent('jh-manual:client:Notify', "Transmission: " .. data.mode:upper(), "success")
    end
    if menuOpen then
        ToggleMenu()
    end
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(_, cb)
    if menuOpen then
        ToggleMenu()
    end
    cb('ok')
end)

CreateThread(function()
    while true do
        local sleep = 500

        if Config.RawInput and Config.RawInput.Enabled then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                sleep = Config.RawInput.PollInterval or 0
                local buttons = Config.RawInput.Buttons or {}

                if buttons.ShiftUp and IsRawInputButtonJustPressed(buttons.ShiftUp) then
                    HandleShift("UP")
                elseif buttons.ShiftDown and IsRawInputButtonJustPressed(buttons.ShiftDown) then
                    HandleShift("DOWN")
                elseif buttons.Neutral and IsRawInputButtonJustPressed(buttons.Neutral) then
                    HandleNeutralToggle()
                elseif buttons.Gear1 and IsRawInputButtonJustPressed(buttons.Gear1) then
                    HandleDirectGearSelect(1)
                elseif buttons.Gear2 and IsRawInputButtonJustPressed(buttons.Gear2) then
                    HandleDirectGearSelect(2)
                elseif buttons.Gear3 and IsRawInputButtonJustPressed(buttons.Gear3) then
                    HandleDirectGearSelect(3)
                elseif buttons.Gear4 and IsRawInputButtonJustPressed(buttons.Gear4) then
                    HandleDirectGearSelect(4)
                elseif buttons.Gear5 and IsRawInputButtonJustPressed(buttons.Gear5) then
                    HandleDirectGearSelect(5)
                elseif buttons.Gear6 and IsRawInputButtonJustPressed(buttons.Gear6) then
                    HandleDirectGearSelect(6)
                end
            end
        end

        Wait(sleep)
    end
end)
