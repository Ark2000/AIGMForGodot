extends Window

## 数据库编辑器
## 管理游戏中的所有数据：角色、职业、物品、技能等

signal database_saved()

@onready var tab_container: TabContainer = $VBoxContainer/TabContainer
@onready var apply_btn: Button = $VBoxContainer/ButtonBar/ApplyBtn
@onready var ok_btn: Button = $VBoxContainer/ButtonBar/OkBtn
@onready var cancel_btn: Button = $VBoxContainer/ButtonBar/CancelBtn

# 角色编辑器
@onready var actor_list: ItemList = $VBoxContainer/TabContainer/角色/ActorList
@onready var actor_name_edit: LineEdit = $VBoxContainer/TabContainer/角色/ActorEditor/BasicInfo/NameEdit
@onready var actor_class_selector: OptionButton = $VBoxContainer/TabContainer/角色/ActorEditor/BasicInfo/ClassSelector
@onready var actor_initial_level: SpinBox = $VBoxContainer/TabContainer/角色/ActorEditor/BasicInfo/InitialLevelSpin
@onready var actor_max_level: SpinBox = $VBoxContainer/TabContainer/角色/ActorEditor/BasicInfo/MaxLevelSpin

var database_manager: DatabaseManager
var current_actor_id: int = 0

func _ready():
	# 连接信号
	close_requested.connect(_on_close)
	apply_btn.pressed.connect(_on_apply)
	ok_btn.pressed.connect(_on_ok)
	cancel_btn.pressed.connect(_on_cancel)
	
	actor_list.item_selected.connect(_on_actor_selected)
	actor_name_edit.text_changed.connect(_on_actor_name_changed)
	
	# 隐藏窗口
	hide()

func initialize(db_manager: DatabaseManager):
	database_manager = db_manager
	_load_data()

func _load_data():
	_load_actors()
	_load_classes()

func _load_actors():
	actor_list.clear()
	
	var actors = database_manager.get_category_list("actors")
	for i in range(1, actors.size()):
		var actor = actors[i]
		if actor and actor.has("name"):
			actor_list.add_item("[%04d] %s" % [i, actor.name])
			actor_list.set_item_metadata(actor_list.item_count - 1, i)

func _load_classes():
	actor_class_selector.clear()
	
	var classes = database_manager.get_category_list("classes")
	for i in range(1, classes.size()):
		var class_data = classes[i]
		if class_data and class_data.has("name"):
			actor_class_selector.add_item(class_data.name, i)

func show_editor():
	_load_data()
	show()

func _on_close():
	hide()

func _on_apply():
	_save_current_data()
	database_manager.save_database()
	database_saved.emit()

func _on_ok():
	_save_current_data()
	database_manager.save_database()
	database_saved.emit()
	hide()

func _on_cancel():
	hide()

# ===== 角色编辑 =====

func _on_actor_selected(index: int):
	_save_current_actor()
	
	var actor_id = actor_list.get_item_metadata(index)
	current_actor_id = actor_id
	
	var actor = database_manager.get_data("actors", actor_id)
	if actor.is_empty():
		return
	
	actor_name_edit.text = actor.get("name", "")
	actor_initial_level.value = actor.get("initial_level", 1)
	actor_max_level.value = actor.get("max_level", 99)
	
	var class_id = actor.get("class_id", 1)
	for i in range(actor_class_selector.item_count):
		if actor_class_selector.get_item_id(i) == class_id:
			actor_class_selector.select(i)
			break

func _on_actor_name_changed(text: String):
	var selected_items = actor_list.get_selected_items()
	if selected_items.size() > 0:
		var index = selected_items[0]
		var actor_id = actor_list.get_item_metadata(index)
		actor_list.set_item_text(index, "[%04d] %s" % [actor_id, text])

func _save_current_actor():
	if current_actor_id <= 0:
		return
	
	var actor = database_manager.get_data("actors", current_actor_id)
	if actor.is_empty():
		return
	
	actor.name = actor_name_edit.text
	actor.initial_level = int(actor_initial_level.value)
	actor.max_level = int(actor_max_level.value)
	actor.class_id = actor_class_selector.get_selected_id()
	
	database_manager.set_data("actors", current_actor_id, actor)

func _save_current_data():
	_save_current_actor()
	# TODO: 保存其他类别的数据
