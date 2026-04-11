-- Priority 55 — tick down modifier durations, apply DoT, tick skill cooldowns

local stats_system = require("systems.stats_system")

return {
    name     = "status_system",
    priority = 55,

    init = function(world)
        world._status_registry = require("data.config.combat_formulas")  -- not used; kept for hook
    end,

    update = function(world)
        -- ── modifier duration countdown + DoT ────────────────────────────
        local mod_eids = world:get_all_entities_with("active_modifiers")
        for _, eid in ipairs(mod_eids) do
            if not world:is_alive(eid) then goto skip_mod end
            local mods = world:get_component(eid, "active_modifiers")
            local registry = world._registry
            local to_remove = {}

            for mod_id, mod in pairs(mods) do
                -- DoT effect
                if mod.tick_effect then
                    local te = mod.tick_effect
                    if te.type == "damage_over_time" then
                        if world.tick % te.interval == 0 then
                            local hp = stats_system.get_hp(world, eid)
                            stats_system.set_hp(world, eid, hp - te.damage)
                            local new_hp = stats_system.get_hp(world, eid)
                            world:emit("entity_attacked", {
                                attacker_id=nil, defender_id=eid,
                                hit=true, crit=false, damage=te.damage,
                                hp_before=hp, hp_after=new_hp,
                                source="dot", modifier_id=mod_id,
                            })
                            if new_hp <= 0 then
                                world:emit("entity_died", {
                                    entity_id=eid, killer_id=nil, room_id=nil
                                })
                            end
                        end
                    end
                else
                    -- pull tick_effect from status_def if available
                    if registry then
                        local sdef = registry:try_get("status_def", mod_id)
                        if sdef and sdef.tick_effect then
                            local te = sdef.tick_effect
                            if te.type == "damage_over_time" then
                                if world.tick % te.interval == 0 then
                                    local hp = stats_system.get_hp(world, eid)
                                    stats_system.set_hp(world, eid, hp - te.damage)
                                    local new_hp = stats_system.get_hp(world, eid)
                                    if new_hp <= 0 then
                                        world:emit("entity_died", {
                                            entity_id=eid, killer_id=nil, room_id=nil
                                        })
                                    end
                                end
                            end
                        end
                    end
                end

                -- duration countdown
                if mod.duration ~= nil then
                    mod.duration = mod.duration - 1
                    if mod.duration <= 0 then
                        table.insert(to_remove, mod_id)
                    end
                end
            end

            for _, mid in ipairs(to_remove) do
                mods[mid] = nil
                world:emit("modifier_removed", { entity_id=eid, modifier_id=mid })
            end

            ::skip_mod::
        end

        -- ── skill cooldown countdown ──────────────────────────────────────
        local skill_eids = world:get_all_entities_with("skills")
        for _, eid in ipairs(skill_eids) do
            if world:is_alive(eid) then
                local skills = world:get_component(eid, "skills")
                for _, sd in pairs(skills) do
                    if sd.cooldown_cur > 0 then
                        sd.cooldown_cur = sd.cooldown_cur - 1
                    end
                end
            end
        end
    end,
}
