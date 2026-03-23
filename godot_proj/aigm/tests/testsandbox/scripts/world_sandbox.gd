extends Node2D
## 沙盒世界：被用户操控角色的协调（摄像机跟镜与操控权不同步时收回权限）；刷道具见 [DebugPanel]。

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
	get_tree().call_group("debug_panel", "rebind_to_controlled")
