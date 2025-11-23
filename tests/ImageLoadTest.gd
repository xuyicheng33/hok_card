extends Node

func _ready():
	test_card_database()

func test_card_database():
	print("=== 测试CardDatabase图片加载 ===")
	
	# 获取CardDatabase实例
	var card_database = get_node("/root/CardDatabase")
	if not card_database:
		print("错误: CardDatabase未找到")
		return
	
	# 初始化数据库
	card_database.initialize()
	
	# 获取所有卡牌
	var all_cards = card_database.get_all_cards()
	print("总共加载了 %d 张卡牌" % all_cards.size())
	
	# 检查每张卡牌的图片
	for card in all_cards:
		if card:
			print("卡牌: %s" % card.card_name)
			if card.card_image:
				print("  图片: %s (类型: %s)" % [str(card.card_image), card.card_image.get_class()])
			else:
				print("  图片: 无")
		else:
			print("错误: 发现空卡牌")
	
	# 测试特定卡牌
	var test_card_names = ["朵莉亚", "澜", "公孙离", "孙尚香", "瑶", "大乔"]
	for card_name in test_card_names:
		var card = card_database.find_card_by_name(card_name)
		if card:
			print("\n测试卡牌: %s" % card_name)
			if card.card_image:
				print("  图片加载成功: %s" % str(card.card_image))
			else:
				print("  图片加载失败")
		else:
			print("未找到卡牌: %s" % card_name)