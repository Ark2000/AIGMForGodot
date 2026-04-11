local util = require("core.util")

return {
    id = "pack_hunter",
    decide = function(world, eid)
        local topology = require("dungeon.topology")
        local pos = world:get_component(eid, "position")
        if not pos then return nil end
        local faction = world:get_component(eid, "faction")
        if not faction then return nil end

        -- Check same-room enemies first
        for _, other in ipairs(world:get_entities_in_room(pos.room_id)) do
            if other ~= eid and world:get_component(other, "is_actor") then
                local of = world:get_component(other, "faction")
                if of and faction.hostility[of.id] == "aggressive" then
                    return { action="attack", target=other }
                end
            end
        end

        -- Search adjacent rooms for enemies
        local neighbors = topology.get_neighbors(world, pos.room_id)
        for _, nid in ipairs(neighbors) do
            for _, other in ipairs(world:get_entities_in_room(nid)) do
                if world:get_component(other, "is_actor") then
                    local of = world:get_component(other, "faction")
                    if of and faction.hostility[of.id] == "aggressive" then
                        return { action="move", target=nid }
                    end
                end
            end
        end

        -- Default: wander
        if #neighbors == 0 then return { action="wait" } end
        return { action="move", target=util.random_pick(neighbors) }
    end,
}
