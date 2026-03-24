# testsandbox（沙盒测试）

本目录是 AIGM 工程里的玩法试验场：角色移动与战斗、地面物品、**调试面板**（摄像机 / 背包 / 刷道具）、观战相机等。

## 设计约定（testsandbox）

- **默认不按「NPC / 玩家」区分机制**：同一套数值与规则适用于所有 `NekomimiWalker`，除非在文档或代码里**单独说明**。
- **饱食度**：全体角色随时间自然下降，与是否由用户操控无关。
- **输入与 AI 分工**：`user_controlled` 只决定键盘/鼠标等输入与 `NpcBehavior` 是否驱动该实例；觅食、游荡等属于「AI 脚本在启用时的行为」，与饱食度等**全局数值**不是两套规则。

## 布局

| 路径 | 内容 |
|------|------|
| `scenes/` | 场景（`.tscn`），入口一般为 `world.tscn`（与主场景 UID 绑定） |
| `scripts/` | 脚本（`.gd`），与场景分离便于浏览 |
| `assets/` | 贴图、TileSet、物品图标等资源 |

**调试面板**：`scenes/debug_panel.tscn` 挂在 `world.tscn` 左上，折叠标题为「调试面板」；内含摄像机跟随、是否操控跟镜角色、跟镜角色属性、背包列表；下拉选择 `ItemDB` 道具后按 **1** 在**鼠标位置**生成地面掉落（数量见面板导出 `spawn_quantity_min` / `max`）。原「右键随机刷物」已移除。

**容器**：在场景里实例化 `scenes/item_container.tscn`，靠近后按 **F** 打开 `ContainerPanel` 存取物品（与地面拾取共用 F：优先打开容器）。开局多组物品在 Inspector 里填 `initial_stacks`（`ItemStackPreset` 数组）；仍保留单项 `preset_item_id` / `preset_quantity` 作兼容（仅当 `initial_stacks` 为空时生效）。

**交易点**：在场景里实例化 `scenes/shop_point.tscn`，角色靠近后按 **F** 打开 `ShopPanel`。左侧是商店无限库存，右侧是角色背包；支持购买/出售。货币默认用 `misc_copper_coin`（铜币）计价。  
脚本侧（供 NPC/AI 使用）可直接调用 `shop_point.gd` 的 `buy_to_walker(walker, item_id, count)` / `sell_from_walker(walker, slot_index, amount)`，无需 UI。

**统一交互会话**：按 **F** 时会先收集附近可交互设施（如商店、容器）。若只有 1 个目标则直接交互；若有多个目标会弹出 `InteractPickerPanel` 供玩家选择。

**独占交互**：容器与商店都实现 `try_acquire/release` 会话锁，单个设施同一时刻只允许 1 名角色交互。若被占用，其它角色不会进入该设施会话。

**NPC 与玩家一致流程**：NPC 访问设施时也会打开同一套面板（共享 UI），并以分步延时执行操作，面板会实时刷新，不再“瞬时完成后立刻离开”。

**背包面板**：用户可按 **Q** 打开 `InventoryPanel`，并在面板中使用道具。NPC 在觅食时也会打开同一面板，再按步骤延时使用背包食物，整个过程会实时更新 UI。

工程主场景在 `project.godot` 里设为 `res://tests/testsandbox/scenes/world.tscn`（与 `world.tscn` 内 UID 一致）。在编辑器里保存主场景后，Godot 也可改回 `uid://…` 形式。

## TODO（下一步：抽象设施 + Utility AI）

- [ ] **引入 Utility AI 决策层**：以 `Need / Goal / Action` 打分选行动，替代硬编码状态分支（保留少量硬规则做兜底）。
- [ ] **设施抽象统一接口**：新增通用 `InteractableFacility` 数据/组件，不让 NPC 识别“床/工作台”具体名词，只读取属性标签与效果。
- [ ] **设施属性标签（可组合）**：例如 `rest`, `work`, `social`, `trade`, `service`；每个设施可同时拥有多个标签与不同效率。
- [ ] **交互契约标准化**：统一字段如 `duration_sec`、`cost_money`、`reward_money`、`satiation_delta`、`energy_delta`、`social_delta`、`cooldown_sec`、`capacity`。
- [ ] **工作-消费闭环**：NPC 可去 `work` 点换钱，再去 `trade/service` 点消费（买食物、买服务），形成基础经济循环。
- [ ] **社交与休息行为**：`social` 点聚集闲聊，`rest` 点睡觉恢复；行为权重受时间段、压力、关系、饱食/精力影响。
- [ ] **排队与占用系统**：设施支持 `capacity`、占用锁、排队超时、失败重试，避免 NPC 重叠抢同一交互点。
- [ ] **可插拔扩展**：新增设施时优先“配数据 + 挂组件 + 设标签”，尽量不改 AI 主逻辑代码。
- [ ] **调试可视化**：在 DebugPanel 增加当前 `Top Goals`、行动评分、目标设施、剩余交互时长，便于调参。
- [ ] **平衡参数表**：把关键权重和阈值集中到配置（资源或 JSON），支持快速迭代而不频繁改脚本。
