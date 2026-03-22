class_name DatabaseManager
extends Node

## 数据库管理器
## 管理游戏中的所有数据：角色、职业、物品、技能、敌人等

signal database_loaded()
signal database_saved()
signal data_changed(category: String, id: int)

const DATABASE_FILES = {
	"actors": "Actors.json",
	"classes": "Classes.json",
	"skills": "Skills.json",
	"items": "Items.json",
	"weapons": "Weapons.json",
	"armors": "Armors.json",
	"enemies": "Enemies.json",
	"troops": "Troops.json",
	"states": "States.json",
	"animations": "Animations.json",
	"tilesets": "Tilesets.json",
	"system": "System.json"
}

var database: Dictionary = {}
var data_path: String = ""

func _ready():
	pass

# ===== 数据库操作 =====

func create_default_database(path: String):
	data_path = path
	database = _create_rich_rpg_data()
	save_database()

func load_database(path: String) -> bool:
	data_path = path
	database = {}
	
	for category in DATABASE_FILES.keys():
		var file_path = path.path_join(DATABASE_FILES[category])
		if FileAccess.file_exists(file_path):
			var data = _load_json_file(file_path)
			if data != null:
				database[category] = data
			else:
				database[category] = []
		else:
			database[category] = []
	
	database_loaded.emit()
	return true

func save_database() -> bool:
	for category in database.keys():
		if DATABASE_FILES.has(category):
			var file_path = data_path.path_join(DATABASE_FILES[category])
			if not _save_json_file(file_path, database[category]):
				return false
	
	database_saved.emit()
	return true

func _load_json_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return null
	
	return json.data

func _save_json_file(file_path: String, data) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true

# ===== 数据操作 =====

func get_data(category: String, id: int) -> Dictionary:
	if database.has(category):
		var list = database[category]
		if id >= 0 and id < list.size():
			return list[id]
	return {}

func set_data(category: String, id: int, data: Dictionary):
	if not database.has(category):
		database[category] = []
	
	var list = database[category]
	while list.size() <= id:
		list.append({})
	
	list[id] = data
	data_changed.emit(category, id)

func add_data(category: String, data: Dictionary) -> int:
	if not database.has(category):
		database[category] = []
	
	var id = database[category].size()
	database[category].append(data)
	data_changed.emit(category, id)
	return id

func remove_data(category: String, id: int) -> bool:
	if database.has(category):
		var list = database[category]
		if id >= 0 and id < list.size():
			list[id] = {}
			data_changed.emit(category, id)
			return true
	return false

func get_category_list(category: String) -> Array:
	if database.has(category):
		return database[category]
	return []

# ===== 丰富的 RPG 数据库 =====

func _create_rich_rpg_data() -> Dictionary:
	var data = {}
	
	# ========== 角色 (8个) ==========
	data["actors"] = [
		null,		# ID 0 保留
		{
			"id": 1,
			"name": "艾德里安",
			"nickname": "勇者",
			"class_id": 1,
			"initial_level": 1,
			"max_level": 99,
			"character_name": "Actor1",
			"character_index": 0,
			"face_name": "Actor1",
			"face_index": 0,
			"equips": [1, 1, 2, 3, 0],
			"profile": "王国的年轻勇者，肩负着拯救世界的使命。性格正直勇敢，深受人民爱戴。",
			"note": "主角"
		},
		{
			"id": 2,
			"name": "塞拉菲娜",
			"nickname": "魔法师",
			"class_id": 2,
			"initial_level": 3,
			"max_level": 99,
			"character_name": "Actor1",
			"character_index": 1,
			"face_name": "Actor1",
			"face_index": 1,
			"equips": [5, 0, 0, 6, 7],
			"profile": "天才魔法师，精通各种元素魔法。虽然性格有点傲娇，但内心善良。",
			"note": "魔法输出"
		},
		{
			"id": 3,
			"name": "格雷森",
			"nickname": "圣骑士",
			"class_id": 3,
			"initial_level": 5,
			"max_level": 99,
			"character_name": "Actor1",
			"character_index": 2,
			"face_name": "Actor1",
			"face_index": 2,
			"equips": [3, 4, 0, 9, 10],
			"profile": "神殿的圣骑士，拥有治疗和防御的能力。是队伍中最可靠的后盾。",
			"note": "治疗/坦克"
		},
		{
			"id": 4,
			"name": "莉莉丝",
			"nickname": "盗贼",
			"class_id": 4,
			"initial_level": 2,
			"max_level": 99,
			"character_name": "Actor1",
			"character_index": 3,
			"face_name": "Actor1",
			"face_index": 3,
			"equips": [6, 0, 0, 8, 11],
			"profile": "来自贫民窟的神偷，身手敏捷。虽然外表轻浮，但重情重义。",
			"note": "物理输出/辅助"
		},
		{
			"id": 5,
			"name": "克罗诺斯",
			"nickname": "贤者",
			"class_id": 5,
			"initial_level": 10,
			"max_level": 99,
			"character_name": "Actor2",
			"character_index": 0,
			"face_name": "Actor2",
			"face_index": 0,
			"equips": [8, 0, 0, 12, 13],
			"profile": "隐居的贤者，掌握着古老的禁术。为了阻止魔王而重新出山。",
			"note": "强力魔法"
		},
		{
			"id": 6,
			"name": "菲奥娜",
			"nickname": "弓箭手",
			"class_id": 6,
			"initial_level": 4,
			"max_level": 99,
			"character_name": "Actor2",
			"character_index": 1,
			"face_name": "Actor2",
			"face_index": 1,
			"equips": [9, 0, 0, 14, 0],
			"profile": "森林精灵族的弓箭手，箭术百发百中。性格冷静沉着，是优秀的狙击手。",
			"note": "远程物理"
		},
		{
			"id": 7,
			"name": "巴尔萨扎",
			"nickname": "狂战士",
			"class_id": 7,
			"initial_level": 8,
			"max_level": 99,
			"character_name": "Actor2",
			"character_index": 2,
			"face_name": "Actor2",
			"face_index": 2,
			"equips": [4, 0, 0, 15, 0],
			"profile": "北方蛮族的战士，拥有惊人的力量。一旦进入战斗就会热血沸腾。",
			"note": "高攻低防"
		},
		{
			"id": 8,
			"name": "伊莉雅",
			"nickname": "歌姬",
			"class_id": 8,
			"initial_level": 6,
			"max_level": 99,
			"character_name": "Actor2",
			"character_index": 3,
			"face_name": "Actor2",
			"face_index": 3,
			"equips": [10, 0, 0, 16, 17],
			"profile": "吟游诗人，用歌声激励队友。她的音乐拥有神奇的魔力。",
			"note": "辅助/增益"
		}
	]
	
	# ========== 职业 (8个) ==========
	data["classes"] = [
		null,
		{
			"id": 1,
			"name": "勇者",
			"params": _create_balanced_params(),
			"learnings": [
				{"level": 1, "skill_id": 1},
				{"level": 5, "skill_id": 6},
				{"level": 10, "skill_id": 11},
				{"level": 20, "skill_id": 16}
			],
			"traits": [
				{"code": 51, "data_id": 2, "value": 1},
				{"code": 52, "data_id": 1, "value": 1}
			]
		},
		{
			"id": 2,
			"name": "魔法师",
			"params": _create_mage_params(),
			"learnings": [
				{"level": 1, "skill_id": 21},
				{"level": 3, "skill_id": 22},
				{"level": 7, "skill_id": 23},
				{"level": 12, "skill_id": 24},
				{"level": 18, "skill_id": 25}
			],
			"traits": [
				{"code": 51, "data_id": 9, "value": 1},
				{"code": 52, "data_id": 1, "value": 1}
			]
		},
		{
			"id": 3,
			"name": "圣骑士",
			"params": _create_tank_params(),
			"learnings": [
				{"level": 1, "skill_id": 31},
				{"level": 5, "skill_id": 32},
				{"level": 10, "skill_id": 33},
				{"level": 15, "skill_id": 34}
			],
			"traits": [
				{"code": 51, "data_id": 3, "value": 1},
				{"code": 52, "data_id": 1, "value": 1},
				{"code": 62, "data_id": 0, "value": 0.8}
			]
		},
		{
			"id": 4,
			"name": "盗贼",
			"params": _create_fast_params(),
			"learnings": [
				{"level": 1, "skill_id": 41},
				{"level": 5, "skill_id": 42},
				{"level": 10, "skill_id": 43},
				{"level": 15, "skill_id": 44}
			],
			"traits": [
				{"code": 51, "data_id": 2, "value": 1},
				{"code": 52, "data_id": 1, "value": 1},
				{"code": 62, "data_id": 0, "value": 1.2}
			]
		},
		{
			"id": 5,
			"name": "贤者",
			"params": _create_sage_params(),
			"learnings": [
				{"level": 1, "skill_id": 51},
				{"level": 5, "skill_id": 52},
				{"level": 10, "skill_id": 53},
				{"level": 20, "skill_id": 54},
				{"level": 30, "skill_id": 55}
			],
			"traits": [
				{"code": 51, "data_id": 9, "value": 1},
				{"code": 52, "data_id": 1, "value": 1}
			]
		},
		{
			"id": 6,
			"name": "弓箭手",
			"params": _create_ranger_params(),
			"learnings": [
				{"level": 1, "skill_id": 61},
				{"level": 5, "skill_id": 62},
				{"level": 12, "skill_id": 63},
				{"level": 18, "skill_id": 64}
			],
			"traits": [
				{"code": 51, "data_id": 7, "value": 1},
				{"code": 52, "data_id": 1, "value": 1}
			]
		},
		{
			"id": 7,
			"name": "狂战士",
			"params": _create_berseker_params(),
			"learnings": [
				{"level": 1, "skill_id": 71},
				{"level": 5, "skill_id": 72},
				{"level": 15, "skill_id": 73},
				{"level": 25, "skill_id": 74}
			],
			"traits": [
				{"code": 51, "data_id": 5, "value": 1},
				{"code": 52, "data_id": 1, "value": 1},
				{"code": 55, "data_id": 2, "value": 0.5}
			]
		},
		{
			"id": 8,
			"name": "吟游诗人",
			"params": _create_bard_params(),
			"learnings": [
				{"level": 1, "skill_id": 81},
				{"level": 5, "skill_id": 82},
				{"level": 10, "skill_id": 83},
				{"level": 15, "skill_id": 84}
			],
			"traits": [
				{"code": 51, "data_id": 10, "value": 1},
				{"code": 52, "data_id": 1, "value": 1}
			]
		}
	]
	
	# ========== 技能 (丰富的技能系统) ==========
	data["skills"] = _create_skills()
	
	# ========== 物品 (消耗品、材料、关键道具) ==========
	data["items"] = _create_items()
	
	# ========== 武器 (各类武器) ==========
	data["weapons"] = _create_weapons()
	
	# ========== 防具 (头盔、铠甲、护腿、饰品) ==========
	data["armors"] = _create_armors()
	
	# ========== 敌人 (多种敌人) ==========
	data["enemies"] = _create_enemies()
	
	# ========== 敌群 (战斗遭遇组合) ==========
	data["troops"] = _create_troops()
	
	# ========== 状态效果 ==========
	data["states"] = _create_states()
	
	# ========== 动画 ==========
	data["animations"] = _create_animations()
	
	# ========== 图块集 ==========
	data["tilesets"] = _create_tilesets()
	
	# ========== 系统设置 ==========
	data["system"] = _create_system()
	
	return data

