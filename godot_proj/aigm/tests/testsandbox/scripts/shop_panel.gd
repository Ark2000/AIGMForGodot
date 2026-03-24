extends CanvasLayer
## 商店 UI：左侧“商店无限库存”，右侧“角色背包”；支持购买与出售，并预留 NPC 可复用的商店脚本接口。

@onready var _title: Label = $CenterContainer/PanelRoot/Margin/VBox/TitleLabel
@onready var _money_label: Label = $CenterContainer/PanelRoot/Margin/VBox/MoneyLabel
@onready var _shop_list: ItemList = $CenterContainer/PanelRoot/Margin/VBox/HBox/ShopVBox/ShopList
@onready var _player_list: ItemList = $CenterContainer/PanelRoot/Margin/VBox/HBox/PlayerVBox/PlayerList
@onready var _btn_buy_one: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/MidButtons/BuyOneButton
@onready var _btn_buy_ten: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/MidButtons/BuyTenButton
@onready var _btn_sell_one: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/MidButtons/SellOneButton
@onready var _btn_sell_all: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/MidButtons/SellAllButton
@onready var _btn_close: Button = $CenterContainer/PanelRoot/Margin/VBox/CloseButton
@onready var _hint: Label = $CenterContainer/PanelRoot/Margin/VBox/HintLabel
@onready var _center: Control = $CenterContainer
@onready var _panel_root: Control = $CenterContainer/PanelRoot

var _walker: NekomimiWalker
var _shop: Node2D
var _shop_item_ids: Array[String] = []
var _session_actor_label: String = ""
var _follow_head_offset: Vector2 = Vector2(0.0, -92.0)


func _ready() -> void:
	add_to_group("shop_panel")
	layer = 26
	follow_viewport_enabled = true
	follow_viewport_scale = 1.0
	visible = false
	_shop_list.fixed_icon_size = Vector2i(28, 28)
	_shop_list.icon_mode = ItemList.ICON_MODE_LEFT
	_player_list.fixed_icon_size = Vector2i(28, 28)
	_player_list.icon_mode = ItemList.ICON_MODE_LEFT
	_btn_buy_one.pressed.connect(_on_buy_one)
	_btn_buy_ten.pressed.connect(_on_buy_ten)
	_btn_sell_one.pressed.connect(_on_sell_one)
	_btn_sell_all.pressed.connect(_on_sell_all)
	_btn_close.pressed.connect(close)
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## 由 [method NekomimiWalker] 在按 [kbd]F[/kbd] 时调用：优先开关商店 UI；否则返回 [code]false[/code] 给其它交互（如容器、拾取）。
func try_handle_f(walker: NekomimiWalker) -> bool:
	if not walker.user_controlled:
		return false
	if visible:
		close()
		return true
	var s: Node2D = _find_nearest_shop(walker)
	if s == null:
		return false
	return open(walker, s)


func open_for_target(walker: NekomimiWalker, shop: Node2D) -> bool:
	if walker == null or shop == null:
		return false
	if not walker.user_controlled:
		return false
	if not shop.has_method("is_walker_in_range") or not bool(shop.call("is_walker_in_range", walker)):
		return false
	if visible and _shop == shop and _walker == walker:
		close()
		return true
	return open(walker, shop)


func open_session(walker: NekomimiWalker, shop: Node2D, actor_label: String = "") -> bool:
	_session_actor_label = actor_label
	return open(walker, shop)


func _find_nearest_shop(walker: NekomimiWalker) -> Node2D:
	var best: Node2D = null
	var best_d2: float = INF
	for n in walker.get_tree().get_nodes_in_group("shop_point"):
		if not (n is Node2D):
			continue
		var n2: Node2D = n as Node2D
		if not n2.has_method("is_walker_in_range"):
			continue
		if not n2.is_walker_in_range(walker):
			continue
		var d2: float = walker.global_position.distance_squared_to(n2.global_position)
		if d2 < best_d2:
			best = n2
			best_d2 = d2
	return best


func open(walker: NekomimiWalker, shop: Node2D) -> bool:
	if walker == null or shop == null:
		return false
	if shop.has_method("try_acquire") and not bool(shop.call("try_acquire", walker)):
		return false
	if _walker != null and is_instance_valid(_walker) and _walker.inventory_changed.is_connected(_on_inventory_changed):
		_walker.inventory_changed.disconnect(_on_inventory_changed)
	if _shop != null and is_instance_valid(_shop) and _shop.is_connected("shop_changed", _on_shop_changed):
		_shop.disconnect("shop_changed", _on_shop_changed)
	if _shop != null and is_instance_valid(_shop) and _shop.is_connected("interaction_state_changed", _on_interaction_state_changed):
		_shop.disconnect("interaction_state_changed", _on_interaction_state_changed)
	_walker = walker
	_shop = shop
	var who: String = _session_actor_label
	if who.is_empty():
		who = str(walker.name)
	_title.text = "%s（使用者：%s）" % [str(shop.get("display_name")), who]
	if not _walker.inventory_changed.is_connected(_on_inventory_changed):
		_walker.inventory_changed.connect(_on_inventory_changed)
	if not _shop.is_connected("shop_changed", _on_shop_changed):
		_shop.connect("shop_changed", _on_shop_changed)
	if _shop.has_signal("interaction_state_changed") and not _shop.is_connected("interaction_state_changed", _on_interaction_state_changed):
		_shop.connect("interaction_state_changed", _on_interaction_state_changed)
	visible = true
	_hint.text = "占用中：仅当前使用者可操作。F/Esc 关闭"
	_refresh_lists()
	set_process(true)
	_update_follow_position()
	return true


