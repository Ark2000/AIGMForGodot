extends CanvasLayer
## 摄像机跟随目标 + 是否用户操控当前跟踪角色（与 [WorldSandbox] 协调）。
## 勾选为「开」时**会记住**：之后只要在下拉里切换「跟随某角色」，会自动操控**当前镜头对准的那名角色**。

@export var spectator_camera_path: NodePath = ^"../SpectatorCamera"

var _cam: Camera2D
var _syncing := false
## 为真表示「用户希望操控对象始终跟镜头走」；切换跟随目标时会自动 [method WorldSandbox.set_controlled_character]。
var _control_follows_camera: bool = false

const _ID_AUTO := 9000
const _ID_FREE := 9001
const _ID_CHAR_BASE := 100


func _ready() -> void:
	add_to_group("camera_mode_menu")
	layer = 18
	_cam = get_node_or_null(spectator_camera_path) as Camera2D
	var opt: OptionButton = $Panel/Margin/VBox/ModeOption
	opt.item_selected.connect(_on_item_selected)
	var cb: CheckBox = $Panel/Margin/VBox/ControlUserCheck
	cb.toggled.connect(_on_control_toggled)
	call_deferred("_rebuild_items")


func refresh_from_camera() -> void:
	_rebuild_items()


func _world() -> Node:
	return get_parent()


func _rebuild_items() -> void:
	if _cam == null:
		_cam = get_tree().get_first_node_in_group("spectator_camera") as Camera2D
	var opt: OptionButton = $Panel/Margin/VBox/ModeOption
	opt.clear()
	var ys: Node2D = get_parent().get_node_or_null("YSort") as Node2D
	var i := 0
	if ys != null:
		for c in ys.get_children():
			if c is NekomimiWalker:
				var w: NekomimiWalker = c
				if w.is_alive():
					opt.add_item("跟随：%s" % w.name, _ID_CHAR_BASE + i)
					i += 1
	opt.add_item("自动轮播（全员）", _ID_AUTO)
	opt.add_item("自由视角（右键拖 / 滚轮）", _ID_FREE)
	var sel_id := _ID_CHAR_BASE
	if _cam != null and _cam.has_method("get_menu_selection_id"):
		sel_id = _cam.get_menu_selection_id()
		if sel_id == _ID_AUTO or sel_id == _ID_FREE:
			_control_follows_camera = false
	opt.set_block_signals(true)
	var found_idx := -1
	for j in range(opt.get_item_count()):
		if opt.get_item_id(j) == sel_id:
			found_idx = j
			break
	if found_idx >= 0:
		opt.select(found_idx)
	else:
		opt.select(0)
	opt.set_block_signals(false)
	_sync_control_checkbox()


func _sync_control_checkbox() -> void:
	var cb: CheckBox = $Panel/Margin/VBox/ControlUserCheck
	_syncing = true
	cb.button_pressed = _control_follows_camera
	_syncing = false


func _on_item_selected(_index: int) -> void:
	if _cam == null:
		return
	var opt: OptionButton = $Panel/Margin/VBox/ModeOption
	var id := opt.get_item_id(opt.selected)
	var world: Node = _world()
	if id == _ID_AUTO:
		_cam.set_mode_auto_cycle()
	elif id == _ID_FREE:
		_cam.set_mode_free()
	if id == _ID_AUTO or id == _ID_FREE:
		# 自动轮播/自由视角下无法对应「单一跟镜角色」，关闭跟镜操控并收回权限
		_control_follows_camera = false
		if world != null and world.has_method("set_controlled_character"):
			world.set_controlled_character(null)
		_sync_control_checkbox()
		return
	if id >= _ID_CHAR_BASE:
		_cam.set_mode_follow_character_by_index(id - _ID_CHAR_BASE)
	if _control_follows_camera:
		call_deferred("_apply_control_to_current_tracked")


func _apply_control_to_current_tracked() -> void:
	if not _control_follows_camera:
		return
	var world: Node = _world()
	if world == null or not world.has_method("set_controlled_character"):
		return
	if _cam == null or not _cam.has_method("get_current_follow_target"):
		return
	var tracked: NekomimiWalker = _cam.get_current_follow_target() as NekomimiWalker
	if tracked != null and tracked.is_alive():
		world.set_controlled_character(tracked)


func _on_control_toggled(pressed: bool) -> void:
	if _syncing:
		return
	_control_follows_camera = pressed
	var world: Node = _world()
	if world == null or not world.has_method("set_controlled_character"):
		return
	if _cam == null:
		return
	if not pressed:
		world.set_controlled_character(null)
		return
	var tracked: NekomimiWalker = _cam.get_current_follow_target() as NekomimiWalker
	if tracked == null or not tracked.is_alive():
		world.set_controlled_character(null)
		return
	world.set_controlled_character(tracked)
