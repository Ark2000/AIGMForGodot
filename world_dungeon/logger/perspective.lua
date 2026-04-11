-- Perspective: controls which events are shown

local topology = require("dungeon.topology")
local renderer = require("logger.renderer")

local M = {}

-- Create a perspective config
function M.new(cfg)
    return {
        mode            = cfg.mode or "world",
        target_eid      = cfg.target_eid,
        perception_range = cfg.perception_range or 1,
        min_importance  = cfg.min_importance or "LOW",
        focus_floor     = cfg.focus_floor,
        auto_follow     = cfg.auto_follow or false,
    }
end

-- Returns true if event passes perspective filter
function M.should_show(world, perspective, event)
    local importance = renderer.importance_of(event.type)
    local min_imp    = renderer.importance_from_name(perspective.min_importance or "LOW")

    -- CRITICAL always shown
    if importance >= renderer.IMPORTANCE.CRITICAL then return true end

    if perspective.mode == "world" then
        if importance < min_imp then return false end
        -- floor filter
        if perspective.focus_floor then
            local room_id = event.data.room_id
                         or event.data.from_room
                         or event.data.to_room
            if room_id then
                local f = topology.get_floor_of_room(world, room_id)
                if f and f ~= perspective.focus_floor then return false end
            end
        end
        return true

    elseif perspective.mode == "follow" then
        local target = perspective.target_eid
        if not target or not world:is_alive(target) then return true end

        -- target's own events always shown
        local d = event.data
        if d.entity_id == target or d.attacker_id == target or
           d.defender_id == target or d.receiver_id == target then
            return importance >= min_imp
        end

        -- events in perception range
        local room_id = d.room_id or d.from_room or d.to_room
        if room_id then
            local tpos = world:get_component(target, "position")
            if tpos and tpos.room_id then
                local dist = topology.graph_distance(world, tpos.room_id, room_id)
                if dist and dist <= perspective.perception_range then
                    return importance >= min_imp
                end
            end
        end
        return false
    end

    return importance >= min_imp
end

-- Find the next living adventurer (for auto-follow)
function M.find_follow_target(world)
    local advs = world:get_all_entities_with("adventurer_goal")
    for _, eid in ipairs(advs) do
        if world:is_alive(eid) then return eid end
    end
    return nil
end

return M
