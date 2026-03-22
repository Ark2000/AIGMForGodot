extends Window

## 事件编辑器
## 可视化编辑事件指令

signal event_saved(event_data: Dictionary)

@onready var name_edit: LineEdit = $VBoxContainer/BasicInfo/NameEdit
@onready var trigger_selector: OptionButton = $VBoxContainer/BasicInfo/TriggerSelector
@onready var graphic_selector: Button = $VBoxContainer/BasicInfo/GraphicSelector
@onready var add_command_btn: MenuButton = $VBoxContainer/CommandToolbar/AddCommand
@onready var edit_command_btn: Button = $VBoxContainer/CommandToolbar/EditCommand
@onready var delete_command_btn: Button = $VBoxContainer/CommandToolbar/DeleteCommand
@onready var move_up_btn: Button = $VBoxContainer/CommandToolbar/MoveUp
@onready var move_down_btn: Button = $VBoxContainer/CommandToolbar/MoveDown
@onready var command_list: ItemList = $VBoxContainer/CommandList
@onready var ok_btn: Button = $VBoxContainer/ButtonBar/OkBtn
@onready var cancel_btn: Button = $VBoxContainer/ButtonBar/CancelBtn

var current_event: Dictionary = {}
var commands: Array = []
var selected_command_index: int = -1

# 命令代码到名称的映射
const COMMAND_NAMES = {
	101: "显示文字",
	102: "显示选项",
	103: "输入数值",
	111: "条件分支",
	112: "循环",
	113: "中断循环",
	115: "中断事件处理",
	117: "公共事件",
	118: "标签",
	119: "跳转标签",
	121: "设置开关",
	122: "设置变量",
	123: "设置独立开关",
	125: "增减物品",
	126: "增减武器",
	127: "增减防具",
	128: "增减角色",
	129: "更改角色状态",
	201: "移动场所",
	202: "设置事件位置",
	203: "滚动地图",
	204: "更改地图设置",
	205: "移动路线",
	211: "更改角色透明度",
	212: "显示动画",
	213: "显示气球动画",
	214: "暂时消除事件",
	221: "更改画面色调",
	222: "闪烁画面",
	223: "更改画面色调",
	224: "屏幕震动",
	225: "等待",
	231: "显示图片",
	232: "移动图片",
	233: "旋转图片",
	234: "更改图片色调",
	235: "消除图片",
	236: "设置天气",
	241: "播放BGM",
	242: "淡出BGM",
	243: "保存BGM",
	244: "恢复BGM",
	245: "播放BGS",
	246: "淡出BGS",
	249: "播放ME",
	250: "播放SE",
	251: "停止SE",
	261: "播放视频",
	281: "更改地图名称显示",
	282: "更改图块集",
	283: "更改战斗背景",
	284: "更改远景",
	285: "获取位置信息",
	301: "战斗处理",
	302: "商店处理",
	303: "名称输入处理",
	311: "更改HP",
	312: "更改MP",
	313: "更改状态",
	314: "完全恢复",
	315: "增减EXP",
	316: "增减等级",
	317: "增减能力值",
	318: "增减技能",
	319: "更改装备",
	320: "更改名字",
	321: "更改职业",
	322: "更改角色图像",
	323: "更改载具图像",
	324: "更改昵称",
	325: "更改简介",
	331: "更改敌人HP",
	332: "更改敌人MP",
	333: "更改敌人状态",
	334: "敌人完全恢复",
	335: "敌人出现",
	336: "敌人变身",
	337: "显示战斗动画",
	339: "强制行动",
	340: "中止战斗",
	351: "打开菜单画面",
	352: "打开存档画面",
	353: "游戏结束",
	354: "返回标题画面",
	355: "脚本",
	0: "@"
}

func _ready():
	# 连接信号
	close_requested.connect(_on_close)
	ok_btn.pressed.connect(_on_ok)
	cancel_btn.pressed.connect(_on_cancel)
	
	add_command_btn.get_popup().id_pressed.connect(_on_add_command)
	edit_command_btn.pressed.connect(_on_edit_command)
	delete_command_btn.pressed.connect(_on_delete_command)
	move_up_btn.pressed.connect(_on_move_up)
	move_down_btn.pressed.connect(_on_move_down)
	command_list.item_selected.connect(_on_command_selected)
	
	hide()

