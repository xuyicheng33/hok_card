extends Node

func _ready():
	test_full_flow()

func test_full_flow():
	print("=== 完整流程测试 ===")
	
	# 1. 测试CardDatabase
	print("\n1. 测试CardDatabase:")
	var card_database = get_node("/root/CardDatabase")
	if not card_database:
		print("错误: CardDatabase未找到")
		return
	
	card_database.initialize()
	var all_cards = card_database.get_all_cards()
	print("加载了 %d 张卡牌" % all_cards.size())
	
	for card in all_cards:
		print("  %s: %s" % [card.card_name, "有图片" if card.card_image else "无图片"])
	
	# 2. 测试特定卡牌
	print("\n2. 测试特定卡牌:")
	var test_cards = ["朵莉亚", "澜", "公孙离"]
	for card_name in test_cards:
		var card = card_database.find_card_by_name(card_name)
		if card:
			print("  %s: %s" % [card_name, "图片加载成功" if card.card_image else "图片加载失败"])
			if card.card_image:
				print("    图片资源: %s" % str(card.card_image))
		else:
			print("  未找到卡牌: %s" % card_name)
	
	print("\n测试完成")