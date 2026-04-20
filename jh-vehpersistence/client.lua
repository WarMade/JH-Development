local orderedPlates = {}      -- newest first
local plateToEntity = {}      -- plate -> entity handle

local maxVehicles = 5

-- ==================== VEHICLE PROPERTIES ====================
local function GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then return {} end

    local color1, color2 = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

    local extras = {}
    for id = 0, 12 do
        if DoesExtraExist(vehicle, id) then
            extras[tostring(id)] = IsVehicleExtraTurnedOn(vehicle, id)
        end
    end

    return {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = Round(GetVehicleBodyHealth(vehicle), 1),
        engineHealth = Round(GetVehicleEngineHealth(vehicle), 1),
        tankHealth = Round(GetVehiclePetrolTankHealth(vehicle), 1),
        fuelLevel = Round(GetVehicleFuelLevel(vehicle), 1),
        dirtLevel = Round(GetVehicleDirtLevel(vehicle), 1),
        color1 = color1,
        color2 = color2,
        pearlescentColor = pearlescentColor,
        wheelColor = wheelColor,
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        xenonColor = GetVehicleXenonLightsColor(vehicle),
        neonEnabled = {
            IsVehicleNeonLightEnabled(vehicle, 0),
            IsVehicleNeonLightEnabled(vehicle, 1),
            IsVehicleNeonLightEnabled(vehicle, 2),
            IsVehicleNeonLightEnabled(vehicle, 3)
        },
        neonColor = {GetVehicleNeonLightsColour(vehicle)},
        tyreSmokeColor = {GetVehicleTyreSmokeColor(vehicle)},
        extras = extras,
        modSpoilers = GetVehicleMod(vehicle, 0),
        modFrontBumper = GetVehicleMod(vehicle, 1),
        modRearBumper = GetVehicleMod(vehicle, 2),
        modSideSkirt = GetVehicleMod(vehicle, 3),
        modExhaust = GetVehicleMod(vehicle, 4),
        modFrame = GetVehicleMod(vehicle, 5),
        modGrille = GetVehicleMod(vehicle, 6),
        modHood = GetVehicleMod(vehicle, 7),
        modFender = GetVehicleMod(vehicle, 8),
        modRightFender = GetVehicleMod(vehicle, 9),
        modRoof = GetVehicleMod(vehicle, 10),
        modEngine = GetVehicleMod(vehicle, 11),
        modBrakes = GetVehicleMod(vehicle, 12),
        modTransmission = GetVehicleMod(vehicle, 13),
        modHorns = GetVehicleMod(vehicle, 14),
        modSuspension = GetVehicleMod(vehicle, 15),
        modArmor = GetVehicleMod(vehicle, 16),
        modTurbo = IsToggleModOn(vehicle, 18),
        modSmokeEnabled = IsToggleModOn(vehicle, 20),
        modXenon = IsToggleModOn(vehicle, 22),
        modFrontWheels = GetVehicleMod(vehicle, 23),
        modBackWheels = GetVehicleMod(vehicle, 24),
        modPlateHolder = GetVehicleMod(vehicle, 25),
        modVanityPlate = GetVehicleMod(vehicle, 26),
        modTrimA = GetVehicleMod(vehicle, 27),
        modOrnaments = GetVehicleMod(vehicle, 28),
        modDashboard = GetVehicleMod(vehicle, 29),
        modDial = GetVehicleMod(vehicle, 30),
        modDoorSpeaker = GetVehicleMod(vehicle, 31),
        modSeats = GetVehicleMod(vehicle, 32),
        modSteeringWheel = GetVehicleMod(vehicle, 33),
        modColumnShifter = GetVehicleMod(vehicle, 34),
        modHydraulics = GetVehicleMod(vehicle, 35),
        modLivery = GetVehicleLivery(vehicle),
    }
end

