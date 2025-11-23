extends Control

## 战斗模式选择界面
## 提供1v1、2v2、3v3三种模式选择

# 预加载中文字体
var chinese_font = preload("res://assets/fonts/Arial Unicode.ttf")

# 基准分辨率和缩放因子
var base_resolution := Vector2(1280, 720)
var current_scale_factor: float = 1.0

# 按钮容器
var button_container: VBoxContainer
var music_player: Panel  # 音乐播放器引用

func _ready():
	print("战斗模式选择界面初始化...")
	
	# 监听窗口大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# 初始化自适应布局
	calculate_scale_factor()
	
	call_deferred("setup_ui")

## 计算缩放因子
func calculate_scale_factor():
	var viewport_size = get_viewport().get_visible_rect().size
	current_scale_factor = min(viewport_size.x / base_resolution.x, viewport_size.y / base_resolution.y)
	# 限制缩放范围，避免过小或过大
	current_scale_factor = clamp(current_scale_factor, 0.5, 2.0)
	print("计算缩放因子: %.2f (视口: %s, 基准: %s)" % [current_scale_factor, str(viewport_size), str(base_resolution)])

## 处理窗口大小变化
func _on_viewport_size_changed():
	print("窗口大小变化事件触发")
	calculate_scale_factor()
	update_layout_for_new_size()

## 根据新尺寸更新布局
func update_layout_for_new_size():
	print("更新战斗模式选择界面布局")
	
	# 清理现有UI子节点
	for child in get_children():
		child.queue_free()
	
	# 等待清理完成
	await get_tree().process_frame
	
	# 重新创建界面
	setup_ui()

## 设置界面
func setup_ui():
	# 创建主容器
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20) # 添加边距
	main_container.add_theme_constant_override("separation", int(20 * current_scale_factor))
	add_child(main_container)
	
	# 标题
	var title_label = Label.new()
	title_label.text = "选择战斗模式"
	title_label.add_theme_font_override("font", chinese_font)
	title_label.add_theme_font_size_override("font_size", int(32 * current_scale_factor))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# 添加间距
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, int(50 * current_scale_factor))
	main_container.add_child(spacer1)
	
	# 内容滚动容器，解决内容溢出问题
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_container.add_child(scroll_container)
	
	# 内容容器
	var content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(content_container)
	
	# 按钮容器
	button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", int(30 * current_scale_factor))
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	content_container.add_child(button_container)
	
	# 创建模式按钮
	create_mode_buttons()
	
	# 底部容器，固定在底部
	var bottom_container = HBoxContainer.new()
	bottom_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_container.custom_minimum_size = Vector2(0, int(80 * current_scale_factor))
	main_container.add_child(bottom_container)
	
	# 返回按钮
	var back_button = Button.new()
	back_button.text = "返回主菜单"
	back_button.custom_minimum_size = Vector2(int(200 * current_scale_factor), int(50 * current_scale_factor))
	back_button.pressed.connect(_on_back_pressed)
	back_button.add_theme_font_override("font", chinese_font)
	back_button.add_theme_font_size_override("font_size", int(18 * current_scale_factor))
	bottom_container.add_child(back_button)
	
	print("战斗模式选择界面设置完成")

## 创建模式按钮
func create_mode_buttons():
	# 1v1模式
	var mode_1v1 = create_mode_button("1v1模式", "朵莉亚 vs 澜\n单挑对决，考验个人技巧")
	var button_1v1 = mode_1v1.get_meta("button")
	button_1v1.pressed.connect(func(): _on_mode_selected("1v1"))
	button_container.add_child(mode_1v1)
	
	# 2v2模式（原有）
	var mode_2v2 = create_mode_button("2v2模式", "公孙离+澜 vs 朵莉亚+澜\n固定组合，快速对战")
	var button_2v2 = mode_2v2.get_meta("button")
	button_2v2.pressed.connect(func(): _on_mode_selected("2v2"))
	button_container.add_child(mode_2v2)
	
	# 2v2卡牌选择模式（新增）
	var mode_2v2_pick = create_mode_button("2v2卡牌选择", "从4张卡牌中选择组合\n随机先手，策略选择")
	var button_2v2_pick = mode_2v2_pick.get_meta("button")
	button_2v2_pick.pressed.connect(func(): _on_mode_selected("2v2_pick"))
	button_container.add_child(mode_2v2_pick)
	
	# 3v3 BP模式（新增）
	var mode_3v3_bp = create_mode_button("3v3 BP模式", "Ban/Pick选人模式\n策略性选人，红蓝双方对抗")
	var button_3v3_bp = mode_3v3_bp.get_meta("button")
	button_3v3_bp.pressed.connect(func(): _on_mode_selected("3v3_bp"))
	button_container.add_child(mode_3v3_bp)
	
	# 3v3模式
	var mode_3v3 = create_mode_button("3v3模式", "朵莉亚+澜+孙尚香 vs 朵莉亚+澜+公孙离\n大规模团战，全面较量")
	var button_3v3 = mode_3v3.get_meta("button")
	button_3v3.pressed.connect(func(): _on_mode_selected("3v3"))
	button_container.add_child(mode_3v3)

## 创建模式按钮
func create_mode_button(mode_name: String, description: String) -> VBoxContainer:
	var mode_container = VBoxContainer.new()  # 重命名以避免冲突
	mode_container.add_theme_constant_override("separation", int(10 * current_scale_factor))
	mode_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# 模式按钮
	var button = Button.new()
	button.text = mode_name
	button.custom_minimum_size = Vector2(int(300 * current_scale_factor), int(60 * current_scale_factor))
	button.add_theme_font_override("font", chinese_font)
	button.add_theme_font_size_override("font_size", int(24 * current_scale_factor))
	mode_container.add_child(button)
	
	# 描述标签
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_override("font", chinese_font)
	desc_label.add_theme_font_size_override("font_size", int(14 * current_scale_factor))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mode_container.add_child(desc_label)
	
	# 将按钮存储在元数据中
	mode_container.set_meta("button", button)
	
	return mode_container

## 模式选择处理
func _on_mode_selected(mode: String):
	print("选择了 %s 模式" % mode)
	
	# 将选择的模式存储到全局
	Engine.set_meta("selected_battle_mode", mode)
	
	# 根据模式跳转到不同场景
	match mode:
		"2v2_pick":
			# 跳转到卡牌选择界面
			get_tree().change_scene_to_file("res://scenes/modes/CardSelection2v2.tscn")
		"3v3_bp":
			# 跳转到BP选人界面
			get_tree().change_scene_to_file("res://scenes/modes/BanPickScene.tscn")
		_:
			# 其他模式直接进入战斗场景
			get_tree().change_scene_to_file("res://scenes/main/BattleScene.tscn")

## 返回主菜单
func _on_back_pressed():
	print("返回主菜单")
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
