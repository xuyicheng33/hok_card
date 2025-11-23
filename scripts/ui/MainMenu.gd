extends Control

## Honor Of Kings 主菜单 - 自适应布局版本
## 支持多种分辨率和设备的自适应布局

# 节点引用
var card_preview_container: Control
var start_game_button: Button
var battle_button: Button
var card_showcase_button: Button
var settings_button: Button
var exit_button: Button
var background_image: TextureRect
var main_container: Control
var content_area: Control
var menu_buttons_area: Control
var music_player: Panel  # 音乐播放器引用

# 布局参数
var base_resolution := Vector2(1280, 720)  # 基准分辨率
var min_button_size := Vector2(200, 50)     # 最小按钮尺寸
var max_button_size := Vector2(300, 80)     # 最大按钮尺寸
var current_scale_factor: float = 1.0       # 当前缩放因子

## 卡牌轮播相关
var available_cards: Array = []
var current_card_index: int = 0
var current_card_ui: CardUI
var carousel_timer: Timer

func _ready():
	print("Honor Of Kings - 自适应布局版本启动...")
	
	# 设置为全屏布局
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 监听窗口大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# 初始化布局
	call_deferred("initialize_adaptive_layout")
	
	# 获取节点引用
	call_deferred("get_node_references")

## 动态加载背景图片
func load_background_image():
	print("尝试加载背景图片...")
	
	if not background_image:
		print("错误: 背景图片节点未找到")
		return
	
	# 检查资源是否存在
	if ResourceLoader.exists("res://assets/images/backgrounds/background.png"):
		print("背景图片文件存在，开始加载...")
		var image_resource = load("res://assets/images/backgrounds/background.png")
		if image_resource:
			background_image.texture = image_resource
			print("背景图片加载成功")
		else:
			print("警告: 背景图片加载失败")
	else:
		print("警告: 背景图片文件不存在")

## 获取节点引用
func get_node_references():
	print("获取节点引用...")
	
	# 安全获取节点引用
	card_preview_container = get_node_or_null("Background/MainContainer/ContentArea/CardPreviewArea")
	start_game_button = get_node_or_null("Background/MainContainer/ContentArea/MenuButtonsArea/MenuButtons/StartGameButton")
	battle_button = get_node_or_null("Background/MainContainer/ContentArea/MenuButtonsArea/MenuButtons/BattleButton")
	card_showcase_button = get_node_or_null("Background/MainContainer/ContentArea/MenuButtonsArea/MenuButtons/CardShowcaseButton")
	settings_button = get_node_or_null("Background/MainContainer/ContentArea/MenuButtonsArea/MenuButtons/SettingsButton")
	exit_button = get_node_or_null("Background/MainContainer/ContentArea/MenuButtonsArea/MenuButtons/ExitButton")
	background_image = get_node_or_null("Background")
	music_player = get_node_or_null("Background/MusicPlayer")  # 获取音乐播放器引用
	
	print("节点引用获取成功")
	
	# 动态加载背景图片
	call_deferred("load_background_image")
	
	# 继续初始化
	call_deferred("setup_main_menu")

## 设置主菜单
func setup_main_menu():
	print("设置主菜单...")
	
	# 检查CardDatabase
	if not CardDatabase:
		print("错误: CardDatabase未加载")
		return
	
	# 获取可用卡牌
	available_cards = CardDatabase.get_all_card_ids()
	print("找到 %d 张卡牌可供轮播" % available_cards.size())
	
	# 设置按钮连接
	setup_button_connections()
	
	# 播放背景音乐
	play_background_music()
	
	# 设置卡牌轮播
	if available_cards.size() > 0:
		call_deferred("setup_card_carousel")
	
	print("主菜单设置完成")

