return {
    base_xp  = 100,
    exponent = 1.5,

    -- xp_next(level) = floor(base_xp * level^exponent)
    xp_for_level = function(level)
        return math.floor(100 * (level ^ 1.5))
    end,

    -- Per-class stat growth on level-up
    growth = {
        default = {
            hp_max  = { add = 5 },
            attack  = { add = 1 },
            defense = { add = 1 },
        },
        warrior = {
            hp_max  = { add = 10 },
            attack  = { add = 3 },
            defense = { add = 2 },
        },
        rogue = {
            hp_max  = { add = 6 },
            attack  = { add = 4 },
            defense = { add = 1 },
            speed   = { add = 1 },
        },
        mage = {
            hp_max  = { add = 4 },
            attack  = { add = 5 },
            defense = { add = 0 },
        },
        monster = {
            hp_max  = { add = 4 },
            attack  = { add = 2 },
            defense = { add = 1 },
        },
    },

    -- skill_unlock[growth_type][level] = skill_id
    skill_unlock = {
        warrior = {
            [2] = "power_strike",
            [4] = "shield_bash",
            [6] = "battle_cry",
        },
        rogue = {
            [2] = "backstab",
            [4] = "poison_blade",
            [6] = "smoke_bomb",
        },
        mage = {
            [2] = "fireball",
            [4] = "frost_bolt",
            [6] = "blink",
        },
    },
}
