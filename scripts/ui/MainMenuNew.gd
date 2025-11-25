extends Control

## Honor Of Kings 新主菜单

func _ready():
	print("新主菜单启动...")
	_setup_buttons()

func _setup_buttons():
	_connect_button("CardShowcaseBtn", _on_card_showcase_pressed)
	_connect_button("OnlineBattleBtn", _on_online_battle_pressed)
	_connect_button("TutorialBtn", _on_tutorial_pressed)
	_connect_button("BattleTestBtn", _on_battle_test_pressed)
	_connect_button("SettingsBtn", _on_settings_pressed)
	_connect_button("ExitBtn", _on_exit_pressed)

func _connect_button(name: String, callback: Callable):
	var btn = get_node_or_null(name)
	if btn:
		btn.pressed.connect(callback)

func _on_card_showcase_pressed():
	print("进入卡牌鉴赏")
	get_tree().change_scene_to_file("res://scenes/modes/CardShowcase.tscn")

func _on_online_battle_pressed():
	print("进入在线对战")
	get_tree().change_scene_to_file("res://scenes/modes/OnlineMatch.tscn")

func _on_tutorial_pressed():
	print("进入玩法教学")
	# TODO: 实现玩法教学场景

func _on_battle_test_pressed():
	print("进入战斗测试")
	get_tree().change_scene_to_file("res://scenes/modes/BattleModeSelection.tscn")

func _on_settings_pressed():
	print("打开设置")
	get_tree().change_scene_to_file("res://scenes/main/SettingsMenu.tscn")

func _on_exit_pressed():
	print("退出游戏")
	get_tree().quit()
