return {
    id       = "backstab",
    name     = "Backstab",
    tags     = { "active", "melee", "damage", "stealth" },
    cooldown = 25,
    targeting = "single_enemy_same_room",
    effects  = {
        {
            type     = "damage",
            formula  = function(atk, def) return math.floor(atk.attack * 2.0) end,
            damage_type = "physical",
        },
    },
    ai_weight = function(world, user_eid, target_eid) return 0.8 end,
}
