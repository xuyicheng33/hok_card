extends Control

## 战斗场景控制脚本 - 自适应布局版本
## 管理战斗场景的UI和交互逻辑，支持多种分辨率

# 预加载中文字体
var chinese_font = preload("res://assets/fonts/Arial Unicode.ttf")

# 布局参数
var base_resolution := Vector2(1280, 720)  # 基准分辨率
var current_scale_factor: float = 1.0       # 当前缩放因子
var card_base_size := Vector2(150, 200)     # 卡牌基本尺寸
var ui_base_font_size: int = 14             # UI基本字体大小

# UI组件引用
var enemy_card_container: HBoxContainer
var player_card_container: HBoxContainer
var battle_status_label: Label
var last_action_label: Label
var turn_info_label: Label
var end_turn_button: Button
var use_skill_button: Button
var cancel_skill_button: Button  # 取消技能按钮引用
var back_to_menu_button: Button
var detail_button: Button  # 新增详情按钮引用
var message_system  # 消息系统
var main_battle_area  # 主战斗区域
var message_area  # 消息区域

# 技能点显示组件
var player_skill_points_label: Label
var enemy_skill_points_label: Label

# 🎯 行动点显示组件（新增）
var player_actions_label: Label
var enemy_actions_label: Label

# 战斗状态
var player_entities: Array = []
var enemy_entities: Array = []
var selected_card = null
var is_selecting_target: bool = false
var is_using_skill: bool = false

# 战斗模式支持
var battle_mode: String = "2v2"  # 默认2v2模式
var player_cards: Array = []  # 存储玩家方卡牌实体
var enemy_cards: Array = []   # 存储敌方卡牌实体

# 测试用卡牌数据
var test_player_cards: Array = []
var test_enemy_cards: Array = []

func _ready():
	print("战斗场景初始化...")
	
	# 设置为全屏布局
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 监听窗口大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# 初始化自适应布局
	calculate_scale_factor()
	
	# 检测战斗模式
	detect_battle_mode()
	
	# 获取节点引用
	call_deferred("get_node_references")

## 计算缩放因子
func calculate_scale_factor():
	var scale_viewport_size = get_viewport().get_visible_rect().size
	current_scale_factor = min(scale_viewport_size.x / base_resolution.x, scale_viewport_size.y / base_resolution.y)
	# 限制缩放范围，避免过小或过大
	current_scale_factor = clamp(current_scale_factor, 0.5, 2.0)
	print("计算缩放因子: %.2f (视口: %s, 基准: %s)" % [current_scale_factor, str(scale_viewport_size), str(base_resolution)])

## 处理窗口大小变化
func _on_viewport_size_changed():
	print("窗口大小变化事件触发")
	calculate_scale_factor()
	update_layout_for_new_size()

## 根据新尺寸更新布局
func update_layout_for_new_size():
	print("更新布局以适应新尺寸，缩放因子: %.2f" % current_scale_factor)
	
	# 更新消息区域宽度
	if message_area:
		var message_width = int(320 * current_scale_factor)
		message_width = clamp(message_width, 280, 400)  # 增加最小宽度使更美观
		message_area.custom_minimum_size = Vector2(message_width, 0)
	
	# 更新字体大小
	update_font_sizes()
	
	# 更新按钮尺寸
	update_button_sizes()
	
	# 更新卡牌区域
	update_card_area_layout()

## 更新字体大小
func update_font_sizes():
	# 更新顶部信息区域的字体大小
	if turn_info_label:
		var title_font_size = int(18 * current_scale_factor)
		title_font_size = clamp(title_font_size, 14, 24)
		turn_info_label.add_theme_font_size_override("font_size", title_font_size)
	
	if battle_status_label:
		var status_font_size = int(16 * current_scale_factor)
		status_font_size = clamp(status_font_size, 12, 20)
		battle_status_label.add_theme_font_size_override("font_size", status_font_size)
	
	# 更新技能点标签字体大小
	if player_skill_points_label:
		var skill_font_size = int(16 * current_scale_factor)
		skill_font_size = clamp(skill_font_size, 14, 20)
		player_skill_points_label.add_theme_font_size_override("font_size", skill_font_size)
	
	if enemy_skill_points_label:
		var skill_font_size = int(16 * current_scale_factor)
		skill_font_size = clamp(skill_font_size, 14, 20)
		enemy_skill_points_label.add_theme_font_size_override("font_size", skill_font_size)
	
	# 更新消息区域字体大小
	if message_system:
		var message_font_size = int(14 * current_scale_factor)
		message_font_size = clamp(message_font_size, 12, 18)
		message_system.add_theme_font_size_override("font_size", message_font_size)

## 更新按钮尺寸
func update_button_sizes():
	# 获取当前分辨率
	var button_viewport_size = get_viewport().get_visible_rect().size
	var is_full_hd = button_viewport_size.x >= 1920 and button_viewport_size.y >= 1080
	
	# 计算自适应按钮尺寸
	var button_width = int(100 * current_scale_factor)
	var button_height = int(40 * current_scale_factor)
	
	# 1920*1080分辨率下优化按钮尺寸
	if is_full_hd:
		# 在高分辨率下设置更美观的按钮尺寸
		button_width = 100
		button_height = 40
	else:
		# 其他分辨率下的正常限制
		button_width = clamp(button_width, 80, 150)
		button_height = clamp(button_height, 30, 60)
	
	if end_turn_button:
		end_turn_button.custom_minimum_size = Vector2(button_width, button_height)
	
	if use_skill_button:
		use_skill_button.custom_minimum_size = Vector2(button_width, button_height)
	
	if back_to_menu_button:
		back_to_menu_button.custom_minimum_size = Vector2(button_width, button_height)
	
	if detail_button:
		detail_button.custom_minimum_size = Vector2(button_width, button_height)
	
	# 更新取消技能按钮
	var cancel_button = get_cancel_skill_button()
	if cancel_button:
		cancel_button.custom_minimum_size = Vector2(button_width, button_height)
	
	print("更新按钮尺寸完成 - 宽度: %d, 高度: %d" % [button_width, button_height])

## 更新卡牌区域布局
func update_card_area_layout():
	# 获取当前分辨率
	var area_viewport_size = get_viewport().get_visible_rect().size
	var is_full_hd = area_viewport_size.x >= 1920 and area_viewport_size.y >= 1080
	var is_high_resolution = area_viewport_size.y >= 900
	
	# 根据战斗模式和缩放因子调整卡牌区域高度
	var area_height = get_card_area_height_for_mode()
	area_height = int(area_height * current_scale_factor)
	
	# 高分辨率下增加最小高度限制
	var min_height = 0
	var max_height = 0
	
	if is_full_hd:  # 1920*1080分辨率
		min_height = 180  # 调整最小高度与卡牌区域高度相匹配
		max_height = 250  # 调整最大高度
	elif is_high_resolution:  # 其他高分辨率
		min_height = 280
		max_height = 460
	else:  # 标准分辨率
		min_height = 200
		max_height = 400
	
	area_height = clamp(area_height, min_height, max_height)
	
	# 更新卡牌间距
	var card_spacing = get_card_spacing_for_mode()
	card_spacing = int(card_spacing * current_scale_factor)
	
	# 高分辨率下增大间距缩放范围
	var min_spacing = 0
	var max_spacing = 0
	
	if is_full_hd:  # 1920*1080分辨率
		min_spacing = 50
		max_spacing = 250
	elif is_high_resolution:  # 其他高分辨率
		min_spacing = 60
		max_spacing = 280
	else:  # 标准分辨率
		min_spacing = 40
		max_spacing = 200
	
	card_spacing = clamp(card_spacing, min_spacing, max_spacing)
	
	# 调整卡牌容器的尺寸
	if enemy_card_container and is_instance_valid(enemy_card_container):
		# 更新卡牌容器高度
		var enemy_area = enemy_card_container.get_parent()
		if enemy_area and is_instance_valid(enemy_area) and enemy_area is Control:
			enemy_area.custom_minimum_size.y = area_height
		
		# 更新卡牌间距
		enemy_card_container.add_theme_constant_override("separation", card_spacing)
	
	# 更新玩家卡牌区域
	if player_card_container and is_instance_valid(player_card_container):
		# 更新卡牌容器高度
		var player_area = player_card_container.get_parent()
		if player_area and is_instance_valid(player_area) and player_area is Control:
			player_area.custom_minimum_size.y = area_height
		
		# 更新卡牌间距
		player_card_container.add_theme_constant_override("separation", card_spacing)
	
	print("更新卡牌区域布局完成 - 高度: %d, 间距: %d, 分辨率: %s" % [area_height, card_spacing, str(area_viewport_size)])

## 获取节点引用
func get_node_references():
	print("创建新的战斗界面布局...")
	
	# 清理现有子节点
	for child in get_children():
		child.queue_free()
	
	# 等待清理完成
	await get_tree().process_frame
	
	# 创建新布局
	create_new_layout()
	
	# 战斗场景不需要音乐播放器引用
	
	# 连接战斗管理器信号
	call_deferred("connect_battle_manager_signals")
	
	# 连接技能点变化信号
	if BattleManager and not BattleManager.skill_points_changed.is_connected(_on_skill_points_changed):
		BattleManager.skill_points_changed.connect(_on_skill_points_changed)
	
	# 🎯 连接行动点变化信号
	if BattleManager and not BattleManager.actions_changed.is_connected(_on_actions_changed):
		BattleManager.actions_changed.connect(_on_actions_changed)
	
	# 连接被动技能触发信号
	if BattleManager and not BattleManager.passive_skill_triggered.is_connected(_on_passive_skill_triggered):
		BattleManager.passive_skill_triggered.connect(_on_passive_skill_triggered)
	
	# 初始化技能点显示
	call_deferred("update_initial_skill_points")
	
	# 初始化界面
	call_deferred("setup_ui")

## 创建新的界面布局 - 自适应版本
func create_new_layout():
	print("创建自适应战斗界面布局...")
	
	# 设置背景
	var background = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.15, 1.0)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 主容器（水平分割）
	var main_container = HBoxContainer.new()
	background.add_child(main_container)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 自适应间距
	var base_separation = 5  # 减小基础间距
	var scaled_separation = int(base_separation * current_scale_factor)
	main_container.add_theme_constant_override("separation", scaled_separation)
	
	# 左侧战斗区域（直接添加到主容器，不使用滚动容器）
	main_battle_area = VBoxContainer.new()
	main_battle_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_battle_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_battle_area.add_theme_constant_override("separation", scaled_separation)
	main_container.add_child(main_battle_area)
	
	# 右侧消息区域（自适应宽度）
	message_area = VBoxContainer.new()
	var message_width = int(320 * current_scale_factor)
	message_width = clamp(message_width, 250, 400)  # 限制最小和最大宽度
	message_area.custom_minimum_size = Vector2(message_width, 0)
	message_area.size_flags_horizontal = Control.SIZE_SHRINK_END
	main_container.add_child(message_area)
	
	# 创建战斗区域内容
	create_battle_area_content()
	
	# 创建消息区域内容
	create_message_area_content()

