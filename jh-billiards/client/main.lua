local QBCore = exports['qb-core']:GetCoreObject()

if not QBCore then
    print("^1ERROR: QBCore object not found! Check your export name.^7")
end

-- Physics & Alignment Constants
local BALL_RADIUS = 0.028
local BALL_SPACING = 0.038 -- Adjust this if balls are too close/far
local FELT_HEIGHT = 0.92    -- Height from table origin to the cloth

local Config = {
    DefaultGuide = true,
    Fee = 50,
    TableModels = { `prop_pooltable_02`, `prop_pooltable_01` },
    BallOffsets = {
        vector3(-1.5, 0.0, 0.0),
        vector3(0.0, 0.0, 0.0),
        vector3(-BALL_SPACING, BALL_SPACING, 0.0),
        vector3(BALL_SPACING, BALL_SPACING, 0.0),
        vector3(-2 * BALL_SPACING, 2 * BALL_SPACING, 0.0),
        vector3(0.0, 2 * BALL_SPACING, 0.0),
        vector3(2 * BALL_SPACING, 2 * BALL_SPACING, 0.0),
        vector3(-3 * BALL_SPACING, 3 * BALL_SPACING, 0.0),
        vector3(-BALL_SPACING, 3 * BALL_SPACING, 0.0),
        vector3(BALL_SPACING, 3 * BALL_SPACING, 0.0),
        vector3(3 * BALL_SPACING, 3 * BALL_SPACING, 0.0),
        vector3(-4 * BALL_SPACING, 4 * BALL_SPACING, 0.0),
        vector3(-2 * BALL_SPACING, 4 * BALL_SPACING, 0.0),
        vector3(0.0, 4 * BALL_SPACING, 0.0),
        vector3(2 * BALL_SPACING, 4 * BALL_SPACING, 0.0),
        vector3(4 * BALL_SPACING, 4 * BALL_SPACING, 0.0),
    },
    Controls = {
        ToggleGuide = 37, -- TAB
        Shoot = 24,       -- Left Click
        Exit = 177        -- ESC / Backspace
    }
}
local isPlaying = false
local poolScaleform = nil
local poolCam = nil
local currentTable = nil
local currentTableNetId = nil
local cuePower = 0.0
local currentPower = 0.0
local showGhostGuide = Config.DefaultGuide
local currentRotation = 0.0
local isMyTurn = false
local isSpectating = false
local spectateCam = nil
local eightBallEntity = nil
local totalBallsOnTable = 15

local ballProps = {}
local ballModels = {
    `prop_poolball_cue`,
    `prop_poolball_1`,
    `prop_poolball_2`,
    `prop_poolball_3`,
    `prop_poolball_4`,
    `prop_poolball_5`,
    `prop_poolball_6`,
    `prop_poolball_7`,
    `prop_poolball_8`,
    `prop_poolball_9`,
    `prop_poolball_10`,
    `prop_poolball_11`,
    `prop_poolball_12`,
    `prop_poolball_13`,
    `prop_poolball_14`,
    `prop_poolball_15`,
}

local shotActive = false

local function LoadModel(model)
    if not HasModelLoaded(model) then
        RequestModel(model)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do
            Wait(0)
        end
    end
end

function ToggleGhostGuide()
    showGhostGuide = not showGhostGuide

    BeginScaleformMovieMethod(poolScaleform, "SET_GUIDE_VISIBLE")
    ScaleformMovieMethodAddParamBool(showGhostGuide)
    EndScaleformMovieMethod()

    local status = showGhostGuide and "Enabled" or "Disabled"
    QBCore.Functions.Notify("Ghost Guide: " .. status, "primary")
end

RegisterNetEvent('jh-billiards:client:setupTurn', function(state)
    isMyTurn = state
    if isMyTurn then
        QBCore.Functions.Notify("It's your turn!", "success")
    else
        QBCore.Functions.Notify("Waiting for opponent...", "primary")
    end
end)

RegisterNetEvent('jh-billiards:client:beginMatch', function(tableId, coords)
    currentTable = NetworkGetEntityFromNetworkId(tableId)
    currentTableNetId = tableId

    local status, err = pcall(function()
        StartPoolGame(coords)
    end)

    if not status then
        print("^1BILLIARDS DEBUG: " .. tostring(err) .. "^7")
    end
end)

RegisterNetEvent('jh-billiards:client:exitGame', function(tableId)
    isPlaying = false
    TogglePoolCam(false)
    currentTable = nil
    currentTableNetId = nil
    isMyTurn = false
    shotActive = false
    ClearPoolBalls()
end)

