--[[
  调用 kimi_bridge.py：请求 JSON（messages + tools）→ 响应 JSON（result 为完整 ChatCompletion）。

  运行前：
    set MOONSHOT_API_KEY=你的key
    确保当前目录下能执行: python kimi_bridge.py

  纯 Lua 标准库没有 JSON 编码；示例用现成请求文件。
  若要在运行时拼请求，请自带 cjson / dkjson / json.lua 做 encode。
]]

local req_path = "kimi_bridge_request.example.json"
local resp_path = "kimi_bridge_last_response.json"

local bridge = "kimi_bridge.py"
-- Windows / 当前目录执行 Python；可按需改成绝对路径
local cmd = string.format('python "%s" "%s" > "%s"', bridge, req_path, resp_path)

local code = os.execute(cmd)
if code ~= 0 and code ~= true then
  error("kimi_bridge failed, exit " .. tostring(code))
end

local f = assert(io.open(resp_path, "r"))
local body = f:read("*a")
f:close()

-- body 为单行 JSON：{"ok":true,"result":{...}} 或 {"ok":false,"error":"..."}
print(body)

-- 若已 require cjson：
-- local cjson = require("cjson")
-- local t = cjson.decode(body)
-- if not t.ok then error(t.error) end
-- local choices = t.result.choices