## 创建战斗区域内容 - 自适应版本
func create_battle_area_content():
	print("创建战斗区域内容...")
	
	# 获取当前分辨率
	var viewport_size = get_viewport().get_visible_rect().size
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080
	var is_high_resolution = viewport_size.y >= 900
	
	# 根据战斗模式和缩放因子调整卡牌区域高度
	var area_height = get_card_area_height_for_mode()
	area_height = int(area_height * current_scale_factor)
	
	# 高分辨率下增加最小高度限制
	var min_height = 0
	var max_height = 0
	
	if is_full_hd:  # 1920*1080分辨率
		min_height = 150  # 增加高度使布局更美观
		max_height = 200
	elif is_high_resolution:  # 其他高分辨率
		min_height = 280
		max_height = 460
	else:  # 标准分辨率
		min_height = 200
		max_height = 400
	
	area_height = clamp(area_height, min_height, max_height)
	
	# 根据战斗模式获取卡牌间距
	var card_spacing = get_card_spacing_for_mode()
	card_spacing = int(card_spacing * current_scale_factor)
	
	# 高分辨率下增大间距缩放范围
	var min_spacing = 0
	var max_spacing = 0
	
	if is_full_hd:  # 1920*1080分辨率
		min_spacing = 100  # 增加间距以适应更大的卡牌尺寸
		max_spacing = 350
	elif is_high_resolution:  # 其他高分辨率
		min_spacing = 60
		max_spacing = 280
	else:  # 标准分辨率
		min_spacing = 40
		max_spacing = 200
	
	card_spacing = clamp(card_spacing, min_spacing, max_spacing)
	
	# 创建主要垂直布局，分为三个部分：顶部信息、中间战斗区域、底部控制区
	var top_section = VBoxContainer.new()
	top_section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_battle_area.add_child(top_section)
	
	# 中间战斗区域 - 使用GridContainer确保对称布局
	var middle_section = VBoxContainer.new()
	middle_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_section.alignment = BoxContainer.ALIGNMENT_CENTER  # 居中对齐，确保中间分隔区域居中
	main_battle_area.add_child(middle_section)
	
	# 使用网格容器来确保敌方卡牌、分隔区和玩家卡牌的对称布局
	var battle_grid = GridContainer.new()
	battle_grid.columns = 1  # 垂直排列
	battle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_section.add_child(battle_grid)
	
	# 敌人卡牌区域
	var enemy_area = VBoxContainer.new()
	enemy_area.custom_minimum_size = Vector2(0, area_height)
	enemy_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_grid.add_child(enemy_area)
	
	var enemy_label = Label.new()
	enemy_label.text = "敌方卡牌"
	enemy_label.add_theme_font_override("font", chinese_font)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.add_theme_font_size_override("font_size", 14)
	enemy_area.add_child(enemy_label)
	
	enemy_card_container = HBoxContainer.new()
	enemy_card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_card_container.add_theme_constant_override("separation", card_spacing)
	enemy_area.add_child(enemy_card_container)
	
	# 中间分隔区域（美化设计）- 这里是关键调整点
	var separator_area = VBoxContainer.new()
	separator_area.custom_minimum_size = Vector2(0, 24)
	separator_area.add_theme_constant_override("separation", 2)
	separator_area.alignment = BoxContainer.ALIGNMENT_CENTER  # 设置为居中对齐
	separator_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_grid.add_child(separator_area)
	
	# 上下间距
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 1)
	separator_area.add_child(spacer1)
	
	# 分隔线
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 1)
	separator_area.add_child(separator)
	
	# VS 标签
	var vs_label = Label.new()
	vs_label.text = "VS"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.add_theme_font_override("font", chinese_font)
	vs_label.add_theme_font_size_override("font_size", 18)
	vs_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))  # 淡红色
	separator_area.add_child(vs_label)
	
	# 下间距
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 1)
	separator_area.add_child(spacer2)
	
	# 玩家卡牌区域
	var player_area = VBoxContainer.new()
	player_area.custom_minimum_size = Vector2(0, area_height)
	player_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_grid.add_child(player_area)
	
	var player_label = Label.new()
	player_label.text = "我方卡牌"
	player_label.add_theme_font_override("font", chinese_font)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_font_size_override("font_size", 14)
	player_area.add_child(player_label)
	
	player_card_container = HBoxContainer.new()
	player_card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	player_card_container.add_theme_constant_override("separation", card_spacing)
	player_area.add_child(player_card_container)
	
	var bottom_section = VBoxContainer.new()
	bottom_section.size_flags_vertical = Control.SIZE_SHRINK_END
	main_battle_area.add_child(bottom_section)
	
	# 添加模式显示标签到顶部区域
	var mode_info_label = Label.new()
	mode_info_label.text = "当前模式: %s" % battle_mode.to_upper()
	mode_info_label.add_theme_font_override("font", chinese_font)
	mode_info_label.add_theme_font_size_override("font_size", 18)
	mode_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_info_label.add_theme_color_override("font_color", get_theme_color_for_mode())
	top_section.add_child(mode_info_label)
	
	# 添加小间距
	var spacer_top = Control.new()
	var spacer_height = int(5 * current_scale_factor)
	spacer_top.custom_minimum_size = Vector2(0, spacer_height)
	top_section.add_child(spacer_top)
	
	# 顶部信息区
	var top_info = HBoxContainer.new()
	var info_height = int(30 * current_scale_factor)
	top_info.custom_minimum_size = Vector2(0, info_height)
	top_section.add_child(top_info)
	
	turn_info_label = Label.new()
	turn_info_label.text = "第 1 回合 - 玩家回合"
	turn_info_label.add_theme_font_override("font", chinese_font)
	turn_info_label.add_theme_font_size_override("font_size", 20)
	top_info.add_child(turn_info_label)
	
	# 技能点显示区域
	var skill_points_container = VBoxContainer.new()
	skill_points_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_points_container.add_theme_constant_override("separation", 5)
	top_info.add_child(skill_points_container)
	
	enemy_skill_points_label = Label.new()
	enemy_skill_points_label.text = "敌方技能点: 4/6"
	enemy_skill_points_label.add_theme_font_override("font", chinese_font)
	enemy_skill_points_label.add_theme_font_size_override("font_size", 16)
	enemy_skill_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_skill_points_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))  # 红色
	skill_points_container.add_child(enemy_skill_points_label)
	
	player_skill_points_label = Label.new()
	player_skill_points_label.text = "我方技能点: 4/6"
	player_skill_points_label.add_theme_font_override("font", chinese_font)
	player_skill_points_label.add_theme_font_size_override("font_size", 16)
	player_skill_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_skill_points_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))  # 蓝色
	skill_points_container.add_child(player_skill_points_label)
	
	# 🎯 行动点显示（新增）
	player_actions_label = Label.new()
	player_actions_label.text = "行动剩余: 3/3"  # 初始剩余3次
	player_actions_label.add_theme_font_override("font", chinese_font)
	player_actions_label.add_theme_font_size_override("font_size", 16)
	player_actions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_actions_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))  # 绿色
	skill_points_container.add_child(player_actions_label)
	
	enemy_actions_label = Label.new()
	enemy_actions_label.text = "敌方剩余: 3/3"  # 初始剩余3次
	enemy_actions_label.add_theme_font_override("font", chinese_font)
	enemy_actions_label.add_theme_font_size_override("font_size", 16)
	enemy_actions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_actions_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))  # 橙色
	skill_points_container.add_child(enemy_actions_label)
	
	# 战斗状态显示
	battle_status_label = Label.new()
	battle_status_label.text = "选择攻击或发动技能"
	battle_status_label.add_theme_font_override("font", chinese_font)
	battle_status_label.add_theme_font_size_override("font_size", 16)
	battle_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_info.add_child(battle_status_label)
	
	# 底部控制区
	var bottom_controls = HBoxContainer.new()
	
	# 获取当前分辨率
	var bottom_viewport_size = get_viewport().get_visible_rect().size
	var bottom_is_full_hd = bottom_viewport_size.x >= 1920 and bottom_viewport_size.y >= 1080
	
	# 调整底部控制区高度
	var bottom_height = 48 if bottom_is_full_hd else 52
	bottom_controls.custom_minimum_size = Vector2(0, bottom_height)
	
	# 添加底部边距，确保按钮不被裁剪
	var bottom_margin = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_bottom", 10 if bottom_is_full_hd else 10)
	bottom_margin.add_child(bottom_controls)
	bottom_section.add_child(bottom_margin)
	
	# 左侧按钮组
	var left_buttons = HBoxContainer.new()
	left_buttons.add_theme_constant_override("separation", 10)
	bottom_controls.add_child(left_buttons)
	
	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.custom_minimum_size = Vector2(120, 48)
	left_buttons.add_child(end_turn_button)
	
	use_skill_button = Button.new()
	use_skill_button.text = "发动技能"
	use_skill_button.custom_minimum_size = Vector2(120, 48)
	left_buttons.add_child(use_skill_button)
	
	# 取消技能按钮
	cancel_skill_button = Button.new()
	cancel_skill_button.text = "取消技能"
	cancel_skill_button.custom_minimum_size = Vector2(120, 48)
	cancel_skill_button.visible = false
	cancel_skill_button.name = "CancelSkillButton"
	left_buttons.add_child(cancel_skill_button)
	
	# 右侧按钮组
	var right_buttons = HBoxContainer.new()
	right_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_buttons.alignment = BoxContainer.ALIGNMENT_END
	bottom_controls.add_child(right_buttons)
	
	# 创建详情按钮
	detail_button = Button.new()
	detail_button.text = "详情"
	detail_button.custom_minimum_size = Vector2(120, 48)
	right_buttons.add_child(detail_button)
	
	back_to_menu_button = Button.new()
	back_to_menu_button.text = "返回主菜单"
	back_to_menu_button.custom_minimum_size = Vector2(120, 48)
	right_buttons.add_child(back_to_menu_button)
	
	# 连接信号
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	use_skill_button.pressed.connect(_on_use_skill_pressed)
	detail_button.pressed.connect(_on_detail_button_pressed)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	
	# 连接取消技能按钮信号
	if cancel_skill_button:
		cancel_skill_button.pressed.connect(_on_cancel_skill_pressed)

func create_message_area_content():
	# 消息区域标题
	var message_title = Label.new()
	message_title.text = "战斗记录"
	message_title.add_theme_font_override("font", chinese_font)
	message_title.add_theme_font_size_override("font_size", 16)  # 增大字体使更美观
	message_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_area.add_child(message_title)
	
	# 创建消息系统
	var message_script = load("res://scripts/battle/BattleMessageSystem.gd")
	if message_script:
		message_system = message_script.new()
		message_system.size_flags_vertical = Control.SIZE_EXPAND_FILL
		message_system.add_theme_font_size_override("font_size", 14)  # 增大字体使更美观
		message_area.add_child(message_system)
	else:
		print("错误: 无法加载 BattleMessageSystem 脚本")

## 连接战斗管理器信号
func connect_battle_manager_signals():
	print("连接战斗管理器信号...")
	
	if not BattleManager:
		print("错误：BattleManager不存在")
		return
	
	# 安全连接信号（避免重复连接）
	if not BattleManager.turn_changed.is_connected(_on_turn_changed):
		BattleManager.turn_changed.connect(_on_turn_changed)
	if not BattleManager.state_changed.is_connected(_on_battle_state_changed):
		BattleManager.state_changed.connect(_on_battle_state_changed)
	if not BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.connect(_on_battle_ended)
	if not BattleManager.card_died.is_connected(_on_card_died):
		BattleManager.card_died.connect(_on_card_died)
	
	# 连接被动技能信号
	if not BattleManager.passive_skill_triggered.is_connected(_on_passive_skill_triggered):
		BattleManager.passive_skill_triggered.connect(_on_passive_skill_triggered)
	# 🌐 连接在线技能执行信号
	if not BattleManager.skill_executed.is_connected(_on_online_skill_executed):
		BattleManager.skill_executed.connect(_on_online_skill_executed)
	
	# 将BattleScene中创建的message_system赋值给BattleManager
	if message_system and BattleManager:
		BattleManager.message_system = message_system
	
	print("战斗管理器信号连接完成")

## 初始化UI
func setup_ui():
	print("初始化战斗场景UI...")
	
	# 播放背景音乐
	play_background_music()
	
	# 🛡️ 安全检查BattleManager
	if BattleManager == null or not is_instance_valid(BattleManager):
		print("❌ BattleManager未加载，延迟初始化...")
		call_deferred("deferred_setup")
		return
	
	# 🌐 在线模式：使用默认2v2卡牌并等待同步
	if BattleManager.is_online_mode:
		print("🌐 在线模式初始化 - 创建默认卡牌")
		create_default_online_cards()
		start_test_battle()
		update_battle_status("等待对手连接..." if NetworkManager.is_host else "等待房主操作...")
		return
	
	# 单机模式：创建测试卡牌并开始战斗
	create_test_cards()
	start_test_battle()

## 延迟初始化（在BattleManager加载后执行）
func deferred_setup():
	await get_tree().process_frame
	
	if BattleManager != null and is_instance_valid(BattleManager):
		if BattleManager.is_online_mode:
			print("🌐 延迟初始化 - 在线模式")
			create_default_online_cards()
			start_test_battle()
			update_battle_status("等待对手连接..." if NetworkManager.is_host else "等待房主操作...")
		else:
			print("延迟初始化 - 单机模式")
			create_test_cards()
			start_test_battle()
	else:
		print("❌ BattleManager仍然无法访问！")
		update_battle_status("游戏初始化失败，请重启")

## 播放背景音乐
func play_background_music():
	print("🔇 测试模式：跳过背景音乐")
	# 测试阶段关闭音乐
	# if MusicManager:
	# 	MusicManager.play_music("res://assets/music/bgm.mp3")

