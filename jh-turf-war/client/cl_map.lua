local zoneBlips = {}

-- Function to draw or update a zone blip
function UpdateZoneBlip(zoneName, ownerGang)
    -- Remove existing blip if it exists
    if zoneBlips[zoneName] then
        RemoveBlip(zoneBlips[zoneName])
        zoneBlips[zoneName] = nil
    end

    -- We only draw a blip if the zone is owned by a recognized gang
    if ownerGang and ownerGang ~= "none" then
        local zoneData = nil
        for _, turf in pairs(Config.Territories or {}) do
            if turf.id == zoneName then
                zoneData = turf
                break
            end
        end

        local gangData = Config.Gangs[ownerGang]

        if zoneData and gangData then
            -- Create the colored radius
            local blip = AddBlipForRadius(zoneData.coords.x, zoneData.coords.y, zoneData.coords.z, zoneData.radius)
            
            -- Set visuals based on your gang config colors
            SetBlipColour(blip, gangData.color)
            SetBlipAlpha(blip, 128) -- 50% transparency (0-255)
            SetBlipAsShortRange(blip, true)
            
            zoneBlips[zoneName] = blip
        end
    end
end

-- Sync all zones when the player loads in
RegisterNetEvent('jh-turf-war:client:SyncAllZones', function(allZones)
    for zoneName, owner in pairs(allZones) do
        UpdateZoneBlip(zoneName, owner)
    end
end)

-- Live update when a territory is captured
RegisterNetEvent('jh-turf-war:client:ZoneCaptured', function(zoneName, newOwner)
    UpdateZoneBlip(zoneName, newOwner)
end)