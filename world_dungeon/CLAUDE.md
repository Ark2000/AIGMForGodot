# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A headless, self-running roguelike dungeon simulation engine written in Lua. No player input, no graphics — only structured event logs. All actors (monsters and adventurers) are AI-driven. The goal is emergent narrative output. Time model: 1 second = 10 ticks.

All design documentation is in `doc/` (Chinese). The implementation is organized into 6 sequential phases defined in `doc/A5_实现顺序建议.md`.

## Commands

```bash
lua main.lua              # Run the simulation
lua test/run_all.lua      # Run all tests
lua test/phases/phaseN_test.lua  # Run a single phase's tests
```

## Architecture

### ECS (Entity-Component-System)

**Components are pure data tables — no methods.** All logic lives in Systems. Systems communicate via events only; no direct cross-system calls (except utility modules like `core/util.lua` and `dungeon/topology.lua`).

- `core/world.lua` — Single ECS container. Manages entity IDs (plain integers), component storage (`_components[name][entity_id]`), spatial index (`_room_index[room_id]`), event log (append-only), and tick counter.
- `core/registry.lua` — Loads all content from `data/` at startup.
- `core/scheduler.lua` — Executes systems in priority order each tick.

### System Priority Ranges

| Range | Responsibility |
|-------|---------------|
| 0–9   | Timing (`action_timer_system`) |
| 10–29 | AI decisions (`ai_system`) |
| 30–49 | Action execution (movement, combat) |
| 50–69 | State updates (status, stats, equipment) |
| 70–89 | Ecology / world changes (spawn, ecology) |
| 90–99 | Logging / output (`log_system`) |

### System Interface

```lua
{
    name     = "system_name",
    priority = number,                    -- determines execution order
    init     = function(world) end,       -- optional, one-time setup
    update   = function(world) end,       -- runs every tick
    on_tick  = number,                    -- optional: run every N ticks instead
}
```

### Data-Driven Design

All game content lives in `data/` as pure Lua tables (entity defs, items, skills, status effects, behaviors, room templates, floor configs). Exception: `data/config/combat_formulas.lua` may contain functions. Entity definitions are **deep-copied** on spawn — never share references between instances.

### Entity Lifecycle

- Create via `world:create_entity()`, destroy via `world:destroy_entity(id)` (queued, flushed at tick end — never delete mid-tick).
- Stats are always accessed through `stats_system`, never by reading the stats component directly.
- Spatial queries always go through `dungeon/topology.lua`, never by accessing `_room_index` directly.

### 6 Implementation Phases

1. **Core Infrastructure** — World, Registry, Scheduler, util. Goal: 10,000 ticks without crash.
2. **Space & Dungeon** — Dungeon generator, topology, movement, action timer, `random_wander` AI.
3. **Combat & Death** — Hit/miss/crit, faction hostility, death/loot, spawn, ecology.
4. **RPG Depth** — Modifier stacking, equipment, skills, status effects, leveling.
5. **Adventurer AI** — Multi-stage goal FSM (explore → strengthen → descend → retrieve Amulet → escape), pathfinding, Hall of Fame.
6. **Logging System** — Event renderer, FOLLOW/WORLD perspective modes, importance filtering, periodic summaries.

### Key Design Constraints (from `doc/A6_关键设计约束.md`)

- Components are pure data — logic goes in systems.
- Cross-system communication only via events (world event log).
- Deep copy entity definitions on spawn.
- Lazy entity deletion (queue + flush).
- Stats via `stats_system` only.
- Spatial queries via `topology.lua` only.
- Event log is append-only (single source of truth for logging).

## Testing

Custom minimal framework (`test/assert.lua` + `test/run_all.lua`). One test file per phase under `test/phases/`. Output: green checkmarks for passes, red X with expected/actual for failures.
