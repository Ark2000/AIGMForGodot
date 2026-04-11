local M = {}
M.__index = M

function M.new()
    local s = setmetatable({}, M)
    s._systems = {}
    return s
end

function M:register(system)
    assert(system.name,     "system must have a name")
    assert(system.priority, "system must have a priority")
    assert(system.update,   "system must have an update function")
    table.insert(self._systems, system)
    table.sort(self._systems, function(a, b) return a.priority < b.priority end)
end

function M:init(world)
    for _, sys in ipairs(self._systems) do
        if sys.init then sys.init(world) end
    end
end

function M:run(world)
    for _, sys in ipairs(self._systems) do
        local n = sys.on_tick or 1
        if world.tick % n == 0 then
            sys.update(world)
        end
    end
end

return M
