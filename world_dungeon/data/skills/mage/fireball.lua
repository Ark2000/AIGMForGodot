return {
    id       = "fireball",
    name     = "Fireball",
    tags     = { "active", "magical", "aoe", "fire" },
    cooldown = 30,
    targeting = "single_enemy_same_room",
    effects  = {
        {
            type     = "damage",
            formula  = function(atk, def) return math.floor(atk.attack * 2.0) end,
            damage_type = "fire",
        },
        {
            type      = "apply_modifier",
            status_id = "burning",
            duration  = 15,
            chance    = 0.6,
        },
    },
    ai_weight = function(world, user_eid, target_eid) return 0.9 end,
}
