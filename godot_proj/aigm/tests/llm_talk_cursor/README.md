# llm_talk_cursor（Godot 极简多轮对话）

这个目录包含一个最小可运行的 Godot LLM 聊天界面：

- 场景：`res://tests/llm_talk_cursor/llm_talk_cursor.tscn`
- 脚本：`res://tests/llm_talk_cursor/llm_talk_cursor.gd`
- 配置：复制 `config.example.json` 为 `config.json` 后填写密钥（`config.json` 已加入 .gitignore）

## 功能

- 简单聊天 UI（对话记录 + 输入框 + 发送按钮）
- 支持多轮上下文（`messages` 会持续累积）
- 通过 `HTTPClient` + SSE 调用 OpenAI 兼容接口，**流式输出**（默认 Moonshot/Kimi）

## 使用步骤

1. 打开 Godot 项目后，直接运行 `llm_talk_cursor.tscn`。
2. 将 `config.example.json` 复制为 `config.json`，填好 `base_url` 和 `api_key`。
3. 在输入框键入消息，按 Enter 或点击发送即可多轮对话。

## config.json 示例

```json
{
  "base_url": "https://api.moonshot.cn/v1",
  "api_key": "YOUR_API_KEY"
}
```

## 说明

- 当前模型写死为 `kimi-k2.5`，可在脚本里自行改成其他模型。
- 请求体使用 `stream: true`，按 SSE（`data: {...}` / `data: [DONE]`）增量解析并刷新「AI:」那一行。
- `base_url` 需带路径前缀（例如 `https://api.moonshot.cn/v1`），脚本会请求 `{base}/chat/completions`。
- 如果请求失败，错误信息会显示在聊天记录里，便于调试。