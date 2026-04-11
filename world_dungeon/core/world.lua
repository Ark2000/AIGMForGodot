local M = {}
M.__index = M

function M.new()
    local w = setmetatable({}, M)
    w._next_id     = 1
    w._entities    = {}   -- { [eid] = true }
    w._destroyed   = {}   -- { [eid] = true } – marked for removal
    w._components  = {}   -- { [comp_name] = { [eid] = data } }
    w._room_index  = {}   -- { [room_id] = { [eid] = true } }
    w._event_log   = {}   -- append-only list of events
    w._listeners   = {}   -- { [event_type] = { fn, ... } }
    w._destroy_queue = {} -- ordered list so flush is deterministic
    w.tick         = 0
    w.dungeon      = { floors = {}, total_floors = 0 }
    w.ecology      = { population = {}, floor_activity = {} }
    w.hall_of_fame = {}
    return w
end

-- ── Entity management ───────────────────────────────────────────────────────

function M:create_entity()
    local id = self._next_id
    self._next_id = self._next_id + 1
    self._entities[id] = true
    return id
end

function M:destroy_entity(id)
    if not self._entities[id] then return end
    if not self._destroyed[id] then
        self._destroyed[id] = true
        table.insert(self._destroy_queue, id)
    end
end

function M:is_alive(id)
    return self._entities[id] == true and not self._destroyed[id]
end

function M:flush_destroyed()
    for _, id in ipairs(self._destroy_queue) do
        -- remove from room index
        local pos = self:get_component(id, "position")
        if pos and pos.room_id then
            local ri = self._room_index[pos.room_id]
            if ri then ri[id] = nil end
        end
        -- remove all components
        for _, store in pairs(self._components) do
            store[id] = nil
        end
        self._entities[id] = nil
        self._destroyed[id] = nil
    end
    self._destroy_queue = {}
end

-- ── Component management ────────────────────────────────────────────────────

function M:add_component(eid, name, data)
    if not self._components[name] then
        self._components[name] = {}
    end
    self._components[name][eid] = data
    -- maintain room index when position is added
    if name == "position" and data and data.room_id then
        local rid = data.room_id
        if not self._room_index[rid] then
            self._room_index[rid] = {}
        end
        self._room_index[rid][eid] = true
    end
end

function M:get_component(eid, name)
    local store = self._components[name]
    if not store then return nil end
    return store[eid]
end

function M:remove_component(eid, name)
    if name == "position" then
        local pos = self:get_component(eid, name)
        if pos and pos.room_id then
            local ri = self._room_index[pos.room_id]
            if ri then ri[eid] = nil end
        end
    end
    local store = self._components[name]
    if store then store[eid] = nil end
end

function M:has_component(eid, name)
    local store = self._components[name]
    return store ~= nil and store[eid] ~= nil
end

-- Returns list of eids that have all of the given component names
function M:query(comp_names)
    -- find smallest set
    local min_store, min_count = nil, math.huge
    for _, name in ipairs(comp_names) do
        local store = self._components[name]
        if not store then return {} end
        local n = 0
        for _ in pairs(store) do n = n + 1 end
        if n < min_count then min_store = store; min_count = n end
    end
    if not min_store then return {} end
    local result = {}
    for eid in pairs(min_store) do
        if self._entities[eid] and not self._destroyed[eid] then
            local ok = true
            for _, name in ipairs(comp_names) do
                local s = self._components[name]
                if not s or not s[eid] then ok = false; break end
            end
            if ok then table.insert(result, eid) end
        end
    end
    return result
end

function M:get_all_entities_with(comp_name)
    local result = {}
    local store = self._components[comp_name]
    if not store then return result end
    for eid in pairs(store) do
        if self._entities[eid] and not self._destroyed[eid] then
            table.insert(result, eid)
        end
    end
    return result
end

-- ── Spatial queries ─────────────────────────────────────────────────────────

function M:get_entities_in_room(room_id)
    local result = {}
    local ri = self._room_index[room_id]
    if not ri then return result end
    for eid in pairs(ri) do
        if self._entities[eid] and not self._destroyed[eid] then
            table.insert(result, eid)
        end
    end
    return result
end

function M:move_entity_to_room(eid, new_room_id)
    local pos = self:get_component(eid, "position")
    if not pos then
        self:add_component(eid, "position", { room_id = new_room_id })
        return
    end
    -- remove from old room
    if pos.room_id then
        local ri = self._room_index[pos.room_id]
        if ri then ri[eid] = nil end
    end
    -- add to new room
    pos.room_id = new_room_id
    if not self._room_index[new_room_id] then
        self._room_index[new_room_id] = {}
    end
    self._room_index[new_room_id][eid] = true
end

-- ── Event system ─────────────────────────────────────────────────────────────

function M:emit(event_type, data)
    local event = { type = event_type, tick = self.tick, data = data or {} }
    table.insert(self._event_log, event)
    local listeners = self._listeners[event_type]
    if listeners then
        for _, fn in ipairs(listeners) do
            fn(event)
        end
    end
end

function M:subscribe(event_type, fn)
    if not self._listeners[event_type] then
        self._listeners[event_type] = {}
    end
    table.insert(self._listeners[event_type], fn)
end

-- ── Tick ─────────────────────────────────────────────────────────────────────

function M:advance_tick()
    self.tick = self.tick + 1
    self:flush_destroyed()
end

-- Convenience: entity name for logging
function M:entity_name(eid)
    if not eid then return "?" end
    local id = self:get_component(eid, "identity")
    if id then return id.name end
    local def = self:get_component(eid, "definition")
    if def then return def.def_id .. "#" .. eid end
    return "entity#" .. eid
end

return M
