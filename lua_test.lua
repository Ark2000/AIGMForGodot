local session = "service_kimi/session_01"  -- 或相对路径，按你实际来

local function write_file(path, text)
  local f = assert(io.open(path, "w"))
  f:write(text)
  f:close()
end

-- 1) 写入请求（内容来自你的逻辑或变量）
write_file(session .. "/messages.json", '[{"role":"user","content":"hi"}]')
write_file(session .. "/tools.json", "[]")

-- 2) 同步调用 kimi.py（阻塞到写完 output.json）
local py = "python"  -- 或完整路径，如 C:/Python39/python.exe
local cmd = string.format('%s "%s/kimi.py" "%s"', py, "service_kimi", session)
local ok, how, code = os.execute(cmd)
if not ok then
  error("kimi.py failed: " .. tostring(how) .. " " .. tostring(code))
end

-- 3) 再读结果
local out = assert(io.open(session .. "/output.json", "r"))
local body = out:read("*a")
out:close()
print(body)
-- body 是 JSON 字符串，用 cjson / dkjson 再 decode