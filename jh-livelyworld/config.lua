Config = {}

-- General Settings
Config.Debug = true             -- Set to false for production
Config.UpdateInterval = 1500    -- (ms)
Config.EventFrequency = 60000   -- Check for events every 60s
Config.EventChance = 40         -- 40% chance
Config.MaxConcurrentEvents = 4 
Config.DespawnTime = 180000     -- 3 minutes
Config.InteractionDist = 10.0   

-- Relationship Settings (5 = Hate)
Config.Relationships = {
    {`COP`, `AMBIENT_GANG_LOST`, 5},
    {`COP`, `AMBIENT_GANG_BALLAS`, 5},
    {`AMBIENT_GANG_BALLAS`, `AMBIENT_GANG_FAMILIES`, 5}
}

-- Positions & Assets
Config.Banks = {
    vector3(149.25, -1038.53, 29.34),   -- Legion
    vector3(-1212.44, -330.55, 37.79),  -- Rockford
    vector3(-2962.33, 482.02, 15.70),   -- Great Ocean
    vector3(1175.75, 2706.71, 38.09)    -- Route 68
}

Config.RaceCars = {`zentorno`, `t20`, `adder`, `jester`}
Config.PoliceCars = {`police`, `police2`, `police3`}
Config.WorkVehicles = {`rubble`, `tiptruck`, `burrito3`}
Config.DrunkCars = {`emperor`, `stanier`, `journey`}
Config.TowTrucks = {`towtruck`, `towtruck2`}
Config.MovingVans = {`mule`, `benson`, `boxville2`}
Config.HeliModels = {`polmav`, `buzzard2`, `frogger`}
Config.PlaneModels = {`luxor`, `shamal`, `mammatus`}
Config.Animals = {`a_c_deer`, `a_c_coyote`, `a_c_boar`}