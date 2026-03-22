extends SubViewport

## 地图视口
## 负责渲染地图、处理鼠标输入和显示网格

signal tile_clicked(pos: Vector2i, button: int)
signal tile_dragged(pos: Vector2i, button: int)
signal map_position_changed(pos: Vector2i)
signal event_clicked(event_id: int)

@onready var camera: Camera2D = $Camera2D
@onready var map_root: Node2D = $MapRoot
@onready var tile_layers: Node2D = $MapRoot/TileLayers
@onready var event_layer: Node2D = $MapRoot/EventLayer
@onready var grid_overlay: Node2D = $MapRoot/GridOverlay
@onready var selection_overlay: Node2D = $MapRoot/SelectionOverlay

var map_data: Dictionary = {}
var tileset_texture: Texture2D = null
var tileset_data: Dictionary = {}

var map_width: int = 0
var map_height: int = 0
var tile_size: int = 32

var current_layer: int = 0
var show_grid: bool = true:
	set(value):
		show_grid = value
		queue_redraw()
var show_events: bool = true:
	set(value):
		show_events = value
		_update_event_visibility()

var zoom_level: float = 1.0
var is_panning: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

func _ready():
	# 启用输入处理
	set_process_input(true)
	set_process(true)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var map_pos = _screen_to_map(get_mouse_position())
				if _is_valid_pos(map_pos):
					tile_clicked.emit(map_pos, event.button_index)
				
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				is_panning = true
				last_mouse_pos = get_mouse_position()
			else:
				if event.button_index == MOUSE_BUTTON_MIDDLE:
					is_panning = false
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_level = min(zoom_level * 1.1, 4.0)
			_update_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_level = max(zoom_level / 1.1, 0.25)
			_update_zoom()
	
	if event is InputEventMouseMotion:
		var map_pos = _screen_to_map(get_mouse_position())
		if _is_valid_pos(map_pos):
			map_position_changed.emit(map_pos)
		
		if is_panning:
			var delta = get_mouse_position() - last_mouse_pos
			camera.position -= delta / zoom_level
			last_mouse_pos = get_mouse_position()
		
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _is_valid_pos(map_pos):
				tile_dragged.emit(map_pos, MOUSE_BUTTON_LEFT)

func _process(delta):
	pass

func _draw():
	# 绘制网格
	if show_grid and map_width > 0 and map_height > 0:
		_draw_grid()

func _draw_grid():
	var color = Color(1, 1, 1, 0.3)
	var map_pixel_width = map_width * tile_size
	var map_pixel_height = map_height * tile_size
	
	# 垂直线
	for x in range(map_width + 1):
		var px = x * tile_size
		draw_line(Vector2(px, 0), Vector2(px, map_pixel_height), color)
	
	# 水平线
	for y in range(map_height + 1):
		var py = y * tile_size
		draw_line(Vector2(0, py), Vector2(map_pixel_width, py), color)

func _screen_to_map(screen_pos: Vector2) -> Vector2i:
	var local_pos = (screen_pos - size / 2.0) / zoom_level + camera.position
	return Vector2i(int(local_pos.x / tile_size), int(local_pos.y / tile_size))

func _map_to_world(map_pos: Vector2i) -> Vector2:
	return Vector2(map_pos.x * tile_size, map_pos.y * tile_size)

func _is_valid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < map_width and pos.y >= 0 and pos.y < map_height

func _update_zoom():
	camera.zoom = Vector2(zoom_level, zoom_level)

func _update_event_visibility():
	event_layer.visible = show_events

# ===== 地图操作 =====

func load_map(data: Dictionary):
	map_data = data
	map_width = data.get("width", 0)
	map_height = data.get("height", 0)
	
	# 清空现有图层
	for child in tile_layers.get_children():
		child.queue_free()
	
	# 创建图层
	var layer_count = 6  # RPG Maker 默认 6 层
	for i in range(layer_count):
		var layer = TileMapLayer.new()
		layer.name = "Layer_%d" % i
		tile_layers.add_child(layer)
		
		# 如果有图块集，设置图块集
		if tileset_texture:
			_setup_tileset(layer)
	
	# 加载地图数据
	_load_tile_data()
	
	# 加载事件
	_load_events()
	
	# 调整相机位置
	camera.position = Vector2(map_width * tile_size / 2, map_height * tile_size / 2)
	
	queue_redraw()