## 检测战斗模式
func detect_battle_mode():
	# 🛡️ 安全检查BattleManager
	if BattleManager == null or not is_instance_valid(BattleManager):
		print("⚠️ BattleManager未加载，使用默认模式")
		battle_mode = "2v2"
		return
	
	# 🌐 检查是否为在线对战模式
	if BattleManager.is_online_mode:
		print("🌐 在线对战模式 - 等待网络同步卡牌数据")
		# 🎯 从元数据获取在线模式类型（由OnlineMatchUI设置）
		if Engine.has_meta("online_battle_mode"):
			battle_mode = Engine.get_meta("online_battle_mode")
			Engine.remove_meta("online_battle_mode")  # 使用后清除
			print("🎮 在线模式类型: %s" % battle_mode)
		else:
			battle_mode = "online_2v2"  # 默认2v2
			print("⚠️ 未找到在线模式类型，使用默认: %s" % battle_mode)
		# 在线模式下不创建测试卡牌，直接返回
		return
	
	# 从全局元数据中获取模式
	if Engine.has_meta("battle_mode"):
		# 卡牌选择模式传递的数据
		battle_mode = Engine.get_meta("battle_mode")
		print("从卡牌选择获取战斗模式: %s" % battle_mode)
	elif Engine.has_meta("selected_battle_mode"):
		# 统一模式选择传递的数据
		battle_mode = Engine.get_meta("selected_battle_mode")
		# 使用后清除全局变量
		Engine.remove_meta("selected_battle_mode")
		print("从模式选择获取战斗模式: %s" % battle_mode)
	else:
		battle_mode = "2v2"  # 默认2v2模式
		print("使用默认战斗模式: %s" % battle_mode)
	
	print("当前战斗模式: %s" % battle_mode)

## 根据模式获取主题颜色
func get_theme_color_for_mode() -> Color:
	# 🎯 处理在线模式：online_3v3 → 3v3, online_2v2 → 2v2
	var mode_type = battle_mode.replace("online_", "")
	
	match mode_type:
		"1v1":
			return Color(1.0, 0.8, 0.2)  # 金色 - 精英对决
		"2v2":
			return Color(0.2, 0.8, 1.0)  # 蓝色 - 团队协作
		"3v3":
			return Color(1.0, 0.4, 0.8)  # 紫红色 - 大型团战
		_:
			return Color(0.2, 0.8, 1.0)  # 默认蓝色
## 根据模式获取卡牌区域高度
func get_card_area_height_for_mode() -> int:
	# 获取当前分辨率来调整高度
	var height_viewport_size = get_viewport().get_visible_rect().size
	
	# 更精细的分辨率检测
	var is_full_hd = height_viewport_size.x >= 1920 and height_viewport_size.y >= 1080
	var is_high_resolution = height_viewport_size.y >= 900 # 高分辨率检测
	
	# 🎯 处理在线模式：online_3v3 → 3v3, online_2v2 → 2v2
	var mode_type = battle_mode.replace("online_", "")
	
	match mode_type:
		"1v1":
			if is_full_hd:
				return 185  # 比之前的147稍大一些
			elif is_high_resolution:
				return 230  # 其他高分辨率
			else:
				return 220  # 标准分辨率
		"2v2":
			if is_full_hd:
				return 185  # 比之前的147稍大一些
			elif is_high_resolution:
				return 215  # 其他高分辨率
			else:
				return 185  # 标准分辨率
		"3v3":
			if is_full_hd:
				return 185  # 比之前的147稍大一些
			elif is_high_resolution:
				return 200  # 其他高分辨率
			else:
				return 170  # 标准分辨率
		"2v2_custom":
			if is_full_hd:
				return 185  # 比之前的147稍大一些
			elif is_high_resolution:
				return 215  # 其他高分辨率
			else:
				return 185  # 标准分辨率
		_:
			if is_full_hd:
				return 185  # 比之前的147稍大一些
			elif is_high_resolution:
				return 215  # 其他高分辨率
			else:
				return 185  # 标准分辨率

## 根据模式获取卡牌间距
func get_card_spacing_for_mode() -> int:
	# 获取当前分辨率来调整间距
	var spacing_viewport_size = get_viewport().get_visible_rect().size
	
	# 更精细的分辨率检测
	var is_full_hd = spacing_viewport_size.x >= 1920 and spacing_viewport_size.y >= 1080
	var is_high_resolution = spacing_viewport_size.x >= 1600 # 高分辨率检测
	
	# 🎯 处理在线模式：online_3v3 → 3v3, online_2v2 → 2v2
	var mode_type = battle_mode.replace("online_", "")
	
	match mode_type:
		"1v1":
			if is_full_hd:
				return 100  # 增加间距以适应更大的卡牌尺寸
			elif is_high_resolution:
				return 200  # 其他高分辨率
			else:
				return 150  # 标准分辨率
		"2v2":
			if is_full_hd:
				return 80  # 增加间距以适应更大的卡牌尺寸
			elif is_high_resolution:
				return 150  # 其他高分辨率
			else:
				return 100  # 标准分辨率
		"3v3":
			if is_full_hd:
				return 60  # 增加间距以适应更大的卡牌尺寸
			elif is_high_resolution:
				return 120  # 其他高分辨率
			else:
				return 80   # 标准分辨率
		"2v2_custom":
			if is_full_hd:
				return 80  # 增加间距以适应更大的卡牌尺寸
			elif is_high_resolution:
				return 150  # 其他高分辨率
			else:
				return 100  # 标准分辨率
		_:
			if is_full_hd:
				return 80  # 增加间距以适应更大的卡牌尺寸
			elif is_high_resolution:
				return 150  # 其他高分辨率
			else:
				return 100  # 标准分辨率
		_:
			if is_full_hd:
				return 80  # 增加间距以适应更大的卡牌尺寸
			elif is_high_resolution:
				return 150  # 其他高分辨率
			else:
				return 100  # 标准分辨率

## 创建测试卡牌数据
func create_test_cards():
	print("创建 %s 模式测试卡牌数据..." % battle_mode)
	
	# 检查CardDatabase
	if not CardDatabase:
		print("错误: CardDatabase未加载")
		return
	
	# 根据模式创建不同的卡牌组合
	match battle_mode:
		"1v1":
			create_1v1_cards()
		"2v2":
			create_2v2_cards()
		"2v2_custom":
			create_2v2_custom_cards()
		"3v3", "3v3_bp":  # 将"3v3_bp"模式也视为3v3模式处理
			create_3v3_cards()
		_:
			print("未知的战斗模式: %s，使用默认2v2模式" % battle_mode)
			create_2v2_cards()

			create_2v2_cards()

## 创建1v1模式卡牌
func create_1v1_cards():
	print("创建1v1模式卡牌: 朵莉亚 vs 澜")
	
	# 玩家方：澜
	var lan_card = CardDatabase.get_card("lan_002")
	if lan_card:
		test_player_cards = [lan_card]
		print("玩家方卡牌: 澜")
	else:
		test_player_cards = [Card.new("澜", "确认目标。", 400, 400, 50, "鲨之猎刃", "增加自己攻击力100点。")]
	
	# 敌方：朵莉亚
	var duoliya_card = CardDatabase.get_card("duoliya_001")
	if duoliya_card:
		test_enemy_cards = [duoliya_card]
		print("敌方卡牌: 朵莉亚")
	else:
		test_enemy_cards = [Card.new("朵莉亚", "可爱的朵朵。", 300, 500, 100, "人鱼之赐", "为选择的队友恢复130点生命值。")]
	
	print("1v1模式卡牌准备完成: 澜 vs 朵莉亚")

## 创建在线模式默认卡牌（带唯一ID）
func create_default_online_cards():
	print("🌐 创建在线模式卡牌...")
	
	# 🎯 从Engine元数据读取服务器发送的卡牌数据
	if Engine.has_meta("online_blue_cards") and Engine.has_meta("online_red_cards"):
		var blue_cards_data = Engine.get_meta("online_blue_cards")
		var red_cards_data = Engine.get_meta("online_red_cards")
		
		print("📦 读取服务器卡牌数据: 蓝方%d张, 红方%d张" % [blue_cards_data.size(), red_cards_data.size()])
		
		# 清除元数据（已使用）
		Engine.remove_meta("online_blue_cards")
		Engine.remove_meta("online_red_cards")
		
		# 根据服务器数据创建卡牌
		var blue_cards = []
		var red_cards = []
		
		# 创建蓝方卡牌
		for card_data in blue_cards_data:
			# 🎯 从服务器ID提取卡牌数据库ID（例如：sunshangxiang_004_blue_0 → sunshangxiang_004）
			var server_id = card_data.get("id", "")
			var card_db_id = ""
			if "_blue_" in server_id or "_red_" in server_id:
				# 提取卡牌数据库ID（去掉_blue_0或_red_0后缀）
				var parts = server_id.split("_")
				if parts.size() >= 2:
					card_db_id = parts[0] + "_" + parts[1]  # 例如：sunshangxiang_004
			
			# 🎯 从CardDatabase获取完整卡牌（包括图片）
			var card = null
			if card_db_id != "":
				card = CardDatabase.get_card(card_db_id)
				if card != null:
					print("   📦 从CardDatabase加载卡牌: %s (ID: %s)" % [card.card_name, card_db_id])
			
			if card == null:
				# 兜底：手动创建Card对象
				card = Card.new(
					card_data.get("card_name", "未知"),
					"",  # description
					card_data.get("attack", 0),
					card_data.get("max_health", 100),
					card_data.get("armor", 0),
					card_data.get("skill_name", ""),
					"",  # skill_description
					null  # card_image
				)
				print("   ⚠️  兜底创建卡牌: %s" % card_data.get("card_name", "未知"))
			
			# 🎯 用服务器数据覆盖动态属性
			card.card_id = server_id
			# 如果服务器发送的health与max_health不同（已受伤），则覆盖health
			var server_health = card_data.get("health", card.max_health)
			if server_health != card.max_health:
				card.health = server_health
				print("   ⚠️  %s 不是满血状态: %d/%d" % [card.card_name, server_health, card.max_health])
			card.shield = card_data.get("shield", 0)
			card.crit_rate = card_data.get("crit_rate", 0.0)
			card.crit_damage = card_data.get("crit_damage", 1.3)
			card.skill_cost = card_data.get("skill_cost", 2)
			# � 特殊属性（公孙离、大乔等）
			card.dodge_rate = card_data.get("dodge_rate", 0.0)
			if card.card_name == "公孙离":
				card.gongsunli_dodge_bonus = card_data.get("dodge_bonus", 0.0)
			# � 大乔被动标记
			if card.card_name == "大乔":
				card.daqiao_passive_used = card_data.get("daqiao_passive_used", false)
			blue_cards.append(card)
			var extra_info = ""
			if card.dodge_rate > 0:
				extra_info += ", 闪避:%.0f%%" % (card.dodge_rate * 100)
			if card.card_name == "大乔":
				extra_info += ", 被动:%s" % ("已用" if card.daqiao_passive_used else "可用")
			print("   创建蓝方卡牌: %s (ID: %s, HP:%d/%d, ATK:%d, ARM:%d%s)" % [card.card_name, card.card_id, card.health, card.max_health, card.attack, card.armor, extra_info])
		
		# 创建红方卡牌
		for card_data in red_cards_data:
			# 🎯 从服务器ID提取卡牌数据库ID（例如：gongsunli_003_red_0 → gongsunli_003）
			var server_id = card_data.get("id", "")
			var card_db_id = ""
			if "_blue_" in server_id or "_red_" in server_id:
				# 提取卡牌数据库ID（去掉_blue_0或_red_0后缀）
				var parts = server_id.split("_")
				if parts.size() >= 2:
					card_db_id = parts[0] + "_" + parts[1]  # 例如：gongsunli_003
			
			# 🎯 从CardDatabase获取完整卡牌（包括图片）
			var card = null
			if card_db_id != "":
				card = CardDatabase.get_card(card_db_id)
				if card != null:
					print("   📦 从CardDatabase加载卡牌: %s (ID: %s)" % [card.card_name, card_db_id])
			
			if card == null:
				# 兜底：手动创建Card对象
				card = Card.new(
					card_data.get("card_name", "未知"),
					"",  # description
					card_data.get("attack", 0),
					card_data.get("max_health", 100),
					card_data.get("armor", 0),
					card_data.get("skill_name", ""),
					"",  # skill_description
					null  # card_image
				)
				print("   ⚠️  兜底创建卡牌: %s" % card_data.get("card_name", "未知"))
			
			# 🎯 用服务器数据覆盖动态属性
			card.card_id = server_id
			# 如果服务器发送的health与max_health不同（已受伤），则覆盖health
			var server_health = card_data.get("health", card.max_health)
			if server_health != card.max_health:
				card.health = server_health
				print("   ⚠️  %s 不是满血状态: %d/%d" % [card.card_name, server_health, card.max_health])
			card.shield = card_data.get("shield", 0)
			card.crit_rate = card_data.get("crit_rate", 0.0)
			card.crit_damage = card_data.get("crit_damage", 1.3)
			card.skill_cost = card_data.get("skill_cost", 2)
			# � 特殊属性（公孙离、大乔等）
			card.dodge_rate = card_data.get("dodge_rate", 0.0)
			if card.card_name == "公孙离":
				card.gongsunli_dodge_bonus = card_data.get("dodge_bonus", 0.0)
			# �� 大乔被动标记
			if card.card_name == "大乔":
				card.daqiao_passive_used = card_data.get("daqiao_passive_used", false)
			red_cards.append(card)
			var extra_info = ""
			if card.dodge_rate > 0:
				extra_info += ", 闪避:%.0f%%" % (card.dodge_rate * 100)
			if card.card_name == "大乔":
				extra_info += ", 被动:%s" % ("已用" if card.daqiao_passive_used else "可用")
			print("   创建红方卡牌: %s (ID: %s, HP:%d/%d, ATK:%d, ARM:%d%s)" % [card.card_name, card.card_id, card.health, card.max_health, card.attack, card.armor, extra_info])
		
		# 🌐 根据is_host决定哪方是"我方"
		if NetworkManager.is_host:
			# 房主：蓝方是我方，红方是对方
			test_player_cards = blue_cards
			test_enemy_cards = red_cards
			var player_names = []
			for c in blue_cards:
				player_names.append(c.card_name)
			var enemy_names = []
			for c in red_cards:
				enemy_names.append(c.card_name)
			print("🌐 房主视角：我方=蓝方(%s), 对方=红方(%s)" % ["+".join(player_names), "+".join(enemy_names)])
		else:
			# 客户端：红方是我方，蓝方是对方
			test_player_cards = red_cards
			test_enemy_cards = blue_cards
			var player_names = []
			for c in red_cards:
				player_names.append(c.card_name)
			var enemy_names = []
			for c in blue_cards:
				enemy_names.append(c.card_name)
			print("🌐 客户端视角：我方=红方(%s), 对方=蓝方(%s)" % ["+".join(player_names), "+".join(enemy_names)])
		
		print("🌐 在线模式卡牌创建完成（从服务器数据）")
	else:
		print("⚠️ 警告：未找到服务器卡牌数据，使用默认卡牌")
		# 兜底逻辑：使用默认卡牌
		_create_fallback_online_cards()

