local util = require("core.util")

local M = {}
M.__index = M

local CATEGORIES = {
    "entity_def", "item_def", "skill_def", "status_def",
    "behavior_def", "room_template", "floor_config",
}

function M.new()
    local r = setmetatable({}, M)
    r._defs = {}
    for _, cat in ipairs(CATEGORIES) do r._defs[cat] = {} end
    return r
end

function M:register(category, id, def)
    if not self._defs[category] then
        self._defs[category] = {}
    end
    assert(not self._defs[category][id],
        string.format("Duplicate registration: %s/%s", category, id))
    self._defs[category][id] = def
end

function M:get(category, id)
    local cat = self._defs[category]
    assert(cat, "Unknown category: " .. tostring(category))
    local def = cat[id]
    assert(def, string.format("Unknown %s: %s", category, tostring(id)))
    return def
end

function M:try_get(category, id)
    local cat = self._defs[category]
    if not cat then return nil end
    return cat[id]
end

function M:get_all(category)
    return self._defs[category] or {}
end

-- Load a single file and register its contents.
-- The file returns { category=..., id=..., ... } or just the def
-- (determined by caller convention).
function M:load_file(path, category, id)
    local def = require(path)
    self:register(category, id or def.id, def)
end

-- Spawn an entity from an entity_def, merging optional overrides.
-- overrides: { [comp_name] = { field=val, ... } } – shallow-merged per component
function M:spawn_entity(world, def_id, overrides)
    local def = self:get("entity_def", def_id)
    local eid = world:create_entity()

    -- deep-copy all components so instances never share references
    for comp_name, comp_data in pairs(def.components or {}) do
        local data = util.deep_copy(comp_data)
        -- apply per-component override
        if overrides and overrides[comp_name] then
            for k, v in pairs(overrides[comp_name]) do
                data[k] = v
            end
        end
        world:add_component(eid, comp_name, data)
    end

    -- top-level overrides that add new components (e.g. position)
    if overrides then
        for comp_name, comp_data in pairs(overrides) do
            if not (def.components and def.components[comp_name]) then
                world:add_component(eid, comp_name, util.deep_copy(comp_data))
            end
        end
    end

    -- debug marker
    world:add_component(eid, "definition", { def_id = def_id })

    return eid
end

return M
