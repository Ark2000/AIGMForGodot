#Use middle mouse to pan, scale
extends Camera2D

@export var input_area:Control

@export var zoom_speed := 3.0

var pan_mode := false
var zoom_level := 2.0

func _ready():
	input_area.gui_input.connect(handle_input)
	set_zoom_level(zoom_level)

func handle_input(event):
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				pan_mode = true
			else:
				pan_mode = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_zoom_level(zoom_level + 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_zoom_level(zoom_level - 0.1)
	elif event is InputEventMouseMotion:
		if pan_mode:
			position -= event.relative * (1.0/zoom.x)

func set_zoom_level(val:float):
	var m = get_global_mouse_position()
	var old_zoom_x = zoom.x
	zoom_level = val
	zoom = Vector2.ONE * pow(zoom_speed, zoom_level)
	#zooming should keep global_mouse_position.
	position = m - (m - position) * old_zoom_x / zoom.x
