extends CanvasLayer
## 容器存取 UI：左右两栏为背包 / 容器格子，中间按钮转移；[kbd]F[/kbd] 开关，[kbd]Esc[/kbd] 关闭。

@onready var _title: Label = $CenterContainer/PanelRoot/Margin/VBox/TitleLabel
@onready var _player_list: ItemList = $CenterContainer/PanelRoot/Margin/VBox/HBox/PlayerVBox/PlayerList
@onready var _container_list: ItemList = $CenterContainer/PanelRoot/Margin/VBox/HBox/ContainerVBox/ContainerList
@onready var _btn_put_one: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/MidButtons/PutOneButton
@onready var _btn_put_all: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/MidButtons/PutAllButton
@onready var _btn_take_one: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/MidButtons/TakeOneButton
@onready var _btn_take_all: Button = $CenterContainer/PanelRoot/Margin/VBox/HBox/MidButtons/TakeAllButton
@onready var _btn_close: Button = $CenterContainer/PanelRoot/Margin/VBox/CloseButton

var _walker: NekomimiWalker
## [ItemContainer] 场景根节点（脚本挂在 [Node2D] 上）。
var _container: Node2D


func _ready() -> void:
	add_to_group("container_panel")
	layer = 25
	visible = false
	_player_list.fixed_icon_size = Vector2i(28, 28)
	_player_list.icon_mode = ItemList.ICON_MODE_LEFT
	_container_list.fixed_icon_size = Vector2i(28, 28)
	_container_list.icon_mode = ItemList.ICON_MODE_LEFT
	_btn_put_one.pressed.connect(_on_put_one)
	_btn_put_all.pressed.connect(_on_put_all)
	_btn_take_one.pressed.connect(_on_take_one)
	_btn_take_all.pressed.connect(_on_take_all)
	_btn_close.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## 由 [method NekomimiWalker] 在按 [kbd]F[/kbd] 时调用：优先开关容器 UI，否则返回 [code]false[/code] 让角色继续拾取。
func try_handle_f(walker: NekomimiWalker) -> bool:
	if not walker.user_controlled:
		return false
	if visible:
		close()
		return true
	var c: Node2D = _find_nearest_container(walker)
	if c == null:
		return false
	open(walker, c)
	return true


func _find_nearest_container(walker: NekomimiWalker) -> Node2D:
	var best: Node2D = null
	var best_d2: float = INF
	for n in walker.get_tree().get_nodes_in_group("item_container"):
		if not (n is Node2D):
			continue
		var n2: Node2D = n as Node2D
		if not n2.has_method("is_walker_in_range"):
			continue
		if not n2.is_walker_in_range(walker):
			continue
		var d2: float = walker.global_position.distance_squared_to(n2.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n2
	return best


func open(walker: NekomimiWalker, container: Node2D) -> void:
	if _walker != null and is_instance_valid(_walker) and _walker.inventory_changed.is_connected(_on_inventory_changed):
		_walker.inventory_changed.disconnect(_on_inventory_changed)
	if _container != null and is_instance_valid(_container) and _container.is_connected("storage_changed", _on_storage_changed):
		_container.disconnect("storage_changed", _on_storage_changed)
	_walker = walker
	_container = container
	_title.text = str(container.get("display_name"))
	if not _walker.inventory_changed.is_connected(_on_inventory_changed):
		_walker.inventory_changed.connect(_on_inventory_changed)
	if not _container.is_connected("storage_changed", _on_storage_changed):
		_container.connect("storage_changed", _on_storage_changed)
	visible = true
	_refresh_lists()


func close() -> void:
	visible = false
	if _walker != null and is_instance_valid(_walker) and _walker.inventory_changed.is_connected(_on_inventory_changed):
		_walker.inventory_changed.disconnect(_on_inventory_changed)
	if _container != null and is_instance_valid(_container) and _container.is_connected("storage_changed", _on_storage_changed):
		_container.disconnect("storage_changed", _on_storage_changed)
	_walker = null
	_container = null


func _on_inventory_changed() -> void:
	if visible:
		_refresh_lists()


func _on_storage_changed() -> void:
	if visible:
		_refresh_lists()


func _refresh_lists() -> void:
	_fill_list(_player_list, _walker.inventory if _walker != null else [])
	var st: Array = []
	if _container != null:
		st = _container.get("storage") as Array
	_fill_list(_container_list, st)


func _fill_list(list: ItemList, slots: Array) -> void:
	list.clear()
	for slot in slots:
		var id: String = str(slot.get("id", ""))
		var cnt: int = int(slot.get("count", 0))
		var def: Dictionary = ItemDB.get_def(id)
		var display: String = def.get("name", id) if not def.is_empty() else id
		var tex: Texture2D = ItemDB.get_icon_texture(id)
		var line: String = "%s × %d" % [display, cnt]
		if tex:
			list.add_item(line, tex)
		else:
			list.add_item(line)


func _on_put_one() -> void:
	_transfer_player_to_container(false)


func _on_put_all() -> void:
	_transfer_player_to_container(true)


func _transfer_player_to_container(all: bool) -> void:
	if _walker == null or _container == null:
		return
	var sel: PackedInt32Array = _player_list.get_selected_items()
	if sel.is_empty():
		return
	var si: int = int(sel[0])
	var amt: int = -1 if all else 1
	if _container.has_method("deposit_from_walker"):
		_container.call("deposit_from_walker", _walker, si, amt)
	_refresh_lists()


func _on_take_one() -> void:
	_transfer_container_to_player(false)


func _on_take_all() -> void:
	_transfer_container_to_player(true)


func _transfer_container_to_player(all: bool) -> void:
	if _walker == null or _container == null:
		return
	var sel: PackedInt32Array = _container_list.get_selected_items()
	if sel.is_empty():
		return
	var si: int = int(sel[0])
	var amt: int = -1 if all else 1
	if _container.has_method("withdraw_to_walker"):
		_container.call("withdraw_to_walker", _walker, si, amt)
	_refresh_lists()
