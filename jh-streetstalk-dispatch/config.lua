Config = {}

-- Heat thresholds
Config.HeatLevelPatrol = 40   -- When ambient cops start "looking"
Config.HeatLevelChase = 75    -- When cops become aggressive on sight
Config.ChatterProbability = 0.65 -- Chance dispatch chatter plays when a violation is noticed
Config.BaseDetectionRange = 22.0 -- Base visual detection distance for patrols
Config.MaxDetectionRange = 85.0  -- Max detection distance when heat/speed are high
Config.SearchUpdateInterval = 4000 -- How often patrols refresh search routes
Config.ForgetTargetTime = 12000 -- How long patrols search the last known position
Config.WarningDuration = 5000 -- Time patrols spend warning before attempting a stop
Config.StopDuration = 7000 -- Time patrols spend trying to stop the player before chasing
Config.ComplianceSpeed = 8.0 -- Speed below which the player is treated as complying
Config.ForceSafeUnitModels = true -- Emergency compatibility mode for guaranteed NPC spawns
Config.SafePedModel = GetHashKey('s_m_y_cop_01')
Config.SafeVehicleModel = GetHashKey('police')

Config.DispatchChatter = {
    warning = {
        '~b~Dispatch:~s~ {district} unit is moving in to identify the suspect vehicle.',
        '~b~Dispatch:~s~ Officer has visual contact. Stand by for compliance check.'
    },
    attempt_stop = {
        '~b~Dispatch:~s~ {district} unit is attempting a traffic stop.',
        '~b~Dispatch:~s~ Suspect vehicle ordered to pull over.'
    },
    compliant = {
        '~b~Dispatch:~s~ Vehicle is slowing. Units are holding position.',
        '~b~Dispatch:~s~ Driver appears to be complying. Monitoring situation.'
    },
    search = {
        '~b~Dispatch:~s~ Unit lost direct sight. Searching the last known area.',
        '~b~Dispatch:~s~ Patrol is sweeping nearby streets for the suspect.'
    },
    chase = {
        '~b~Dispatch:~s~ Suspect is fleeing. Pursuit authorized.',
        '~b~Dispatch:~s~ Vehicle failed to stop. Engaging in active pursuit.'
    }
}

Config.Highways = {
    [GetHashKey('great_ocean_hwy')] = true,
    [GetHashKey('senora_fwy')] = true,
    [GetHashKey('los_santos_fwy')] = true,
    [GetHashKey('palomino_fwy')] = true
}

Config.Districts = {
    ['LSPD'] = {
        name = "LSPD",
        peds = { GetHashKey('s_m_y_cop_01'), GetHashKey('s_m_y_hwaycop_01') },
        vehicles = { GetHashKey('police'), GetHashKey('police2'), GetHashKey('police3') },
        spawnPoints = {
            vector4(441.8, -982.0, 30.7, 180.0), -- Mission Row
            vector4(-1108.0, -845.0, 19.0, 130.0) -- Vespucci
        }
    },
    ['BCSO'] = {
        name = "Sheriff",
        peds = { GetHashKey('s_m_y_sheriff_01') },
        vehicles = { GetHashKey('sheriff'), GetHashKey('sheriff2'), GetHashKey('pranger') },
        spawnPoints = {
            vector4(1853.0, 3686.0, 34.0, 30.0), -- Sandy Shores
            vector4(-443.0, 6012.0, 31.0, 315.0) -- Paleto Bay
        }
    },
    ['STATE'] = {
        name = "State Trooper",
        peds = { GetHashKey('s_m_y_cop_01') },
        vehicles = { GetHashKey('police4'), GetHashKey('police3') },
        spawnPoints = {
            vector4(2500.0, 4000.0, 38.0, 0.0), -- Senora Fwy Turnaround
            vector4(-400.0, -2100.0, 10.0, 0.0) -- Terminal Freeway
        }
    }
}

Config.Fines = {
    -- Minor Violations ($150 - $300)
    ['using_phone']      = { label = "Distracted Driving", amount = 150, heat = 2 },
    ['no_helmet']        = { label = "No Helmet", amount = 200, heat = 1 },
    ['damaged_vehicle']  = { label = "Unsafe Vehicle", amount = 250, heat = 3 },
    ['stop_sign']        = { label = "Ran Stop Sign", amount = 300, heat = 4 },

    -- Major Violations ($450 - $800)
    ['speeding']         = { label = "Exceeding Speed Limit", amount = 450, heat = 5 },
    ['tailgating']       = { label = "Following Too Closely", amount = 500, heat = 4 },
    ['red_light']        = { label = "Ran Red Light", amount = 650, heat = 6 },
    ['wrong_way']        = { label = "Driving Against Traffic", amount = 800, heat = 8 },

    -- Reckless Endangerment ($1,000 - $2,500)
    ['drifting']         = { label = "Stunt Driving (Drifting)", amount = 1200, heat = 12 },
    ['wheelie']          = { label = "Stunt Driving (Wheelie)", amount = 1000, heat = 10 },
    ['sidewalk']         = { label = "Driving on Sidewalk", amount = 1500, heat = 20 },
    ['collision']        = { label = "Vehicular Collision", amount = 2500, heat = 25 },
}