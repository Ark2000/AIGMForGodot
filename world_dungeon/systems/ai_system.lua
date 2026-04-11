-- Priority 10 — produce ai_intent for every ready entity

local stats_system = require("systems.stats_system")

return {
    name     = "ai_system",
    priority = 10,

    update = function(world)
        local registry = world._registry
        local eids = world:query({ "action_timer", "ai_behavior", "position" })

        for _, eid in ipairs(eids) do
            if not world:is_alive(eid) then goto continue end

            local at = world:get_component(eid, "action_timer")
            if not at or not at.ready then goto continue end

            -- skip if already has an intent
            if world:get_component(eid, "ai_intent") then goto continue end

            -- skip if cannot act
            if stats_system.has_flag(world, eid, "cannot_act") then
                at.ready       = false
                at.cooldown_cur = at.cooldown_max
                goto continue
            end

            local behavior = world:get_component(eid, "ai_behavior")
            local def = registry and registry:try_get("behavior_def", behavior.archetype)

            if def and def.decide then
                local intent = def.decide(world, eid)
                if intent and intent.action ~= "wait" then
                    world:add_component(eid, "ai_intent", intent)
                else
                    -- "wait" or nil: consume the ready action and reset timer
                    local actor = world:get_component(eid, "actor")
                    if at and actor then
                        local spd = require("systems.stats_system").get_stat(world, eid, "speed")
                        at.cooldown_max = math.max(1, math.floor(actor.move_cooldown * 10 / math.max(1, spd)))
                        at.cooldown_cur = at.cooldown_max
                        at.ready        = false
                    elseif at then
                        at.cooldown_cur = at.cooldown_max
                        at.ready        = false
                    end
                end
            end

            ::continue::
        end
    end,
}
