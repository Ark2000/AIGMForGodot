extends CharacterBody2D
class_name NekomimiWalker
## 8 向行走，帧布局与 `char_white_nekomimi_walk_spritesheet.md` 一致（6×4，每向 3 帧）。
##
## 多人在同屏时，把实例放在带 `y_sort_enabled` 的父节点（如 `World/Characters`）下，并调 [member Node2D.y_sort_origin_offset] 对齐脚底。
##
## 所有实例均为「角色」：[member user_controlled] 为真时读键盘/点击与普攻；为假时由 [NpcBehavior] 驱动。
## 共用 [member inventory]、[method add_item_to_inventory] 等；自动拾取见 [member player_auto_pickup] 与 [NpcBehavior.npc_auto_pickup]。
## 组 [code]controlled_nekomimi[/code] / [code]npc_nekomimi[/code] 仅用于输入与 AI 分工；**伤害判定与是否被用户操控无关**（同类互打规则一致）。
## 普攻为泰拉瑞亚式绕身挥击：子节点 [AttackSwingPivot] 带拳头贴图与 [AttackSwingArea] 碰撞，在 [member attack_hitbox_duration_sec] 内扫过一段弧。

signal destination_reached
signal navigation_stuck
signal speech_bubble_hidden
signal inventory_changed
signal hp_changed(current: int, maximum: int)
signal died
## 饱食度变化（0～[member satiation_max]）；全体角色随时间扣减（与是否用户操控无关）。
signal satiation_changed(current: float, maximum: float)

## 为真时由用户输入操控（与 [NpcBehavior] 互斥）；由 [WorldSandbox] / UI 设置。
var user_controlled: bool = false

@export_group("When user_controlled")
## 用户操控时是否用方向键移动。
@export var player_keyboard_move: bool = true
## 用户操控时是否左键点击地面移动。
@export var player_click_move: bool = true
## 用户操控时 [kbd]E[/kbd] 是否触发随机台词气泡。
@export var player_key_interact_talk: bool = true
## 靠近掉落物时是否自动入包；关闭后需按 [kbd]F[/kbd]（[member player_key_pickup]）拾取。
@export var player_auto_pickup: bool = true
## 用户操控时 [kbd]F[/kbd] 是否用于拾取 / 容器交互（与 [member player_auto_pickup] 配合）。
@export var player_key_pickup: bool = true
## 用户操控时 [kbd]Q[/kbd] 是否打开背包面板。
@export var player_key_inventory: bool = true
## 轻量即时战斗：按 [kbd]J[/kbd] 普攻（仅用户操控时）。
@export var player_key_attack: bool = true

@export_group("Combat (light)")
## 生命上限；[member hp] 开局与此对齐。
@export var combat_max_hp: int = 300
## 单次普攻造成的伤害数值。
@export var attack_damage: int = 25
## 两次普攻之间的最短间隔（秒）。
@export var attack_cooldown_sec: float = 0.42
## 挥击窗口持续时长（秒），此间 [member AttackSwingArea] 参与命中检测。
@export var attack_hitbox_duration_sec: float = 0.18
## 泰拉瑞亚式挥击：拳头与碰撞绕胸口 [member AttackSwingPivot] 旋转的总角度（度）。
@export var attack_swing_arc_deg: float = 115.0

@export_group("Items / inventory")
## 背包格数上限（每格可堆叠至 [ItemDB] 的 [code]max_stack[/code]）。
@export var inventory_max_slots: int = 24
## 当前背包：每项为 [code]{ "id": String, "count": int }[/code]，[signal inventory_changed] 时更新。
var inventory: Array[Dictionary] = []

@export_group("Satiation")
## 饱食度上限；全体角色共用同一套规则。
@export var satiation_max: float = 100.0
## 当前饱食度；开局在 [method _ready] 会与 [member satiation_max] 对齐。
## 游戏**运行中**可在编辑器下方切到 [b]Remote[/b] 场景树，选中本角色后在 Inspector 里直接改（用于调试觅食等）。
@export var satiation: float = 100.0
## 每秒自然扣减的饱食度（全体角色；见 [method _physics_process]）。
@export var satiation_drain_per_sec: float = 0.4

## 行走与寻路时的移动速度（像素/秒）。
@export var move_speed: float = 180
## 行走动画帧切换快慢（越大循环越快）。
@export var anim_speed: float = 9.0
## 为真时在控制台打印朝向 / 帧变化（调试用）。
@export var debug_log_sprite_changes: bool = false

