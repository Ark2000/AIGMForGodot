--[[
  Lua agent — single session, single run_lua tool, service_kimi/kimi.py bridge.
  Sections: CONFIG → JSON (rxi) → ATOMIC → …
]]

local config = {
  session_dir = "service_kimi/session_01",
  kimi_root = "service_kimi",
  python = "python",
  max_tool_rounds = 8,
  lua_doc_path = "docs/agent_lua_ref.md",
  tool_name = "run_lua",
  sandbox_max_instructions = 5000000,
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

local json = (function()
--
-- json.lua
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end


local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
  return "null"
end


local function encode_table(val, stack)
  local res = {}
  stack = stack or {}

  -- Circular reference?
  if stack[val] then error("circular reference") end

  stack[val] = true

  if rawget(val, 1) ~= nil or next(val) == nil then
    -- Treat as array -- check keys are valid and it is not sparse
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then
        error("invalid table: mixed or invalid key types")
      end
      n = n + 1
    end
    if n ~= #val then
      error("invalid table: sparse array")
    end
    -- Encode
    for i, v in ipairs(val) do
      table.insert(res, encode(v, stack))
    end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"

  else
    -- Treat as an object
    for k, v in pairs(val) do
      if type(k) ~= "string" then
        error("invalid table: mixed or invalid key types")
      end
      table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end


local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
  -- Check for NaN, -inf and inf
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("unexpected number value '" .. tostring(val) .. "'")
  end
  return string.format("%.14g", val)
end


local type_func_map = {
  [ "nil"     ] = encode_nil,
  [ "table"   ] = encode_table,
  [ "string"  ] = encode_string,
  [ "number"  ] = encode_number,
  [ "boolean" ] = tostring,
}


encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val, stack)
  end
  error("unexpected type '" .. t .. "'")
end


function json.encode(val)
  return ( encode(val) )
end


-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(1, 4),  16 )
  local n2 = tonumber( s:sub(7, 10), 16 )
   -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end


local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 34 then -- `"`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end


local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end


local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}


parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end


return json

end)()
-- ### ATOMIC / TOOLS / SESSION / KIMI / LOOP (appended after embedded json.lua)

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

local function make_sandbox_env()
  local print_buf = {}
  local env = {
    math = math,
    string = string,
    table = table,
    utf8 = utf8,
    print = function(...)
      local t = { ... }
      for i = 1, #t do
        t[i] = tostring(t[i])
      end
      table.insert(print_buf, table.concat(t, "\t"))
    end,
  }
  env._G = env
  return env, print_buf
end

local function sandbox_run(code, cfg)
  local env, print_buf = make_sandbox_env()
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
          local result = sandbox_run(args.code, cfg)
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
  assert(sandbox_run("return 5", scfg) == "5")
  local e1 = sandbox_run("error('x')", scfg)
  assert(e1:find("x"))
  local bad = sandbox_run("+++", scfg)
  assert(bad:sub(1, 9) == "[compile]" or bad:sub(1, 7) == "[error]")
  print("OK")
end

if arg[1] == "--test" then
  run_self_test()
  os.exit(0)
end

parse_args(arg)
main()
