local util = require("core.util")

return {
    id = "random_wander",
    decide = function(world, eid)
        local topology = require("dungeon.topology")
        local pos = world:get_component(eid, "position")
        if not pos then return nil end
        local neighbors = topology.get_neighbors(world, pos.room_id)
        if #neighbors == 0 then return { action="wait" } end
        return { action="move", target = util.random_pick(neighbors) }
    end,
}
