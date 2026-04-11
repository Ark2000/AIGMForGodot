-- Priority 38 — execute use_skill intents

local stats_system = require("systems.stats_system")
local util         = require("core.util")

return {
    name     = "skill_system",
    priority = 38,

    update = function(world)
        local registry = world._registry
        local eids = world:query({ "action_timer", "ai_intent", "skills" })

        for _, eid in ipairs(eids) do
            if not world:is_alive(eid) then goto continue end

            local intent = world:get_component(eid, "ai_intent")
            if not intent or intent.action ~= "use_skill" then goto continue end

            local skill_id   = intent.target.skill_id
            local target_eid = intent.target.target_eid

            local skills = world:get_component(eid, "skills")
            local sd     = skills and skills[skill_id]
            if not sd or sd.cooldown_cur > 0 then
                world:remove_component(eid, "ai_intent")
                goto continue
            end

            local def = registry and registry:try_get("skill_def", sd.def_id)
            if not def then
                world:remove_component(eid, "ai_intent")
                goto continue
            end

            -- check target is valid
            if def.targeting == "single_enemy_same_room" then
                if not target_eid or not world:is_alive(target_eid) then
                    world:remove_component(eid, "ai_intent")
                    goto continue
                end
                local pos  = world:get_component(eid,       "position")
                local tpos = world:get_component(target_eid, "position")
                if not pos or not tpos or pos.room_id ~= tpos.room_id then
                    world:remove_component(eid, "ai_intent")
                    goto continue
                end
            end

            -- execute effects
            local atk_stats = {
                attack  = stats_system.get_stat(world, eid, "attack"),
                defense = stats_system.get_stat(world, eid, "defense"),
                speed   = stats_system.get_stat(world, eid, "speed"),
                level   = stats_system.get_stat(world, eid, "level"),
            }

            for _, eff in ipairs(def.effects or {}) do
                local actual_target = (eff.target == "self") and eid or target_eid

                if eff.type == "damage" and actual_target and world:is_alive(actual_target) then
                    local def_stats = {
                        attack  = stats_system.get_stat(world, actual_target, "attack"),
                        defense = stats_system.get_stat(world, actual_target, "defense"),
                        speed   = stats_system.get_stat(world, actual_target, "speed"),
                        level   = stats_system.get_stat(world, actual_target, "level"),
                    }
                    local dmg = eff.formula and eff.formula(atk_stats, def_stats) or atk_stats.attack
                    dmg = math.max(1, dmg)
                    local hp_before = stats_system.get_hp(world, actual_target)
                    stats_system.set_hp(world, actual_target, hp_before - dmg)
                    local hp_after = stats_system.get_hp(world, actual_target)
                    world:emit("entity_attacked", {
                        attacker_id=eid, defender_id=actual_target,
                        hit=true, crit=false, damage=dmg,
                        hp_before=hp_before, hp_after=hp_after,
                        skill_id=skill_id,
                    })
                    if hp_after <= 0 then
                        local pos = world:get_component(eid, "position")
                        world:emit("entity_died", {
                            entity_id=actual_target, killer_id=eid,
                            room_id=pos and pos.room_id,
                        })
                    end

                elseif eff.type == "heal" and actual_target and world:is_alive(actual_target) then
                    local hp  = stats_system.get_hp(world, actual_target)
                    local max = stats_system.get_stat(world, actual_target, "hp_max")
                    stats_system.set_hp(world, actual_target, math.min(max, hp + (eff.amount or 20)))

                elseif eff.type == "apply_modifier" then
                    local t = actual_target or eid
                    if t and world:is_alive(t) then
                        if not eff.chance or math.random() < eff.chance then
                            local status_def = registry:try_get("status_def", eff.status_id)
                            if status_def then
                                local mods = world:get_component(t, "active_modifiers")
                                if mods then
                                    mods[eff.status_id] = {
                                        id       = eff.status_id,
                                        source   = eid,
                                        duration = eff.duration,
                                        stats    = util.deep_copy(status_def.stats or {}),
                                        flags    = util.deep_copy(status_def.flags or {}),
                                    }
                                    world:emit("modifier_applied", {
                                        entity_id=t, modifier_id=eff.status_id, source_id=eid
                                    })
                                end
                            end
                        end
                    end

                elseif eff.type == "teleport" and eff.target == "random_adjacent" then
                    local topology = require("dungeon.topology")
                    local pos = world:get_component(eid, "position")
                    if pos then
                        local ns = topology.get_neighbors(world, pos.room_id)
                        if #ns > 0 then
                            local dest = ns[math.random(#ns)]
                            local from = pos.room_id
                            world:move_entity_to_room(eid, dest)
                            world:emit("entity_moved", {
                                entity_id=eid, from_room=from, to_room=dest
                            })
                        end
                    end
                end
            end

            -- set skill on cooldown
            sd.cooldown_cur = def.cooldown or 20

            world:emit("skill_used", { entity_id=eid, skill_id=skill_id, target_id=target_eid })

            -- reset action timer
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