function DrawManualGuide(cueBall, rotation)
    if not DoesEntityExist(cueBall) then
        return
    end

    local startCoords = GetEntityCoords(cueBall)
    local endCoords = vector3(
        startCoords.x + (math.sin(math.rad(rotation)) * -10.0),
        startCoords.y + (math.cos(math.rad(rotation)) * 10.0),
        startCoords.z
    )

    local rayHandle = StartShapeTestRay(startCoords.x, startCoords.y, startCoords.z, endCoords.x, endCoords.y, endCoords.z, 10, cueBall, 0)
    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)

    if hit then
        DrawLine(startCoords.x, startCoords.y, startCoords.z, hitCoords.x, hitCoords.y, hitCoords.z, 255, 255, 255, 150)
        DrawMarker(28, hitCoords.x, hitCoords.y, hitCoords.z, 0, 0, 0, 0, 0, 0, 0.1, 0.1, 0.1, 255, 255, 255, 100, false, false, 2, nil, nil, false)
    end
end

local function ClearPoolBalls()
    for _, ball in ipairs(ballProps) do
        if DoesEntityExist(ball) then
            DeleteObject(ball)
        end
    end

    ballProps = {}
    eightBallEntity = nil
end

local TABLE_WIDTH = 0.55  -- X-axis (Short side)
local TABLE_LENGTH = 1.05 -- Y-axis (Long side)
local BOUNCE_DAMPING = 0.8 -- Energy lost when hitting a rail

local POCKETS = {
    vector3(0.55, 1.05, 0.0),   -- Top Left
    vector3(-0.55, 1.05, 0.0),  -- Top Right
    vector3(0.55, 0.0, 0.0),    -- Middle Left
    vector3(-0.55, 0.0, 0.0),   -- Middle Right
    vector3(0.55, -1.05, 0.0),  -- Bottom Left
    vector3(-0.55, -1.05, 0.0), -- Bottom Right
}

local tableOffsets = {
    topCenter = vector3(0.0, 0.0, FELT_HEIGHT),
    cornerTL = vector3(-0.6, 1.1, FELT_HEIGHT),
    cornerTR = vector3(0.6, 1.1, FELT_HEIGHT),
}

local rackedPositions = {
    vector3(-1.5, 0.0, 0.9),
    vector3(0.0, 0.0, 0.9),
    vector3(-BALL_SPACING, BALL_SPACING, 0.9),
    vector3(BALL_SPACING, BALL_SPACING, 0.9),
    vector3(-2 * BALL_SPACING, 2 * BALL_SPACING, 0.9),
    vector3(0.0, 2 * BALL_SPACING, 0.9),
    vector3(2 * BALL_SPACING, 2 * BALL_SPACING, 0.9),
    vector3(-3 * BALL_SPACING, 3 * BALL_SPACING, 0.9),
    vector3(-BALL_SPACING, 3 * BALL_SPACING, 0.9),
    vector3(BALL_SPACING, 3 * BALL_SPACING, 0.9),
    vector3(3 * BALL_SPACING, 3 * BALL_SPACING, 0.9),
    vector3(-4 * BALL_SPACING, 4 * BALL_SPACING, 0.9),
    vector3(-2 * BALL_SPACING, 4 * BALL_SPACING, 0.9),
    vector3(0.0, 4 * BALL_SPACING, 0.9),
    vector3(2 * BALL_SPACING, 4 * BALL_SPACING, 0.9),
    vector3(4 * BALL_SPACING, 4 * BALL_SPACING, 0.9),
}

function SpawnPoolBalls(tableEntity)
    if not DoesEntityExist(tableEntity) then return end

    -- 1. Clear old balls to prevent stacking
    for _, ball in ipairs(ballProps) do
        if DoesEntityExist(ball) then
            DeleteEntity(ball)
        end
    end
    ballProps = {}

    local spacing = BALL_SPACING or 0.038
    local feltHeight = 0.92

    local rackOffsets = {
        vector3(0.0, 0.5, feltHeight),
        vector3(-spacing / 2, 0.5 + spacing, feltHeight),
        vector3(spacing / 2, 0.5 + spacing, feltHeight),
        -- Add more rows as needed...
    }

    for i, offset in ipairs(rackOffsets) do
        local worldPos = GetOffsetFromEntityInWorldCoords(tableEntity, offset.x, offset.y, offset.z)
        local ball = CreateObject(`prop_poolball_1`, worldPos.x, worldPos.y, worldPos.z, true, true, false)

        if DoesEntityExist(ball) then
            SetEntityCollision(ball, false, false)
            FreezeEntityPosition(ball, true)
            table.insert(ballProps, ball)
        end
    end

    SetTimeout(500, function()
        for _, ball in ipairs(ballProps) do
            if DoesEntityExist(ball) then
                SetEntityCollision(ball, true, true)
                FreezeEntityPosition(ball, false)
                ActivatePhysics(ball)
            end
        end
    end)
