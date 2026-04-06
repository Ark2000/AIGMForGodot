# AIGM - AI Agent Framework for Godot

## Project Overview

AIGM is a **runtime AI Agent framework for Godot 4.x** that enables Large Language Models (LLMs) to directly interact with and influence game worlds. Unlike traditional static AI tools that only generate code or assets, AIGM allows AI agents to act as "virtual gods" - observing game state, executing commands via REPL, and dynamically modifying gameplay in real-time.

### Key Design Philosophy

- **Runtime-Native Agent**: Unlike external MCP (Model Context Protocol) + generic agent setups, AIGM's agent orchestration lives inside the game runtime
- **Proactive Intervention**: Agents can wake up based on game events or time ticks, not just respond to player input
- **Pure Text Interface**: Designed for machine consumption - structured logs, REPL commands, function calls
- **Self-Healing Loop**: Agent executes code → captures errors → auto-corrects via LLM feedback

### Project Motivation

Current AI game dev tools are static (code generation, image generation). AIGM enables:
1. **AI Game Director**: Monitor player behavior, spawn monsters, change weather dynamically
2. **Smart NPCs**: NPCs that truly understand game world state and react contextually
3. **Automated QA**: Agent tests levels, finds collision bugs, reports issues automatically
4. **Natural Language Programming**: Describe game logic in natural language, agent executes at runtime

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| Game Engine | Godot 4.6 |
| Scripting | GDScript |
| Physics | Jolt Physics (3D), built-in (2D) |
| Rendering | GLES3 (GL Compatibility) |
| LLM API | Moonshot/Kimi API (OpenAI-compatible) |
| HTTP Client | Godot HTTPClient + SSE streaming |

---

## Project Structure

```
AIGMForGodot/
├── docs/
│   ├── aigm/v0.1.md           # Core architecture documentation (Chinese)
│   └── llmapi/kimi/           # Kimi API documentation
├── godot_proj/aigm/           # Main Godot project
│   ├── project.godot          # Godot project configuration
│   ├── icon.svg               # Project icon
│   ├── tests/
│   │   ├── llm_talk_cursor/   # LLM chat + tool call system
│   │   │   ├── aigm_stream.gd # Core LLM streaming controller
│   │   │   ├── agents_wnd.gd  # Multi-agent UI manager
│   │   │   ├── commands.gd    # Agent Lua tool (stdlib-only sandbox via lua-gdextension)
│   │   │   ├── config.json    # API configuration (gitignored)
│   │   │   └── config.example.json
│   │   ├── rpgmaker_kimi/     # RPG Maker-style editor prototype
│   │   │   ├── editor.tscn    # Main editor scene
│   │   │   ├── editor/
│   │   │   │   ├── core/      # Project/Map/Database managers
│   │   │   │   ├── modules/   # Map editor, event system, etc.
│   │   │   │   └── ui/        # Editor UI components
│   │   │   └── README.md
│   │   └── testsandbox/       # AI test sandbox world
│   │       ├── scenes/
│   │       │   └── world.tscn # Main sandbox scene
│   │       └── scripts/
│   │           ├── nekomimi_walker.gd    # 8-direction character controller
│   │           ├── npc_behavior.gd       # AI state machine (combat/forage/rest/work)
│   │           ├── world_sandbox.gd      # Sandbox coordinator
│   │           ├── spectator_camera.gd   # Camera follow system
│   │           └── item_database.gd      # Item system
│   └── .godot/                # Godot cache (gitignored)
└── .vscode/settings.json      # VS Code configuration
```

---

## Key Components

### 1. AIGM Core System (`addons/aigm/`)

**aigm_stream.gd**: Main LLM controller (thin layer)
- Owns HTTPClient/TLS, timers, UI signals, tool execution (`commands.gd`)
- Conversation state, Kimi/OpenAI request JSON, SSE parsing, and tool-call merging live in **`addons/aigm/lua/`** (loaded by `aigm_lua_host.gd`)

**`addons/aigm/lua/`** (pure Lua, no Godot): `aigm.lua` → `api.lua` (session, payloads, stream), `sse.lua`, `tool_merge.lua`, `url.lua`, `json.lua` (rxi)

**aigm_lua_host.gd**: Instantiates lua-gdextension `LuaState` (with `package` + `res://` paths), `require("aigm")`, bridges GDScript ↔ Lua via JSON strings

**agents_wnd.gd**: Multi-agent UI
- Tabbed interface for multiple parallel agents
- Typewriter effect for AI responses
- Hotkey: `` ` `` (backtick) or `F1` to toggle
- Dynamic tab creation/closing

**commands.gd**: Agent Lua tool (host-side runner)
- Single LLM tool `aigm_lua_run`: runs a **standard Lua** snippet (lua-gdextension `LuaState` with only `LUA_*` libraries opened, no `GODOT_*` bindings)
- Agent code has no Godot API inside the VM; host GDScript is only the runner and UI

### 2. Test Sandbox (`tests/testsandbox/`)

**NekomimiWalker** (`nekomimi_walker.gd`):
- 8-directional walking with sprite animation
- Combat system: Terraria-style melee swings
- Inventory system with item stacking
- Satiation/Energy mechanics (survival elements)
- Navigation2D for pathfinding

**NpcBehavior** (`npc_behavior.gd`):
- AI state machine: WANDER → COMBAT/FLEE/FORAGE/REST/WORK
- Utility AI for decision making
- Combat: Pursue threats, attack in melee range
- Foraging: Search food → eat inventory → loot containers → buy from shop
- Rest/Work: Sleep at beds, earn money at work points when hungry but broke

### 3. RPG Maker Editor (`tests/rpgmaker_kimi/`)

Prototype RPG Maker-style editor with:
- Map editor with tile layers
- Database editor (characters, items, enemies)
- Event system (visual scripting)
- Asset manager

---

## Configuration

### API Configuration

Copy `addons/aigm/config.example.json` to `config.json`:

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

### Project Settings (`project.godot`)

- **Main Scene**: `tests/testsandbox/scenes/world.tscn`
- **Autoload**: `AIGM` (agents window)
- **Input**: WASD + Arrow keys for movement, J for attack, E for talk, F for pickup, Q for inventory
- **Physics Layers**: Layer 5 (pickup), Layer 6 (combat_hurt)

---

## Build and Run

### Prerequisites

- Godot 4.6+ installed
- Kimi/Moonshot API key (get from https://platform.moonshot.cn/console)

### Running the Project

1. Open Godot 4.6
2. Import `godot_proj/aigm/project.godot`
3. Copy `config.example.json` to `config.json` and add your API key
4. Press F5 to run
5. In-game: Press `` ` `` (backtick) to open AI chat window

