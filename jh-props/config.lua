Config = {}

-- Weight Settings
Config.MaxPickupWeight = 15.0
Config.DeleteOnSearch = true

-- Physical Weight Mapping
Config.PropWeights = {
    ['crate'] = 25.0,
    ['beer'] = 0.5,
    ['cola'] = 0.5,
    ['bottle'] = 1.0,
    ['box'] = 5.0,
    ['toolbox'] = 10.0,
    ['register'] = 18.0,
    ['safe'] = 60.0,
    ['briefcase'] = 4.0,
    ['suitcase'] = 8.0,
    ['computer'] = 9.0,
    ['monitor'] = 6.0,
    ['tv'] = 12.0,
    ['barrel'] = 35.0,
    ['locker'] = 45.0,
    ['cabinet'] = 30.0,
    ['fridge'] = 80.0,
    ['cooler'] = 8.0,
    ['vending'] = 120.0,
    ['mailbox'] = 20.0
}

-- Material Rewards for "Searching" or "Scrapping"
Config.LootTable = {
    ['plastic'] = {"plastic", "rubber", "glass"},
    ['metal'] = {"metalscrap", "steel", "iron", "aluminum", "copper"},
    ['electronics'] = {"electronicstack", "glass", "phone", "radio"},
    ['medical'] = {"bandage", "condom"},
    ['supplies'] = {"water_bottle", "sandwich", "coffee", "condom"},
    ['kitchenware'] = {"water_bottle", "coffee", "plastic", "glass"},
    ['hardware'] = {"lockpick", "repairkit", "metalscrap", "steel"},
    ['storage'] = {"plastic", "rubber", "water_bottle", "sandwich"},
    ['tools'] = {"lockpick", "repairkit"},
    ['office'] = {"phone", "radio", "plastic"},
    ['valuables'] = {"markedbills", "phone", "radio", "rolex", "goldbar", "diamond_ring"}
}

-- Intelligent Archetype Matching
-- Props only become interactable if the mapped item exists in QBCore.Shared.Items
Config.Archetypes = {
    -- PICKUPS: model keyword -> QB item name
    ['pickups'] = {
        ['beer'] = "beer",
        ['cola'] = "ecola",
        ['soda'] = "ecola",
        ['can'] = "ecola",
        ['coffee'] = "coffee",
        ['cup'] = "coffee",
        ['mug'] = "coffee",
        ['water'] = "water_bottle",
        ['bottle'] = "water_bottle",
        ['juice'] = "water_bottle",
        ['sandwich'] = "sandwich",
        ['burger'] = "sandwich",
        ['snack'] = "sandwich",
        ['pizza'] = "sandwich",
        ['bandage'] = "bandage",
        ['med'] = "bandage",
        ['medkit'] = "bandage",
        ['firstaid'] = "bandage",
        ['ammo'] = "pistol_ammo",
        ['pistol'] = "weapon_pistol",
        ['revolver'] = "weapon_revolver",
        ['smg'] = "weapon_smg",
        ['shotgun'] = "weapon_pumpshotgun",
        ['carbine'] = "weapon_carbinerifle",
        ['rifle'] = "weapon_assaultrifle",
        ['sniper'] = "weapon_sniperrifle",
        ['knife'] = "weapon_knife",
        ['bat'] = "weapon_bat",
        ['crowbar'] = "weapon_crowbar",
        ['phone'] = "phone",
        ['radio'] = "radio",
        ['walkie'] = "radio",
        ['tablet'] = "tablet",
        ['laptop'] = "laptop",
        ['toolbox'] = "repairkit",
        ['repair'] = "repairkit",
        ['wrench'] = "repairkit",
        ['drill'] = "repairkit",
        ['lockpick'] = "lockpick",
        ['cash'] = "markedbills",
        ['money'] = "markedbills",
        ['wallet'] = "markedbills",
        ['briefcase'] = "markedbills",
        ['suitcase'] = "markedbills"
    },

    -- SEARCHABLE: model keyword -> loot table group
    ['containers'] = {
        ['trash'] = "plastic",
        ['bag'] = "plastic",
        ['basket'] = "plastic",
        ['mailbox'] = "plastic",
        ['crate'] = "metal",
        ['barrel'] = "metal",
        ['locker'] = "metal",
        ['cabinet'] = "metal",
        ['shelf'] = "plastic",
        ['drawer'] = "office",
        ['desk'] = "office",
        ['office'] = "office",
        ['filing'] = "office",
        ['toolbox'] = "tools",
        ['case'] = "tools",
        ['box'] = "electronics",
        ['computer'] = "electronics",
        ['monitor'] = "electronics",
        ['tv'] = "electronics",
        ['speaker'] = "electronics",
        ['register'] = "valuables",
        ['safe'] = "valuables",
        ['briefcase'] = "valuables",
        ['suitcase'] = "valuables",
        ['vending'] = "supplies",
        ['cooler'] = "supplies",
        ['fridge'] = "supplies",
        ['cupboard'] = "supplies",
        ['kitchen'] = "supplies",
        ['microwave'] = "kitchenware",
        ['oven'] = "kitchenware",
        ['stove'] = "kitchenware",
        ['medical'] = "medical",
        ['med'] = "medical",
        ['firstaid'] = "medical",
        ['medcabinet'] = "medical",
        ['toolchest'] = "hardware",
        ['workbench'] = "hardware",
        ['closet'] = "storage",
        ['wardrobe'] = "storage",
        ['generator'] = "metal",
        ['machine'] = "metal",
        ['fusebox'] = "electronics",
        ['panel'] = "electronics"
    }
}