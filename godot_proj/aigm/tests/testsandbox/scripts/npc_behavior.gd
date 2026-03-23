extends Node
class_name NpcBehavior
## 挂在 [NekomimiWalker] 下：游荡、环境台词、**战斗 AI 状态机**（追击 / 逃跑 / 脱战）、**觅食**（饱食度低时吃面包 / 找地面与容器）、自动拾取等。
## 需要角色与箱子/储物格交互（不经 UI）时：拿到储物容器节点（`item_container.gd`），调用 `deposit_from_walker` / `withdraw_to_walker`（与 [ContainerPanel] 共用实现）。

enum AiState {
	WANDER, ## 随机游荡（由到达目标等信号驱动）
	COMBAT, ## 追击威胁并进入近战则出手
	FLEE, ## 拉远距离，持续一段时间后再评估
	FORAGE, ## 饱食度低：优先吃背包 → 靠近地面食物 → 靠近容器取食 → 附近乱走搜刮
}

@export_group("Items (AI behavior)")
## 非用户操控时是否靠近即自动拾取地面物品（与 [member NekomimiWalker.player_auto_pickup] 对应）。
@export var npc_auto_pickup: bool = true

@export_group("Forage (AI)")
## 饱食度低于 [member forage_enter_below_ratio]×满饱食时进入觅食（[NpcBehavior] 仅在非用户操控时运行）；与战斗/逃跑互斥（饥饿不抢战斗）。
@export var forage_enabled: bool = true
## 进入觅食的相对阈值（相对 [member NekomimiWalker.satiation_max]）。
@export_range(0.05, 0.95, 0.01) var forage_enter_below_ratio: float = 0.38
## 吃饱后退出觅食的相对阈值，应大于 [member forage_enter_below_ratio] 形成滞回。
@export_range(0.1, 1.0, 0.01) var forage_exit_above_ratio: float = 0.62
## 当某食物未配置 `food_satiation` 时，使用该默认回复值。
@export var forage_default_food_restore: float = 16.0
## 只考虑该距离内的地面物品与容器（像素）。
@export var forage_max_search_radius: float = 880.0
## 视野内没有食物时，隔多久换一次「乱走」探路目标。
@export var forage_explore_interval_sec: float = 1.75
## 全图扫描「地面食物 / 容器」的最小间隔，避免每帧 [method Node.get_nodes_in_group]。
@export var forage_rescan_interval_sec: float = 0.45
## NPC 吃掉食物时的动作时长（秒）；期间移动/寻路被锁定并显示脚下进度条。
@export var forage_eat_duration_sec: float = 1.05

@export_group("Forage speech (empty = skip)")
@export var speech_enter_forage: Array[String] = ["肚子饿了喵…", "想吃点面包…", "去找点吃的。"]

@export_group("Wander")
## 是否启用随机游荡（到达目标后再选点）。
@export var wander_enabled: bool = true
## 游荡矩形中心（世界坐标）；[code](0,0)[/code] 表示用角色开局位置。
@export var wander_center: Vector2 = Vector2.ZERO
## 游荡矩形半宽、半高（像素）。
@export var wander_half_extents: Vector2 = Vector2(240, 180)
## 新目标与当前位置至少相隔此距离（像素），避免抖脚。
@export var wander_min_step_distance: float = 36.0
## 到达游荡点后停留时间的下限（秒）。
@export var wander_min_idle_sec: float = 0.35
## 到达游荡点后停留时间的上限（秒）。
@export var wander_max_idle_sec: float = 1.75
## 进入逃跑后这段时间内不重新选游荡点（避免与逃跑位移打架）。
@export var flee_wander_suppress_sec: float = 2.8

