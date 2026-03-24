extends Node
## 沙盒里**按需实例化**交互 UI（背包 / 商店 / 容器 / 多目标选择），使多名角色可同时各自持有一套面板，而不是全局单例抢同一个 [CanvasLayer]。

const _PICKER_SCENE := preload("res://tests/testsandbox/scenes/interact_picker_panel.tscn")
const _INV_SCENE := preload("res://tests/testsandbox/scenes/inventory_panel.tscn")
const _SHOP_SCENE := preload("res://tests/testsandbox/scenes/shop_panel.tscn")
const _CONTAINER_SCENE := preload("res://tests/testsandbox/scenes/container_panel.tscn")


func _ready() -> void:
	add_to_group("interaction_ui_host")


func open_shop_for_target(walker: NekomimiWalker, shop: Node2D) -> bool:
	if walker == null or shop == null:
		return false
	for c in get_children():
		if c.is_in_group("shop_panel") and c.has_method("matches_facility_session"):
			if bool(c.call("matches_facility_session", walker, shop)):
				c.call("close")
				return true
	var p: Node = _SHOP_SCENE.instantiate()
	add_child(p)
	if p.has_method("open_for_target") and bool(p.call("open_for_target", walker, shop)):
		return true
	p.queue_free()
	return false


func open_container_for_target(walker: NekomimiWalker, container: Node2D) -> bool:
	if walker == null or container == null:
		return false
	for c in get_children():
		if c.is_in_group("container_panel") and c.has_method("matches_facility_session"):
			if bool(c.call("matches_facility_session", walker, container)):
				c.call("close")
				return true
	var p: Node = _CONTAINER_SCENE.instantiate()
	add_child(p)
	if p.has_method("open_for_target") and bool(p.call("open_for_target", walker, container)):
		return true
	p.queue_free()
	return false


func open_interact_picker(walker: NekomimiWalker, targets: Array[Dictionary]) -> void:
	var p: Node = _PICKER_SCENE.instantiate()
	add_child(p)
	if p.has_method("open_for_walker"):
		p.call("open_for_walker", walker, targets)
	else:
		p.queue_free()


func toggle_inventory_for_walker(walker: NekomimiWalker) -> void:
	if walker == null:
		return
	for c in get_children():
		if c.is_in_group("inventory_panel") and c.has_method("is_open_for_walker"):
			if bool(c.call("is_open_for_walker", walker)):
				c.call("close")
				return
	var p: Node = _INV_SCENE.instantiate()
	add_child(p)
	if p.has_method("open_for_walker"):
		p.call("open_for_walker", walker)
	else:
		p.queue_free()


func spawn_container_session(walker: NekomimiWalker, container: Node2D, actor_label: String) -> Node:
	var p: Node = _CONTAINER_SCENE.instantiate()
	add_child(p)
	if p.has_method("open_session") and bool(p.call("open_session", walker, container, actor_label)):
		return p
	p.queue_free()
	return null


func spawn_shop_session(walker: NekomimiWalker, shop: Node2D, actor_label: String) -> Node:
	var p: Node = _SHOP_SCENE.instantiate()
	add_child(p)
	if p.has_method("open_session") and bool(p.call("open_session", walker, shop, actor_label)):
		return p
	p.queue_free()
	return null


func spawn_inventory_session(walker: NekomimiWalker, actor_label: String) -> Node:
	var p: Node = _INV_SCENE.instantiate()
	add_child(p)
	if p.has_method("open_session") and bool(p.call("open_session", walker, actor_label)):
		return p
	p.queue_free()
	return null


func close_all_panels_for_walker(walker: NekomimiWalker) -> void:
	if walker == null:
		return
	var snapshot: Array[Node] = []
	for c in get_children():
		snapshot.append(c)
	for c in snapshot:
		if c.has_method("close_if_actor"):
			c.call("close_if_actor", walker)
