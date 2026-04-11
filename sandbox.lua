--[[
  Lua sandbox — restricted execution environment for the run_lua tool.
  Exposed API: sandbox.run(code, cfg) -> string
  cfg fields used:
    sandbox_max_instructions (number)
    agent_state_path (string|nil) — path to agent_state.json; backs state_get/state_set/events_read cursor
    events_path      (string|nil) — path to events.jsonl; used by events_read
]]

local json    = require("json")
local sandbox = {}

local function make_env(cfg)
  cfg = cfg or {}
  local print_buf = {}

  -- host-level helpers (io/os are NOT exposed in sandbox _G, only used here in closures)
  local function read_file_raw(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
  end

  local function write_atomic_raw(path, text)
    local tmp = path .. ".tmp"
    local f = io.open(tmp, "wb")
    if not f then return end
    f:write(text); f:close()
    os.remove(path)
    local ok = os.rename(tmp, path)
    if not ok then os.remove(path); os.rename(tmp, path) end
  end

  local function load_state()
    if not cfg.agent_state_path then return {} end
    local s = read_file_raw(cfg.agent_state_path)
    if not s then return {} end
    local ok, t = pcall(json.decode, s)
    return (ok and type(t) == "table") and t or {}
  end

  local function save_state(st)
    if not cfg.agent_state_path then return end
    write_atomic_raw(cfg.agent_state_path, json.encode(st))
  end

  local env = {
    -- standard libraries
    math   = math,
    string = string,
    table  = table,
    utf8   = utf8,

    -- safe builtins
    tostring  = tostring,
    tonumber  = tonumber,
    type      = type,
    ipairs    = ipairs,
    pairs     = pairs,
    select    = select,
    error     = error,
    assert    = assert,
    pcall     = pcall,
    xpcall    = xpcall,
    unpack    = table.unpack,  -- Lua 5.4 compat alias

    print  = function(...)
      local t = { ... }
      for i = 1, #t do t[i] = tostring(t[i]) end
      table.insert(print_buf, table.concat(t, "\t"))
    end,

    -- JSON helpers for structured data
    json_encode = function(val) return json.encode(val) end,
    json_decode = function(s)   return json.decode(s)   end,

    -- Persistent world model (backed by agent_state.json)
    state_get = function(key)
      return load_state()[key]
    end,

    state_set = function(key, val)
      local st = load_state()
      st[key] = val
      save_state(st)
    end,

    -- Shared game world state (backed by world.json) — readable and writable by agent.
    world_get = function(key)
      if not cfg.world_path then return nil end
      local s = read_file_raw(cfg.world_path)
      if not s then return nil end
      local ok, t = pcall(json.decode, s)
      if not (ok and type(t) == "table") then return nil end
      return t[key]
    end,

    world_set = function(key, val)
      if not cfg.world_path then return end
      local s = read_file_raw(cfg.world_path)
      local world = {}
      if s then
        local ok, t = pcall(json.decode, s)
        if ok and type(t) == "table" then world = t end
      end
      world[key] = val
      write_atomic_raw(cfg.world_path, json.encode(world))
    end,

    -- Read up to n unread game events from events.jsonl; advances agent read cursor.
    -- Returns a JSON-encoded array string.
    events_read = function(n)
      if not cfg.events_path then return "[]" end
      n = (type(n) == "number" and n > 0) and math.floor(n) or 50
      local st = load_state()
      local cursor = tonumber(st._events_cursor) or 0
      local f = io.open(cfg.events_path, "rb")
      if not f then return "[]" end
      local seeked = f:seek("set", cursor)
      if not seeked then f:close(); return "[]" end
      local events = {}
      local new_pos = cursor
      while #events < n do
        local line = f:read("*l")
        if not line then break end
        new_pos = f:seek("cur", 0)
        line = line:gsub("\r$", "")
        if line ~= "" then
          local ok2, ev = pcall(json.decode, line)
          if ok2 and type(ev) == "table" then
            events[#events + 1] = ev
          end
        end
      end
      f:close()
      if new_pos ~= cursor then
        st._events_cursor = new_pos
        save_state(st)
      end
      return json.encode(events)
    end,
  }

  env._G = env
  return env, print_buf
end

function sandbox.run(code, cfg)
  local env, print_buf = make_env(cfg)
  local chunk, cerr = load(code, "@sandbox", "t", env)
  if not chunk then
    return "[compile] " .. tostring(cerr)
  end
  debug.sethook(function()
    error("SANDBOX_TIMEOUT")
  end, "i", cfg.sandbox_max_instructions)
  local ok, res = pcall(chunk)
  debug.sethook(nil)
  if not ok then
    local err = tostring(res)
    if err:find("SANDBOX_TIMEOUT") then
      return "[error] sandbox timeout (instruction limit)"
    end
    return "[error] " .. err
  end
  if res ~= nil then
    return tostring(res)
  end
  if #print_buf > 0 then
    return table.concat(print_buf, "\n")
  end
  return ""
end

return sandbox
