## 第四层：RPG深度系统

> 目标：装备、技能、状态效果、等级，让数值有深度。

### 4.1 Modifier系统

**这是第四层的基础，其他所有系统依赖它。**

所有属性加成不直接修改stats，而是通过modifier层叠加。

**active_modifiers组件**：
```
active_modifiers = {
    [modifier_id] = {
        id       : string
        source   : eid        -- 来源实体（哪件装备/谁施的buff）
        duration : number|nil -- nil=永久，number=剩余tick数
        stats = {
            [stat_name] = {
                add : number | nil
                mul : number | nil  -- 乘法在加法之后应用
            }
        }
        flags = {
            cannot_act   : bool | nil
            cannot_move  : bool | nil
            invisible    : bool | nil
            -- 后续可扩展
        }
    }
}
```

**stats_system（工具模块，非独立system）**：
- `get_stat(world, eid, stat_name)` → 计算base + 所有modifier叠加后的有效值
- 计算顺序：先累加所有add，再累乘所有mul，结果取floor
- `has_flag(world, eid, flag_name)` → 检查是否有某个flag

**status_system（Priority：55）**：
- 每tick遍历所有`active_modifiers`
- duration不为nil的modifier，duration - 1
- duration归零时移除该modifier，emit `modifier_removed`事件

### 4.2 装备系统

**equipment_slots组件**：
```
equipment_slots = {
    main_hand  : item_eid | nil
    off_hand   : item_eid | nil
    head       : item_eid | nil
    body       : item_eid | nil
    feet       : item_eid | nil
    accessory  : item_eid | nil
}
```

**item_def中的equippable定义**：
```lua
equippable = {
    slot      = "main_hand",
    modifiers = {
        stats = {
            attack  = { add = 8 },
            speed   = { add = -1 },
        }
    }
}
```

**equipment_system（工具模块）**：
- `equip(world, actor_eid, item_eid)` →
 1. 检查slot是否空闲，不空闲先unequip
 2. 更新equipment_slots
 3. 更新item的location组件
 4. 将item的modifiers添加到actor的active_modifiers（duration=nil）
 5. emit `item_equipped`
- `unequip(world, actor_eid, slot)` →
 1. 移除对应modifier
 2. 更新slot为nil
 3. 更新item的location为inventory
 4. emit `item_unequipped`

### 4.3 背包系统

**inventory组件**：
```
inventory = {
    capacity      : number        -- 最大携带重量
    weight_current: number
    items         : { item_eid → true }
}
```

**item_system（Priority：40）**：
处理`ai_intent`为`pick_up`的情况：
1. 检查item是否在同一房间
2. 检查背包重量是否超限
3. 更新item的location（ground → inventory）
4. 更新inventory的items和weight
5. emit `item_picked_up`

AI何时拾取：在ai_system中，实体ready时检查同房间是否有感兴趣的物品（由AI行为原型决定感兴趣的条件）。

### 4.4 技能系统

**skills组件**：
```
skills = {
    [skill_id] = {
        def_id   : string
        level    : number       -- 技能等级，影响效果
        cooldown_cur : number   -- 剩余冷却tick
    }
}
```

**skill_def数据格式**：
```lua
return {
    id   = "shield_bash",
    name = "盾击",
    tags = { "active", "melee" },
    
    cooldown = 50,   -- tick冷却
    
    requirements = {
        equipment = { off_hand = { tag = "shield" } },
    },
    
    targeting = "single_enemy_same_room",
    
    effects = {
        {
            type        = "damage",
            formula     = "attacker.attack * 0.8",
            damage_type = "physical",
        },
        {
            type      = "apply_modifier",
            modifier  = {
                stats = {},
                flags = { cannot_act = true, cannot_move = true }
            },
            duration  = 15,
            chance    = 0.3,
        }
    },
    
    -- AI使用倾向
    ai_weight = function(world, user_eid, target_eid)
        -- 返回0-1，越高越倾向使用
        -- 比如：目标正在施法时权重更高
        return 0.5
    end,
}
```

**skill_system（Priority：38）**：
处理`ai_intent`为`use_skill`的情况：
1. 验证技能要求（装备、冷却等）
2. 按effects列表逐个执行效果
3. 效果类型：`damage`、`heal`、`apply_modifier`、`remove_modifier`、`summon`
4. 重置技能cd和action_timer
5. emit `skill_used`

**status_system同时负责技能cd**：
每tick遍历所有实体的skills，cooldown_cur > 0的-1。

### 4.5 等级系统

**level组件**：
```
level = {
    current : number
    xp      : number
    xp_next : number   -- 升级所需经验，由level_curve计算
}
```

**level_curve数据定义**：
```lua
-- data/config/level_curve.lua
return {
    base_xp  = 100,
    exponent = 1.5,
    
    -- 升级时的属性成长，按职业/类型分
    growth = {
        default = {
            hp_max  = { add = 5  },
            attack  = { add = 2  },
            defense = { add = 1  },
        },
        warrior = {
            hp_max  = { add = 10 },
            attack  = { add = 3  },
            defense = { add = 2  },
        },
    },
    
    -- 某些等级解锁技能
    skill_unlock = {
        -- [level] = skill_id
        [3]  = "power_strike",
        [5]  = "battle_cry",
    }
}
```

**level_system（订阅xp_gained事件）**：
1. 增加xp
2. 如果xp >= xp_next：触发升级
3. 升级：level+1，计算新xp_next，按growth表增加base stats
4. 检查skill_unlock，有则添加新技能到skills组件
5. emit `entity_leveled_up`

**验收标准**：
- 装备物品后有效属性正确变化
- buff/debuff有持续时间，到期自动移除
- 技能有冷却，效果正确执行
- 击杀获得经验，经验足够后升级
- 升级后属性正确提升

---