end

function ProcessBallPhysics(ball, tableEntity)
    if not DoesEntityExist(ball) then
        return
    end

    local ballCoords = GetEntityCoords(ball)
    if DoesEntityExist(tableEntity) then
        local localCoords = GetOffsetFromEntityGivenWorldCoords(tableEntity, ballCoords.x, ballCoords.y, ballCoords.z)
        local velocity = GetEntityVelocity(ball)
        local hitRail = false

        if localCoords.x > TABLE_WIDTH or localCoords.x < -TABLE_WIDTH then
            velocity = vector3(-velocity.x * BOUNCE_DAMPING, velocity.y, velocity.z)
            hitRail = true
        end

        if localCoords.y > TABLE_LENGTH or localCoords.y < -TABLE_LENGTH then
            velocity = vector3(velocity.x, -velocity.y * BOUNCE_DAMPING, velocity.z)
            hitRail = true
        end

        if hitRail then
            SetEntityVelocity(ball, velocity.x, velocity.y, velocity.z)
            PlaySoundFromEntity(-1, "Ball_Hit_Rail", ball, "Hint_System_Sounds", 0, 0)
        end
    else
        print("Error: Table entity disappeared during physics check!")
    end
end

function CheckPockets(ball, tableEntity)
    if not DoesEntityExist(ball) then
        return false
    end

    local ballCoords = GetEntityCoords(ball)
    if DoesEntityExist(tableEntity) then
        local localCoords = GetOffsetFromEntityGivenWorldCoords(tableEntity, ballCoords.x, ballCoords.y, ballCoords.z)

        for _, pocketPos in ipairs(POCKETS) do
            if #(localCoords - pocketPos) < 0.12 then
                PotBall(ball)
                return true
            end
        end
    end

    return false
end

function PotBall(ball)
    if not DoesEntityExist(ball) then
        return
    end

    local isEightBall = (ball == eightBallEntity)
    local ballId = ObjToNet(ball)

    if DoesEntityExist(currentTable) then
        local tableState = Entity(currentTable).state
        local currentPotted = tableState.pottedBalls or {}
        table.insert(currentPotted, ballId)
        tableState:set('pottedBalls', currentPotted, true)
    end

    -- Count remaining balls (excluding the cue ball)
    local remainingBalls = 0
    for _, b in ipairs(ballProps) do
        if DoesEntityExist(b) and b ~= ballProps[1] then
            remainingBalls = remainingBalls + 1
        end
    end

    TriggerServerEvent('jh-billiards:server:processPot', currentTableNetId, isEightBall, remainingBalls)

    DeleteObject(ball)
end