# ========== 参数生成辅助函数 ==========

func _create_balanced_params() -> Array:
	# 勇者 - 平衡型
	var hp = []
	var mp = []
	var atk = []
	var def = []
	var mat = []
	var mdf = []
	var agi = []
	var luk = []
	
	for level in range(100):
		hp.append(500 + level * 30)
		mp.append(50 + level * 5)
		atk.append(20 + level * 3)
		def.append(15 + level * 2)
		mat.append(10 + level * 2)
		mdf.append(10 + level * 2)
		agi.append(15 + level * 2)
		luk.append(10 + level * 2)
	
	return [hp, mp, atk, def, mat, mdf, agi, luk]

func _create_mage_params() -> Array:
	# 魔法师 - 高魔攻低防御
	var hp = []
	var mp = []
	var atk = []
	var def = []
	var mat = []
	var mdf = []
	var agi = []
	var luk = []
	
	for level in range(100):
		hp.append(350 + level * 15)
		mp.append(150 + level * 15)
		atk.append(5 + level)
		def.append(5 + level)
		mat.append(30 + level * 4)
		mdf.append(20 + level * 3)
		agi.append(12 + level * 2)
		luk.append(15 + level * 2)
	
	return [hp, mp, atk, def, mat, mdf, agi, luk]

func _create_tank_params() -> Array:
	# 圣骑士 - 高血高防
	var hp = []
	var mp = []
	var atk = []
	var def = []
	var mat = []
	var mdf = []
	var agi = []
	var luk = []
	
	for level in range(100):
		hp.append(700 + level * 40)
		mp.append(40 + level * 4)
		atk.append(15 + level * 2)
		def.append(25 + level * 3)
		mat.append(10 + level)
		mdf.append(20 + level * 3)
		agi.append(8 + level)
		luk.append(8 + level)
	
	return [hp, mp, atk, def, mat, mdf, agi, luk]

func _create_fast_params() -> Array:
	# 盗贼 - 高速高暴击
	var hp = []
	var mp = []
	var atk = []
	var def = []
	var mat = []
	var mdf = []
	var agi = []
	var luk = []
	
	for level in range(100):
		hp.append(400 + level * 20)
		mp.append(60 + level * 5)
		atk.append(25 + level * 3)
		def.append(10 + level * 2)
		mat.append(8 + level)
		mdf.append(8 + level)
		agi.append(25 + level * 4)
		luk.append(20 + level * 3)
	
	return [hp, mp, atk, def, mat, mdf, agi, luk]

func _create_sage_params() -> Array:
	# 贤者 - 全能型魔法
	var hp = []
	var mp = []
	var atk = []
	var def = []
	var mat = []
	var mdf = []
	var agi = []
	var luk = []
	
	for level in range(100):
		hp.append(450 + level * 18)
		mp.append(200 + level * 20)
		atk.append(10 + level * 2)
		def.append(12 + level * 2)
		mat.append(35 + level * 4)
		mdf.append(25 + level * 3)
		agi.append(12 + level * 2)
		luk.append(12 + level * 2)
	
	return [hp, mp, atk, def, mat, mdf, agi, luk]

func _create_ranger_params() -> Array:
	# 弓箭手 - 远程物理
	var hp = []
	var mp = []
	var atk = []
	var def = []
	var mat = []
	var mdf = []
	var agi = []
	var luk = []
	
	for level in range(100):
		hp.append(420 + level * 22)
		mp.append(50 + level * 4)
		atk.append(28 + level * 3)
		def.append(10 + level * 2)
		mat.append(8 + level)
		mdf.append(10 + level * 2)
		agi.append(20 + level * 3)
		luk.append(15 + level * 2)
	
	return [hp, mp, atk, def, mat, mdf, agi, luk]

func _create_berseker_params() -> Array:
	# 狂战士 - 超高攻击
	var hp = []
	var mp = []
	var atk = []
	var def = []
	var mat = []
	var mdf = []
	var agi = []
	var luk = []
	
	for level in range(100):
		hp.append(600 + level * 35)
		mp.append(20 + level * 2)
		atk.append(40 + level * 5)
		def.append(8 + level)
		mat.append(5 + level)
		mdf.append(5 + level)
		agi.append(12 + level * 2)
		luk.append(10 + level * 2)
	
	return [hp, mp, atk, def, mat, mdf, agi, luk]

func _create_bard_params() -> Array:
	# 吟游诗人 - 辅助型
	var hp = []
	var mp = []
	var atk = []
	var def = []
	var mat = []
	var mdf = []
	var agi = []
	var luk = []
	
	for level in range(100):
		hp.append(380 + level * 18)
		mp.append(100 + level * 10)
		atk.append(12 + level * 2)
		def.append(10 + level * 2)
		mat.append(20 + level * 3)
		mdf.append(18 + level * 2)
		agi.append(15 + level * 2)
		luk.append(18 + level * 3)
	
	return [hp, mp, atk, def, mat, mdf, agi, luk]

func _create_default_params() -> Array:
	# 默认参数
	var params = []
	for i in range(8):
		var level_params = []
		for level in range(100):
			level_params.append(1 + level * 10)
		params.append(level_params)
	return params

# ========== 创建技能 ==========

