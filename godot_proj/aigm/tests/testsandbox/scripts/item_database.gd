extends RefCounted
## 沙盒物品定义：与 `assets/item_icons` 下 PNG 一一对应；[method get_def] 懒加载缓存。
class_name ItemDB

const BASE := "res://tests/testsandbox/assets/item_icons"

static var _defs: Dictionary = {}
static var _icon_tex_cache: Dictionary = {}


static func _ensure() -> void:
	if not _defs.is_empty():
		return
	_defs = {
		# Equipment
		"equipment_bag": _row("背包", "能装不少东西的随身包。", "Equipment/Bag.png", "equipment", 1),
		"equipment_belt": _row("腰带", "束紧衣袍，也能挂些小物件。", "Equipment/Belt.png", "equipment", 1),
		"equipment_helm": _row("头盔", "基础护头装备。", "Equipment/Helm.png", "equipment", 1),
		"equipment_iron_armor": _row("铁甲", "结实的铁制胸甲。", "Equipment/Iron Armor.png", "equipment", 1),
		"equipment_iron_boot": _row("铁靴", "沉重的铁靴，踏地有声。", "Equipment/Iron Boot.png", "equipment", 1),
		"equipment_iron_helmet": _row("铁盔", "覆盖面更多的铁制头盔。", "Equipment/Iron Helmet.png", "equipment", 1),
		"equipment_leather_armor": _row("皮甲", "轻便的皮革护甲。", "Equipment/Leather Armor.png", "equipment", 1),
		"equipment_leather_boot": _row("皮靴", "适合长途跋涉。", "Equipment/Leather Boot.png", "equipment", 1),
		"equipment_leather_helmet": _row("皮帽", "朴素的皮制护头。", "Equipment/Leather Helmet.png", "equipment", 1),
		"equipment_wizard_hat": _row("巫师帽", "尖尖的帽檐，好像会变聪明。", "Equipment/Wizard Hat.png", "equipment", 1),
		"equipment_wooden_armor": _row("木甲", "用木板拼成的简易护具。", "Equipment/Wooden Armor.png", "equipment", 1),
		# Food
		"food_apple": _row("苹果", "脆甜的红苹果，恢复一点点心情。", "Food/Apple.png", "food", 99),
		"food_beer": _row("麦酒", "泡沫丰富，少喝怡情。", "Food/Beer.png", "food", 99),
		"food_bread": _row("面包", "旅行必备的主食。", "Food/Bread.png", "food", 99),
		"food_cheese": _row("奶酪", "咸香浓郁，配面包刚好。", "Food/Cheese.png", "food", 99),
		"food_fish_steak": _row("鱼排", "煎得恰到好处的鱼肉。", "Food/Fish Steak.png", "food", 99),
		"food_green_apple": _row("青苹果", "略酸，但很提神。", "Food/Green Apple.png", "food", 99),
		"food_ham": _row("火腿", "咸香厚实的一片。", "Food/Ham.png", "food", 99),
		"food_meat": _row("肉块", "新鲜的肉，烤一烤更香。", "Food/Meat.png", "food", 99),
		"food_mushroom": _row("蘑菇", "采自林间，煮汤不错。", "Food/Mushroom.png", "food", 99),
		"food_wine": _row("葡萄酒", "果香与橡木桶气息。", "Food/Wine.png", "food", 99),
		"food_wine_2": _row("陈酿", "颜色更深，口感更醇。", "Food/Wine 2.png", "food", 99),
		# Material
		"material_fabric": _row("布料", "柔软的织物，可做衣物。", "Material/Fabric.png", "material", 99),
		"material_leather": _row("皮革", "鞣制过的皮料。", "Material/Leather.png", "material", 99),
		"material_paper": _row("纸张", "写字、卷轴或糊窗都行。", "Material/Paper.png", "material", 99),
		"material_rope": _row("绳索", "结实，能绑也能爬。", "Material/Rope.png", "material", 99),
		"material_string": _row("细线", "缝纫或小型陷阱用。", "Material/String.png", "material", 99),
		"material_wood_log": _row("原木", "伐木所得，可锯成板材。", "Material/Wood Log.png", "material", 99),
		"material_wooden_plank": _row("木板", "加工后的木料，建房做家具。", "Material/Wooden Plank.png", "material", 99),
		"material_wool": _row("羊毛", "蓬松保暖。", "Material/Wool.png", "material", 99),
		# Misc
		"misc_book": _row("书籍", "记载着故事或知识。", "Misc/Book.png", "misc", 99),
		"misc_book_2": _row("旧书", "书页泛黄，仍有可读之处。", "Misc/Book 2.png", "misc", 99),
		"misc_book_3": _row("精装书", "封面考究，像收藏品。", "Misc/Book 3.png", "misc", 99),
		"misc_candle": _row("蜡烛", "微弱但温暖的光。", "Misc/Candle.png", "misc", 99),
		"misc_chest": _row("宝箱", "里面也许有好东西。", "Misc/Chest.png", "misc", 1),
		"misc_copper_coin": _row("铜币", "最常见的零钱。", "Misc/Copper Coin.png", "misc", 999),
		"misc_crate": _row("木箱", "堆叠货物用。", "Misc/Crate.png", "misc", 99),
		"misc_envolop": _row("信封", "装着信件或秘密。", "Misc/Envolop.png", "misc", 99),
		"misc_gear": _row("齿轮", "机械零件。", "Misc/Gear.png", "misc", 99),
		"misc_golden_coin": _row("金币", "闪亮的大额货币。", "Misc/Golden Coin.png", "misc", 999),
		"misc_golden_key": _row("金钥匙", "能打开重要的门。", "Misc/Golden Key.png", "misc", 99),
		"misc_heart": _row("心形物", "象征生命或好感。", "Misc/Heart.png", "misc", 99),
		"misc_iron_key": _row("铁钥匙", "普通的门锁都能试试。", "Misc/Iron Key.png", "misc", 99),
		"misc_lantern": _row("提灯", "夜里照路很方便。", "Misc/Lantern.png", "misc", 1),
		"misc_map": _row("地图", "标记了路线与地点。", "Misc/Map.png", "misc", 1),
		"misc_rune_stone": _row("符文石", "刻着神秘符号。", "Misc/Rune Stone.png", "misc", 99),
		"misc_scroll": _row("卷轴", "可能记载法术或任务。", "Misc/Scroll.png", "misc", 99),
		"misc_silver_coin": _row("银币", "比铜币值钱一点。", "Misc/Silver Coin.png", "misc", 999),
		"misc_silver_key": _row("银钥匙", "精致且少见。", "Misc/Silver Key.png", "misc", 99),
		# Monster Part
		"monster_bone": _row("骨头", "来自某只魔物的残骸。", "Monster Part/Bone.png", "monster_part", 99),
		"monster_egg": _row("蛋", "小小的蛋，不知会孵出什么。", "Monster Part/Egg.png", "monster_part", 99),
		"monster_feather": _row("羽毛", "轻盈，可做箭羽。", "Monster Part/Feather.png", "monster_part", 99),
		"monster_egg_large": _row("魔物蛋", "个头很大，晃动时有声响。", "Monster Part/Monster Egg.png", "monster_part", 99),
		"monster_eye": _row("魔眼", "还在微微转动……", "Monster Part/Monster Eye.png", "monster_part", 99),
		"monster_meat": _row("魔物肉", "料理需谨慎。", "Monster Part/Monster Meat.png", "monster_part", 99),
		"monster_skull": _row("骷髅", "空洞的眼窝望着你。", "Monster Part/Skull.png", "monster_part", 99),
		"monster_slime_gel": _row("史莱姆凝胶", "黏糊糊，炼金常用。", "Monster Part/Slime Gel.png", "monster_part", 99),
		# Ore & Gem
		"ore_coal": _row("煤炭", "燃料与冶炼原料。", "Ore & Gem/Coal.png", "ore_gem", 99),
		"ore_copper_ingot": _row("铜锭", "冶炼后的铜材。", "Ore & Gem/Copper Ingot.png", "ore_gem", 99),
		"ore_copper_nugget": _row("铜块", "天然铜矿石碎块。", "Ore & Gem/Copper Nugget.png", "ore_gem", 99),
		"ore_crystal": _row("水晶", "透明而多面。", "Ore & Gem/Crystal.png", "ore_gem", 99),
		"ore_cut_emerald": _row("刻面祖母绿", "切割后的绿色宝石。", "Ore & Gem/Cut Emerald.png", "ore_gem", 99),
		"ore_cut_ruby": _row("刻面红宝石", "切割后的红色宝石。", "Ore & Gem/Cut Ruby.png", "ore_gem", 99),
		"ore_cut_sapphire": _row("刻面蓝宝石", "切割后的蓝色宝石。", "Ore & Gem/Cut Sapphire.png", "ore_gem", 99),
		"ore_cut_topaz": _row("刻面黄玉", "切割后的黄色宝石。", "Ore & Gem/Cut Topaz.png", "ore_gem", 99),
		"ore_diamond": _row("钻石", "坚硬且耀眼。", "Ore & Gem/Diamond.png", "ore_gem", 99),
		"ore_emerald": _row("祖母绿原石", "深绿色矿石。", "Ore & Gem/Emerald.png", "ore_gem", 99),
		"ore_gold_nugget": _row("金块", "沉甸甸的自然金。", "Ore & Gem/Gold Nugget.png", "ore_gem", 99),
		"ore_golden_ingot": _row("金锭", "财富的象征。", "Ore & Gem/Golden Ingot.png", "ore_gem", 99),
		"ore_obsidian": _row("黑曜石", "锋利如玻璃。", "Ore & Gem/Obsidian.png", "ore_gem", 99),
		"ore_pearl": _row("珍珠", "温润光泽。", "Ore & Gem/Pearl.png", "ore_gem", 99),
		"ore_ruby": _row("红宝石原石", "炽热的红色。", "Ore & Gem/Ruby.png", "ore_gem", 99),
		"ore_sapphire": _row("蓝宝石原石", "海洋般的蓝。", "Ore & Gem/Sapphire.png", "ore_gem", 99),
		"ore_silver_ingot": _row("银锭", "圣洁金属。", "Ore & Gem/Silver Ingot.png", "ore_gem", 99),
		"ore_silver_nugget": _row("银块", "闪亮的碎银。", "Ore & Gem/Silver Nugget.png", "ore_gem", 99),
		"ore_topaz": _row("黄玉原石", "暖黄色晶体。", "Ore & Gem/Topaz.png", "ore_gem", 99),
		# Potion
		"potion_blue": _row("蓝药水", "常用来恢复魔力。", "Potion/Blue Potion.png", "potion", 99),
		"potion_blue_2": _row("蓝药水·型贰", "魔力涌动更强。", "Potion/Blue Potion 2.png", "potion", 99),
		"potion_blue_3": _row("蓝药水·型叁", "瓶身纹路更复杂。", "Potion/Blue Potion 3.png", "potion", 99),
		"potion_empty_bottle": _row("空瓶", "可灌装或出售。", "Potion/Empty Bottle.png", "potion", 99),
		"potion_green": _row("绿药水", "也许是解毒剂。", "Potion/Green Potion.png", "potion", 99),
		"potion_green_2": _row("绿药水·型贰", "颜色略深。", "Potion/Green Potion 2.png", "potion", 99),
		"potion_green_3": _row("绿药水·型叁", "冒泡更欢快。", "Potion/Green Potion 3.png", "potion", 99),
		"potion_red": _row("红药水", "常用来恢复生命。", "Potion/Red Potion.png", "potion", 99),
		"potion_red_2": _row("红药水·型贰", "愈合气息更浓。", "Potion/Red Potion 2.png", "potion", 99),
		"potion_red_3": _row("红药水·型叁", "像浓缩的生命。", "Potion/Red Potion 3.png", "potion", 99),
		"potion_water_bottle": _row("水瓶", "解渴，也可稀释药剂。", "Potion/Water Bottle.png", "potion", 99),
		# Weapon & Tool
		"weapon_arrow": _row("箭矢", "配合弓使用。", "Weapon & Tool/Arrow.png", "weapon_tool", 999),
		"weapon_axe": _row("斧头", "伐木与劈砍。", "Weapon & Tool/Axe.png", "weapon_tool", 1),
		"weapon_bow": _row("弓", "远程射击。", "Weapon & Tool/Bow.png", "weapon_tool", 1),
		"weapon_emerald_staff": _row("祖母绿法杖", "杖端嵌着绿宝石。", "Weapon & Tool/Emerald Staff.png", "weapon_tool", 1),
		"weapon_golden_sword": _row("黄金剑", "华丽且锋利。", "Weapon & Tool/Golden Sword.png", "weapon_tool", 1),
		"weapon_hammer": _row("铁锤", "锻造与破甲。", "Weapon & Tool/Hammer.png", "weapon_tool", 1),
		"weapon_iron_shield": _row("铁盾", "可靠的格挡。", "Weapon & Tool/Iron Shield.png", "weapon_tool", 1),
		"weapon_iron_sword": _row("铁剑", "冒险者常用武器。", "Weapon & Tool/Iron Sword.png", "weapon_tool", 1),
		"weapon_knife": _row("小刀", "轻巧迅捷。", "Weapon & Tool/Knife.png", "weapon_tool", 1),
		"weapon_magic_wand": _row("魔杖", "施法者的伙伴。", "Weapon & Tool/Magic Wand.png", "weapon_tool", 1),
		"weapon_pickaxe": _row("镐", "挖矿必备。", "Weapon & Tool/Pickaxe.png", "weapon_tool", 1),
		"weapon_ruby_staff": _row("红宝石法杖", "炽热的魔力。", "Weapon & Tool/Ruby Staff.png", "weapon_tool", 1),
		"weapon_sapphire_staff": _row("蓝宝石法杖", "沉静的魔力。", "Weapon & Tool/Sapphire Staff.png", "weapon_tool", 1),
		"weapon_shovel": _row("铲子", "挖坑与园艺。", "Weapon & Tool/Shovel.png", "weapon_tool", 1),
		"weapon_silver_sword": _row("银剑", "对某些魔物有奇效。", "Weapon & Tool/Silver Sword.png", "weapon_tool", 1),
		"weapon_topaz_staff": _row("黄玉法杖", "温暖的魔力。", "Weapon & Tool/Topaz Staff.png", "weapon_tool", 1),
		"weapon_torch": _row("火把", "照明与驱赶野兽。", "Weapon & Tool/Torch.png", "weapon_tool", 1),
		"weapon_wooden_shield": _row("木盾", "轻便的起步装备。", "Weapon & Tool/Wooden Shield.png", "weapon_tool", 1),
		"weapon_wooden_staff": _row("木杖", "初学者的法杖。", "Weapon & Tool/Wooden Staff.png", "weapon_tool", 1),
		"weapon_wooden_sword": _row("木剑", "练习用。", "Weapon & Tool/Wooden Sword.png", "weapon_tool", 1),
	}