function TakeShot(yaw, power)
    local cueBall = ballProps[1]
    if not DoesEntityExist(cueBall) then return end

    if not NetworkHasControlOfEntity(cueBall) then
        NetworkRequestControlOfEntity(cueBall)
        local timeout = 0
        while not NetworkHasControlOfEntity(cueBall) and timeout < 50 do
            Wait(10)
            timeout = timeout + 1
        end
    end

    local angleRad = math.rad(yaw)
    local forceX = math.sin(angleRad) * -(power * 0.5)
    local forceY = math.cos(angleRad) * (power * 0.5)

    ApplyForceToEntity(cueBall, 1, forceX, forceY, 0.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    MonitorBallMovement()
end

function MonitorBallMovement()
    CreateThread(function()
        local moving = true
        local pottedCount = 0

        while moving do
            Wait(100)
            moving = false

            for _, ball in ipairs(ballProps) do
                if DoesEntityExist(ball) then
                    local velocity = GetEntityVelocity(ball)
                    if #(velocity) > 0.1 then
                        moving = true
                    end

                    if CheckPockets(ball, currentTable) then
                        pottedCount = pottedCount + 1
                    end
                end
            end
        end

        shotActive = false

        if isMyTurn and currentTableNetId then
            TriggerServerEvent('jh-billiards:server:endShot', currentTableNetId, pottedCount)
        end
    end)
end

-- Load the scaleform
function LoadPoolScaleform()
    poolScaleform = RequestScaleformMovie("billiards")
    while not HasScaleformMovieLoaded(poolScaleform) do
        Wait(0)
    end
    
    BeginScaleformMovieMethod(poolScaleform, "SET_TABLE_TYPE")
    ScaleformMovieMethodAddParamInt(0) -- 0: Standard, 1: Bar
    EndScaleformMovieMethod()
end

function CallScaleform(method, ...)
    if not poolScaleform or not HasScaleformMovieLoaded(poolScaleform) then
        return
    end

    BeginScaleformMovieMethod(poolScaleform, method)
    local params = {...}
    for _, param in ipairs(params) do
        local t = type(param)
        if t == "boolean" then
            ScaleformMovieMethodAddParamBool(param)
        elseif t == "number" then
            if math.type and math.type(param) == "integer" then
                ScaleformMovieMethodAddParamInt(param)
            else
                ScaleformMovieMethodAddParamFloat(param)
            end
        elseif t == "string" then
            ScaleformMovieMethodAddParamTextureNameString(param)
        elseif t == "table" and param.x and param.y and param.z then
            ScaleformMovieMethodAddParamFloat(param.x)
            ScaleformMovieMethodAddParamFloat(param.y)
            ScaleformMovieMethodAddParamFloat(param.z)
        else
            ScaleformMovieMethodAddParamFloat(param)
        end
    end
    EndScaleformMovieMethod()
end

AddStateBagChangeHandler('pottedBalls', nil, function(bagName, key, value)
    if not isSpectating and not isPlaying then return end
    if not poolScaleform then return end

    -- Update the Scaleform UI with the new list of potted balls
    for _, ballId in ipairs(value) do
        BeginScaleformMovieMethod(poolScaleform, "SET_BALL_POTTED")
        ScaleformMovieMethodAddParamInt(ballId)
        EndScaleformMovieMethod()
    end
end)

-- Camera Logic
local cameraDistance = 2.0
local cameraHeight = 1.2
local cameraPitch = -35.0 -- Looking down
local cameraYaw = 0.0

function TogglePoolCam(toggle, coords)
    if not coords then
        if currentTable and DoesEntityExist(currentTable) then
            coords = GetEntityCoords(currentTable)
        else
            print("^1Billiards Error: TogglePoolCam called without valid coordinates!^7")
            return
        end
    end

    if toggle then
        poolCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(poolCam, coords.x, coords.y, coords.z + 1.2)
        PointCamAtCoord(poolCam, coords.x, coords.y, coords.z)
        SetCamActive(poolCam, true)
        RenderScriptCams(true, true, 1000, true, true)
    else
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(poolCam, false)
        poolCam = nil
    end
end

function UpdateFreeFormCamera(cueBall)
    if not DoesEntityExist(cueBall) then return end
    local ballCoords = GetEntityCoords(cueBall)

    local tableCoords = vector3(0.0, 0.0, 0.0)
    if DoesEntityExist(currentTable) then
        tableCoords = GetEntityCoords(currentTable)
    end

    if ballCoords.z > tableCoords.z + 2.0 then
        ballCoords = vector3(ballCoords.x, ballCoords.y, tableCoords.z + 0.92)
    end

    local mouseX = GetControlNormal(0, 1) * -5.0
    cameraYaw = cameraYaw + mouseX

    local offsetX = math.sin(math.rad(cameraYaw)) * cameraDistance
    local offsetY = math.cos(math.rad(cameraYaw)) * cameraDistance
    local camCoords = vector3(ballCoords.x + offsetX, ballCoords.y + offsetY, ballCoords.z + cameraHeight)

    SetCamCoord(poolCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(poolCam, ballCoords.x, ballCoords.y, ballCoords.z)

    BeginScaleformMovieMethod(poolScaleform, "SET_CUE_ROTATION")
    ScaleformMovieMethodAddParamFloat(cameraYaw)
    EndScaleformMovieMethod()
end

local function UpdateSpectatorCam(coords)
    if not poolCam then return end
    
    local angle = GetGameTimer() / 5000 -- Slow rotation
    local camX = coords.x + math.cos(angle) * 2.0
    local camY = coords.y + math.sin(angle) * 2.0
    
    SetCamCoord(poolCam, camX, camY, coords.z + 1.2)
    PointCamAtCoord(poolCam, coords.x, coords.y, coords.z)
end

function StartSpectating(tableEntity)
    if isSpectating or isPlaying then
        return
    end

    local tableCoords = GetEntityCoords(tableEntity)
    isSpectating = true
    
    LoadPoolScaleform() -- Load the UI
    TogglePoolCam(true, tableCoords) -- Give them the table view

    CreateThread(function()
        while isSpectating do
            Wait(0)
            -- Draw the scaleform so they see the same UI as the players
            DrawScaleformMovieFullscreen(poolScaleform, 255, 255, 255, 255, 0)

            -- Instructions for spectators
            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName("Press ~INPUT_FRONTEND_CANCEL~ to stop spectating")
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustPressed(0, Config.Controls.Exit) then
                StopSpectating()
            end
        end
    end)
end

function StopSpectating()
    isSpectating = false
    TogglePoolCam(false)
    -- Clean up local scaleform memory
    SetScaleformMovieAsNoLongerNeeded(poolScaleform)
    poolScaleform = nil
end

-- Main Game Loop
function StartPoolGame(tableEntity)
    if not poolScaleform then
        LoadPoolScaleform()
    end

    if not tableEntity or not DoesEntityExist(tableEntity) then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        tableEntity = GetClosestObjectOfType(pos.x, pos.y, pos.z, 3.0, `prop_pooltable_02`, false, false, false)
    end

    if DoesEntityExist(tableEntity) then
        currentTable = tableEntity
        local tableCoords = GetEntityCoords(tableEntity)
        isPlaying = true
        isMyTurn = true
        shotActive = false
        cuePower = 0.0
        currentPower = 0.0

        if currentTable and DoesEntityExist(currentTable) then
            local tableState = Entity(currentTable).state
            tableState:set('pottedBalls', {}, true)
        end

        TogglePoolCam(true, tableCoords)
        SpawnPoolBalls(currentTable)

        CreateThread(function()
        while isPlaying do
            Wait(0)

            DisableControlAction(0, 24, true) -- Attack (Left Click)
            DisableControlAction(0, 25, true) -- Aim (Right Click)
            DisableControlAction(0, 22, true) -- Jump (Space)

            if isMyTurn then
                UpdateFreeFormCamera(ballProps[1])

                if IsDisabledControlPressed(0, 22) then -- SPACE
                    currentPower = currentPower + 1.5
                    if currentPower > 100.0 then currentPower = 100.0 end

                    BeginScaleformMovieMethod(poolScaleform, "SET_CUE_POWER")
                    ScaleformMovieMethodAddParamInt(math.floor(currentPower))
                    EndScaleformMovieMethod()
                elseif IsDisabledControlReleased(0, 22) and currentPower > 5.0 then
                    TakeShot(cameraYaw, currentPower)
                    currentPower = 0.0
                end

                if IsControlJustPressed(0, Config.Controls.ToggleGuide) then
                    ToggleGhostGuide()
                end
            end

            DrawScaleformMovieFullscreen(poolScaleform, 255, 255, 255, 255, 0)
        end

        shotActive = false
        currentTable = nil
        currentTableNetId = nil
        isMyTurn = false
        ClearPoolBalls()
    end)
    else
        print("^1Error: No pool table found at " .. tostring(tableCoords) .. "^7")
        QBCore.Functions.Notify("Error finding table!", "error")
    end
end

-- Target Interaction
exports['qb-target']:AddTargetModel(Config.TableModels, {
    options = {
        {
            type = "client",
            action = function(entity)
                if DoesEntityExist(entity) then
                    QBCore.Functions.TriggerCallback('jh-billiards:server:canPlay', function(canPlay)
                        if canPlay then
                            StartPoolGame(entity)
                        else
                            QBCore.Functions.Notify("You need a Pool Cue and $50 to play!", "error")
                        end
                    end)
                end
            end,
            icon = "fas fa-poker-chip",
            label = "Play Billiards",
        },
        {
            type = "client",
            action = function(entity)
                StartSpectating(entity)
            end,
            icon = "fas fa-eye",
            label = "Watch Game",
        },
    },
    distance = 2.5
})

RegisterCommand('jh-billiards:toggleghostguide', function()
    if isPlaying and poolScaleform then
        ToggleGhostGuide()
    else
        QBCore.Functions.Notify('You must be playing billiards to toggle the ghost guide.', 'error')
    end
end, false)

RegisterKeyMapping('jh-billiards:toggleghostguide', 'Toggle billiards ghost guide', 'keyboard', 'G')

exports('IsPlayingBilliards', function()
    return isPlaying
end)

exports('GetCurrentTable', function()
    return currentTable
end)