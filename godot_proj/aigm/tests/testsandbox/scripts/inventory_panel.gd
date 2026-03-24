extends CanvasLayer
## 背包面板：玩家按 [kbd]Q[/kbd] 打开并使用道具；NPC 也会复用该面板执行延时使用流程。

@onready var _title: Label = $CenterContainer/PanelRoot/Margin/VBox/TitleLabel
@onready var _list: ItemList = $CenterContainer/PanelRoot/Margin/VBox/ItemList
@onready var _hint: Label = $CenterContainer/PanelRoot/Margin/VBox/HintLabel
@onready var _btn_use: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/UseButton
@onready var _btn_close: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/CloseButton
@onready var _center: Control = $CenterContainer
@onready var _panel_root: Control = $CenterContainer/PanelRoot

var _walker: NekomimiWalker
var _session_actor_label: String = ""
var _item_ids: Array[String] = []
var _follow_head_offset: Vector2 = Vector2(0.0, -92.0)


func _ready() -> void:
	add_to_group("inventory_panel")
	layer = 24
	follow_viewport_enabled = true
	follow_viewport_scale = 1.0
	visible = false
	_list.fixed_icon_size = Vector2i(28, 28)
	_list.icon_mode = ItemList.ICON_MODE_LEFT
	_btn_use.pressed.connect(_on_use_pressed)
	_btn_close.pressed.connect(close)
	_list.item_activated.connect(_on_item_activated)
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_Q):
		close()
		get_viewport().set_input_as_handled()


func toggle_for_walker(walker: NekomimiWalker) -> void:
	if walker == null:
		return
	if visible and _walker == walker:
		close()
		return
	open_for_walker(walker)


func open_for_walker(walker: NekomimiWalker) -> void:
	_session_actor_label = ""
	open_session(walker, "")


func open_session(walker: NekomimiWalker, actor_label: String = "") -> bool:
	if walker == null:
		return false
	if _walker != null and is_instance_valid(_walker) and _walker.inventory_changed.is_connected(_on_inventory_changed):
		_walker.inventory_changed.disconnect(_on_inventory_changed)
	_walker = walker
	_session_actor_label = actor_label
	if _walker != null and not _walker.inventory_changed.is_connected(_on_inventory_changed):
		_walker.inventory_changed.connect(_on_inventory_changed)
	var who: String = actor_label if not actor_label.is_empty() else str(walker.name)
	_title.text = "背包（使用者：%s）" % who
	visible = true
	_refresh_list()
	set_process(true)
	_update_follow_position()
	return true


func close() -> void:
	visible = false
	if _walker != null and is_instance_valid(_walker) and _walker.inventory_changed.is_connected(_on_inventory_changed):
		_walker.inventory_changed.disconnect(_on_inventory_changed)
	_walker = null
	_session_actor_label = ""
	_item_ids.clear()
	set_process(false)


func close_if_actor(walker: NekomimiWalker) -> void:
	if not visible:
		return
	if _walker != walker:
		return
	close()


func _on_inventory_changed() -> void:
	if visible:
		_refresh_list()


func _process(_delta: float) -> void:
	if visible:
		_update_follow_position()


func _update_follow_position() -> void:
	if _walker == null or not is_instance_valid(_walker) or _center == null or _panel_root == null:
		return
	_center.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	var world_p: Vector2 = _walker.global_position
	var panel_sz: Vector2 = _panel_root.size
	_center.size = panel_sz
	var desired: Vector2 = world_p + _follow_head_offset - Vector2(panel_sz.x * 0.5, panel_sz.y)
	_center.position = desired


func _refresh_list() -> void:
	_list.clear()
	_item_ids.clear()
	if _walker == null:
		return
	for slot in _walker.inventory:
		if not (slot is Dictionary):
			continue
		var id: String = str((slot as Dictionary).get("id", ""))
		var cnt: int = int((slot as Dictionary).get("count", 0))
		if id.is_empty() or cnt <= 0:
			continue
		var def: Dictionary = ItemDB.get_def(id)
		var name_text: String = str(def.get("name", id)) if not def.is_empty() else id
		var sat: float = ItemDB.get_food_satiation(id, 0.0)
		var line: String = "%s × %d" % [name_text, cnt]
		if sat > 0.0:
			line += "  [饱食+%d]" % roundi(sat)
		var tex: Texture2D = ItemDB.get_icon_texture(id)
		if tex:
			_list.add_item(line, tex)
		else:
			_list.add_item(line)
		_item_ids.append(id)


func _on_use_pressed() -> void:
	_use_selected()


func _on_item_activated(_index: int) -> void:
	_use_selected()


func _use_selected() -> bool:
	if _walker == null:
		return false
	var sel: PackedInt32Array = _list.get_selected_items()
	if sel.is_empty():
		return false
	var i: int = int(sel[0])
	if i < 0 or i >= _item_ids.size():
		return false
	return npc_use_item_by_id(_walker, _item_ids[i])


func npc_use_item_by_id(walker: NekomimiWalker, item_id: String) -> bool:
	if walker == null or item_id.is_empty():
		return false
	if not walker.has_method("try_use_item_by_id"):
		return false
	var ok: bool = bool(walker.call("try_use_item_by_id", item_id))
	if ok:
		_hint.text = "已使用：%s" % item_id
	else:
		var sat: float = ItemDB.get_food_satiation(item_id, 0.0)
		_hint.text = "无法使用该道具" if sat <= 0.0 else "当前无法进食（可能已饱或动作中）"
	_refresh_list()
	return ok


func pick_best_food_item_id(walker: NekomimiWalker) -> String:
	if walker == null:
		return ""
	var best_id: String = ""
	var best_sat: float = 0.0
	for slot in walker.inventory:
		if not (slot is Dictionary):
			continue
		var sid: String = str((slot as Dictionary).get("id", ""))
		var sat: float = ItemDB.get_food_satiation(sid, 0.0)
		if sat > best_sat:
			best_sat = sat
			best_id = sid
	return best_id
