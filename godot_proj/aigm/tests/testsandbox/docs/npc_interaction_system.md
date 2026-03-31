# NPC 交互设施系统

## 概述

交互设施系统是 NPC 与游戏世界互动的核心机制。通过一套**鸭子类型**的接口约定，任何场景节点都可以成为可交互设施——NPC 无需知道设施具体是什么，只需要调用约定的方法即可完成交互。

### 核心设计

- **统一接口**：所有设施实现相同的方法签名
- **占用机制**：设施可被占用，防止多人同时使用
- **NPC 无感知**：NPC 代码不依赖具体设施类型，只依赖方法存在
- **玩家/NPC 共享**：同一套设施接口供玩家和 NPC 使用

---

## 鸭子类型接口规范

GDScript 没有 `interface` 关键字，通过**鸭子类型**实现：只要对象有这些方法，就可以作为设施使用。

### 必需方法

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `can_interact` | `walker: NekomimiWalker` | `bool` | 检查设施是否可用（未被占用、在范围内等） |
| `try_acquire` | `walker: NekomimiWalker` | `bool` | 尝试占用设施，成功返回 true |
| `release` | `walker: NekomimiWalker` | - | 释放设施占用 |

### 可选方法

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `is_walker_in_range` | `walker: CharacterBody2D` | `bool` | 检查角色是否在交互范围内 |
| `get_current_user` | - | `NekomimiWalker` | 获取当前占用者 |
| `build_f_interact_entry` | `walker: NekomimiWalker` | `Dictionary` | 构建玩家 F 键菜单项 |

### 安全调用模式

```gdscript
# 调用方使用 has_method + call 进行安全检查
if facility.has_method("can_interact") and facility.call("can_interact", walker):
    if facility.has_method("try_acquire") and facility.call("try_acquire", walker):
        # 执行交互逻辑
        if facility.has_method("apply_effect"):
            facility.call("apply_effect", walker)
        facility.call("release", walker)
```

---

## 现有设施详解

### 1. ShopPoint (商店)

**场景**: `scenes/shop_point.tscn`  
**脚本**: `scripts/shop_point.gd`

**功能**：买卖物品，NPC 可在饥饿时自动购买食物

**接口实现**：
```gdscript
func can_interact(walker: NekomimiWalker) -> bool
func try_acquire(walker: NekomimiWalker) -> bool
func release(walker: NekomimiWalker)
func is_walker_in_range(walker: CharacterBody2D) -> bool
func get_current_user() -> NekomimiWalker
func build_f_interact_entry(walker: NekomimiWalker) -> Dictionary
```

**特有方法**（NPC 使用）：
```gdscript
# NPC 购买物品，返回实际购买数量
func buy_to_walker(walker: NekomimiWalker, item_id: String, count: int) -> int

# NPC 出售物品，返回实际卖出数量
func sell_from_walker(walker: NekomimiWalker, slot_index: int, amount: int) -> int

# 获取物品购买价格
func get_buy_price(item_id: String) -> int

# 获取物品出售价格
func get_sell_price(item_id: String) -> int

# 获取商店售卖物品列表
func get_sell_item_ids() -> Array[String]
```

**配置属性**：
```gdscript
@export var display_name: String = "商店"
@export var interact_radius: float = 92.0
@export var sell_item_ids: Array[String] = []  # 空则售卖所有物品
@export var buy_price_multiplier: float = 1.0
@export var sell_price_multiplier: float = 0.6
```

---

### 2. BedPoint (床铺)

**场景**: `scenes/bed_point.tscn`  
**脚本**: `scripts/bed_point.gd`

**功能**：NPC 休息恢复精力

**接口实现**：标准 6 个方法

**特有方法**：
```gdscript
# 获取 NPC 使用时长（秒）
func get_npc_action_duration_sec() -> float

# 应用休息效果（恢复精力）
func apply_rest_to_walker(walker: NekomimiWalker) -> void
```