func _create_skills() -> Array:
	return [
		null,		# ID 0 保留
		
		# ========== 基础攻击技能 (1-10) ==========
		{
			"id": 1,
			"name": "攻击",
			"icon_index": 76,
			"description": "使用武器进行普通攻击。",
			"stype_id": 0,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 0,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 4 - b.def * 2"}
		},
		{
			"id": 2,
			"name": "强力斩击",
			"icon_index": 77,
			"description": "用全力斩击敌人，造成150%伤害。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 5,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 6 - b.def * 2"}
		},
		{
			"id": 3,
			"name": "连击",
			"icon_index": 78,
			"description": "连续攻击两次。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 8,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 3 - b.def * 2", "times": 2}
		},
		{
			"id": 4,
			"name": "横扫",
			"icon_index": 79,
			"description": "攻击所有敌人。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 12,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 3 - b.def * 2"}
		},
		{
			"id": 5,
			"name": "破甲攻击",
			"icon_index": 80,
			"description": "降低敌人防御的攻击。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 10,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 4 - b.def"},
			"effects": [{"code": 21, "data_id": 3, "value1": 0.5, "value2": 3}]
		},
		
		# ========== 勇者专属技能 (6-10) ==========
		{
			"id": 6,
			"name": "圣光斩",
			"icon_index": 81,
			"description": "使用圣光之力斩击敌人。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 15,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": 8, "formula": "a.atk * 5 + a.mat * 2 - b.def * 2"}
		},
		{
			"id": 7,
			"name": "勇气之剑",
			"icon_index": 82,
			"description": "提升自身攻击力的斩击。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 20,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 5 - b.def * 2"},
			"effects": [{"code": 31, "data_id": 2, "value1": 2, "value2": 0}]
		},
		{
			"id": 8,
			"name": "王者之剑",
			"icon_index": 83,
			"description": "传说中的剑技，对敌人造成巨大伤害。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 35,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 8 - b.def * 2"}
		},
		
		# ========== 火系魔法 (11-15) ==========
		{
			"id": 11,
			"name": "火球术",
			"icon_index": 96,
			"description": "发射火球攻击单个敌人。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 8,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 2, "formula": "100 + a.mat * 4 - b.mdf * 2"}
		},
		{
			"id": 12,
			"name": "大火球",
			"icon_index": 97,
			"description": "更大的火球造成更强伤害。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 15,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 2, "formula": "200 + a.mat * 6 - b.mdf * 2"}
		},
		{
			"id": 13,
			"name": "火焰风暴",
			"icon_index": 98,
			"description": "召唤火焰风暴攻击所有敌人。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 25,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 2, "formula": "150 + a.mat * 4 - b.mdf * 2"}
		},
		{
			"id": 14,
			"name": "地狱之火",
			"icon_index": 99,
			"description": "召唤地狱之火焚烧一切。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 45,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 2, "formula": "300 + a.mat * 8 - b.mdf * 2"}
		},
		{
			"id": 15,
			"name": "陨石术",
			"icon_index": 100,
			"description": "召唤陨石砸向敌人。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 60,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 2, "formula": "500 + a.mat * 10 - b.mdf * 2"}
		},
		
		# ========== 冰系魔法 (16-20) ==========
		{
			"id": 16,
			"name": "冰箭",
			"icon_index": 101,
			"description": "发射冰箭攻击敌人。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 8,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 3, "formula": "100 + a.mat * 4 - b.mdf * 2"}
		},
		{
			"id": 17,
			"name": "冰冻术",
			"icon_index": 102,
			"description": "冻结敌人造成伤害。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 15,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 3, "formula": "200 + a.mat * 6 - b.mdf * 2"}
		},
		{
			"id": 18,
			"name": "暴风雪",
			"icon_index": 103,
			"description": "召唤暴风雪攻击所有敌人。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 25,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 3, "formula": "150 + a.mat * 4 - b.mdf * 2"}
		},
		{
			"id": 19,
			"name": "绝对零度",
			"icon_index": 104,
			"description": "使温度降至绝对零度。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 50,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 3, "formula": "400 + a.mat * 9 - b.mdf * 2"}
		},
		
		# ========== 雷系魔法 (21-25) ==========
		{
			"id": 21,
			"name": "闪电",
			"icon_index": 105,
			"description": "召唤闪电攻击单个敌人。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 10,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 4, "formula": "120 + a.mat * 4 - b.mdf * 2"}
		},
		{
			"id": 22,
			"name": "雷击",
			"icon_index": 106,
			"description": "强力的雷电攻击。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 18,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 4, "formula": "220 + a.mat * 6 - b.mdf * 2"}
		},
		{
			"id": 23,
			"name": "连锁闪电",
			"icon_index": 107,
			"description": "闪电在敌人间跳跃。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 28,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 4, "formula": "180 + a.mat * 5 - b.mdf * 2"}
		},
		{
			"id": 24,
			"name": "审判之雷",
			"icon_index": 108,
			"description": "召唤天罚之雷。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 55,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 4, "formula": "450 + a.mat * 9 - b.mdf * 2"}
		},
		{
			"id": 25,
			"name": "神雷",
			"icon_index": 109,
			"description": "召唤神之雷霆。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 70,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 4, "formula": "600 + a.mat * 11 - b.mdf * 2"}
		},
		
		# ========== 治疗技能 (31-35) ==========
		{
			"id": 31,
			"name": "治疗术",
			"icon_index": 176,
			"description": "恢复单体少量HP。",
			"stype_id": 1,
			"scope": 7,
			"occasion": 0,
			"mp_cost": 8,
			"tp_cost": 0,
			"damage": {"type": 3, "element_id": 0, "formula": "100 + a.mat * 2"}
		},
		{
			"id": 32,
			"name": "中级治疗",
			"icon_index": 177,
			"description": "恢复单体中等HP。",
			"stype_id": 1,
			"scope": 7,
			"occasion": 0,
			"mp_cost": 15,
			"tp_cost": 0,
			"damage": {"type": 3, "element_id": 0, "formula": "300 + a.mat * 4"}
		},
		{
			"id": 33,
			"name": "高级治疗",
			"icon_index": 178,
			"description": "恢复单体大量HP。",
			"stype_id": 1,
			"scope": 7,
			"occasion": 0,
			"mp_cost": 25,
			"tp_cost": 0,
			"damage": {"type": 3, "element_id": 0, "formula": "600 + a.mat * 6"}
		},
		{
			"id": 34,
			"name": "全体治疗",
			"icon_index": 179,
			"description": "恢复全体队友HP。",
			"stype_id": 1,
			"scope": 8,
			"occasion": 0,
			"mp_cost": 30,
			"tp_cost": 0,
			"damage": {"type": 3, "element_id": 0, "formula": "200 + a.mat * 3"}
		},
		{
			"id": 35,
			"name": "复活术",
			"icon_index": 180,
			"description": "复活倒下的队友。",
			"stype_id": 1,
			"scope": 9,
			"occasion": 0,
			"mp_cost": 50,
			"tp_cost": 0,
			"damage": {"type": 3, "element_id": 0, "formula": "a.mhp * 0.5"}
		},
		
		# ========== 辅助技能 (41-45) ==========
		{
			"id": 41,
			"name": "加速",
			"icon_index": 200,
			"description": "提升单体速度。",
			"stype_id": 2,
			"scope": 7,
			"occasion": 0,
			"mp_cost": 10,
			"tp_cost": 0,
			"effects": [{"code": 31, "data_id": 6, "value1": 2, "value2": 0}]
		},
		{
			"id": 42,
			"name": "护盾",
			"icon_index": 201,
			"description": "提升单体防御。",
			"stype_id": 2,
			"scope": 7,
			"occasion": 0,
			"mp_cost": 10,
			"tp_cost": 0,
			"effects": [{"code": 31, "data_id": 3, "value1": 2, "value2": 0}]
		},
		{
			"id": 43,
			"name": "力量提升",
			"icon_index": 202,
			"description": "提升单体攻击。",
			"stype_id": 2,
			"scope": 7,
			"occasion": 0,
			"mp_cost": 12,
			"tp_cost": 0,
			"effects": [{"code": 31, "data_id": 2, "value1": 2, "value2": 0}]
		},
		{
			"id": 44,
			"name": "净化",
			"icon_index": 203,
			"description": "解除所有负面状态。",
			"stype_id": 2,
			"scope": 7,
			"occasion": 0,
			"mp_cost": 15,
			"tp_cost": 0,
			"effects": [{"code": 22, "data_id": 0, "value1": 1, "value2": 0}]
		},
		
		# ========== 盗贼技能 (51-55) ==========
		{
			"id": 51,
			"name": "偷窃",
			"icon_index": 220,
			"description": "从敌人身上偷取物品。",
			"stype_id": 2,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 5,
			"tp_cost": 0
		},
		{
			"id": 52,
			"name": "背刺",
			"icon_index": 221,
			"description": "从背后攻击造成暴击。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 15,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 5 - b.def * 2"},
			"effects": [{"code": 23, "data_id": 0, "value1": 0.5, "value2": 0}]
		},
		{
			"id": 53,
			"name": "烟雾弹",
			"icon_index": 222,
			"description": "降低敌人命中。",
			"stype_id": 2,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 12,
			"tp_cost": 0,
			"effects": [{"code": 21, "data_id": 6, "value1": 0.5, "value2": 3}]
		},
		
		# ========== 贤者高级魔法 (54-60) ==========
		{
			"id": 54,
			"name": "黑洞",
			"icon_index": 230,
			"description": "召唤黑洞吞噬一切。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 80,
			"tp_cost": 0,
			"damage": {"type": 2, "element_id": 9, "formula": "800 + a.mat * 12 - b.mdf * 2"}
		},
		{
			"id": 55,
			"name": "时间停止",
			"icon_index": 231,
			"description": "停止时间一回合。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 100,
			"tp_cost": 0,
			"effects": [{"code": 21, "data_id": 6, "value1": 0, "value2": 1}]
		},
		
		# ========== 弓箭手技能 (61-65) ==========
		{
			"id": 61,
			"name": "精准射击",
			"icon_index": 240,
			"description": "精准的一箭。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 8,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 5 - b.def * 2"}
		},
		{
			"id": 62,
			"name": "连射",
			"icon_index": 241,
			"description": "连续射出三箭。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 18,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 2.5 - b.def * 2", "times": 3}
		},
		{
			"id": 63,
			"name": "箭雨",
			"icon_index": 242,
			"description": "箭雨攻击所有敌人。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 25,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 4 - b.def * 2"}
		},
		{
			"id": 64,
			"name": "狙击",
			"icon_index": 243,
			"description": "必中的致命一箭。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 30,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 7 - b.def * 2"},
			"effects": [{"code": 23, "data_id": 0, "value1": 1, "value2": 0}]
		},
		
		# ========== 狂战士技能 (71-75) ==========
		{
			"id": 71,
			"name": "狂怒",
			"icon_index": 250,
			"description": "牺牲防御提升攻击。",
			"stype_id": 2,
			"scope": 11,
			"occasion": 1,
			"mp_cost": 0,
			"tp_cost": 0,
			"effects": [
				{"code": 31, "data_id": 2, "value1": 3, "value2": 0},
				{"code": 31, "data_id": 3, "value1": 0.5, "value2": 0}
			]
		},
		{
			"id": 72,
			"name": "战吼",
			"icon_index": 251,
			"description": "震慑敌人的怒吼。",
			"stype_id": 2,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 10,
			"tp_cost": 0,
			"effects": [{"code": 21, "data_id": 2, "value1": 0.5, "value2": 3}]
		},
		{
			"id": 73,
			"name": "旋风斩",
			"icon_index": 252,
			"description": "旋转攻击所有敌人。",
			"stype_id": 1,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 25,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 6 - b.def * 2"}
		},
		{
			"id": 74,
			"name": "狂暴打击",
			"icon_index": 253,
			"description": "舍身一击。",
			"stype_id": 1,
			"scope": 1,
			"occasion": 1,
			"mp_cost": 30,
			"tp_cost": 0,
			"damage": {"type": 1, "element_id": -1, "formula": "a.atk * 10 - b.def * 2"},
			"effects": [{"code": 11, "data_id": 0, "value1": 0.2, "value2": 0}]
		},
		
		# ========== 吟游诗人技能 (81-85) ==========
		{
			"id": 81,
			"name": "勇气之歌",
			"icon_index": 260,
			"description": "提升全体攻击。",
			"stype_id": 2,
			"scope": 8,
			"occasion": 0,
			"mp_cost": 15,
			"tp_cost": 0,
			"effects": [{"code": 31, "data_id": 2, "value1": 1.5, "value2": 0}]
		},
		{
			"id": 82,
			"name": "守护之歌",
			"icon_index": 261,
			"description": "提升全体防御。",
			"stype_id": 2,
			"scope": 8,
			"occasion": 0,
			"mp_cost": 15,
			"tp_cost": 0,
			"effects": [{"code": 31, "data_id": 3, "value1": 1.5, "value2": 0}]
		},
		{
			"id": 83,
			"name": "恢复之歌",
			"icon_index": 262,
			"description": "每回合恢复HP。",
			"stype_id": 2,
			"scope": 8,
			"occasion": 0,
			"mp_cost": 20,
			"tp_cost": 0,
			"effects": [{"code": 41, "data_id": 0, "value1": 0.1, "value2": 0}]
		},
		{
			"id": 84,
			"name": "镇魂曲",
			"icon_index": 263,
			"description": "降低敌人全体能力。",
			"stype_id": 2,
			"scope": 2,
			"occasion": 1,
			"mp_cost": 25,
			"tp_cost": 0,
			"effects": [
				{"code": 21, "data_id": 2, "value1": 0.7, "value2": 3},
				{"code": 21, "data_id": 3, "value1": 0.7, "value2": 3}
			]
		}
	]