## 创建兜底的在线模式卡牌（当服务器数据丢失时）
func _create_fallback_online_cards():
	print("🔄 使用兜底卡牌配置...")
	# 原有的默认卡牌逻辑
	var blue_lan = CardDatabase.get_card("lan_002")
	var blue_sunshangxiang = CardDatabase.get_card("sunshangxiang_004")
	var red_gongsunli = CardDatabase.get_card("gongsunli_003")
	var red_duoliya = CardDatabase.get_card("duoliya_001")
	
	if not blue_lan or not blue_sunshangxiang or not red_gongsunli or not red_duoliya:
		print("❌ 无法获取兜底卡牌")
		return
	
	blue_lan.card_id = "lan_002_blue_0"
	blue_sunshangxiang.card_id = "sunshangxiang_004_blue_1"
	red_gongsunli.card_id = "gongsunli_003_red_0"
	red_duoliya.card_id = "duoliya_001_red_1"
	
	if NetworkManager.is_host:
		test_player_cards = [blue_lan, blue_sunshangxiang]
		test_enemy_cards = [red_gongsunli, red_duoliya]
	else:
		test_player_cards = [red_gongsunli, red_duoliya]
		test_enemy_cards = [blue_lan, blue_sunshangxiang]
	
	print("🔄 兜底卡牌配置完成")

## 创建2v2模式卡牌
func create_2v2_cards():
	print("创建2v2模式卡牌: 公孙离+澜 vs 朵莉亚+澜")
	
	# 创建玩家方卡牌：公孙离 + 澜
	var gongsunli_card = CardDatabase.get_card("gongsunli_003")
	var lan_card = CardDatabase.get_card("lan_002")
	
	if gongsunli_card and lan_card:
		test_player_cards = [gongsunli_card, lan_card]
		print("成功获取玩家方卡牌: 公孙离 + 澜")
	else:
		print("错误: 无法获取玩家方卡牌")
		create_default_2v2_cards()
		return
	
	# 创建敌方卡牌：朵莉亚 + 澜
	var duoliya_card = CardDatabase.get_card("duoliya_001")
	var enemy_lan_card = CardDatabase.get_card("lan_002")
	
	if duoliya_card and enemy_lan_card:
		test_enemy_cards = [duoliya_card, enemy_lan_card]
		print("成功获取敌方卡牌: 朵莉亚 + 澜")
	else:
		print("错误: 无法获取敌方卡牌")
		create_default_2v2_cards()
		return
	
	print("2v2模式卡牌准备完成: [公孙离+澜] vs [朵莉亚+澜]")

## 创建2v2自定义选择模式卡牌
func create_2v2_custom_cards():
	print("创建2v2自定义模式卡牌...")
	
	# 从全局元数据获取选择的卡牌
	if Engine.has_meta("player1_cards") and Engine.has_meta("player2_cards"):
		var player1_cards = Engine.get_meta("player1_cards")
		var player2_cards = Engine.get_meta("player2_cards")
		var first_player = Engine.get_meta("first_player", 1)
		
		print("加载自定义卡牌选择:")
		print("  玩家1卡牌: %d张" % player1_cards.size())
		print("  玩家2卡牌: %d张" % player2_cards.size())
		print("  先手玩家: %d" % first_player)
		
		# 正确复制卡牌对象，确保数据独立性
		var duplicated_player1_cards = []
		var duplicated_player2_cards = []
		
		for card in player1_cards:
			if card:
				duplicated_player1_cards.append(card.duplicate_card())
				print("  复制玩家1卡牌: %s" % card.card_name)
		
		for card in player2_cards:
			if card:
				duplicated_player2_cards.append(card.duplicate_card())
				print("  复制玩家2卡牌: %s" % card.card_name)
		
		# 根据先手决定谁是"玩家方"谁是"敌方"
		if first_player == 1:
			# 玩家1先手，设置为玩家方
			test_player_cards = duplicated_player1_cards
			test_enemy_cards = duplicated_player2_cards
			print("玩家1先手 - 玩家1为我方，玩家2为敌方")
		else:
			# 玩家2先手，设置为玩家方
			test_player_cards = duplicated_player2_cards
			test_enemy_cards = duplicated_player1_cards
			print("玩家2先手 - 玩家2为我方，玩家1为敌方")
		
		# 清理全局元数据
		Engine.remove_meta("player1_cards")
		Engine.remove_meta("player2_cards")
		Engine.remove_meta("first_player")
		Engine.remove_meta("battle_mode")
		
		print("2v2自定义卡牌准备完成")
	else:
		print("警告: 未找到自定义卡牌数据，使用默认2v2模式")
		create_2v2_cards()

## 创建3v3模式卡牌
func create_3v3_cards():
	print("创建3v3模式卡牌...")
	
	# 检查是否使用自定义队伍
	if BattleManager.use_custom_teams:
		print("使用自定义队伍配置")
		test_player_cards = BattleManager.custom_blue_team
		test_enemy_cards = BattleManager.custom_red_team
		# 重置自定义队伍标志
		BattleManager.use_custom_teams = false
		BattleManager.custom_blue_team = []
		BattleManager.custom_red_team = []
		print("3v3自定义卡牌准备完成")
		return
	
	print("创建默认3v3模式卡牌: 少司缘+瑶+孙尚香 vs 大乔+杨玉环+公孙离")
	
	# 获取所有卡牌
	var shaosiyuan_card = CardDatabase.get_card("shaosiyuan_007")  # 少司缘替换朵莉亚
	var yao_card = CardDatabase.get_card("yao_005")  # 瑶
	var yangyuhuan_card = CardDatabase.get_card("yangyuhuan_008")  # 杨玉环替换澜
	var gongsunli_card = CardDatabase.get_card("gongsunli_003")
	var sunshangxiang_card = CardDatabase.get_card("sunshangxiang_004")
	var daqiao_card = CardDatabase.get_card("daqiao_006")  # 大乔
	
	if shaosiyuan_card and yao_card and yangyuhuan_card and gongsunli_card and sunshangxiang_card and daqiao_card:
	# 玩家方：少司缘 + 瑶 + 孙尚香（将朵莉亚替换为少司缘）
		# 注意：这里不使用duplicate()，以保持少司缘的偋取点数计数
		test_player_cards = [shaosiyuan_card, yao_card, sunshangxiang_card]
		# 敌方：大乔 + 杨玉环 + 公孙离（将澜替换为杨玉环）
		test_enemy_cards = [daqiao_card, yangyuhuan_card, gongsunli_card]
		print("3v3模式卡牌准备完成: [少司缘+瑶+孙尚香] vs [大乔+杨玉环+公孙离]")
	else:
		print("错误: 无法获取3v3模式卡牌")
		create_default_3v3_cards()


## 创建默认2v2测试卡牌
func create_default_2v2_cards():
	print("创建默认2v2测试卡牌...")
	
	# 创建默认玩家方卡牌
	var gongsunli = Card.new("公孙离", "送你冰心一片。", 400, 300, 0, "晚云落", "增加自己50%暴击率。")
	var lan = Card.new("澜", "确认目标。", 400, 400, 50, "鲨之猎刃", "增加自己攻击力100点。")
	test_player_cards = [gongsunli, lan]
	
	# 创建默认敌方卡牌
	var duoliya = Card.new("朵莉亚", "可爱的朵朵。", 300, 500, 100, "人鱼之赐", "为选择的队友恢复130点生命值。")
	var enemy_lan = Card.new("澜", "确认目标。", 400, 400, 50, "鲨之猎刃", "增加自己攻击力100点。")
	test_enemy_cards = [duoliya, enemy_lan]
	
	print("默认2v2测试卡牌创建完成")

## 创建默认3v3测试卡牌
func create_default_3v3_cards():
	print("创建默认3v3测试卡牌...")
	
	# 创建默认玩家方卡牌
	var duoliya_p = Card.new("朵莉亚", "可爱的朵朵。", 300, 500, 100, "人鱼之赐", "为选择的队友恢复130点生命值。")
	var yao_p = Card.new("瑶", "有只小鹿飞走了。", 280, 850, 200, "鹿灵守心", "使一名友方英雄获得150点护盾值。")  # 瑶替换原来的澜
	var sunshangxiang_p = Card.new("孙尚香", "本小姐才是你在废墟中唯一的信仰。", 550, 625, 175, "红莲爆弹", "选择一名敌方单位，永久性的减少其60点护甲值，并对其造成75点真实伤害。")
	test_player_cards = [duoliya_p, yao_p, sunshangxiang_p]
	
	# 创建默认敌方卡牌
	var daqiao_e = Card.new("大乔", "宿命之海，沧海之曜。", 300, 800, 150, "沧海之曜", "对每个敌方英雄造成(已损生命值+攻击力)/5点真实伤害。", null, "宿命之海", "受到致命伤害时，立即将大乔生命值设置为1点，并使己方技能点池增加3点。若己方技能点增加后溢出，每溢出1点技能点则转换为大乔150点护盾值。一局游戏只能触发一次。")
	daqiao_e.crit_rate = 0.10  # 设置暴击率10%
	daqiao_e.skill_cost = 4  # 设置技能消耗4点
	daqiao_e.skill_ends_turn = false  # 🎯 所有技能不再强制结束回合
	var lan_e = Card.new("澜", "确认目标。", 400, 400, 50, "鲨之猎刃", "增加自己攻击力100点。")
	var gongsunli_e = Card.new("公孙离", "送你冰心一片。", 400, 300, 0, "晚云落", "增加自己50%暴击率。")
	test_enemy_cards = [daqiao_e, lan_e, gongsunli_e]
	
	print("默认3v3测试卡牌创建完成")

## 开始测试战斗
func start_test_battle():
	print("开始2v2测试战斗...")
	
	if test_player_cards.is_empty() or test_enemy_cards.is_empty():
		print("错误: 测试卡牌数据为空")
		update_battle_status("错误: 无法开始战斗，卡牌数据缺失")
		return
	
	# 在开始战斗前，确保朵莉亚的被动技能已设置正确
	for card in test_player_cards:
		if card.card_name == "朵莉亚":
			card.passive_skill_name = "欢歌"
			card.passive_skill_effect = "每回合开始时，为朵莉亚自己恢复75点生命值，如果恢复到满生命值，溢出的部分将会转化为自己的护盾值。"
	
	for card in test_enemy_cards:
		if card.card_name == "朵莉亚":
			card.passive_skill_name = "欢歌"
			card.passive_skill_effect = "每回合开始时，为朵莉亚自己恢复75点生命值，如果恢复到满生命值，溢出的部分将会转化为自己的护盾值。"
	
	# 开始战斗
	var success = BattleManager.start_battle(test_player_cards, test_enemy_cards)
	if success:
		print("2v2战斗开始成功")
		# 创建战斗实体
		call_deferred("create_battle_entities")
	else:
		print("战斗开始失败")
		update_battle_status("战斗开始失败")

