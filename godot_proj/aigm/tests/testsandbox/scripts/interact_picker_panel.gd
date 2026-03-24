extends CanvasLayer
## 多交互目标选择面板：当角色按 [kbd]F[/kbd] 时附近可交互目标 >1，弹出列表供玩家选择。

@onready var _list: ItemList = $CenterContainer/PanelRoot/Margin/VBox/TargetsList
@onready var _btn_ok: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/OkButton
@onready var _btn_cancel: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/CancelButton
@onready var _hint: Label = $CenterContainer/PanelRoot/Margin/VBox/HintLabel
@onready var _center: Control = $CenterContainer
@onready var _panel_root: Control = $CenterContainer/PanelRoot

var _walker: NekomimiWalker
var _targets: Array[Dictionary] = []
var _follow_head_offset: Vector2 = Vector2(0.0, -92.0)
var _closing: bool = false


func _ready() -> void:
	add_to_group("interact_picker_panel")
	layer = 27
	follow_viewport_enabled = true
	follow_viewport_scale = 1.0
	visible = false
	_list.item_activated.connect(_on_item_activated)
	_btn_ok.pressed.connect(_activate_selected)
	_btn_cancel.pressed.connect(close)
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open_for_walker(walker: NekomimiWalker, targets: Array[Dictionary]) -> void:
	_walker = walker
	_targets = targets.duplicate()
	_list.clear()
	for t in _targets:
		_list.add_item(str(t.get("label", "交互")))
	visible = true
	set_process(true)
	_update_follow_position()
	if _list.item_count > 0:
		_list.select(0)
		_hint.text = "选择一个交互目标"
	else:
		_hint.text = "没有可交互目标"


func close_if_actor(walker: NekomimiWalker) -> void:
	if not visible:
		return
	if _walker != walker:
		return
	close()


func close() -> void:
	if _closing or is_queued_for_deletion():
		return
	_closing = true
	visible = false
	_targets.clear()
	_walker = null
	set_process(false)
	queue_free()


func _on_item_activated(_index: int) -> void:
	_activate_selected()


func _activate_selected() -> void:
	if _walker == null:
		close()
		return
	var sel: PackedInt32Array = _list.get_selected_items()
	if sel.is_empty():
		return
	var i: int = int(sel[0])
	if i < 0 or i >= _targets.size():
		return
	var target: Dictionary = _targets[i]
	var node: Node = target.get("node", null) as Node
	if node == null:
		_hint.text = "目标已失效"
		return
	var host: Node = get_tree().get_first_node_in_group("interaction_ui_host")
	if host == null:
		_hint.text = "交互 UI 未就绪"
		return
	var ok: bool = false
	var t: String = str(target.get("type", ""))
	if t == "shop":
		ok = host.has_method("open_shop_for_target") and bool(host.call("open_shop_for_target", _walker, node))
	elif t == "container":
		ok = host.has_method("open_container_for_target") and bool(host.call("open_container_for_target", _walker, node))
	if ok:
		close()
	else:
		_hint.text = "交互失败：目标可能不可用或不在范围"


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
