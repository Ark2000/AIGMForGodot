-- Utility module (not a scheduled system).

local M = {}

function M.equip(world, actor_eid, item_eid)
    local eq = world:get_component(item_eid, "equippable")
    if not eq then return false, "not equippable" end

    local slots = world:get_component(actor_eid, "equipment_slots")
    if not slots then return false, "no equipment slots" end

    local slot = eq.slot
    -- unequip current occupant
    if slots[slot] then
        M.unequip(world, actor_eid, slot)
    end

    slots[slot] = item_eid

    -- update item location
    local loc = world:get_component(item_eid, "location")
    if loc then
        loc.type = "equipped"; loc.owner_id = actor_eid; loc.slot = slot; loc.room_id = nil
    end

    -- remove item from inventory if present
    local inv = world:get_component(actor_eid, "inventory")
    if inv and inv.items[item_eid] then
        inv.items[item_eid] = nil
        local ii = world:get_component(item_eid, "item_info")
        inv.weight_current = math.max(0, inv.weight_current - (ii and ii.weight or 0))
    end

    world:emit("item_equipped", { entity_id=actor_eid, item_id=item_eid, slot=slot })
    return true
end

function M.unequip(world, actor_eid, slot)
    local slots = world:get_component(actor_eid, "equipment_slots")
    if not slots then return false end
    local item_eid = slots[slot]
    if not item_eid then return false end

    slots[slot] = nil

    local loc = world:get_component(item_eid, "location")
    if loc then
        loc.type = "inventory"; loc.slot = nil; loc.owner_id = actor_eid
    end

    -- add back to inventory
    local inv = world:get_component(actor_eid, "inventory")
    if inv then
        inv.items[item_eid] = true
        local ii = world:get_component(item_eid, "item_info")
        inv.weight_current = inv.weight_current + (ii and ii.weight or 0)
    end

    world:emit("item_unequipped", { entity_id=actor_eid, item_id=item_eid, slot=slot })
    return true
end

-- Equip best weapon in inventory
function M.auto_equip(world, actor_eid)
    local inv   = world:get_component(actor_eid, "inventory")
    local slots = world:get_component(actor_eid, "equipment_slots")
    if not inv or not slots then return end

    local stats_sys = require("systems.stats_system")
    local cur_atk   = stats_sys.get_stat(world, actor_eid, "attack")

    for item_eid in pairs(inv.items) do
        local eq = world:get_component(item_eid, "equippable")
        if eq then
            -- simple: if slot is empty, equip it
            if not slots[eq.slot] then
                M.equip(world, actor_eid, item_eid)
            else
                -- compare attack bonus
                local new_bonus = 0
                for _, m in ipairs(eq.modifiers or {}) do
                    if m.stat == "attack" and m.type == "add" then
                        new_bonus = new_bonus + m.value
                    end
                end
                local cur_item   = slots[eq.slot]
                local cur_bonus  = 0
                if cur_item then
                    local ceq = world:get_component(cur_item, "equippable")
                    for _, m in ipairs(ceq and ceq.modifiers or {}) do
                        if m.stat == "attack" and m.type == "add" then
                            cur_bonus = cur_bonus + m.value
                        end
                    end
                end
                if new_bonus > cur_bonus then
                    M.equip(world, actor_eid, item_eid)
                end
            end
        end
    end
end

return M
