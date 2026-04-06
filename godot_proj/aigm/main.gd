extends Node2D

var t = 0
var icons = []

func _ready() -> void:
	icons = [$Icon]
	var size = DisplayServer.window_get_size()
	print(size)
	for i in range(20):
		var new_icon = $Icon.duplicate()
		add_child(new_icon)
		icons.append(new_icon)
		new_icon.position = Vector2(randf() * size.x, randf() * size.y)

func _physics_process(delta: float) -> void:
	t = t + delta
	for i in range(len(icons)):
		icons[i].rotation = sin(t+i) * 4.0
