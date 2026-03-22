extends Window

## 关于对话框

signal confirmed()

func _ready():
	close_requested.connect(_on_close)

func show_dialog():
	show()

func _on_close():
	hide()
