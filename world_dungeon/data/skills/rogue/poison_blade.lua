return {
    id       = "poison_blade",
    name     = "Poison Blade",
    tags     = { "active", "melee", "debuff" },
    cooldown = 20,
    targeting = "single_enemy_same_room",
    effects  = {
        {
            type     = "damage",
            formula  = function(atk, def) return math.floor(atk.attack * 0.8) end,
            damage_type = "physical",
        },
        {
            type      = "apply_modifier",
            status_id = "poisoned",
            duration  = 30,
            chance    = 0.8,
        },
    },
    ai_weight = function(world, user_eid, target_eid) return 0.7 end,
}