## 设置按钮连接
func setup_button_connections():
	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_pressed)
		print("开始游戏按钮已连接")
	
	if battle_button:
		battle_button.pressed.connect(_on_battle_pressed)
		print("战斗按钮已连接")
	
	if card_showcase_button:
		card_showcase_button.pressed.connect(_on_card_showcase_pressed)
		print("卡牌展示按钮已连接")
	
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
		print("设置按钮已连接")
	
	if exit_button:
		exit_button.pressed.connect(_on_exit_game_pressed)
		print("退出按钮已连接")

## 播放背景音乐
func play_background_music():
	print("🔇 测试模式：跳过主菜单背景音乐")
	# 测试阶段关闭音乐
	# MusicManager.play_music("res://assets/music/bgm.mp3")

## 按钮事件处理
func _on_start_game_pressed():
	print("进入在线对战")
	get_tree().change_scene_to_file("res://scenes/modes/OnlineMatch.tscn")

func _on_battle_pressed():
	print("进入战斗模式选择")
	get_tree().change_scene_to_file("res://scenes/modes/BattleModeSelection.tscn")

func _on_online_battle_pressed():
	print("进入在线对战")
	get_tree().change_scene_to_file("res://scenes/modes/OnlineMatch.tscn")

func _on_card_showcase_pressed():
	print("切换到卡牌展示场景")
	get_tree().change_scene_to_file("res://scenes/modes/CardShowcase.tscn")

func _on_settings_pressed():
	print("打开设置界面")
	get_tree().change_scene_to_file("res://scenes/main/SettingsMenu.tscn")

func _on_exit_game_pressed():
	print("退出游戏")
	get_tree().quit()

## 处理键盘输入
func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				_on_exit_game_pressed()
			KEY_ENTER:
				_on_start_game_pressed()

## 设置卡牌轮播
func setup_card_carousel():
	print("设置卡牌轮播...")
	
	if not card_preview_container:
		print("错误: 卡牌预览容器不存在")
		return
		
	if available_cards.is_empty():
		print("警告: 没有可用卡牌")
		return
	
	# 创建计时器用于自动轮播
	carousel_timer = Timer.new()
	carousel_timer.wait_time = 3.0  # 3秒切换一次
	carousel_timer.timeout.connect(_on_carousel_timer_timeout)
	carousel_timer.autostart = true
	add_child(carousel_timer)
	
	# 显示第一张卡牌
	show_card_at_index(0)
	print("卡牌轮播设置完成")

## 显示指定索引的卡牌
func show_card_at_index(index: int):
	if index < 0 or index >= available_cards.size():
		return
	
	# 清理之前的卡牌
	if current_card_ui:
		current_card_ui.queue_free()
		current_card_ui = null
	
	# 获取卡牌数据
	var card_id = available_cards[index]
	var card_data = CardDatabase.get_card(card_id)
	
	if not card_data:
		print("错误: 无法获取卡牌数据 %s" % card_id)
		return
	
	# 安全加载卡牌UI
	if ResourceLoader.exists("res://scenes/ui/CardUI.tscn"):
		var card_ui_scene = load("res://scenes/ui/CardUI.tscn")
		if card_ui_scene:
			current_card_ui = card_ui_scene.instantiate()
			card_preview_container.add_child(current_card_ui)
			
			# 设置卡牌数据
			current_card_ui.set_card(card_data)
			current_card_ui.set_interactive(true)
			
			# 等待下一帧再设置位置
			call_deferred("_position_card_ui")
			
			# 更新当前索引
			current_card_index = index
			
			print("轮播显示卡牌: %s" % card_data.card_name)
		else:
			print("错误: 卡牌UI场景加载失败")
	else:
		print("错误: 卡牌UI场景文件不存在")

## 轮播计时器回调
func _on_carousel_timer_timeout():
	var next_index = (current_card_index + 1) % available_cards.size()
	show_card_at_index(next_index)