func close() -> void:
	visible = false
	if _walker != null and is_instance_valid(_walker) and _walker.inventory_changed.is_connected(_on_inventory_changed):
		_walker.inventory_changed.disconnect(_on_inventory_changed)
	if _shop != null and is_instance_valid(_shop) and _shop.is_connected("shop_changed", _on_shop_changed):
		_shop.disconnect("shop_changed", _on_shop_changed)
	if _shop != null and is_instance_valid(_shop) and _shop.is_connected("interaction_state_changed", _on_interaction_state_changed):
		_shop.disconnect("interaction_state_changed", _on_interaction_state_changed)
	if _shop != null and is_instance_valid(_shop) and _shop.has_method("release"):
		_shop.call("release", _walker)
	_walker = null
	_shop = null
	_shop_item_ids.clear()
	_session_actor_label = ""
	set_process(false)


func close_if_actor(walker: NekomimiWalker) -> void:
	if not visible:
		return
	if _walker != walker:
		return
	close()


func _on_inventory_changed() -> void:
	if visible:
		_refresh_lists()


func _on_shop_changed() -> void:
	if visible:
		_refresh_lists()


func _on_interaction_state_changed() -> void:
	if not visible or _shop == null:
		return
	if _shop.has_method("get_current_user"):
		var session_user: NekomimiWalker = _shop.call("get_current_user") as NekomimiWalker
		if session_user != _walker:
			close()


func _process(_delta: float) -> void:
	if visible:
		_update_follow_position()


func _update_follow_position() -> void:
	if _walker == null or not is_instance_valid(_walker) or _center == null or _panel_root == null:
		return
	_center.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	var world_p: Vector2 = _walker.global_position
	var panel_sz: Vector2 = _panel_root.size
	_center.size = panel_sz
	var desired: Vector2 = world_p + _follow_head_offset - Vector2(panel_sz.x * 0.5, panel_sz.y)
	_center.position = desired


func _refresh_lists() -> void:
	_fill_shop_list()
	_fill_player_list()
	_refresh_money_label()


func _refresh_money_label() -> void:
	if _walker == null:
		_money_label.text = "铜币: 0"
		return
	_money_label.text = "铜币: %d" % _walker.get_money()


func _fill_shop_list() -> void:
	_shop_list.clear()
	_shop_item_ids.clear()
	if _shop == null:
		return
	if not _shop.has_method("get_sell_item_ids"):
		return
	var ids: Array = _shop.call("get_sell_item_ids")
	for idv in ids:
		var id: String = str(idv)
		var def: Dictionary = ItemDB.get_def(id)
		if def.is_empty():
			continue
		var name_text: String = str(def.get("name", id))
		var p: int = int(_shop.call("get_buy_price", id)) if _shop.has_method("get_buy_price") else ItemDB.get_price(id, 0)
		var line: String = "%s  [买:%d]" % [name_text, p]
		var tex: Texture2D = ItemDB.get_icon_texture(id)
		if tex:
			_shop_list.add_item(line, tex)
		else:
			_shop_list.add_item(line)
		_shop_item_ids.append(id)


func _fill_player_list() -> void:
	_player_list.clear()
	if _walker == null:
		return
	for slot in _walker.inventory:
		var id: String = str(slot.get("id", ""))
		var cnt: int = int(slot.get("count", 0))
		var def: Dictionary = ItemDB.get_def(id)
		var name_text: String = str(def.get("name", id)) if not def.is_empty() else id
		var sell_p: int = int(_shop.call("get_sell_price", id)) if _shop != null and _shop.has_method("get_sell_price") else 0
		var line: String = "%s × %d  [卖:%d]" % [name_text, cnt, sell_p]
		var tex: Texture2D = ItemDB.get_icon_texture(id)
		if tex:
			_player_list.add_item(line, tex)
		else:
			_player_list.add_item(line)


func _on_buy_one() -> void:
	_buy_selected(1)


func _on_buy_ten() -> void:
	_buy_selected(10)


func _buy_selected(n: int) -> void:
	if _walker == null or _shop == null:
		return
	var sel: PackedInt32Array = _shop_list.get_selected_items()
	if sel.is_empty():
		return
	var si: int = int(sel[0])
	if si < 0 or si >= _shop_item_ids.size():
		return
	var item_id: String = _shop_item_ids[si]
	if not _shop.has_method("buy_to_walker"):
		return
	var got: int = int(_shop.call("buy_to_walker", _walker, item_id, n))
	if got <= 0:
		_hint.text = "购买失败：可能余额不足或背包已满"
	else:
		_hint.text = "已购买 %s × %d" % [item_id, got]
	_refresh_lists()


func _on_sell_one() -> void:
	_sell_selected(1)


func _on_sell_all() -> void:
	_sell_selected(-1)


func _sell_selected(amount: int) -> void:
	if _walker == null or _shop == null:
		return
	var sel: PackedInt32Array = _player_list.get_selected_items()
	if sel.is_empty():
		return
	if not _shop.has_method("sell_from_walker"):
		return
	var si: int = int(sel[0])
	var sold: int = int(_shop.call("sell_from_walker", _walker, si, amount))
	if sold <= 0:
		_hint.text = "出售失败：该物品不可回收或数量不足"
	else:
		_hint.text = "已出售 × %d" % sold
	_refresh_lists()