@export_group("Navigation stuck")
## 是否启用「寻路卡住」检测并 [signal navigation_stuck]。
@export var navigation_stuck_enabled: bool = true
## 正在沿路径移动时，全局位置连续若干秒几乎不变则视为卡住并取消寻路。
@export var navigation_stuck_time_sec: float = 1.25
## 判定「仍在移动」所需的最小位移（像素），低于此视为未动。
@export var navigation_stuck_min_move_distance: float = 2.5

@export_group("Appearance")
## 若指定则覆盖场景中 Sprite2D 的默认贴图；帧布局需与 `sprite_hframes` / `sprite_vframes` 及 `_FRAMES` 一致。
@export var character_texture: Texture2D
## 精灵表横向帧数（与 [member character_texture]、[member _FRAMES] 布局一致）。
@export var sprite_hframes: int = 6
## 精灵表纵向帧数。
@export var sprite_vframes: int = 4

## 气泡内文字打完后的停留时间（秒），再关闭气泡。
@export var speech_duration: float = 2.5
## 打字机速度（字/秒）；打完后再计 `speech_duration` 才关闭气泡。
@export var speech_chars_per_second: float = 28.0
## 随机台词候选池（[kbd]E[/kbd] 等；可留空由 [NpcBehavior] 覆盖）。
@export var speech_lines: Array[String] = [
	"喵~",
	"今天也要加油！",
	"好累呀…\n🥱",
	"要去哪里呢？\n😏",
	"嗯嗯！\n😃",
	"肚子有点饿了喵。\n🤤",
]

## 与 md 中行列说明一致：行优先，frame = row * 6 + col
const _FRAMES: Dictionary = {
	"down": [0, 1, 2],
	"down_left": [3, 4, 5],
	"left": [6, 7, 8],
	"down_right": [9, 10, 11],
	"right": [12, 13, 14],
	"up_left": [15, 16, 17],
	"up": [18, 19, 20],
	"up_right": [21, 22, 23],
}

## 每向 3 帧时本地下标：0→1→2→1→0…
const _WALK_LOCAL_PINGPONG: Array[int] = [0, 1, 2, 1]

## 与 [member GroundItem.PICKUP_LAYER_BIT] 一致：物理层第 5 层（位掩码 16）。
const PICKUP_LAYER_BIT: int = 16
## 与 [code]project.godot[/code] 中 [code]combat_hurt[/code] 层一致：第 6 层（位掩码 32）。
const HURT_LAYER_BIT: int = 32
const MONEY_ITEM_ID: String = "misc_copper_coin"

## 角色精灵；帧索引由朝向与行走驱动。
@onready var _sprite: Sprite2D = $Sprite2D
## [method move_to] 使用的导航代理。
@onready var _nav_agent: NavigationAgent2D = $NavigationAgent2D
## 头顶台词气泡根控件。
@onready var _speech_bubble: Control = $Control
## 气泡内文案 [Label]。
@onready var _speech_label: Label = $Control/Label
## 与 [GroundItem] 同物理层重叠检测，用于拾取。
@onready var _pickup_area: Area2D = $PickupArea
## 受击判定区（[code]combat_hurt[/code] 组）。
@onready var _hurt_area: Area2D = $HurtArea
## 挥击绕身旋转的轴心（贴图父节点）。
@onready var _attack_swing_pivot: Node2D = $AttackSwingPivot
## 挥击弧上的命中 [Area2D]。
@onready var _attack_hitbox: Area2D = $AttackSwingPivot/AttackSwingArea
## 游荡 / 战斗 / 觅食等 AI；用户操控时仍挂在节点上但由 [member user_controlled] 门控。
@onready var _npc_behavior: NpcBehavior = $NpcBehavior
## 脚下动作进度 UI 根节点（如“进食中”）。
@onready var _action_ui: Control = $ActionUI
## 脚下动作进度条。
@onready var _action_bar: ProgressBar = $ActionUI/ActionProgress
## 进度条下方状态文案。
@onready var _action_label: Label = $ActionUI/ActionLabel
## 动作关联道具图标（如进食时显示食物）。
@onready var _action_icon: TextureRect = $ActionUI/ActionIcon