## 创建战斗实体
func create_battle_entities():
	print("创建2v2战斗实体...")
	
	# 清理现有实体
	clear_battle_entities()
	
	# 创建玩家方卡牌实体
	for i in range(test_player_cards.size()):
		var card = test_player_cards[i]
		var entity = create_battle_entity(card, true)
		if entity:
			player_cards.append(entity)
			print("玩家卡牌实体创建成功: %s" % entity.get_card().card_name)
	
	# 创建敌方卡牌实体
	for i in range(test_enemy_cards.size()):
		var card = test_enemy_cards[i]
		var entity = create_battle_entity(card, false)
		if entity:
			enemy_cards.append(entity)
			print("敌方卡牌实体创建成功: %s" % entity.get_card().card_name)
	
	print("2v2战斗实体创建完成 - 双方手动操作模式")
	update_battle_status("公孙离的回合 - 选择攻击或发动技能")
	print("游戏提示: 现在2v2模式，可以测试所有技能效果！")
	print("- 点击自己的卡牌选择攻击者，再点击敌方卡牌攻击")
	print("- 点击技能按钮发动当前选中卡牌的技能")
	
	# 显示实时属性
	call_deferred("update_cards_display")

## 更新所有卡牌的实时属性显示
func update_cards_display():
	print("\n=== 实时卡牌属性 ===")
	
	# 显示玩家方卡牌
	print("💫 玩家方卡牌:")
	for i in range(player_cards.size()):
		var entity = player_cards[i]
		if entity and is_instance_valid(entity):
			var card = entity.get_card()
			if card:
				var status = "👾" if card.is_dead() else "💪"
				print("  %d. %s %s - 攻击:%d | 生命:%d/%d | 护甲:%d" % [
					i+1, status, card.card_name, card.attack, card.health, card.max_health, card.armor
				])
	
	# 显示敌方卡牌
	print("💫 敌方卡牌:")
	for i in range(enemy_cards.size()):
		var entity = enemy_cards[i]
		if entity and is_instance_valid(entity):
			var card = entity.get_card()
			if card:
				var status = "👾" if card.is_dead() else "💪"
				print("  %d. %s %s - 攻击:%d | 生命:%d/%d | 护甲:%d" % [
					i+1, status, card.card_name, card.attack, card.health, card.max_health, card.armor
				])
	
	print("======================\n")

## 获取首个存活的玩家卡牌
func get_first_alive_player_card():
	for entity in player_cards:
		if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
			return entity
	return null

## 获取首个存活的敌方卡牌
func get_first_alive_enemy_card():
	for entity in enemy_cards:
		if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
			return entity
	return null

## 创建单个战斗实体
func create_battle_entity(card, is_player: bool):
	if not card:
		print("警告: 尝试创建空卡牌的战斗实体")
		return null
	
	print("创建战斗实体: %s (玩家: %s)" % [card.card_name, str(is_player)])
	
	# 创建BattleEntity实例
	var battle_entity_script = load("res://scripts/battle/BattleEntity.gd")
	if not battle_entity_script:
		print("错误: 无法加载BattleEntity脚本")
		return null
	
	var entity = battle_entity_script.new()
	entity.set_card_data(card, is_player)
	
	# 🌐 注册卡牌实体到BattleManager（用于网络同步时更新UI）
	BattleManager.entity_card_map[card] = entity
	print("🌐 注册卡牌实体: %s -> %s" % [card.card_name, entity])
	
	# 连接信号
	entity.card_clicked.connect(_on_card_clicked)
	entity.health_changed.connect(_on_entity_health_changed)
	entity.died.connect(_on_entity_died)
	
	# 添加到对应容器
	if is_player:
		if player_card_container and is_instance_valid(player_card_container):
			player_card_container.add_child(entity)
			player_entities.append(entity)
		else:
			print("错误: 玩家卡牌容器不存在")
			return null
	else:
		if enemy_card_container and is_instance_valid(enemy_card_container):
			enemy_card_container.add_child(entity)
			enemy_entities.append(entity)
		else:
			print("错误: 敌人卡牌容器不存在")
			return null
	
	return entity

## 清理战斗实体
func clear_battle_entities():
	print("清理战斗实体...")
	
	# 清理玩家实体
	for entity in player_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	player_entities.clear()
	
	# 清理敌人实体
	for entity in enemy_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	enemy_entities.clear()
	
	# 🌐 清除BattleManager的卡牌实体映射
	BattleManager.entity_card_map.clear()
	print("🌐 已清除卡牌实体映射")

## 卡牌点击处理
func _on_card_clicked(entity):
	print("卡牌被点击: %s (is_player: %s)" % [entity.get_card().card_name, entity.is_player()])
	
	# 🌐 在线模式：检查是否是我的回合
	if BattleManager.is_online_mode:
		# 判断当前是否是我的回合
		var current_turn_num = BattleManager.current_turn
		var is_host_turn = (current_turn_num % 2 == 1)  # 奇数回合是房主
		var is_my_turn = (NetworkManager.is_host == is_host_turn)
		
		if not is_my_turn:
			# 🔍 非我回合时，允许查看卡牌信息
			show_card_info_popup(entity)
			return
		
		# ⚠️ 只在选择攻击者时检查（未选择目标时）
		# 如果已经选择了攻击者，则允许点击敌方卡牌作为目标
		if not is_selecting_target and not entity.is_player():
			# 🔍 允许查看敌方卡牌信息
			show_card_info_popup(entity)
			return
	
	# 如果正在使用技能（特别是治疗技能）
	if is_using_skill and is_selecting_target and selected_card:
		# 显示取消按钮
		var cancel_button = get_cancel_skill_button()
		if cancel_button:
			cancel_button.visible = true
		
		# 使用SkillManager验证目标是否有效
		var caster_card = selected_card.get_card()
		if SkillManager.is_valid_target(selected_card, entity, caster_card.card_name, caster_card.skill_name):
			# 执行技能（使用通用方法）
			execute_skill(selected_card, entity)
			# 🔧 技能执行后重置选择状态
			reset_selection()
			return
		else:
			update_battle_status("请选择有效的技能目标")
			return
	
	# 普通攻击目标选择
	if is_selecting_target and selected_card and not is_using_skill:
		# 检查是否点击的是己方卡牌（用于切换选择）
		var same_side = (selected_card.is_player() and entity.is_player()) or (not selected_card.is_player() and not entity.is_player())
		if same_side and not entity.get_card().is_dead():
			# 如果点击的是己方卡牌，且不是当前选中的卡牌，则切换选择
			if entity != selected_card:
				print("切换卡牌选择: %s -> %s" % [selected_card.get_card().card_name, entity.get_card().card_name])
				# 不再在消息系统中记录切换操作，减少干扰信息
				# 重置当前选择状态
				reset_selection()
				# 选择新的卡牌
				select_attacker(entity)
				return
			else:
				# 如果点击的是同一张卡牌，保持当前选择不变
				update_battle_status("当前已选中%s，请选择攻击目标或点击其他卡牌切换" % entity.get_card().card_name)
				return
		
		# 检查是否是有效的攻击目标（对方阵营）
		var different_side = (selected_card.is_player() and not entity.is_player()) or (not selected_card.is_player() and entity.is_player())
		if different_side and not entity.get_card().is_dead():
			execute_attack(selected_card, entity)
			return
		else:
			update_battle_status("请选择敌方的存活卡牌进行攻击")
			return
	
	# 选择攻击者或施法者
	if BattleManager.is_player_turn():
		# 玩家回合，只能选择玩家方卡牌
		if entity.is_player() and not entity.get_card().is_dead():
			select_attacker(entity)
		else:
			update_battle_status("请选择己方存活的卡牌")
	else:
		# 敌方回合，只能选择敌方卡牌
		if not entity.is_player() and not entity.get_card().is_dead():
			select_attacker(entity)
		else:
			update_battle_status("请选择己方存活的卡牌")

## 选择攻击者
func select_attacker(entity):
	if not entity.can_attack():
		update_battle_status("该卡牌无法攻击")
		return
	
	# 取消之前的选择
	if selected_card:
		selected_card.set_selected(false)
	
	# 选择新的攻击者
	selected_card = entity
	selected_card.set_selected(true)
	is_selecting_target = true
	
	# 更新技能按钮状态（根据新选中的卡牌）
	update_skill_button_state()
	
	# 根据当前回合设置目标卡牌为可攻击状态
	if BattleManager.is_player_turn():
		# 澜的回合，设置朵莉亚为目标
		for enemy in enemy_entities:
			enemy.set_targetable(true)
	else:
		# 朵莉亚的回合，设置澜为目标
		for player in player_entities:
			player.set_targetable(true)
	
	update_battle_status("已选中%s - 点击敌方卡牌攻击，或点击其他己方卡牌切换" % selected_card.get_card().card_name)

## 执行攻击
func execute_attack(attacker, target):
	# 重置选择状态
	reset_selection()
	
	# 播放攻击动画并等待完成
	var target_pos = target.global_position
	await attacker.play_attack_animation(target_pos)
	
	# 攻击动画已经内置位置重置，无需额外调用
	# 添加额外的安全检查确保位置正确
	if attacker.original_position != Vector2.ZERO:
		attacker.position = attacker.original_position
		print("额外安全检查: %s 位置重置为 %s" % [attacker.get_card().card_name, str(attacker.position)])
	
	# 根据当前回合确定攻击者是否为玩家方
	var attacker_is_player = BattleManager.is_player_turn()
	
	# 执行战斗管理器的攻击逻辑（在线模式只发送意图）
	var result = BattleManager.execute_attack(attacker.get_card(), target.get_card(), attacker_is_player)
	
	# 🌐 在线模式：攻击意图已发送，等待服务器结果
	if BattleManager.is_online_mode:
		print("🌐 在线模式：攻击意图已发送，等待服务器结果...")
		# 服务器结果会通过 _handle_opponent_attack 处理
		# 🎯 使用行动点
		var should_end = BattleManager.use_action(attacker_is_player)
		if should_end:
			call_deferred("end_turn")
		return
	
	# 单机模式：处理本地攻击结果
	
	if result.success:
		# 更新目标实体
		target.update_display()
		
		# 优化：统一记录攻击结果到消息系统，避免重复消息
		if message_system:
			# 先记录被动技能触发（如果有）
			if result.lan_passive_triggered:
				var passive_details = {
					"damage_bonus": 0.3
				}
				message_system.add_passive_skill(attacker.get_card().card_name, "狩猎", "目标生命值低于50%，增伤+30%", passive_details)
			
			# 处理闪避情况
			if result.is_dodged:
				var dodge_details = {
					"dodge_rate": target.get_card().get_gongsunli_dodge_rate() if target.get_card().card_name == "公孙离" else 0.3
				}
				message_system.add_dodge(target.get_card().card_name, attacker.get_card().card_name, result.get("original_damage", result.final_damage), dodge_details)
			else:
				# 准备详细信息
				var attack_details = {
					"attacker_attack": result.attacker.attack,
					"target_armor": result.target.armor,
					"base_damage": result.base_damage,
					"is_critical": result.is_critical,
					"crit_damage": result.crit_damage,
					"has_damage_bonus": result.has_damage_bonus,
					"damage_bonus_percent": result.get("damage_bonus_percent", 0)
				}
				
				# 使用组合攻击消息，自动处理各种效果组合
				var effects = []
				if result.is_critical:
					effects.append("暴击")
				if result.has_damage_bonus:
					effects.append("被动")
				
				if not effects.is_empty():
					message_system.add_combo_attack(attacker.get_card().card_name, target.get_card().card_name, result.final_damage, effects, attack_details)
				else:
					message_system.add_attack(attacker.get_card().card_name, target.get_card().card_name, result.final_damage, attack_details)
		
			# 如果目标死亡，记录死亡消息
			if result.target_dead:
				message_system.add_death(target.get_card().card_name)
		
		# 如果目标死亡，播放死亡动画
		if result.target_dead:
			target.take_damage(0)  # 触发死亡动画
	
	# 🎯 使用行动点，检查是否应该结束回合
	var should_end = BattleManager.use_action(attacker_is_player)
	if should_end:
		call_deferred("end_turn")

