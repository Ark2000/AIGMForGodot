-- Adventurer behavior: complex goal-driven FSM
local util = require("core.util")

-- ── helpers ──────────────────────────────────────────────────────────────────

local function get_enemies_in_room(world, eid, room_id)
    local faction = world:get_component(eid, "faction")
    if not faction then return {} end
    local enemies = {}
    for _, other in ipairs(world:get_entities_in_room(room_id)) do
        if other ~= eid and world:get_component(other, "is_actor") and world:is_alive(other) then
            local of = world:get_component(other, "faction")
            if of and faction.hostility[of.id] == "aggressive" then
                table.insert(enemies, other)
            end
        end
    end
    return enemies
end

local function get_items_in_room(world, room_id)
    local items = {}
    for _, eid in ipairs(world:get_entities_in_room(room_id)) do
        local loc = world:get_component(eid, "location")
        if loc and loc.type == "ground" then
            table.insert(items, eid)
        end
    end
    return items
end

local function has_healing_item(world, eid)
    local inv = world:get_component(eid, "inventory")
    if not inv then return false end
    for item_id in pairs(inv.items) do
        local ii = world:get_component(item_id, "item_info")
        if ii and util.table_contains(ii.tags or {}, "healing") then return true end
    end
    return false
end

local function has_yendor(world, eid)
    local inv = world:get_component(eid, "inventory")
    if not inv then return false end
    for item_id in pairs(inv.items) do
        local ii = world:get_component(item_id, "item_info")
        if ii and util.table_contains(ii.tags or {}, "quest_item") then return true end
    end
    return false
end

local function count_healing_items(world, eid)
    local inv = world:get_component(eid, "inventory")
    if not inv then return 0 end
    local n = 0
    for item_id in pairs(inv.items) do
        local ii = world:get_component(item_id, "item_info")
        if ii and util.table_contains(ii.tags or {}, "healing") then n = n + 1 end
    end
    return n
end

-- Try to use a skill; returns intent or nil
local function try_skill(world, eid, enemies)
    local skills = world:get_component(eid, "skills")
    if not skills then return nil end
    local registry = world._registry
    if not registry then return nil end
    -- pick best ready skill
    local best_skill, best_weight = nil, -1
    for sid, sd in pairs(skills) do
        if sd.cooldown_cur <= 0 then
            local def = registry:try_get("skill_def", sd.def_id)
            if def then
                local w = def.ai_weight and def.ai_weight(world, eid, enemies[1]) or 0.5
                if w > best_weight then
                    best_weight = w
                    best_skill  = sid
                end
            end
        end
    end
    if best_skill and #enemies > 0 then
        return { action="use_skill", target={ skill_id=best_skill, target_eid=enemies[1] } }
    end
    return nil
end

-- Use best consumable healing item
local function use_healing(world, eid)
    local inv = world:get_component(eid, "inventory")
    if not inv then return nil end
    for item_id in pairs(inv.items) do
        local ii = world:get_component(item_id, "item_info")
        if ii and util.table_contains(ii.tags or {}, "healing") then
            return { action="use_item", target=item_id }
        end
    end
    return nil
end

-- Move toward a target room via path
local function move_toward(world, eid, target_room_id)
    local topology = require("dungeon.topology")
    local pos = world:get_component(eid, "position")
    if not pos then return nil end
    if pos.room_id == target_room_id then return nil end
    local path = topology.find_path(world, pos.room_id, target_room_id)
    if not path or #path < 2 then return nil end
    return { action="move", target=path[2] }
end

-- Wander to unexplored room
local function explore_move(world, eid, goal)
    local topology = require("dungeon.topology")
    local pos = world:get_component(eid, "position")
    if not pos then return nil end
    local neighbors = topology.get_neighbors(world, pos.room_id)
    -- prefer unexplored
    local unexplored = {}
    for _, nid in ipairs(neighbors) do
        if not goal.explored_rooms[nid] then
            table.insert(unexplored, nid)
        end
    end
    if #unexplored > 0 then
        return { action="move", target=util.random_pick(unexplored) }
    end
    if #neighbors > 0 then
        return { action="move", target=util.random_pick(neighbors) }
    end
    return { action="wait" }
