-- Priority 35 — execute attack intents

local stats_system = require("systems.stats_system")

return {
    name     = "combat_system",
    priority = 35,

    init = function(world)
        world._combat_formulas = require("data.config.combat_formulas")
    end,

    update = function(world)
        local formulas = world._combat_formulas
        local eids = world:query({ "action_timer", "ai_intent" })

        for _, eid in ipairs(eids) do
            if not world:is_alive(eid) then goto continue end

            local intent = world:get_component(eid, "ai_intent")
            if not intent or intent.action ~= "attack" then goto continue end

            local target_id = intent.target
            if not target_id or not world:is_alive(target_id) then
                world:remove_component(eid, "ai_intent")
                goto continue
            end

            -- build effective stat snapshots
            local atk_stats = {
                attack  = stats_system.get_stat(world, eid,       "attack"),
                defense = stats_system.get_stat(world, eid,       "defense"),
                speed   = stats_system.get_stat(world, eid,       "speed"),
                level   = stats_system.get_stat(world, eid,       "level"),
            }
            local def_stats = {
                attack  = stats_system.get_stat(world, target_id, "attack"),
                defense = stats_system.get_stat(world, target_id, "defense"),
                speed   = stats_system.get_stat(world, target_id, "speed"),
                level   = stats_system.get_stat(world, target_id, "level"),
            }

            local hit  = math.random() < formulas.hit_chance(atk_stats, def_stats)
            local crit = hit and math.random() < formulas.crit_chance(atk_stats)
            local damage = 0
            if hit then
                damage = formulas.physical_damage(atk_stats, def_stats)
                if crit then damage = math.floor(damage * formulas.crit_multiplier) end
            end

            local hp_before = stats_system.get_hp(world, target_id)
            local hp_after  = hp_before

            if hit then
                stats_system.set_hp(world, target_id, hp_before - damage)
                hp_after = stats_system.get_hp(world, target_id)
            end

            local pos = world:get_component(eid, "position")
            world:emit("entity_attacked", {
                attacker_id = eid,
                defender_id = target_id,
                hit         = hit,
                crit        = crit,
                damage      = damage,
                hp_before   = hp_before,
                hp_after    = hp_after,
                room_id     = pos and pos.room_id,
            })

            if hp_after <= 0 then
                world:emit("entity_died", {
                    entity_id = target_id,
                    killer_id = eid,
                    room_id   = pos and pos.room_id,
                })
            end

            -- reset timer
            local at    = world:get_component(eid, "action_timer")
            local actor = world:get_component(eid, "actor")
            if at and actor then
                local spd = stats_system.get_stat(world, eid, "speed")
                at.cooldown_max = math.max(1, math.floor(actor.attack_cooldown * 10 / math.max(1, spd)))
                at.cooldown_cur = at.cooldown_max
                at.ready        = false
            end

            world:remove_component(eid, "ai_intent")
            ::continue::
        end
    end,
}