# ========== 创建物品 ==========

func _create_items() -> Array:
	return [
		null,		# ID 0 保留
		
		# ========== 回复道具 ==========
		{
			"id": 1,
			"name": "药水",
			"icon_index": 176,
			"description": "回复200点HP。",
			"itype_id": 1,
			"price": 50,
			"consumable": true,
			"effects": [{"code": 11, "data_id": 0, "value1": 0, "value2": 200}]
		},
		{
			"id": 2,
			"name": "高级药水",
			"icon_index": 177,
			"description": "回复500点HP。",
			"itype_id": 1,
			"price": 150,
			"consumable": true,
			"effects": [{"code": 11, "data_id": 0, "value1": 0, "value2": 500}]
		},
		{
			"id": 3,
			"name": "完全恢复药",
			"icon_index": 178,
			"description": "完全回复HP。",
			"itype_id": 1,
			"price": 500,
			"consumable": true,
			"effects": [{"code": 11, "data_id": 0, "value1": 1, "value2": 0}]
		},
		{
			"id": 4,
			"name": "魔法药水",
			"icon_index": 179,
			"description": "回复50点MP。",
			"itype_id": 1,
			"price": 100,
			"consumable": true,
			"effects": [{"code": 12, "data_id": 0, "value1": 0, "value2": 50}]
		},
		{
			"id": 5,
			"name": "高级魔法药水",
			"icon_index": 180,
			"description": "回复150点MP。",
			"itype_id": 1,
			"price": 300,
			"consumable": true,
			"effects": [{"code": 12, "data_id": 0, "value1": 0, "value2": 150}]
		},
		{
			"id": 6,
			"name": "恢复草",
			"icon_index": 181,
			"description": "回复100点HP和30点MP。",
			"itype_id": 1,
			"price": 80,
			"consumable": true,
			"effects": [
				{"code": 11, "data_id": 0, "value1": 0, "value2": 100},
				{"code": 12, "data_id": 0, "value1": 0, "value2": 30}
			]
		},
		
		# ========== 状态恢复道具 ==========
		{
			"id": 7,
			"name": "解毒草",
			"icon_index": 182,
			"description": "解除中毒状态。",
			"itype_id": 1,
			"price": 50,
			"consumable": true,
			"effects": [{"code": 22, "data_id": 4, "value1": 1, "value2": 0}]
		},
		{
			"id": 8,
			"name": "苏醒药",
			"icon_index": 183,
			"description": "解除睡眠状态。",
			"itype_id": 1,
			"price": 50,
			"consumable": true,
			"effects": [{"code": 22, "data_id": 5, "value1": 1, "value2": 0}]
		},
		{
			"id": 9,
			"name": "万能药",
			"icon_index": 184,
			"description": "解除所有负面状态。",
			"itype_id": 1,
			"price": 200,
			"consumable": true,
			"effects": [{"code": 22, "data_id": 0, "value1": 1, "value2": 0}]
		},
		{
			"id": 10,
			"name": "不死鸟之尾",
			"icon_index": 185,
			"description": "复活倒下的队友。",
			"itype_id": 1,
			"price": 500,
			"consumable": true,
			"effects": [{"code": 11, "data_id": 0, "value1": 0.5, "value2": 0}]
		},
		
		# ========== 增益道具 ==========
		{
			"id": 11,
			"name": "力量药水",
			"icon_index": 186,
			"description": "暂时提升攻击力。",
			"itype_id": 1,
			"price": 150,
			"consumable": true,
			"effects": [{"code": 41, "data_id": 2, "value1": 1.5, "value2": 3}]
		},
		{
			"id": 12,
			"name": "铁壁药水",
			"icon_index": 187,
			"description": "暂时提升防御力。",
			"itype_id": 1,
			"price": 150,
			"consumable": true,
			"effects": [{"code": 41, "data_id": 3, "value1": 1.5, "value2": 3}]
		},
		{
			"id": 13,
			"name": "速度药水",
			"icon_index": 188,
			"description": "暂时提升速度。",
			"itype_id": 1,
			"price": 150,
			"consumable": true,
			"effects": [{"code": 41, "data_id": 6, "value1": 1.5, "value2": 3}]
		},
		
		# ========== 伤害道具 ==========
		{
			"id": 14,
			"name": "炸弹",
			"icon_index": 189,
			"description": "对敌人造成伤害。",
			"itype_id": 1,
			"price": 100,
			"consumable": true,
			"damage": {"type": 2, "element_id": 2, "formula": "100"}
		},
		{
			"id": 15,
			"name": "手里剑",
			"icon_index": 190,
			"description": "对敌人造成物理伤害。",
			"itype_id": 1,
			"price": 80,
			"consumable": true,
			"damage": {"type": 1, "element_id": -1, "formula": "80"}
		},
		
		# ========== 关键道具 ==========
		{
			"id": 16,
			"name": "火把",
			"icon_index": 191,
			"description": "照亮黑暗的地方。",
			"itype_id": 2,
			"price": 0,
			"consumable": false
		},
		{
			"id": 17,
			"name": "绳索",
			"icon_index": 192,
			"description": "可以下降到洞窟深处。",
			"itype_id": 2,
			"price": 0,
			"consumable": false
		},
		{
			"id": 18,
			"name": "古代钥匙",
			"icon_index": 193,
			"description": "开启古代遗迹的门。",
			"itype_id": 2,
			"price": 0,
			"consumable": false
		},
		{
			"id": 19,
			"name": "勇者徽章",
			"icon_index": 194,
			"description": "勇者的身份证明。",
			"itype_id": 2,
			"price": 0,
			"consumable": false
		},
		{
			"id": 20,
			"name": "魔法地图",
			"icon_index": 195,
			"description": "显示迷宫的完整地图。",
			"itype_id": 2,
			"price": 0,
			"consumable": false
		}
	]

# ========== 创建武器 ==========

