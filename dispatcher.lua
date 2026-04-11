--[[
  dispatcher.lua — poll loop: reads events.jsonl, checks agent triggers/schedule, wakes lua_agent.lua.

  Usage:
    .\lua54.exe dispatcher.lua [--session_dir=...] [--events_path=...] [--poll_s=1] [--once]

  --once exits after a single poll cycle (useful for testing).
  Wake messages are passed to lua_agent.lua via stdin as JSON:
    {"wake":"trigger",  "event":  {t, type, data}}
    {"wake":"schedule", "reason": "name"}
]]

local json = require("json")

local config = {
  session_dir  = "service_kimi/session_01",
  events_path  = "events.jsonl",
  cursor_path  = nil,   -- derived: session_dir/dispatcher_cursor.json
  lock_path    = nil,   -- derived: session_dir/agent.lock; game sim polls this
  poll_s       = 1,
  lua_exe      = ".\\lua54.exe",
  agent_script = "lua_agent.lua",
}

local once = false
for i = 1, #arg do
  local a = arg[i]
  if a == "--once" then
    once = true
  else
    local k, v = a:match("^%-%-([^=]+)=(.*)")
    if k then
      if k == "poll_s" then
        config.poll_s = tonumber(v) or config.poll_s
      else
        config[k] = v
      end
    end
  end
end

if not config.cursor_path then
  config.cursor_path = config.session_dir .. "/dispatcher_cursor.json"
end
if not config.lock_path then
  config.lock_path = config.session_dir .. "/agent.lock"
end

-- helpers

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a"); f:close()
  return s
end

local function write_atomic(path, text)
  local tmp = path .. ".tmp"
  local f = assert(io.open(tmp, "wb"))
  f:write(text); f:close()
  os.remove(path)
  local ok = os.rename(tmp, path)
  if not ok then os.remove(path); assert(os.rename(tmp, path)) end
end

local function read_cursor()
  return tonumber(read_file(config.cursor_path)) or 0
end