### Debug Commands

In the AI chat window, type:
- `/help` - Show available commands
- `/clear` - Clear conversation history
- `/reload` - Reload configuration

---

## Code Style Guidelines

### GDScript Conventions

- **Comments**: Chinese for game logic, English for technical implementation
- **Class Names**: `PascalCase` (e.g., `NekomimiWalker`, `NpcBehavior`)
- **Functions/Variables**: `snake_case` (e.g., `move_speed`, `combat_max_hp`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `PICKUP_LAYER_BIT`)
- **Private**: Prefix with `_` (e.g., `_nav_agent`, `_process_attack_hits`)
- **Signals**: Past tense verbs (e.g., `destination_reached`, `hp_changed`)

### Documentation Style

- Use GDScript doc comments `##` for public APIs
- Document exported variables with `@export_group` organization
- Include usage examples in class documentation

### Naming Conventions

```gdscript
# Public exported variables
@export var move_speed: float = 180.0
@export var speech_lines: Array[String] = []

# Private internal variables
var _nav_agent: NavigationAgent2D
var _anim_time: float = 0.0

# Constants
const PICKUP_LAYER_BIT: int = 16
const _FRAMES: Dictionary = {"down": [0, 1, 2]}

# Signals
signal destination_reached
signal hp_changed(current: int, maximum: int)

# Functions
func move_to(pos: Vector2) -> void:
func _physics_process(delta: float) -> void:
```

---

## Testing

### Manual Testing

1. **LLM Chat**: Toggle UI with `` ` ``, send message, verify streaming response
2. **Tool Calls**: Ask AI to run a small Lua snippet via `aigm_lua_run` (e.g. `return 2+2`)
3. **Combat**: Press J to attack, verify damage and AI reaction
4. **Foraging**: Watch NPCs automatically seek food when hungry

### Test Scenes

- `testsandbox/scenes/world.tscn` - Main sandbox with NPCs, items, shops
- `rpgmaker_kimi/editor.tscn` - RPG editor prototype
- `llm_talk_cursor/llm_talk_cursor.tscn` - Minimal chat UI

---

## Architecture Details

### Agent Orchestration Model

```
┌─────────────────────────────────────────────────────────────┐
│                    Godot Game Runtime                       │
│  ┌──────────────┐        ┌─────────────────────────────┐   │
│  │ Game Logic   │◄──────►│ AIGM Interface Layer        │   │
│  └──────────────┘        └─────────────────────────────┘   │
│            ▲                              │                 │
│            │ Logs                         │ REPL            │
│            │                              ▼                 │
│  ┌──────────────┐        ┌─────────────────────────────┐   │
│  │ Native Logger│        │   REPL Executor (Sandbox)   │   │
│  └──────────────┘        └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────┐
│                             ▼                               │
│              Envoy Orchestrator Core                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ Event Router │  │ Tick Scheduler│  │ State & Memory   │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────┐
│                             ▼                               │
│                 LLM Interface Layer                         │
│  ┌──────────────────┐        ┌──────────────────────────┐  │
│  │ Context Builder  │◄──────►│ API Gateway (HTTP+SSE)   │  │
│  └──────────────────┘        └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Event-Driven Wakeup**: Critical game events (low HP, boss entered) immediately wake agent
2. **Tick Polling**: Agent has its own "mind clock" (e.g., every 5 seconds) for regular decisions
3. **Perception Buffer**: Filtered game logs feed into agent context
4. **Self-Healing**: Execution errors are fed back to LLM for automatic correction

---

## Security Considerations

> ⚠️ **Important**: AIGM prioritizes development convenience over security. The framework assumes:
> - Developers control what APIs to expose
> - It's a game runtime, not production server environment
> - Agent can read/write game state freely
> 
> Only protection: Prevent arbitrary file system access outside game directories.

---

## Development Phases

### Phase 1: Infrastructure ✅
- Basic REPL execution environment
- Structured log capture

### Phase 2: Single Agent Loop ✅
- LLM API integration
- Basic prompt building
- Tool call loop

### Phase 3: Advanced Orchestration 🔄
- Tick mechanism and event wakeup
- Multi-agent coordination

### Phase 4: Developer Kit ⏳
- Easy-to-use Godot nodes
- Configuration UI
- Plugin distribution

---

## References

- [Kimi API Documentation](https://platform.moonshot.cn/docs/)
- [Godot 4.x Documentation](https://docs.godotengine.org/)
- [PankuConsole](https://github.com/Ark2000/PankuConsole) - Predecessor project

---

## License

MIT License - See individual component READMEs for details.
