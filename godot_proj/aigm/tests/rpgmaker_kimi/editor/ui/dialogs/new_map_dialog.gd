extends Window

## 新建地图对话框

signal map_created(map_data: Dictionary)

@onready var name_edit: LineEdit = $VBoxContainer/GridContainer/NameEdit
@onready var display_name_edit: LineEdit = $VBoxContainer/GridContainer/DisplayNameEdit
@onready var width_spin: SpinBox = $VBoxContainer/GridContainer/WidthSpin
@onready var height_spin: SpinBox = $VBoxContainer/GridContainer/HeightSpin
@onready var tileset_selector: OptionButton = $VBoxContainer/GridContainer/TilesetSelector
@onready var ok_btn: Button = $VBoxContainer/ButtonBar/OkBtn
@onready var cancel_btn: Button = $VBoxContainer/ButtonBar/CancelBtn

var tilesets: Dictionary = {}

func _ready():
	# 连接信号
	close_requested.connect(_on_close)
	ok_btn.pressed.connect(_on_ok)
	cancel_btn.pressed.connect(_on_cancel)
	
	# 加载图块集列表
	_load_tilesets()

func _load_tilesets():
	# 这里应该从数据库加载图块集
	tilesets = {
		1: "Overworld",
		2: "Dungeon",
		3: "Town"
	}
	
	tileset_selector.clear()
	for id in tilesets.keys():
		tileset_selector.add_item(tilesets[id], id)
	
	if tileset_selector.item_count > 0:
		tileset_selector.select(0)

func show_dialog():
	# 生成默认地图名称
	var timestamp = Time.get_time_string_from_system().replace(":", "")
	name_edit.text = "MAP%s" % timestamp
	display_name_edit.text = ""
	
	show()

func _on_ok():
	var map_name = name_edit.text.strip_edges()
	
	if map_name.is_empty():
		_show_error("请输入地图名称")
		return
	
	var map_data = {
		"name": map_name,
		"display_name": display_name_edit.text,
		"width": int(width_spin.value),
		"height": int(height_spin.value),
		"tileset_id": tileset_selector.get_selected_id()
	}
	
	map_created.emit(map_data)
	hide()

func _on_cancel():
	hide()

func _on_close():
	hide()

func _show_error(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "错误"
	dialog.dialog_text = message
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
