-- Priority 65 — subscribe to xp_gained, handle level-ups

local stats_system = require("systems.stats_system")
local util         = require("core.util")

return {
    name     = "level_system",
    priority = 65,

    init = function(world)
        local level_curve = require("data.config.level_curve")

        world:subscribe("xp_gained", function(event)
            local eid    = event.data.receiver_id
            local amount = event.data.amount or 0

            if not eid or not world:is_alive(eid) then return end

            local lvl = world:get_component(eid, "level")
            if not lvl then return end

            lvl.xp = lvl.xp + amount

            -- level-up loop (can gain multiple levels)
            while lvl.xp >= lvl.xp_next do
                lvl.xp      = lvl.xp - lvl.xp_next
                lvl.current = lvl.current + 1

                -- calc next threshold
                lvl.xp_next = level_curve.xp_for_level(lvl.current)

                -- apply growth
                local id       = world:get_component(eid, "identity")
                local archtype = id and id.archetype or "default"
                local growth   = level_curve.growth[archtype] or level_curve.growth.default
                local stats    = world:get_component(eid, "stats")
                if stats and growth then
                    for stat, delta in pairs(growth) do
                        if delta.add then
                            stats[stat] = (stats[stat] or 0) + delta.add
                        end
                    end
                    -- also restore HP to new max
                    stats.hp = stats.hp_max
                    -- sync level in stats
                    stats.level = lvl.current
                end

                -- skill unlocks
                local unlock_table = level_curve.skill_unlock[archtype]
                if unlock_table then
                    local skill_id = unlock_table[lvl.current]
                    if skill_id then
                        local skills = world:get_component(eid, "skills")
                        if skills and not skills[skill_id] then
                            skills[skill_id] = {
                                def_id       = skill_id,
                                level        = 1,
                                cooldown_cur = 0,
                            }
                            world:emit("skill_unlocked", {
                                entity_id=eid, skill_id=skill_id, level=lvl.current
                            })
                        end
                    end
                end

                world:emit("entity_leveled_up", {
                    entity_id = eid,
                    new_level = lvl.current,
                })
            end
        end)
    end,

    update = function(world) end,
}
