class_name AssetManager
extends Node

## 资源管理器
## 负责图片、音频等资源的导入、预览和管理

signal asset_imported(path: String, type: String)
signal asset_deleted(path: String)
signal asset_preview_ready(path: String, texture: Texture2D)

const SUPPORTED_IMAGE_FORMATS = ["png", "jpg", "jpeg", "webp", "bmp"]
const SUPPORTED_AUDIO_FORMATS = ["ogg", "mp3", "wav"]

var project_path: String = ""
var cache: Dictionary = {}

func _ready():
	pass

# ===== 资源扫描 =====

func scan_project_assets(path: String):
	project_path = path
	cache = {}
	
	_scan_directory(path.path_join("img"), "image")
	_scan_directory(path.path_join("audio"), "audio")

func _scan_directory(dir_path: String, type: String):
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			_scan_directory(full_path, type)
		else:
			var ext = file_name.get_extension().to_lower()
			if type == "image" and ext in SUPPORTED_IMAGE_FORMATS:
				_add_to_cache(full_path, "image")
			elif type == "audio" and ext in SUPPORTED_AUDIO_FORMATS:
				_add_to_cache(full_path, "audio")
		file_name = dir.get_next()
	dir.list_dir_end()

func _add_to_cache(path: String, type: String):
	var category = path.get_base_dir().get_file()
	if not cache.has(category):
		cache[category] = []
	
	cache[category].append({
		"path": path,
		"name": path.get_file().get_basename(),
		"type": type,
		"extension": path.get_extension()
	})

# ===== 资源导入 =====

func import_image(source_path: String, target_category: String) -> bool:
	var file_name = source_path.get_file()
	var target_path = project_path.path_join("img").path_join(target_category).path_join(file_name)
	
	var err = DirAccess.copy_absolute(source_path, target_path)
	if err == OK:
		_add_to_cache(target_path, "image")
		asset_imported.emit(target_path, "image")
		return true
	return false

func import_audio(source_path: String, target_category: String) -> bool:
	var file_name = source_path.get_file()
	var target_path = project_path.path_join("audio").path_join(target_category).path_join(file_name)
	
	var err = DirAccess.copy_absolute(source_path, target_path)
	if err == OK:
		_add_to_cache(target_path, "audio")
		asset_imported.emit(target_path, "audio")
		return true
	return false

# ===== 资源删除 =====

func delete_asset(path: String) -> bool:
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(path)
		if err == OK:
			_remove_from_cache(path)
			asset_deleted.emit(path)
			return true
	return false

func _remove_from_cache(path: String):
	for category in cache.keys():
		var items = cache[category]
		for i in range(items.size() - 1, -1, -1):
			if items[i].path == path:
				items.remove_at(i)

# ===== 资源加载 =====

func load_image(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	
	var image = Image.new()
	var err = image.load(path)
	if err != OK:
		return null
	
	var texture = ImageTexture.create_from_image(image)
	return texture

func load_tileset_image(path: String, tile_size: int = 32) -> Texture2D:
	return load_image(path)

# ===== 资源查询 =====

func get_assets_by_category(category: String) -> Array:
	if cache.has(category):
		return cache[category]
	return []

func get_all_categories() -> Array:
	return cache.keys()

func get_asset_info(path: String) -> Dictionary:
	for category in cache.keys():
		for asset in cache[category]:
			if asset.path == path:
				return asset
	return {}

func asset_exists(path: String) -> bool:
	return FileAccess.file_exists(path)

# ===== 预览 =====

func create_preview(path: String, max_size: Vector2i = Vector2i(64, 64)) -> Texture2D:
	var ext = path.get_extension().to_lower()
	
	if ext in SUPPORTED_IMAGE_FORMATS:
		return _create_image_preview(path, max_size)
	elif ext in SUPPORTED_AUDIO_FORMATS:
		return _create_audio_preview(path)
	
	return null

func _create_image_preview(path: String, max_size: Vector2i) -> Texture2D:
	var image = Image.new()
	var err = image.load(path)
	if err != OK:
		return null
	
	# 缩放图片
	var size = image.get_size()
	if size.x > max_size.x or size.y > max_size.y:
		var scale = min(float(max_size.x) / size.x, float(max_size.y) / size.y)
		image.resize(int(size.x * scale), int(size.y * scale), Image.INTERPOLATE_BILINEAR)
	
	return ImageTexture.create_from_image(image)

func _create_audio_preview(path: String) -> Texture2D:
	# 返回音频图标
	# 可以加载一个预设的音频图标
	return null

# ===== 路径工具 =====

func get_image_path(file_name: String, subfolder: String = "") -> String:
	if subfolder.is_empty():
		return project_path.path_join("img").path_join(file_name)
	return project_path.path_join("img").path_join(subfolder).path_join(file_name)

func get_audio_path(file_name: String, subfolder: String = "") -> String:
	if subfolder.is_empty():
		return project_path.path_join("audio").path_join(file_name)
	return project_path.path_join("audio").path_join(subfolder).path_join(file_name)

func get_relative_path(absolute_path: String) -> String:
	return absolute_path.replace(project_path, "")