## 定位卡牌UI的辅助函数
func _position_card_ui():
	if not current_card_ui or not card_preview_container:
		return
		
	# 等待容器准备好
	if card_preview_container.size == Vector2.ZERO:
		call_deferred("_position_card_ui")
		return
		
	# 设置卡牌位置和尺寸（适合预览的尺寸）
	current_card_ui.scale = Vector2(1.2, 1.2)  # 稍微放大一点用于展示
	current_card_ui.position = Vector2(
		(card_preview_container.size.x - 150 * 1.2) / 2,
		(card_preview_container.size.y - 230 * 1.2) / 2
	)

## 初始化自适应布局
func initialize_adaptive_layout():
	print("初始化自适应布局...")
	
	# 计算当前缩放因子
	calculate_scale_factor()
	
	# 应用自适应布局
	apply_adaptive_layout()

func calculate_scale_factor():
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_x = viewport_size.x / base_resolution.x
	var scale_y = viewport_size.y / base_resolution.y
	
	# 使用较小的缩放因子以保持尺寸比例
	current_scale_factor = min(scale_x, scale_y)
	# 限制缩放范围，避免过小或过大
	current_scale_factor = clamp(current_scale_factor, 0.5, 2.0)
	
	print("窗口尺寸: %s, 缩放因子: %.2f" % [viewport_size, current_scale_factor])

func apply_adaptive_layout():
	print("应用自适应布局...")
	
	# 等待节点就绪
	await get_tree().process_frame
	
	# 更新按钮尺寸
	update_button_sizes()
	
	# 更新字体尺寸
	update_font_sizes()
	
	# 更新间距和外边距
	update_spacing_and_margins()

func update_button_sizes():
	var buttons = [start_game_button, battle_button, card_showcase_button, settings_button, exit_button]
	
	for button in buttons:
		if not button:
			continue
		
		# 计算新的按钮尺寸
		var new_size = min_button_size * current_scale_factor
		new_size = Vector2(
			clamp(new_size.x, min_button_size.x, max_button_size.x),
			clamp(new_size.y, min_button_size.y, max_button_size.y)
		)
		
		# 应用新尺寸
		button.custom_minimum_size = new_size

func update_font_sizes():
	# 计算自适应字体尺寸
	var base_font_size = 16
	var scaled_font_size = int(base_font_size * current_scale_factor)
	scaled_font_size = clamp(scaled_font_size, 12, 24)
	
	# 更新按钮字体
	var buttons = [start_game_button, battle_button, card_showcase_button, settings_button, exit_button]
	for button in buttons:
		if button:
			button.add_theme_font_size_override("font_size", scaled_font_size)

func update_spacing_and_margins():
	# 获取主容器
	main_container = get_node_or_null("Background/MainContainer")
	content_area = get_node_or_null("Background/MainContainer/ContentArea")
	menu_buttons_area = get_node_or_null("Background/MainContainer/ContentArea/MenuButtonsArea")
	
	if main_container:
		# 计算自适应间距
		var base_margin = 20
		var scaled_margin = int(base_margin * current_scale_factor)
		scaled_margin = clamp(scaled_margin, 10, 40)
		
		# 更新外边距
		if main_container is MarginContainer:
			main_container.add_theme_constant_override("margin_left", scaled_margin)
			main_container.add_theme_constant_override("margin_right", scaled_margin)
			main_container.add_theme_constant_override("margin_top", scaled_margin)
			main_container.add_theme_constant_override("margin_bottom", scaled_margin)
	
	if menu_buttons_area:
		# 更新按钮间距
		var base_separation = 15
		var scaled_separation = int(base_separation * current_scale_factor)
		scaled_separation = clamp(scaled_separation, 8, 30)
		
		if menu_buttons_area is VBoxContainer:
			menu_buttons_area.add_theme_constant_override("separation", scaled_separation)

## 窗口大小变化事件处理
func _on_viewport_size_changed():
	print("窗口大小发生变化")
	
	# 重新计算和应用布局
	calculate_scale_factor()
	apply_adaptive_layout()
