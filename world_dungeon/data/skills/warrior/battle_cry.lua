return {
    id       = "battle_cry",
    name     = "Battle Cry",
    tags     = { "active", "buff", "aoe" },
    cooldown = 60,
    targeting = "self",
    effects  = {
        {
            type      = "apply_modifier",
            status_id = "strengthened",
            duration  = 30,
            target    = "self",
        },
    },
    ai_weight = function(world, user_eid, target_eid) return 0.5 end,
}
