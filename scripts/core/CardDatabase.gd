extends Node

## 卡牌数据库
## 存储和管理所有卡牌数据
## 支持从JSON文件加载数据（数据驱动设计）

## 卡牌数据库字典，使用卡牌ID作为键
var cards: Dictionary = {}
var initialized: bool = false

## JSON数据相关
var json_data: Dictionary = {}
var json_file_path: String = "res://assets/data/cards_data.json"

func _ready():
	print("卡牌数据库初始化...")
	initialize()

## 初始化卡牌数据库
func initialize():
	if not initialized:
		print("开始初始化卡牌数据库...")
		# 尝试从JSON加载，如果失败则使用代码创建
		if _load_from_json():
			print("从JSON文件加载卡牌数据成功")
		else:
			print("警告：JSON加载失败，使用代码创建卡牌数据")
			_create_cards()
		initialized = true
		print("卡牌数据库初始化完成，共%d张卡牌" % cards.size())
	else:
		print("卡牌数据库已初始化，跳过重复初始化")

## 创建所有卡牌数据（备用，优先使用JSON）
func _create_cards():
	print("⚠️ 警告：JSON加载失败，使用备用硬编码数据")
	print("❌ 硬编码数据已过期，请检查JSON文件！")
	# 不再创建硬编码卡牌，强制使用JSON

## 根据ID获取卡牌
func get_card(card_id: String) -> Card:
	initialize()
	if cards.has(card_id):
		return cards[card_id].duplicate_card()
	else:
		print("警告: 找不到ID为 %s 的卡牌" % card_id)
		return null

## 获取所有卡牌ID列表
func get_all_card_ids() -> Array:
	initialize()
	return cards.keys()

## 获取所有卡牌的副本
func get_all_cards() -> Array:
	initialize()
	var card_list = []
	for card in cards.values():
		card_list.append(card.duplicate_card())
	return card_list

## 根据名称搜索卡牌
func find_card_by_name(card_name: String) -> Card:
	initialize()
	for card in cards.values():
		if card.card_name == card_name:
			return card.duplicate_card()
	print("警告: 找不到名称为 %s 的卡牌" % card_name)
	return null

## 获取随机卡牌
func get_random_card() -> Card:
	initialize()
	var card_ids = get_all_card_ids()
	if card_ids.size() > 0:
		var random_id = card_ids[randi() % card_ids.size()]
		return get_card(random_id)
	return null

## 打印所有卡牌信息（用于调试）
func print_all_cards():
	initialize()
	print("=== 卡牌数据库 ===")
	for card_id in cards.keys():
		var card = cards[card_id]
		print("ID: %s" % card_id)
		print(card.get_card_info())
		print("---")

## ================== JSON数据加载系统 ==================