## 当前八向朝向键（如 [code]down[/code]、[code]up_left[/code]）。
var _facing: String = "down"
## 行走动画用的时间累加（与 [member anim_speed] 配合）。
var _anim_time: float = 0.0
## 气泡「打字结束」后的剩余显示时间（秒）。
var _speech_time_left: float = 0.0
## 当前气泡完整文案。
var _speech_full: String = ""
## 打字机当前已显示的字符数（由 [member speech_chars_per_second] 与时间累加）。
var _speech_type_progress: float = 0.0
## 是否处于打字机播放中。
var _speech_typing: bool = false
## 上一帧导航是否已结束（用于边沿检测 [signal destination_reached]）。
var _prev_nav_finished: bool = true
## 寻路卡住：静止累计时间（秒）。
var _nav_stuck_accum: float = 0.0
## 寻路卡住检测用的上一采样位置。
var _nav_stuck_last_pos: Vector2 = Vector2.ZERO
## 上一帧是否处于沿导航移动中（卡住逻辑用）。
var _was_following_nav: bool = false

## 当前生命；[method _ready] 设为 [member combat_max_hp]，死亡后为 0。
var hp: int = 0
## 普攻冷却剩余（秒）。
var _attack_cooldown_left: float = 0.0
## 当前挥击窗口剩余（秒）；大于 0 时扫判定。
var _attack_active_time: float = 0.0
## 本段挥击已命中过的实例 id，防重复伤害。
var _hit_ids_this_attack: Array[int] = []
## 记录精灵默认缩放，用于攻击/受击 tween 还原。
var _sprite_base_scale: Vector2 = Vector2.ONE
## 记录精灵默认本地位置，用于受击 tween。
var _sprite_base_pos: Vector2 = Vector2.ZERO
## 受击闪红/位移 tween（非空时先杀再建）。
var _hurt_fx_tween: Tween
## 攻击缩放 tween。
var _attack_fx_tween: Tween
## 动作锁定剩余时长（秒）；大于 0 时角色无法移动与寻路。
var _action_busy_left: float = 0.0
## 当前动作锁定总时长（秒），用于驱动进度条。
var _action_busy_total: float = 0.0


func _ready() -> void:
	add_to_group("npc_nekomimi")
	add_to_group("camera_trackable")
	hp = combat_max_hp
	satiation = satiation_max
	_sprite_base_scale = _sprite.scale
	_sprite_base_pos = _sprite.position
	if _hurt_area:
		_hurt_area.collision_layer = HURT_LAYER_BIT
		_hurt_area.collision_mask = 0
		_hurt_area.monitoring = false
		_hurt_area.monitorable = true
		_hurt_area.add_to_group("combat_hurt")
	if _attack_hitbox:
		_attack_hitbox.collision_layer = 0
		_attack_hitbox.collision_mask = HURT_LAYER_BIT
		_attack_hitbox.monitoring = false
	_speech_bubble.visible = false
	_speech_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _action_ui:
		_action_ui.visible = false
		_action_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_character_texture_if_set()
	if _pickup_area:
		_pickup_area.collision_layer = 0
		_pickup_area.collision_mask = PICKUP_LAYER_BIT
		_pickup_area.monitoring = true
		_pickup_area.monitorable = false
	await get_tree().physics_frame
	_nav_agent.target_position = global_position
	_prev_nav_finished = _nav_agent.is_navigation_finished()
	_nav_stuck_last_pos = global_position


func is_user_controlled() -> bool:
	return user_controlled


func is_alive() -> bool:
	return hp > 0


func set_user_controlled(on: bool) -> void:
	if user_controlled == on:
		return
	user_controlled = on
	if user_controlled:
		remove_from_group("npc_nekomimi")
		add_to_group("controlled_nekomimi")
	else:
		remove_from_group("controlled_nekomimi")
		add_to_group("npc_nekomimi")
		if _npc_behavior:
			_npc_behavior.resume_after_control()


func _mouse_world_pos() -> Vector2:
	return _sprite.get_global_mouse_position()


func _is_key_press(event: InputEvent, key: Key) -> bool:
	if not (event is InputEventKey):
		return false
	var ek: InputEventKey = event as InputEventKey
	if not ek.pressed or ek.echo:
		return false
	return ek.keycode == key or ek.physical_keycode == key