func edit_event(event_data: Dictionary):
	current_event = event_data.duplicate(true)
	
	# 加载基本信息
	name_edit.text = event_data.get("name", "")
	trigger_selector.select(event_data.get("trigger", 0))
	
	# 加载指令列表
	commands = event_data.get("pages", [{}])[0].get("list", []) if event_data.has("pages") else []
	_refresh_command_list()
	
	show()

func _refresh_command_list():
	command_list.clear()
	
	var indent = 0
	for i in range(commands.size()):
		var cmd = commands[i]
		var code = cmd.get("code", 0)
		var name = COMMAND_NAMES.get(code, "未知指令(%d)" % code)
		
		# 处理缩进
		if code == 111 or code == 112:  # 条件分支、循环
			indent += 1
		elif code == 411:  # 否则
			indent = max(0, indent - 1)
		elif code == 0:  # 结束
			indent = max(0, indent - 1)
		
		var prefix = ""
		for j in range(indent):
			prefix += "  "
		
		command_list.add_item(prefix + name)
		command_list.set_item_metadata(command_list.item_count - 1, i)

func _on_add_command(code: int):
	var new_command = {
		"code": code,
		"indent": 0,
		"parameters": _default_parameters(code)
	}
	
	var selected = command_list.get_selected_items()
	if selected.size() > 0:
		var index = selected[0]
		commands.insert(index + 1, new_command)
	else:
		commands.append(new_command)
	
	_refresh_command_list()

func _default_parameters(code: int) -> Array:
	match code:
		101:  # 显示文字
			return ["", 0, 0, 2]
		102:  # 显示选项
			return [[], 0]
		103:  # 输入数值
			return [1, 1]
		111:  # 条件分支
			return [0, 1, 0]
		121:  # 设置开关
			return [1, 1, 0]
		122:  # 设置变量
			return [1, 1, 0, 0]
		201:  # 移动场所
			return [0, 0, 0, 0, 0]
		205:  # 移动路线
			return [0, {"list": [], "repeat": false, "skippable": false, "wait": true}]
		223:  # 更改画面色调
			return [[255, 255, 255, 255], 60, false]
		_:
			return []

func _on_edit_command():
	var selected = command_list.get_selected_items()
	if selected.size() == 0:
		return
	
	var index = command_list.get_item_metadata(selected[0])
	var cmd = commands[index]
	
	print("编辑指令: ", cmd)
	# TODO: 打开指令编辑对话框

func _on_delete_command():
	var selected = command_list.get_selected_items()
	if selected.size() == 0:
		return
	
	var index = command_list.get_item_metadata(selected[0])
	commands.remove_at(index)
	_refresh_command_list()

func _on_move_up():
	var selected = command_list.get_selected_items()
	if selected.size() == 0:
		return
	
	var index = command_list.get_item_metadata(selected[0])
	if index > 0:
		var temp = commands[index]
		commands[index] = commands[index - 1]
		commands[index - 1] = temp
		_refresh_command_list()
		command_list.select(selected[0] - 1)

func _on_move_down():
	var selected = command_list.get_selected_items()
	if selected.size() == 0:
		return
	
	var index = command_list.get_item_metadata(selected[0])
	if index < commands.size() - 1:
		var temp = commands[index]
		commands[index] = commands[index + 1]
		commands[index + 1] = temp
		_refresh_command_list()
		command_list.select(selected[0] + 1)

func _on_command_selected(index: int):
	selected_command_index = command_list.get_item_metadata(index)

func _on_ok():
	# 保存事件数据
	current_event.name = name_edit.text
	
	if not current_event.has("pages"):
		current_event.pages = [{}]
	
	current_event.pages[0].trigger = trigger_selector.get_selected_id()
	current_event.pages[0].list = commands
	
	event_saved.emit(current_event)
	hide()

func _on_cancel():
	hide()

func _on_close():
	hide()
