-- Priority 72 — handle entity_died (loot/xp) and spawn_requested

local stats_system = require("systems.stats_system")
local util         = require("core.util")

return {
    name     = "spawn_system",
    priority = 72,

    init = function(world)
        local formulas = require("data.config.combat_formulas")

        -- ── entity_died → loot + xp + destroy ───────────────────────────
        world:subscribe("entity_died", function(event)
            local eid      = event.data.entity_id
            local killer   = event.data.killer_id
            local room_id  = event.data.room_id

            if not world:is_alive(eid) then return end

            -- Loot drop
            local loot_table = world:get_component(eid, "loot_table")
            if loot_table and room_id then
                for _, entry in ipairs(loot_table) do
                    if math.random() < (entry.chance or 1) then
                        local count = type(entry.count) == "table"
                                      and math.random(entry.count.min or 1, entry.count.max or 1)
                                      or (entry.count or 1)
                        for _ = 1, count do
                            local registry = world._registry
                            if registry then
                                pcall(function()
                                    local item_eid = registry:spawn_entity(world, entry.item_id, {
                                        position = { room_id=room_id },
                                        location = { type="ground", room_id=room_id },
                                    })
                                    world:emit("item_spawned", {
                                        item_id=item_eid, room_id=room_id, def_id=entry.item_id
                                    })
                                end)
                            end
                        end
                    end
                end
            end

            -- XP distribution — give XP to killers in same room
            if killer and world:is_alive(killer) and room_id then
                local killer_level = stats_system.get_stat(world, killer, "level")
                local dead_level   = stats_system.get_stat(world, eid,    "level")
                local xp = formulas.xp_for_kill(killer_level, dead_level)
                world:emit("xp_gained", { receiver_id=killer, amount=xp, source_id=eid })
            end

            -- Update ecology
            local faction = world:get_component(eid, "faction")
            if faction then
                local pop = world.ecology.population[faction.id]
                if pop then
                    pop.count = math.max(0, pop.count - 1)
                    if room_id then
                        local ri = world:get_component(room_id, "room_info")
                        if ri and ri.floor then
                            local fa = world.ecology.floor_activity[ri.floor]
                            if fa then fa.kills_this_period = (fa.kills_this_period or 0) + 1 end
                        end
                    end
                end
            end

            -- Adventurer death: record kill for killer, log Hall of Fame if adventurer
            local adv_goal = world:get_component(eid, "adventurer_goal")
            if adv_goal then
                local id = world:get_component(eid, "identity")
                local lvl = world:get_component(eid, "level")
                local entry = {
                    name        = id and id.name or "Unknown",
                    archetype   = id and id.archetype or "?",
                    level       = lvl and lvl.current or 1,
                    ticks_taken = world.tick - (adv_goal.spawn_tick or 0),
                    kills       = adv_goal.kills or 0,
                    tick        = world.tick,
                    outcome     = "died",
                }
                world:emit("adventurer_died", { entity_id=eid, entry=entry })
            end

            -- Track killer's kills
            if killer and world:is_alive(killer) then
                local kadv = world:get_component(killer, "adventurer_goal")
                if kadv then kadv.kills = (kadv.kills or 0) + 1 end
            end

            -- Destroy the dead entity
            world:destroy_entity(eid)
        end)

        -- ── spawn_requested → create entity ─────────────────────────────
        world:subscribe("spawn_requested", function(event)
            local d = event.data
            local registry = world._registry
            if not registry then return end
            local room_id = d.room_id
            if not room_id then return end

            -- capacity check
            local occupants = world:get_entities_in_room(room_id)
            if #occupants >= 8 then return end

            pcall(function()
                local eid = registry:spawn_entity(world, d.def_id, {
                    position = { room_id=room_id }
                })
                local actor = world:get_component(eid, "actor")
                local cd    = actor and actor.move_cooldown or 10
                if not world:get_component(eid, "action_timer") then
                    world:add_component(eid, "action_timer", {
                        cooldown_max=cd, cooldown_cur=cd, ready=false
                    })
                end
                -- update ecology
                local faction = world:get_component(eid, "faction")
                if faction then
                    local pop = world.ecology.population[faction.id]
                    if pop then
                        pop.count      = pop.count + 1
                        pop.peak       = math.max(pop.peak, pop.count)
                        pop.last_spawn = world.tick
                    end
                end
            end)
        end)

        -- ── adventurer_escaped → Hall of Fame ────────────────────────────
        world:subscribe("adventurer_escaped", function(event)
            local eid = event.data.entity_id
            if not world:is_alive(eid) then return end

            local id  = world:get_component(eid, "identity")
            local lvl = world:get_component(eid, "level")
            local adv = world:get_component(eid, "adventurer_goal")
            local entry = {
                name        = id  and id.name  or "Unknown",
                archetype   = id  and id.archetype or "?",
                level       = lvl and lvl.current or 1,
                ticks_taken = world.tick - (adv and adv.spawn_tick or 0),
                kills       = adv and adv.kills or 0,
                tick        = world.tick,
                outcome     = "escaped",
            }
            table.insert(world.hall_of_fame, entry)
            world:emit("yendor_retrieved", { entity_id=eid, entry=entry })
            world:destroy_entity(eid)
        end)
    end,

    update = function(world) end,  -- logic is event-driven
}
