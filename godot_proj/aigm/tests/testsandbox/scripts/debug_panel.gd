extends CanvasLayer
## 沙盒**调试面板**（左上）：摄像机跟随模式、是否操控当前跟镜角色、跟镜角色属性、背包列表、[kbd]1[/kbd] 在鼠标处生成所选 [ItemDB] 掉落物。

const _GROUND_ITEM_SCENE := preload("res://tests/testsandbox/scenes/ground_item.tscn")
const _ID_AUTO := 9000
const _ID_FREE := 9001
const _ID_CHAR_BASE := 100
const _CTX_USE := 1

@export var spectator_camera_path: NodePath = ^"../SpectatorCamera"
## [kbd]1[/kbd] 刷出的数量随机范围（含端点）。
@export var spawn_quantity_min: int = 1
@export var spawn_quantity_max: int = 3

var _cam: Camera2D
var _syncing: bool = false
## 为真时切换镜头跟随目标会自动把操控权交给该角色（与 [WorldSandbox] 协调）。
var _control_follows_camera: bool = false
var _walker: CharacterBody2D
var _expanded: bool = false
var _height_expanded: float = 0.0
## 与刷道具下拉选项顺序一致的 [ItemDB] id 列表。
var _spawn_item_ids: Array[String] = []
## 与背包列表顺序一致的 item_id 列表，用于右键菜单定位。
var _inventory_item_ids: Array[String] = []
var _ctx_item_index: int = -1

@onready var _panel: Panel = $Panel
@onready var _toggle: Button = $Panel/Margin/VBox/ToggleButton
@onready var _fold: Control = $Panel/Margin/VBox/FoldContent
@onready var _item_list: ItemList = $Panel/Margin/VBox/FoldContent/ItemList
@onready var _hint: Label = $Panel/Margin/VBox/FoldContent/HintLabel
@onready var _spawn_opt: OptionButton = $Panel/Margin/VBox/FoldContent/SpawnItemOption
@onready var _item_ctx_menu: PopupMenu = $ItemContextMenu


func _ready() -> void:
	add_to_group("debug_panel")
	_cam = get_node_or_null(spectator_camera_path) as Camera2D
	var opt: OptionButton = $Panel/Margin/VBox/FoldContent/ModeOption
	opt.item_selected.connect(_on_item_selected)
	var cb: CheckBox = $Panel/Margin/VBox/FoldContent/ControlUserCheck
	cb.toggled.connect(_on_control_toggled)
	_toggle.pressed.connect(_on_toggle_pressed)
	_item_list.gui_input.connect(_on_item_list_gui_input)
	_item_ctx_menu.id_pressed.connect(_on_item_ctx_id_pressed)
	_item_ctx_menu.add_theme_font_size_override("font_size", 16)
	_item_list.fixed_icon_size = Vector2i(18, 18)
	_item_list.icon_mode = ItemList.ICON_MODE_LEFT
	_apply_small_option_popup_font(opt)
	_apply_small_option_popup_font(_spawn_opt)
	_hint.text = "右键背包道具可使用 | F 拾取 / 箱子 | 1 刷物"
	_fill_spawn_items()
	_update_toggle_label()
	call_deferred("_rebuild_items")
	call_deferred("_defer_bind_layout")
	set_process(true)


## 下拉展开列表用 [PopupMenu]，需单独改字号才会与按钮上一致。
func _apply_small_option_popup_font(opt: OptionButton) -> void:
	var pop: PopupMenu = opt.get_popup()
	if pop == null:
		return
	pop.add_theme_font_size_override("font_size", 16)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1:
		_spawn_selected_item_at_mouse()
		get_viewport().set_input_as_handled()


func _spawn_selected_item_at_mouse() -> void:
	var item_id: String = _get_selected_spawn_item_id()
	if item_id.is_empty():
		return
	var vp: Viewport = get_viewport()
	var world_pos: Vector2 = vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()
	var lo: int = mini(spawn_quantity_min, spawn_quantity_max)
	var hi: int = maxi(spawn_quantity_min, spawn_quantity_max)
	var qty: int = randi_range(lo, hi)
	var gi: Node = _GROUND_ITEM_SCENE.instantiate()
	if gi is GroundItem:
		var g: GroundItem = gi as GroundItem
		g.item_id = item_id
		g.quantity = qty
	var parent_node: Node2D = _ysort_parent()
	parent_node.add_child(gi)
	gi.global_position = world_pos


func _get_selected_spawn_item_id() -> String:
	if _spawn_opt == null:
		return ""
	var i: int = _spawn_opt.selected
	if i < 0 or i >= _spawn_item_ids.size():
		return ""
	return _spawn_item_ids[i]


func _ysort_parent() -> Node2D:
	var w: Node = get_parent()
	if w == null:
		## [CanvasLayer] 无父节点时（极少），用主场景根（沙盒里为 [Node2D] World）。
		return get_tree().current_scene as Node2D
	var ys: Node2D = w.get_node_or_null("YSort") as Node2D
	return ys if ys != null else w as Node2D


func _fill_spawn_items() -> void:
	_spawn_opt.clear()
	_spawn_item_ids.clear()
	var ids: Array[String] = ItemDB.all_item_ids()
	ids.sort()
	for id in ids:
		var def: Dictionary = ItemDB.get_def(id)
		var disp: String = str(def.get("name", id)) if not def.is_empty() else id
		_spawn_opt.add_item("%s — %s" % [disp, id])
		_spawn_item_ids.append(id)


func _defer_bind_layout() -> void:
	await get_tree().process_frame
	_height_expanded = maxf(_panel.size.y, 200.0)
	_apply_fold_layout()
	rebind_to_controlled()


