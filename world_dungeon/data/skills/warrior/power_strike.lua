return {
    id       = "power_strike",
    name     = "Power Strike",
    tags     = { "active", "melee", "damage" },
    cooldown = 20,
    targeting = "single_enemy_same_room",
    effects  = {
        {
            type     = "damage",
            formula  = function(atk, def) return math.floor(atk.attack * 1.5) end,
            damage_type = "physical",
        },
    },
    ai_weight = function(world, user_eid, target_eid) return 0.7 end,
}
