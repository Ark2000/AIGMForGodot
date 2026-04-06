# AIGM Addon（Godot 多轮对话 + Agent 工具）

## 布局

| 路径 | 作用 |
|------|------|
| `agents_wnd.tscn` | 聊天 UI 场景 |
| `aigm_stream.gd` | HTTP/SSE、信号、调用 Lua 核心与 `commands.gd` |
| `aigm_lua_host.gd` | 加载 lua-gdextension，执行 `require("aigm")`，与 Lua 互传数据 |
| `lua/` | **纯 Lua**：会话状态、Kimi/OpenAI 请求 JSON、SSE 解析、tool 合并、`json`（rxi） |
| `commands.gd` | LLM 工具 `aigm_lua_run`：标准库 Lua 沙箱（与核心 Lua 无关） |
| `../lua-gdextension/` | 第三方 Lua 扩展（`build/` 需存在，见下） |

## 依赖

- **lua-gdextension**：工程内为 `res://addons/lua-gdextension/`。若克隆后没有 `addons/lua-gdextension/build/`，在仓库根目录执行：
  - `powershell -ExecutionPolicy Bypass -File godot_proj/aigm/tools/fetch_lua_gdextension_build.ps1`

## 使用步骤

1. 复制 `config.example.json` 为同目录下的 `config.json`，填写 `base_url`、`api_key`。
2. 运行 `agents_wnd.tscn`（或项目默认场景）。
3. 输入消息，Enter / 发送；支持多轮与工具循环（若 `enable_tools` 为 true）。

## config.json 示例

```json
{
  "base_url": "https://api.moonshot.cn/v1",
  "api_key": "YOUR_API_KEY_HERE",
  "model": "kimi-k2-turbo-preview",
  "max_tokens": 8192,
  "enable_tools": true,
  "debug_tool_trace": false,
  "debug_aigm_trace": false
}
```

- `enable_tools`：是否向 API 注册工具（当前为 `aigm_lua_run`）。兼容旧键：`enable_godot_tools`、`enable_lua_tool`（二者均为真时才等价于开启工具）。

## 说明

- 默认模型可在 `config.json` 的 `model` 中配置；未写则使用代码内默认。
- 请求体 `stream: true`，按 SSE（`data: {...}` / `data: [DONE]`）增量解析。
- `base_url` 需含路径前缀（如 `https://api.moonshot.cn/v1`），请求路径为 `{base}/chat/completions`（由 Lua `api.lua` 拼装）。
