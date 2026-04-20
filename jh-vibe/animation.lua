function PlayVibeSequence(type)
    local playerPed = PlayerPedId()
    local ped = interactionPed
    
    -- Cinematic Cam
    local cinCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    AttachCamToEntity(cinCam, playerPed, 0.5, 0.0, 0.7, true)
    SetCamActive(cinCam, true)
    RenderScriptCams(true, true, 1000, true, true)

    -- Animations (The "Spicy" Part)
    -- Using native Rockstar scenarios for vehicle-based intimacy
    if type == "low" then
        TaskPlayAnim(ped, "mini@prostitutes@sexlow_veh", "low_car_sex_loop_player", 8.0, -8.0, -1, 1, 0, false, false, false)
        TaskPlayAnim(playerPed, "mini@prostitutes@sexlow_veh", "low_car_sex_loop_female", 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    -- After sequence
    Wait(10000) -- Duration
    RenderScriptCams(false, true, 1000, true, true)
    DestroyCam(cinCam)
    -- Ped leaves vehicle
    TaskLeaveVehicle(ped, GetVehiclePedIsIn(playerPed, false), 0)
    SetEntityAsNoLongerNeeded(ped)
    inSequence = false
end