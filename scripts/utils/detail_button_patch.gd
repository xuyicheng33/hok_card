## 详情按钮点击事件处理
func _on_detail_button_pressed():
	# 加载所有卡牌详情弹窗场景
	var popup_scene = preload("res://scenes/ui/AllCardsDetailPopup.tscn")
	if not popup_scene:
		print("错误: 无法加载AllCardsDetailPopup场景")
		return
	
	# 创建弹窗实例
	var popup = popup_scene.instantiate()
	if not popup:
		print("错误: 无法实例化AllCardsDetailPopup")
		return
	
	# 添加到场景树
	add_child(popup)
	
	# 设置所有卡牌详情
	popup.setup_details(player_cards, enemy_cards)