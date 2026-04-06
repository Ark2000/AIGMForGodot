# Lua Agent（单 session）设计说明

**状态**：已评审（与用户脑暴对齐）  
**日期**：2026-04-06  
**依赖**：`service_kimi/kimi.py`（会话目录 + `messages.json` / `tools.json` → `output.json`）

---

## 1. 目标

- 在 **单个 Lua 文件** 内实现：**会话状态、调用 Kimi、工具调用循环、自动持久化**。
- **一个 Lua 进程只服务一个 session**；需要多 session 时 **多开多个 Lua 进程**（进程级隔离）。
- **不实现流式**：对机器而言非流式足够；与现有 `kimi.py`（`stream: false`）一致。

## 2. 非目标（本 spec 不覆盖）

- 单进程内多 session 调度、真并行多路 `kimi.py`。
- Godot 嵌入细节（后续可将「写文件 + `os.execute`」换成宿主 API，协议形状保持不变）。

---

## 3. 架构概览

```
[配置区 + arg 覆盖]
      ↓
[Session：messages 表、tools 定义、元数据]
      ↓
  写 messages.json / tools.json（自动保存）
      ↓
  os.execute → python kimi.py <session_dir>
      ↓
  读 output.json → 解析 assistant 与 tool_calls
      ↓
  若有 tool_calls → 逐个执行工具 → 每条结果必写入 messages（role=tool）→ 再保存 → 再调 kimi（循环）
      ↓
  直到 finish_reason 为 stop（或等价）或达到 max_tool_rounds
```

**文件边界**：Python 仅负责 HTTP 与原始 `output.json`；**对话形状与工具循环**在 Lua 中维护。

---

## 4. 单文件内逻辑分区（同一 `.lua`，用注释分段）

| 区块 | 职责 |
|------|------|
| 配置默认值 | `session_dir`、`python`、`kimi_py` 路径、`max_tool_rounds`、可选模型名等 |
| 命令行解析 | 覆盖配置（见 §5） |
| JSON | 满足 `messages` / `output` 解析与写盘的最小 **encode/decode**（可内嵌短实现，不引入多文件） |
| 持久化 | 原子写：`messages.json.tmp` → `messages.json`；`tools.json` 同理（与 `kimi.py` 策略一致） |
| Kimi 调用 | 写盘 → `os.execute` → 读 `output.json`；检查进程退出码与 `error` 字段 |
| 工具注册 | `tools[name] = function(args_table) return string end`（或返回可 `tostring` 的结果） |
| 主循环 | 用户输入 / 一轮推理：`append user` → `llm_round` → 可能多轮 tool 直到停止 |

---

## 5. 配置与命令行

- **文件开头**为默认配置表（Lua table 或一组 `local`）。
- **启动参数**覆盖默认值：约定一种简单格式（例如 `--session_dir=...`、`--max_tool_rounds=8`），在脚本入口解析 `arg`。
- 未指定的键沿用默认值。

---

## 6. 持久化（自动保存，选项 B）

在以下事件后 **必须** 将当前 `messages` 序列化并 **原子写入** `session_dir/messages.json`：

- 追加或修改了与对话相关的任何内容（含 user、assistant、tool）。

**启动时**：若存在 `messages.json`，则 **加载** 为当前 session 的 `messages`，以支持续聊。

`tools.json`：在工具表变更时写入；若工具集固定，可在首次运行或每次运行前根据内存中的工具定义写一次，保证与发给 Kimi 的 schema 一致。

---

## 7. 工具调用策略（硬规则）

- 当模型返回需执行工具时（例如 `finish_reason` 表示 `tool_calls` 或响应体中含完整 `tool_calls`）：
  - 对 **每一个** tool 调用：执行对应 Lua 函数（或统一 dispatcher）。
  - **无论成功、失败或抛错**，都向 `messages` 追加一条 **`role: "tool"`** 消息，且内容与 OpenAI 兼容字段对齐（含 `tool_call_id`、必要时 `name`）。
  - **失败/异常**：`content` 为可读错误信息（例如前缀 `error:` 或简短 JSON 字符串），**不得因失败而省略该条 tool 消息**。
- 写完所有本轮 tool 消息后 **自动保存**，再发起下一轮 `kimi.py`。
- **上限**：`max_tool_rounds`（或命名 `max_llm_rounds`）防止无限循环；达到上限时明确中止并可选写入最后一条 system/user 提示。

---

## 8. 与 `kimi.py` 的契约

- **输入**：`session_dir/messages.json`、`session_dir/tools.json`（与现有 `kimi.py` 一致）。
- **输出**：`session_dir/output.json`；成功为完整 completion 的 JSON；失败为 `{"error": "..."}` 且非零退出码（以 `kimi.py` 行为为准）。
- Lua 侧根据退出码与 JSON 内容分支：**无有效 choices 时不得静默当成功**。

---

## 9. 错误处理

- `kimi.py` 非零：读取 `output.json` 中的 `error`（若有），记录并 **不** 伪造 assistant 消息，除非产品层决定写入一条 assistant 错误占位（本 spec 默认：**不向 messages 注入虚假 assistant**，由上层打印/日志处理）。
- 工具执行失败：**仍**按 §7 写入 tool 消息。

---

## 10. 测试建议

- 使用最小 `tools.json` + 短 `messages` 跑通一轮无工具、一轮有工具。
- 人为让工具返回错误字符串，确认 messages 中仍含对应 `tool` 行且能进入下一轮。

---

## 11. 后续可演进（不在本阶段实现）

- 上下文裁剪 / 摘要（token 上限时截断或摘要）。
- 将「写文件 + 执行 Python」替换为 Godot 网络层，**保持 messages 与 tool 消息形状不变**。
