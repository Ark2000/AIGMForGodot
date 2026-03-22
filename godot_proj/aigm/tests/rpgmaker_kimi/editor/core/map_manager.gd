class_name MapManager
extends Node

## 地图管理器
## 负责地图的创建、加载、保存和渲染

signal map_loaded(map_id: int)
signal map_saved(map_id: int)
signal map_created(map_id: int)
signal map_modified(map_id: int)

var maps: Dictionary = {}
var current_map_id: int = -1
var maps_path: String = ""

func _ready():
	pass

# ===== 地图操作 =====

func load_maps(path: String):
	maps_path = path
	maps = {}
	
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and file_name.begins_with("Map"):
				var map_id = _extract_map_id(file_name)
				if map_id > 0:
					_load_map_file(map_id)
			file_name = dir.get_next()
		dir.list_dir_end()

func _extract_map_id(file_name: String) -> int:
	# Map001.json -> 1
	var num_str = file_name.replace("Map", "").replace(".json", "")
	return num_str.to_int()

func _load_map_file(map_id: int) -> bool:
	var file_path = _get_map_file_path(map_id)
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return false
	
	maps[map_id] = json.data
	return true

func save_map(path: String, map_data: Dictionary) -> bool:
	var file_path = path.path_join("Map%03d.json" % map_data.id)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	
	var json_string = JSON.stringify(map_data, "\t")
	file.store_string(json_string)
	file.close()
	
	maps[map_data.id] = map_data
	map_saved.emit(map_data.id)
	return true

func create_map(width: int, height: int, tileset_id: int = 1) -> int:
	var map_id = _get_next_map_id()
	
	var map_data = {
		"id": map_id,
		"name": "MAP%03d" % map_id,
		"display_name": "",
		"note": "",
		"width": width,
		"height": height,
		"x": 0,
		"y": 0,
		"scroll_type": 0,
		"specify_battleback": false,
		"battleback1_name": "",
		"battleback2_name": "",
		"autoplay_bgm": false,
		"bgm": {"name": "", "pan": 0, "pitch": 100, "volume": 90},
		"autoplay_bgs": false,
		"bgs": {"name": "", "pan": 0, "pitch": 100, "volume": 90},
		"disable_dashing": false,
		"encounter_list": [],
		"encounter_step": 30,
		"parallax_name": "",
		"parallax_loop_x": false,
		"parallax_loop_y": false,
		"parallax_sx": 0,
		"parallax_sy": 0,
		"parallax_show": false,
		"tileset_id": tileset_id,
		"data": _create_empty_map_data(width, height),
		"events": []
	}
	
	maps[map_id] = map_data
	map_created.emit(map_id)
	return map_id

func _create_empty_map_data(width: int, height: int) -> Array:
	# RPG Maker 使用三层图块 + 阴影 + 区域ID
	var layers = 6
	var data = []
	
	for layer in range(layers):
		var layer_data = []
		for y in range(height):
			for x in range(width):
				layer_data.append(0)
		data.append(layer_data)
	
	return data

func delete_map(map_id: int) -> bool:
	if maps.has(map_id):
		var file_path = _get_map_file_path(map_id)
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
		maps.erase(map_id)
		return true
	return false

func _get_next_map_id() -> int:
	var max_id = 0
	for id in maps.keys():
		if id > max_id:
			max_id = id
	return max_id + 1

func _get_map_file_path(map_id: int) -> String:
	return maps_path.path_join("Map%03d.json" % map_id)

# ===== 地图数据操作 =====

func get_map(map_id: int) -> Dictionary:
	if maps.has(map_id):
		return maps[map_id]
	return {}

func get_current_map() -> Dictionary:
	if current_map_id > 0 and maps.has(current_map_id):
		return maps[current_map_id]
	return {}

func set_current_map(map_id: int) -> bool:
	if maps.has(map_id):
		current_map_id = map_id
		map_loaded.emit(map_id)
		return true
	return false

func get_tile_data(map_id: int, layer: int, x: int, y: int) -> int:
	if not maps.has(map_id):
		return 0
	
	var map = maps[map_id]
	if not map.has("data"):
		return 0
	
	var width = map.width
	var height = map.height
	
	if x < 0 or x >= width or y < 0 or y >= height:
		return 0
	
	var layer_data = map.data[layer]
	return layer_data[y * width + x]

func set_tile_data(map_id: int, layer: int, x: int, y: int, tile_id: int):
	if not maps.has(map_id):
		return
	
	var map = maps[map_id]
	if not map.has("data"):
		return
	
	var width = map.width
	var height = map.height
	
	if x < 0 or x >= width or y < 0 or y >= height:
		return
	
	map.data[layer][y * width + x] = tile_id
	map_modified.emit(map_id)

# ===== 地图列表 =====

func get_map_list() -> Array:
	var list = []
	for map_id in maps.keys():
		var map = maps[map_id]
		list.append({
			"id": map_id,
			"name": map.get("name", ""),
			"display_name": map.get("display_name", ""),
			"width": map.get("width", 0),
			"height": map.get("height", 0)
		})
	return list

func get_map_info(map_id: int) -> Dictionary:
	if maps.has(map_id):
		var map = maps[map_id]
		return {
			"id": map_id,
			"name": map.get("name", ""),
			"display_name": map.get("display_name", ""),
			"width": map.get("width", 0),
			"height": map.get("height", 0),
			"tileset_id": map.get("tileset_id", 1)
		}
	return {}

# ===== 事件操作 =====

func add_event(map_id: int, event_data: Dictionary) -> int:
	if not maps.has(map_id):
		return -1
	
	var map = maps[map_id]
	if not map.has("events"):
		map.events = []
	
	var event_id = map.events.size()
	event_data["id"] = event_id
	map.events.append(event_data)
	map_modified.emit(map_id)
	
	return event_id

func get_event(map_id: int, event_id: int) -> Dictionary:
	if not maps.has(map_id):
		return {}
	
	var map = maps[map_id]
	if not map.has("events"):
		return {}
	
	if event_id >= 0 and event_id < map.events.size():
		return map.events[event_id]
	return {}

func update_event(map_id: int, event_id: int, event_data: Dictionary):
	if not maps.has(map_id):
		return
	
	var map = maps[map_id]
	if not map.has("events"):
		return
	
	if event_id >= 0 and event_id < map.events.size():
		map.events[event_id] = event_data
		map_modified.emit(map_id)

func delete_event(map_id: int, event_id: int) -> bool:
	if not maps.has(map_id):
		return false
	
	var map = maps[map_id]
	if not map.has("events"):
		return false
	
	if event_id >= 0 and event_id < map.events.size():
		map.events[event_id] = null
		map_modified.emit(map_id)
		return true
	return false
