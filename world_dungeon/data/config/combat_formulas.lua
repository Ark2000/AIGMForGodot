return {
    -- Physical damage after mitigation (minimum 1)
    physical_damage = function(atk_stats, def_stats)
        local base = atk_stats.attack - math.floor(def_stats.defense * 0.5)
        return math.max(1, base)
    end,

    -- Hit probability [0.05, 0.95]
    hit_chance = function(atk_stats, def_stats)
        local base = 0.75
        local diff = (atk_stats.speed or 10) - (def_stats.speed or 10)
        return math.min(0.95, math.max(0.05, base + diff * 0.03))
    end,

    -- Critical-hit probability [0, 0.50]
    crit_chance = function(atk_stats)
        local base = 0.05
        return math.min(0.50, base)
    end,

    crit_multiplier = 2.0,

    -- XP awarded to killer for slaying a target
    xp_for_kill = function(killer_level, target_level)
        local base = 20 + target_level * 10
        local lvl_diff = target_level - killer_level
        local mult = math.max(0.25, 1 + lvl_diff * 0.1)
        return math.floor(base * mult)
    end,
}
