extends Node
class_name NpcBehavior
## 挂在 [NekomimiWalker] 下：游荡、环境台词、**战斗 AI 状态机**（追击 / 逃跑 / 脱战）、自动拾取等。
## 需要 NPC 与箱子/储物格交互时：拿到储物容器节点（`item_container.gd`），调用 `deposit_from_walker` / `withdraw_to_walker`（与 [ContainerPanel] 共用实现，无需 UI）。

enum AiState {
	WANDER, ## 随机游荡（由到达目标等信号驱动）
	COMBAT, ## 追击威胁并进入近战则出手
	FLEE, ## 拉远距离，持续一段时间后再评估
}

@export_group("Items (NPC)")
@export var npc_auto_pickup: bool = true

@export_group("Wander")
@export var wander_enabled: bool = true
@export var wander_center: Vector2 = Vector2.ZERO
@export var wander_half_extents: Vector2 = Vector2(240, 180)
@export var wander_min_step_distance: float = 36.0
@export var wander_min_idle_sec: float = 0.35
@export var wander_max_idle_sec: float = 1.75
@export var flee_wander_suppress_sec: float = 2.8

@export_group("Ambient speech")
@export var random_speech_enabled: bool = true
@export var random_speech_interval_min_sec: float = 8.0
@export var random_speech_interval_max_sec: float = 22.0
@export var npc_speech_lines: Array[String] = []

@export_group("Combat AI (state machine)")
## 关闭后受击只播台词，不进入追击/逃跑状态（仍游荡）。
@export var combat_ai_enabled: bool = true
## 当前生命低于最大生命的该比例时，受击优先进入 [enum AiState.FLEE]。
@export var flee_hp_ratio: float = 0.35
## 进入战斗后，与威胁距离超过此值则脱战回游荡。
@export var combat_disengage_radius: float = 520.0
## 进入近战尝试普攻的距离（像素，近似）。
@export var melee_range: float = 105.0
## 状态机里两次普攻尝试的最小间隔（秒）。
@export var ai_attack_interval: float = 0.55
## [AiState.FLEE] 单次持续至少这么久再重新评估（秒）。
@export var flee_state_min_sec: float = 2.0
## [AiState.COMBAT] 下若这么久**没再挨打**，视为仇恨消失，回游荡。
@export var combat_no_damage_timeout_sec: float = 5.0
## [AiState.FLEE] 下若这么久**没再挨打**，视为冷静下来，回游荡。
@export var flee_no_damage_timeout_sec: float = 4.0

@export_group("State speech (empty = skip)")
## 进入战斗（受击后高血线）；与受伤台词错开，略延迟播放。
@export var speech_enter_combat: Array[String] = ["来啊！", "别想跑！", "站住！"]
## 进入逃跑（低血线受击）。
@export var speech_enter_flee: Array[String] = ["先撤一步…", "好疼…"]
## 因「太久没挨打」退出战斗。
@export var speech_calm_exit_combat: Array[String] = ["不追了…", "跑哪去了？", "算了。"]
## 因「太久没挨打」退出逃跑。
@export var speech_calm_exit_flee: Array[String] = ["呼…应该没事了", "安全了吗…"]
## 因追太远脱战。
@export var speech_disengage_distance: Array[String] = ["太远了…", "先不追了。"]
## 威胁无效 / 已死。
@export var speech_threat_lost: Array[String] = ["人呢？", "结束了？"]
## 逃跑后血线回升，从逃跑切回战斗追击。
@export var speech_reengage_from_flee: Array[String] = ["还没完！", "再来！"]
## 用户交还操控权后回到游荡。
@export var speech_resume_wander: Array[String] = []
## [COMBAT] 中每隔 [member combat_taunt_interval_sec] 秒播一句（0=关闭）。
@export var combat_taunt_interval_sec: float = 0.0
@export var speech_combat_taunt: Array[String] = ["别躲！", "吃我一拳！"]
## [FLEE] 中每隔 [member flee_mutter_interval_sec] 秒播一句（0=关闭）。
@export var flee_mutter_interval_sec: float = 0.0
@export var speech_flee_mutter: Array[String] = ["快跑…", "别追了…"]

