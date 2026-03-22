# testsandbox（沙盒测试）

本目录是 AIGM 工程里的玩法试验场：角色移动与战斗、地面物品、背包 UI、观战相机等。

## 布局

| 路径 | 内容 |
|------|------|
| `scenes/` | 场景（`.tscn`），入口一般为 `world.tscn`（与主场景 UID 绑定） |
| `scripts/` | 脚本（`.gd`），与场景分离便于浏览 |
| `assets/` | 贴图、TileSet、物品图标等资源 |

工程主场景在 `project.godot` 里设为 `res://tests/testsandbox/scenes/world.tscn`（与 `world.tscn` 内 UID 一致）。在编辑器里保存主场景后，Godot 也可改回 `uid://…` 形式。