## 获取取消技能按钮
func get_cancel_skill_button():
	return cancel_skill_button

## 重置选择状态
func reset_selection():
	if selected_card:
		selected_card.set_selected(false)
		selected_card = null
	
	is_selecting_target = false
	is_using_skill = false
	
	# 隐藏取消技能按钮
	var cancel_button = get_cancel_skill_button()
	if cancel_button:
		cancel_button.visible = false
	
	# 重置所有卡牌的可攻击/可选择状态
	for i in range(player_cards.size() - 1, -1, -1):
		var entity = player_cards[i]
		if entity and is_instance_valid(entity):
			entity.set_targetable(false)
		else:
			# 移除无效实体
			player_cards.remove_at(i)
			print("从player_cards移除无效实体")
	
	for i in range(enemy_cards.size() - 1, -1, -1):
		var entity = enemy_cards[i]
		if entity and is_instance_valid(entity):
			entity.set_targetable(false)
		else:
			# 移除无效实体
			enemy_cards.remove_at(i)
			print("从enemy_cards移除无效实体")
	
	# 确保兼容旧的实体数组
	for i in range(enemy_entities.size() - 1, -1, -1):
		var enemy = enemy_entities[i]
		if is_instance_valid(enemy):
			enemy.set_targetable(false)
		else:
			# 移除无效实体
			enemy_entities.remove_at(i)
			print("从enemy_entities移除无效实体")
	
	for i in range(player_entities.size() - 1, -1, -1):
		var player = player_entities[i]
		if is_instance_valid(player):
			player.set_targetable(false)
		else:
			# 移除无效实体
			player_entities.remove_at(i)
			print("从player_entities移除无效实体")

## 结束回合
func end_turn():
	print("结束回合")
	reset_selection()
	
	# 全局位置验证：确保所有卡牌位置正确
	verify_all_card_positions()
	
	# 🌐 在线模式：只发送消息，等待服务器的turn_changed
	if BattleManager.is_online_mode and NetworkManager:
		NetworkManager.send_end_turn()
		print("� 已发送结束回合到服务器，等待服务器响应...")
		# ⚠️ 不做任何本地计算！等待服务器的turn_changed消息
		return
	
	# 单机模式：立即切换回合
	BattleManager.next_turn()
	
	# 双方都由玩家手动操作，不自动执行AI

## 验证所有卡牌位置
func verify_all_card_positions():
	print("验证所有卡牌位置...")
	var fixed_count = 0
	
	# 验证玩家方卡牌
	for entity in player_cards:
		if entity and is_instance_valid(entity):
			if entity.verify_and_fix_position():
				fixed_count += 1
	
	# 验证敌方卡牌
	for entity in enemy_cards:
		if entity and is_instance_valid(entity):
			if entity.verify_and_fix_position():
				fixed_count += 1
	
	# 兼容旧的实体数组
	for entity in player_entities:
		if is_instance_valid(entity):
			if entity.verify_and_fix_position():
				fixed_count += 1
	
	for entity in enemy_entities:
		if is_instance_valid(entity):
			if entity.verify_and_fix_position():
				fixed_count += 1
	
	if fixed_count > 0:
		print("已修复 %d 张卡牌的位置偏差" % fixed_count)
	else:
		print("所有卡牌位置正常")



## 更新界面信息
func update_battle_status(message: String):
	if battle_status_label and is_instance_valid(battle_status_label):
		battle_status_label.text = message

# 优化：减少不必要的调试输出
func update_last_action(_message: String):
	# 消息已经通过消息系统统一处理，此方法仅用于兼容性
	pass

func update_turn_info(turn: int, is_player: bool):
	if turn_info_label and is_instance_valid(turn_info_label):
		var turn_text = "回合 %d - %s回合" % [turn, "玩家" if is_player else "敌人"]
		turn_info_label.text = turn_text

## 战斗管理器信号处理
func _on_turn_changed(is_player_turn: bool):
	var battle_info = BattleManager.get_battle_info()
	update_turn_info(battle_info.turn, is_player_turn)
	
	# 消息系统记录回合开始
	if message_system:
		# 确保每个回合都传递玩家信息，包括第一回合
		var player_name = "玩家" if is_player_turn else "敌方"
		message_system.start_new_turn(battle_info.turn, player_name)
	else:
		print("错误: message_system 为 null")
	
	if is_player_turn:
		# 获取当前玩家回合的首个存活卡牌
		var current_player_card = get_first_alive_player_card()
		if current_player_card:
			update_battle_status("%s的回合 - 选择攻击或发动技能" % current_player_card.get_card().card_name)
		else:
			update_battle_status("玩家回合 - 选择攻击或发动技能")
		
		if end_turn_button and is_instance_valid(end_turn_button):
			end_turn_button.disabled = false
		if use_skill_button and is_instance_valid(use_skill_button):
			use_skill_button.disabled = false
			use_skill_button.text = "发动技能"  # 默认文本
	else:
		# 获取当前敌方回合的首个存活卡牌
		var current_enemy_card = get_first_alive_enemy_card()
		if current_enemy_card:
			update_battle_status("%s的回合 - 选择攻击或发动技能" % current_enemy_card.get_card().card_name)
		else:
			update_battle_status("敌方回合 - 选择攻击或发动技能")
		
		if end_turn_button and is_instance_valid(end_turn_button):
			end_turn_button.disabled = false
		if use_skill_button and is_instance_valid(use_skill_button):
			use_skill_button.disabled = false
			use_skill_button.text = "发动技能"  # 默认文本
	
	# 更新属性显示
	call_deferred("update_cards_display")
	
	# 输出回合开始的详细信息
	print("\n=== 第 %d 回合开始 ===" % battle_info.turn)
	print("当前回合: %s" % ("玩家" if is_player_turn else "敌方"))
	
	# 显示当前所有卡牌状态
	call_deferred("update_cards_display")

func _on_battle_state_changed(new_state):
	# 只在关键状态变化时输出
	# 检查是否是整数类型（枚举值）
	if typeof(new_state) == TYPE_INT and new_state == BattleManager.BattleStateEnum.BATTLE_END:
		print("战斗状态变化: 战斗结束")
	# 检查是否是字符串类型（状态名称）
	elif typeof(new_state) == TYPE_STRING and new_state == "battle_end":
		print("战斗状态变化: 战斗结束")

func _on_battle_ended(result: Dictionary):
	# 减少调试输出，只保留关键信息
	if message_system:
		message_system.add_battle_end(result.victory)
	
	var message = "战斗结束 - %s！" % ("胜利" if result.victory else "失败")
	update_battle_status(message)
	
	if end_turn_button and is_instance_valid(end_turn_button):
		end_turn_button.disabled = true

func _on_card_died(_card: Card, _is_player: bool):
	# 死亡信息已由消息系统处理，此处不再重复输出
	pass

func _on_entity_health_changed(_entity, _old_health: int, _new_health: int):
	# 减少冗余的调试信息
	pass

func _on_entity_died(entity):
	# 从列表中移除
	if entity in player_entities:
		player_entities.erase(entity)
		print("移除已死亡实体从 player_entities: %s" % entity.get_card().card_name)
	elif entity in enemy_entities:
		enemy_entities.erase(entity)
		print("移除已死亡实体从 enemy_entities: %s" % entity.get_card().card_name)
	
	# 移除实体从新数组中
	if entity in player_cards:
		player_cards.erase(entity)
		print("移除已死亡实体从 player_cards: %s" % entity.get_card().card_name)
	elif entity in enemy_cards:
		enemy_cards.erase(entity)
		print("移除已死亡实体从 enemy_cards: %s" % entity.get_card().card_name)
	
	# 检查战斗是否结束
	BattleManager.call_deferred("check_battle_end")

## 被动技能触发处理
func _on_passive_skill_triggered(card: Card, skill_name: String, effect: String, details: Dictionary = {}):
	print("被动技能触发: %s 的 %s - %s" % [card.card_name, skill_name, effect])
	
	# 更新对应卡牌实体的显示
	update_card_entity_display(card)
	
	# 在消息系统中记录被动技能
	if message_system:
		match skill_name:
			"欢歌":
				# 🔧 朵莉亚的被动技能处理 - 使用服务器传来的真实数据
				var heal_details = {
					"heal_amount": details.get("heal_amount", 0),
					"overflow_shield": details.get("overflow_shield", 0)
				}
				
				# 直接传递details给add_passive_skill，让它根据数据判断显示内容
				message_system.add_passive_skill(card.card_name, skill_name, effect, heal_details)
			"狩猎":
				details = {
					"damage_bonus": 0.3
				}
				message_system.add_passive_skill(card.card_name, skill_name, "目标生命值低于50%，增伤+30%", details)
			"千金重弩":
				var regex = RegEx.new()
				regex.compile(r"(\d+)点技能点")
				var match_result = regex.search(effect)
				var skill_points = 1
				if match_result:
					skill_points = int(match_result.get_string(1))
				details = {
					"skill_points_gained": skill_points
				}
				message_system.add_passive_skill(card.card_name, skill_name, "获得%d点技能点" % skill_points, details)
			"霜叶舞":
				if "成功闪避攻击" in effect:
					# 闪避成功效果 - 增加攻击力和暴击率
					details = {
						"attack_bonus": 10,
						"crit_rate_bonus": 0.05,
						"current_attack": card.attack,
						"current_crit_rate": card.crit_rate * 100 # 转为百分比
					}
					message_system.add_passive_skill(card.card_name, skill_name, "成功闪避攻击，获得攻击力+10和暴击率+5%", details)
				elif "攻击暴击触发" in effect:
					# 暴击触发效果 - 增加闪避概率
					var current_dodge_rate = 0.0
					
					# 尝试从效果消息中提取当前闪避概率
					var regex = RegEx.new()
					regex.compile(r"当前闪避概率([\d\.]+)%")
					var match_result = regex.search(effect)
					if match_result:
						current_dodge_rate = float(match_result.get_string(1))
					else:
						# 如果消息中没有，则从卡牌获取
						current_dodge_rate = card.get_gongsunli_dodge_rate() * 100
					
					print("公孙离攻击暴击触发被动技能：当前闪避概率 %.1f%%" % current_dodge_rate)
					
					details = {
						"dodge_bonus": 0.05,
						"current_dodge_rate": current_dodge_rate
					}
					message_system.add_passive_skill(card.card_name, skill_name, "攻击暴击，获得固定增益，闪避概率+5%%，当前闪避概率%.1f%%" % current_dodge_rate, details)
			"山鬼白鹿":
				# 瑶被动技能为其他角色添加护盾的情况
				# 从effect中提取目标名称，用于更新UI
				var regex = RegEx.new()
				regex.compile(r"为(.+)添加(\d+)点护盾")
				var match_result = regex.search(effect)
				if match_result:
					var target_name = match_result.get_string(1)
					# 更新获得护盾的友方卡牌显示
					for entity in player_cards + enemy_cards:
						if entity and is_instance_valid(entity) and entity.get_card().card_name == target_name:
							entity.update_display()
							print("更新获得护盾的友方卡牌显示: %s" % target_name)
							break
				# 直接使用传入的details，已经包含正确的数值
				message_system.add_passive_skill(card.card_name, "山鬼白鹿", effect, details)
			"宿命之海":
				# 大乔的被动技能处理
				if not details.is_empty():
					# 使用我们新添加的详细处理方法
					message_system.add_daqiao_passive(card.card_name, skill_name, effect, details)
				else:
					# 兼容旧的处理方式
					message_system.add_passive_skill(card.card_name, skill_name, effect)
			"怨离别":
				# 少司缘的被动技能处理
				if not details.is_empty():
					# 使用我们新添加的详细处理方法
					message_system.add_shaosiyuan_passive(card.card_name, skill_name, effect, details)
				else:
					# 兼容旧的处理方式
					message_system.add_passive_skill(card.card_name, skill_name, effect)
			"霓裳风华":
				# 杨玉环的被动技能处理
				if not details.is_empty():
					# 使用我们新添加的详细处理方法
					message_system.add_yangyuhuan_passive(card.card_name, skill_name, effect, details)
				else:
					# 兼容旧的处理方式
					message_system.add_passive_skill(card.card_name, skill_name, effect)
			_:
				message_system.add_passive_skill(card.card_name, skill_name, "被动技能发动")
	
	# 显示实时属性
	call_deferred("update_cards_display")
	
	# 输出被动技能触发后的详细状态
	print("被动技能触发后状态:")
	call_deferred("update_cards_display")

