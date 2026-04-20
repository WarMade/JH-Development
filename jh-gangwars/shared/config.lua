Config = {}
Config.PoliceChance = 15
Config.BonusMultiplier = 1.25
Config.LocateCommand = "locate_dealers"

Config.PassiveSaleInterval = 5 * 60000 -- How often the dealer attempts a sale (5 mins)
Config.PassiveSaleChance = 70 -- % Chance a sale actually occurs every interval
Config.PoliceCallChance = 15  -- % Chance a bystander calls the cops during a sale
Config.DispatchMessage = "10-13: Suspicious activity reported. Possible narcotics distribution."

Config.Reputation = {
    MaxRep = 1000,
    BonusPerSale = 2,       -- Rep gained per successful passive sale
    LossOnPolice = 50,      -- Rep lost if cops are called to the area
    PriceMultiplier = 0.05, -- 5% price increase for every 100 Rep
    SaleChanceBonus = 2     -- 2% extra sale chance for every 100 Rep
}

Config.CornerItems = {
    ["weed_skunk"] = true,
    ["weed_og-kush"] = true,
    ["coke_small_baggy"] = true,
    ["meth"] = true,
    -- Add any other retail units here
}

Config.DrugItemPatterns = { -- Keywords to look for in item names/categories
    "weed", "coke", "meth", "crack", "heroin", "oxy", "ecstasy"
}

-- Fallback/Manual list for items that don't fit the naming pattern
Config.ManualDrugList = {
    ["liquid_acid"] = true,
    ["xanax"] = true
}

Config.DrugDiscovery = {
    -- Keywords found in item names
    NamePatterns = {"weed", "coke", "meth", "crack", "heroin", "oxy", "perc", "acid", "xanax", "brick"},
    
    -- Keywords found in item descriptions/categories (if your items have them)
    CategoryPatterns = {"narcotic", "drug", "illegal"},
    
    -- Items that don't follow naming conventions but are definitely drugs
    ExplicitWhitelist = {
        ["joint"] = true,
        ["baggy"] = true,
    }
}

Config.Items = {
    -- [[ WHOLESALE / BRICKS ]]
    -- Master bricks use the 'strains' table to decide what they break down into.
    ['weed_brick'] = { 
        type = 'brick', 
        strains = { 'weed_skunk', 'weed_og-kush', 'weed_white-widow', 'weed_ak47' }, 
        ratio = 10 
    },
    
    ['coke_brick'] = { 
        type = 'brick', 
        strains = { 'coke_small_baggy', 'crack_baggy' }, 
        ratio = 15 
    },

    ['meth_brick'] = { 
        type = 'brick', 
        baggy = 'meth', -- Direct 1:1 breakdown
        ratio = 12 
    },

    -- [[ RETAIL / UNITS ]]
    -- Weed Strains
    ['weed_skunk'] = { type = 'unit' },
    ['weed_og-kush'] = { type = 'unit' },
    ['weed_white-widow'] = { type = 'unit' },
    ['weed_ak47'] = { type = 'unit' },

    -- Hard Drugs
    ['coke_small_baggy'] = { type = 'unit' },
    ['crack_baggy'] = { type = 'unit' },
    ['meth'] = { type = 'unit' },
    ['heroin_heavy'] = { type = 'unit' },
    
    -- Pharmaceuticals
    ['oxy'] = { type = 'unit' },
    ['ecstasy_baggy'] = { type = 'unit' }
}

Config.SellItems = {
    -- WEED (Lower tier, high volume)
    ['weed_skunk'] = { minPrice = 120, maxPrice = 180, label = 'Skunk Weed' },
    ['weed_og-kush'] = { minPrice = 150, maxPrice = 220, label = 'OG Kush' },
    ['weed_white-widow'] = { minPrice = 140, maxPrice = 210, label = 'White Widow' },
    ['weed_ak47'] = { minPrice = 160, maxPrice = 240, label = 'AK-47 Weed' },
    
    -- COKE & CRACK (High tier)
    ['coke_small_baggy'] = { minPrice = 350, maxPrice = 520, label = 'Coke Baggy' },
    ['crack_baggy'] = { minPrice = 280, maxPrice = 400, label = 'Crack Baggy' },
    
    -- METH & HEROIN (High risk/reward)
    ['meth'] = { minPrice = 400, maxPrice = 650, label = 'Pure Meth' },
    ['heroin_heavy'] = { minPrice = 500, maxPrice = 850, label = 'Pure Heroin' },
    
    -- OTHERS
    ['oxy'] = { minPrice = 200, maxPrice = 350, label = 'Oxycodone' },
    ['ecstasy_baggy'] = { minPrice = 180, maxPrice = 300, label = 'Ecstasy' },
}

Config.Gangs = {
    ["families"] = { label = "Families", color = 18, models = { "g_m_y_famca_01", "g_m_y_famdnf_01", "g_m_y_famfor_01", "g_f_y_families_01" } },
    ["ballas"] = { label = "Ballas", color = 27, models = { "g_m_y_ballaeast_01", "g_m_y_ballaorig_01", "g_m_y_ballasout_01", "g_f_y_ballas_01" } },
    ["vagos"] = { label = "Vagos", color = 46, models = { "g_m_y_mexgoon_01", "g_m_y_mexgoon_02", "g_m_y_mexgoon_03", "g_f_y_vagos_01" } },
    ["marabunta"] = { label = "Marabunta", color = 3, models = { "g_m_y_salvaboss_01", "g_m_y_salvagoon_01", "g_m_y_salvagoon_02", "g_f_y_vagos_01" } },
    ["aztecas"] = { label = "Aztecas", color = 64, models = { "g_m_y_azteca_01", "g_m_y_pologoon_01", "g_m_y_pologoon_02" } },
    ["lostmc"] = { label = "Lost MC", color = 40, models = { "g_m_y_lost_01", "g_m_y_lost_02", "g_m_y_lost_03", "g_f_y_lost_01" } },
    ["kkangpae"] = { label = "Kkangpae", color = 11, models = { "g_m_y_korean_01", "g_m_y_korean_02", "g_m_y_korlieut_01" } },
    ["armenian"] = { label = "Armenian", color = 39, models = { "g_m_m_armgoon_01", "g_m_y_armgoon_02" } },
    ["madrazo"] = { label = "Madrazo", color = 5, models = { "g_m_m_cartelguards_01", "g_m_y_mexoti_01" } },
    ["triads"] = { label = "Triads", color = 1, models = { "g_m_y_strp_01", "g_m_y_strp_02", "g_f_y_vagos_01" } },
}

-- This automatically creates the lookup table for the script to use
Config.GangModels = {}
for gangName, data in pairs(Config.Gangs) do
    for _, modelName in ipairs(data.models or {}) do
        Config.GangModels[modelName] = gangName
        Config.GangModels[GetHashKey(modelName)] = gangName
    end
end