-- Read all new lines from events.jsonl since the dispatcher cursor.
-- Returns: events (array of tables), new_cursor (byte position after last line read)
local function read_new_events()
  local cursor = read_cursor()
  local f = io.open(config.events_path, "rb")
  if not f then return {}, cursor end
  local seeked = f:seek("set", cursor)
  if not seeked then f:close(); return {}, cursor end
  local events = {}
  local new_pos = cursor
  while true do
    local line = f:read("*l")
    if not line then break end
    new_pos = f:seek("cur", 0)
    line = line:gsub("\r$", "")
    if line ~= "" then
      local ok, ev = pcall(json.decode, line)
      if ok and type(ev) == "table" then
        events[#events + 1] = ev
      end
    end
  end
  f:close()
  return events, new_pos
end

local function load_agent_state()
  local s = read_file(config.session_dir .. "/agent_state.json")
  if not s then return {} end
  local ok, t = pcall(json.decode, s)
  return (ok and type(t) == "table") and t or {}
end

local function save_agent_state(st)
  write_atomic(config.session_dir .. "/agent_state.json", json.encode(st))
end

-- Wake the agent by writing the wake message to a temp file and piping it as stdin.
-- Writes lock_path before invoking so the game sim pauses; removes it after.
local function wake_agent(wake_msg)
  -- Signal game sim to pause
  local lf = io.open(config.lock_path, "wb")
  if lf then lf:write("1"); lf:close() end

  local wake_path = config.session_dir .. "/wake_msg.json"
  write_atomic(wake_path, json.encode(wake_msg))
  local cmd = string.format('%s "%s" < "%s"', config.lua_exe, config.agent_script, wake_path)
  io.stderr:write("[dispatcher] waking agent: wake=" .. (wake_msg.wake or "?") .. "\n")
  os.execute(cmd)

  -- Release lock: game sim resumes and fast-forwards [t1,t2]
  os.remove(config.lock_path)
end

local function poll_once()
  local events, new_pos = read_new_events()
  local old_cursor = read_cursor()

  -- advance dispatcher cursor past any new lines
  if new_pos ~= old_cursor then
    write_atomic(config.cursor_path, tostring(new_pos))
  end

  local state = load_agent_state()

  -- check event triggers
  local triggers = type(state.triggers) == "table" and state.triggers or {}
  local trigger_set = {}
  for _, v in ipairs(triggers) do trigger_set[tostring(v)] = true end

  for _, ev in ipairs(events) do
    if ev.type and trigger_set[ev.type] then
      wake_agent({ wake = "trigger", event = ev })
      return  -- one wake per poll cycle
    end
  end

  -- check schedule
  local schedule = type(state.schedule) == "table" and state.schedule or {}
  local now = os.time()
  for i, entry in ipairs(schedule) do
    if type(entry.at) == "number" and entry.at <= now then
      table.remove(schedule, i)
      state.schedule = schedule
      save_agent_state(state)
      wake_agent({ wake = "schedule", reason = entry.reason or "scheduled" })
      return
    end
  end
end

local function run_self_test()
  local state_tmp  = "z_disp_state.json"
  local events_tmp = "z_disp_events.jsonl"
  local cursor_tmp = "z_disp_cursor.json"

  -- helper: write a file
  local function wf(path, text)
    local f = assert(io.open(path, "wb")); f:write(text); f:close()
  end

  -- trigger match: event type in triggers list → wake_agent called
  wf(state_tmp,  json.encode({ triggers = { "boss_spawned", "player_died" } }))
  wf(events_tmp, '{"t":1,"type":"player_died","data":{}}\n{"t":2,"type":"noop","data":{}}\n')
  wf(cursor_tmp, "0")

  local old_cfg = {}
  for k, v in pairs(config) do old_cfg[k] = v end
  config.session_dir  = "."
  config.events_path  = events_tmp
  config.cursor_path  = cursor_tmp

  -- redirect agent_state path via session_dir
  local _load_agent_state_orig = load_agent_state
  -- override: point state file to our temp
  local function load_test_state()
    local s = read_file(state_tmp)
    if not s then return {} end
    local ok, t = pcall(json.decode, s); return (ok and type(t) == "table") and t or {}
  end
  local function save_test_state(st) wf(state_tmp, json.encode(st)) end

  local woken = nil
  local real_wake = wake_agent
  -- monkeypatch wake_agent
  wake_agent = function(msg) woken = msg end  -- luacheck: ignore

  -- patch load/save for this test
  local real_load = load_agent_state
  local real_save = save_agent_state
  load_agent_state = load_test_state   -- luacheck: ignore
  save_agent_state = save_test_state   -- luacheck: ignore

  poll_once()
  assert(woken and woken.wake == "trigger" and woken.event.type == "player_died",
    "expected trigger wake for player_died")

  -- cursor advanced: second poll should produce no trigger wake
  woken = nil
  poll_once()
  assert(woken == nil, "expected no wake on second poll (cursor advanced)")

  -- schedule: entry due in the past → wake
  save_test_state({ schedule = { { at = os.time() - 1, reason = "survey" } } })
  poll_once()
  assert(woken and woken.wake == "schedule" and woken.reason == "survey",
    "expected schedule wake")

  -- schedule entry consumed: no second wake
  woken = nil
  poll_once()
  assert(woken == nil, "expected no wake after schedule consumed")

  -- restore
  wake_agent       = real_wake   -- luacheck: ignore
  load_agent_state = real_load   -- luacheck: ignore
  save_agent_state = real_save   -- luacheck: ignore
  for k, v in pairs(old_cfg) do config[k] = v end

  os.remove(state_tmp)
  os.remove(events_tmp)
  os.remove(cursor_tmp)
  os.remove(cursor_tmp .. ".tmp")  -- may not exist

  print("OK")
end

-- main
if arg[1] == "--test" then
  run_self_test()
  os.exit(0)
end

if once then
  poll_once()
else
  io.stderr:write("[dispatcher] started — session=" .. config.session_dir
    .. " events=" .. config.events_path .. " poll=" .. config.poll_s .. "s\n")
  while true do
    local ok, err = pcall(poll_once)
    if not ok then
      io.stderr:write("[dispatcher] error: " .. tostring(err) .. "\n")
    end
    os.execute("sleep " .. tostring(math.max(1, math.floor(config.poll_s))))
  end
end
