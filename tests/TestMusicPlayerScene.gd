extends Control

## 音乐播放器测试场景脚本

func _ready():
	# 获取返回按钮并连接事件
	var back_button = get_node_or_null("Background/BackButton")
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	print("音乐播放器测试场景已加载")

## 返回按钮事件处理
func _on_back_button_pressed():
	print("返回主菜单")
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")