## 按钮事件处理
func _on_end_turn_pressed():
	# 🌐 在线模式：检查是否是我的回合
	if BattleManager.is_online_mode:
		var current_turn_num = BattleManager.current_turn
		var is_host_turn = (current_turn_num % 2 == 1)
		var is_my_turn = (NetworkManager.is_host == is_host_turn)
		
		if not is_my_turn:
			update_battle_status("不是你的回合！")
			print("🌐 阻止结束回合：当前是对手回合")
			return
	
	end_turn()

func _on_use_skill_pressed():
	# 🌐 在线模式：检查是否是我的回合
	if BattleManager.is_online_mode:
		var current_turn_num = BattleManager.current_turn
		var is_host_turn = (current_turn_num % 2 == 1)
		var is_my_turn = (NetworkManager.is_host == is_host_turn)
		
		if not is_my_turn:
			update_battle_status("不是你的回合！")
			print("🌐 阻止技能：当前是对手回合")
			return
	
	use_player_skill()

func _on_cancel_skill_pressed():
	# 取消技能释放
	reset_selection()
	update_battle_status("已取消技能释放")
	# 隐藏取消按钮
	var cancel_button = get_cancel_skill_button()
	if cancel_button:
		cancel_button.visible = false

func _on_back_to_menu_pressed():
	# 遵循规范：返回主菜单时重置所有状态
	reset_all_global_states()
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

## 显示卡牌详细信息弹窗
func show_card_info_popup(entity):
	if not entity or not entity.get_card():
		print("❌ entity或card为空")
		return
	
	var card = entity.get_card()
	
	# 详细调试输出
	print("==================================================")
	print("📖 准备显示卡牌信息")
	print("   卡牌名: %s" % card.card_name)
	print("   卡牌ID: %s" % card.card_id)
	print("   技能名: [%s]" % card.skill_name)
	print("   技能效果长度: %d" % card.skill_effect.length())
	print("   技能效果内容: [%s]" % card.skill_effect)
	print("   被动名: [%s]" % card.passive_skill_name)
	print("   被动效果长度: %d" % card.passive_skill_effect.length())
	print("   被动效果内容: [%s]" % card.passive_skill_effect)
	print("==================================================")
	
	# 加载并实例化弹窗脚本
	var CardInfoPopup = load("res://scripts/battle/CardInfoPopup.gd")
	var popup = Panel.new()
	popup.set_script(CardInfoPopup)
	
	# 添加到场景
	add_child(popup)
	
	# 延迟调用以确保节点已准备好
	popup.call_deferred("show_card", card)
	
	print("📖 弹窗已创建并添加到场景")

## 🌐 处理在线模式技能执行（显示消息）
func _on_online_skill_executed(skill_data: Dictionary):
	if not message_system:
		return
	
	var caster_id = skill_data.get("caster_id", "")
	var caster = BattleManager._find_card_by_id(caster_id)
	if not caster:
		return
	
	var effect_type = skill_data.get("effect_type", "")
	
	# 根据技能类型添加消息
	match effect_type:
		"heal":
			var target_id = skill_data.get("target_id", "")
			var target = BattleManager._find_card_by_id(target_id)
			if target:
				message_system.add_active_skill(caster.card_name, caster.skill_name, 
					"恢复%d点生命值" % skill_data.get("heal_amount", 0))
		"attack_buff":
			message_system.add_active_skill(caster.card_name, caster.skill_name, 
				"攻击力提升%d点" % skill_data.get("buff_amount", 0))
		"crit_buff":
			message_system.add_active_skill(caster.card_name, caster.skill_name, 
				"暴击率提升%.1f%%" % (skill_data.get("new_crit_rate", 0) * 100 - skill_data.get("old_crit_rate", 0) * 100))
		"true_damage_and_armor_reduction":
			var target_id = skill_data.get("target_id", "")
			var target = BattleManager._find_card_by_id(target_id)
			if target:
				message_system.add_active_skill(caster.card_name, caster.skill_name, 
					"减少%d护甲并造成%d真实伤害" % [skill_data.get("armor_reduction", 0), skill_data.get("true_damage", 0)])
		"shield_and_buff":
			var target_id = skill_data.get("target_id", "")
			var target = BattleManager._find_card_by_id(target_id)
			if target:
				message_system.add_active_skill(caster.card_name, caster.skill_name, 
					"提供%d护盾" % skill_data.get("shield_amount", 0))
		"aoe_true_damage":
			message_system.add_active_skill(caster.card_name, caster.skill_name, 
				"造成%d点AOE真实伤害" % skill_data.get("base_damage", 0))
		_:
			message_system.add_active_skill(caster.card_name, caster.skill_name, "技能发动")
	
	print("📝 已添加技能消息: %s - %s" % [caster.card_name, caster.skill_name])

## 重置所有全局状态（遵循规范）
func reset_all_global_states():
	if BattleManager:
		BattleManager.reset_battle()
	if SkillManager:
		SkillManager.initialized = false
	# 清理全局元数据
	if Engine.has_meta("selected_battle_mode"):
		Engine.remove_meta("selected_battle_mode")

## 技能系统相关方法

## 使用当前选中卡牌的技能
func use_player_skill():
	# 首先检查是否有选中的卡牌
	if selected_card and is_instance_valid(selected_card):
		# 使用选中卡牌的技能
		execute_selected_card_skill()
	else:
		# 如果没有选中卡牌，使用默认策略
		use_default_skill()

## 执行选中卡牌的技能
func execute_selected_card_skill():
	var card = selected_card.get_card()
	if not card:
		update_battle_status("卡牌数据无效")
		return
	
	if card.is_dead():
		update_battle_status("卡牌已死亡，无法发动技能")
		return
	
	print("执行选中卡牌技能: %s - %s" % [card.card_name, card.skill_name])
	
	# 统一使用execute_skill方法处理所有技能，包括需要选择目标的技能
	execute_skill(selected_card, null)

## 使用默认技能策略
func use_default_skill():
	# 根据当前回合确定行动的卡牌
	var current_card
	
	if BattleManager.is_player_turn():
		current_card = get_first_alive_player_card()
	else:
		current_card = get_first_alive_enemy_card()
	
	if not current_card or not is_instance_valid(current_card):
		update_battle_status("没有可用的卡牌")
		return
	
	var card = current_card.get_card()
	if not card:
		update_battle_status("卡牌数据无效")
		return
	
	if card.is_dead():
		update_battle_status("卡牌已死亡，无法发动技能")
		return
	
	# 统一使用execute_skill方法处理所有技能，包括需要选择目标的技能
	execute_skill(current_card, null)

## 开始治疗目标选择
func start_healing_target_selection(caster):
	print("开始选择治疗目标...")
	
	# 🔧 先设置选中的施放者和显示取消按钮
	if selected_card:
		selected_card.set_selected(false)
	selected_card = caster
	selected_card.set_selected(true)
	
	# 设置选择模式
	is_selecting_target = true
	is_using_skill = true
	
	# 🎯 立即显示取消技能按钮（不管技能点是否足够）
	var cancel_button = get_cancel_skill_button()
	if cancel_button:
		cancel_button.visible = true
		print("取消技能按钮已显示")
	
	# 检查技能点是否足够（但不消耗）
	var caster_card = caster.get_card()
	var skill_cost = caster_card.skill_cost
	var is_player = caster.is_player()
	
	if not BattleManager.can_use_skill(is_player, skill_cost):
		update_battle_status("技能点不足，无法发动技能 - 请点击取消按钮")
		# ⚠️ 不要重置，让用户手动点击取消按钮
		return
	
	print("朵莉亚技能点检查通过: %s 方有 %d 点技能点" % ["玩家" if is_player else "敌人", skill_cost])
	
	# 根据回合设置可选择的治疗目标
	if BattleManager.is_player_turn():
		# 玩家回合，可以治疗玩家方卡牌
		for entity in player_cards:
			if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
				entity.set_targetable(true)
	else:
		# 敌方回合，可以治疗敌方卡牌
		for entity in enemy_cards:
			if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
				entity.set_targetable(true)
	
	update_battle_status("选择治疗目标 - 点击要治疗的卡牌或点击取消按钮")

## 开始技能目标选择（重构后的统一方法）
func start_target_selection_for_skill(caster):
	print("开始技能目标选择: %s" % caster.get_card().card_name)
	
	# 🔧 先设置选中的施放者和显示取消按钮
	if selected_card:
		selected_card.set_selected(false)
	selected_card = caster
	selected_card.set_selected(true)
	
	# 设置选择模式
	is_selecting_target = true
	is_using_skill = true
	
	# 🎯 立即显示取消技能按钮（不管技能点是否足够）
	var cancel_button = get_cancel_skill_button()
	if cancel_button:
		cancel_button.visible = true
		print("取消技能按钮已显示")
	else:
		print("警告: 找不到取消技能按钮")
	
	# 检查技能点是否足够（但不消耗）
	var caster_card = caster.get_card()
	var skill_cost = caster_card.skill_cost
	var is_player = caster.is_player()
	
	if not BattleManager.can_use_skill(is_player, skill_cost):
		update_battle_status("技能点不足，无法发动技能 - 请点击取消按钮")
		# ⚠️ 不要重置，让用户手动点击取消按钮
		return
	
	print("技能点检查通过: %s 方有足够技能点" % ["玩家" if is_player else "敌人"])
	
	# 根据技能目标类型设置可选择的目标
	var target_type = SkillManager.get_target_type(caster_card.card_name, caster_card.skill_name)
	set_targetable_entities_for_skill(caster, target_type)
	
	# 根据不同的技能类型设置不同的提示信息
	var prompt = ""
	match target_type:
		"ally":
			prompt = "选择友方目标"
		"enemy":
			prompt = "选择敌方目标"
		"self":
			prompt = "选择自己为目标"
		"any":
			prompt = "选择任意目标"
		_:
			prompt = "选择技能目标"
	
	update_battle_status("%s - 点击目标卡牌或点击取消按钮" % prompt)

## 设置技能可选择的实体
func set_targetable_entities_for_skill(caster, target_type: String):
	match target_type:
		"ally":
			# 只能选择同阵营的存活卡牌
			if caster.is_player():
				for entity in player_cards:
					if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
						entity.set_targetable(true)
			else:
				for entity in enemy_cards:
					if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
						entity.set_targetable(true)
		"enemy":
			# 只能选择敌对阵营的存活卡牌
			if caster.is_player():
				for entity in enemy_cards:
					if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
						entity.set_targetable(true)
			else:
				for entity in player_cards:
					if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
						entity.set_targetable(true)
		"self":
			# 只能选择自己
			caster.set_targetable(true)
		"any":
			# 可以选择任意存活卡牌（少司缘的技能）
			for entity in player_cards + enemy_cards:
				if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
					entity.set_targetable(true)
		"all_enemies":
			# 选择所有敌方卡牌（大乔技能）
			if caster.is_player():
				for entity in enemy_cards:
					if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
						entity.set_targetable(true)
			else:
				for entity in player_cards:
					if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
						entity.set_targetable(true)
		_:
			# 默认情况，只能选择敌方卡牌
			if caster.is_player():
				for entity in enemy_cards:
					if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
						entity.set_targetable(true)
			else:
				for entity in player_cards:
					if entity and is_instance_valid(entity) and not entity.get_card().is_dead():
						entity.set_targetable(true)

