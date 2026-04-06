# Lua Agent（单 session）设计说明

**状态**：已评审（与用户脑暴对齐）  
**日期**：2026-04-06（修订：单工具 + Lua 沙箱）  
**依赖**：`service_kimi/kimi.py`（会话目录 + `messages.json` / `tools.json` → `output.json`）

---

## 1. 目标

- 在 **单个 Lua 文件** 内实现：**会话状态、调用 Kimi、工具调用循环、自动持久化**。
- **一个 Lua 进程只服务一个 session**；需要多 session 时 **多开多个 Lua 进程**（进程级隔离）。
- **不实现流式**：与现有 `kimi.py`（`stream: false`）一致。
- **工具层**：对外（OpenAI/Kimi API）**只暴露一个 function tool**，模型通过 **执行沙箱内 Lua 代码** 扩展行为；**不再**为每种能力增加单独的 function 定义。
- **能力扩展**：通过 **Lua 能力说明文档**（给模型阅读的参考）+ **沙箱内实际提供的 API** 同步演进；优先 **改文档与沙箱实现**，**不改** `tools.json` 的 schema 形状（仅一个 `code` 类参数即可稳定长期维持）。

---

## 2. 非目标（本 spec 不覆盖）

- 单进程内多 session 调度、真并行多路 `kimi.py`。
- Godot 嵌入细节（后续可将「写文件 + `os.execute`」换成宿主 API，协议形状保持不变）。
- 多 function 的「业务工具矩阵」（Calculator、fetch…）——**本设计明确不要**，由 **单工具 + Lua** 替代。

---

## 3. 核心：Lua 沙箱 + 单工具

### 3.1 对外 schema（`tools.json`）

- **有且仅有一条** OpenAI 兼容的 function 定义，例如名称 `run_lua`（或项目约定名，全局唯一）。
- **参数**：至少包含 **`code: string`**（模型生成的 Lua 源码片段）；是否增加可选字段（如 `id`）由实现定，但 **保持单一 function**，避免再次出现多工具枚举。

### 3.2 执行语义

- Lua Agent 在收到 `tool_calls` 且 `name` 为该唯一工具时：
  - 在 **受限环境** 中执行 `code`（见 §3.3），得到 **字符串结果**（成功时的返回值序列化 / 打印捕获；失败时为错误信息）。
  - 将结果 **始终** 作为一条 `role: "tool"` 写回 `messages`（见 §7），**无论成功或失败**。

### 3.3 沙箱（必须写清边界）

实现侧必须定义并文档化：

- **允许**：哪些标准库、是否允许 `require`、是否提供项目自定义 `api` 表（如 `game.*`）。
- **禁止或移除**：`io`、`os`、未授权 `package`、`debug`、原生加载等——**按威胁模型裁剪**；若当前阶段仅为本机可信开发，可注明 **「全权限临时模式」** 与后续收紧路径。
- **超时**：单次 `code` 执行必须有 **上限时间**（或步数上限），超时结果作为 **tool 错误内容** 回灌，不得吞掉。
- **错误**：运行时错误、语法错误、超时，一律变成 **tool 消息的 `content` 字符串**，便于模型自纠。

### 3.4 能力文档（给模型，非给终端用户）

- 单独文件（如 `lua_capabilities.md` / `agent_lua_ref.md`）或配置区路径；启动时读入，放入 **system 或 developer** 消息（或固定前缀），使模型知道 **沙箱里有哪些全局、模块、示例**。
- **扩展新能力**的推荐流程：**更新文档** + **在沙箱中实现对应接口**；**无需**新增第二个 OpenAI tool。

### 3.5 Token 与文档体积

- 单工具 + 长文档会占用 context：若日后超限，再在 **后续阶段** 做摘要、分块或「文档外置 + 模型先写小探测脚本」——本 spec 只要求 **设计预留**，首版可采用 **全文放入 system**（在可接受长度内）。

---

## 4. 架构概览

```
[配置区 + arg 覆盖]（含：沙箱策略、文档路径、max_tool_rounds）
      ↓
[Session：messages、唯一 tools schema、元数据]
      ↓
  写 messages.json / tools.json（自动保存；tools.json 长期稳定为「单 function」）
      ↓
  os.execute → python kimi.py <session_dir>
      ↓
  读 output.json → 解析 assistant 与 tool_calls
      ↓
  若有 tool_calls → 仅解析「唯一 run_lua」类调用 → 沙箱执行 code → 每条结果必写入 messages（role=tool）→ 再保存 → 再调 kimi（循环）
      ↓
  直到 finish_reason 为 stop（或等价）或达到 max_tool_rounds
```

