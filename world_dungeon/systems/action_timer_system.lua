-- Priority 5 — decrements cooldowns and sets ready flag

return {
    name     = "action_timer_system",
    priority = 5,

    update = function(world)
        local eids = world:get_all_entities_with("action_timer")
        for _, eid in ipairs(eids) do
            if world:is_alive(eid) then
                local at = world:get_component(eid, "action_timer")
                if not at.ready then
                    at.cooldown_cur = at.cooldown_cur - 1
                    if at.cooldown_cur <= 0 then
                        at.ready = true
                    end
                end
            end
        end
    end,
}
