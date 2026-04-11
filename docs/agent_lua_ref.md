# Lua 沙箱能力（给模型阅读）

## 工具调用

- **工具名**：`run_lua`
- **参数**（JSON）：`code`（字符串）— 要在沙箱中执行的 Lua 源码片段。

---

## 沙箱内可用

### 标准库
- `math`、`string`、`table`、`utf8`
- `print(...)`：输出会合并进工具返回的字符串（无 `return` 时作为结果）
- **没有**：`io`、`os`、`package`、`require`、`debug`

### JSON 工具
- `json_encode(val)` → 字符串：将 Lua 值（表、数字、字符串等）编码为 JSON。
- `json_decode(s)` → Lua 值：将 JSON 字符串解析为 Lua 值。

### 持久化世界状态
键值存储，跨调用持久，写入 `agent_state.json`。

- `state_get(key)` → 值（Lua 类型）：读取状态键。
- `state_set(key, val)`：写入状态键（val 可为表、字符串、数字等）。

常用约定（非强制，自行维护一致性）：
```lua
-- 世界模型
state_set("world", { player_hp = 80, location = "dungeon_b2", quest = "slay_lich" })

-- 触发器：触发 GM 唤醒的事件类型列表
state_set("triggers", { "player_hp_critical", "boss_spawned", "player_died" })

-- 计划：定时唤醒列表（at 为 Unix 时间戳）
state_set("schedule", { { at = os.time() + 300, reason = "world_survey" } })
-- 注意：沙箱内无 os.time()；需在接收到 wake 消息时读取 wake.event.t 或由宿主注入当前时间。
-- 可用 state_get("now") 读取宿主注入的当前时间戳（若宿主已写入）。
```

### 游戏世界状态（直接读写）
直接访问游戏的 `world.json`，与游戏引擎共享。GM 可在此读取或修改任意游戏数据。

- `world_get(key)` → 值：读取游戏世界状态的顶层键。
- `world_set(key, val)`：写入游戏世界状态的顶层键（原子写入）。

```lua
-- 读取当前玩家状态
local player = world_get("player")
print("HP: " .. player.hp .. "/" .. player.max_hp)

-- 治疗玩家（直接修改世界状态，下一 tick 生效）
local player = world_get("player")
player.hp = math.min(player.hp + 50, player.max_hp)
world_set("player", player)

-- 消灭一个敌人
local entities = world_get("entities")
entities.goblin.alive = false
world_set("entities", entities)
```

> **注意**：游戏在 GM 运行期间暂停，GM 的修改在恢复后的第一个 tick 即生效，
> 无需担心并发冲突。

### 游戏事件
- `events_read(n)` → JSON 字符串（数组）：读取至多 n 条未读游戏事件，自动推进读取游标。

每条事件结构：
```json
{"t": 1712345678, "type": "player_hp_critical", "data": {"hp": 5, "max": 100}}
```
字段：`t`（Unix 时间戳）、`type`（字符串，触发器匹配用）、`data`（任意负载）。

示例用法：
```lua
local raw = events_read(20)
local events = json_decode(raw)
for _, ev in ipairs(events) do
  if ev.type == "player_hp_critical" then
    print("player HP critical: " .. ev.data.hp)
  end
end
```

---

## GM 唤醒协议

GM 不会一直运行——它由 **dispatcher** 按需唤醒。每次唤醒时，用户消息（`user` 角色）为 JSON 字符串，格式如下：

### 事件触发唤醒
```json
{"wake": "trigger", "event": {"t": 1712345678, "type": "player_hp_critical", "data": {"hp": 5}}}
```

### 计划唤醒
```json
{"wake": "schedule", "reason": "world_survey"}
```

---

## GM 职责

每次唤醒时，建议按以下步骤处理：

1. **解析唤醒原因** — 读取 `wake` 字段，了解是事件触发还是计划唤醒。
2. **读取游戏世界** — `world_get("player")`、`world_get("entities")` 等，直接获取当前游戏状态。
3. **读取未读事件** — `events_read(50)` 获取近期游戏动态，补充事件流信息。
4. **决策与行动** — 根据世界状态决定 GM 干预（治疗玩家、消灭敌人、修改属性等），用 `world_set` 写回。
5. **更新触发器与计划** — 按需调整 `state_set("triggers", ...)` 和 `state_set("schedule", ...)`，控制下次唤醒条件。

---

## 示例

```lua
-- 基本计算
return 2 + 2
-- 工具返回："4"

-- 读取并更新世界状态
local world = state_get("world") or {}
world.player_hp = 80
state_set("world", world)
return json_encode(world)

-- 注册触发器与计划
state_set("triggers", {"player_hp_critical", "boss_spawned"})
-- schedule 由宿主填入当前时间；此处示例用固定偏移（实际应从 wake 消息读 t）
local now = (state_get("now") or 0)
state_set("schedule", {{ at = now + 300, reason = "world_survey" }})
return "triggers and schedule updated"
```
