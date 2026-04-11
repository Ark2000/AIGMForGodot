-- Dungeon topology queries — systems must use this instead of raw _room_index

local M = {}

-- Returns list of room_ids reachable from room_id (open connections only)
function M.get_neighbors(world, room_id)
    local conns = world:get_component(room_id, "connections")
    if not conns then return {} end
    local result = {}
    for _, conn in pairs(conns) do
        if conn.state == "open" then
            table.insert(result, conn.target_room_id)
        end
    end
    return result
end

-- Returns all connections (including locked/hidden)
function M.get_connections(world, room_id)
    return world:get_component(room_id, "connections") or {}
end

-- BFS shortest path; returns array of room_ids including from and to, or nil
function M.find_path(world, from_room, to_room)
    if from_room == to_room then return { from_room } end
    local visited = { [from_room] = true }
    local queue   = { { from_room } }
    local head    = 1
    while head <= #queue do
        local path = queue[head]; head = head + 1
        local current = path[#path]
        for _, nid in ipairs(M.get_neighbors(world, current)) do
            if nid == to_room then
                local full = {}
                for _, r in ipairs(path) do table.insert(full, r) end
                table.insert(full, nid)
                return full
            end
            if not visited[nid] then
                visited[nid] = true
                local new_path = {}
                for _, r in ipairs(path) do table.insert(new_path, r) end
                table.insert(new_path, nid)
                table.insert(queue, new_path)
            end
        end
    end
    return nil -- unreachable
end

-- Returns list of entity ids within graph-distance `range` of room_id
-- filter_fn(eid) optional — return false to exclude
function M.find_entities_in_range(world, room_id, range, filter_fn)
    local visited = { [room_id] = 0 }
    local queue   = { { room_id, 0 } }
    local head    = 1
    local result  = {}
    while head <= #queue do
        local curr_room, dist = queue[head][1], queue[head][2]; head = head + 1
        for _, eid in ipairs(world:get_entities_in_room(curr_room)) do
            if not filter_fn or filter_fn(eid) then
                table.insert(result, eid)
            end
        end
        if dist < range then
            for _, nid in ipairs(M.get_neighbors(world, curr_room)) do
                if not visited[nid] then
                    visited[nid] = dist + 1
                    table.insert(queue, { nid, dist + 1 })
                end
            end
        end
    end
    return result
end

-- Returns the floor number of a room
function M.get_floor_of_room(world, room_id)
    local ri = world:get_component(room_id, "room_info")
    if ri then return ri.floor end
    return nil
end

-- Returns the exit room eid for a given floor number
function M.get_stairs_down(world, floor_num)
    local floor_data = world.dungeon.floors[floor_num]
    if not floor_data then return nil end
    return floor_data.exit
end

-- Graph distance between two rooms (returns nil if not reachable)
function M.graph_distance(world, room_a, room_b)
    local path = M.find_path(world, room_a, room_b)
    if not path then return nil end
    return #path - 1
end

return M