func _setup_tileset(layer: TileMapLayer):
	if tileset_texture == null:
		return
	
	var tile_set = TileSet.new()
	var atlas_source = TileSetAtlasSource.new()
	atlas_source.texture = tileset_texture
	atlas_source.texture_region_size = Vector2i(tile_size, tile_size)
	
	# 计算图块数量
	var tex_size = tileset_texture.get_size()
	var cols = tex_size.x / tile_size
	var rows = tex_size.y / tile_size
	
	# 添加图块
	for y in range(rows):
		for x in range(cols):
			atlas_source.create_tile(Vector2i(x, y))
	
	tile_set.add_source(atlas_source, 0)
	layer.tile_set = tile_set

func _load_tile_data():
	if not map_data.has("data"):
		return
	
	var data = map_data.data
	var layers = tile_layers.get_children()
	
	for layer_index in range(min(data.size(), layers.size())):
		var layer = layers[layer_index]
		var layer_data = data[layer_index]
		
		# 清空图层
		layer.clear()
		
		# 设置图块
		for y in range(map_height):
			for x in range(map_width):
				var tile_id = layer_data[y * map_width + x]
				if tile_id > 0:
					_set_tile_at(layer, x, y, tile_id)

func _set_tile_at(layer: TileMapLayer, x: int, y: int, tile_id: int):
	if tile_id <= 0:
		layer.erase_cell(Vector2i(x, y))
		return
	
	# 计算图块在图集上的位置
	if tileset_texture:
		var tex_size = tileset_texture.get_size()
		var cols = tex_size.x / tile_size
		
		var atlas_x = (tile_id - 1) % int(cols)
		var atlas_y = (tile_id - 1) / int(cols)
		
		layer.set_cell(Vector2i(x, y), 0, Vector2i(atlas_x, atlas_y))

func _load_events():
	# 清空现有事件
	for child in event_layer.get_children():
		child.queue_free()
	
	if not map_data.has("events"):
		return
	
	for event in map_data.events:
		if event == null:
			continue
		
		var event_node = _create_event_node(event)
		event_layer.add_child(event_node)

func _create_event_node(event: Dictionary) -> Node2D:
	var node = Node2D.new()
	node.name = "Event_%d" % event.id
	node.position = _map_to_world(Vector2i(event.x, event.y))
	
	# 添加事件图标
	var sprite = Sprite2D.new()
	# TODO: 加载事件图标
	node.add_child(sprite)
	
	# 添加标签
	var label = Label.new()
	label.text = event.get("name", "EV%03d" % event.id)
	label.position = Vector2(0, -20)
	node.add_child(label)
	
	return node

func clear_map():
	map_data = {}
	map_width = 0
	map_height = 0
	
	for child in tile_layers.get_children():
		child.queue_free()
	
	for child in event_layer.get_children():
		child.queue_free()
	
	queue_redraw()

# ===== 公共接口 =====

func set_tile(x: int, y: int, layer: int, tile_id: int):
	if layer < 0 or layer >= tile_layers.get_child_count():
		return
	
	var layer_node = tile_layers.get_child(layer)
	_set_tile_at(layer_node, x, y, tile_id)
	
	# 更新地图数据
	if map_data.has("data"):
		map_data.data[layer][y * map_width + x] = tile_id

func set_current_layer(layer: int):
	current_layer = layer

func set_tileset(texture: Texture2D, data: Dictionary):
	tileset_texture = texture
	tileset_data = data
	
	# 更新所有图层
	for layer in tile_layers.get_children():
		_setup_tileset(layer)

func set_zoom(zoom: float):
	zoom_level = zoom
	_update_zoom()

func get_map_data() -> Dictionary:
	return map_data

func refresh():
	queue_redraw()
	for layer in tile_layers.get_children():
		layer.queue_redraw()