@export_group("On hurt (speech only)")
@export var hurt_speech_enabled: bool = true
@export var hurt_speech_lines: Array[String] = []

var _countdown: float = 0.0
var _wander_center_world: Vector2 = Vector2.ZERO
var _wander_block_until: float = 0.0

var _ai_state: AiState = AiState.WANDER
var _threat: Node2D = null
var _flee_reeval_at: float = 0.0
var _next_attack_at: float = 0.0
## 上一次**挨打**（[method notify_hurt]）的时间，用于战斗/逃跑「仇恨冷却」。
var _last_damage_time_sec: float = -1.0
var _next_combat_taunt_at: float = 0.0
var _next_flee_mutter_at: float = 0.0

const _DEFAULT_HURT_LINES: PackedStringArray = ["呜…好痛！", "别打啦喵！", "好过分！", "好疼…"]


func _ready() -> void:
	if not (get_parent() is NekomimiWalker):
		set_process(false)
		set_physics_process(false)
		return
	if not _walker_is_npc():
		set_process(false)
		set_physics_process(false)
		return
	if random_speech_enabled:
		_reset_timer()
	else:
		set_process(false)
	set_physics_process(combat_ai_enabled)
	if wander_enabled:
		_start_wander_routine()


func _walker_is_npc() -> bool:
	var w: Node = get_parent()
	return w is NekomimiWalker and not (w as NekomimiWalker).user_controlled


## 用户结束操控、改回 AI 时由 [NekomimiWalker] 调用，恢复游荡与战斗状态机。
func resume_after_control() -> void:
	if not _walker_is_npc():
		return
	_ai_state = AiState.WANDER
	_threat = null
	_last_damage_time_sec = -1.0
	if random_speech_enabled:
		set_process(true)
		_reset_timer()
	else:
		set_process(false)
	set_physics_process(combat_ai_enabled)
	_say_from_pool(speech_resume_wander)
	if wander_enabled:
		call_deferred("_pick_and_go")


func _start_wander_routine() -> void:
	await get_tree().process_frame
	if not _walker_is_npc() or not wander_enabled:
		return
	var w: NekomimiWalker = get_parent() as NekomimiWalker
	if w == null:
		return
	_wander_center_world = wander_center
	if _wander_center_world == Vector2.ZERO:
		_wander_center_world = w.global_position
	if not w.destination_reached.is_connected(_on_wander_destination_reached):
		w.destination_reached.connect(_on_wander_destination_reached)
	if not w.navigation_stuck.is_connected(_on_wander_navigation_stuck):
		w.navigation_stuck.connect(_on_wander_navigation_stuck)
	await get_tree().create_timer(randf_range(0.08, 0.35)).timeout
	_pick_and_go()


func _now_sec() -> float:
	return Time.get_ticks_msec() * 0.001


func _wander_blocked() -> bool:
	return _now_sec() < _wander_block_until


func _suppress_wander_for_flee() -> void:
	var until: float = _now_sec() + maxf(0.0, flee_wander_suppress_sec)
	if until > _wander_block_until:
		_wander_block_until = until


func _await_wander_unblock() -> void:
	var t: float = _wander_block_until - _now_sec()
	if t > 0.0:
		await get_tree().create_timer(t).timeout


func _on_wander_destination_reached() -> void:
	if _ai_state != AiState.WANDER or not wander_enabled or not _walker_is_npc():
		return
	await get_tree().create_timer(randf_range(wander_min_idle_sec, wander_max_idle_sec)).timeout
	await _await_wander_unblock()
	_pick_and_go()


func _on_wander_navigation_stuck() -> void:
	if _ai_state != AiState.WANDER or not wander_enabled or not _walker_is_npc():
		return
	await get_tree().create_timer(randf_range(0.12, 0.4)).timeout
	await _await_wander_unblock()
	_pick_and_go()


