return {
    id       = "smoke_bomb",
    name     = "Smoke Bomb",
    tags     = { "active", "buff", "stealth" },
    cooldown = 40,
    targeting = "self",
    effects  = {
        {
            type      = "apply_modifier",
            status_id = "invisible",
            duration  = 15,
            target    = "self",
        },
    },
    ai_weight = function(world, user_eid, target_eid) return 0.4 end,
}
