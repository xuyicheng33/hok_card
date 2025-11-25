extends Node

## 预加载管理器 - 预加载大型资源避免卡顿

var main_menu_bg: Texture2D = null

func _ready():
	# 预加载主菜单背景
	main_menu_bg = load("res://assets/images/backgrounds/main_menu_bg.jpg")
	print("预加载完成: 主菜单背景")