func _create_weapons() -> Array:
	return [
		null,		# ID 0 保留
		
		# ========== 剑类武器 ==========
		{
			"id": 1,
			"name": "短剑",
			"icon_index": 96,
			"description": "初学者使用的短剑。",
			"wtype_id": 2,
			"price": 200,
			"params": [0, 0, 5, 0, 0, 0, 0, 0],
			"traits": []
		},
		{
			"id": 2,
			"name": "铁剑",
			"icon_index": 97,
			"description": "普通的铁制长剑。",
			"wtype_id": 3,
			"price": 500,
			"params": [0, 0, 10, 0, 0, 0, 0, 0],
			"traits": []
		},
		{
			"id": 3,
			"name": "钢剑",
			"icon_index": 98,
			"description": "用精钢打造的剑，相当锋利。",
			"wtype_id": 3,
			"price": 1200,
			"params": [0, 0, 18, 0, 0, 0, 2, 0],
			"traits": []
		},
		{
			"id": 4,
			"name": "骑士剑",
			"icon_index": 99,
			"description": "骑士团正式配发的剑。",
			"wtype_id": 3,
			"price": 2500,
			"params": [0, 0, 28, 5, 0, 0, 0, 0],
			"traits": []
		},
		{
			"id": 5,
			"name": "破魔剑",
			"icon_index": 100,
			"description": "对魔法生物有特效的剑。",
			"wtype_id": 3,
			"price": 5000,
			"params": [0, 0, 35, 0, 10, 5, 0, 0],
			"traits": [{"code": 31, "data_id": 9, "value": 1.5}]
		},
		{
			"id": 6,
			"name": "圣剑埃克斯卡利伯",
			"icon_index": 101,
			"description": "传说中的圣剑，拥有神圣的力量。",
			"wtype_id": 3,
			"price": 50000,
			"params": [0, 0, 80, 10, 20, 10, 5, 10],
			"traits": [{"code": 31, "data_id": 8, "value": 2}]
		},
		
		# ========== 法杖类武器 ==========
		{
			"id": 7,
			"name": "木杖",
			"icon_index": 110,
			"description": "普通的木制法杖。",
			"wtype_id": 8,
			"price": 150,
			"params": [0, 0, 2, 0, 5, 0, 0, 0],
			"traits": []
		},
		{
			"id": 8,
			"name": "魔法杖",
			"icon_index": 111,
			"description": "可以增强魔法的法杖。",
			"wtype_id": 8,
			"price": 800,
			"params": [0, 0, 4, 0, 15, 0, 0, 0],
			"traits": []
		},
		{
			"id": 9,
			"name": "贤者之杖",
			"icon_index": 112,
			"description": "贤者使用的法杖，蕴含魔力。",
			"wtype_id": 8,
			"price": 3000,
			"params": [50, 50, 5, 0, 30, 10, 0, 5],
			"traits": [{"code": 33, "data_id": 0, "value": 1.2}]
		},
		{
			"id": 10,
			"name": "世界树之杖",
			"icon_index": 113,
			"description": "由世界树枝条制成的传说法杖。",
			"wtype_id": 8,
			"price": 45000,
			"params": [100, 100, 10, 5, 60, 20, 5, 10],
			"traits": [{"code": 33, "data_id": 0, "value": 1.5}]
		},
		
		# ========== 斧类武器 ==========
		{
			"id": 11,
			"name": "手斧",
			"icon_index": 120,
			"description": "小型手斧，容易挥动。",
			"wtype_id": 4,
			"price": 300,
			"params": [0, 0, 12, 0, 0, 0, -2, 0],
			"traits": []
		},
		{
			"id": 12,
			"name": "战斧",
			"icon_index": 121,
			"description": "战士使用的斧。",
			"wtype_id": 4,
			"price": 800,
			"params": [0, 0, 22, 0, 0, 0, -3, 0],
			"traits": []
		},
		{
			"id": 13,
			"name": "巨斧",
			"icon_index": 122,
			"description": "需要极大力量才能挥动的巨斧。",
			"wtype_id": 4,
			"price": 2000,
			"params": [0, 0, 40, 0, 0, 0, -5, 0],
			"traits": [{"code": 23, "data_id": 0, "value": 0.1}]
		},
		
		# ========== 枪类武器 ==========
		{
			"id": 14,
			"name": "长枪",
			"icon_index": 130,
			"description": "标准的长枪。",
			"wtype_id": 5,
			"price": 450,
			"params": [0, 0, 15, 2, 0, 0, -1, 0],
			"traits": []
		},
		{
			"id": 15,
			"name": "骑士枪",
			"icon_index": 131,
			"description": "骑士使用的长枪。",
			"wtype_id": 5,
			"price": 1500,
			"params": [0, 0, 25, 5, 0, 0, -2, 0],
			"traits": []
		},
		
		# ========== 弓类武器 ==========
		{
			"id": 16,
			"name": "短弓",
			"icon_index": 140,
			"description": "简单的木弓。",
			"wtype_id": 6,
			"price": 400,
			"params": [0, 0, 8, 0, 0, 0, 3, 5],
			"traits": []
		},
		{
			"id": 17,
			"name": "长弓",
			"icon_index": 141,
			"description": "射程更远的长弓。",
			"wtype_id": 6,
			"price": 1200,
			"params": [0, 0, 18, 0, 0, 0, 5, 8],
			"traits": []
		},
		{
			"id": 18,
			"name": "精灵弓",
			"icon_index": 142,
			"description": "精灵族制作的精致长弓。",
			"wtype_id": 6,
			"price": 3500,
			"params": [0, 0, 30, 0, 5, 0, 8, 12],
			"traits": [{"code": 23, "data_id": 0, "value": 0.2}]
		},
		{
			"id": 19,
			"name": "风神之弓",
			"icon_index": 143,
			"description": "蕴含风之力的传说之弓。",
			"wtype_id": 6,
			"price": 40000,
			"params": [0, 0, 55, 0, 10, 0, 15, 20],
			"traits": [{"code": 31, "data_id": 7, "value": 1.5}]
		},
		
		# ========== 匕首类武器 ==========
		{
			"id": 20,
			"name": "匕首",
			"icon_index": 150,
			"description": "小型匕首，适合快速攻击。",
			"wtype_id": 2,
			"price": 250,
			"params": [0, 0, 6, 0, 0, 0, 5, 0],
			"traits": [{"code": 23, "data_id": 0, "value": 0.05}]
		},
		{
			"id": 21,
			"name": "暗杀者之刃",
			"icon_index": 151,
			"description": "暗杀者使用的短剑。",
			"wtype_id": 2,
			"price": 2800,
			"params": [0, 0, 25, 0, 0, 0, 10, 0],
			"traits": [{"code": 23, "data_id": 0, "value": 0.3}]
		}
	]

# ========== 创建防具 ==========

func _create_armors() -> Array:
	return [
		null,		# ID 0 保留
		
		# ========== 轻型护甲 ==========
		{
			"id": 1,
			"name": "布衣",
			"icon_index": 135,
			"description": "普通的布衣，提供基本防护。",
			"atype_id": 1,
			"etype_id": 2,
			"price": 100,
			"params": [0, 0, 0, 3, 0, 2, 0, 0],
			"traits": []
		},
		{
			"id": 2,
			"name": "皮甲",
			"icon_index": 136,
			"description": "用皮革制成的护甲。",
			"atype_id": 2,
			"etype_id": 2,
			"price": 300,
			"params": [0, 0, 0, 8, 0, 3, 0, 0],
			"traits": []
		},
		{
			"id": 3,
			"name": "硬皮甲",
			"icon_index": 137,
			"description": "加固的皮革护甲。",
			"atype_id": 2,
			"etype_id": 2,
			"price": 800,
			"params": [0, 0, 0, 15, 0, 5, 0, 0],
			"traits": []
		},
		
		# ========== 中型护甲 ==========
		{
			"id": 4,
			"name": "链甲",
			"icon_index": 138,
			"description": "由金属环连成的护甲。",
			"atype_id": 3,
			"etype_id": 2,
			"price": 1500,
			"params": [0, 0, 0, 22, 0, 8, -2, 0],
			"traits": []
		},
		{
			"id": 5,
			"name": "鳞甲",
			"icon_index": 139,
			"description": "鳞片状的护甲。",
			"atype_id": 3,
			"etype_id": 2,
			"price": 2800,
			"params": [0, 0, 0, 30, 0, 12, -3, 0],
			"traits": []
		},
		
		# ========== 重型护甲 ==========
		{
			"id": 6,
			"name": "板甲",
			"icon_index": 140,
			"description": "由金属板制成的重型护甲。",
			"atype_id": 4,
			"etype_id": 2,
			"price": 5000,
			"params": [0, 0, 0, 45, 0, 15, -5, 0],
			"traits": [{"code": 62, "data_id": 1, "value": 0.9}]
		},
		{
			"id": 7,
			"name": "骑士铠甲",
			"icon_index": 141,
			"description": "骑士团正式配发的铠甲。",
			"atype_id": 4,
			"etype_id": 2,
			"price": 12000,
			"params": [0, 0, 5, 55, 0, 20, -3, 0],
			"traits": [{"code": 62, "data_id": 1, "value": 0.85}]
		},
		{
			"id": 8,
			"name": "圣骑士铠甲",
			"icon_index": 142,
			"description": "神圣骑士的铠甲，蕴含祝福。",
			"atype_id": 4,
			"etype_id": 2,
			"price": 35000,
			"params": [100, 50, 10, 70, 10, 25, 0, 10],
			"traits": [{"code": 62, "data_id": 8, "value": 0.5}]
		},
		
		# ========== 法袍 ==========
		{
			"id": 9,
			"name": "魔法袍",
			"icon_index": 143,
			"description": "增强魔法的法袍。",
			"atype_id": 5,
			"etype_id": 2,
			"price": 600,
			"params": [0, 20, 0, 5, 10, 10, 0, 0],
			"traits": [{"code": 33, "data_id": 0, "value": 1.1}]
		},
		{
			"id": 10,
			"name": "贤者法袍",
			"icon_index": 144,
			"description": "贤者穿的法袍。",
			"atype_id": 5,
			"etype_id": 2,
			"price": 3500,
			"params": [50, 80, 0, 12, 25, 20, 0, 5],
			"traits": [{"code": 33, "data_id": 0, "value": 1.2}]
		},
		{
			"id": 11,
			"name": "大法师之袍",
			"icon_index": 145,
			"description": "传说中的大法师所穿的法袍。",
			"atype_id": 5,
			"etype_id": 2,
			"price": 30000,
			"params": [100, 150, 5, 20, 50, 30, 5, 10],
			"traits": [{"code": 33, "data_id": 0, "value": 1.4}]
		},
		
		# ========== 头盔 ==========
		{
			"id": 12,
			"name": "皮帽",
			"icon_index": 146,
			"description": "皮革制成的帽子。",
			"atype_id": 1,
			"etype_id": 3,
			"price": 150,
			"params": [0, 0, 0, 2, 0, 1, 0, 0],
			"traits": []
		},
		{
			"id": 13,
			"name": "铁盔",
			"icon_index": 147,
			"description": "铁制的头盔。",
			"atype_id": 2,
			"etype_id": 3,
			"price": 500,
			"params": [0, 0, 0, 6, 0, 2, 0, 0],
			"traits": []
		},
		{
			"id": 14,
			"name": "骑士头盔",
			"icon_index": 148,
			"description": "骑士用的头盔。",
			"atype_id": 3,
			"etype_id": 3,
			"price": 2000,
			"params": [20, 0, 0, 12, 0, 5, 0, 0],
			"traits": []
		},
		{
			"id": 15,
			"name": "魔法头饰",
			"icon_index": 149,
			"description": "魔法师用的头饰。",
			"atype_id": 5,
			"etype_id": 3,
			"price": 1200,
			"params": [0, 30, 0, 3, 10, 5, 0, 0],
			"traits": []
		},
		
		# ========== 护腿 ==========
		{
			"id": 16,
			"name": "布鞋",
			"icon_index": 150,
			"description": "普通的鞋子。",
			"atype_id": 1,
			"etype_id": 4,
			"price": 80,
			"params": [0, 0, 0, 1, 0, 1, 1, 0],
			"traits": []
		},
		{
			"id": 17,
			"name": "皮靴",
			"icon_index": 151,
			"description": "结实的皮靴。",
			"atype_id": 2,
			"etype_id": 4,
			"price": 300,
			"params": [0, 0, 0, 4, 0, 2, 2, 0],
			"traits": []
		},
		{
			"id": 18,
			"name": "铁靴",
			"icon_index": 152,
			"description": "铁制的重靴。",
			"atype_id": 3,
			"etype_id": 4,
			"price": 1000,
			"params": [0, 0, 0, 8, 0, 4, -1, 0],
			"traits": []
		},
		
		# ========== 饰品 ==========
		{
			"id": 19,
			"name": "铜戒指",
			"icon_index": 153,
			"description": "铜制的戒指。",
			"atype_id": 1,
			"etype_id": 5,
			"price": 200,
			"params": [10, 0, 1, 1, 1, 1, 0, 0],
			"traits": []
		},
		{
			"id": 20,
			"name": "银戒指",
			"icon_index": 154,
			"description": "银制的戒指，有魔力增幅效果。",
			"atype_id": 2,
			"etype_id": 5,
			"price": 1500,
			"params": [30, 20, 2, 2, 5, 3, 2, 2],
			"traits": []
		},
		{
			"id": 21,
			"name": "金戒指",
			"icon_index": 155,
			"description": "金制的戒指，蕴含强大魔力。",
			"atype_id": 3,
			"etype_id": 5,
			"price": 5000,
			"params": [50, 40, 5, 5, 10, 8, 5, 5],
			"traits": []
		},
		{
			"id": 22,
			"name": "力量护符",
			"icon_index": 156,
			"description": "提升力量的护符。",
			"atype_id": 1,
			"etype_id": 6,
			"price": 800,
			"params": [0, 0, 10, 0, 0, 0, 0, 0],
			"traits": []
		},
		{
			"id": 23,
			"name": "守护护符",
			"icon_index": 157,
			"description": "提升防御的护符。",
			"atype_id": 1,
			"etype_id": 6,
			"price": 800,
			"params": [0, 0, 0, 10, 0, 5, 0, 0],
			"traits": []
		},
		{
			"id": 24,
			"name": "速度之靴",
			"icon_index": 158,
			"description": "穿上后速度提升。",
			"atype_id": 2,
			"etype_id": 4,
			"price": 2500,
			"params": [0, 0, 0, 5, 0, 5, 15, 0],
			"traits": []
		},
		{
			"id": 25,
			"name": "幸运金币",
			"icon_index": 159,
			"description": "据说能带来好运。",
			"atype_id": 2,
			"etype_id": 6,
			"price": 3000,
			"params": [0, 0, 0, 0, 0, 0, 0, 20],
			"traits": [{"code": 23, "data_id": 0, "value": 0.1}]
		}
	]

