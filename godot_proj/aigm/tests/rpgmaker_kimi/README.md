# RPG Maker 风格编辑器

这是一个基于 Godot 4.x 开发的 RPG Maker 风格游戏编辑器。

## 项目结构

```
.
├── editor.tscn                  # 主入口场景
├── editor/
│   ├── core/                    # 核心管理器
│   │   ├── project_manager.gd   # 项目管理
│   │   ├── database_manager.gd  # 数据库管理
│   │   ├── map_manager.gd       # 地图管理
│   │   └── asset_manager.gd     # 资源管理
│   ├── ui/                      # 用户界面
│   │   ├── main_editor.gd       # 主编辑器
│   │   ├── main_layout.tscn     # 主布局
│   │   ├── menu_bar.tscn        # 菜单栏
│   │   ├── project_dock.tscn    # 项目面板
│   │   └── dialogs/             # 对话框
│   │       ├── new_project_dialog.tscn
│   │       └── new_map_dialog.tscn
│   ├── modules/                 # 功能模块
│   │   ├── map_editor/          # 地图编辑器
│   │   │   ├── map_editor.tscn
│   │   │   ├── map_viewport.tscn
│   │   │   ├── tileset_panel.tscn
│   │   │   └── layer_panel.tscn
│   │   ├── database/            # 数据库编辑器
│   │   │   └── database_editor.tscn
│   │   ├── event_system/        # 事件系统
│   │   │   └── event_editor.tscn
│   │   └── asset_manager/       # 资源管理器
│   │       └── asset_dock.tscn
│   └── resources/
│       └── theme.tres           # 编辑器主题
```

## 功能模块

### 1. 地图编辑器
- 多层图块绘制
- 图块集选择
- 图层管理（显示/隐藏、不透明度）
- 网格显示
- 事件放置
- 缩放和平移

### 2. 数据库编辑器
- 角色编辑
- 职业编辑
- 技能编辑
- 物品编辑
- 武器/防具编辑
- 敌人编辑
- 图块集配置
- 系统设置

### 3. 事件系统
- 可视化事件编辑
- 丰富的指令集
- 条件分支
- 循环控制
- 变量/开关操作

### 4. 资源管理器
- 图片资源浏览
- 音频资源浏览
- 资源预览
- 资源导入

## 使用方法

1. 在 Godot 中打开项目
2. 打开 `editor.tscn` 场景
3. 运行场景启动编辑器

### 创建新项目
1. 点击菜单栏「文件」→「新建项目」
2. 填写项目名称和位置
3. 配置游戏设置
4. 点击确定

### 创建地图
1. 在项目面板中点击「+地图」按钮
2. 设置地图名称、尺寸和图块集
3. 点击确定

### 编辑地图
1. 在项目面板中选择地图
2. 在图块集面板选择图块
3. 使用工具栏工具在地图上绘制
4. 使用图层面板管理图层

### 编辑数据库
1. 点击菜单栏「工具」→「数据库」
2. 选择要编辑的类别
3. 修改数据后点击应用或确定

## 数据结构

### 项目文件
```json
{
    "name": "项目名称",
    "version": "1.0.0",
    "settings": {
        "tile_size": 32,
        "screen_width": 816,
        "screen_height": 624
    }
}
```

### 地图文件 (Map001.json)
```json
{
    "id": 1,
    "name": "MAP001",
    "width": 20,
    "height": 15,
    "tileset_id": 1,
    "data": [...],
    "events": [...]
}
```

## 待完成功能

- [ ] 实际图块集渲染
- [ ] 事件详细编辑
- [ ] 项目导出功能
- [ ] 插件系统
- [ ] 脚本编辑器
- [ ] 战斗测试
- [ ] 游戏预览

## 许可证

MIT License
