extends Node2D
## 沙盒：右键在点击处随机生成一个 [GroundItem]；实例挂在 [code]YSort[/code] 下以便排序。

const _GROUND_ITEM_SCENE := preload("res://tests/testsandbox/scenes/ground_item.tscn")

@export var spawn_quantity_min: int = 1
@export var spawn_quantity_max: int = 3


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
