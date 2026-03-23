extends Camera2D
## 独立于角色的摄像机：跟随某角色、自由平移缩放、自动轮播；跟踪目标死亡时自动换目标。

enum Mode {
	FOLLOW_CHARACTER,
	AUTO_CYCLE,
	FREE,
}

@export var zoom_speed := 3.0
@export var auto_cycle_interval_sec: float = 5.0
@export var ysort_path: NodePath = ^"../YSort"

var mode: Mode = Mode.FOLLOW_CHARACTER
## 在 [method _get_characters_ordered] 列表中的下标。
var follow_character_index: int = 0
var _pan_offset: Vector2 = Vector2.ZERO
var _pan_mode := false
var _zoom_level := 2.0
var _auto_timer: float = 0.0
var _auto_cycle_i: int = 0
var _follow_node: NekomimiWalker


func _ready() -> void:
	add_to_group("spectator_camera")
	_zoom_level = log(zoom.x) / log(zoom_speed) if zoom.x > 0 else 2.0
	position_smoothing_enabled = true
	rotation_smoothing_enabled = true
	call_deferred("_initial_snap")
	call_deferred("_connect_trackables")


func get_current_follow_target() -> NekomimiWalker:
	return _resolve_follow_target()


func _initial_snap() -> void:
	var t := _resolve_follow_target()
	if t != null:
		global_position = t.global_position + _pan_offset


func _connect_trackables() -> void:
	for n in get_tree().get_nodes_in_group("camera_trackable"):
		if n is NekomimiWalker:
			var w: NekomimiWalker = n
			if not w.died.is_connected(_on_trackable_died):
				w.died.connect(_on_trackable_died.bind(w))


func _on_trackable_died(_who: NekomimiWalker) -> void:
	if mode != Mode.FREE:
		var cur := _resolve_follow_target()
		if cur == _who:
			_pan_offset = Vector2.ZERO
			_pick_fallback_after_death()
	if is_inside_tree():
		get_tree().call_group("debug_panel", "refresh_from_camera")


func _pick_fallback_after_death() -> void:
	var alive: Array[NekomimiWalker] = _list_alive_trackables()
	if alive.is_empty():
		mode = Mode.FREE
		return
	mode = Mode.FOLLOW_CHARACTER
	follow_character_index = 0
	_follow_node = alive[0]


func _list_alive_trackables() -> Array[NekomimiWalker]:
	var out: Array[NekomimiWalker] = []
	for n in get_tree().get_nodes_in_group("camera_trackable"):
		if n is NekomimiWalker:
			var w: NekomimiWalker = n
			if w.is_alive() and is_instance_valid(w):
				out.append(w)
	return out


func _get_characters_ordered() -> Array[NekomimiWalker]:
	var ys: Node2D = get_node_or_null(ysort_path) as Node2D
	var out: Array[NekomimiWalker] = []
	if ys == null:
		for n in get_tree().get_nodes_in_group("camera_trackable"):
			if n is NekomimiWalker:
				var w: NekomimiWalker = n as NekomimiWalker
				if w.is_alive():
					out.append(w)
		return out
	for c in ys.get_children():
		if c is NekomimiWalker:
			var w: NekomimiWalker = c
			if w.is_alive():
				out.append(w)
	return out


func _resolve_follow_target() -> NekomimiWalker:
	match mode:
		Mode.FREE:
			return null
		Mode.FOLLOW_CHARACTER:
			if _follow_node != null and is_instance_valid(_follow_node) and _follow_node.is_alive():
				return _follow_node
			var chars := _get_characters_ordered()
			if chars.is_empty():
				return null
			var i := clampi(follow_character_index, 0, chars.size() - 1)
			return chars[i]
		Mode.AUTO_CYCLE:
			var list := _list_alive_trackables()
			if list.is_empty():
				return null
			var idx := _auto_cycle_i % list.size()
			return list[idx]
	return null


func set_mode_follow_character_by_index(index: int) -> void:
	var chars := _get_characters_ordered()
	if chars.is_empty():
		set_mode_free()
		return
	mode = Mode.FOLLOW_CHARACTER
	follow_character_index = clampi(index, 0, chars.size() - 1)
	_follow_node = chars[follow_character_index]


func set_mode_follow_character(node: NekomimiWalker) -> void:
	if node == null or not node.is_alive():
		set_mode_follow_character_by_index(0)
		return
	mode = Mode.FOLLOW_CHARACTER
	_follow_node = node
	var chars := _get_characters_ordered()
	var fi := chars.find(node)
	follow_character_index = maxi(0, fi)


func set_mode_follow_first_character() -> void:
	set_mode_follow_character_by_index(0)


func set_mode_auto_cycle() -> void:
	mode = Mode.AUTO_CYCLE
	_pan_offset = Vector2.ZERO
	_auto_timer = 0.0
	var alive := _list_alive_trackables()
	if not alive.is_empty():
		_auto_cycle_i = 0


func set_mode_free() -> void:
	mode = Mode.FREE


func get_menu_selection_id() -> int:
	const ID_AUTO := 9000
	const ID_FREE := 9001
	const ID_CHAR_BASE := 100
	match mode:
		Mode.AUTO_CYCLE:
			return ID_AUTO
		Mode.FREE:
			return ID_FREE
		Mode.FOLLOW_CHARACTER:
			var chars := _get_characters_ordered()
			if chars.is_empty():
				return ID_FREE
			var idx: int = follow_character_index
			if _follow_node != null and is_instance_valid(_follow_node) and _follow_node.is_alive():
				var fi: int = chars.find(_follow_node)
				if fi >= 0:
					idx = fi
			idx = clampi(idx, 0, chars.size() - 1)
			return ID_CHAR_BASE + idx
	return ID_FREE


func _physics_process(delta: float) -> void:
	if mode == Mode.AUTO_CYCLE:
		var alive := _list_alive_trackables()
		if alive.is_empty():
			mode = Mode.FREE
			if is_inside_tree():
				get_tree().call_group("debug_panel", "refresh_from_camera")
			return
		_auto_timer += delta
		if _auto_timer >= auto_cycle_interval_sec:
			_auto_timer = 0.0
			_auto_cycle_i = (_auto_cycle_i + 1) % maxi(1, alive.size())

	var target := _resolve_follow_target()
	if target != null:
		global_position = target.global_position + _pan_offset
	elif mode != Mode.FREE:
		_pick_fallback_after_death()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if e.pressed:
				_pan_mode = true
			else:
				_pan_mode = false
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_set_zoom_level(_zoom_level + 0.1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_set_zoom_level(_zoom_level - 0.1)
	elif event is InputEventMouseMotion:
		var m: InputEventMouseMotion = event
		if _pan_mode:
			var d := m.relative * (1.0 / zoom.x)
			if mode == Mode.FREE:
				global_position -= d
			else:
				_pan_offset -= d


func _set_zoom_level(val: float) -> void:
	var m := get_global_mouse_position()
	var old_zx := zoom.x
	_zoom_level = val
	zoom = Vector2.ONE * pow(zoom_speed, _zoom_level)
	global_position = m - (m - global_position) * old_zx / zoom.x
