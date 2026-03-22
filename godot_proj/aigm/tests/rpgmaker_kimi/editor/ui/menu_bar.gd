@tool
extends Panel

signal file_menu_selected(id: int)
signal edit_menu_selected(id: int)
signal view_menu_selected(id: int)
signal tools_menu_selected(id: int)
signal help_menu_selected(id: int)
signal tool_selected(tool: String)

@onready var file_menu: MenuButton = $HBoxContainer/FileMenu
@onready var edit_menu: MenuButton = $HBoxContainer/EditMenu
@onready var view_menu: MenuButton = $HBoxContainer/ViewMenu
@onready var tools_menu: MenuButton = $HBoxContainer/ToolsMenu
@onready var help_menu: MenuButton = $HBoxContainer/HelpMenu

# 工具按钮
@onready var pencil_btn: Button = $HBoxContainer/ToolButtons/Pencil
@onready var rectangle_btn: Button = $HBoxContainer/ToolButtons/Rectangle
@onready var circle_btn: Button = $HBoxContainer/ToolButtons/Circle
@onready var fill_btn: Button = $HBoxContainer/ToolButtons/Fill
@onready var erase_btn: Button = $HBoxContainer/ToolButtons/Erase
@onready var undo_btn: Button = $HBoxContainer/ToolButtons/Undo
@onready var redo_btn: Button = $HBoxContainer/ToolButtons/Redo

var tool_buttons: Dictionary = {}
var current_tool: String = "pencil"

func _ready():
	# 连接菜单信号
	file_menu.get_popup().id_pressed.connect(_on_file_menu_pressed)
	edit_menu.get_popup().id_pressed.connect(_on_edit_menu_pressed)
	view_menu.get_popup().id_pressed.connect(_on_view_menu_pressed)
	tools_menu.get_popup().id_pressed.connect(_on_tools_menu_pressed)
	help_menu.get_popup().id_pressed.connect(_on_help_menu_pressed)
	
	# 初始化工具按钮
	_init_tool_buttons()

func _init_tool_buttons():
	tool_buttons = {
		"pencil": pencil_btn,
		"rectangle": rectangle_btn,
		"circle": circle_btn,
		"fill": fill_btn,
		"erase": erase_btn
	}
	
	for tool_name in tool_buttons.keys():
		var btn = tool_buttons[tool_name]
		btn.toggled.connect(_on_tool_toggled.bind(tool_name))
	
	undo_btn.pressed.connect(_on_undo_pressed)
	redo_btn.pressed.connect(_on_redo_pressed)

func _on_file_menu_pressed(id: int):
	file_menu_selected.emit(id)

func _on_edit_menu_pressed(id: int):
	edit_menu_selected.emit(id)

func _on_view_menu_pressed(id: int):
	view_menu_selected.emit(id)

func _on_tools_menu_pressed(id: int):
	tools_menu_selected.emit(id)

func _on_help_menu_pressed(id: int):
	help_menu_selected.emit(id)

func _on_tool_toggled(pressed: bool, tool_name: String):
	if pressed:
		_select_tool(tool_name)

func _select_tool(tool_name: String):
	current_tool = tool_name
	
	# 更新按钮状态
	for name in tool_buttons.keys():
		tool_buttons[name].button_pressed = (name == tool_name)
	
	tool_selected.emit(tool_name)

func _on_undo_pressed():
	edit_menu_selected.emit(0)  # 撤销

func _on_redo_pressed():
	edit_menu_selected.emit(1)  # 重做

# 公共接口

func set_tool(tool_name: String):
	if tool_buttons.has(tool_name):
		_select_tool(tool_name)

func get_current_tool() -> String:
	return current_tool