end

-- ── main decide ──────────────────────────────────────────────────────────────

return {
    id = "adventurer",
    decide = function(world, eid)
        local stats_system = require("systems.stats_system")
        local topology     = require("dungeon.topology")

        local pos  = world:get_component(eid, "position")
        local goal = world:get_component(eid, "adventurer_goal")
        if not pos or not goal then return nil end

        local room_id = pos.room_id
        local stats   = world:get_component(eid, "stats")
        if not stats then return nil end

        local hp     = stats_system.get_stat(world, eid, "hp")
        local hp_max = stats_system.get_stat(world, eid, "hp_max")

        -- mark current room explored
        goal.explored_rooms[room_id] = true

        -- record known stairs
        local ri = world:get_component(room_id, "room_info")
        if ri and (ri.type == "stairs" or ri.type == "stairs_down") then
            goal.known_stairs = room_id
        end

        -- ── Yendor acquired: switch to escape_with_yendor ─────────────────
        if has_yendor(world, eid)
            and goal.current_stage ~= "escape_with_yendor"
            and goal.current_stage ~= "escape" then
            goal.current_stage = "escape_with_yendor"
        end

        -- ── Emergency escape ──────────────────────────────────────────────
        if hp < hp_max * 0.25 and not has_healing_item(world, eid)
            and goal.current_stage ~= "escape"
            and goal.current_stage ~= "escape_with_yendor" then
            goal.current_stage = "escape"
        end

        -- ── Heal if injured and in no combat ─────────────────────────────
        local enemies = get_enemies_in_room(world, eid, room_id)
        if hp < hp_max * 0.6 and #enemies == 0 and has_healing_item(world, eid) then
            local heal_intent = use_healing(world, eid)
            if heal_intent then return heal_intent end
        end

        -- ── Fight enemies in room ─────────────────────────────────────────
        if #enemies > 0 then
            local sk = try_skill(world, eid, enemies)
            if sk then return sk end
            return { action="attack", target=enemies[1] }
        end

        -- ── Pick up interesting items ─────────────────────────────────────
        local room_items = get_items_in_room(world, room_id)
        for _, item_id in ipairs(room_items) do
            if world:is_alive(item_id) then
                local ii = world:get_component(item_id, "item_info")
                if ii then
                    -- Always pick up Yendor
                    if util.table_contains(ii.tags or {}, "quest_item") then
                        return { action="pick_up", target=item_id }
                    end
                    -- Pick up healing if low
                    if util.table_contains(ii.tags or {}, "healing") and hp < hp_max * 0.9 then
                        return { action="pick_up", target=item_id }
                    end
                    -- Pick up weapons and armor (upgrade)
                    if util.table_contains(ii.tags or {}, "weapon") or
                       util.table_contains(ii.tags or {}, "armor") then
                        local inv = world:get_component(eid, "inventory")
                        if inv and inv.weight_current + (ii.weight or 0) <= inv.capacity then
                            return { action="pick_up", target=item_id }
                        end
                    end
                end
            end
        end

        -- ── Goal-based movement ───────────────────────────────────────────
        local stage = goal.current_stage
        local lvl   = world:get_component(eid, "level")
        local cur_level = lvl and lvl.current or 1

        -- detect floor
        local cur_floor = ri and ri.floor or goal.target_floor or 1

        if stage == "escape" or stage == "escape_with_yendor" then
            -- Head to floor 1 entrance (find_path handles cross-floor BFS)
            local f1 = world.dungeon.floors[1]
            if f1 then
                local entrance = f1.entrance
                if room_id == entrance then
                    -- Escaped!
                    world:emit("adventurer_escaped", { entity_id = eid })
                    return { action="wait" }
                end
                local intent = move_toward(world, eid, entrance)
                if intent then return intent end
            end
            return explore_move(world, eid, goal)

        elseif stage == "explore_floor" then
            -- Transition check: strong enough to descend?
            local floor_cfg = world._registry and world._registry:try_get("floor_config", "floor_" .. cur_floor)
            local rec_level = floor_cfg and floor_cfg.recommended_level or cur_floor
            if cur_level >= rec_level and count_healing_items(world, eid) >= 1 then
                goal.current_stage = "find_stairs"
                stage = "find_stairs"
            else
                -- explore
                return explore_move(world, eid, goal)
            end

        end

        if stage == "find_stairs" or stage == "seek_strength" then
            -- Know stairs? go there
            if goal.known_stairs then
                if room_id == goal.known_stairs then
                    goal.current_stage = "descend"
                    stage = "descend"
                else
                    local intent = move_toward(world, eid, goal.known_stairs)
                    if intent then return intent end
                end
            else
                -- explore to find them
                return explore_move(world, eid, goal)
            end
        end

        if stage == "descend" then
            -- Move through stairs connection (topology handles cross-floor)
            if goal.known_stairs and room_id == goal.known_stairs then
                -- find the stairs connection target
                local conns = world:get_component(room_id, "connections")
                if conns then
                    for _, conn in pairs(conns) do
                        if conn.type == "stairs_down" or conn.type == "stairs_up" then
                            local tfloor_ri = world:get_component(conn.target_room_id, "room_info")
                            if tfloor_ri and tfloor_ri.floor and tfloor_ri.floor > cur_floor then
                                goal.target_floor   = tfloor_ri.floor
                                goal.known_stairs   = nil
                                goal.current_stage  = "explore_floor"
                                -- on deepest floor, hunt boss
                                if tfloor_ri.floor == world.dungeon.total_floors then
                                    goal.current_stage = "hunt_boss"
                                end
                                return { action="move", target=conn.target_room_id }
                            end
                        end
                    end
                end
            else
                if goal.known_stairs then
                    local intent = move_toward(world, eid, goal.known_stairs)
                    if intent then return intent end
                end
            end
            goal.current_stage = "find_stairs"
            return explore_move(world, eid, goal)
        end

        if stage == "hunt_boss" then
            local this_floor = world.dungeon.floors[cur_floor]
            local boss_room  = this_floor and this_floor.boss_room
            if boss_room then
                if room_id == boss_room then
                    -- Stay and fight; transition only when boss_room is clear
                    if #enemies == 0 then
                        goal.current_stage = "retrieve_artifact"
                        stage = "retrieve_artifact"
                    else
                        -- fight handled above; shouldn't reach here, but just in case
                        return { action="wait" }
                    end
                else
                    local intent = move_toward(world, eid, boss_room)
                    if intent then return intent end
                end
            end
            if stage == "hunt_boss" then
                return explore_move(world, eid, goal)
            end
        end

        if stage == "retrieve_artifact" then
            -- Go to boss_room to find the Amulet (it spawns there)
            local this_floor = world.dungeon.floors[cur_floor]
            local boss_room  = this_floor and this_floor.boss_room
            if boss_room then
                if room_id ~= boss_room then
                    local intent = move_toward(world, eid, boss_room)
                    if intent then return intent end
                end
                -- In boss_room: check if Yendor is still here
                local has_quest_item_in_room = false
                for _, iid in ipairs(get_items_in_room(world, room_id)) do
                    local ii = world:get_component(iid, "item_info")
                    if ii and util.table_contains(ii.tags or {}, "quest_item") then
                        has_quest_item_in_room = true
                        break
                    end
                end
                if has_quest_item_in_room then
                    -- item pickup logic above will handle it; wait this tick
                    return { action="wait" }
                else
                    -- Yendor is gone (taken by another adventurer); nothing to do here
                    goal.current_stage = "escape"
                    stage = "escape"
                end
            end
            if stage == "retrieve_artifact" then
                return explore_move(world, eid, goal)
            end
        end

        return explore_move(world, eid, goal)
    end,
}
