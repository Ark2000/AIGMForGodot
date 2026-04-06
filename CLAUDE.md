# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Agent

```powershell
# Run with a user message (from project root)
.\lua54.exe lua_agent.lua -- "your message here"

# Override config via CLI flags
.\lua54.exe lua_agent.lua --session_dir=service_kimi/session_01 --max_tool_rounds=5 -- "message"

# Offline self-check (no API needed)
.\lua54.exe lua_agent.lua --test

# Pipe a message via stdin
echo "compute 1+1" | .\lua54.exe lua_agent.lua
```

## Python bridge (kimi.py)

```powershell
# Called internally by lua_agent.lua; can also be invoked directly for debugging:
python service_kimi/kimi.py service_kimi/session_01
# Reads:  session_dir/messages.json + session_dir/tools.json
# Writes: session_dir/output.json  (atomic replace via .tmp)
```

Dependencies: `pip install httpx openai`

## Architecture

This is a **single-file Lua agent** (`lua_agent.lua`) that drives a Kimi (Moonshot) LLM via a thin Python bridge.

```
lua_agent.lua
  └─ bootstrap_session()      load doc → load messages → write tools.json → save messages
  └─ llm_round()              agentic loop:
       save_messages → os.execute(kimi.py) → read output.json
       if finish_reason == "tool_calls":
         for each call: sandbox_run(code) → append role:tool → save → repeat
       else: return final assistant message
  └─ sandbox_run()            load(code, "t", restricted_env) + debug.sethook instruction limit

service_kimi/kimi.py          Python HTTP shim: reads messages.json + tools.json, calls Moonshot API,
                               writes output.json. Stateless — all session state lives in the JSON files.
```

### Key design decisions

- **Single tool**: The API sees exactly one function tool (`run_lua`). The model extends behavior by writing Lua code to execute in the sandbox — not by calling different tools. Do not add more function tools; instead update `docs/agent_lua_ref.md` and expand the sandbox environment.
- **Session isolation**: one Lua process = one session directory. Parallel sessions = parallel processes, each with its own `session_dir`.
- **Persistence**: every message append triggers an atomic write to `session_dir/messages.json`. `kimi.py` is stateless; on restart the conversation resumes from file.
- **Sandbox**: restricted environment exposes only `math`, `string`, `table`, `utf8`, and a capturing `print`. No `io`, `os`, `require`, or `debug`. Timeout enforced via `debug.sethook` instruction count (`sandbox_max_instructions`, default 5 000 000).
- **JSON**: rxi/json.lua (MIT) lives in `json.lua` and is loaded via `require("json")`.

### File map

| Path | Role |
|------|------|
| `lua_agent.lua` | Config, CLI, atomic write, tools schema, session load/save, kimi.py invocation, sandbox, main loop, `--test` self-check |
| `json.lua` | rxi/json.lua (MIT) — encode/decode; `require`d by `lua_agent.lua` |
| `sandbox.lua` | Restricted Lua execution environment; `sandbox.run(code, cfg)` → string; extend here to add new sandbox APIs |
| `service_kimi/kimi.py` | Python HTTP shim; do not add business logic here |
| `docs/agent_lua_ref.md` | Sandbox capability doc injected as the system message; keep in sync with the actual sandbox `env` |
| `tests/fixtures/lua_agent/` | Offline JSON fixtures for `--test` (no API call required) |
| `lua54.exe` / `lua54.dll` | Lua 5.4 runtime (Windows, included in repo) |

### Extending sandbox capabilities

1. Add the new API to `make_env()` in `sandbox.lua`.
2. Document it in `docs/agent_lua_ref.md` (this becomes the model's system message).
3. No changes to `tools.json` schema or `kimi.py` are needed.

### kimi.py contract

- **Input**: `session_dir/messages.json` (array), `session_dir/tools.json` (single-function array)
- **Output**: `session_dir/output.json` — success: full OpenAI-compatible completion; failure: `{"error": "..."}` with non-zero exit
- Model: `kimi-k2.5`, `stream: false`, `max_tokens: 32768`
- API endpoint: Moonshot (`https://api.moonshot.cn/v1`); key is hardcoded in `kimi.py`
