Config = {}
Config.EventChance = 0.4 -- 40% chance
Config.CheckInterval = 45000 -- Check every 45 seconds
Config.SpawnDistance = 60.0
Config.Reward = 500

Config.Events = { "mugging", "party", "police_chase", "gang_war" }

-- Blacklisted Zones (X, Y, Z, Radius)
Config.BlacklistedZones = {
    {coords = vec3(441.1, -981.1, 30.6), radius = 100.0, label = "Mission Row PD"},
    {coords = vec3(298.2, -584.5, 43.2), radius = 150.0, label = "Pillbox Medical"},
    {coords = vec3(-1037.1, -2737.5, 13.7), radius = 200.0, label = "LS Airport Spawn"}
}

Config.PoliceModels = { `police`, `police2` }
Config.GangModels = { `g_m_y_ballasout_01`, `g_m_y_famca_01` }
Config.PartyModels = { `a_m_y_beach_01`, `a_f_y_beach_01`, `a_m_y_hipster_01` }
Config.UseDispatch = true
