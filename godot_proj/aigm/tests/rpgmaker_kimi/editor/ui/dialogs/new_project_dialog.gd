extends Window

## 新建项目对话框

signal project_created(project_name: String, project_path: String, settings: Dictionary)

@onready var name_edit: LineEdit = $VBoxContainer/GridContainer/NameEdit
@onready var location_edit: LineEdit = $VBoxContainer/GridContainer/LocationHBox/LocationEdit
@onready var browse_btn: Button = $VBoxContainer/GridContainer/LocationHBox/BrowseBtn
@onready var title_edit: LineEdit = $VBoxContainer/SettingsGrid/TitleEdit
@onready var width_spin: SpinBox = $VBoxContainer/SettingsGrid/ScreenSizeHBox/WidthSpin
@onready var height_spin: SpinBox = $VBoxContainer/SettingsGrid/ScreenSizeHBox/HeightSpin
@onready var tile_size_spin: SpinBox = $VBoxContainer/SettingsGrid/TileSizeSpin
@onready var ok_btn: Button = $VBoxContainer/ButtonBar/OkBtn
@onready var cancel_btn: Button = $VBoxContainer/ButtonBar/CancelBtn

var file_dialog: FileDialog

func _ready():
	# 设置默认路径
	location_edit.text = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("RPGMakerProjects")
	
	# 连接信号
	close_requested.connect(_on_close)
	browse_btn.pressed.connect(_on_browse)
	ok_btn.pressed.connect(_on_ok)
	cancel_btn.pressed.connect(_on_cancel)
	
	# 创建文件对话框
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.title = "选择项目位置"
	file_dialog.dir_selected.connect(_on_dir_selected)
	add_child(file_dialog)

func show_dialog():
	show()

func _on_browse():
	file_dialog.popup_centered(Vector2i(600, 400))

func _on_dir_selected(dir: String):
	location_edit.text = dir

func _on_ok():
	var project_name = name_edit.text.strip_edges()
	var project_path = location_edit.text.strip_edges()
	
	if project_name.is_empty():
		_show_error("请输入项目名称")
		return
	
	if project_path.is_empty():
		_show_error("请选择项目位置")
		return
	
	var full_path = project_path.path_join(project_name)
	
	# 检查目录是否已存在
	if DirAccess.dir_exists_absolute(full_path):
		_show_error("项目目录已存在")
		return
	
	var settings = {
		"title": title_edit.text,
		"screen_width": int(width_spin.value),
		"screen_height": int(height_spin.value),
		"tile_size": int(tile_size_spin.value)
	}
	
	project_created.emit(project_name, full_path, settings)
	hide()

func _on_cancel():
	hide()

func _on_close():
	hide()

func _show_error(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "错误"
	dialog.dialog_text = message
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
