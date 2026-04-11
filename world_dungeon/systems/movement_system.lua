-- Priority 30 — execute move intents

local topology    = require("dungeon.topology")
local stats_system = require("systems.stats_system")

return {
    name     = "movement_system",
    priority = 30,

    update = function(world)
        local eids = world:query({ "position", "action_timer", "ai_intent" })

        for _, eid in ipairs(eids) do
            if not world:is_alive(eid) then goto continue end

            local intent = world:get_component(eid, "ai_intent")
            if not intent or intent.action ~= "move" then goto continue end

            -- cannot_move check
            if stats_system.has_flag(world, eid, "cannot_move") then
                world:remove_component(eid, "ai_intent")
                local at = world:get_component(eid, "action_timer")
                if at then at.ready = false; at.cooldown_cur = at.cooldown_max end
                goto continue
            end

            local target_room = intent.target
            local pos         = world:get_component(eid, "position")
            local at          = world:get_component(eid, "action_timer")

            -- validate adjacency
            local neighbors = topology.get_neighbors(world, pos.room_id)
            local valid = false
            for _, n in ipairs(neighbors) do
                if n == target_room then valid = true; break end
            end

            if valid then
                local from_room = pos.room_id
                world:move_entity_to_room(eid, target_room)
                world:emit("entity_moved", {
                    entity_id   = eid,
                    from_room   = from_room,
                    to_room     = target_room,
                })
                -- reset timer based on speed
                if at then
                    local actor = world:get_component(eid, "actor")
                    local base  = actor and actor.move_cooldown or 10
                    local spd   = stats_system.get_stat(world, eid, "speed")
                    at.cooldown_max = math.max(1, math.floor(base * 10 / math.max(1, spd)))
                    at.cooldown_cur = at.cooldown_max
                    at.ready        = false
                end
            end

            world:remove_component(eid, "ai_intent")
            ::continue::
        end
    end,
}
