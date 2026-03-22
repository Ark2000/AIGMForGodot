@tool
extends HSplitContainer

## 主布局管理器
## 管理左中右三个面板的显示和隐藏

signal map_selected(map_id: int)
signal layer_selected(layer_index: int)
signal tile_selected(tile_id: int)

@onready var left_panel: VSplitContainer = $LeftPanel
@onready var center_panel: VSplitContainer = $CenterPanel
@onready var right_panel: VSplitContainer = $RightPanel

@onready var project_dock: Control = $LeftPanel/ProjectDock
@onready var tileset_panel: Control = $LeftPanel/TilesetPanel
@onready var map_editor: Control = $CenterPanel/MapEditor
@onready var asset_dock: Control = $CenterPanel/AssetDock
@onready var layer_panel: Control = $RightPanel/LayerPanel
@onready var properties_panel: Panel = $RightPanel/PropertiesPanel

func _ready():
	# 连接子面板信号
	_connect_panels()

func _connect_panels():
	# 连接项目面板信号
	if project_dock.has_signal("map_selected"):
		project_dock.map_selected.connect(_on_map_selected)
	
	# 连接图块集面板信号
	if tileset_panel.has_signal("tile_selected"):
		tileset_panel.tile_selected.connect(_on_tile_selected)
	
	# 连接图层面板信号
	if layer_panel.has_signal("layer_selected"):
		layer_panel.layer_selected.connect(_on_layer_selected)

func _on_map_selected(map_id: int):
	map_selected.emit(map_id)

func _on_tile_selected(tile_id: int):
	tile_selected.emit(tile_id)

func _on_layer_selected(layer_index: int):
	layer_selected.emit(layer_index)

# ===== 面板显示控制 =====

func show_panel(panel_name: String):
	match panel_name:
		"project":
			left_panel.visible = true
			project_dock.visible = true
		"tileset":
			left_panel.visible = true
			tileset_panel.visible = true
		"map":
			center_panel.visible = true
			map_editor.visible = true
		"assets":
			center_panel.visible = true
			asset_dock.visible = true
		"layers":
			right_panel.visible = true
			layer_panel.visible = true
		"properties":
			right_panel.visible = true
			properties_panel.visible = true

func hide_panel(panel_name: String):
	match panel_name:
		"project":
			project_dock.visible = false
		"tileset":
			tileset_panel.visible = false
		"map":
			map_editor.visible = false
		"assets":
			asset_dock.visible = false
		"layers":
			layer_panel.visible = false
		"properties":
			properties_panel.visible = false

func toggle_panel(panel_name: String):
	match panel_name:
		"project":
			project_dock.visible = !project_dock.visible
		"tileset":
			tileset_panel.visible = !tileset_panel.visible
		"map":
			map_editor.visible = !map_editor.visible
		"assets":
			asset_dock.visible = !asset_dock.visible
		"layers":
			layer_panel.visible = !layer_panel.visible
		"properties":
			properties_panel.visible = !properties_panel.visible

# ===== 获取面板引用 =====

func get_map_editor() -> Control:
	return map_editor

func get_tileset_panel() -> Control:
	return tileset_panel

func get_layer_panel() -> Control:
	return layer_panel

func get_project_dock() -> Control:
	return project_dock

func get_asset_dock() -> Control:
	return asset_dock

func get_properties_panel() -> Panel:
	return properties_panel
