local M = {}

function M.deep_copy(obj)
    if type(obj) ~= "table" then return obj end
    local copy = {}
    for k, v in pairs(obj) do
        copy[M.deep_copy(k)] = M.deep_copy(v)
    end
    return setmetatable(copy, getmetatable(obj))
end

function M.table_merge(target, source)
    local result = M.deep_copy(target)
    for k, v in pairs(source or {}) do
        result[k] = v
    end
    return result
end

function M.table_size(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function M.table_contains(t, value)
    for _, v in pairs(t) do
        if v == value then return true end
    end
    return false
end

-- Fisher-Yates in-place shuffle
function M.shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- items: list of {value, weight}
function M.weighted_random(items)
    local total = 0
    for _, p in ipairs(items) do total = total + p[2] end
    if total == 0 then return items[1] and items[1][1] end
    local r = math.random() * total
    local cum = 0
    for _, p in ipairs(items) do
        cum = cum + p[2]
        if r <= cum then return p[1] end
    end
    return items[#items][1]
end

-- keys of a table as a list
function M.keys(t)
    local ks = {}
    for k in pairs(t) do table.insert(ks, k) end
    return ks
end

-- random element from an array
function M.random_pick(t)
    if #t == 0 then return nil end
    return t[math.random(#t)]
end

return M
