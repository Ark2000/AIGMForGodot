@tool
class_name RPGMakerEditor
extends Control

## RPG Maker 风格编辑器主类
## 负责管理整个编辑器的生命周期和模块通信

signal project_loaded(project_path: String)
signal project_saved(project_path: String)
signal current_map_changed(map_id: int)

# 核心管理器
var project_manager: ProjectManager
var database_manager: DatabaseManager
var map_manager: MapManager
var asset_manager: AssetManager

# 对话框和窗口
var new_project_dialog: Window
var new_map_dialog: Window
var database_editor: Window
var event_editor: Window

# 当前状态
var current_project_path: String = ""
var current_map_id: int = -1
var is_modified: bool = false

@onready var menu_bar: Panel = $VBoxContainer/MenuBar
@onready var main_layout: Control = $VBoxContainer/MainLayout
@onready var status_label: Label = $VBoxContainer/StatusBar/HBoxContainer/StatusLabel
@onready var zoom_label: Label = $VBoxContainer/StatusBar/HBoxContainer/ZoomLabel
@onready var position_label: Label = $VBoxContainer/StatusBar/HBoxContainer/PositionLabel

func _ready():
	print("RPG Maker Editor 初始化...")
	
	# 初始化核心管理器
	project_manager = ProjectManager.new()
	database_manager = DatabaseManager.new()
	map_manager = MapManager.new()
	asset_manager = AssetManager.new()
	
	add_child(project_manager)
	add_child(database_manager)
	add_child(map_manager)
	add_child(asset_manager)
	
	# 初始化对话框
	_init_dialogs()
	
	# 连接信号
	_connect_signals()
	
	# 更新状态栏
	_update_status("编辑器就绪")

func _init_dialogs():
	# 新建项目对话框
	new_project_dialog = preload("res://editor/ui/dialogs/new_project_dialog.tscn").instantiate()
	new_project_dialog.project_created.connect(_on_project_created)
	add_child(new_project_dialog)
	
	# 新建地图对话框
	new_map_dialog = preload("res://editor/ui/dialogs/new_map_dialog.tscn").instantiate()
	new_map_dialog.map_created.connect(_on_map_created)
	add_child(new_map_dialog)
	
	# 数据库编辑器
	database_editor = preload("res://editor/modules/database/database_editor.tscn").instantiate()
	database_editor.initialize(database_manager)
	add_child(database_editor)
	
	# 事件编辑器
	event_editor = preload("res://editor/modules/event_system/event_editor.tscn").instantiate()
	add_child(event_editor)

func _connect_signals():
	# 连接菜单信号
	if menu_bar.has_signal("file_menu_selected"):
		menu_bar.file_menu_selected.connect(_on_file_menu)
	if menu_bar.has_signal("edit_menu_selected"):
		menu_bar.edit_menu_selected.connect(_on_edit_menu)
	if menu_bar.has_signal("view_menu_selected"):
		menu_bar.view_menu_selected.connect(_on_view_menu)
	if menu_bar.has_signal("tools_menu_selected"):
		menu_bar.tools_menu_selected.connect(_on_tools_menu)
	if menu_bar.has_signal("help_menu_selected"):
		menu_bar.help_menu_selected.connect(_on_help_menu)
	
	# 连接主布局信号
	if main_layout.has_signal("map_selected"):
		main_layout.map_selected.connect(_on_map_selected)
	if main_layout.has_signal("tile_selected"):
		main_layout.tile_selected.connect(_on_tile_selected)
	if main_layout.has_signal("layer_selected"):
		main_layout.layer_selected.connect(_on_layer_selected)
	
	# 连接项目面板信号
	var project_dock = main_layout.get_project_dock()
	if project_dock:
		project_dock.map_selected.connect(_on_project_map_selected)

func _on_file_menu(id: int):
	match id:
		0: _new_project()
		1: _open_project()
		2: _save_project()
		4: _import_assets()
		5: _export_project()
		7: _quit()

func _on_edit_menu(id: int):
	match id:
		0: undo()
		1: redo()
		3: cut()
		4: copy()
		5: paste()

func _on_view_menu(id: int):
	match id:
		0: show_map_editor()
		1: show_database()
		2: show_event_editor()
		4: toggle_fullscreen()

func _on_tools_menu(id: int):
	match id:
		0: show_database()
		1: show_plugin_manager()
		3: show_options()

func _on_help_menu(id: int):
	match id:
		0: show_documentation()
		2: show_about()

