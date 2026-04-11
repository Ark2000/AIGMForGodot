-- Priority 40 — execute pick_up and use_item intents

local stats_system    = require("systems.stats_system")
local equipment_system = require("systems.equipment_system")
local util            = require("core.util")

return {
    name     = "item_system",
    priority = 40,

    update = function(world)
        local eids = world:query({ "action_timer", "ai_intent" })

        for _, eid in ipairs(eids) do
            if not world:is_alive(eid) then goto continue end

            local intent = world:get_component(eid, "ai_intent")
            if not intent then goto continue end

            -- ── pick_up ───────────────────────────────────────────────────
            if intent.action == "pick_up" then
                local item_id = intent.target
                if not item_id or not world:is_alive(item_id) then
                    world:remove_component(eid, "ai_intent")
                    goto continue
                end

                local loc  = world:get_component(item_id, "location")
                local pos  = world:get_component(eid,     "position")
                if not loc or loc.type ~= "ground" then
                    world:remove_component(eid, "ai_intent")
                    goto continue
                end
                if loc.room_id ~= pos.room_id then
                    world:remove_component(eid, "ai_intent")
                    goto continue
                end

                local inv = world:get_component(eid, "inventory")
                local ii  = world:get_component(item_id, "item_info")
                local w   = ii and ii.weight or 0
                if inv and (inv.weight_current + w) > inv.capacity then
                    world:remove_component(eid, "ai_intent")
                    goto continue
                end

                -- Move to inventory
                loc.type     = "inventory"
                loc.owner_id = eid
                loc.room_id  = nil

                if inv then
                    inv.items[item_id]   = true
                    inv.weight_current   = inv.weight_current + w
                end

                -- Remove from room index
                world:remove_component(item_id, "position")

                world:emit("item_picked_up", { entity_id=eid, item_id=item_id })

                -- Try to equip if it's better
                local adv = world:get_component(eid, "adventurer_goal")
                if adv then
                    local eq = world:get_component(item_id, "equippable")
                    if eq then
                        equipment_system.auto_equip(world, eid)
                    end
                end

                -- Reset timer
                local at    = world:get_component(eid, "action_timer")
                local actor = world:get_component(eid, "actor")
                if at and actor then
                    local spd = stats_system.get_stat(world, eid, "speed")
                    at.cooldown_max = math.max(1, math.floor(actor.move_cooldown * 10 / math.max(1, spd)))
                    at.cooldown_cur = at.cooldown_max
                    at.ready        = false
                end

                world:remove_component(eid, "ai_intent")

            -- ── use_item ──────────────────────────────────────────────────
            elseif intent.action == "use_item" then
                local item_id = intent.target
                if not item_id or not world:is_alive(item_id) then
                    world:remove_component(eid, "ai_intent")
                    goto continue
                end

                local usable = world:get_component(item_id, "usable")
                if not usable then
                    world:remove_component(eid, "ai_intent")
                    goto continue
                end

                -- Apply effects
                for _, eff in ipairs(usable.effects or {}) do
                    if eff.type == "heal" then
                        local hp     = stats_system.get_hp(world, eid)
                        local hp_max = stats_system.get_stat(world, eid, "hp_max")
                        local new_hp = math.min(hp_max, hp + (eff.amount or 0))
                        stats_system.set_hp(world, eid, new_hp)
                        world:emit("entity_healed", { entity_id=eid, amount=new_hp-hp, item_id=item_id })

                    elseif eff.type == "remove_modifier" then
                        local mods = world:get_component(eid, "active_modifiers")
                        if mods and eff.modifier_id then
                            mods[eff.modifier_id] = nil
                        end
                    end
                end

                -- Consume if consumable
                if usable.consumable then
                    local inv = world:get_component(eid, "inventory")
                    if inv then
                        inv.items[item_id] = nil
                        local ii = world:get_component(item_id, "item_info")
                        inv.weight_current = math.max(0, inv.weight_current - (ii and ii.weight or 0))
                    end
                    local loc = world:get_component(item_id, "location")
                    if loc then loc.type = "consumed" end
                    world:destroy_entity(item_id)
                end

                world:emit("item_used", { entity_id=eid, item_id=item_id })

                local at    = world:get_component(eid, "action_timer")
                local actor = world:get_component(eid, "actor")
                if at and actor then
                    local spd = stats_system.get_stat(world, eid, "speed")
                    at.cooldown_max = math.max(1, math.floor(actor.move_cooldown * 10 / math.max(1, spd)))
                    at.cooldown_cur = at.cooldown_max
                    at.ready        = false
                end

                world:remove_component(eid, "ai_intent")
            end

            ::continue::
        end
    end,
}
