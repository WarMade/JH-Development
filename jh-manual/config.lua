Config = {}

Config.Settings = {
    DefaultMode = "auto",         -- Now starts as "auto"
    StallEnabled = true,
    ClutchRequired = true,
    UseNUI = true,
    MoneyShiftDamage = true,
}

Config.Controls = {
    ShiftUp = { key = 'PAGEUP', desc = 'Shift Gear Up' },
    ShiftDown = { key = 'PAGEDOWN', desc = 'Shift Gear Down' },
    Clutch = { key = 'LEFTSHIFT', desc = 'Clutch Pedal' },
    Menu = { key = 'F9', desc = 'Open JH-Manual Settings' },
}

Config.RawInput = {
    Enabled = false,              -- Enable if you use a RawInput joystick resource
    Resource = 'RawInput',        -- Resource name that exposes joystick exports
    PollInterval = 0,             -- 0 = every frame
    Buttons = {
        Clutch = false,
        ShiftUp = false,
        ShiftDown = false,
        Neutral = false,
        Gear1 = false,
        Gear2 = false,
        Gear3 = false,
        Gear4 = false,
        Gear5 = false,
        Gear6 = false,
    }
}

-- Damage scaling for "Money Shifting"
Config.DamageMult = 2.5

-- Gear speeds (RPM to speed conversion)
Config.MaxSpeedPerGear = {
    [1] = 40.0,   -- 1st gear max speed
    [2] = 80.0,   -- 2nd gear max speed
    [3] = 120.0,  -- 3rd gear max speed
    [4] = 160.0,  -- 4th gear max speed
    [5] = 200.0,  -- 5th gear max speed
    [6] = 240.0,  -- 6th gear max speed
}

-- Over-revving damage
Config.OverRevving = {
    Enabled = true,
    DamageAmount = 300.0, -- Engine damage per over-rev
    SmokeThreshold = 400.0, -- Speed at which smoke starts
}

-- Stalling
Config.StallSpeedThreshold = 1.0
Config.StallRpmThreshold = 0.2

-- Engine Braking
Config.EngineBraking = {
    Enabled = true,
    BrakingStrength = 0.15, -- Multiplier for compression braking (0.1-0.3 recommended)
    MinRpmThreshold = 0.5,  -- Minimum RPM before braking takes effect
}

-- Camera Shake & Immersion
Config.CameraShake = {
    Enabled = true,
    HighRpmShake = 0.5,     -- Intensity multiplier for high RPM vibration (0.3-0.7 recommended)
    IdleShake = 0.1,        -- Intensity for idle vibration when in gear
    StallShake = 0.1,       -- Intensity for stall shudder
}

-- Launch Control (Prevents wheelspin on hard acceleration)
Config.LaunchControl = {
    Enabled = true,
    MaxLaunchRpm = 0.65,         -- RPM cap during launch (keeps at ~65% for traction)
    EnabledGears = {1, 2},       -- Gears that launch control works in
    ThrottleThreshold = 0.8,     -- Minimum throttle input to trigger (0.0-1.0)
    AntiLagEnabled = true,       -- Enable anti-lag pops/backfires
    AntiLagChance = 0.25,        -- Probability of anti-lag pop per frame (0.1-0.4)
}

-- Shift Delay (Realistic transmission speed based on vehicle class)
Config.ShiftDelay = {
    Enabled = true,
    -- Vehicle class -> shift delay in milliseconds
    ByClass = {
        [7] = 150,     -- Supercars (DCT/Sequential)
        [20] = 1000,   -- Commercial/Trucks (slow manual)
    },
    DefaultDelay = 400, -- Default for sedans/coupes/sports cars
}
