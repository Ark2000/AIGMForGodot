--[[
  Lua sandbox — restricted execution environment for the run_lua tool.
  Exposed API: sandbox.run(code, cfg) -> string
  cfg fields used: sandbox_max_instructions (number)
]]

local sandbox = {}

local function make_env()
  local print_buf = {}
  local env = {
    math   = math,
    string = string,
    table  = table,
    utf8   = utf8,
    print  = function(...)
      local t = { ... }
      for i = 1, #t do t[i] = tostring(t[i]) end
      table.insert(print_buf, table.concat(t, "\t"))
    end,
  }
  env._G = env
  return env, print_buf
end

function sandbox.run(code, cfg)
  local env, print_buf = make_env()
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