@export_group("Ambient speech")
## 是否启用定时随机环境台词（与战斗台词独立）。
@export var random_speech_enabled: bool = true
## 两句环境台词之间的最短间隔（秒）。
@export var random_speech_interval_min_sec: float = 8.0
## 两句环境台词之间的最长间隔（秒）。
@export var random_speech_interval_max_sec: float = 22.0
## 非空时覆盖 [member NekomimiWalker.speech_lines] 作为随机池。
@export var npc_speech_lines: Array[String] = []

@export_group("Combat AI (state machine)")
## 关闭后受击只播台词，不进入追击/逃跑状态（仍游荡）。
@export var combat_ai_enabled: bool = true
## 当前生命低于最大生命的该比例时，受击优先进入 [enum AiState.FLEE]。
@export var flee_hp_ratio: float = 0.35
## 与威胁距离超过此值则退出战斗回游荡（像素）。
@export var combat_disengage_radius: float = 520.0
## 进入近战并尝试 [method NekomimiWalker.try_npc_attack] 的大致距离（像素）。
@export var melee_range: float = 105.0
## 战斗中两次普攻尝试的最小间隔（秒）。
@export var ai_attack_interval: float = 0.55
## [AiState.FLEE] 状态下至少持续这么久才允许重新评估是否追击/继续逃。
@export var flee_state_min_sec: float = 2.0
## [AiState.COMBAT] 下若这么久**没再挨打**，视为脱战回游荡。
@export var combat_no_damage_timeout_sec: float = 5.0
## [AiState.FLEE] 下若这么久**没再挨打**，视为冷静回游荡。
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
## [AiState.COMBAT] 中每隔多少秒播一句 [member speech_combat_taunt]（0=关闭）。
@export var combat_taunt_interval_sec: float = 0.0
## 战斗嘲讽台词池。
@export var speech_combat_taunt: Array[String] = ["别躲！", "吃我一拳！"]
## [AiState.FLEE] 中每隔多少秒播一句 [member speech_flee_mutter]（0=关闭）。
@export var flee_mutter_interval_sec: float = 0.0
## 逃跑碎碎念台词池。
@export var speech_flee_mutter: Array[String] = ["快跑…", "别追了…"]

@export_group("On hurt (speech only)")
## 受击时是否播放 [member hurt_speech_lines]（与状态迁移独立）。
@export var hurt_speech_enabled: bool = true
## 非空则优先从中随机；空则用内置默认受伤句。
@export var hurt_speech_lines: Array[String] = []

## 环境随机台词：距离下次播放的剩余时间（秒）。
var _countdown: float = 0.0
## 游荡矩形中心的世界坐标（由 [member wander_center] 或角色位置得到）。
var _wander_center_world: Vector2 = Vector2.ZERO
## 时间戳：在此之前不选新游荡点（逃跑抑制用）。
var _wander_block_until: float = 0.0

## 当前主状态机状态。
var _ai_state: AiState = AiState.WANDER
## 战斗/逃跑锁定的威胁目标（通常为 [code]controlled_nekomimi[/code]）。
var _threat: Node2D = null
## 逃跑子状态：下次允许重新评估的时刻。
var _flee_reeval_at: float = 0.0
## 下次允许发起普攻尝试的时刻。
var _next_attack_at: float = 0.0
## 上一次**挨打**（[method notify_hurt]）的时间，用于战斗/逃跑「仇恨冷却」。
var _last_damage_time_sec: float = -1.0
## 下次战斗嘲讽台词时刻。
var _next_combat_taunt_at: float = 0.0
## 下次逃跑碎碎念时刻。
var _next_flee_mutter_at: float = 0.0
## 觅食：锁定的地面 [GroundItem] 目标。
var _forage_ground_target: Node2D = null
## 觅食：锁定的 `item_container` 场景节点。
var _forage_container_target: Node2D = null
## 觅食：下次允许随机探路时刻。
var _forage_next_explore_at: float = 0.0
## 觅食：下次全图扫描食物/容器的时刻。
var _forage_next_scan_at: float = 0.0

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
	set_physics_process(combat_ai_enabled or forage_enabled)
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
	set_physics_process(combat_ai_enabled or forage_enabled)
	_clear_forage_targets()
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
	if not _walker_is_npc():
		return
	if not combat_ai_enabled and not forage_enabled:
		return
	var w: NekomimiWalker = get_parent() as NekomimiWalker
	if w == null or w.hp <= 0:
		return
	if forage_enabled and _ai_state == AiState.WANDER:
		if w.satiation <= w.satiation_max * forage_enter_below_ratio:
			_enter_forage_state()
	match _ai_state:
		AiState.WANDER:
			pass
		AiState.COMBAT:
			if combat_ai_enabled:
				_tick_combat(w)
		AiState.FLEE:
			if combat_ai_enabled:
				_tick_flee(w)
		AiState.FORAGE:
			if forage_enabled:
				_tick_forage(w)


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
	_clear_forage_targets()
	if wander_enabled:
		call_deferred("_pick_and_go")


