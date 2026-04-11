return {
    id    = "poisoned",
    name  = "Poisoned",
    flags = {},
    stats = {},
    -- deal 2 damage every 5 ticks
    tick_effect = { type="damage_over_time", damage=2, interval=5 },
}