func _collect_f_interact_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in get_tree().get_nodes_in_group("shop_point"):
		if not (n is Node2D):
			continue
		var s: Node2D = n as Node2D
		if not s.has_method("can_interact") or not bool(s.call("can_interact", self)):
			continue
		var label: String = str(s.call("get_interact_label")) if s.has_method("get_interact_label") else str(s.get("display_name"))
		out.append({
			"type": "shop",
			"node": s,
			"label": ("商店 · %s" % label) if not label.is_empty() else "商店",
			"d2": global_position.distance_squared_to(s.global_position),
		})
	for n in get_tree().get_nodes_in_group("item_container"):
		if not (n is Node2D):
			continue
		var c: Node2D = n as Node2D
		if not c.has_method("can_interact") or not bool(c.call("can_interact", self)):
			continue
		var label: String = str(c.call("get_interact_label")) if c.has_method("get_interact_label") else str(c.get("display_name"))
		out.append({
			"type": "container",
			"node": c,
			"label": ("容器 · %s" % label) if not label.is_empty() else "容器",
			"d2": global_position.distance_squared_to(c.global_position),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("d2", INF)) < float(b.get("d2", INF))
	)
	return out


func _try_open_target(target: Dictionary) -> bool:
	var t: String = str(target.get("type", ""))
	var node: Node = target.get("node", null) as Node
	if node == null:
		return false
	if t == "shop":
		var shop_panel: Node = get_tree().get_first_node_in_group("shop_panel")
		return shop_panel != null and shop_panel.has_method("open_for_target") and bool(shop_panel.call("open_for_target", self, node))
	if t == "container":
		var panel: Node = get_tree().get_first_node_in_group("container_panel")
		return panel != null and panel.has_method("open_for_target") and bool(panel.call("open_for_target", self, node))
	return false


func _try_handle_f_interaction() -> bool:
	var targets: Array[Dictionary] = _collect_f_interact_targets()
	if targets.is_empty():
		return false
	if targets.size() == 1:
		return _try_open_target(targets[0])
	var picker: Node = get_tree().get_first_node_in_group("interact_picker_panel")
	if picker != null and picker.has_method("open_for_walker"):
		picker.call("open_for_walker", self, targets)
		return true
	return _try_open_target(targets[0])


func _unhandled_input(event: InputEvent) -> void:
	if not user_controlled:
		return
	if hp <= 0:
		return
	if _is_key_press(event, KEY_J):
		if player_key_attack:
			_try_attack()
			get_viewport().set_input_as_handled()
		return
	if _is_key_press(event, KEY_F):
		if player_key_pickup:
			if _try_handle_f_interaction():
				get_viewport().set_input_as_handled()
				return
			pickup_item(0)
			get_viewport().set_input_as_handled()
		return
	if _is_key_press(event, KEY_E):
		if player_key_interact_talk:
			_say_random_line()
			get_viewport().set_input_as_handled()
		return
	if _is_key_press(event, KEY_Q):
		if player_key_inventory:
			var inv_panel: Node = get_tree().get_first_node_in_group("inventory_panel")
			if inv_panel != null and inv_panel.has_method("toggle_for_walker"):
				inv_panel.call("toggle_for_walker", self)
				get_viewport().set_input_as_handled()
		return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		if player_click_move:
			move_to(_mouse_world_pos())
			get_viewport().set_input_as_handled()


func _say_random_line() -> void:
	if speech_lines.is_empty():
		return
	talk(speech_lines.pick_random())


## NPC 随机台词；逻辑在 [NpcBehavior]，此处转发以便外部仍对 walker 调用。
func npc_say_random() -> void:
	if _npc_behavior:
		_npc_behavior.say_random_line()


## 显示头顶气泡（打字机）；若正在显示则从头重播新文案。
func talk(text: String) -> void:
	_speech_full = text
	_speech_type_progress = 0.0
	_speech_typing = not text.is_empty()
	_speech_label.text = ""
	_speech_time_left = 0.0
	_speech_bubble.visible = not text.is_empty()
	if text.is_empty():
		_speech_typing = false


func move_to(pos: Vector2) -> void:
	_nav_agent.target_position = pos


func start_action_lock(text: String, duration_sec: float, item_id: String = "") -> void:
	var d: float = maxf(0.0, duration_sec)
	if d <= 0.0:
		clear_action_lock()
		return
	_action_busy_total = d
	_action_busy_left = d
	velocity = Vector2.ZERO
	if _nav_agent:
		_nav_agent.target_position = global_position
	if _action_ui:
		_action_ui.visible = true
	if _action_label:
		_action_label.text = text
	if _action_icon:
		var tex: Texture2D = ItemDB.get_icon_texture(item_id) if not item_id.is_empty() else null
		_action_icon.texture = tex
		_action_icon.visible = tex != null
	if _action_bar:
		_action_bar.max_value = 100.0
		_action_bar.value = 0.0


