local QBCore = exports['qb-core']:GetCoreObject()

local isPlaying = false
local poolScaleform = nil
local poolCam = nil
local currentTable = nil
local currentTableNetId = nil
local currentPower = 0.0
local showGhostGuide = Config.DefaultGuide
local cameraYaw = 0.0
local isMyTurn = false
local isSpectating = false
local ballProps = {}
local eightBallEntity = nil
local shotActive = false

-- Constants from Config or hardcoded for physics
local BALL_RADIUS = 0.028
local POCKETS = {
    vector3(0.55, 1.05, 0.0),   -- Top Left
    vector3(-0.55, 1.05, 0.0),  -- Top Right
    vector3(0.55, 0.0, 0.0),    -- Middle Left
    vector3(-0.55, 0.0, 0.0),   -- Middle Right
    vector3(0.55, -1.05, 0.0),  -- Bottom Left
    vector3(-0.55, -1.05, 0.0), -- Bottom Right
}

local function LoadModel(model)
    if not HasModelLoaded(model) then
        RequestModel(model)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do
            Wait(0)
        end
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

function ToggleGhostGuide()
    showGhostGuide = not showGhostGuide
    if poolScaleform then
        BeginScaleformMovieMethod(poolScaleform, "SET_GUIDE_VISIBLE")
        ScaleformMovieMethodAddParamBool(showGhostGuide)
        EndScaleformMovieMethod()
    end
    local status = showGhostGuide and "Enabled" or "Disabled"
    QBCore.Functions.Notify("Ghost Guide: " .. status, "primary")
end

function LoadPoolScaleform()
    poolScaleform = RequestScaleformMovie("billiards")
    while not HasScaleformMovieLoaded(poolScaleform) do
        Wait(0)
    end
    BeginScaleformMovieMethod(poolScaleform, "SET_TABLE_TYPE")
    ScaleformMovieMethodAddParamInt(0)
    EndScaleformMovieMethod()
end

function TogglePoolCam(toggle, coords)
    if toggle then
        if not poolCam then
            poolCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
            SetCamCoord(poolCam, coords.x, coords.y, coords.z + 1.2)
            PointCamAtCoord(poolCam, coords.x, coords.y, coords.z)
            SetCamActive(poolCam, true)
            RenderScriptCams(true, true, 1000, true, true)
        end
    else
        RenderScriptCams(false, true, 1000, true, true)
        if poolCam then
            DestroyCam(poolCam, false)
            poolCam = nil
        end
    end
end

function SpawnPoolBalls(tableEntity)
    if not DoesEntityExist(tableEntity) then return end
    ClearPoolBalls()

    local spacing = Config.BallSpacing
    local feltHeight = Config.FeltHeight

    -- Standard 8-ball rack
    local rackOffsets = {
        vector3(0.0, 0.5, feltHeight), -- Cue ball position (roughly)
        -- Row 1
        vector3(0.0, -0.5, feltHeight),
        -- Row 2
        vector3(-spacing/2, -0.5 - spacing, feltHeight),
        vector3(spacing/2, -0.5 - spacing, feltHeight),
        -- Row 3
        vector3(-spacing, -0.5 - (spacing * 2), feltHeight),
        vector3(0.0, -0.5 - (spacing * 2), feltHeight), -- 8 Ball usually here
        vector3(spacing, -0.5 - (spacing * 2), feltHeight),
        -- Row 4
        vector3(-spacing * 1.5, -0.5 - (spacing * 3), feltHeight),
        vector3(-spacing/2, -0.5 - (spacing * 3), feltHeight),
        vector3(spacing/2, -0.5 - (spacing * 3), feltHeight),
        vector3(spacing * 1.5, -0.5 - (spacing * 3), feltHeight),
        -- Row 5
        vector3(-spacing * 2, -0.5 - (spacing * 4), feltHeight),
        vector3(-spacing, -0.5 - (spacing * 4), feltHeight),
        vector3(0.0, -0.5 - (spacing * 4), feltHeight),
        vector3(spacing, -0.5 - (spacing * 4), feltHeight),
        vector3(spacing * 2, -0.5 - (spacing * 4), feltHeight),
    }

    for i, offset in ipairs(rackOffsets) do
        local model = Config.BallModels[i]
        LoadModel(model)
        local worldPos = GetOffsetFromEntityInWorldCoords(tableEntity, offset.x, offset.y, offset.z)
        local ball = CreateObject(model, worldPos.x, worldPos.y, worldPos.z, true, true, false)
        
        if DoesEntityExist(ball) then
            SetEntityCollision(ball, true, true)
            -- Use physics
            ActivatePhysics(ball)
            table.insert(ballProps, ball)
            if model == `prop_poolball_8` then
                eightBallEntity = ball
            end
        end
    end
