return {
    id       = "frost_bolt",
    name     = "Frost Bolt",
    tags     = { "active", "magical", "cc", "ice" },
    cooldown = 20,
    targeting = "single_enemy_same_room",
    effects  = {
        {
            type     = "damage",
            formula  = function(atk, def) return math.floor(atk.attack * 1.4) end,
            damage_type = "ice",
        },
        {
            type      = "apply_modifier",
            status_id = "frozen",
            duration  = 6,
            chance    = 0.7,
        },
    },
    ai_weight = function(world, user_eid, target_eid) return 0.75 end,
}
