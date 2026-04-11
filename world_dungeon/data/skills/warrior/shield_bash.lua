return {
    id       = "shield_bash",
    name     = "Shield Bash",
    tags     = { "active", "melee", "cc" },
    cooldown = 35,
    targeting = "single_enemy_same_room",
    effects  = {
        {
            type     = "damage",
            formula  = function(atk, def) return math.floor(atk.attack * 0.8) end,
            damage_type = "physical",
        },
        {
            type      = "apply_modifier",
            status_id = "stunned",
            duration  = 10,
            chance    = 0.5,
        },
    },
    ai_weight = function(world, user_eid, target_eid) return 0.6 end,
}