func refresh_from_camera() -> void:
	_rebuild_items()
	_rebind_inventory_to_tracked()
	_refresh_stats_line()


func rebind_to_controlled() -> void:
	_rebind_inventory_to_tracked()


func _current_tracked_walker() -> CharacterBody2D:
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_tree().get_first_node_in_group("spectator_camera") as Camera2D
	if _cam == null or not _cam.has_method("get_current_follow_target"):
		return null
	return _cam.get_current_follow_target() as CharacterBody2D


func _rebind_inventory_to_tracked() -> void:
	var next_walker: CharacterBody2D = _current_tracked_walker()
	if next_walker == _walker:
		return
	if _walker != null and is_instance_valid(_walker) and _walker.has_signal("inventory_changed"):
		if _walker.inventory_changed.is_connected(_on_inventory_changed):
			_walker.inventory_changed.disconnect(_on_inventory_changed)
	_walker = next_walker
	if _walker != null and _walker.has_signal("inventory_changed"):
		_walker.inventory_changed.connect(_on_inventory_changed)
	_on_inventory_changed()


func _process(_delta: float) -> void:
	_rebind_inventory_to_tracked()
	_refresh_stats_line()


func _refresh_stats_line() -> void:
	var lbl: Label = $Panel/Margin/VBox/FoldContent/StatsLine
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_tree().get_first_node_in_group("spectator_camera") as Camera2D
	if _cam == null:
		lbl.text = "—"
		return
	var w: NekomimiWalker = _cam.get_current_follow_target() as NekomimiWalker
	if w == null or not is_instance_valid(w) or not w.is_alive():
		lbl.text = "无跟随目标"
		return
	var hpmax: int = maxi(1, w.combat_max_hp)
	var smax: float = maxf(0.001, w.satiation_max)
	lbl.text = "HP %d/%d · 饱食%d/%d · 速%d" % [
		w.hp,
		hpmax,
		roundi(w.satiation),
		roundi(smax),
		roundi(w.move_speed),
	]


func _world() -> Node:
	return get_parent()


func _rebuild_items() -> void:
	if _cam == null:
		_cam = get_tree().get_first_node_in_group("spectator_camera") as Camera2D
	var opt: OptionButton = $Panel/Margin/VBox/FoldContent/ModeOption
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
	var cb: CheckBox = $Panel/Margin/VBox/FoldContent/ControlUserCheck
	_syncing = true
	cb.button_pressed = _control_follows_camera
	_syncing = false


func _on_item_selected(_index: int) -> void:
	if _cam == null:
		return
	var opt: OptionButton = $Panel/Margin/VBox/FoldContent/ModeOption
	var id := opt.get_item_id(opt.selected)
	var world: Node = _world()
	if id == _ID_AUTO:
		_cam.set_mode_auto_cycle()
	elif id == _ID_FREE:
		_cam.set_mode_free()
	if id == _ID_AUTO or id == _ID_FREE:
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


func _on_toggle_pressed() -> void:
	_expanded = not _expanded
	_apply_fold_layout()


func _apply_fold_layout() -> void:
	_fold.visible = _expanded
	_update_toggle_label()
	var h: float = _height_expanded if _expanded else _collapsed_panel_height()
	_panel.offset_bottom = _panel.offset_top + h


func _collapsed_panel_height() -> float:
	var row: float = maxf(_toggle.get_minimum_size().y, _toggle.size.y)
	return row + 3.0


func _update_toggle_label() -> void:
	_toggle.text = "▼ 调试面板" if _expanded else "▶ 调试面板"


func _on_inventory_changed() -> void:
	_item_list.clear()
	_inventory_item_ids.clear()
	if _walker == null:
		return
	for slot in _walker.inventory:
		var id: String = slot.get("id", "")
		var cnt: int = int(slot.get("count", 0))
		var def: Dictionary = ItemDB.get_def(id)
		var display: String = def.get("name", id) if not def.is_empty() else id
		var tex: Texture2D = ItemDB.get_icon_texture(id)
		var line: String = "%s × %d" % [display, cnt]
		if tex:
			_item_list.add_item(line, tex)
		else:
			_item_list.add_item(line)
		_inventory_item_ids.append(id)


func _on_item_list_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	var idx: int = _item_list.get_item_at_position(mb.position, true)
	if idx < 0 or idx >= _inventory_item_ids.size():
		return
	_ctx_item_index = idx
	var item_id: String = _inventory_item_ids[idx]
	var def: Dictionary = ItemDB.get_def(item_id)
	var name_text: String = str(def.get("name", item_id)) if not def.is_empty() else item_id
	_item_ctx_menu.clear()
	_item_ctx_menu.add_item("使用：%s" % name_text, _CTX_USE)
	_item_ctx_menu.position = Vector2i(int(mb.global_position.x), int(mb.global_position.y))
	_item_ctx_menu.popup()
	_item_list.accept_event()


func _on_item_ctx_id_pressed(id: int) -> void:
	if id != _CTX_USE:
		return
	if _ctx_item_index < 0 or _ctx_item_index >= _inventory_item_ids.size():
		return
	if _walker == null or not is_instance_valid(_walker):
		return
	if not _walker.has_method("try_use_item_by_id"):
		return
	var item_id: String = _inventory_item_ids[_ctx_item_index]
	var ok: bool = bool(_walker.call("try_use_item_by_id", item_id))
	if not ok:
		var sat: float = ItemDB.get_food_satiation(item_id, 0.0)
		_hint.text = "该道具不可用或当前无法使用" if sat <= 0.0 else "当前无法进食（可能已饱或在动作中）"
	else:
		_hint.text = "已使用：%s" % item_id
	_ctx_item_index = -1