## 执行技能（重构后的统一方法）
func execute_skill(caster, target = null):
	var card = caster.get_card()
	var skill_name = card.skill_name
	
	print("执行技能: %s 使用 %s" % [card.card_name, skill_name])
	
	# 检查是否需要目标选择
	if SkillManager.requires_target_selection(card.card_name, skill_name) and not target:
		# 需要目标但没有提供，开始目标选择
		start_target_selection_for_skill(caster)
		return
	
	# 🌐 使用BattleManager统一处理技能（支持在线模式）
	var targets = []
	if target:
		targets.append(target.get_card())
	
	var is_player = caster.is_player()
	var result = BattleManager.execute_skill(card, skill_name, targets, is_player)
	
	# 如果是在线模式，服务器会返回结果后由_handle_opponent_skill处理
	if BattleManager.is_online_mode:
		print("🌐 在线模式：技能请求已发送到服务器")
		# 🎯 使用行动点（重要！）
		var should_end = BattleManager.use_action(is_player)
		if should_end:
			print("🎯 行动次数用尽，结束回合")
			call_deferred("end_turn")
		return
	
	if result.success:
		# 显示技能效果
		show_skill_result(caster, result)
		
		# 记录到消息系统
		if message_system:
			var details = {}
			# 检查是否为真实伤害技能，使用专门消息处理
			if result.get("effect_type") == "true_damage" and target:
				details = {
					"base_damage": result.get("original_damage", 0),
					"crit_damage": caster.get_card().crit_damage,
					"is_crit": result.get("is_crit", false)
				}
				message_system.add_true_damage_skill(
					card.card_name,
					target.get_card().card_name,
					skill_name,
					result.get("damage_amount", 0),
					result.get("armor_reduction", 0),
					result.get("is_crit", false),
					details
				)
			elif result.get("effect_type") == "daqiao_true_damage":
				# 大乔的真实伤害技能特殊处理
				message_system.add_daqiao_skill(
					card.card_name,
					skill_name,
					result.get("damage_results", []),
					result.get("total_damage", 0)
				)
			elif result.get("effect_type") == "shaosiyuan_heal" or result.get("effect_type") == "shaosiyuan_damage":
				# 少司缘的技能特殊处理
				message_system.add_shaosiyuan_skill(
					card.card_name,
					skill_name,
					target.get_card().card_name,
					result.get("effect_type", ""),
					result
				)
			elif result.get("effect_type") == "yangyuhuan_damage" or result.get("effect_type") == "yangyuhuan_heal":
				# 杨玉环的技能特殊处理
				message_system.add_yangyuhuan_skill(
					card.card_name,
					skill_name,
					result.get("is_high_health", false),
					result.get("damage_results", result.get("heal_results", [])),
					result.get("total_damage", result.get("total_heal", 0))
				)
			else:
				# 其他技能使用通用消息处理
				match skill_name:
					"鹿灵守心":
						# 使用SkillManager返回的详细信息
						details = {
							"target_name": target.get_card().card_name,
							"base_shield": result.get("base_shield", 150),
							"health_percent": result.get("health_percentage", 8),
							"yao_health": result.get("yao_health", card.health),
							"crit_buff": result.get("crit_buff", 0.05),
							"armor_buff": result.get("armor_buff", 20),
							# 添加目标强化后的属性值
							"target_current_crit_rate": result.get("target_current_crit_rate", 0),
							"target_current_armor": result.get("target_current_armor", 0),
							"target_current_shield": result.get("new_shield", 0),
							"old_crit_rate": result.get("old_crit_rate", 0) * 100, # 转为百分比
							"old_armor": result.get("old_armor", 0),
							"old_shield": result.get("old_shield", 0)
						}
					"人鱼之赐":
						details = {
							"heal_amount": result.get("heal_amount", 0),
							# 添加治疗后的生命值信息
							"target_current_health": target.get_card().health,
							"target_max_health": target.get_card().max_health
						}
					"鲨之猎刃":
						details = {
							"attack_buff": result.get("buff_amount", 0)
						}
					"晚云落":
						details = {
							"crit_rate_buff": result.get("buff_amount", 0)
						}
						if result.get("crit_damage_bonus", 0) > 0:
							details["crit_damage_bonus"] = result.get("crit_damage_bonus", 0)
					"红莲爆弹":
						details = {
							"damage_amount": result.get("damage_amount", 0),
							"armor_reduction": result.get("armor_reduction", 0),
							"is_crit": result.get("is_crit", false)
						}
				
				message_system.add_active_skill(card.card_name, skill_name, get_skill_effect_description(result), details)
				if result.has("heal_amount") and target:
					var heal_details = {
						"heal_amount": result.get("heal_amount", 0)
					}
					message_system.add_heal(card.card_name, target.get_card().card_name, result.heal_amount, heal_details)
		
		print("技能执行完成: %s" % result)
		
		# 🎯 使用行动点（重用前面定义的is_player变量）
		var should_end = BattleManager.use_action(is_player)
		
		# 检查技能是否需要结束回合，或者行动点用尽
		if card.skill_ends_turn or should_end:
			if card.skill_ends_turn:
				print("%s 的技能 %s 标记为结束回合" % [card.card_name, skill_name])
			if should_end:
				print("🎯 行动次数用尽，结束回合")
			# 延迟结束回合，确保所有动画和效果都完成
			call_deferred("end_turn")
	else:
		update_battle_status("技能执行失败: %s" % result.get("error", "未知错误"))
	
	# 重置选择状态
	reset_selection()
	is_using_skill = false

## 执行治疗技能（重构后的版本）
func execute_healing_skill(caster, target):
	var caster_card = caster.get_card()
	var skill_name = caster_card.skill_name
	
	# 使用SkillManager统一处理
	var result = SkillManager.execute_skill(caster, skill_name, target)
	
	if result.success:
		# 显示技能效果
		show_skill_result(caster, result)
		
		# 记录到消息系统
		if message_system:
			message_system.add_active_skill(caster_card.card_name, skill_name, get_skill_effect_description(result))
			message_system.add_heal(caster_card.card_name, target.get_card().card_name, result.get("heal_amount", 0))
		
		print("治疗技能执行完成: %s" % result)
	else:
		update_battle_status("治疗技能执行失败: %s" % result.get("error", "未知错误"))
	
	# 重置选择状态
	reset_selection()
	is_using_skill = false

## 处理ESC键
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_to_menu_pressed()

## 技能点变化处理
func _on_skill_points_changed(player_points: int, enemy_points: int):
	print("技能点更新: 玩家: %d, 敌人: %d" % [player_points, enemy_points])
	
	# 更新技能点显示
	if player_skill_points_label and is_instance_valid(player_skill_points_label):
		player_skill_points_label.text = "我方技能点: %d/6" % player_points
	
	if enemy_skill_points_label and is_instance_valid(enemy_skill_points_label):
		enemy_skill_points_label.text = "敌方技能点: %d/6" % enemy_points
	
	# 更新技能按钮状态
	update_skill_button_state()

## 🎯 行动点变化处理（新增）
func _on_actions_changed(player_actions: int, enemy_actions: int):
	var player_remaining = 3 - player_actions
	var enemy_remaining = 3 - enemy_actions
	print("🎯 [UI更新] 行动点变化: 玩家已用 %d/3 (剩余%d), 敌人已用 %d/3 (剩余%d)" % [
		player_actions, player_remaining, enemy_actions, enemy_remaining
	])
	
	# 更新行动点显示（显示剩余次数更直观）
	if player_actions_label and is_instance_valid(player_actions_label):
		var old_text = player_actions_label.text
		player_actions_label.text = "行动剩余: %d/3" % player_remaining
		print("  → 玩家标签更新: \"%s\" → \"%s\"" % [old_text, player_actions_label.text])
	else:
		print("  ⚠️ 玩家行动点标签无效！")
	
	if enemy_actions_label and is_instance_valid(enemy_actions_label):
		var old_text = enemy_actions_label.text
		enemy_actions_label.text = "敌方剩余: %d/3" % enemy_remaining
		print("  → 敌方标签更新: \"%s\" → \"%s\"" % [old_text, enemy_actions_label.text])
	else:
		print("  ⚠️ 敌方行动点标签无效！")

## 更新技能按钮状态
func update_skill_button_state():
	if not use_skill_button or not is_instance_valid(use_skill_button):
		return
	
	# 🌐 在线模式：检查是否是我的回合
	if BattleManager.is_online_mode:
		var current_turn_num = BattleManager.current_turn
		var is_host_turn = (current_turn_num % 2 == 1)
		var is_my_turn = (NetworkManager.is_host == is_host_turn)
		
		if not is_my_turn:
			use_skill_button.disabled = true
			use_skill_button.text = "对手回合"
			use_skill_button.modulate = Color(0.5, 0.5, 0.5)
			return
	
	# 检查是否有选中的卡牌
	if not selected_card or not is_instance_valid(selected_card):
		use_skill_button.disabled = true
		use_skill_button.text = "发动技能"
		return
	
	var card = selected_card.get_card()
	if not card or card.is_dead():
		use_skill_button.disabled = true
		use_skill_button.text = "发动技能"
		return
	
	# 检查技能点是否足够
	var skill_cost = card.skill_cost
	var can_use = false
	if BattleManager.is_player_turn():
		if selected_card.is_player():
			can_use = BattleManager.can_use_skill(true, skill_cost)
	else:
		if not selected_card.is_player():
			can_use = BattleManager.can_use_skill(false, skill_cost)
	
	# 更新按钮状态
	use_skill_button.disabled = not can_use
	if can_use:
		use_skill_button.text = "发动技能 (%d点)" % skill_cost
		use_skill_button.modulate = Color.WHITE
	else:
		use_skill_button.text = "技能点不足"
		use_skill_button.modulate = Color(0.6, 0.6, 0.6)

## ================== 技能系统重构辅助方法 ==================
## 显示技能效果结果
func show_skill_result(caster, result: Dictionary):
	var caster_card = caster.get_card()
	var effect_type = result.get("effect_type", "")
	var message = ""
	
	match effect_type:
		"heal":
			message = "%s 发动「%s」，为 %s 恢复了 %d 点生命值" % [
				caster_card.card_name, caster_card.skill_name, 
				result.get("target_name", "目标"), result.get("heal_amount", 0)
			]
		"attack_buff":
			message = "%s 发动「%s」，攻击力从 %d 增加到 %d" % [
				caster_card.card_name, caster_card.skill_name,
				result.get("old_attack", 0), result.get("new_attack", 0)
			]
		"crit_buff":
			message = "%s 发动「%s」，暴击率从 %.1f%% 增加到 %.1f%%" % [
				caster_card.card_name, caster_card.skill_name,
				result.get("old_crit_rate", 0) * 100, result.get("new_crit_rate", 0) * 100
			]
		_:
			message = "%s 发动「%s」" % [caster_card.card_name, caster_card.skill_name]
	
	update_last_action(message)

## 获取技能效果描述
func get_skill_effect_description(result: Dictionary) -> String:
	var effect_type = result.get("effect_type", "")
	
	match effect_type:
		"heal":
			return "治疗%d生命值" % result.get("heal_amount", 0)
		"attack_buff":
			return "攻击力+%d" % result.get("buff_amount", 0)
		"crit_buff":
			return "暴击率+%.0f%%" % (result.get("buff_amount", 0) * 100)
		"true_damage":
			# 对于真实伤害技能，返回简单描述，详细消息由专门方法处理
			return "护甲减少%d，真实伤害%d" % [result.get("armor_reduction", 0), result.get("damage_amount", 0)]
		"daqiao_true_damage":
			# 大乔的真实伤害技能
			return "对所有敌方造成真实伤害，总伤害%d" % result.get("total_damage", 0)
		_:
			return "技能效果"

## 初始化技能点显示
func update_initial_skill_points():
	if BattleManager:
		var skill_info = BattleManager.get_skill_points_info()
		_on_skill_points_changed(skill_info.player_points, skill_info.enemy_points)
		
		# 🎯 同时初始化行动点显示
		var action_info = BattleManager.get_action_info()
		_on_actions_changed(action_info.player_used, action_info.enemy_used)

## 更新特定卡牌实体的显示
func update_card_entity_display(card: Card):
	# 查找对应的卡牌实体并更新显示
	for entity in player_cards:
		if entity and is_instance_valid(entity) and entity.get_card() == card:
			entity.update_display()
			print("更新玩家卡牌显示: %s" % card.card_name)
			return
	
	for entity in enemy_cards:
		if entity and is_instance_valid(entity) and entity.get_card() == card:
			entity.update_display()
			print("更新敌方卡牌显示: %s" % card.card_name)
			return

## 销毁特定卡牌实体
func destroy_card_entity(card: Card):
	# 查找并销毁对应的卡牌实体
	for i in range(player_cards.size()):
		var entity = player_cards[i]
		if entity and is_instance_valid(entity) and entity.get_card() == card:
			# 从数组中移除
			player_cards.remove_at(i)
			
			# 触发死亡动画
			if not card.is_dead():
				print("设置卡牌生命值为0: %s" % card.card_name)
				card.health = 0
				entity.take_damage(0)  # 触发死亡动画
			else:
				# 直接播放死亡动画
				entity.call_deferred("play_death_animation")
				# 动画完成后实体会自行发送died信号并被销毁
			
			print("销毁玩家卡牌实体: %s" % card.card_name)
			return
	
	for i in range(enemy_cards.size()):
		var entity = enemy_cards[i]
		if entity and is_instance_valid(entity) and entity.get_card() == card:
			# 从数组中移除
			enemy_cards.remove_at(i)
			
			# 触发死亡动画
			if not card.is_dead():
				print("设置卡牌生命值为0: %s" % card.card_name)
				card.health = 0
				entity.take_damage(0)  # 触发死亡动画
			else:
				# 直接播放死亡动画
				entity.call_deferred("play_death_animation")
				# 动画完成后实体会自行发送died信号并被销毁
			
			print("销毁敌方卡牌实体: %s" % card.card_name)
			return

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