**使用流程**：
1. NPC 移动到床铺位置
2. 调用 `try_acquire` 占用床铺
3. 调用 `apply_rest_to_walker` 恢复精力
4. 调用 `release` 释放床铺

---

### 3. WorkPoint (工作点)

**场景**: `scenes/work_point.tscn`  
**脚本**: `scripts/work_point.gd`

**功能**：NPC 打工赚取货币

**接口实现**：标准 6 个方法

**特有方法**：
```gdscript
# 获取 NPC 工作时长（秒）
func get_npc_action_duration_sec() -> float

# 应用打工报酬
func apply_pay_to_walker(walker: NekomimiWalker) -> void
```

**使用流程**：
1. NPC 移动到工作点
2. 调用 `try_acquire` 占用工位
3. 等待工作时长
4. 调用 `apply_pay_to_walker` 获得货币
5. 调用 `release` 释放工位

---

### 4. ItemContainer (容器)

**场景**: `scenes/item_container.tscn`  
**脚本**: `scripts/item_container.gd`

**功能**：存储物品，NPC 可取用其中的食物

**接口实现**：标准 6 个方法

**特有属性和方法**：
```gdscript
# 容器存储的物品数组
var storage: Array[Dictionary] = []

# NPC 从容器取出物品到背包
func withdraw_to_walker(walker: NekomimiWalker, slot_index: int, amount: int) -> int

# 获取物品图标
func get_item_icon_texture(item_id: String) -> Texture2D
```

---

## NPC 如何使用设施

### 设施搜索

```gdscript
# 在 NpcBehavior 中搜索最近的可交互设施
func _find_nearest_facility(w: NekomimiWalker, group_name: String, radius: float) -> Node2D:
    var best: Node2D = null
    var best_d2: float = INF
    var r2: float = radius * radius
    
    for n in get_tree().get_nodes_in_group(group_name):
        if not is_instance_valid(n) or not (n is Node2D):
            continue
        
        # 检查 can_interact 方法（鸭子类型）
        if n.has_method("can_interact") and not bool(n.call("can_interact", w)):
            continue
            
        var d2: float = w.global_position.distance_squared_to(n.global_position)
        if d2 <= r2 and d2 < best_d2:
            best = n
            best_d2 = d2
    return best

# 使用示例
var shop = _find_nearest_facility(walker, "shop_point", 880.0)
var bed = _find_nearest_facility(walker, "bed_point", 920.0)
var work = _find_nearest_facility(walker, "work_point", 920.0)
```

### 标准交互流程

```gdscript
# 1. 移动到设施
walker.move_to(facility.global_position)

# 2. 检查是否在范围内
if facility.has_method("is_walker_in_range") and facility.call("is_walker_in_range", walker):
    
    # 3. 尝试占用
    if facility.has_method("try_acquire") and facility.call("try_acquire", walker):
        
        # 4. 执行设施特定操作
        if facility.has_method("apply_rest_to_walker"):
            facility.call("apply_rest_to_walker", walker)
        elif facility.has_method("apply_pay_to_walker"):
            facility.call("apply_pay_to_walker", walker)
        
        # 5. 释放设施
        if facility.has_method("release"):
            facility.call("release", walker)
```

### 会话管理

设施占用后创建"会话"，包含 UI 面板和占用状态：

```gdscript
# NPC 开始与容器交互
func _start_forage_container_session(w: NekomimiWalker, c: Node) -> void:
    # 尝试占用
    if not c.has_method("try_acquire") or not bool(c.call("try_acquire", w)):
        return
    
    # 打开 UI 面板（玩家可见 NPC 操作）
    var panel = host.call("spawn_container_session", w, c, w.name)
    
    # 执行多次取物操作
    for i in range(facility_actions_per_session):
        if not c.has_method("is_walker_in_range") or not c.call("is_walker_in_range", w):
            break
        _try_withdraw_food_from_container(w, c)
        await get_tree().create_timer(facility_action_step_delay_sec).timeout
    
    # 关闭面板并释放
    panel.call("close_if_actor", w)
    c.call("release", w)
```