## 与 [method NekomimiWalker.add_item_to_inventory] 相同合并规则；返回**未能入格**的数量。
static func add_items_to_slots(slots: Array, max_slots: int, item_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	_ensure()
	var def: Dictionary = get_def(item_id)
	if def.is_empty():
		return amount
	var max_stack: int = int(def.get("max_stack", 99))
	var remaining: int = amount
	for slot in slots:
		if str(slot.get("id", "")) == item_id:
			var c: int = int(slot.get("count", 0))
			if c < max_stack:
				var take: int = mini(remaining, max_stack - c)
				slot["count"] = c + take
				remaining -= take
				if remaining <= 0:
					return 0
	while remaining > 0:
		if slots.size() >= max_slots:
			break
		var take2: int = mini(remaining, max_stack)
		slots.append({"id": item_id, "count": take2})
		remaining -= take2
	return remaining


## 从 [param slots] 的 [param slot_index] 移除至多 [param amount] 个；返回**实际移除**的数量（槽变空则删掉该格）。
static func remove_items_from_slot(slots: Array, slot_index: int, amount: int) -> int:
	if amount <= 0 or slot_index < 0 or slot_index >= slots.size():
		return 0
	var slot: Dictionary = slots[slot_index]
	var c: int = int(slot.get("count", 0))
	var take: int = mini(amount, c)
	if take <= 0:
		return 0
	c -= take
	if c <= 0:
		slots.remove_at(slot_index)
	else:
		slot["count"] = c
	return take


static func _row(display_name: String, description: String, rel_path: String, category: String, max_stack: int) -> Dictionary:
	return {
		"name": display_name,
		"description": description,
		"icon": "%s/%s" % [BASE, rel_path],
		"category": category,
		"max_stack": max_stack,
	}


static func get_def(item_id: String) -> Dictionary:
	_ensure()
	return _defs.get(item_id, {})


static func has_id(item_id: String) -> bool:
	_ensure()
	return _defs.has(item_id)


static func all_item_ids() -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for k in _defs.keys():
		out.append(k)
	return out


static func get_icon_texture(item_id: String) -> Texture2D:
	var d: Dictionary = get_def(item_id)
	if d.is_empty():
		return null
	var path: String = d.get("icon", "")
	if path.is_empty():
		return null
	if _icon_tex_cache.has(path):
		return _icon_tex_cache[path]
	var t: Texture2D = load(path) as Texture2D
	if t:
		_icon_tex_cache[path] = t
	return t
