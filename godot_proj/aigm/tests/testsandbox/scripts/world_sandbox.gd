extends Node2D
## 沙盒世界：地面物品生成、被用户操控角色的协调（背包 UI、摄像机切走时收回操控权）。

const _GROUND_ITEM_SCENE := preload("res://tests/testsandbox/scenes/ground_item.tscn")

@export var spawn_quantity_min: int = 1
@export var spawn_quantity_max: int = 3

var _controlled: NekomimiWalker


func _ready() -> void:
	add_to_group("world_sandbox")


func _physics_process(_delta: float) -> void:
	_sync_control_with_camera_follow()


func _sync_control_with_camera_follow() -> void:
	var cam: Node = get_tree().get_first_node_in_group("spectator_camera")
	if cam == null or not cam.has_method("get_current_follow_target"):
		return
	var tracked: NekomimiWalker = cam.get_current_follow_target() as NekomimiWalker
	if _controlled != null and is_instance_valid(_controlled):
		if tracked != _controlled:
			_controlled.set_user_controlled(false)
			_controlled = null
			_notify_inventory_rebind()


## 将操控权交给 [param walker]；传 [code]null[/code] 表示只收回当前操控。
func set_controlled_character(walker: NekomimiWalker) -> void:
	if _controlled != null and is_instance_valid(_controlled):
		if walker == null or _controlled != walker:
			_controlled.set_user_controlled(false)
	_controlled = walker
	if _controlled != null and is_instance_valid(_controlled):
		_controlled.set_user_controlled(true)
	_notify_inventory_rebind()


func get_controlled_character() -> NekomimiWalker:
	return _controlled if is_instance_valid(_controlled) else null


func _notify_inventory_rebind() -> void:
	get_tree().call_group("inventory_hud", "rebind_to_controlled")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
	_spawn_random_ground_item(world_pos)
	get_viewport().set_input_as_handled()


func _spawn_random_ground_item(world_pos: Vector2) -> void:
	var ids: Array[String] = ItemDB.all_item_ids()
	if ids.is_empty():
		return
	var id: String = ids.pick_random()
	var gi: Node = _GROUND_ITEM_SCENE.instantiate()
	var lo: int = mini(spawn_quantity_min, spawn_quantity_max)
	var hi: int = maxi(spawn_quantity_min, spawn_quantity_max)
	var qty: int = randi_range(lo, hi)
	if gi is GroundItem:
		var g: GroundItem = gi as GroundItem
		g.item_id = id
		g.quantity = qty
	var parent_node: Node2D = _ysort_parent()
	parent_node.add_child(gi)
	gi.global_position = world_pos


func _ysort_parent() -> Node2D:
	var ys: Node2D = get_node_or_null("YSort") as Node2D
	return ys if ys != null else self