## 从JSON文件加载卡牌数据
func _load_from_json() -> bool:
	print("尝试从JSON文件加载卡牌数据: %s" % json_file_path)
	
	# 检查文件是否存在
	if not ResourceLoader.exists(json_file_path):
		print("错误：JSON文件不存在: %s" % json_file_path)
		return false
	
	# 加载文件
	var file = FileAccess.open(json_file_path, FileAccess.READ)
	if not file:
		print("错误：无法打开JSON文件: %s" % json_file_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	# 解析JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("错误：JSON解析失败: %s" % json.error_string)
		return false
	
	json_data = json.data
	
	# 验证JSON结构
	if not json_data.has("cards") or not json_data.cards is Dictionary:
		print("错误：JSON文件缺少有效的cards数据")
		return false
	
	# 创建卡牌对象
	return _create_cards_from_json()

## 从JSON数据创建卡牌对象
func _create_cards_from_json() -> bool:
	print("从JSON数据创建卡牌对象...")
	
	var cards_data = json_data.cards
	var success_count = 0
	
	for card_id in cards_data.keys():
		var card_info = cards_data[card_id]
		var card = _create_card_from_json_data(card_id, card_info)
		
		if card:
			cards[card_id] = card
			success_count += 1
			print("成功创建卡牌: %s" % card.card_name)
		else:
			print("警告：创建卡牌失败: %s" % card_id)
	
	print("从JSON创建了 %d/%d 张卡牌" % [success_count, cards_data.size()])
	return success_count > 0

## 从单个JSON数据创建卡牌
func _create_card_from_json_data(card_id: String, card_info: Dictionary) -> Card:
	# 验证必需字段
	var required_fields = ["name", "description", "attack", "health", "armor"]
	for field in required_fields:
		if not card_info.has(field):
			print("错误：卡牌 %s 缺少必需字段: %s" % [card_id, field])
			return null
	
	# 加载卡牌图片
	var card_image = null
	if card_info.has("image_path") and card_info.image_path != "":
		if ResourceLoader.exists(card_info.image_path):
			card_image = load(card_info.image_path)
			print("成功加载%s图片: %s (资源类型: %s)" % [card_info.name, card_info.image_path, card_image.get_class() if card_image else "null"])
		else:
			print("警告：%s图片不存在: %s" % [card_info.name, card_info.image_path])
	else:
		print("卡牌%s没有配置图片路径" % card_info.name)
	
	# 创建卡牌对象
	# 确保正确处理skill_cost数值类型
	var skill_cost_value = 2  # 默认值
	if card_info.has("skill_cost"):
		skill_cost_value = int(card_info.skill_cost)  # 强制转换为整数
		print("从 JSON 读取 %s 的 skill_cost: %s -> %d" % [card_info.name, str(card_info.skill_cost), skill_cost_value])
	
	var card = Card.new(
		card_info.name,
		card_info.description,
		card_info.attack,
		card_info.health,
		card_info.armor,
		card_info.get("skill_name", ""),
		card_info.get("skill_effect", ""),
		card_image,
		card_info.get("passive_skill_name", ""),
		card_info.get("passive_skill_effect", ""),
		skill_cost_value,
		card_info.get("skill_ends_turn", false)
	)
	
	# 设置卡牌ID
	card.card_id = card_id
	
	# 🐛 调试：验证所有卡牌数据
	print("🐛 [CardDatabase] 创建卡牌: %s" % card_info.name)
	print("   skill_effect长度: %d" % card.skill_effect.length())
	print("   passive_skill_effect长度: %d" % card.passive_skill_effect.length())
	
	if card_info.name == "公孙离":
		print("============================================================")
		print("🐛🐛🐛 [公孙离] 特别调试")
		print("   JSON skill_effect前50字符: [%s]" % card_info.get("skill_effect", "").substr(0, 50))
		print("   Card skill_effect前50字符: [%s]" % card.skill_effect.substr(0, 50))
		print("   JSON passive前50字符: [%s]" % card_info.get("passive_skill_effect", "").substr(0, 50))
		print("   Card passive前50字符: [%s]" % card.passive_skill_effect.substr(0, 50))
		print("============================================================")
	
	# 设置个性化暴击率（如果配置文件中有的话）
	if card_info.has("crit_rate"):
		card.crit_rate = card_info.crit_rate
		print("为%s设置初始暴击率: %.1f%%" % [card.card_name, card.crit_rate * 100])
	
	# 设置个性化暴击效果（如果配置文件中有的话）
	if card_info.has("crit_damage"):
		card.crit_damage = card_info.crit_damage
		print("为%s设置初始暴击效果: %.1f%%" % [card.card_name, card.crit_damage * 100])
	
	# 设置闪避率（公孙离专用）
	if card_info.has("dodge_rate"):
		card.dodge_rate = card_info.dodge_rate
		print("为%s设置初始闪避率: %.1f%%" % [card.card_name, card.dodge_rate * 100])
	
	# 验证卡牌图片是否正确设置
	if card.card_image:
		print("卡牌%s的图片已正确设置: %s" % [card.card_name, str(card.card_image)])
	else:
		print("卡牌%s的图片未设置或为空" % card.card_name)
	
	return card

## 获取JSON数据版本
func get_data_version() -> String:
	if json_data.has("version"):
		return json_data.version
	return "unknown"

## 获取所有卡牌类型
func get_card_types() -> Dictionary:
	if json_data.has("card_types"):
		return json_data.card_types
	return {}

## 获取所有稀有度
func get_rarities() -> Dictionary:
	if json_data.has("rarities"):
		return json_data.rarities
	return {}