local function SetVehicleProperties(vehicle, props)
    if not props or not DoesEntityExist(vehicle) then return end
    SetVehicleModKit(vehicle, 0)

    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
    if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end
    if props.color1 and props.color2 then SetVehicleColours(vehicle, props.color1, props.color2) end
    if props.pearlescentColor then SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor or 0) end
    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end

    if props.neonEnabled then
        for i = 1, 4 do
            SetVehicleNeonLightEnabled(vehicle, i-1, props.neonEnabled[i])
        end
    end
    if props.neonColor then SetVehicleNeonLightsColour(vehicle, table.unpack(props.neonColor)) end
    if props.tyreSmokeColor then SetVehicleTyreSmokeColor(vehicle, table.unpack(props.tyreSmokeColor)) end
    if props.extras then
        for id, enabled in pairs(props.extras) do
            SetVehicleExtra(vehicle, tonumber(id), not enabled)
        end
    end

    for i = 0, 16 do
        if props["mod" .. i] ~= nil then
            SetVehicleMod(vehicle, i, props["mod" .. i], false)
        end
    end
    if props.modTurbo ~= nil then ToggleVehicleMod(vehicle, 18, props.modTurbo) end
    if props.modXenon ~= nil then ToggleVehicleMod(vehicle, 22, props.modXenon) end
    if props.modLivery then SetVehicleLivery(vehicle, props.modLivery) end
end

-- ==================== SAVE & ADD ====================
local function saveCurrentState()
    local dataToSave = {}
    for _, plate in ipairs(orderedPlates) do
        local veh = plateToEntity[plate]
        if veh and DoesEntityExist(veh) then
            local props = GetVehicleProperties(veh)
            local coords = GetEntityCoords(veh)
            local heading = GetEntityHeading(veh)
            table.insert(dataToSave, {
                plate = plate,
                model = tostring(GetEntityModel(veh)),
                x = coords.x,
                y = coords.y,
                z = coords.z,
                heading = heading,
                properties = props
            })
        end
    end
    TriggerServerEvent('vehicle_persistence:saveVehicles', dataToSave)
end

local function addToLastVehicles(veh)
    if not veh or not DoesEntityExist(veh) then return end
    local plate = GetVehicleNumberPlateText(veh):gsub("%s+", "")  -- clean plate
    if plate == "" then return end

    -- Only add if player is in DRIVER seat
    if GetPedInVehicleSeat(veh, -1) ~= PlayerPedId() then return end

    -- remove duplicate
    for i = #orderedPlates, 1, -1 do
        if orderedPlates[i] == plate then
            table.remove(orderedPlates, i)
            break
        end
    end

    table.insert(orderedPlates, 1, plate)
    plateToEntity[plate] = veh

    if #orderedPlates > maxVehicles then
        local oldPlate = table.remove(orderedPlates)
        plateToEntity[oldPlate] = nil
    end

    saveCurrentState()
end

-- ==================== SPAWN ON JOIN ====================
RegisterNetEvent('vehicle_persistence:receiveData', function(vehicles)
    orderedPlates = {}
    plateToEntity = {}

    for _, data in ipairs(vehicles) do
        local modelHash = tonumber(data.model)
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(10) end

        local veh = CreateVehicle(modelHash, data.x, data.y, data.z, data.heading, true, false)
        SetVehicleOnGroundProperly(veh)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleHasBeenOwnedByPlayer(veh, true)
        SetVehicleNeedsToBeHotwired(veh, false)
        SetVehicleIsStolen(veh, false)

        SetVehicleProperties(veh, data.properties or {})

        table.insert(orderedPlates, data.plate)
        plateToEntity[data.plate] = veh
    end
end)

-- ==================== MAIN LOOP (driver seat only) ====================
CreateThread(function()
    while true do
        Wait(3000)

        local ped = PlayerPedId()
        local currentVeh = GetVehiclePedIsIn(ped, false)

        if currentVeh ~= 0 and GetPedInVehicleSeat(currentVeh, -1) == ped then
            addToLastVehicles(currentVeh)
        end

        -- cleanup deleted vehicles (garage store, etc.)
        for i = #orderedPlates, 1, -1 do
            local plate = orderedPlates[i]
            local veh = plateToEntity[plate]

            if not veh or not DoesEntityExist(veh) then
                table.remove(orderedPlates, i)
                plateToEntity[plate] = nil
                TriggerServerEvent('vehicle_persistence:removeVehicle', plate)
            else
                if NetworkRequestControlOfEntity(veh) or NetworkHasControlOfEntity(veh) then
                    SetEntityAsMissionEntity(veh, true, true)
                end
            end
        end
    end
end)

-- periodic save
CreateThread(function()
    while true do
        Wait(30000)
        if #orderedPlates > 0 then
            saveCurrentState()
        end
    end
end)

-- request data on join
CreateThread(function()
    Wait(5000)
    TriggerServerEvent('vehicle_persistence:requestData')
end)

print('^2[vehicle_persistence_last5] ^7QBCore + Driver Seat Only version loaded')