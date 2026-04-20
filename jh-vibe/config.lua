Config = {}
Config.PoliceRisk = true -- Enable police detection
Config.RequireProtection = true -- Require condom item for full service
Config.ProtectionItem = 'condom' -- Item checked before protected services
Config.MotelLocation = vector3(312.5, -209.5, 54.0) -- Legacy single motel reference
Config.MotelLocations = {
    {
        coords = vector3(312.5, -209.5, 54.0),
        interior = vector3(315.84, -193.62, 54.23),
        interiorOffset = vector3(316.34, -193.22, 54.23)
    }
}

Config.Motels = {
    ['pink_cage'] = {
        entry = vector3(312.5, -209.5, 54.0), -- Outside door
        inside = vector4(151.45, -1007.57, -98.99, 180.0), -- Inside (Generic Apartment/Motel)
        bed = vector3(151.5, -1007.5, -98.5) -- The actual bed location
    }
}

Config.InteriorServices = {
    ['bed_sex'] = { 
        price = 200, 
        duration = 30000, 
        animDict = "rcmpaparazzo_2", 
        animPlayer = "shag_loop_a", 
        animPed = "shag_loop_b" 
    }
}

Config.MotelBlip = {
    sprite = 475, -- Hotel/Building icon
    color = 3,    -- Light Blue
    scale = 0.8,
    label = "Available Motel Room"
}

Config.BaseAcceptChance = 50 -- Base percentage chance (50/50)
Config.NiceCarBonus = 25    -- Adds 25% if in a Super or Sport car
Config.CheapCarPenalty = 15 -- Subtracts 15% if in a "junk" car (utility/vans)
Config.RobberyChance = 15 -- 15% chance she tries to rob you
Config.RobberyWeapons = {
    "WEAPON_KNIFE",
    "WEAPON_PISTOL",
    "WEAPON_SWITCHBLADE"
}

-- Add a "Fear" factor: If player is in a scary car or has a weapon out, she might not rob
Config.AntiRobClass = 7 -- Super cars (Too fast to escape from)

Config.Models = {
    ["s_f_y_hooker_01"] = true, -- Standard Street (Low-End)
    ["s_f_y_hooker_02"] = true, -- Standard Street (Mid-End)
    ["s_f_y_hooker_03"] = true, -- Standard Street (High-End)
    ["s_f_y_hooker_04"] = true, -- Vinewood / High-Class Variant
    ["s_f_y_hooker_05"] = true, -- Additional Lore Variant
    ["s_f_m_maid_01"] = false,  -- (Optional) Included but disabled by default
}

-- The rest of your alias logic remains the same
Config.InteractModels = {}
for model, enabled in pairs(Config.Models) do
    if enabled then
        Config.InteractModels[model] = true
        Config.InteractModels[joaat(model)] = true -- Ensures both string and hash work
    end
end

Config.Services = {
    ['handjob'] = { price = 50, duration = 10000, protection = false, animDict = "mini@prostitutes@sexlow_veh", animPlayer = "low_car_sex_loop_player", animPed = "low_car_sex_loop_female" },
    ['blowjob'] = { price = 70, duration = 15000, protection = false, animDict = "mini@prostitutes@sexmid_veh", animPlayer = "mid_car_sex_loop_player", animPed = "mid_car_sex_loop_female" },
    ['sex'] = { price = 100, duration = 20000, protection = true, animDict = "mini@prostitutes@sexhigh_veh", animPlayer = "high_car_sex_loop_player", animPed = "high_car_sex_loop_female" }
}