# ===== 文件操作 =====

func _new_project():
	print("创建新项目...")
	new_project_dialog.show_dialog()
	_update_status("创建新项目")

func _on_project_created(project_name: String, project_path: String, settings: Dictionary):
	print("创建项目: ", project_name, " 在 ", project_path)
	
	if project_manager.create_project(project_path, project_name):
		# 应用设置
		for key in settings.keys():
			project_manager.set_setting(key, settings[key])
		
		project_manager.save_project()
		current_project_path = project_path
		
		# 加载数据库
		database_manager.load_database(project_manager.get_data_path())
		
		# 加载地图
		map_manager.load_maps(project_manager.get_maps_path())
		
		# 加载资源
		asset_manager.scan_project_assets(project_path)
		
		project_loaded.emit(project_path)
		_update_status("项目已创建: " + project_name)

func _open_project():
	print("打开项目...")
	# TODO: 打开文件对话框选择项目
	_update_status("打开项目")
	
	# 临时：直接加载示例项目
	_load_sample_project()

func _load_sample_project():
	# 创建一个示例项目用于演示
	print("加载示例项目...")
	_update_status("示例项目已加载")

func _save_project():
	print("保存项目...")
	project_saved.emit(current_project_path)
	_update_status("项目已保存")

func _import_assets():
	print("导入资源...")
	_update_status("导入资源")

func _export_project():
	print("导出项目...")
	_update_status("导出项目")

func _quit():
	get_tree().quit()

# ===== 编辑操作 =====

func undo():
	print("撤销")
	_update_status("撤销")

func redo():
	print("重做")
	_update_status("重做")

func cut():
	print("剪切")

func copy():
	print("复制")

func paste():
	print("粘贴")

# ===== 视图切换 =====

func show_map_editor():
	print("显示地图编辑器")
	_update_status("地图编辑器")

func show_database():
	print("显示数据库")
	database_editor.show_editor()
	_update_status("数据库编辑器")

func show_event_editor():
	print("显示事件编辑器")
	# 打开事件编辑器
	event_editor.edit_event({})
	_update_status("事件编辑器")

func toggle_fullscreen():
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func show_plugin_manager():
	print("显示插件管理器")

func show_options():
	print("显示选项")

func show_documentation():
	print("显示文档")

func show_about():
	print("显示关于")

# ===== 地图操作 =====

func _on_map_created(map_data: Dictionary):
	var map_id = map_manager.create_map(map_data.width, map_data.height, map_data.tileset_id)
	var full_map_data = map_manager.get_map(map_id)
	full_map_data.name = map_data.name
	full_map_data.display_name = map_data.display_name
	
	map_manager.save_map(project_manager.get_maps_path(), full_map_data)
	
	# 刷新项目面板
	var project_dock = main_layout.get_project_dock()
	if project_dock:
		project_dock.add_map({
			"id": map_id,
			"name": map_data.name,
			"type": "map",
			"parent": -1
		})

func _on_map_selected(map_id: int):
	print("选择地图: ", map_id)
	current_map_id = map_id
	
	var map_data = map_manager.get_map(map_id)
	if not map_data.is_empty():
		var map_editor = main_layout.get_map_editor()
		if map_editor:
			map_editor.load_map(map_id, map_data)
		current_map_changed.emit(map_id)

func _on_tile_selected(tile_id: int):
	var map_editor = main_layout.get_map_editor()
	if map_editor:
		map_editor.set_current_tile(tile_id)

func _on_layer_selected(layer_index: int):
	var map_editor = main_layout.get_map_editor()
	if map_editor:
		map_editor.set_current_layer(layer_index)

func _on_project_map_selected(map_id: int):
	_on_map_selected(map_id)

# ===== 状态管理 =====

func _update_status(message: String):
	if status_label:
		status_label.text = message

func update_position(pos: Vector2i):
	if position_label:
		position_label.text = "X: %d, Y: %d" % [pos.x, pos.y]

func update_zoom(zoom: float):
	if zoom_label:
		zoom_label.text = "%d%%" % int(zoom * 100)

# ===== 公共接口 =====

func get_map_manager() -> MapManager:
	return map_manager

func get_database_manager() -> DatabaseManager:
	return database_manager

func get_asset_manager() -> AssetManager:
	return asset_manager

# ===== 对话框接口 =====

func show_new_map_dialog():
	if new_map_dialog:
		new_map_dialog.show_dialog()