func _enter_combat(w: NekomimiWalker, attacker: Node) -> void:
	_clear_forage_targets()
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
	_clear_forage_targets()
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


func _clear_forage_targets() -> void:
	_forage_ground_target = null
	_forage_container_target = null


func _enter_forage_state() -> void:
	_ai_state = AiState.FORAGE
	_clear_forage_targets()
	_forage_next_explore_at = _now_sec()
	_forage_next_scan_at = 0.0
	_say_from_pool(speech_enter_forage)


func _tick_forage(w: NekomimiWalker) -> void:
	if w.is_action_locked():
		return
	var exit_at: float = w.satiation_max * forage_exit_above_ratio
	if w.satiation >= exit_at:
		_enter_wander("forage_sated")
		return
	var consumed_id: String = _consume_any_food_from_inventory(w)
	if not consumed_id.is_empty():
		w.start_action_lock("进食中", forage_eat_duration_sec, consumed_id)
		_clear_forage_targets()
		if w.satiation >= exit_at:
			_enter_wander("forage_ate_inv")
		return
	if _forage_ground_target != null and not is_instance_valid(_forage_ground_target):
		_forage_ground_target = null
	if _forage_container_target != null and not is_instance_valid(_forage_container_target):
		_forage_container_target = null
	if _forage_ground_target != null:
		w.move_to(_forage_ground_target.global_position)
		return
	if _forage_container_target != null:
		w.move_to(_forage_container_target.global_position)
		if _forage_container_target.has_method("is_walker_in_range") and bool(_forage_container_target.call("is_walker_in_range", w)):
			_try_withdraw_food_from_container(w, _forage_container_target)
			_forage_container_target = null
		return
	if _now_sec() < _forage_next_scan_at:
		if _now_sec() >= _forage_next_explore_at:
			_pick_forage_explore(w)
		return
	_forage_next_scan_at = _now_sec() + maxf(0.08, forage_rescan_interval_sec)
	var gi2: GroundItem = _find_nearest_ground_food(w)
	var cn2: Node2D = _find_nearest_container_with_food(w)
	if gi2 != null and cn2 != null:
		var dg2: float = w.global_position.distance_squared_to(gi2.global_position)
		var dc2: float = w.global_position.distance_squared_to(cn2.global_position)
		if dg2 <= dc2:
			_forage_ground_target = gi2
			w.move_to(gi2.global_position)
		else:
			_forage_container_target = cn2
			w.move_to(cn2.global_position)
		return
	if gi2 != null:
		_forage_ground_target = gi2
		w.move_to(gi2.global_position)
		return
	if cn2 != null:
		_forage_container_target = cn2
		w.move_to(cn2.global_position)
		return
	if _now_sec() >= _forage_next_explore_at:
		_pick_forage_explore(w)


