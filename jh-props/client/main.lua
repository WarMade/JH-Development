local QBCore = exports['qb-core']:GetCoreObject()
local searchedEntities = {}

local PropSlots = {
    [0] = true, -- Hats
    [1] = true, -- Glasses
    [2] = true, -- Ears
    [6] = true, -- Watches
    [7] = true, -- Bracelets
}

local function SetPedAppearanceSlot(ped, slot, drawable, texture, palette)
    if not DoesEntityExist(ped) then
        return
    end

    drawable = drawable or 0
    texture = texture or 0
    palette = palette or 0

    if PropSlots[slot] then
        if drawable < 0 then
            ClearPedProp(ped, slot)
        else
            SetPedPropIndex(ped, slot, drawable, texture, true)
        end
        return
    end

    SetPedComponentVariation(ped, slot, drawable, texture, palette)
end

local function EnsureNetworkedEntity(entity)
    if not DoesEntityExist(entity) then
        return false, nil
    end

    local timeout = 0
    while not NetworkGetEntityIsNetworked(entity) and timeout < 20 do
        Wait(10)
        timeout = timeout + 1
    end

    if not NetworkGetEntityIsNetworked(entity) then
        return false, nil
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId ~= 0 then
        SetNetworkIdExistsOnAllMachines(netId, true)
        return true, netId
    end

    return false, nil
end

local function CreateNetworkedProp(modelHash, x, y, z, heading)
    local prop = CreateObject(modelHash, x, y, z, true, true, false)

    if heading then
        SetEntityHeading(prop, heading)
    end

    local ok, netId = EnsureNetworkedEntity(prop)
    if not ok then
        DeleteEntity(prop)
        return nil, nil
    end

    return prop, netId
end

exports('SetPedAppearanceSlot', SetPedAppearanceSlot)
exports('CreateNetworkedProp', CreateNetworkedProp)

local function IsValidQBItem(itemName)
    return itemName and QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[itemName] ~= nil
end

local function GetPropWeight(modelName)
    for keyword, weight in pairs(Config.PropWeights or {}) do
        if string.find(modelName, keyword, 1, true) then
            return weight
        end
    end

    return 1.0
end

exports['qb-target']:AddGlobalObject({
    options = {
        {
            type = "client",
            event = "jh-props:client:Interact",
            icon = "fas fa-hand-paper",
            label = "Interact",
            canInteract = function(entity)
                return GetEntityType(entity) == 3 and not IsEntityAttachedToAnyPed(entity)
            end,
        },
    },
    distance = 2.0
})

local function DetermineAction(entity, modelName)
    local foundAction = false

    for keyword, item in pairs(Config.Archetypes.pickups or {}) do
        if string.find(modelName, keyword, 1, true) and IsValidQBItem(item) then
            PickupObject(entity, item)
            foundAction = true
            break
        end
    end

    if not foundAction then
        for keyword, lootType in pairs(Config.Archetypes.containers or {}) do
            if string.find(modelName, keyword, 1, true) then
                SearchObject(entity, lootType)
                foundAction = true
                break
            end
        end
    end

    if not foundAction then
        QBCore.Functions.Notify("You can't do much with this.", "error")
    end
end

RegisterNetEvent('jh-props:client:Interact', function(data)
    local entity = data.entity
    local modelName = string.lower(GetEntityArchetypeName(entity) or "")
    local physicalWeight = GetPropWeight(modelName)

    if physicalWeight > (Config.MaxPickupWeight or 15.0) then
        QBCore.Functions.Notify("This is too heavy/bulky to carry!", "error")
        return
    end

    DetermineAction(entity, modelName)
end)

function PickupObject(entity, item)
    QBCore.Functions.Progressbar("pickup_prop", "Picking up...", 1000, false, true, {
        disableMovement = true,
    }, { animDict = "pickup_object", anim = "pickup_low" }, {}, {}, function()
        if not NetworkHasControlOfEntity(entity) then
            NetworkRequestControlOfEntity(entity)
            local timeout = 0
            while not NetworkHasControlOfEntity(entity) and timeout < 100 do
                Wait(10)
                timeout = timeout + 1
            end
        end

        local ok, netId = EnsureNetworkedEntity(entity)
        if not ok then
            QBCore.Functions.Notify("This object could not be synced.", "error")
            return
        end

        TriggerServerEvent('jh-props:server:ProcessAction', netId, "pickup", item)
    end)
end

function SearchObject(entity, lootType)
    if searchedEntities[entity] then
        QBCore.Functions.Notify("This has already been searched/emptied.", "error")
        return
    end

    if lootType == "valuables" and GetResourceState('qb-lock') == 'started' then
        local success = exports['qb-lock']:StartLockPickCircle(3, 20)
        if not success then
            QBCore.Functions.Notify("You failed to crack the lock.", "error")
            return
        end
    end

    QBCore.Functions.Progressbar("search_prop", "Searching...", 3000, false, true, {
        disableMovement = true,
    }, { animDict = "anim@amb@business@weed@weed_inspecting_lo_med_hi@", anim = "weed_stand_check_v2_inspect_v2_pa_low" }, {}, {}, function()
        if not NetworkHasControlOfEntity(entity) then
            NetworkRequestControlOfEntity(entity)
            local timeout = 0
            while not NetworkHasControlOfEntity(entity) and timeout < 100 do
                Wait(10)
                timeout = timeout + 1
            end
        end

        local ok, netId = EnsureNetworkedEntity(entity)
        if not ok then
            QBCore.Functions.Notify("This object could not be synced.", "error")
            return
        end

        searchedEntities[entity] = true
        TriggerServerEvent('jh-props:server:ProcessAction', netId, "search", lootType)
    end)
end