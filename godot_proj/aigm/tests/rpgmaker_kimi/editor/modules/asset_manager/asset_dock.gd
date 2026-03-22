@tool
extends Panel

## 资源管理面板
## 显示项目中的图片、音频等资源

signal asset_selected(path: String, type: String)
signal asset_double_clicked(path: String)
signal import_requested()

@onready var category_tabs: TabBar = $VBoxContainer/CategoryTabs
@onready var import_btn: Button = $VBoxContainer/Toolbar/ImportBtn
@onready var refresh_btn: Button = $VBoxContainer/Toolbar/RefreshBtn
@onready var search_edit: LineEdit = $VBoxContainer/Toolbar/SearchEdit
@onready var asset_grid: ItemList = $VBoxContainer/AssetGrid

var current_category: String = "images"
var current_filter: String = ""

var categories: Dictionary = {
	0: "images",
	1: "audio",
	2: "animations",
	3: "scripts",
	4: "fonts"
}

var assets: Dictionary = {}

func _ready():
	# 连接信号
	category_tabs.tab_changed.connect(_on_category_changed)
	import_btn.pressed.connect(_on_import)
	refresh_btn.pressed.connect(_on_refresh)
	search_edit.text_changed.connect(_on_search)
	asset_grid.item_selected.connect(_on_asset_selected)
	asset_grid.item_activated.connect(_on_asset_activated)
	
	# 加载示例资源
	_load_sample_assets()
	_refresh_asset_grid()

func _load_sample_assets():
	assets = {
		"images": [
			{"name": "Actor1", "path": "img/faces/Actor1.png", "type": "image"},
			{"name": "Actor2", "path": "img/faces/Actor2.png", "type": "image"},
			{"name": "World_A1", "path": "img/tilesets/World_A1.png", "type": "image"},
			{"name": "Dungeon_A1", "path": "img/tilesets/Dungeon_A1.png", "type": "image"},
		],
		"audio": [
			{"name": "Town1", "path": "audio/bgm/Town1.ogg", "type": "audio"},
			{"name": "Battle1", "path": "audio/bgm/Battle1.ogg", "type": "audio"},
			{"name": "Cursor1", "path": "audio/se/Cursor1.ogg", "type": "audio"},
		],
		"animations": [
			{"name": "HitPhysical", "path": "img/animations/HitPhysical.png", "type": "animation"},
			{"name": "HitEffect", "path": "img/animations/HitEffect.png", "type": "animation"},
		],
		"scripts": [],
		"fonts": []
	}

func _refresh_asset_grid():
	asset_grid.clear()
	
	var category_assets = assets.get(current_category, [])
	
	for asset in category_assets:
		# 过滤
		if not current_filter.is_empty():
			if not current_filter.to_lower() in asset.name.to_lower():
				continue
		
		# 添加图标（使用默认图标）
		var icon = _get_icon_for_type(asset.type)
		asset_grid.add_item(asset.name, icon)
		asset_grid.set_item_metadata(asset_grid.item_count - 1, asset)

func _get_icon_for_type(type: String) -> Texture2D:
	match type:
		"image":
			return get_theme_icon("Image", "EditorIcons")
		"audio":
			return get_theme_icon("AudioStreamPlayer", "EditorIcons")
		"animation":
			return get_theme_icon("AnimatedSprite2D", "EditorIcons")
		_:
			return get_theme_icon("File", "EditorIcons")

func _on_category_changed(tab: int):
	if categories.has(tab):
		current_category = categories[tab]
		_refresh_asset_grid()

func _on_import():
	import_requested.emit()

func _on_refresh():
	_refresh_asset_grid()

func _on_search(text: String):
	current_filter = text
	_refresh_asset_grid()

func _on_asset_selected(index: int):
	var asset = asset_grid.get_item_metadata(index)
	if asset:
		asset_selected.emit(asset.path, asset.type)

func _on_asset_activated(index: int):
	var asset = asset_grid.get_item_metadata(index)
	if asset:
		asset_double_clicked.emit(asset.path)

# ===== 公共接口 =====

func add_asset(asset: Dictionary):
	var type = asset.get("type", "")
	var category = _get_category_for_type(type)
	
	if not assets.has(category):
		assets[category] = []
	
	assets[category].append(asset)
	
	if category == current_category:
		_refresh_asset_grid()

func remove_asset(path: String):
	for category in assets.keys():
		var list = assets[category]
		for i in range(list.size() - 1, -1, -1):
			if list[i].path == path:
				list.remove_at(i)
				if category == current_category:
					_refresh_asset_grid()
				return

func _get_category_for_type(type: String) -> String:
	match type:
		"image", "animation":
			return "images"
		"audio":
			return "audio"
		"script":
			return "scripts"
		"font":
			return "fonts"
		_:
			return "images"

func refresh():
	_refresh_asset_grid()

func set_assets(new_assets: Dictionary):
	assets = new_assets
	_refresh_asset_grid()