func _pick_and_go() -> void:
	if _ai_state != AiState.WANDER or not wander_enabled or not _walker_is_npc():
		return
	if _wander_blocked():
		return
	var w: NekomimiWalker = get_parent() as NekomimiWalker
	if w == null:
		return
	var min_d2: float = wander_min_step_distance * wander_min_step_distance
	var target := Vector2.ZERO
	for _i in range(12):
		var x := randf_range(
			_wander_center_world.x - wander_half_extents.x,
			_wander_center_world.x + wander_half_extents.x
		)
		var y := randf_range(
			_wander_center_world.y - wander_half_extents.y,
			_wander_center_world.y + wander_half_extents.y
		)
		target = Vector2(x, y)
		if target.distance_squared_to(w.global_position) >= min_d2:
			break
	w.move_to(target)


func _process(delta: float) -> void:
	if not _walker_is_npc() or not random_speech_enabled:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		say_random_line()
		_reset_timer()


func _physics_process(_delta: float) -> void:
	if not combat_ai_enabled or not _walker_is_npc():
		return
	var w: NekomimiWalker = get_parent() as NekomimiWalker
	if w == null or w.hp <= 0:
		return
	match _ai_state:
		AiState.WANDER:
			pass
		AiState.COMBAT:
			_tick_combat(w)
		AiState.FLEE:
			_tick_flee(w)


func _resolve_threat() -> void:
	if _threat != null and is_instance_valid(_threat):
		return
	var n: Node = get_tree().get_first_node_in_group("controlled_nekomimi")
	if n is Node2D:
		_threat = n as Node2D


func _tick_combat(w: NekomimiWalker) -> void:
	if _last_damage_time_sec >= 0.0 and (_now_sec() - _last_damage_time_sec) > combat_no_damage_timeout_sec:
		_say_from_pool(speech_calm_exit_combat)
		_enter_wander("combat_calm")
		return
	_resolve_threat()
	if _threat == null or not is_instance_valid(_threat):
		_say_from_pool(speech_threat_lost)
		_enter_wander("threat_lost")
		return
	var tw: NekomimiWalker = _threat as NekomimiWalker
	if tw != null and tw.hp <= 0:
		_say_from_pool(speech_threat_lost)
		_enter_wander("threat_dead")
		return
	var d: float = w.global_position.distance_to(_threat.global_position)
	if d > combat_disengage_radius:
		_say_from_pool(speech_disengage_distance)
		_enter_wander("disengage")
		return
	if combat_taunt_interval_sec > 0.0 and not speech_combat_taunt.is_empty():
		if _now_sec() >= _next_combat_taunt_at:
			_say_from_pool(speech_combat_taunt)
			_next_combat_taunt_at = _now_sec() + combat_taunt_interval_sec
	w.move_to(_threat.global_position)
	if d <= melee_range and _now_sec() >= _next_attack_at:
		w.face_toward_world(_threat.global_position)
		w.try_npc_attack(true)
		_next_attack_at = _now_sec() + maxf(0.12, ai_attack_interval)


func _tick_flee(w: NekomimiWalker) -> void:
	if _last_damage_time_sec >= 0.0 and (_now_sec() - _last_damage_time_sec) > flee_no_damage_timeout_sec:
		_say_from_pool(speech_calm_exit_flee)
		_enter_wander("flee_calm")
		return
	_resolve_threat()
	if _now_sec() < _flee_reeval_at:
		if flee_mutter_interval_sec > 0.0 and not speech_flee_mutter.is_empty() and _now_sec() >= _next_flee_mutter_at:
			_say_from_pool(speech_flee_mutter)
			_next_flee_mutter_at = _now_sec() + flee_mutter_interval_sec
		return
	var max_hp: int = maxi(1, w.combat_max_hp)
	var ratio: float = float(w.hp) / float(max_hp)
	if ratio > flee_hp_ratio + 0.08 and (_threat == null or w.global_position.distance_to(_threat.global_position) > combat_disengage_radius * 0.85):
		_enter_wander("flee_recover")
		return
	if ratio <= flee_hp_ratio and _threat != null and is_instance_valid(_threat):
		_apply_flee(w, _threat)
		_flee_reeval_at = _now_sec() + flee_state_min_sec
	else:
		_say_from_pool(speech_reengage_from_flee)
		_ai_state = AiState.COMBAT
		_next_attack_at = _now_sec()
		_next_combat_taunt_at = _now_sec() + combat_taunt_interval_sec if combat_taunt_interval_sec > 0.0 else 0.0


