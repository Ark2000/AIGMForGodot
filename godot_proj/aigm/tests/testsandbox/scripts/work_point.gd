extends Node2D
## 工作地点：范围内开始打工，结束时获得铜币。
##
## 契约：[method build_f_interact_entry]、[method open_player_interaction]。

signal interaction_state_changed

@export var display_name: String = "工作岗位"
@export var interact_radius: float = 88.0
@export var work_duration_sec: float = 3.2
@export var pay_copper: int = 14
@export var preview_item_id: String = "misc_gear"

var _interact_area: Area2D
var _near_controlled_count: int = 0
var _session_owner: NekomimiWalker

@onready var _hint: Label = $HintLabel


func _ready() -> void:
	add_to_group("work_point")
	add_to_group("interactable_facility")
	_interact_area = $InteractArea
	var sh: CollisionShape2D = $InteractArea/CollisionShape2D
	if sh != null and sh.shape is CircleShape2D:
		(sh.shape as CircleShape2D).radius = interact_radius
	_interact_area.body_entered.connect(_on_body_entered)
	_interact_area.body_exited.connect(_on_body_exited)
	_refresh_sprite()
	if _hint != null:
		_hint.visible = false
		_hint.text = "F 打工"


func _refresh_sprite() -> void:
	var spr: Sprite2D = $Sprite2D
	if spr == null:
		return
	var tex: Texture2D = ItemDB.get_icon_texture(preview_item_id)
	if tex:
		spr.texture = tex
		var max_sz: float = maxf(tex.get_width(), tex.get_height())
		var s: float = 48.0 / maxf(1.0, max_sz)
		spr.scale = Vector2(s, s)


func is_walker_in_range(walker: CharacterBody2D) -> bool:
	return _interact_area != null and _interact_area.overlaps_body(walker)


func get_interact_label() -> String:
	return "打工 · %s" % display_name if not display_name.is_empty() else "打工"


func get_current_user() -> NekomimiWalker:
	if _session_owner == null or not is_instance_valid(_session_owner):
		return null
	return _session_owner


func can_interact(walker: NekomimiWalker) -> bool:
	if walker == null:
		return false
	if not is_walker_in_range(walker):
		return false
	var u: NekomimiWalker = get_current_user()
	return u == null or u == walker


func try_acquire(walker: NekomimiWalker) -> bool:
	if not can_interact(walker):
		return false
	if get_current_user() == walker:
		return true
	_session_owner = walker
	interaction_state_changed.emit()
	return true


func release(walker: NekomimiWalker) -> void:
	var u: NekomimiWalker = get_current_user()
	if u == null:
		return
	if walker != null and u != walker:
		return
	_session_owner = null
	interaction_state_changed.emit()


func apply_pay_to_walker(walker: NekomimiWalker) -> void:
	if walker == null:
		return
	walker.earn_money(maxi(0, pay_copper))


func get_npc_action_duration_sec() -> float:
	return maxf(0.05, work_duration_sec)


func build_f_interact_entry(walker: NekomimiWalker) -> Dictionary:
	if walker == null or not can_interact(walker):
		return {}
	return {
		"node": self,
		"label": get_interact_label(),
		"d2": walker.global_position.distance_squared_to(global_position),
	}


func open_player_interaction(host: Node, walker: NekomimiWalker) -> bool:
	if walker == null or host == null:
		return false
	if not try_acquire(walker):
		return false
	var d: float = maxf(0.05, work_duration_sec)
	walker.start_action_lock("打工中", d, preview_item_id)
	get_tree().create_timer(d).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		if is_instance_valid(walker):
			apply_pay_to_walker(walker)
		release(walker)
	, CONNECT_ONE_SHOT)
	return true


func _on_body_entered(body: Node) -> void:
	if body is NekomimiWalker and (body as NekomimiWalker).user_controlled:
		_near_controlled_count += 1
		_update_hint()


func _on_body_exited(body: Node) -> void:
	if body is NekomimiWalker and (body as NekomimiWalker).user_controlled:
		_near_controlled_count = maxi(0, _near_controlled_count - 1)
		_update_hint()


func _update_hint() -> void:
	if _hint != null:
		_hint.visible = _near_controlled_count > 0
