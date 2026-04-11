local util = require("core.util")

return {
    id = "coward",
    decide = function(world, eid)
        local topology = require("dungeon.topology")
        local pos = world:get_component(eid, "position")
        if not pos then return nil end
        local faction = world:get_component(eid, "faction")
        if not faction then return nil end

        -- Flee from enemies in same room
        for _, other in ipairs(world:get_entities_in_room(pos.room_id)) do
            if other ~= eid and world:get_component(other, "is_actor") then
                local of = world:get_component(other, "faction")
                if of and faction.hostility[of.id] == "aggressive" then
                    local neighbors = topology.get_neighbors(world, pos.room_id)
                    if #neighbors > 0 then
                        return { action="move", target=util.random_pick(neighbors) }
                    end
                    return { action="wait" }
                end
            end
        end

        local neighbors = topology.get_neighbors(world, pos.room_id)
        if #neighbors == 0 then return { action="wait" } end
        return { action="move", target=util.random_pick(neighbors) }
    end,
}