end

function CheckPockets(ball, tableEntity)
    if not DoesEntityExist(ball) or not DoesEntityExist(tableEntity) then return false end
    local ballCoords = GetEntityCoords(ball)
    local localCoords = GetOffsetFromEntityGivenWorldCoords(tableEntity, ballCoords.x, ballCoords.y, ballCoords.z)

    for _, pocketPos in ipairs(POCKETS) do
        if #(localCoords - pocketPos) < 0.12 then
            return true
        end
    end
    return false
end

function PotBall(ball)
    local isEightBall = (ball == eightBallEntity)
    local isCueBall = (ball == ballProps[1])
    
    if isCueBall then
        -- Respawn cue ball logic or foul
        QBCore.Functions.Notify("Scratch! Cue ball potted.", "error")
        -- Reset cue ball position
        local tableCoords = GetEntityCoords(currentTable)
        local respawnPos = GetOffsetFromEntityInWorldCoords(currentTable, 0.0, 0.5, Config.FeltHeight)
        SetEntityCoords(ball, respawnPos.x, respawnPos.y, respawnPos.z)
        SetEntityVelocity(ball, 0.0, 0.0, 0.0)
        return false
    end

    local ballId = ObjToNet(ball)
    if DoesEntityExist(currentTable) then
        local tableState = Entity(currentTable).state
        local currentPotted = tableState.pottedBalls or {}
        table.insert(currentPotted, ballId)
        tableState:set('pottedBalls', currentPotted, true)
    end

    local remainingBalls = 0
    for i=2, #ballProps do
        if DoesEntityExist(ballProps[i]) and ballProps[i] ~= ball then
            remainingBalls = remainingBalls + 1
        end
    end

    TriggerServerEvent('jh-billiards:server:processPot', currentTableNetId, isEightBall, remainingBalls)
    DeleteObject(ball)
    return true
end

function MonitorBallMovement()
    shotActive = true
    CreateThread(function()
        local moving = true
        while moving do
            Wait(100)
            moving = false
            local pottedThisTick = 0

            for i, ball in ipairs(ballProps) do
                if DoesEntityExist(ball) then
                    local velocity = GetEntityVelocity(ball)
                    if #(velocity) > 0.01 then
                        moving = true
                        -- Basic rail bounce logic if native physics fails or needs help
                        local ballCoords = GetEntityCoords(ball)
                        local localCoords = GetOffsetFromEntityGivenWorldCoords(currentTable, ballCoords.x, ballCoords.y, ballCoords.z)
                        
                        if math.abs(localCoords.x) > Config.TableWidth or math.abs(localCoords.y) > Config.TableLength then
                            local newVel = velocity * Config.BounceDamping
                            if math.abs(localCoords.x) > Config.TableWidth then newVel = vector3(-newVel.x, newVel.y, newVel.z) end
                            if math.abs(localCoords.y) > Config.TableLength then newVel = vector3(newVel.x, -newVel.y, newVel.z) end
                            SetEntityVelocity(ball, newVel.x, newVel.y, newVel.z)
                        end
                    end

                    if CheckPockets(ball, currentTable) then
                        if PotBall(ball) then
                            pottedThisTick = pottedThisTick + 1
                        end
                    end
                end
            end
        end

        shotActive = false
        if isMyTurn and currentTableNetId then
            TriggerServerEvent('jh-billiards:server:endShot', currentTableNetId, 0) -- Simplified for now
        end
    end)
end

