extends Node2D
## 商店交互点：角色站在范围内按 [kbd]F[/kbd] 可打开 [ShopPanel]；脚本也提供 NPC 可直接调用的买卖接口（不依赖 UI）。

signal shop_changed
signal interaction_state_changed

@export var display_name: String = "商店"
@export var interact_radius: float = 92.0
## 为空时自动按 [method ItemDB.all_item_ids] 填充；可在 Inspector 配成“只卖某几样”。
@export var sell_item_ids: Array[String] = []
## 商店卖出倍率（玩家购买价 = [code]ItemDB.price * buy_price_multiplier[/code]）。
@export var buy_price_multiplier: float = 1.0
## 商店回收倍率（玩家卖出价 = [code]ItemDB.price * sell_price_multiplier[/code]）。
@export var sell_price_multiplier: float = 0.6
## 用于商店标记展示的图标 id。
@export var preview_item_id: String = "misc_golden_coin"

var _interact_area: Area2D
var _near_controlled_count: int = 0
var _cached_sell_ids: Array[String] = []
var _session_owner: NekomimiWalker
const MONEY_ITEM_ID: String = "misc_copper_coin"

@onready var _hint: Label = $HintLabel


func _ready() -> void:
	add_to_group("shop_point")
	add_to_group("interactable_facility")
	_interact_area = $InteractArea
	var sh: CollisionShape2D = $InteractArea/CollisionShape2D
	if sh != null and sh.shape is CircleShape2D:
		(sh.shape as CircleShape2D).radius = interact_radius
	_interact_area.body_entered.connect(_on_body_entered)
	_interact_area.body_exited.connect(_on_body_exited)
	_refresh_sprite()
	_rebuild_sell_ids()
	if _hint != null:
		_hint.visible = false
		_hint.text = "F 交易"


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


func _rebuild_sell_ids() -> void:
	_cached_sell_ids.clear()
	if sell_item_ids.is_empty():
		_cached_sell_ids = ItemDB.all_item_ids()
	else:
		for id in sell_item_ids:
			if ItemDB.has_id(id):
				_cached_sell_ids.append(id)
	_cached_sell_ids = _cached_sell_ids.filter(func(id: String) -> bool:
		return id != MONEY_ITEM_ID and ItemDB.get_price(id, 0) > 0
	)
	_cached_sell_ids.sort()
	shop_changed.emit()


func is_walker_in_range(walker: CharacterBody2D) -> bool:
	return _interact_area != null and _interact_area.overlaps_body(walker)


func get_interact_label() -> String:
	return "商店 · %s" % display_name if not display_name.is_empty() else "商店"


func build_f_interact_entry(walker: NekomimiWalker) -> Dictionary:
	if walker == null or not can_interact(walker):
		return {}
	return {
		"node": self,
		"label": get_interact_label(),
		"d2": walker.global_position.distance_squared_to(global_position),
	}


func open_player_interaction(host: Node, walker: NekomimiWalker) -> bool:
	if host == null or walker == null:
		return false
	return host.has_method("open_shop_for_target") and bool(host.call("open_shop_for_target", walker, self))


func get_current_user() -> NekomimiWalker:
	if _session_owner == null or not is_instance_valid(_session_owner):
		return null
	return _session_owner


func is_busy() -> bool:
	return get_current_user() != null


func can_interact(walker: NekomimiWalker) -> bool:
	if walker == null:
		return false
	if not is_walker_in_range(walker):
		return false
	var session_user: NekomimiWalker = get_current_user()
	return session_user == null or session_user == walker


func try_acquire(walker: NekomimiWalker) -> bool:
	if not can_interact(walker):
		return false
	if get_current_user() == walker:
		return true
	_session_owner = walker
	interaction_state_changed.emit()
	return true


func release(walker: NekomimiWalker) -> void:
	var session_user: NekomimiWalker = get_current_user()
	if session_user == null:
		return
	if walker != null and session_user != walker:
		return
	_session_owner = null
	interaction_state_changed.emit()


func get_sell_item_ids() -> Array[String]:
	return _cached_sell_ids.duplicate()


func get_buy_price(item_id: String) -> int:
	var base: int = ItemDB.get_price(item_id, 0)
	return maxi(0, ceili(float(base) * maxf(0.0, buy_price_multiplier)))


func get_sell_price(item_id: String) -> int:
	var base: int = ItemDB.get_price(item_id, 0)
	if base <= 0:
		return 0
	return maxi(1, floori(float(base) * maxf(0.0, sell_price_multiplier)))


## NPC/脚本接口：尝试购买 [param count] 个，返回实际买到数量。
func buy_to_walker(walker: NekomimiWalker, item_id: String, count: int = 1) -> int:
	if walker == null or count <= 0:
		return 0
	if not ItemDB.has_id(item_id):
		return 0
	if item_id not in _cached_sell_ids:
		return 0
	var price_each: int = get_buy_price(item_id)
	if price_each <= 0:
		return 0
	var ok: int = 0
	for _i in range(count):
		if walker.get_money() < price_each:
			break
		var left: int = walker.add_item_to_inventory(item_id, 1)
		if left > 0:
			break
		if not walker.spend_money(price_each):
			walker.remove_items_from_inventory_by_id(item_id, 1)
			break
		ok += 1
	return ok


## NPC/脚本接口：尝试把背包第 [param slot_index] 格卖给商店，返回实际卖出数量。
func sell_from_walker(walker: NekomimiWalker, slot_index: int, amount: int = 1) -> int:
	if walker == null or amount == 0:
		return 0
	if slot_index < 0 or slot_index >= walker.inventory.size():
		return 0
	var slot: Dictionary = walker.inventory[slot_index]
	var item_id: String = str(slot.get("id", ""))
	var can: int = int(slot.get("count", 0))
	if can <= 0 or item_id.is_empty():
		return 0
	var price_each: int = get_sell_price(item_id)
	if price_each <= 0:
		return 0
	var req: int = can if amount < 0 else mini(can, amount)
	var removed: int = ItemDB.remove_items_from_slot(walker.inventory, slot_index, req)
	if removed <= 0:
		return 0
	var earned: int = walker.earn_money(price_each * removed)
	var sold: int = removed
	if earned < price_each * removed and price_each > 0:
		sold = floori(float(earned) / float(price_each))
		var rollback: int = removed - sold
		if rollback > 0:
			walker.add_item_to_inventory(item_id, rollback)
	if sold > 0:
		walker.inventory_changed.emit()
	return sold


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
