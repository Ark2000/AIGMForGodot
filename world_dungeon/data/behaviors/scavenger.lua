local util = require("core.util")

return {
    id = "scavenger",
    decide = function(world, eid)
        local topology = require("dungeon.topology")
        local pos = world:get_component(eid, "position")
        if not pos then return nil end

        -- Pick up items in same room
        for _, other in ipairs(world:get_entities_in_room(pos.room_id)) do
            local loc = world:get_component(other, "location")
            if loc and loc.type == "ground" then
                return { action="pick_up", target=other }
            end
        end

        local neighbors = topology.get_neighbors(world, pos.room_id)
        if #neighbors == 0 then return { action="wait" } end
        return { action="move", target=util.random_pick(neighbors) }
    end,
}
