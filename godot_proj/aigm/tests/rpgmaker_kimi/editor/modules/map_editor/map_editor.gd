@tool
extends Panel

## 地图编辑器主面板
## 管理地图视口、工具栏和交互

signal tile_drawn(x: int, y: int, layer: int, tile_id: int)
signal event_selected(event_id: int)
signal map_position_changed(position: Vector2i)

@onready var map_label: Label = $VBoxContainer/Toolbar/MapLabel
@onready var zoom_label: Label = $VBoxContainer/Toolbar/ZoomLabel
@onready var position_label: Label = $VBoxContainer/BottomBar/PositionLabel
@onready var tile_info: Label = $VBoxContainer/BottomBar/TileInfo
@onready var zoom_in_btn: Button = $VBoxContainer/Toolbar/ZoomIn
@onready var zoom_out_btn: Button = $VBoxContainer/Toolbar/ZoomOut
@onready var grid_toggle: CheckButton = $VBoxContainer/Toolbar/GridToggle
@onready var event_toggle: CheckButton = $VBoxContainer/Toolbar/EventToggle
@onready var viewport: SubViewport = $VBoxContainer/ViewportContainer/MapViewport
@onready var viewport_container: SubViewportContainer = $VBoxContainer/ViewportContainer

var current_map_id: int = -1
var current_layer: int = 0
var current_tile_id: int = 0
var current_tool: String = "pencil"
var zoom_level: float = 1.0
var show_grid: bool = true
var show_events: bool = true

# 绘制状态
var is_drawing: bool = false
var draw_start_pos: Vector2i = Vector2i.ZERO
var last_drawn_pos: Vector2i = Vector2i(-1, -1)

func _ready():
	# 连接信号
	zoom_in_btn.pressed.connect(_on_zoom_in)
	zoom_out_btn.pressed.connect(_on_zoom_out)
	grid_toggle.toggled.connect(_on_grid_toggled)
	event_toggle.toggled.connect(_on_event_toggled)
	
	# 连接视口信号
	if viewport.has_signal("tile_clicked"):
		viewport.tile_clicked.connect(_on_tile_clicked)
	if viewport.has_signal("tile_dragged"):
		viewport.tile_dragged.connect(_on_tile_dragged)
	if viewport.has_signal("map_position_changed"):
		viewport.map_position_changed.connect(_on_map_position_changed)

func _on_zoom_in():
	zoom_level = min(zoom_level * 1.2, 4.0)
	_update_zoom()

func _on_zoom_out():
	zoom_level = max(zoom_level / 1.2, 0.25)
	_update_zoom()

func _update_zoom():
	zoom_label.text = "%d%%" % int(zoom_level * 100)
	if viewport:
		viewport.set_zoom(zoom_level)

func _on_grid_toggled(toggled: bool):
	show_grid = toggled
	if viewport:
		viewport.show_grid = show_grid

func _on_event_toggled(toggled: bool):
	show_events = toggled
	if viewport:
		viewport.show_events = show_events

func _on_tile_clicked(pos: Vector2i, button: int):
	match current_tool:
		"pencil":
			_draw_tile(pos)
		"fill":
			_fill_area(pos)
		"erase":
			_erase_tile(pos)
		_:
			_draw_tile(pos)

func _on_tile_dragged(pos: Vector2i, button: int):
	if button == MOUSE_BUTTON_LEFT:
		match current_tool:
			"pencil", "erase":
				if pos != last_drawn_pos:
					if current_tool == "pencil":
						_draw_tile(pos)
					else:
						_erase_tile(pos)
					last_drawn_pos = pos

func _on_map_position_changed(pos: Vector2i):
	position_label.text = "X: %d, Y: %d" % [pos.x, pos.y]
	map_position_changed.emit(pos)

func _draw_tile(pos: Vector2i):
	if viewport:
		viewport.set_tile(pos.x, pos.y, current_layer, current_tile_id)
		tile_drawn.emit(pos.x, pos.y, current_layer, current_tile_id)
		tile_info.text = "图块: %d" % current_tile_id

func _erase_tile(pos: Vector2i):
	if viewport:
		viewport.set_tile(pos.x, pos.y, current_layer, 0)
		tile_drawn.emit(pos.x, pos.y, current_layer, 0)
		tile_info.text = "图块: 0"

func _fill_area(pos: Vector2i):
	# TODO: 实现填充算法
	print("填充区域: ", pos)

# ===== 公共接口 =====

func load_map(map_id: int, map_data: Dictionary):
	current_map_id = map_id
	map_label.text = "地图: %s" % map_data.get("name", "未命名")
	
	if viewport:
		viewport.load_map(map_data)
	
	_update_zoom()

func clear_map():
	current_map_id = -1
	map_label.text = "地图: 未选择"
	if viewport:
		viewport.clear_map()

func set_current_layer(layer: int):
	current_layer = layer
	if viewport:
		viewport.set_current_layer(layer)

func set_current_tile(tile_id: int):
	current_tile_id = tile_id

func set_tool(tool: String):
	current_tool = tool
	print("工具切换到: ", tool)

func set_tileset(tileset_texture: Texture2D, tileset_data: Dictionary):
	if viewport:
		viewport.set_tileset(tileset_texture, tileset_data)

func refresh_view():
	if viewport:
		viewport.refresh()

func save_current_map() -> Dictionary:
	if viewport:
		return viewport.get_map_data()
	return {}
