Config = {}
Config.Debug = false

Config.CaptureTime = 90
Config.ContestDistance = 20.0
Config.DeSpawnDistance = 120.0

Config.DeathLoot = {
    Enabled = true,
    CooldownSeconds = 30,
    MaxDrugStacks = 2,
    MaxItemsPerStack = 5,
    CashPercent = 0.15,
    CashMin = 50,
    CashMax = 350,
    DrugPriority = {
        "cokebaggy",
        "meth",
        "methbag",
        "crack_baggy",
        "weed_brick",
        "weed_baggy",
        "weed",
        "oxy",
        "xtcbaggy",
        "lean",
        "heroin",
        "opium"
    }
}

-- Gang definitions include label, color, and model groups.
Config.Gangs = {
    ["families"] = { label = "Families", color = 18, models = { GetHashKey("g_m_y_famca_01"), GetHashKey("g_m_y_famdnf_01"), GetHashKey("g_m_y_famfor_01"), GetHashKey("g_f_y_families_01") } },
    ["ballas"] = { label = "Ballas", color = 27, models = { GetHashKey("g_m_y_ballaeast_01"), GetHashKey("g_m_y_ballaorig_01"), GetHashKey("g_m_y_ballasout_01"), GetHashKey("g_f_y_ballas_01") } },
    ["vagos"] = { label = "Vagos", color = 46, models = { GetHashKey("g_m_y_mexgoon_01"), GetHashKey("g_m_y_mexgoon_02"), GetHashKey("g_m_y_mexgoon_03"), GetHashKey("g_f_y_vagos_01") } },
    ["marabunta"] = { label = "Marabunta", color = 3, models = { GetHashKey("g_m_y_salvaboss_01"), GetHashKey("g_m_y_salvagoon_01"), GetHashKey("g_m_y_salvagoon_02"), GetHashKey("g_f_y_vagos_01") } },
    ["aztecas"] = { label = "Aztecas", color = 64, models = { GetHashKey("g_m_y_azteca_01"), GetHashKey("g_m_y_pologoon_01"), GetHashKey("g_m_y_pologoon_02") } },
    ["lostmc"] = { label = "Lost MC", color = 40, models = { GetHashKey("g_m_y_lost_01"), GetHashKey("g_m_y_lost_02"), GetHashKey("g_m_y_lost_03"), GetHashKey("g_f_y_lost_01") } },
    ["kkangpae"] = { label = "Kkangpae", color = 11, models = { GetHashKey("g_m_y_korean_01"), GetHashKey("g_m_y_korean_02"), GetHashKey("g_m_y_korlieut_01") } },
    ["armenian"] = { label = "Armenian", color = 39, models = { GetHashKey("g_m_m_armgoon_01"), GetHashKey("g_m_y_armgoon_02") } },
    ["madrazo"] = { label = "Madrazo", color = 5, models = { GetHashKey("g_m_m_cartelguards_01"), GetHashKey("g_m_y_mexoti_01") } },
    ["triads"] = { label = "Triads", color = 1, models = { GetHashKey("g_m_y_strp_01"), GetHashKey("g_m_y_strp_02"), GetHashKey("g_f_y_vagos_01") } },
}

-- Initial turf control assignments, now aligned with Los Santos map locations.
Config.Territories = {
    { id = "grove_st", label = "Grove Street", owner = "ballas", coords = vector3(120.0, -1935.0, 20.0), radius = 70.0 }, -- compact residential block
    { id = "chamberlain", label = "Chamberlain Hills", owner = "families", coords = vector3(-20.0, -1445.0, 31.0), radius = 120.0 }, -- larger hill neighborhood
    { id = "rancho", label = "Rancho Projects", owner = "vagos", coords = vector3(335.0, -2005.0, 21.0), radius = 110.0 }, -- mid-sized project area
    { id = "el_burro", label = "El Burro Heights", owner = "marabunta", coords = vector3(1265.0, -1625.0, 45.0), radius = 140.0 }, -- expansive industrial district
    { id = "stab_city", label = "Stab City", owner = "lostmc", coords = vector3(70.0, 3140.0, 40.0), radius = 130.0 }, -- large trailer park zone
    { id = "little_seoul", label = "Little Seoul", owner = "kkangpae", coords = vector3(-700.0, -860.0, 24.0), radius = 95.0 }, -- compact commercial/residential district
    { id = "chinatown", label = "Chinatown", owner = "triads", coords = vector3(-255.0, -1005.0, 34.0), radius = 85.0 }, -- dense urban core
    { id = "la_puerta", label = "La Puerta", owner = "madrazo", coords = vector3(-1076.0, -285.0, 37.0), radius = 105.0 }, -- port and industrial area
}
