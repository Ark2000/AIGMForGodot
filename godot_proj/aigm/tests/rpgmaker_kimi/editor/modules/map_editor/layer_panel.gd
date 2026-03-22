@tool
extends Panel

## 图层面板
## 管理地图图层，支持选择、显示/隐藏、调整不透明度

signal layer_selected(layer_index: int)
signal layer_visibility_changed(layer_index: int, visible: bool)
signal layer_opacity_changed(layer_index: int, opacity: float)

@onready var layer_list: ItemList = $VBoxContainer/LayerList
@onready var add_btn: Button = $VBoxContainer/Toolbar/AddLayer
@onready var delete_btn: Button = $VBoxContainer/Toolbar/DeleteLayer
@onready var move_up_btn: Button = $VBoxContainer/Toolbar/MoveUp
@onready var move_down_btn: Button = $VBoxContainer/Toolbar/MoveDown
@onready var visibility_toggle: CheckButton = $VBoxContainer/BottomBar/VisibilityToggle
@onready var opacity_slider: HSlider = $VBoxContainer/BottomBar/OpacitySlider

var layers: Array = []
var current_layer_index: int = 0

func _ready():
	# 连接信号
	layer_list.item_selected.connect(_on_layer_selected)
	add_btn.pressed.connect(_on_add_layer)
	delete_btn.pressed.connect(_on_delete_layer)
	move_up_btn.pressed.connect(_on_move_up)
	move_down_btn.pressed.connect(_on_move_down)
	visibility_toggle.toggled.connect(_on_visibility_toggled)
	opacity_slider.value_changed.connect(_on_opacity_changed)
	
	# 初始化默认图层
	_setup_default_layers()

func _setup_default_layers():
	layers = [
		{"name": "阴影", "visible": true, "opacity": 1.0},
		{"name": "区域", "visible": true, "opacity": 1.0},
		{"name": "上层", "visible": true, "opacity": 1.0},
		{"name": "中层B", "visible": true, "opacity": 1.0},
		{"name": "中层A", "visible": true, "opacity": 1.0},
		{"name": "下层", "visible": true, "opacity": 1.0},
	]
	_refresh_layer_list()
	
	# 选择第一个图层
	if layers.size() > 0:
		layer_list.select(0)
		_on_layer_selected(0)

func _refresh_layer_list():
	layer_list.clear()
	
	# 从下往上显示（RPG Maker风格）
	for i in range(layers.size() - 1, -1, -1):
		var layer = layers[i]
		var icon = get_theme_icon("GuiVisibilityVisible", "EditorIcons") if layer.visible else get_theme_icon("GuiVisibilityHidden", "EditorIcons")
		layer_list.add_item(layer.name, icon)
		layer_list.set_item_metadata(layer_list.item_count - 1, i)

func _on_layer_selected(index: int):
	var layer_index = layer_list.get_item_metadata(index)
	current_layer_index = layer_index
	
	var layer = layers[layer_index]
	visibility_toggle.button_pressed = layer.visible
	opacity_slider.value = layer.opacity * 255
	
	layer_selected.emit(layer_index)

func _on_add_layer():
	var new_layer = {
		"name": "新图层 %d" % (layers.size() + 1),
		"visible": true,
		"opacity": 1.0
	}
	layers.append(new_layer)
	_refresh_layer_list()

func _on_delete_layer():
	if layers.size() <= 1:
		return
	
	var selected_items = layer_list.get_selected_items()
	if selected_items.size() > 0:
		var list_index = selected_items[0]
		var layer_index = layer_list.get_item_metadata(list_index)
		layers.remove_at(layer_index)
		_refresh_layer_list()
		
		# 选择新的图层
		if layers.size() > 0:
			var new_index = min(layer_index, layers.size() - 1)
			layer_list.select(layers.size() - 1 - new_index)
			_on_layer_selected(layers.size() - 1 - new_index)

func _on_move_up():
	var selected_items = layer_list.get_selected_items()
	if selected_items.size() > 0:
		var list_index = selected_items[0]
		var layer_index = layer_list.get_item_metadata(list_index)
		
		if layer_index < layers.size() - 1:
			var temp = layers[layer_index]
			layers[layer_index] = layers[layer_index + 1]
			layers[layer_index + 1] = temp
			_refresh_layer_list()
			layer_list.select(list_index - 1)
			layer_selected.emit(layer_index + 1)

func _on_move_down():
	var selected_items = layer_list.get_selected_items()
	if selected_items.size() > 0:
		var list_index = selected_items[0]
		var layer_index = layer_list.get_item_metadata(list_index)
		
		if layer_index > 0:
			var temp = layers[layer_index]
			layers[layer_index] = layers[layer_index - 1]
			layers[layer_index - 1] = temp
			_refresh_layer_list()
			layer_list.select(list_index + 1)
			layer_selected.emit(layer_index - 1)

func _on_visibility_toggled(visible: bool):
	var selected_items = layer_list.get_selected_items()
	if selected_items.size() > 0:
		var list_index = selected_items[0]
		var layer_index = layer_list.get_item_metadata(list_index)
		
		layers[layer_index].visible = visible
		_refresh_layer_list()
		layer_list.select(list_index)
		
		layer_visibility_changed.emit(layer_index, visible)

func _on_opacity_changed(value: float):
	var selected_items = layer_list.get_selected_items()
	if selected_items.size() > 0:
		var list_index = selected_items[0]
		var layer_index = layer_list.get_item_metadata(list_index)
		
		var opacity = value / 255.0
		layers[layer_index].opacity = opacity
		
		layer_opacity_changed.emit(layer_index, opacity)

# ===== 公共接口 =====

func set_layers(new_layers: Array):
	layers = new_layers
	_refresh_layer_list()

func get_current_layer() -> int:
	return current_layer_index

func select_layer(index: int):
	if index >= 0 and index < layers.size():
		current_layer_index = index
		layer_list.select(layers.size() - 1 - index)
		_on_layer_selected(layers.size() - 1 - index)

func set_layer_visibility(index: int, visible: bool):
	if index >= 0 and index < layers.size():
		layers[index].visible = visible
		_refresh_layer_list()