func clear_action_lock() -> void:
	_action_busy_left = 0.0
	_action_busy_total = 0.0
	if _action_ui:
		_action_ui.visible = false
	if _action_icon:
		_action_icon.visible = false
		_action_icon.texture = null


func is_action_locked() -> bool:
	return _action_busy_left > 0.0


## 将八向朝向对准世界坐标（用于 NPC 反击等，不移动）。
func face_toward_world(pos: Vector2) -> void:
	var d: Vector2 = pos - global_position
	if d.length_squared() < 4.0:
		return
	_facing = _vector_to_facing(d.normalized())


func _try_attack() -> void:
	if not user_controlled or _attack_hitbox == null:
		return
	if hp <= 0:
		return
	_begin_attack_window()


## NPC 反击等由 [NpcBehavior] 调用；与玩家共用冷却与判定。
## [param ignore_cooldown]：受击反击时传 [code]true[/code]，避免玩家连打导致反击一直被冷却挡掉。
func try_npc_attack(ignore_cooldown: bool = false) -> void:
	if user_controlled or _attack_hitbox == null:
		return
	if hp <= 0:
		return
	_begin_attack_window(ignore_cooldown)


func _begin_attack_window(ignore_cooldown: bool = false) -> void:
	if hp <= 0:
		return
	if not ignore_cooldown and _attack_cooldown_left > 0.0:
		return
	_attack_cooldown_left = attack_cooldown_sec
	_attack_active_time = attack_hitbox_duration_sec
	_hit_ids_this_attack.clear()
	_attack_hitbox.monitoring = true
	if _attack_swing_pivot:
		_attack_swing_pivot.visible = true
	_update_attack_swing()
	_play_attack_fx()


func _update_attack_swing() -> void:
	if _attack_swing_pivot == null:
		return
	var fwd: Vector2 = _facing_to_vector()
	var base_angle: float = fwd.angle()
	var half_arc: float = deg_to_rad(attack_swing_arc_deg * 0.5)
	var u := 1.0 - (_attack_active_time / attack_hitbox_duration_sec)
	u = clampf(u, 0.0, 1.0)
	var angle := base_angle - half_arc + u * (2.0 * half_arc)
	_attack_swing_pivot.rotation = angle


func _facing_to_vector() -> Vector2:
	match _facing:
		"down":
			return Vector2(0, 1)
		"up":
			return Vector2(0, -1)
		"left":
			return Vector2(-1, 0)
		"right":
			return Vector2(1, 0)
		"down_left":
			return Vector2(-0.70710678, 0.70710678)
		"down_right":
			return Vector2(0.70710678, 0.70710678)
		"up_left":
			return Vector2(-0.70710678, -0.70710678)
		"up_right":
			return Vector2(0.70710678, -0.70710678)
		_:
			return Vector2(0, 1)


func _process_attack_hits() -> void:
	if _attack_hitbox == null:
		return
	for a in _attack_hitbox.get_overlapping_areas():
		if not a.is_in_group("combat_hurt"):
			continue
		var target_node: Node = a.get_parent()
		if target_node == self:
			continue
		if not (target_node is NekomimiWalker):
			continue
		var target: NekomimiWalker = target_node as NekomimiWalker
		var tid: int = target.get_instance_id()
		if tid in _hit_ids_this_attack:
			continue
		target.take_damage(attack_damage, self)
		_hit_ids_this_attack.append(tid)


## 伤害与是否被用户操控无关；仅排除自己打自己。
func take_damage(amount: int, attacker: Node) -> void:
	if amount <= 0 or hp <= 0:
		return
	if attacker != null and attacker == self:
		return
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp, combat_max_hp)
	_play_hurt_fx()
	if not user_controlled and _npc_behavior:
		_npc_behavior.notify_hurt(attacker)
	if hp <= 0:
		_die()