func _enter_wander(_reason: String = "") -> void:
	_ai_state = AiState.WANDER
	_threat = null
	_last_damage_time_sec = -1.0
	_wander_block_until = 0.0
	if wander_enabled:
		call_deferred("_pick_and_go")


func _enter_combat(w: NekomimiWalker, attacker: Node) -> void:
	if attacker is Node2D:
		_threat = attacker as Node2D
	_ai_state = AiState.COMBAT
	_suppress_wander_for_flee()
	_next_attack_at = _now_sec() + 0.08
	_next_combat_taunt_at = _now_sec() + combat_taunt_interval_sec if combat_taunt_interval_sec > 0.0 else 0.0
	if _threat != null:
		w.move_to(_threat.global_position)
	_schedule_state_line(speech_enter_combat, 0.42)


func _enter_flee(w: NekomimiWalker, attacker: Node) -> void:
	if attacker is Node2D:
		_threat = attacker as Node2D
	_ai_state = AiState.FLEE
	_apply_flee(w, attacker)
	_flee_reeval_at = _now_sec() + flee_state_min_sec
	_next_flee_mutter_at = _now_sec() + flee_mutter_interval_sec if flee_mutter_interval_sec > 0.0 else 0.0
	_schedule_state_line(speech_enter_flee, 0.42)


## 由 [method NekomimiWalker.take_damage] 调用：只负责台词 + 状态迁移（不再用单独计时器「条件反射」反击）。
func notify_hurt(attacker: Node) -> void:
	var w: NekomimiWalker = get_parent() as NekomimiWalker
	if w == null:
		return
	if _walker_is_npc():
		_last_damage_time_sec = _now_sec()
	if hurt_speech_enabled:
		var pool: Array[String] = hurt_speech_lines.duplicate()
		if pool.is_empty():
			for s in _DEFAULT_HURT_LINES:
				pool.append(String(s))
		if not pool.is_empty():
			w.talk(pool.pick_random())
	if not _walker_is_npc():
		return
	if not combat_ai_enabled:
		return
	var max_hp: int = maxi(1, w.combat_max_hp)
	var ratio: float = float(w.hp) / float(max_hp)
	if ratio <= flee_hp_ratio:
		_enter_flee(w, attacker)
	else:
		_enter_combat(w, attacker)


func _apply_flee(w: NekomimiWalker, attacker: Node) -> void:
	var away: Vector2 = Vector2.RIGHT * 80.0
	if attacker is Node2D:
		away = w.global_position - (attacker as Node2D).global_position
	if away.length_squared() < 4.0:
		away = Vector2(1, 0).rotated(randf() * TAU) * 40.0
	var dist: float = maxf(120.0, combat_disengage_radius * 0.55)
	away = away.normalized() * dist
	_suppress_wander_for_flee()
	w.move_to(w.global_position + away)


func _say_from_pool(lines: Array[String]) -> void:
	if lines.is_empty():
		return
	var w: NekomimiWalker = get_parent() as NekomimiWalker
	if w == null:
		return
	w.talk(lines.pick_random())


func _schedule_state_line(lines: Array[String], delay_sec: float) -> void:
	if lines.is_empty():
		return
	get_tree().create_timer(delay_sec).timeout.connect(func() -> void:
		var ww: NekomimiWalker = get_parent() as NekomimiWalker
		if ww == null or not is_instance_valid(self) or not _walker_is_npc():
			return
		ww.talk(lines.pick_random())
	, CONNECT_ONE_SHOT)


func _reset_timer() -> void:
	var lo: float = minf(random_speech_interval_min_sec, random_speech_interval_max_sec)
	var hi: float = maxf(random_speech_interval_min_sec, random_speech_interval_max_sec)
	_countdown = randf_range(lo, hi)


func say_random_line() -> void:
	var w: NekomimiWalker = get_parent() as NekomimiWalker
	if w == null:
		return
	var lines: Array[String] = npc_speech_lines if not npc_speech_lines.is_empty() else w.speech_lines
	if lines.is_empty():
		return
	w.talk(lines.pick_random())