function TakeShot(yaw, power)
    local cueBall = ballProps[1]
    if not DoesEntityExist(cueBall) then return end

    NetworkRequestControlOfEntity(cueBall)
    
    local angleRad = math.rad(yaw)
    local forceX = math.sin(angleRad) * -(power * 0.2)
    local forceY = math.cos(angleRad) * (power * 0.2)

    ApplyForceToEntity(cueBall, 1, forceX, forceY, 0.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    MonitorBallMovement()
end

function UpdateFreeFormCamera(cueBall)
    if not DoesEntityExist(cueBall) then return end
    local ballCoords = GetEntityCoords(cueBall)

    local mouseX = GetControlNormal(0, 1) * -5.0
    cameraYaw = cameraYaw + mouseX

    local distance = 1.5
    local height = 0.8
    local offsetX = math.sin(math.rad(cameraYaw)) * distance
    local offsetY = math.cos(math.rad(cameraYaw)) * distance
    local camCoords = vector3(ballCoords.x + offsetX, ballCoords.y + offsetY, ballCoords.z + height)

    SetCamCoord(poolCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(poolCam, ballCoords.x, ballCoords.y, ballCoords.z)

    if poolScaleform then
        BeginScaleformMovieMethod(poolScaleform, "SET_CUE_ROTATION")
        ScaleformMovieMethodAddParamFloat(cameraYaw)
        EndScaleformMovieMethod()
    end
end

function StartPoolGame(tableEntity)
    if isPlaying then return end
    
    currentTable = tableEntity
    currentTableNetId = ObjToNet(tableEntity)
    local tableCoords = GetEntityCoords(tableEntity)
    
    LoadPoolScaleform()
    TogglePoolCam(true, tableCoords)
    SpawnPoolBalls(tableEntity)
    
    isPlaying = true
    isMyTurn = true

    CreateThread(function()
        while isPlaying do
            Wait(0)
            
            -- Disable standard controls
            DisableControlAction(0, 24, true) 
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 22, true)

            if isMyTurn and not shotActive then
                UpdateFreeFormCamera(ballProps[1])

                if IsDisabledControlPressed(0, Config.Controls.Power) then
                    currentPower = currentPower + 1.0
                    if currentPower > 100.0 then currentPower = 100.0 end
                    
                    if poolScaleform then
                        BeginScaleformMovieMethod(poolScaleform, "SET_CUE_POWER")
                        ScaleformMovieMethodAddParamInt(math.floor(currentPower))
                        EndScaleformMovieMethod()
                    end
                elseif IsDisabledControlReleased(0, Config.Controls.Power) and currentPower > 1.0 then
                    TakeShot(cameraYaw, currentPower)
                    currentPower = 0.0
                end

                if IsControlJustPressed(0, Config.Controls.ToggleGuide) then
                    ToggleGhostGuide()
                end
            end

            if IsControlJustPressed(0, Config.Controls.Exit) then
                isPlaying = false
                TriggerServerEvent('jh-billiards:server:leaveTable', currentTableNetId)
            end

            if poolScaleform then
                DrawScaleformMovieFullscreen(poolScaleform, 255, 255, 255, 255, 0)
            end
        end
        
        TogglePoolCam(false)
        ClearPoolBalls()
        if poolScaleform then
            SetScaleformMovieAsNoLongerNeeded(poolScaleform)
            poolScaleform = nil
        end
    end)
end

-- Events
RegisterNetEvent('jh-billiards:client:setupTurn', function(state)
    isMyTurn = state
    if isMyTurn then
        QBCore.Functions.Notify("Your Turn", "success")
    end
end)

RegisterNetEvent('jh-billiards:client:beginMatch', function(tableNetId, coords)
    local entity = NetToObj(tableNetId)
    if DoesEntityExist(entity) then
        StartPoolGame(entity)
    end
end)

RegisterNetEvent('jh-billiards:client:exitGame', function()
    isPlaying = false
end)

-- Target
exports['qb-target']:AddTargetModel(Config.TableModels, {
    options = {
        {
            type = "client",
            action = function(entity)
                local dialog = exports['qb-input']:ShowInput({
                    header = "Wager Amount",
                    submitText = "Start Game",
                    inputs = {
                        {
                            text = "Bet ($)",
                            name = "bet",
                            type = "number",
                            isRequired = true,
                            default = Config.Fee
                        }
                    }
                })
                if dialog then
                    local bet = tonumber(dialog.bet)
                    QBCore.Functions.TriggerCallback('jh-billiards:server:canPlay', function(canPlay)
                        if canPlay then
                            TriggerServerEvent('jh-billiards:server:joinTable', ObjToNet(entity), bet, GetEntityCoords(entity))
                        else
                            QBCore.Functions.Notify("You need a Pool Cue and enough cash!", "error")
                        end
                    end)
                end
            end,
            icon = "fas fa-poker-chip",
            label = "Play Pool",
        }
    },
    distance = 2.5
})
