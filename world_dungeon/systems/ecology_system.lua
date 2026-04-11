-- Priority 75, on_tick 100 — population checks and adventurer spawning

local util = require("core.util")

return {
    name     = "ecology_system",
    priority = 75,
    on_tick  = 100,

    init = function(world)
        -- init ecology counters from world state
        world:subscribe("entity_spawned", function(event)
            local eid = event.data.entity_id
            if not world:is_alive(eid) then return end
            local faction = world:get_component(eid, "faction")
            if faction then
                local pop = world.ecology.population[faction.id]
                if not pop then
                    world.ecology.population[faction.id] = {
                        count=0, peak=0, last_spawn=0
                    }
                    pop = world.ecology.population[faction.id]
                end
                pop.count      = pop.count + 1
                pop.peak       = math.max(pop.peak, pop.count)
                pop.last_spawn = world.tick
            end
        end)
    end,

    update = function(world)
        local registry = world._registry
        if not registry then return end

        local sim_cfg = require("data.config.simulation")

        -- ── adventurer spawning ──────────────────────────────────────────
        local adventurers = world:get_all_entities_with("adventurer_goal")
        local adv_count   = 0
        for _, eid in ipairs(adventurers) do
            if world:is_alive(eid) then adv_count = adv_count + 1 end
        end

        local last_adv_spawn = world.ecology._last_adv_spawn or 0
        if adv_count < sim_cfg.max_adventurers
           and (world.tick - last_adv_spawn) >= sim_cfg.adventurer_spawn_interval
        then
            -- spawn a random adventurer archetype at floor 1 entrance
            local floor1 = world.dungeon.floors[1]
            if floor1 and floor1.entrance then
                local archetypes = { "warrior", "rogue", "mage" }
                local archetype  = util.random_pick(archetypes)
                local adv_def    = registry:try_get("entity_def", archetype)
                if adv_def then
                    local names   = adv_def.name_pool or { "Hero" }
                    local name    = util.random_pick(names)
                    local adv_eid = registry:spawn_entity(world, archetype, {
                        position = { room_id = floor1.entrance },
                    })
                    -- set name
                    local id = world:get_component(adv_eid, "identity")
                    if id then id.name = name end

                    -- set spawn tick
                    local adv = world:get_component(adv_eid, "adventurer_goal")
                    if adv then adv.spawn_tick = world.tick end

                    -- init action timer
                    local actor = world:get_component(adv_eid, "actor")
                    local cd    = actor and actor.move_cooldown or 10
                    world:add_component(adv_eid, "action_timer", {
                        cooldown_max=cd, cooldown_cur=math.random(1, cd), ready=false
                    })

                    -- give starting gear
                    local gear = adv_def.starting_gear
                    if gear then
                        -- guaranteed items
                        for _, item_def_id in ipairs(gear.guaranteed or {}) do
                            pcall(function()
                                local item_eid = registry:spawn_entity(world, item_def_id, {
                                    location = { type="inventory", owner_id=adv_eid }
                                })
                                local inv = world:get_component(adv_eid, "inventory")
                                if inv then
                                    inv.items[item_eid] = true
                                    local ii = world:get_component(item_eid, "item_info")
                                    inv.weight_current = inv.weight_current + (ii and ii.weight or 0)
                                end
                                -- auto-equip
                                local eq_sys = require("systems.equipment_system")
                                eq_sys.equip(world, adv_eid, item_eid)
                            end)
                        end
                        -- random items
                        for _, ri in ipairs(gear.random or {}) do
                            if math.random() < ri.chance then
                                local count = type(ri.count) == "table"
                                              and math.random(ri.count[1], ri.count[2]) or 1
                                for _ = 1, count do
                                    pcall(function()
                                        local item_eid = registry:spawn_entity(world, ri.item_id, {
                                            location = { type="inventory", owner_id=adv_eid }
                                        })
                                        local inv = world:get_component(adv_eid, "inventory")
                                        if inv then
                                            inv.items[item_eid] = true
                                            local ii = world:get_component(item_eid, "item_info")
                                            inv.weight_current = inv.weight_current + (ii and ii.weight or 0)
                                        end
                                    end)
                                end
                            end
                        end
                    end

                    world.ecology._last_adv_spawn = world.tick
                    world:emit("adventurer_spawned", {
                        entity_id=adv_eid, archetype=archetype, name=name
                    })
                end
            end
        end

        -- ── monster population maintenance ────────────────────────────────
        for floor_num, floor_data in pairs(world.dungeon.floors) do
            local floor_cfg = registry:try_get("floor_config", "floor_" .. floor_num)
            if not floor_cfg then goto next_floor end

            local eco = floor_cfg.ecology
            if not eco then goto next_floor end

            -- count entities on this floor
            local entity_count = 0
            for rid in pairs(floor_data.rooms) do
                for _, eid in ipairs(world:get_entities_in_room(rid)) do
                    if world:get_component(eid, "is_actor") and
                       not world:get_component(eid, "adventurer_goal") then
                        entity_count = entity_count + 1
                    end
                end
            end

            -- update floor activity
            if not world.ecology.floor_activity[floor_num] then
                world.ecology.floor_activity[floor_num] = { kills_this_period=0, entity_count=0 }
            end
            world.ecology.floor_activity[floor_num].entity_count = entity_count

            -- respawn if under minimum
            if entity_count < eco.min_population then
                local pool = floor_cfg.monster_pool
                if pool and #pool > 0 then
                    local spawn_count = math.min(eco.spawn_per_cycle, eco.min_population - entity_count)
                    local rooms_list  = util.keys(floor_data.rooms)
                    for _ = 1, spawn_count do
                        local spawn_room = util.random_pick(rooms_list)
                        local ri = world:get_component(spawn_room, "room_info")
                        if spawn_room and ri and ri.type ~= "entrance" and ri.type ~= "boss_room" then
                            world:emit("spawn_requested", {
                                def_id  = util.random_pick(pool),
                                room_id = spawn_room,
                            })
                        end
                    end
                end
            end

            ::next_floor::
        end

        -- reset period kill counters
        for _, fa in pairs(world.ecology.floor_activity) do
            fa.kills_this_period = 0
        end
    end,
}