func _try_withdraw_food_from_container(w: NekomimiWalker, c: Node) -> void:
	var stor: Variant = c.get("storage")
	if not (stor is Array):
		return
	var slots: Array = stor as Array
	var si: int = _first_food_slot(slots)
	if si < 0:
		return
	var picked_id: String = str((slots[si] as Dictionary).get("id", ""))
	var got: int = 0
	if c.has_method("withdraw_to_walker"):
		got = c.call("withdraw_to_walker", w, si, 1)
	if got > 0:
		var sat_per: float = ItemDB.get_food_satiation(picked_id, forage_default_food_restore)
		w.consume_inventory_item_for_satiation(picked_id, got, sat_per)
		w.start_action_lock("进食中", forage_eat_duration_sec, picked_id)


func _find_nearest_ground_food(w: NekomimiWalker) -> GroundItem:
	var best: GroundItem = null
	var best_d2: float = INF
	var r2: float = forage_max_search_radius * forage_max_search_radius
	var p: Vector2 = w.global_position
	for n in get_tree().get_nodes_in_group("ground_item"):
		if not is_instance_valid(n) or not (n is GroundItem):
			continue
		var g: GroundItem = n as GroundItem
		if not ItemDB.is_food(g.item_id):
			continue
		var d2: float = p.distance_squared_to(g.global_position)
		if d2 <= r2 and d2 < best_d2:
			best = g
			best_d2 = d2
	return best


func _find_nearest_container_with_food(w: NekomimiWalker) -> Node2D:
	var best: Node2D = null
	var best_d2: float = INF
	var r2: float = forage_max_search_radius * forage_max_search_radius
	var p: Vector2 = w.global_position
	for n in get_tree().get_nodes_in_group("item_container"):
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		var stor: Variant = n.get("storage")
		if not (stor is Array):
			continue
		if _first_food_slot(stor as Array) < 0:
			continue
		var d2: float = p.distance_squared_to((n as Node2D).global_position)
		if d2 <= r2 and d2 < best_d2:
			best = n as Node2D
			best_d2 = d2
	return best


func _consume_any_food_from_inventory(w: NekomimiWalker) -> String:
	var best_id: String = ""
	var best_sat: float = 0.0
	for slot in w.inventory:
		if not (slot is Dictionary):
			continue
		var sid: String = str((slot as Dictionary).get("id", ""))
		var sat: float = ItemDB.get_food_satiation(sid, 0.0)
		if sat <= 0.0:
			continue
		if sat > best_sat:
			best_sat = sat
			best_id = sid
	if best_id.is_empty():
		return ""
	var sat_per: float = ItemDB.get_food_satiation(best_id, forage_default_food_restore)
	return best_id if w.consume_inventory_item_for_satiation(best_id, 1, sat_per) > 0 else ""


func _first_food_slot(slots: Array) -> int:
	var best_idx: int = -1
	var best_sat: float = -1.0
	for i in range(slots.size()):
		var slot: Variant = slots[i]
		if not (slot is Dictionary):
			continue
		var sid: String = str((slot as Dictionary).get("id", ""))
		var sat: float = ItemDB.get_food_satiation(sid, 0.0)
		if sat <= 0.0:
			continue
		if sat > best_sat:
			best_sat = sat
			best_idx = i
	return best_idx


func _pick_forage_explore(w: NekomimiWalker) -> void:
	var cx: float = _wander_center_world.x
	var cy: float = _wander_center_world.y
	if _wander_center_world == Vector2.ZERO:
		cx = w.global_position.x
		cy = w.global_position.y
	var hx: float = wander_half_extents.x
	var hy: float = wander_half_extents.y
	var step: float = mini(hx, hy) * 0.45
	var x: float = clampf(w.global_position.x + randf_range(-step, step), cx - hx, cx + hx)
	var y: float = clampf(w.global_position.y + randf_range(-step, step), cy - hy, cy + hy)
	w.move_to(Vector2(x, y))
	_forage_next_explore_at = _now_sec() + forage_explore_interval_sec


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
