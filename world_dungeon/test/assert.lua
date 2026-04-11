local M = {}

local _passed = 0
local _failed = 0
local _current_suite = ""

function M.suite(name)
    _current_suite = name
    print(string.format("[%s]", name))
end

local function pass(msg)
    _passed = _passed + 1
    print(string.format("  \27[32m✓\27[0m %s", msg))
end

local function fail(msg, expected, actual, info)
    _failed = _failed + 1
    io.write(string.format("  \27[31m✗ FAILED:\27[0m %s\n", msg))
    if expected ~= nil then
        io.write(string.format("    Expected: %s\n", tostring(expected)))
    end
    if actual ~= nil then
        io.write(string.format("    Actual:   %s\n", tostring(actual)))
    end
    if info then
        io.write(string.format("    Location: %s\n", info))
    end
end

local function location()
    local info = debug.getinfo(3, "Sl")
    return info and (info.short_src .. ":" .. info.currentline) or "?"
end

function M.equal(actual, expected, msg)
    if actual == expected then pass(msg or "equal")
    else fail(msg or "equal", expected, actual, location()) end
end

function M.not_equal(actual, expected, msg)
    if actual ~= expected then pass(msg or "not_equal")
    else fail(msg or "not_equal — values should differ", nil, actual, location()) end
end

function M.is_true(val, msg)
    if val then pass(msg or "is_true")
    else fail(msg or "expected true", true, val, location()) end
end

function M.is_false(val, msg)
    if not val then pass(msg or "is_false")
    else fail(msg or "expected false", false, val, location()) end
end

function M.is_nil(val, msg)
    if val == nil then pass(msg or "is_nil")
    else fail(msg or "expected nil", nil, val, location()) end
end

function M.not_nil(val, msg)
    if val ~= nil then pass(msg or "not_nil")
    else fail(msg or "expected non-nil", "non-nil", nil, location()) end
end

function M.greater_than(actual, bound, msg)
    if actual > bound then pass(msg or "greater_than")
    else fail(msg or "greater_than", ">"..tostring(bound), actual, location()) end
end

function M.less_than(actual, bound, msg)
    if actual < bound then pass(msg or "less_than")
    else fail(msg or "less_than", "<"..tostring(bound), actual, location()) end
end

function M.has_key(t, key, msg)
    if type(t) == "table" and t[key] ~= nil then pass(msg or "has_key:"..tostring(key))
    else fail(msg or "missing key: "..tostring(key), nil, nil, location()) end
end

function M.table_size(t, expected_size, msg)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    if n == expected_size then pass(msg or "table_size="..expected_size)
    else fail(msg or "table_size", expected_size, n, location()) end
end

function M.no_error(fn, msg)
    local ok, err = pcall(fn)
    if ok then pass(msg or "no_error")
    else fail(msg or "unexpected error", nil, tostring(err), location()) end
end

function M.has_error(fn, msg)
    local ok = pcall(fn)
    if not ok then pass(msg or "has_error")
    else fail(msg or "expected an error but got none", nil, nil, location()) end
end

function M.summary()
    print(string.rep("─", 44))
    local total = _passed + _failed
    print(string.format("Total: %d passed, %d failed  (%d total)", _passed, _failed, total))
    return _failed == 0
end

function M.reset()
    _passed = 0
    _failed = 0
    _current_suite = ""
end

return M