# ========== 创建敌人 ==========

func _create_enemies() -> Array:
	return [
		null,		# ID 0 保留
		
		# ========== 弱小敌人 (Lv 1-5) ==========
		{
			"id": 1,
			"name": "史莱姆",
			"battler_name": "Slime",
			"battler_hue": 0,
			"params": [80, 0, 8, 3, 5, 5, 8, 5],
			"exp": 8,
			"gold": 5,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1}
			]
		},
		{
			"id": 2,
			"name": "大史莱姆",
			"battler_name": "Slime",
			"battler_hue": 180,
			"params": [150, 0, 12, 5, 8, 8, 6, 5],
			"exp": 15,
			"gold": 10,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1}
			]
		},
		{
			"id": 3,
			"name": "哥布林",
			"battler_name": "Goblin",
			"battler_hue": 0,
			"params": [100, 0, 12, 5, 8, 5, 10, 8],
			"exp": 12,
			"gold": 8,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1}
			]
		},
		{
			"id": 4,
			"name": "哥布林法师",
			"battler_name": "Goblin",
			"battler_hue": 280,
			"params": [80, 30, 6, 3, 18, 10, 8, 10],
			"exp": 18,
			"gold": 15,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 11}
			]
		},
		{
			"id": 5,
			"name": "蝙蝠",
			"battler_name": "Bat",
			"battler_hue": 0,
			"params": [60, 0, 10, 3, 5, 3, 15, 5],
			"exp": 6,
			"gold": 3,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1}
			]
		},
		
		# ========== 普通敌人 (Lv 5-15) ==========
		{
			"id": 6,
			"name": "兽人",
			"battler_name": "Orc",
			"battler_hue": 0,
			"params": [250, 0, 25, 12, 10, 8, 12, 8],
			"exp": 35,
			"gold": 25,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 2}
			]
		},
		{
			"id": 7,
			"name": "兽人战士",
			"battler_name": "Orc",
			"battler_hue": 30,
			"params": [350, 0, 35, 18, 12, 10, 10, 8],
			"exp": 50,
			"gold": 35,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 4}
			]
		},
		{
			"id": 8,
			"name": "骷髅",
			"battler_name": "Skeleton",
			"battler_hue": 0,
			"params": [180, 0, 22, 8, 15, 12, 8, 8],
			"exp": 30,
			"gold": 20,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1}
			]
		},
		{
			"id": 9,
			"name": "骷髅战士",
			"battler_name": "Skeleton",
			"battler_hue": 60,
			"params": [280, 0, 32, 15, 18, 15, 12, 10],
			"exp": 45,
			"gold": 30,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 2}
			]
		},
		{
			"id": 10,
			"name": "暗影",
			"battler_name": "Ghost",
			"battler_hue": 200,
			"params": [150, 50, 15, 10, 25, 20, 12, 15],
			"exp": 40,
			"gold": 25,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 11},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 16}
			]
		},
		
		# ========== 强力敌人 (Lv 15-30) ==========
		{
			"id": 11,
			"name": "魔像",
			"battler_name": "Golem",
			"battler_hue": 0,
			"params": [600, 0, 45, 35, 15, 15, 5, 5],
			"exp": 80,
			"gold": 60,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 4}
			]
		},
		{
			"id": 12,
			"name": "黑暗法师",
			"battler_name": "DarkMage",
			"battler_hue": 0,
			"params": [350, 150, 20, 15, 50, 35, 18, 20],
			"exp": 90,
			"gold": 70,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 12},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 13},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 2, "skill_id": 18}
			]
		},
		{
			"id": 13,
			"name": "恶魔",
			"battler_name": "Demon",
			"battler_hue": 0,
			"params": [500, 80, 40, 25, 40, 25, 22, 15],
			"exp": 100,
			"gold": 80,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 14}
			]
		},
		{
			"id": 14,
			"name": "吸血鬼",
			"battler_name": "Vampire",
			"battler_hue": 0,
			"params": [450, 100, 35, 20, 45, 30, 25, 20],
			"exp": 120,
			"gold": 100,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 16},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 2, "skill_id": 32}
			]
		},
		{
			"id": 15,
			"name": "龙",
			"battler_name": "Dragon",
			"battler_hue": 0,
			"params": [1000, 200, 60, 40, 50, 40, 20, 20],
			"exp": 200,
			"gold": 200,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 4, "skill_id": 4},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 13},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 2, "skill_id": 14}
			]
		},
		
		# ========== BOSS 敌人 ==========
		{
			"id": 20,
			"name": "哥布林王",
			"battler_name": "GoblinKing",
			"battler_hue": 0,
			"params": [800, 0, 55, 30, 25, 20, 18, 15],
			"exp": 300,
			"gold": 300,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 4},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 2, "skill_id": 43}
			]
		},
		{
			"id": 21,
			"name": "死灵法师",
			"battler_name": "Necromancer",
			"battler_hue": 0,
			"params": [600, 300, 30, 20, 70, 50, 20, 25],
			"exp": 400,
			"gold": 400,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 18},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 4, "skill_id": 24},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 2, "skill_id": 55}
			]
		},
		{
			"id": 22,
			"name": "恶魔领主",
			"battler_name": "DemonLord",
			"battler_hue": 0,
			"params": [1200, 200, 80, 50, 80, 50, 30, 25],
			"exp": 600,
			"gold": 600,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 4, "skill_id": 14},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 13},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 2, "skill_id": 72}
			]
		},
		{
			"id": 23,
			"name": "龙王",
			"battler_name": "DragonKing",
			"battler_hue": 0,
			"params": [2000, 300, 100, 70, 80, 60, 25, 30],
			"exp": 1000,
			"gold": 1000,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 4, "skill_id": 4},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 15},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 2, "skill_id": 14}
			]
		},
		{
			"id": 99,
			"name": "魔王",
			"battler_name": "DemonKing",
			"battler_hue": 0,
			"params": [5000, 999, 150, 100, 120, 80, 40, 40],
			"exp": 5000,
			"gold": 5000,
			"actions": [
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 5, "skill_id": 1},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 4, "skill_id": 14},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 4, "skill_id": 24},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 3, "skill_id": 54},
				{"condition_param1": 0, "condition_param2": 0, "condition_type": 0, "rating": 2, "skill_id": 55}
			]
		}
	]

# ========== 创建敌群 ==========

