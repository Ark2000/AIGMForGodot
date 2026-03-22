extends Node2D
## 场景中的储物容器：玩家在交互范围内按 [kbd]F[/kbd] 打开 [ContainerPanel] 存取物品。
##
## **与 NPC / AI 的接口**：所有「背包 ↔ 容器」的实质操作都通过下面两个方法完成（[ContainerPanel] 内部也调用它们）。
## 在 [NpcBehavior] 或其它 AI 里，拿到目标 [ItemContainer] 与 [NekomimiWalker] 引用后即可调用，无需 UI。
## [code]amount == -1[/code] 表示该格**全部**可转移数量（整格）。

signal storage_changed

@export var display_name: String = "木箱"
@export var inventory_max_slots: int = 18
@export var interact_radius: float = 88.0
## 用于 [Sprite2D] 展示的 [ItemDB] id（如图标）。
@export var preview_item_id: String = "misc_crate"
## 开局向容器放入（便于测试）；正式关卡可在编辑器里清空。
@export var preset_item_id: String = ""
@export var preset_quantity: int = 0

var storage: Array[Dictionary] = []

var _interact_area: Area2D
var _near_controlled_count: int = 0

@onready var _hint: Label = $HintLabel


func _ready() -> void:
	add_to_group("item_container")
	_interact_area = $InteractArea
	var sh: CollisionShape2D = $InteractArea/CollisionShape2D
	if sh != null and sh.shape is CircleShape2D:
		(sh.shape as CircleShape2D).radius = interact_radius
	_interact_area.body_entered.connect(_on_body_entered)
	_interact_area.body_exited.connect(_on_body_exited)
	_refresh_sprite()
	if not preset_item_id.is_empty() and preset_quantity > 0:
		ItemDB.add_items_to_slots(storage, inventory_max_slots, preset_item_id, preset_quantity)
	if _hint != null:
		_hint.visible = false
		_hint.text = "F 打开"


func _refresh_sprite() -> void:
	var spr: Sprite2D = $Sprite2D
	if spr == null:
		return
	var tex: Texture2D = ItemDB.get_icon_texture(preview_item_id)
	if tex:
		spr.texture = tex
		var max_sz: float = maxf(tex.get_width(), tex.get_height())
		var s: float = 48.0 / max_sz
		spr.scale = Vector2(s, s)


func notify_storage_changed() -> void:
	storage_changed.emit()


## 从 [param walker] 背包第 [param slot_index] 格向本容器转移物品。[param amount] 为 [code]-1[/code] 时转移该格剩余全部。
## 返回**实际进入容器的数量**（背包格无效、数量为 0 则为 0）。容器满时多出的会退回背包。
func deposit_from_walker(walker: NekomimiWalker, slot_index: int, amount: int = -1) -> int:
	if walker == null:
		return 0
	var slots: Array = walker.inventory
	if slot_index < 0 or slot_index >= slots.size():
		return 0
	var slot: Dictionary = slots[slot_index]
	var id: String = str(slot.get("id", ""))
	var cnt: int = int(slot.get("count", 0))
	if cnt <= 0 or id.is_empty():
		return 0
	var amt: int = cnt if amount < 0 else mini(amount, cnt)
	var removed: int = ItemDB.remove_items_from_slot(slots, slot_index, amt)
	if removed <= 0:
		return 0
	var leftover: int = ItemDB.add_items_to_slots(storage, inventory_max_slots, id, removed)
	if leftover > 0:
		ItemDB.add_items_to_slots(walker.inventory, walker.inventory_max_slots, id, leftover)
	walker.inventory_changed.emit()
	notify_storage_changed()
	return removed - leftover


## 从本容器第 [param slot_index] 格向 [param walker] 背包转移物品。[param amount] 为 [code]-1[/code] 时转移该格全部。
## 返回**实际进入背包的数量**（容器格无效则为 0）。背包满时多出的会退回容器。
func withdraw_to_walker(walker: NekomimiWalker, slot_index: int, amount: int = -1) -> int:
	if walker == null:
		return 0
	if slot_index < 0 or slot_index >= storage.size():
		return 0
	var slot: Dictionary = storage[slot_index]
	var id: String = str(slot.get("id", ""))
	var cnt: int = int(slot.get("count", 0))
	if cnt <= 0 or id.is_empty():
		return 0
	var amt: int = cnt if amount < 0 else mini(amount, cnt)
	var removed: int = ItemDB.remove_items_from_slot(storage, slot_index, amt)
	if removed <= 0:
		return 0
	var leftover: int = ItemDB.add_items_to_slots(walker.inventory, walker.inventory_max_slots, id, removed)
	if leftover > 0:
		ItemDB.add_items_to_slots(storage, inventory_max_slots, id, leftover)
	walker.inventory_changed.emit()
	notify_storage_changed()
	return removed - leftover


func is_walker_in_range(walker: CharacterBody2D) -> bool:
	return _interact_area != null and _interact_area.overlaps_body(walker)


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