func _die() -> void:
	died.emit()
	clear_action_lock()
	velocity = Vector2.ZERO
	talk("")
	_speech_bubble.visible = false
	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0
	if _nav_agent:
		_nav_agent.target_position = global_position
		_nav_agent.process_mode = Node.PROCESS_MODE_DISABLED
	if _hurt_area:
		_hurt_area.monitorable = false
	if _attack_hitbox:
		_attack_hitbox.monitoring = false
	if _attack_swing_pivot:
		_attack_swing_pivot.visible = false
	if _pickup_area:
		_pickup_area.monitoring = false
	if _npc_behavior:
		_npc_behavior.set_process(false)
		_npc_behavior.set_physics_process(false)
	if _sprite:
		var npc_die_tw: Tween = create_tween()
		npc_die_tw.tween_property(_sprite, "modulate:a", 0.0, 0.38)
		npc_die_tw.finished.connect(queue_free)
	else:
		queue_free()


func _play_attack_fx() -> void:
	if _sprite == null:
		return
	if _attack_fx_tween != null:
		_attack_fx_tween.kill()
	_attack_fx_tween = create_tween()
	var s0: Vector2 = _sprite_base_scale
	_attack_fx_tween.tween_property(_sprite, "scale", s0 * 1.14, 0.05)
	_attack_fx_tween.tween_property(_sprite, "scale", s0, 0.09)


func _play_hurt_fx() -> void:
	if _sprite == null:
		return
	if _hurt_fx_tween != null:
		_hurt_fx_tween.kill()
	_hurt_fx_tween = create_tween()
	var p0: Vector2 = _sprite_base_pos
	_sprite.modulate = Color(1.0, 0.45, 0.45)
	_hurt_fx_tween.tween_property(_sprite, "position", p0 + Vector2(5, 0), 0.04)
	_hurt_fx_tween.tween_property(_sprite, "position", p0 + Vector2(-4, 0), 0.04)
	_hurt_fx_tween.tween_property(_sprite, "position", p0, 0.06)
	_hurt_fx_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.14)


## 返回当前拾取范围内、按距离从近到远排序的 [GroundItem] 节点（玩家与 NPC 均可用）。
func get_ground_items() -> Array:
	if _pickup_area == null:
		return []
	return _collect_ground_items_sorted()


## 拾取列表中第 [param index] 个地面物品（0 为最近）；手动拾取时一般由玩家按 [kbd]F[/kbd] 调 [code]pickup_item(0)[/code]，NPC 可由 AI 脚本调用。
func pickup_item(index: int) -> void:
	if _pickup_area == null:
		return
	var grounds: Array = _collect_ground_items_sorted()
	if index < 0 or index >= grounds.size():
		return
	var gi: GroundItem = grounds[index] as GroundItem
	if gi != null:
		_try_pickup_ground(gi)


## 将物品加入背包，返回未能入包的数量（背包满或无效 id 时大于 0）。
func add_item_to_inventory(item_id: String, amount: int) -> int:
	var remaining: int = ItemDB.add_items_to_slots(inventory, inventory_max_slots, item_id, amount)
	if remaining < amount:
		inventory_changed.emit()
	return remaining


func get_money() -> int:
	var total: int = 0
	for slot in inventory:
		if not (slot is Dictionary):
			continue
		if str((slot as Dictionary).get("id", "")) != MONEY_ITEM_ID:
			continue
		total += maxi(0, int((slot as Dictionary).get("count", 0)))
	return total


func spend_money(amount: int) -> bool:
	var need: int = maxi(0, amount)
	if need <= 0:
		return true
	if get_money() < need:
		return false
	var removed: int = remove_items_from_inventory_by_id(MONEY_ITEM_ID, need)
	return removed >= need


func earn_money(amount: int) -> int:
	var a: int = maxi(0, amount)
	if a <= 0:
		return 0
	var left: int = add_item_to_inventory(MONEY_ITEM_ID, a)
	return a - left


func add_satiation(amount: float) -> void:
	if amount <= 0.0:
		return
	var prev: float = satiation
	satiation = minf(satiation_max, satiation + amount)
	if not is_equal_approx(satiation, prev):
		satiation_changed.emit(satiation, satiation_max)


## 从背包按 id 移除至多 [param count] 个（跨多格）；返回实际移除数量。
func remove_items_from_inventory_by_id(item_id: String, count: int) -> int:
	if count <= 0:
		return 0
	var total: int = 0
	var left: int = count
	while left > 0:
		var si: int = ItemDB.first_slot_with_item(inventory, item_id)
		if si < 0:
			break
		var removed: int = ItemDB.remove_items_from_slot(inventory, si, left)
		if removed <= 0:
			break
		total += removed
		left -= removed
	if total > 0:
		inventory_changed.emit()
	return total


