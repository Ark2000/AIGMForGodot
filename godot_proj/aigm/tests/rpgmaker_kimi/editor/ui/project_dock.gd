@tool
extends Panel

## 项目面板 - 显示地图列表和项目结构

signal map_selected(map_id: int)
signal map_double_clicked(map_id: int)
signal map_right_clicked(map_id: int, position: Vector2)

@onready var tree: Tree = $VBoxContainer/Tree
@onready var add_map_btn: Button = $VBoxContainer/Toolbar/AddMap
@onready var add_folder_btn: Button = $VBoxContainer/Toolbar/AddFolder
@onready var delete_btn: Button = $VBoxContainer/Toolbar/Delete
@onready var context_menu: PopupMenu = $ContextMenu

var root_item: TreeItem
var selected_map_id: int = -1

# 地图数据缓存
var map_data: Dictionary = {}

func _ready():
	# 设置列标题
	tree.set_column_title(0, "名称")
	tree.set_column_title(1, "ID")
	
	# 连接信号
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_activated)
	tree.item_mouse_selected.connect(_on_item_mouse_selected)
	tree.button_clicked.connect(_on_button_clicked)
	
	add_map_btn.pressed.connect(_on_add_map)
	add_folder_btn.pressed.connect(_on_add_folder)
	delete_btn.pressed.connect(_on_delete)
	
	context_menu.id_pressed.connect(_on_context_menu)
	
	# 初始化树
	_setup_tree()
	
	# 加载示例数据
	_load_sample_data()

func _setup_tree():
	tree.clear()
	root_item = tree.create_item()
	root_item.set_text(0, "项目")
	root_item.set_metadata(0, {"type": "root", "id": -1})

func _load_sample_data():
	# 示例地图数据
	var sample_maps = [
		{"id": 1, "name": "初始村庄", "type": "map", "parent": -1},
		{"id": 2, "name": "村庄广场", "type": "map", "parent": 1},
		{"id": 3, "name": "道具店", "type": "map", "parent": 1},
		{"id": 4, "name": "武器店", "type": "map", "parent": 1},
		{"id": 5, "name": "草原", "type": "map", "parent": -1},
		{"id": 6, "name": "森林", "type": "map", "parent": -1},
		{"id": 7, "name": "洞穴", "type": "map", "parent": -1},
	]
	
	for map in sample_maps:
		_add_map_to_tree(map)

func _add_map_to_tree(map_info: Dictionary) -> TreeItem:
	var parent = root_item
	
	# 查找父项
	if map_info.parent > 0:
		parent = _find_item_by_id(map_info.parent)
		if parent == null:
			parent = root_item
	
	var item = tree.create_item(parent)
	item.set_text(0, map_info.name)
	item.set_text(1, str(map_info.id))
	item.set_metadata(0, {"type": map_info.type, "id": map_info.id})
	
	# 添加图标
	if map_info.type == "folder":
		item.set_icon(0, get_theme_icon("Folder", "EditorIcons"))
	else:
		item.set_icon(0, get_theme_icon("WorldEnvironment", "EditorIcons"))
	
	map_data[map_info.id] = map_info
	
	return item

func _find_item_by_id(id: int) -> TreeItem:
	return _find_item_recursive(root_item, id)

func _find_item_recursive(item: TreeItem, id: int) -> TreeItem:
	if item == null:
		return null
	
	var meta = item.get_metadata(0)
	if meta and meta.has("id") and meta.id == id:
		return item
	
	var child = item.get_first_child()
	while child:
		var result = _find_item_recursive(child, id)
		if result:
			return result
		child = child.get_next()
	
	return null

func _on_item_selected():
	var selected = tree.get_selected()
	if selected:
		var meta = selected.get_metadata(0)
		if meta and meta.has("id"):
			selected_map_id = meta.id
			map_selected.emit(selected_map_id)

func _on_item_activated():
	var selected = tree.get_selected()
	if selected:
		var meta = selected.get_metadata(0)
		if meta and meta.has("id"):
			map_double_clicked.emit(meta.id)

func _on_item_mouse_selected(position: Vector2, mouse_button_index: int):
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var selected = tree.get_selected()
		if selected:
			var meta = selected.get_metadata(0)
			if meta and meta.has("id"):
				context_menu.position = get_global_mouse_position()
				context_menu.popup()
				map_right_clicked.emit(meta.id, position)

func _on_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int):
	pass

func _on_add_map():
	print("添加新地图")
	# 发送信号让主编辑器打开对话框
	# 这里我们使用一个间接的方式
	var main_editor = get_tree().get_root().get_node_or_null("Editor")
	if main_editor and main_editor.has_method("show_new_map_dialog"):
		main_editor.show_new_map_dialog()

func _on_add_folder():
	print("添加新文件夹")
	# TODO: 创建文件夹

func _on_delete():
	var selected = tree.get_selected()
	if selected:
		var meta = selected.get_metadata(0)
		if meta and meta.has("id"):
			print("删除: ", meta.id)
			# TODO: 删除确认对话框

func _on_context_menu(id: int):
	match id:
		0: # 编辑
			_on_item_activated()
		1: # 复制
			print("复制地图")
		2: # 粘贴
			print("粘贴地图")
		4: # 重命名
			var selected = tree.get_selected()
			if selected:
				tree.edit_selected(true)
		5: # 删除
			_on_delete()

# 公共接口

func add_map(map_info: Dictionary):
	_add_map_to_tree(map_info)

func remove_map(map_id: int):
	var item = _find_item_by_id(map_id)
	if item:
		item.free()
		map_data.erase(map_id)

func select_map(map_id: int):
	var item = _find_item_by_id(map_id)
	if item:
		item.select(0)

func get_selected_map_id() -> int:
	return selected_map_id

func get_map_data(map_id: int) -> Dictionary:
	if map_data.has(map_id):
		return map_data[map_id]
	return {}

func clear():
	_setup_tree()
	map_data.clear()
