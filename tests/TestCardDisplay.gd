extends Control

func _ready():
	test_card_display()

func test_card_display():
	print("=== 测试卡牌显示 ===")
	
	# 创建一个简单的测试场景
	var card_database = get_node("/root/CardDatabase")
	if not card_database:
		print("错误: CardDatabase未找到")
		return
	
	# 获取一张测试卡牌
	var test_card = card_database.find_card_by_name("朵莉亚")
	if not test_card:
		print("错误: 无法获取测试卡牌")
		return
	
	print("测试卡牌: %s" % test_card.card_name)
	if test_card.card_image:
		print("图片加载成功: %s" % str(test_card.card_image))
	else:
		print("图片加载失败")
	
	# 创建一个简单的TextureRect来显示图片
	var texture_rect = TextureRect.new()
	texture_rect.texture = test_card.card_image
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(200, 200)
	texture_rect.position = Vector2(100, 100)
	add_child(texture_rect)
	
	print("测试完成")