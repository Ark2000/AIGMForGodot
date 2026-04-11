--[[
  Lua agent — single session, single run_lua tool, service_kimi/kimi.py bridge.
  Sections: CONFIG → ATOMIC → TOOLS → SESSION → KIMI → LOOP
  Dependencies: json.lua (rxi/json.lua, MIT), sandbox.lua
]]

local config = {
  session_dir = "service_kimi/session_01",
  kimi_root = "service_kimi",
  python = "python",
  max_tool_rounds = 8,
  lua_doc_path = "docs/agent_lua_ref.md",
  tool_name = "run_lua",
  sandbox_max_instructions = 5000000,
  events_path = "events.jsonl",
  world_path = "world.json",
  agent_state_path = nil,  -- derived: session_dir/agent_state.json
}

local user_message

local function set_config_kv(k, v)
  if k == "max_tool_rounds" or k == "sandbox_max_instructions" then
    local n = tonumber(v)
    if n then
      config[k] = n
    end
  else
    config[k] = v
  end
end

local function parse_args(argv)
  user_message = nil
  local user_parts = {}
  local collecting = false
  for i = 1, #argv do
    local a = argv[i]
    if a == "--" then
      collecting = true
    elseif collecting then
      user_parts[#user_parts + 1] = a
    else
      local k, v = a:match("^%-%-([^=]+)=(.*)$")
      if k then
        set_config_kv(k, v)
      end
    end
  end
  if #user_parts > 0 then
    user_message = table.concat(user_parts, " ")
  end
end

local json    = require("json")
local sandbox = require("sandbox")
-- ### ATOMIC / TOOLS / SESSION / KIMI / LOOP

local function join_path(a, b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then
    return a .. b
  end
  return a .. "/" .. b
end

local function ensure_session_dir(dir)
  local p = dir:gsub("/", "\\")
  os.execute('mkdir "' .. p .. '" 2>nul')
end

local function atomic_write(path, text)
  local tmp = path .. ".tmp"
  local f, err = io.open(tmp, "wb")
  if not f then
    error(err)
  end
  assert(f:write(text))
  assert(f:close())
  os.remove(path)
  local ok, _ = os.rename(tmp, path)
  if not ok then
    os.remove(path)
    assert(os.rename(tmp, path))
  end
end

local function read_file(path)
  local fh, err = io.open(path, "rb")
  if not fh then
    return nil, err
  end
  local s = fh:read("*a")
  fh:close()
  return s
end

local function build_tools_payload(cfg)
  return {
    {
      type = "function",
      ["function"] = {
        name = cfg.tool_name,
        description = "在受限 Lua 沙箱中执行一段代码并返回字符串结果。",
        parameters = {
          type = "object",
          required = { "code" },
          properties = {
            code = {
              type = "string",
              description = "要执行的 Lua 源码片段。",
            },
          },
        },
      },
    },
  }
end

local function write_tools_json(session_dir, cfg)
  local path = join_path(session_dir, "tools.json")
  atomic_write(path, json.encode(build_tools_payload(cfg)))
end

local function read_doc(path)
  local raw = read_file(path)
  if raw then
    return raw
  end
  return "（未找到能力文档，请实现 docs/agent_lua_ref.md）"
end

local function ensure_system_message(messages, doc_text)
  if messages[1] and messages[1].role == "system" then
    return
  end
  table.insert(messages, 1, { role = "system", content = doc_text })
end

local function load_messages(session_dir)
  local path = join_path(session_dir, "messages.json")
  local raw = read_file(path)
  if not raw then
    return {}
  end
  local t = json.decode(raw)
  if type(t) ~= "table" then
    error("messages.json must decode to a table")
  end
  if t[1] == nil then
    if next(t) == nil then
      return {}
    end
    error("messages.json must be a JSON array")
  end
  return t
end

local function save_messages(session_dir, messages)
  local path = join_path(session_dir, "messages.json")
  atomic_write(path, json.encode(messages))
end

local function bootstrap_session(cfg)
  ensure_session_dir(cfg.session_dir)
  local doc = read_doc(cfg.lua_doc_path)
  local messages = load_messages(cfg.session_dir)
  ensure_system_message(messages, doc)
  write_tools_json(cfg.session_dir, cfg)
  save_messages(cfg.session_dir, messages)
  return messages
end

local function kimi_py_path(cfg)
  return join_path(cfg.kimi_root, "kimi.py")
end

local function call_kimi(cfg)
  local cmd = string.format('%s "%s" "%s"', cfg.python, kimi_py_path(cfg), cfg.session_dir)
  local ok, _how, exitcode = os.execute(cmd)
  local raw = read_file(join_path(cfg.session_dir, "output.json"))
  if not raw then
    return nil, "no output.json after kimi.py"
  end
  local out = json.decode(raw)
  if type(out.error) == "string" then
    return nil, out.error
  end
  if not ok then
    return nil, "kimi.py failed (exit " .. tostring(exitcode) .. ")"
  end
  return out
end

local function append_assistant_from_completion(messages, msg)
  local entry = { role = "assistant" }
  if msg.content ~= nil then
    entry.content = msg.content
  end
  if msg.tool_calls ~= nil then
    entry.tool_calls = msg.tool_calls
  end
  table.insert(messages, entry)
end

local function append_tool_result(messages, payload)
  table.insert(messages, {
    role = "tool",
    tool_call_id = payload.tool_call_id,
    name = payload.name,
    content = payload.content,
  })
end

local function extract_tool_calls(msg)
  if type(msg.tool_calls) == "table" then
    return msg.tool_calls
  end
  return {}
end

local function llm_round(messages, cfg)
  local rounds = 0
  local last_out
  while true do
    rounds = rounds + 1
    if rounds > cfg.max_tool_rounds then
      return nil, "max_tool_rounds exceeded"
    end
    save_messages(cfg.session_dir, messages)
    local out, err = call_kimi(cfg)
    if not out then
      return nil, err
    end
    last_out = out
    local choice = out.choices and out.choices[1]
    if not choice or not choice.message then
      return nil, "invalid completion: missing message"
    end
    local msg = choice.message
    local finish = choice.finish_reason
    append_assistant_from_completion(messages, msg)
    save_messages(cfg.session_dir, messages)
    if finish ~= "tool_calls" then
      return last_out, nil
    end
    local calls = extract_tool_calls(msg)
    if #calls == 0 then
      return nil, "finish_reason tool_calls but no tool_calls"
    end
    for _, call in ipairs(calls) do
      local tid = tostring(call.id or "")
      local fn = call["function"]
      local fname = fn and fn.name or "?"
      local args_raw = fn and fn.arguments or "{}"
      if fname ~= cfg.tool_name then
        append_tool_result(messages, {
          tool_call_id = tid,
          name = fname,
          content = "[error] unexpected tool " .. fname,
        })
      else
        local okd, args = pcall(json.decode, args_raw)
        if not okd or type(args) ~= "table" then
          append_tool_result(messages, {
            tool_call_id = tid,
            name = fname,
            content = "[error] invalid arguments JSON",
          })
        elseif type(args.code) ~= "string" then
          append_tool_result(messages, {
            tool_call_id = tid,
            name = fname,
            content = "[error] missing code string in arguments",
          })
        else
          local result = sandbox.run(args.code, cfg)
          append_tool_result(messages, {
            tool_call_id = tid,
            name = fname,
            content = result,
          })
        end
      end
    end
    save_messages(cfg.session_dir, messages)
  end
end

local function main()
  if user_message == nil then
    user_message = io.read("*a")
  end
  user_message = (user_message or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if user_message == "" then
    io.stderr:write("usage: lua_agent.lua [options] -- <message>   or pipe message on stdin\n")
    os.exit(2)
  end
  if not config.agent_state_path then
    config.agent_state_path = join_path(config.session_dir, "agent_state.json")
  end
  local messages = bootstrap_session(config)
  table.insert(messages, { role = "user", content = user_message })
  local out, err = llm_round(messages, config)
  if not out then
    io.stderr:write(tostring(err) .. "\n")
    os.exit(1)
  end
  local msg = out.choices and out.choices[1] and out.choices[1].message
  if msg and msg.content then
    print(msg.content)
  else
    print("")
  end
end

local function run_self_test()
  assert(json.decode(json.encode({ a = 1, b = { "x" } })).a == 1)
  local tmp = "z_atomic_test_selfcheck.txt"
  atomic_write(tmp, "ok")
  local f = assert(io.open(tmp, "rb"))
  assert(f:read("*a") == "ok")
  f:close()
  os.remove(tmp)
  local fixture = assert(io.open("tests/fixtures/lua_agent/output_tool_calls.json", "rb"))
  local tout = json.decode(fixture:read("*a"))
  fixture:close()
  assert(tout.choices[1].message.tool_calls[1]["function"].name == "run_lua")
  local scfg = { sandbox_max_instructions = 5000000, tool_name = "run_lua" }
  assert(sandbox.run("return 5", scfg) == "5")
  local e1 = sandbox.run("error('x')", scfg)
  assert(e1:find("x"))
  local bad = sandbox.run("+++", scfg)
  assert(bad:sub(1, 9) == "[compile]" or bad:sub(1, 7) == "[error]")

  -- sandbox: json_encode / json_decode
  assert(sandbox.run("return json_encode({k=1})", scfg):find('"k"'))
  assert(sandbox.run("return json_decode('{\"n\":7}').n", scfg) == "7")

  -- sandbox: state_get / state_set round-trip
  local state_tmp  = "z_test_state.json"
  local events_tmp = "z_test_events.jsonl"
  local scfg2 = {
    sandbox_max_instructions = 5000000,
    tool_name = "run_lua",
    agent_state_path = state_tmp,
    events_path = events_tmp,
  }
  assert(sandbox.run("state_set('x', 99); return state_get('x')", scfg2) == "99")
  assert(sandbox.run("state_set('t', {a=1}); return state_get('t').a", scfg2) == "1")

  -- sandbox: events_read cursor advancement
  local ef = assert(io.open(events_tmp, "wb"))
  ef:write('{"t":1,"type":"foo","data":{}}\n')
  ef:write('{"t":2,"type":"bar","data":{}}\n')
  ef:close()
  local evs1 = sandbox.run("return events_read(10)", scfg2)
  assert(json.decode(evs1)[1].type == "foo", "first read should return 2 events starting with foo")
  assert(#json.decode(evs1) == 2)
  local evs2 = sandbox.run("return events_read(10)", scfg2)
  assert(#json.decode(evs2) == 0, "second read should be empty (cursor advanced)")

  os.remove(state_tmp)
  os.remove(events_tmp)

  print("OK")
end

if arg[1] == "--test" then
  run_self_test()
  os.exit(0)
end

parse_args(arg)
main()
