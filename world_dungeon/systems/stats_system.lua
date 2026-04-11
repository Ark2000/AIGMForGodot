-- Utility module (not a scheduled system).
-- Always call get_stat / has_flag instead of reading stats component directly.

local M = {}

function M.get_stat(world, eid, stat_name)
    local stats = world:get_component(eid, "stats")
    if not stats then return 0 end
    local base = stats[stat_name] or 0

    -- Collect modifiers from active_modifiers
    local add = 0
    local mul = 1.0
    local mods = world:get_component(eid, "active_modifiers")
    if mods then
        for _, mod in pairs(mods) do
            if mod.stats then
                local s = mod.stats[stat_name]
                if s then
                    if s.add then add = add + s.add end
                    if s.mul then mul = mul * s.mul end
                end
            end
        end
    end

    -- Equipment slot modifiers
    local slots = world:get_component(eid, "equipment_slots")
    if slots then
        for _, item_id in pairs(slots) do
            if item_id and world:is_alive(item_id) then
                local eq = world:get_component(item_id, "equippable")
                if eq and eq.modifiers then
                    for _, em in ipairs(eq.modifiers) do
                        if em.stat == stat_name then
                            if em.type == "add" then add = add + em.value
                            elseif em.type == "mul" then mul = mul * em.value
                            end
                        end
                    end
                end
            end
        end
    end

    return math.floor((base + add) * mul)
end

function M.has_flag(world, eid, flag_name)
    local mods = world:get_component(eid, "active_modifiers")
    if not mods then return false end
    for _, mod in pairs(mods) do
        if mod.flags and mod.flags[flag_name] then return true end
    end
    return false
end

-- Convenience: set hp directly on stats component (after damage/heal)
function M.set_hp(world, eid, new_hp)
    local stats = world:get_component(eid, "stats")
    if not stats then return end
    local hp_max = M.get_stat(world, eid, "hp_max")
    stats.hp = math.min(hp_max, math.max(0, new_hp))
end

function M.get_hp(world, eid)
    local stats = world:get_component(eid, "stats")
    if not stats then return 0 end
    return stats.hp
end

return M