func _create_troops() -> Array:
	return [
		null,		# ID 0 保留
		
		# ========== 草原敌群 ==========
		{
			"id": 1,
			"name": "史莱姆*2",
			"members": [
				{"enemy_id": 1, "x": 250, "y": 200, "hidden": false},
				{"enemy_id": 1, "x": 350, "y": 250, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 2,
			"name": "史莱姆*3",
			"members": [
				{"enemy_id": 1, "x": 200, "y": 180, "hidden": false},
				{"enemy_id": 1, "x": 300, "y": 220, "hidden": false},
				{"enemy_id": 1, "x": 400, "y": 260, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 3,
			"name": "哥布林*2",
			"members": [
				{"enemy_id": 3, "x": 250, "y": 200, "hidden": false},
				{"enemy_id": 3, "x": 350, "y": 250, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 4,
			"name": "哥布林小队",
			"members": [
				{"enemy_id": 3, "x": 200, "y": 180, "hidden": false},
				{"enemy_id": 3, "x": 320, "y": 220, "hidden": false},
				{"enemy_id": 4, "x": 440, "y": 260, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 5,
			"name": "混合小队",
			"members": [
				{"enemy_id": 1, "x": 200, "y": 200, "hidden": false},
				{"enemy_id": 3, "x": 320, "y": 180, "hidden": false},
				{"enemy_id": 5, "x": 440, "y": 220, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		
		# ========== 洞窟敌群 ==========
		{
			"id": 6,
			"name": "蝙蝠群",
			"members": [
				{"enemy_id": 5, "x": 200, "y": 150, "hidden": false},
				{"enemy_id": 5, "x": 300, "y": 200, "hidden": false},
				{"enemy_id": 5, "x": 400, "y": 250, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 7,
			"name": "骷髅*2",
			"members": [
				{"enemy_id": 8, "x": 250, "y": 200, "hidden": false},
				{"enemy_id": 8, "x": 350, "y": 250, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 8,
			"name": "骷髅小队",
			"members": [
				{"enemy_id": 8, "x": 180, "y": 180, "hidden": false},
				{"enemy_id": 8, "x": 300, "y": 220, "hidden": false},
				{"enemy_id": 9, "x": 420, "y": 260, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 9,
			"name": "暗影*2",
			"members": [
				{"enemy_id": 10, "x": 250, "y": 200, "hidden": false},
				{"enemy_id": 10, "x": 350, "y": 250, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		
		# ========== 森林敌群 ==========
		{
			"id": 10,
			"name": "兽人*2",
			"members": [
				{"enemy_id": 6, "x": 250, "y": 200, "hidden": false},
				{"enemy_id": 6, "x": 350, "y": 250, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 11,
			"name": "兽人小队",
			"members": [
				{"enemy_id": 6, "x": 200, "y": 180, "hidden": false},
				{"enemy_id": 6, "x": 320, "y": 220, "hidden": false},
				{"enemy_id": 7, "x": 440, "y": 260, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		
		# ========== 遗迹敌群 ==========
		{
			"id": 12,
			"name": "魔像",
			"members": [
				{"enemy_id": 11, "x": 300, "y": 220, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 13,
			"name": "黑暗法师+魔像",
			"members": [
				{"enemy_id": 11, "x": 200, "y": 220, "hidden": false},
				{"enemy_id": 12, "x": 380, "y": 200, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 14,
			"name": "恶魔+暗影",
			"members": [
				{"enemy_id": 13, "x": 280, "y": 200, "hidden": false},
				{"enemy_id": 10, "x": 420, "y": 250, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		
		# ========== BOSS 战 ==========
		{
			"id": 20,
			"name": "哥布林王",
			"members": [
				{"enemy_id": 20, "x": 300, "y": 220, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 21,
			"name": "死灵法师+骷髅",
			"members": [
				{"enemy_id": 21, "x": 300, "y": 200, "hidden": false},
				{"enemy_id": 8, "x": 180, "y": 250, "hidden": false},
				{"enemy_id": 8, "x": 420, "y": 250, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 22,
			"name": "恶魔领主",
			"members": [
				{"enemy_id": 22, "x": 300, "y": 220, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 23,
			"name": "龙王",
			"members": [
				{"enemy_id": 23, "x": 300, "y": 220, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		},
		{
			"id": 99,
			"name": "魔王",
			"members": [
				{"enemy_id": 99, "x": 300, "y": 220, "hidden": false}
			],
			"pages": [{"conditions": {}, "list": [], "span": 0}]
		}
	]

# ========== 创建状态效果 ==========

func _create_states() -> Array:
	return [
		null,		# ID 0 保留
		
		# ========== 负面状态 ==========
		{
			"id": 1,
			"name": "中毒",
			"icon_index": 175,
			"restriction": 0,
			"priority": 50,
			"auto_removal_timing": 2,
			"min_turns": 3,
			"max_turns": 5,
			"message1": "%s中毒了！",
			"message2": "%s中毒了！",
			"message3": "",
			"message4": "%s的毒解除了！",
			"traits": [{"code": 22, "data_id": 7, "value": 0.1}]
		},
		{
			"id": 2,
			"name": "失明",
			"icon_index": 176,
			"restriction": 0,
			"priority": 60,
			"auto_removal_timing": 2,
			"min_turns": 2,
			"max_turns": 4,
			"message1": "%s失明了！",
			"message2": "%s失明了！",
			"message3": "",
			"message4": "%s恢复了视力！",
			"traits": [{"code": 22, "data_id": 0, "value": 0.5}]
		},
		{
			"id": 3,
			"name": "沉默",
			"icon_index": 177,
			"restriction": 0,
			"priority": 70,
			"auto_removal_timing": 2,
			"min_turns": 2,
			"max_turns": 4,
			"message1": "%s被沉默了！",
			"message2": "%s被沉默了！",
			"message3": "",
			"message4": "%s的沉默解除了！",
			"traits": [{"code": 14, "data_id": 1, "value": 1}]
		},
		{
			"id": 4,
			"name": "混乱",
			"icon_index": 178,
			"restriction": 2,
			"priority": 80,
			"auto_removal_timing": 2,
			"min_turns": 1,
			"max_turns": 3,
			"message1": "%s混乱了！",
			"message2": "%s混乱了！",
			"message3": "",
			"message4": "%s恢复了理智！"
		},
		{
			"id": 5,
			"name": "睡眠",
			"icon_index": 179,
			"restriction": 4,
			"priority": 90,
			"auto_removal_timing": 2,
			"min_turns": 2,
			"max_turns": 4,
			"message1": "%s睡着了！",
			"message2": "%s睡着了！",
			"message3": "",
			"message4": "%s醒来了！"
		},
		{
			"id": 6,
			"name": "麻痹",
			"icon_index": 180,
			"restriction": 4,
			"priority": 90,
			"auto_removal_timing": 2,
			"min_turns": 1,
			"max_turns": 3,
			"message1": "%s麻痹了！",
			"message2": "%s麻痹了！",
			"message3": "",
			"message4": "%s的麻痹解除了！"
		},
		{
			"id": 7,
			"name": "即死",
			"icon_index": 181,
			"restriction": 0,
			"priority": 100,
			"auto_removal_timing": 0,
			"message1": "%s倒下了！",
			"message2": "%s倒下了！",
			"message3": "",
			"message4": ""
		},
		{
			"id": 8,
			"name": "诅咒",
			"icon_index": 182,
			"restriction": 0,
			"priority": 85,
			"auto_removal_timing": 2,
			"min_turns": 5,
			"max_turns": 10,
			"message1": "%s受到了诅咒！",
			"message2": "%s受到了诅咒！",
			"message3": "",
			"message4": "%s的诅咒解除了！",
			"traits": [
				{"code": 21, "data_id": 2, "value": 0.5},
				{"code": 21, "data_id": 3, "value": 0.5}
			]
		},
		
		# ========== 正面状态 ==========
		{
			"id": 11,
			"name": "防御提升",
			"icon_index": 185,
			"restriction": 0,
			"priority": 50,
			"auto_removal_timing": 2,
			"min_turns": 3,
			"max_turns": 5,
			"message1": "%s的防御提升了！",
			"message2": "%s的防御提升了！",
			"message3": "",
			"message4": "%s的防御恢复了正常。",
			"traits": [{"code": 21, "data_id": 3, "value": 1.5}]
		},
		{
			"id": 12,
			"name": "攻击提升",
			"icon_index": 186,
			"restriction": 0,
			"priority": 50,
			"auto_removal_timing": 2,
			"min_turns": 3,
			"max_turns": 5,
			"message1": "%s的攻击力提升了！",
			"message2": "%s的攻击力提升了！",
			"message3": "",
			"message4": "%s的攻击力恢复了正常。",
			"traits": [{"code": 21, "data_id": 2, "value": 1.5}]
		},
		{
			"id": 13,
			"name": "速度提升",
			"icon_index": 187,
			"restriction": 0,
			"priority": 50,
			"auto_removal_timing": 2,
			"min_turns": 3,
			"max_turns": 5,
			"message1": "%s的速度提升了！",
			"message2": "%s的速度提升了！",
			"message3": "",
			"message4": "%s的速度恢复了正常。",
			"traits": [{"code": 21, "data_id": 6, "value": 1.5}]
		},
		{
			"id": 14,
			"name": "再生",
			"icon_index": 188,
			"restriction": 0,
			"priority": 50,
			"auto_removal_timing": 2,
			"min_turns": 5,
			"max_turns": 10,
			"message1": "%s获得了再生的力量！",
			"message2": "%s获得了再生的力量！",
			"message3": "",
			"message4": "%s的再生效果消失了。",
			"traits": [{"code": 22, "data_id": 7, "value": 0.1}]
		},
		{
			"id": 15,
			"name": "护盾",
			"icon_index": 189,
			"restriction": 0,
			"priority": 60,
			"auto_removal_timing": 2,
			"min_turns": 3,
			"max_turns": 5,
			"message1": "%s获得了护盾！",
			"message2": "%s获得了护盾！",
			"message3": "",
			"message4": "%s的护盾消失了。",
			"traits": [{"code": 62, "data_id": 1, "value": 0.5}]
		},
		{
			"id": 16,
			"name": "魔法屏障",
			"icon_index": 190,
			"restriction": 0,
			"priority": 60,
			"auto_removal_timing": 2,
			"min_turns": 3,
			"max_turns": 5,
			"message1": "%s被魔法屏障包围！",
			"message2": "%s被魔法屏障包围！",
			"message3": "",
			"message4": "%s的魔法屏障消失了。",
			"traits": [{"code": 62, "data_id": 2, "value": 0.5}]
		},
		{
			"id": 17,
			"name": "反射",
			"icon_index": 191,
			"restriction": 0,
			"priority": 70,
			"auto_removal_timing": 2,
			"min_turns": 2,
			"max_turns": 4,
			"message1": "%s获得了反射能力！",
			"message2": "%s获得了反射能力！",
			"message3": "",
			"message4": "%s的反射能力消失了。"
		}
	]

# ========== 创建动画 ==========

func _create_animations() -> Array:
	return [
		null,		# ID 0 保留
		
		# ========== 物理攻击动画 ==========
		{
			"id": 1,
			"name": "斩击",
			"animation1_name": "HitPhysical",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		{
			"id": 2,
			"name": "重击",
			"animation1_name": "HitPhysical",
			"animation1_hue": 30,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		{
			"id": 3,
			"name": "突刺",
			"animation1_name": "HitEffect",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		
		# ========== 魔法动画 ==========
		{
			"id": 11,
			"name": "火球",
			"animation1_name": "Fire1",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		{
			"id": 12,
			"name": "火焰",
			"animation1_name": "Fire2",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		{
			"id": 13,
			"name": "冰冻",
			"animation1_name": "Ice1",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		{
			"id": 14,
			"name": "雷电",
			"animation1_name": "Thunder1",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		{
			"id": 15,
			"name": "圣光",
			"animation1_name": "Light1",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		{
			"id": 16,
			"name": "黑暗",
			"animation1_name": "Darkness1",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		
		# ========== 治疗动画 ==========
		{
			"id": 21,
			"name": "治疗",
			"animation1_name": "Heal1",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 0,
			"frames": [],
			"timings": []
		},
		{
			"id": 22,
			"name": "大治愈",
			"animation1_name": "Heal2",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 0,
			"frames": [],
			"timings": []
		},
		{
			"id": 23,
			"name": "复活",
			"animation1_name": "Resurrection",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 0,
			"frames": [],
			"timings": []
		},
		
		# ========== 状态动画 ==========
		{
			"id": 31,
			"name": "增益",
			"animation1_name": "Buff1",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 0,
			"frames": [],
			"timings": []
		},
		{
			"id": 32,
			"name": "减益",
			"animation1_name": "Debuff1",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		{
			"id": 33,
			"name": "中毒",
			"animation1_name": "Poison",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		{
			"id": 34,
			"name": "麻痹",
			"animation1_name": "Paralyze",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		},
		{
			"id": 35,
			"name": "睡眠",
			"animation1_name": "Sleep",
			"animation1_hue": 0,
			"animation2_name": "",
			"animation2_hue": 0,
			"position": 1,
			"frames": [],
			"timings": []
		}
	]

# ========== 创建图块集 ==========

func _create_tilesets() -> Array:
	return [
		null,		# ID 0 保留
		
		# ========== 野外图块集 ==========
		{
			"id": 1,
			"name": "Overworld - 野外",
			"tileset_names": [
				"World_A1",
				"World_A2",
				"World_B",
				"World_C"
			],
			"flags": [],
			"mode": 1,
			"note": "用于野外地图的图块集",
			"tileset_name": "野外",
			"autotile_bodies": [],
			"autotile_terrains": []
		},
		
		# ========== 城镇图块集 ==========
		{
			"id": 2,
			"name": "Town - 城镇",
			"tileset_names": [
				"Town_A1",
				"Town_A2",
				"Town_B",
				"Town_C"
			],
			"flags": [],
			"mode": 1,
			"note": "用于城镇地图的图块集",
			"tileset_name": "城镇",
			"autotile_bodies": [],
			"autotile_terrains": []
		},
		
		# ========== 洞窟图块集 ==========
		{
			"id": 3,
			"name": "Dungeon - 地牢",
			"tileset_names": [
				"Dungeon_A1",
				"Dungeon_A2",
				"Dungeon_B",
				"Dungeon_C"
			],
			"flags": [],
			"mode": 1,
			"note": "用于洞窟和地牢的图块集",
			"tileset_name": "地牢",
			"autotile_bodies": [],
			"autotile_terrains": []
		},
		
		# ========== 城堡图块集 ==========
		{
			"id": 4,
			"name": "Castle - 城堡",
			"tileset_names": [
				"Castle_A1",
				"Castle_A2",
				"Castle_B",
				"Castle_C"
			],
			"flags": [],
			"mode": 1,
			"note": "用于城堡内部的图块集",
			"tileset_name": "城堡",
			"autotile_bodies": [],
			"autotile_terrains": []
		},
		
		# ========== 室内图块集 ==========
		{
			"id": 5,
			"name": "Interior - 室内",
			"tileset_names": [
				"Interior_A1",
				"Interior_A2",
				"Interior_B",
				"Interior_C"
			],
			"flags": [],
			"mode": 1,
			"note": "用于房屋内部的图块集",
			"tileset_name": "室内",
			"autotile_bodies": [],
			"autotile_terrains": []
		},
		
		# ========== 雪地图块集 ==========
		{
			"id": 6,
			"name": "Snow - 雪地",
			"tileset_names": [
				"Snow_A1",
				"Snow_A2",
				"Snow_B",
				"Snow_C"
			],
			"flags": [],
			"mode": 1,
			"note": "用于雪地场景的图块集",
			"tileset_name": "雪地",
			"autotile_bodies": [],
			"autotile_terrains": []
		},
		
		# ========== 沙漠图块集 ==========
		{
			"id": 7,
			"name": "Desert - 沙漠",
			"tileset_names": [
				"Desert_A1",
				"Desert_A2",
				"Desert_B",
				"Desert_C"
			],
			"flags": [],
			"mode": 1,
			"note": "用于沙漠场景的图块集",
			"tileset_name": "沙漠",
			"autotile_bodies": [],
			"autotile_terrains": []
		}
	]

# ========== 创建系统设置 ==========

func _create_system() -> Dictionary:
	return {
		"game_title": "未命名游戏",
		"version_id": 0,
		"locale": "zh_CN",
		"party_members": [1],
		"currency_unit": "G",
		"window_tone": [0, 0, 0, 0],
		"attack_motions": [
			{"type": 0, "weapon_image_id": 0},
			{"type": 0, "weapon_image_id": 1},
			{"type": 0, "weapon_image_id": 2},
			{"type": 0, "weapon_image_id": 3},
			{"type": 0, "weapon_image_id": 4},
			{"type": 0, "weapon_image_id": 5},
			{"type": 0, "weapon_image_id": 6},
			{"type": 0, "weapon_image_id": 7},
			{"type": 0, "weapon_image_id": 8},
			{"type": 0, "weapon_image_id": 9},
			{"type": 0, "weapon_image_id": 10}
		],
		"elements": ["", "物理", "火", "冰", "雷", "水", "土", "风", "光", "暗"],
		"skill_types": ["", "魔法", "特技"],
		"weapon_types": ["", "无", "短剑", "剑", "斧", "枪", "弓", "杖", "拳套", "书"],
		"armor_types": ["", "", "布衣", "皮甲", "链甲", "板甲", "法袍", "神器"],
		"switches": [
			"",
			"游戏开始",
			"获得勇者之剑",
			"击败哥布林王",
			"获得古代钥匙",
			"进入最终迷宫",
			"击败魔王",
			"结局A",
			"结局B",
			"结局C",
			"支线任务1完成",
			"支线任务2完成",
			"支线任务3完成",
			"隐藏道路开启",
			"商店折扣",
			"夜晚",
			"下雨",
			"BOSS战",
			"剧情进行中",
			"可以存档"
		],
		"variables": [
			"",
			"玩家等级",
			"游戏时间（小时）",
			"游戏时间（分钟）",
			"杀敌数",
			"金币获得",
			"死亡次数",
			"逃跑次数",
			"任务进度",
			"好感度-塞拉菲娜",
			"好感度-格雷森",
			"好感度-莉莉丝",
			"剧情章节",
			"当前地图",
			"天气",
			"时间",
			"游戏难度",
			"新游戏+",
			"",
			""
		],
		"title1_name": "Title",
		"title2_name": "",
		"opt_draw_title": true,
		"opt_transparent": false,
		"opt_followers": true,
		"opt_slip_death": false,
		"opt_floor_death": false,
		"opt_display_tp": true,
		"opt_extra_exp": false,
		"opt_side_view": true,
		"boat": {
			"bgm": {"name": "Ship1", "pan": 0, "pitch": 100, "volume": 90},
			"character_index": 0,
			"character_name": "Vehicle",
			"start_map_id": 0,
			"start_x": 0,
			"start_y": 0
		},
		"ship": {
			"bgm": {"name": "Ship2", "pan": 0, "pitch": 100, "volume": 90},
			"character_index": 1,
			"character_name": "Vehicle",
			"start_map_id": 0,
			"start_x": 0,
			"start_y": 0
		},
		"airship": {
			"bgm": {"name": "Ship3", "pan": 0, "pitch": 100, "volume": 90},
			"character_index": 2,
			"character_name": "Vehicle",
			"start_map_id": 0,
			"start_x": 0,
			"start_y": 0
		},
		"title_bgm": {"name": "Title", "pan": 0, "pitch": 100, "volume": 90},
		"battle_bgm": {"name": "Battle", "pan": 0, "pitch": 100, "volume": 90},
		"defeat_me": {"name": "Defeat", "pan": 0, "pitch": 100, "volume": 90},
		"gameover_me": {"name": "Gameover", "pan": 0, "pitch": 100, "volume": 90},
		"victory_me": {"name": "Victory", "pan": 0, "pitch": 100, "volume": 90},
		"sounds": [
			{"name": "Cursor", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Decision", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Cancel", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Buzzer", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Equip", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Save", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Load", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "BattleStart", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Escape", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "EnemyAttack", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "EnemyDamage", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "ActorDamage", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Recovery", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Evasion", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "MagicEvasion", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Reflection", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Collapse", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "CollapseEnemy", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "Shop", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "UseItem", "pan": 0, "pitch": 100, "volume": 80},
			{"name": "UseSkill", "pan": 0, "pitch": 100, "volume": 80}
		]
	}
