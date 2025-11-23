extends Node

func _ready():
	test_image_loading()

func test_image_loading():
	print("开始测试图片加载...")
	
	# 测试ResourceLoader.exists
	var test_paths = [
		"res://assets/images/cards/duoliya.png",
		"res://assets/images/cards/lan.png",
		"res://assets/images/cards/gongsunli.png",
		"res://assets/images/cards/sunshangxiang.png",
		"res://assets/images/cards/daqiao.png",
		"res://assets/images/cards/yao.png"
	]
	
	for path in test_paths:
		var exists = ResourceLoader.exists(path)
		print("路径 %s 存在: %s" % [path, str(exists)])
		
		if exists:
			var resource = load(path)
			print("  加载资源: %s (类型: %s)" % [str(resource), resource.get_class() if resource else "null"])
	
	# 测试CardDatabase
	var card_database = get_node("/root/CardDatabase")
	if card_database:
		print("\n测试CardDatabase...")
		card_database.print_all_cards()
	else:
		print("CardDatabase未找到")