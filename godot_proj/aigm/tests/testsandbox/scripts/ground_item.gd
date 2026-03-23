extends Area2D
## 掉落在场景里的可拾取物；需在物理层 5（位掩码 [member PICKUP_LAYER_BIT]）上与玩家 [PickupArea] 重叠检测。
## [member ProximityArea] 比拾取碰撞大，用于在玩家靠近时显示 [member NameLabel]。
class_name GroundItem

## 与 [member NekomimiWalker.PICKUP_LAYER_BIT] 一致：物理层第 5 层。
const PICKUP_LAYER_BIT: int = 16

## 对应 [ItemDB] 中的 id，例如 [code]food_apple[/code]。
@export var item_id: String = "food_apple"
@export var quantity: int = 1

## 显示名称标签的环形范围半径（应大于拾取碰撞 + 玩家 [PickupArea] 半径之和）。
@export var name_tag_radius: float = 120.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = $NameLabel
@onready var _proximity_area: Area2D = $ProximityArea
@onready var _proximity_shape: CollisionShape2D = $ProximityArea/CollisionShape2D

var _player_nearby_count: int = 0


func _ready() -> void:
	add_to_group("ground_item")
	collision_layer = PICKUP_LAYER_BIT
	collision_mask = 0
	monitorable = true
	monitoring = false
	_apply_proximity_radius()
	_name_label.visible = false
	_proximity_area.body_entered.connect(_on_proximity_body_entered)
	_proximity_area.body_exited.connect(_on_proximity_body_exited)
	refresh_visual()


func _apply_proximity_radius() -> void:
	var sh: Shape2D = _proximity_shape.shape
	if sh is CircleShape2D:
		(sh as CircleShape2D).radius = maxf(8.0, name_tag_radius)


func _on_proximity_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.is_in_group("controlled_nekomimi"):
		_player_nearby_count += 1
		_update_name_visibility()


func _on_proximity_body_exited(body: Node) -> void:
	if body is CharacterBody2D and body.is_in_group("controlled_nekomimi"):
		_player_nearby_count = maxi(0, _player_nearby_count - 1)
		_update_name_visibility()


func _update_name_visibility() -> void:
	_name_label.visible = _player_nearby_count > 0


func refresh_visual() -> void:
	_apply_icon()
	_refresh_name_label()


func _apply_icon() -> void:
	var tex: Texture2D = ItemDB.get_icon_texture(item_id)
	if _sprite == null:
		return
	if tex != null:
		_sprite.texture = tex
		var s: float = 1
		_sprite.scale = Vector2(s, s)
	else:
		_sprite.texture = null


func _refresh_name_label() -> void:
	if _name_label == null:
		return
	var def: Dictionary = ItemDB.get_def(item_id)
	var display: String = def.get("name", item_id) if not def.is_empty() else item_id
	if quantity > 1:
		_name_label.text = "%s × %d" % [display, quantity]
	else:
		_name_label.text = display


## 由玩家拾取后更新数量或移除；返回未能入包的数量。
func apply_pickup_result(leftover: int) -> void:
	quantity = leftover
	if quantity <= 0:
		queue_free()
	else:
		refresh_visual()