---

## 创建新设施

### 最小实现示例

创建一个最简单的治疗泉水：

```gdscript
# healing_spring.gd
extends Node2D

@export var interact_radius: float = 80.0
@export var heal_amount: int = 50

var _session_owner: NekomimiWalker = null

func _ready():
    add_to_group("interactable_facility")
    add_to_group("healing_spring")  # 供 NPC 搜索

# === 鸭子类型接口方法 ===

func is_walker_in_range(walker: CharacterBody2D) -> bool:
    return global_position.distance_to(walker.global_position) <= interact_radius

func can_interact(walker: NekomimiWalker) -> bool:
    return is_walker_in_range(walker) and (_session_owner == null or _session_owner == walker)

func try_acquire(walker: NekomimiWalker) -> bool:
    if not can_interact(walker):
        return false
    _session_owner = walker
    return true

func release(walker: NekomimiWalker) -> void:
    if _session_owner == walker:
        _session_owner = null

func build_f_interact_entry(walker: NekomimiWalker) -> Dictionary:
    if not can_interact(walker):
        return {}
    return {
        "node": self,
        "label": "F 饮用泉水",
        "d2": walker.global_position.distance_squared_to(global_position)
    }

# === 设施特定方法 ===

func apply_heal_to_walker(walker: NekomimiWalker) -> void:
    walker.hp = mini(walker.hp + heal_amount, walker.combat_max_hp)
    walker.hp_changed.emit(walker.hp, walker.combat_max_hp)
```

### 完整设施清单

创建新设施需要：

1. **脚本**：实现鸭子类型接口
2. **场景**：包含 `Area2D` 用于范围检测（可选但推荐）
3. **分组**：加入 `"interactable_facility"` 和自定义分组
4. **NPC 支持**：在 `NpcBehavior` 中添加使用逻辑（如需要）

---

## 玩家与设施交互

### F 键交互系统

玩家按 **F** 键时，系统收集周围所有设施的交互选项：

```gdscript
# NekomimiWalker._collect_f_interact_targets()
func _collect_f_interact_targets() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for n in get_tree().get_nodes_in_group("interactable_facility"):
        if n.has_method("build_f_interact_entry"):
            var entry = n.call("build_f_interact_entry", self)
            if not entry.is_empty():
                out.append(entry)
    # 按距离排序
    out.sort_custom(func(a, b): return a.d2 < b.d2)
    return out
```

### 交互菜单

- **单个设施**：直接交互
- **多个设施**：弹出选择面板 `interact_picker_panel.tscn`

### 面板类型

| 设施 | 玩家面板 | NPC 可见 |
|------|----------|----------|
| ShopPoint | `shop_panel.tscn` | 是（简化显示） |
| ItemContainer | `container_panel.tscn` | 是 |
| BedPoint/WorkPoint | 无（直接执行） | 是（脚下进度条） |

---

## 设施事件

设施可发出信号通知状态变化：

```gdscript
# 商店示例
signal shop_changed              # 商品列表变化
signal interaction_state_changed # 占用状态变化
```

---

## 文件索引

| 文件 | 说明 |
|------|------|
| `scripts/shop_point.gd` | 商店设施 |
| `scripts/bed_point.gd` | 床铺设施 |
| `scripts/work_point.gd` | 工作点设施 |
| `scripts/item_container.gd` | 容器设施 |
| `scripts/npc_behavior.gd` | NPC 设施使用逻辑（搜索、占用、释放） |
| `scripts/nekomimi_walker.gd` | 玩家 F 键交互收集 |
| `scenes/shop_point.tscn` | 商店场景 |
| `scenes/bed_point.tscn` | 床铺场景 |
| `scenes/work_point.tscn` | 工作点场景 |
| `scenes/item_container.tscn` | 容器场景 |
