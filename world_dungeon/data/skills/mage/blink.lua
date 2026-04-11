return {
    id       = "blink",
    name     = "Blink",
    tags     = { "active", "movement", "magical" },
    cooldown = 15,
    targeting = "self",
    effects  = {
        {
            type   = "teleport",
            target = "random_adjacent",
        },
    },
    ai_weight = function(world, user_eid, target_eid) return 0.3 end,
}