**文件边界**：Python 仅负责 HTTP 与原始 `output.json`；**对话形状、沙箱执行与工具循环**在 Lua 中维护。

---

## 5. 单文件内逻辑分区（同一 `.lua`，用注释分段）

| 区块 | 职责 |
|------|------|
| 配置默认值 | `session_dir`、`python`、`kimi_py`、`max_tool_rounds`、**`lua_doc_path`**、**沙箱/超时** 等 |
| 命令行解析 | 覆盖配置（见 §6） |
| JSON | 满足 `messages` / `output` 解析与写盘的最小 **encode/decode**（可内嵌短实现，不引入多文件） |
| 持久化 | 原子写：`*.tmp` → 正式文件（与 `kimi.py` 一致） |
| Kimi 调用 | 写盘 → `os.execute` → 读 `output.json`；检查退出码与 `error` 字段 |
| **沙箱** | **唯一**入口：对字符串 `code` 执行并返回字符串结果（成功/失败/超时） |
| **tools.json 生成** | 内存中固定 **单 function** schema，写盘供 `kimi.py` 使用 |
| 主循环 | 用户输入 / 一轮推理：`append user` → `llm_round` → 可能多轮 tool 直到停止 |

---

## 6. 配置与命令行

- **文件开头**为默认配置表。
- **启动参数**覆盖默认值：例如 `--session_dir=...`、`--max_tool_rounds=8`、`--lua_doc=...`。
- 未指定的键沿用默认值。

---

## 7. 持久化（自动保存，选项 B）

在以下事件后 **必须** 将当前 `messages` 序列化并 **原子写入** `session_dir/messages.json`：

- 追加或修改了与对话相关的任何内容（含 user、assistant、tool）。

**启动时**：若存在 `messages.json`，则 **加载** 为当前 session 的 `messages`，以支持续聊。

`tools.json`：**schema 固定为单 function**；每次运行写盘与内存一致即可（或仅在变更时写，首版可每次写以保证与 Kimi 一致）。

---

## 8. 工具调用策略（硬规则）

- 当模型返回需执行工具时（例如 `finish_reason` 为 `tool_calls`）：
  - 对 **每一个** tool 调用：在本设计中 **应均为同一 `run_lua`（名以实现为准）**；解析 `arguments` 得到 `code`（或等价字段）。
  - 在 **沙箱** 中执行，**无论成功、失败或抛错**，都向 `messages` 追加一条 **`role: "tool"`**，字段与 OpenAI 兼容（含 `tool_call_id`、`name`）。
  - **失败/异常/超时**：`content` 为可读错误信息，**不得省略该条 tool 消息**。
- 写完所有本轮 tool 消息后 **自动保存**，再发起下一轮 `kimi.py`。
- **上限**：`max_tool_rounds` 防止无限循环；达到上限时明确中止。

---

## 9. 与 `kimi.py` 的契约

- **输入**：`session_dir/messages.json`、`session_dir/tools.json`（`tools.json` 为 **单工具** schema）。
- **输出**：`session_dir/output.json`；成功为完整 completion 的 JSON；失败为 `{"error": "..."}` 且非零退出码。
- Lua 侧根据退出码与 JSON 内容分支：**无有效 choices 时不得静默当成功**。

---

## 10. 错误处理

- `kimi.py` 非零：读取 `output.json` 中的 `error`（若有）；默认 **不向 messages 注入虚假 assistant**（由上层日志处理）。
- **沙箱执行失败**：仍按 §8 写入 tool 消息。

---

## 11. 测试建议

- 最小 `messages` + **仅含单 function 的** `tools.json` 跑通一轮无工具、一轮 `run_lua` 成功、一轮 **故意语法错误** 仍出现 tool 消息并进入下一轮。
- 确认 **文档片段** 出现在 system（或等价）且模型能据此生成合法沙箱调用。

---

## 12. 后续可演进（不在本阶段实现）

- 上下文裁剪 / 摘要（token 上限）。
- 沙箱进一步收紧、审计日志。
- Godot 网络层替换 `kimi.py`，**保持 messages 与单 tool 形状不变**。
