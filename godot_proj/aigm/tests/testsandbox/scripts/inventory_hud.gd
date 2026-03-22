extends CanvasLayer
## 简单背包列表：绑定组 [code]controlled_nekomimi[/code] 当前角色；标题栏可折叠。

@onready var _panel: Panel = $Panel
@onready var _toggle: Button = $Panel/Margin/VBox/ToggleButton
@onready var _fold_content: Control = $Panel/Margin/VBox/FoldContent
@onready var _item_list: ItemList = $Panel/Margin/VBox/FoldContent/ItemList
@onready var _hint: Label = $Panel/Margin/VBox/FoldContent/HintLabel

var _walker: CharacterBody2D
var _expanded: bool = false
var _height_expanded: float = 0.0


func _ready() -> void:
	add_to_group("inventory_hud")
	_hint.text = "F 拾取 / 靠近箱子打开 | 自动拾取可在角色上关"
	_item_list.fixed_icon_size = Vector2i(28, 28)
	_item_list.icon_mode = ItemList.ICON_MODE_LEFT
	_toggle.pressed.connect(_on_toggle_pressed)
	_update_toggle_label()
	_defer_bind()


func rebind_to_controlled() -> void:
	if _walker != null and is_instance_valid(_walker) and _walker.has_signal("inventory_changed"):
		if _walker.inventory_changed.is_connected(_on_inventory_changed):
			_walker.inventory_changed.disconnect(_on_inventory_changed)
	_walker = get_tree().get_first_node_in_group("controlled_nekomimi") as CharacterBody2D
	if _walker != null and _walker.has_signal("inventory_changed"):
		_walker.inventory_changed.connect(_on_inventory_changed)
	_on_inventory_changed()


func _defer_bind() -> void:
	await get_tree().process_frame
	_height_expanded = maxf(_panel.size.y, 200.0)
	_apply_fold_layout()
	rebind_to_controlled()


func _apply_fold_layout() -> void:
	_fold_content.visible = _expanded
	_update_toggle_label()
	var h: float = _height_expanded if _expanded else _collapsed_panel_height()
	_panel.offset_bottom = _panel.offset_top + h


func _on_toggle_pressed() -> void:
	_expanded = not _expanded
	_apply_fold_layout()


func _collapsed_panel_height() -> float:
	var row: float = maxf(_toggle.get_minimum_size().y, _toggle.size.y)
	return row + 20.0


func _update_toggle_label() -> void:
	_toggle.text = "▼ 背包 / 仓储" if _expanded else "▶ 背包 / 仓储"


func _on_inventory_changed() -> void:
	if _walker == null:
		return
	_item_list.clear()
	for slot in _walker.inventory:
		var id: String = slot.get("id", "")
		var cnt: int = int(slot.get("count", 0))
		var def: Dictionary = ItemDB.get_def(id)
		var display: String = def.get("name", id) if not def.is_empty() else id
		var tex: Texture2D = ItemDB.get_icon_texture(id)
		var line: String = "%s × %d" % [display, cnt]
		if tex:
			_item_list.add_item(line, tex)
		else:
			_item_list.add_item(line)
