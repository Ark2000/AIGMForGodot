return {
    id = "territorial",
    decide = function(world, eid)
        local pos = world:get_component(eid, "position")
        if not pos then return nil end
        local faction = world:get_component(eid, "faction")
        if not faction then return nil end

        -- Attack enemies in same room; stay otherwise
        for _, other in ipairs(world:get_entities_in_room(pos.room_id)) do
            if other ~= eid and world:get_component(other, "is_actor") then
                local of = world:get_component(other, "faction")
                if of and faction.hostility[of.id] == "aggressive" then
                    return { action="attack", target=other }
                end
            end
        end
        return { action="wait" }
    end,
}
