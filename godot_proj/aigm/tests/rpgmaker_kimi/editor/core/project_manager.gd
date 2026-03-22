class_name ProjectManager
extends Node

## 项目管理器
## 负责项目的创建、加载、保存等操作

signal project_created(project_path: String)
signal project_loaded(project_path: String)
signal project_saved(project_path: String)
signal project_closed()

const PROJECT_FILE = "project.rpgproject"
const DATA_DIR = "data"
const IMG_DIR = "img"
const AUDIO_DIR = "audio"
const MAPS_DIR = "data/maps"

var current_project: Dictionary = {}
var current_path: String = ""

func _ready():
	pass

# ===== 项目操作 =====

func create_project(project_path: String, project_name: String) -> bool:
	if not DirAccess.dir_exists_absolute(project_path):
		var err = DirAccess.make_dir_recursive_absolute(project_path)
		if err != OK:
			push_error("无法创建项目目录: " + project_path)
			return false
	
	# 创建标准目录结构
	_create_directory_structure(project_path)
	
	# 创建项目文件
	current_project = {
		"name": project_name,
		"version": "1.0.0",
		"engine_version": Engine.get_version_info(),
		"created_at": Time.get_datetime_string_from_system(),
		"modified_at": Time.get_datetime_string_from_system(),
		"settings": _default_project_settings()
	}
	
	current_path = project_path
	
	# 保存项目文件
	_save_project_file()
	
	# 创建默认数据库
	_create_default_database()
	
	# 创建初始地图
	_create_initial_map()
	
	project_created.emit(project_path)
	return true

func load_project(project_path: String) -> bool:
	var project_file = project_path.path_join(PROJECT_FILE)
	
	if not FileAccess.file_exists(project_file):
		push_error("项目文件不存在: " + project_file)
		return false
	
	var file = FileAccess.open(project_file, FileAccess.READ)
	if file == null:
		push_error("无法打开项目文件: " + project_file)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("项目文件解析失败")
		return false
	
	current_project = json.data
	current_path = project_path
	
	project_loaded.emit(project_path)
	return true

func save_project() -> bool:
	if current_path.is_empty():
		push_error("没有打开的项目")
		return false
	
	current_project["modified_at"] = Time.get_datetime_string_from_system()
	
	if not _save_project_file():
		return false
	
	project_saved.emit(current_path)
	return true

func close_project():
	current_project = {}
	current_path = ""
	project_closed.emit()

func _save_project_file() -> bool:
	var project_file = current_path.path_join(PROJECT_FILE)
	var file = FileAccess.open(project_file, FileAccess.WRITE)
	if file == null:
		push_error("无法写入项目文件")
		return false
	
	var json_string = JSON.stringify(current_project, "\t")
	file.store_string(json_string)
	file.close()
	return true

func _create_directory_structure(base_path: String):
	var dirs = [DATA_DIR, IMG_DIR, AUDIO_DIR, MAPS_DIR]
	for dir in dirs:
		DirAccess.make_dir_recursive_absolute(base_path.path_join(dir))
	
	# 创建子目录
	var img_subdirs = ["characters", "faces", "parallaxes", "tilesets", "titles", "animations", "battlers", "icons"]
	for dir in img_subdirs:
		DirAccess.make_dir_recursive_absolute(base_path.path_join(IMG_DIR).path_join(dir))
	
	var audio_subdirs = ["bgm", "bgs", "me", "se"]
	for dir in audio_subdirs:
		DirAccess.make_dir_recursive_absolute(base_path.path_join(AUDIO_DIR).path_join(dir))

func _create_default_database():
	# 创建默认数据库文件
	var db = DatabaseManager.new()
	add_child(db)
	db.create_default_database(current_path.path_join(DATA_DIR))
	remove_child(db)

func _create_initial_map():
	var map_manager = MapManager.new()
	add_child(map_manager)
	
	var map_data = {
		"id": 1,
		"name": "MAP001",
		"display_name": "初始地图",
		"width": 20,
		"height": 15,
		"tileset_id": 1,
		"layers": []
	}
	
	# 创建空白图层
	for i in range(3):
		var layer = {
			"name": "Layer %d" % i,
			"visible": true,
			"data": []
		}
		# 填充空白数据
		for y in range(map_data.height):
			var row = []
			for x in range(map_data.width):
				row.append(0)
			layer.data.append(row)
		map_data.layers.append(layer)
	
	map_manager.save_map(current_path.path_join(MAPS_DIR), map_data)
	remove_child(map_manager)

# ===== 项目设置 =====

func _default_project_settings() -> Dictionary:
	return {
		"tile_size": 32,
		"screen_width": 816,
		"screen_height": 624,
		"start_map_id": 1,
		"start_x": 0,
		"start_y": 0,
		"title": "未命名游戏",
		"window_color": "#000000"
	}

func get_setting(key: String, default_value = null):
	if current_project.has("settings"):
		var settings = current_project.settings
		if settings.has(key):
			return settings[key]
	return default_value

func set_setting(key: String, value):
	if not current_project.has("settings"):
		current_project["settings"] = {}
	current_project.settings[key] = value

# ===== 项目信息 =====

func get_project_name() -> String:
	return current_project.get("name", "")

func get_project_path() -> String:
	return current_path

func is_project_open() -> bool:
	return not current_path.is_empty()

func get_data_path() -> String:
	return current_path.path_join(DATA_DIR)

func get_img_path() -> String:
	return current_path.path_join(IMG_DIR)

func get_audio_path() -> String:
	return current_path.path_join(AUDIO_DIR)

func get_maps_path() -> String:
	return current_path.path_join(MAPS_DIR)
