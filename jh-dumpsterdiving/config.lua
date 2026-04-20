Config = {}

Config.SearchTime = 7000
Config.Cooldown = 20 -- Minutes
Config.Skillbar = 'qb-skillbar'

-- ANIMATIONS
Config.Animations = {
    { dict = "amb@prop_human_bum_bin@base", anim = "base", label = "Classic Dive" },
    { dict = "anim@amb@business@weed@weed_inspecting_lo_med_hi@", anim = "inspect_low_idle01_inspector", label = "Low Inspect" },
    { dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", anim = "machinic_loop_mechl", label = "Rummaging" },
    { dict = "amb@medic@standing@tendtodead@idle_a", anim = "idle_a", label = "Low Kneel Search" }
}

Config.MultiLootChances = {
    [4] = 3,  
    [3] = 10, 
    [2] = 25  
}

Config.DumpsterModels = {
    GetHashKey("prop_dumpster_01a"), GetHashKey("prop_dumpster_02a"), GetHashKey("prop_dumpster_02b"),
    GetHashKey("prop_dumpster_3a"), GetHashKey("prop_dumpster_4a"), GetHashKey("prop_dumpster_4b"),
}

Config.Props = {
    { model = GetHashKey("prop_cs_rub_binbag_01"), bone = 57005, pos = vector3(0.12, 0.0, 0.0), rot = vector3(-90.0, 0.0, 0.0) }
}

Config.RealWorldItems = {
    "empty_beer_bottle", "old_shoe", "plastic_bottle", "crumpled_paper",
    "used_napkin", "broken_glass", "rusty_nail", "chewed_gum",
    "old_newspaper", "dry_battery", "empty_can", "torn_rag"
}

Config.AreaLoot = {
    ['Richman'] = {
        label = "Richman Mansions",
        coords = vector3(-1182.0, 563.0, 102.0),
        radius = 350.0,
        loot = {
            ["valuable"] = { chance = {0, 70}, items = {"rolex", "diamond_ring", "goldchain", "iphone", "laptop", "samsung_phone"} },
            ["cash"] = { chance = {71, 100}, min = 150, max = 400 }
        }
    },
    ['RockfordHills'] = {
        label = "Rockford Hills",
        coords = vector3(-760.0, 300.0, 85.0),
        radius = 400.0,
        loot = {
            ["valuable"] = { chance = {0, 60}, items = {"wallet", "creditcard", "iphone", "tablet"} },
            ["food"] = { chance = {61, 85}, items = {"coffee", "sandwich", "water_bottle"} },
            ["cash"] = { chance = {86, 100}, min = 50, max = 200 }
        }
    },
    ['Davis'] = {
        label = "Davis / South Central",
        coords = vector3(100.0, -1500.0, 30.0),
        radius = 450.0,
        loot = {
            ["illegal"] = { chance = {0, 65}, items = {"pistol_ammo", "meth", "markedbills", "weed_baggy", "joint"} },
            ["rare"] = { chance = {66, 90}, items = {"weapon_pistol", "sub_ammo", "bandage"} },
            ["cash"] = { chance = {91, 100}, min = 5, max = 45 }
        }
    },
    ['ElysianIsland'] = {
        label = "Elysian Island",
        coords = vector3(500.0, -3000.0, 5.0),
        radius = 800.0,
        loot = {
            ["industrial"] = { chance = {0, 100}, items = {"metalscrap", "aluminum", "plastic", "iron", "glass", "copper", "steel"} }
        }
    },
    ['SandyShores'] = {
        label = "Sandy Shores",
        coords = vector3(1850.0, 3700.0, 33.0),
        radius = 600.0,
        loot = {
            ["illegal"] = { chance = {0, 50}, items = {"meth", "beer", "joint", "empty_weed_bag"} },
            ["industrial"] = { chance = {51, 90}, items = {"metalscrap", "plastic", "copper"} },
            ["cash"] = { chance = {91, 100}, min = 2, max = 30 }
        }
    },
    ['Default'] = {
        label = "The City",
        loot = {
            ["trash"] = { chance = {0, 50}, items = {"plastic", "iron", "metalscrap"} },
            ["food"] = { chance = {51, 90}, items = {"sandwich", "tosti", "water_bottle", "kurkakola"} },
            ["cash"] = { chance = {91, 100}, min = 5, max = 25 }
        }
    }
}

-- SCAVENGER NPC (SILAS)
Config.Scavenger = {
    Model = GetHashKey("u_m_m_filmdirector_01"),
    Phone = "555-0199",
    ContactName = "Old Man Silas",
    RelocateMinutes = 30,
    Locations = {
        vector4(351.48, -1892.51, 29.04, 154.0), -- Rancho Alley (Outside)
        vector4(-301.7, -1994.5, 20.5, 30.0),   -- Banning Yard (Open Area)
        vector4(128.8, -1454.2, 29.3, 230.0),   -- Strawberry Underpass (Clear)
    },
    Blip = {
        Sprite = 464, 
        Color = 5,   
        Scale = 0.8,
        Label = "Old Man Silas (Scavenger)"
    },
    BuyRates = {
        ["rolex"] = 400,
        ["goldchain"] = 250,
        ["iphone"] = 150,
        ["laptop"] = 300,
        ["diamond_ring"] = 500,
        ["tablet"] = 125,
        ["wallet"] = 50,
    }
}

-- POLICE & NPC REACTIONS
Config.Reactions = {
    Enabled = true,
    Chance = 30, -- 30% chance an NPC reacts if they are close
    AggroChance = 10, -- 10% chance they actually pull a weapon/fight you
    Radius = 15.0, -- How close an NPC needs to be to notice
    Voices = {
        "GENERIC_DISGUSTED_MED",
        "GENERIC_INSULT_HIGH",
        "SHOUT_THREAT_LOUD",
        "TREVOR_ABUSE_PED"
    },
    Areas = {
        {
            Name = "Mission Row Police",
            Type = "police",
            Coords = vector3(425.1, -979.5, 30.7),
            Radius = 120.0,
            Chance = 65,
            AggroChance = 35,
            Notify = "An officer is moving in on you!",
            Weapons = {"WEAPON_NIGHTSTICK", "WEAPON_PISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "GENERIC_FRIGHTENED_HIGH", "SHOUT_THREAT_LOUD"}
        },
        {
            Name = "Vinewood Police Presence",
            Type = "police",
            Coords = vector3(635.9, 1.4, 82.8),
            Radius = 140.0,
            Chance = 55,
            AggroChance = 25,
            Notify = "Security in the area is closing in!",
            Weapons = {"WEAPON_NIGHTSTICK", "WEAPON_STUNGUN", "WEAPON_PISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "GENERIC_SHOCKED_HIGH", "SHOUT_THREAT_LOUD"}
        },
        {
            Name = "Downtown Transit Patrol",
            Type = "police",
            Coords = vector3(232.5, -791.2, 30.6),
            Radius = 150.0,
            Chance = 50,
            AggroChance = 20,
            Notify = "Transit patrol is closing in on you!",
            Weapons = {"WEAPON_NIGHTSTICK", "WEAPON_STUNGUN", "WEAPON_PISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "GENERIC_FRIGHTENED_HIGH", "SHOUT_THREAT_LOUD"}
        },
        {
            Name = "Vespucci Beach Patrol",
            Type = "police",
            Coords = vector3(-1193.5, -890.7, 13.9),
            Radius = 160.0,
            Chance = 48,
            AggroChance = 18,
            Notify = "Beach patrol is moving toward you!",
            Weapons = {"WEAPON_NIGHTSTICK", "WEAPON_STUNGUN", "WEAPON_PISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "GENERIC_SHOCKED_HIGH", "SHOUT_THREAT_LOUD"}
        },
        {
            Name = "Paleto Bay Sheriff",
            Type = "police",
            Coords = vector3(-441.0, 6020.0, 31.5),
            Radius = 150.0,
            Chance = 55,
            AggroChance = 25,
            Notify = "The sheriff is onto you!",
            Weapons = {"WEAPON_NIGHTSTICK", "WEAPON_PISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "SHOUT_THREAT_LOUD", "GENERIC_FRIGHTENED_HIGH"}
        },
        {
            Name = "Davis Gang Turf",
            Type = "gang",
            Coords = vector3(85.0, -1958.0, 20.7),
            Radius = 220.0,
            Chance = 70,
            AggroChance = 45,
            Notify = "The neighborhood is turning hostile!",
            Weapons = {"WEAPON_BAT", "WEAPON_KNIFE", "WEAPON_PISTOL"},
            Voices = {"TREVOR_ABUSE_PED", "GENERIC_INSULT_HIGH", "SHOUT_THREAT_LOUD"}
        },
        {
            Name = "Rancho Block Watch",
            Type = "gang",
            Coords = vector3(350.0, -2020.0, 22.3),
            Radius = 220.0,
            Chance = 68,
            AggroChance = 42,
            Notify = "Locals on the block are moving in!",
            Weapons = {"WEAPON_BAT", "WEAPON_KNIFE", "WEAPON_PISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "SHOUT_THREAT_LOUD", "TREVOR_ABUSE_PED"}
        },
        {
            Name = "Banning / Docks Crew",
            Type = "gang",
            Coords = vector3(-420.0, -1688.0, 19.0),
            Radius = 220.0,
            Chance = 60,
            AggroChance = 40,
            Notify = "Dock workers and locals are coming at you!",
            Weapons = {"WEAPON_WRENCH", "WEAPON_BAT", "WEAPON_PISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "SHOUT_THREAT_LOUD", "TREVOR_ABUSE_PED"}
        },
        {
            Name = "La Mesa Crew",
            Type = "gang",
            Coords = vector3(810.0, -950.0, 26.3),
            Radius = 210.0,
            Chance = 62,
            AggroChance = 38,
            Notify = "The East Side crew is getting aggressive!",
            Weapons = {"WEAPON_BAT", "WEAPON_CROWBAR", "WEAPON_PISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "SHOUT_THREAT_LOUD", "GENERIC_DISGUSTED_MED"}
        },
        {
            Name = "Mirror Park Locals",
            Type = "gang",
            Coords = vector3(1210.0, -470.0, 66.2),
            Radius = 190.0,
            Chance = 45,
            AggroChance = 20,
            Notify = "The locals are confronting you!",
            Weapons = {"WEAPON_BAT", "WEAPON_KNIFE"},
            Voices = {"GENERIC_DISGUSTED_MED", "GENERIC_INSULT_HIGH", "SHOUT_THREAT_LOUD"}
        },
        {
            Name = "Rockford Hills Security",
            Type = "gang",
            Coords = vector3(-760.0, 300.0, 85.0),
            Radius = 180.0,
            Chance = 42,
            AggroChance = 15,
            Notify = "Private security is confronting you!",
            Weapons = {"WEAPON_NIGHTSTICK", "WEAPON_PISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "GENERIC_FRIGHTENED_HIGH", "SHOUT_THREAT_LOUD"}
        },
        {
            Name = "Sandy Shores Outskirts",
            Type = "gang",
            Coords = vector3(1848.0, 3678.0, 33.7),
            Radius = 260.0,
            Chance = 55,
            AggroChance = 35,
            Notify = "The desert locals do not like strangers!",
            Weapons = {"WEAPON_BAT", "WEAPON_KNIFE", "WEAPON_SNSPISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "SHOUT_THREAT_LOUD", "GENERIC_DISGUSTED_MED"}
        },
        {
            Name = "Harmony Trouble Spot",
            Type = "gang",
            Coords = vector3(571.0, 2730.0, 42.0),
            Radius = 220.0,
            Chance = 50,
            AggroChance = 28,
            Notify = "The locals here are getting rowdy!",
            Weapons = {"WEAPON_BAT", "WEAPON_KNIFE", "WEAPON_SNSPISTOL"},
            Voices = {"GENERIC_INSULT_HIGH", "GENERIC_DISGUSTED_MED", "SHOUT_THREAT_LOUD"}
        },
        {
            Name = "Elysian Scrap Yard",
            Type = "gang",
            Coords = vector3(520.0, -3045.0, 6.0),
            Radius = 260.0,
            Chance = 65,
            AggroChance = 40,
            Notify = "The scrapyard crew is getting violent!",
            Weapons = {"WEAPON_WRENCH", "WEAPON_CROWBAR", "WEAPON_PISTOL"},
            Voices = {"TREVOR_ABUSE_PED", "SHOUT_THREAT_LOUD", "GENERIC_INSULT_HIGH"}
        }
    }
}

Config.Effects = {
    Enabled = true,
    Dict = "core",
    Name = "ent_dst_dust",
    Scale = 1.0
}

Config.Police = {
    Enabled = true,
    AlertScript = "ps-dispatch", -- or 'qb-default'
    AreaChance = {
        ['Richman'] = 0.25,
        ['RockfordHills'] = 0.20,
        ['Davis'] = 0.05,
        ['Default'] = 0.10
    }
}

-- EXPERIENCE SYSTEM
Config.Experience = {
    Enabled = true,
    MaxLevel = 10,
    XPPerDive = 15,
    SkillBonus = 1.5, -- Extra width on skillbar per level
    LootBonus = 1.05
}
