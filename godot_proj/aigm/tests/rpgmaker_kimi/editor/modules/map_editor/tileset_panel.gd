@tool
extends Panel

## 图块集面板
## 显示和选择图块集中的图块

signal tile_selected(tile_id: int)
signal tile_preview_requested(tile_id: int)

@onready var tileset_selector: OptionButton = $VBoxContainer/TilesetSelector
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var tileset_display: Control = $VBoxContainer/ScrollContainer/TilesetDisplay
@onready var tileset_texture: TextureRect = $VBoxContainer/ScrollContainer/TilesetDisplay/TilesetTexture
@onready var selection_overlay: Control = $VBoxContainer/ScrollContainer/TilesetDisplay/SelectionOverlay
@onready var tile_id_label: Label = $VBoxContainer/BottomBar/TileIdLabel
@onready var passability_btn: Button = $VBoxContainer/BottomBar/PassabilityBtn

var current_tileset_id: int = 0
var tilesets: Dictionary = {}
var selected_tile_id: int = 0
var tile_size: int = 32

func _ready():
	# 连接信号
	tileset_selector.item_selected.connect(_on_tileset_selected)
	tileset_texture.gui_input.connect(_on_tileset_input)
	passability_btn.pressed.connect(_on_passability_edit)
	
	# 加载示例图块集
	_load_sample_tilesets()

func _load_sample_tilesets():
	# 示例图块集数据
	tilesets = {
		0: {"name": "Overworld", "tile_count": 256},
		1: {"name": "Dungeon", "tile_count": 128},
		2: {"name": "Town", "tile_count": 192}
	}
	
	# 更新选择器
	tileset_selector.clear()
	for id in tilesets.keys():
		tileset_selector.add_item(tilesets[id].name, id)
	
	if tilesets.size() > 0:
		tileset_selector.select(0)
		_on_tileset_selected(0)

func _on_tileset_selected(index: int):
	current_tileset_id = tileset_selector.get_item_id(index)
	_load_tileset(current_tileset_id)

func _load_tileset(tileset_id: int):
	# TODO: 从数据库加载实际的图块集纹理
	# 这里使用一个占位纹理
	
	var tileset_info = tilesets.get(tileset_id, {})
	print("加载图块集: ", tileset_info.get("name", ""))
	
	# 更新显示区域大小
	_update_display_size()

func _update_display_size():
	if tileset_texture.texture:
		var tex_size = tileset_texture.texture.get_size()
		tileset_display.custom_minimum_size = tex_size
		tileset_texture.size = tex_size

func _on_tileset_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = tileset_texture.get_local_mouse_position()
			_select_tile_at(local_pos)

func _select_tile_at(local_pos: Vector2):
	if tileset_texture.texture == null:
		return
	
	var tex_size = tileset_texture.texture.get_size()
	if local_pos.x < 0 or local_pos.x >= tex_size.x or local_pos.y < 0 or local_pos.y >= tex_size.y:
		return
	
	var tile_x = int(local_pos.x / tile_size)
	var tile_y = int(local_pos.y / tile_size)
	
	var cols = int(tex_size.x / tile_size)
	selected_tile_id = tile_y * cols + tile_x + 1  # 图块ID从1开始，0表示空白
	
	# 更新选择框位置
	selection_overlay.position = Vector2(tile_x * tile_size, tile_y * tile_size)
	selection_overlay.size = Vector2(tile_size, tile_size)
	selection_overlay.visible = true
	
	# 更新标签
	tile_id_label.text = "图块: %d" % selected_tile_id
	
	tile_selected.emit(selected_tile_id)

func _on_passability_edit():
	print("编辑通行设置: ", selected_tile_id)
	# TODO: 打开通行设置对话框

# ===== 公共接口 =====

func set_tileset(tileset_id: int, texture: Texture2D, data: Dictionary):
	tileset_texture.texture = texture
	_update_display_size()
	
	# 选择对应的图块集
	for i in range(tileset_selector.item_count):
		if tileset_selector.get_item_id(i) == tileset_id:
			tileset_selector.select(i)
			break

func get_selected_tile() -> int:
	return selected_tile_id

func refresh():
	_load_tileset(current_tileset_id)