## 吃掉背包里的物品并增加饱食度；返回实际吃掉个数。
func consume_inventory_item_for_satiation(item_id: String, count: int, satiation_per_unit: float) -> int:
	var n: int = remove_items_from_inventory_by_id(item_id, count)
	if n > 0:
		add_satiation(satiation_per_unit * float(n))
	return n


## 调试/快捷使用入口：当前仅实现食物（恢复饱食并触发动作读条）。
func try_use_item_by_id(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	if hp <= 0:
		return false
	if is_action_locked():
		return false
	var sat_per: float = ItemDB.get_food_satiation(item_id, 0.0)
	if sat_per <= 0.0:
		return false
	if satiation >= satiation_max:
		return false
	if consume_inventory_item_for_satiation(item_id, 1, sat_per) <= 0:
		return false
	start_action_lock("进食中", 1.05, item_id)
	return true


func _collect_ground_items_sorted() -> Array:
	var out: Array = []
	if _pickup_area == null:
		return out
	for a in _pickup_area.get_overlapping_areas():
		if a is GroundItem:
			out.append(a)
	out.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return out


func _try_pickup_ground(gi: GroundItem) -> void:
	if gi == null or not is_instance_valid(gi):
		return
	var left: int = add_item_to_inventory(gi.item_id, gi.quantity)
	gi.apply_pickup_result(left)


func _apply_character_texture_if_set() -> void:
	if character_texture == null:
		return
	_sprite.texture = character_texture
	_sprite.hframes = maxi(1, sprite_hframes)
	_sprite.vframes = maxi(1, sprite_vframes)
	var max_f: int = _sprite.hframes * _sprite.vframes - 1
	_sprite.frame = clampi(_sprite.frame, 0, max_f)


## 运行时换图；[param hframes]/[param vframes] 为 0 时用当前 [member sprite_hframes]/[member sprite_vframes]。
func set_character_texture(tex: Texture2D, hframes: int = 0, vframes: int = 0) -> void:
	character_texture = tex
	if tex == null or _sprite == null:
		return
	var hf: int = sprite_hframes if hframes <= 0 else hframes
	var vf: int = sprite_vframes if vframes <= 0 else vframes
	sprite_hframes = maxi(1, hf)
	sprite_vframes = maxi(1, vf)
	_sprite.texture = tex
	_sprite.hframes = sprite_hframes
	_sprite.vframes = sprite_vframes
	var max_f: int = _sprite.hframes * _sprite.vframes - 1
	_sprite.frame = clampi(_sprite.frame, 0, max_f)


func _cancel_navigation_stuck() -> void:
	_nav_stuck_accum = 0.0
	_nav_stuck_last_pos = global_position
	_prev_nav_finished = true
	velocity = Vector2.ZERO
	_nav_agent.target_position = global_position
	navigation_stuck.emit()


func _step_speech_bubble(delta: float) -> void:
	if _speech_typing:
		_speech_type_progress += delta * speech_chars_per_second
		var n: int = mini(floori(_speech_type_progress), _speech_full.length())
		_speech_label.text = _speech_full.substr(0, n)
		if n >= _speech_full.length():
			_speech_typing = false
			_speech_time_left = speech_duration
	elif _speech_time_left > 0.0:
		_speech_time_left -= delta
		if _speech_time_left <= 0.0:
			_speech_bubble.visible = false
			speech_bubble_hidden.emit()


func _physics_process(delta: float) -> void:
	var was_facing := _facing
	var was_frame := _sprite.frame

	var action_locked: bool = is_action_locked()
	var manual := false
	var dir := Vector2.ZERO
	if not action_locked and user_controlled and player_keyboard_move:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		manual = dir.length_squared() > 0.0001

	if action_locked:
		velocity = Vector2.ZERO
		if _nav_agent:
			_nav_agent.target_position = global_position
		var seq_locked: Array = _FRAMES[_facing]
		_sprite.frame = seq_locked[1]
	elif manual:
		dir = dir.normalized()
		_nav_agent.target_position = global_position
		velocity = dir * move_speed
		_facing = _vector_to_facing(dir)
		_anim_time += delta * anim_speed
		var seq: Array = _FRAMES[_facing]
		var li: int = _WALK_LOCAL_PINGPONG[int(_anim_time) % _WALK_LOCAL_PINGPONG.size()]
		_sprite.frame = seq[li]
	elif not _nav_agent.is_navigation_finished():
		var next_pos: Vector2 = _nav_agent.get_next_path_position()
		var to_next: Vector2 = next_pos - global_position
		if to_next.length_squared() > 0.0001:
			var nav_dir: Vector2 = to_next.normalized()
			velocity = nav_dir * move_speed
			_facing = _vector_to_facing(nav_dir)
			_anim_time += delta * anim_speed
			var seq2: Array = _FRAMES[_facing]
			var li2: int = _WALK_LOCAL_PINGPONG[int(_anim_time) % _WALK_LOCAL_PINGPONG.size()]
			_sprite.frame = seq2[li2]
		else:
			velocity = Vector2.ZERO
			var seq_idle2: Array = _FRAMES[_facing]
			_sprite.frame = seq_idle2[1]
	else:
		velocity = Vector2.ZERO
		var seq_idle: Array = _FRAMES[_facing]
		_sprite.frame = seq_idle[1]

	var nav_finished_now := _nav_agent.is_navigation_finished()
	if not _prev_nav_finished and nav_finished_now:
		destination_reached.emit()
	_prev_nav_finished = nav_finished_now

	if debug_log_sprite_changes and (was_facing != _facing or was_frame != _sprite.frame):
		print("[NekomimiWalker] facing %s → %s | sprite.frame %d → %d" % [was_facing, _facing, was_frame, _sprite.frame])

	_step_speech_bubble(delta)

	if hp > 0 and satiation > 0.0:
		var prev_s: float = satiation
		satiation = maxf(0.0, satiation - satiation_drain_per_sec * delta)
		if not is_equal_approx(satiation, prev_s):
			satiation_changed.emit(satiation, satiation_max)

	if _action_busy_left > 0.0:
		_action_busy_left = maxf(0.0, _action_busy_left - delta)
		if _action_bar and _action_busy_total > 0.0:
			var ratio: float = 1.0 - (_action_busy_left / _action_busy_total)
			_action_bar.value = clampf(ratio * 100.0, 0.0, 100.0)
		if _action_busy_left <= 0.0:
			clear_action_lock()

	move_and_slide()

	if _attack_cooldown_left > 0.0:
		_attack_cooldown_left -= delta
	if _attack_active_time > 0.0:
		_attack_active_time -= delta
		_update_attack_swing()
		_process_attack_hits()
		if _attack_active_time <= 0.0 and _attack_hitbox != null:
			_attack_hitbox.monitoring = false
			if _attack_swing_pivot:
				_attack_swing_pivot.visible = false

	if navigation_stuck_enabled:
		var following_nav := not manual and not _nav_agent.is_navigation_finished()
		var min_d2: float = navigation_stuck_min_move_distance * navigation_stuck_min_move_distance
		if following_nav:
			if not _was_following_nav:
				_nav_stuck_accum = 0.0
				_nav_stuck_last_pos = global_position
			elif global_position.distance_squared_to(_nav_stuck_last_pos) > min_d2:
				_nav_stuck_last_pos = global_position
				_nav_stuck_accum = 0.0
			else:
				_nav_stuck_accum += delta
				if _nav_stuck_accum >= navigation_stuck_time_sec:
					_cancel_navigation_stuck()
		else:
			_nav_stuck_accum = 0.0
			_nav_stuck_last_pos = global_position
		_was_following_nav = not manual and not _nav_agent.is_navigation_finished()

	if _pickup_area != null and _should_auto_pickup():
		var auto_grounds: Array = _collect_ground_items_sorted()
		for node in auto_grounds:
			var gi: GroundItem = node as GroundItem
			if gi != null:
				_try_pickup_ground(gi)


func _should_auto_pickup() -> bool:
	if user_controlled:
		return player_auto_pickup
	if _npc_behavior:
		return _npc_behavior.npc_auto_pickup
	return true


func _vector_to_facing(d: Vector2) -> String:
	var t := 0.45
	var hx := d.x
	var hy := d.y
	if absf(hx) > t and absf(hy) > t:
		if hx > 0.0 and hy < 0.0:
			return "up_right"
		if hx > 0.0 and hy > 0.0:
			return "down_right"
		if hx < 0.0 and hy < 0.0:
			return "up_left"
		return "down_left"
	if absf(hx) > absf(hy):
		return "right" if hx > 0.0 else "left"
	return "down" if hy > 0.0 else "up"
