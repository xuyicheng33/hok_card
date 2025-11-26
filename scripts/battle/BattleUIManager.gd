class_name BattleUIManager
extends RefCounted

## UI布局管理器 - 负责战斗场景的UI创建和自适应布局
## 从BattleScene.gd拆分而来，专注于UI布局逻辑

# 预加载中文字体
var chinese_font = preload("res://assets/fonts/Arial Unicode.ttf")

# 布局参数
var base_resolution := Vector2(1280, 720)  # 基准分辨率
var current_scale_factor: float = 1.0       # 当前缩放因子
var card_base_size := Vector2(150, 200)     # 卡牌基本尺寸
var ui_base_font_size: int = 14             # UI基本字体大小

# 主场景引用
var battle_scene: Control

# UI组件引用
var enemy_card_container: HBoxContainer
var player_card_container: HBoxContainer
var battle_status_label: Label
var turn_info_label: Label
var end_turn_button: Button
var use_skill_button: Button
var cancel_skill_button: Button
var buy_equipment_button: Button
var craft_equipment_button: Button
var back_to_menu_button: Button
var detail_button: Button
var message_system  # 消息系统
var main_battle_area: VBoxContainer
var message_area: VBoxContainer

# 技能点和行动点显示
var player_skill_points_label: Label
var enemy_skill_points_label: Label
var player_actions_label: Label
var enemy_actions_label: Label
var gold_info_label: Label

func _init(scene: Control):
	battle_scene = scene
	print("BattleUIManager 初始化完成")

## 计算缩放因子
func calculate_scale_factor():
	var viewport_size = battle_scene.get_viewport().get_visible_rect().size
	current_scale_factor = min(viewport_size.x / base_resolution.x, viewport_size.y / base_resolution.y)
	current_scale_factor = clamp(current_scale_factor, 0.5, 2.0)
	print("UI缩放因子: %.2f (视口: %s)" % [current_scale_factor, str(viewport_size)])

## 创建完整的UI布局
func create_layout(battle_mode: String):
	print("创建UI布局 (模式: %s)..." % battle_mode)

	# 清理现有子节点
	for child in battle_scene.get_children():
		child.queue_free()

	# 等待清理完成
	await battle_scene.get_tree().process_frame

	# 设置背景
	var background = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.15, 1.0)
	battle_scene.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 主容器（水平分割）
	var main_container = HBoxContainer.new()
	background.add_child(main_container)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var base_separation = 5
	var scaled_separation = int(base_separation * current_scale_factor)
	main_container.add_theme_constant_override("separation", scaled_separation)

	# 左侧战斗区域
	main_battle_area = VBoxContainer.new()
	main_battle_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_battle_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_battle_area.add_theme_constant_override("separation", scaled_separation)
	main_container.add_child(main_battle_area)

	# 右侧消息区域
	message_area = VBoxContainer.new()
	var message_width = int(320 * current_scale_factor)
	message_width = clamp(message_width, 250, 400)
	message_area.custom_minimum_size = Vector2(message_width, 0)
	message_area.size_flags_horizontal = Control.SIZE_SHRINK_END
	main_container.add_child(message_area)

	# 创建战斗区域内容
	create_battle_area_content(battle_mode)

	# 创建消息区域内容
	create_message_area_content()

	print("UI布局创建完成")

## 创建战斗区域内容
func create_battle_area_content(battle_mode: String):
	var viewport_size = battle_scene.get_viewport().get_visible_rect().size
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080
	var is_high_resolution = viewport_size.y >= 900

	# 获取卡牌区域高度和间距
	var area_height = get_card_area_height_for_mode(battle_mode)
	area_height = int(area_height * current_scale_factor)

	var min_height = 180 if is_full_hd else (280 if is_high_resolution else 200)
	var max_height = 250 if is_full_hd else (460 if is_high_resolution else 400)
	area_height = clamp(area_height, min_height, max_height)

	var card_spacing = get_card_spacing_for_mode(battle_mode)
	card_spacing = int(card_spacing * current_scale_factor)

	var min_spacing = 50 if is_full_hd else (60 if is_high_resolution else 40)
	var max_spacing = 250 if is_full_hd else (280 if is_high_resolution else 200)
	card_spacing = clamp(card_spacing, min_spacing, max_spacing)

	# 顶部区域
	var top_section = VBoxContainer.new()
	top_section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_battle_area.add_child(top_section)

	# 中间战斗区域
	var middle_section = VBoxContainer.new()
	middle_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_section.alignment = BoxContainer.ALIGNMENT_CENTER
	main_battle_area.add_child(middle_section)

	var battle_grid = GridContainer.new()
	battle_grid.columns = 1
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

	# 中间分隔区域
	var separator_area = VBoxContainer.new()
	separator_area.custom_minimum_size = Vector2(0, 24)
	separator_area.add_theme_constant_override("separation", 2)
	separator_area.alignment = BoxContainer.ALIGNMENT_CENTER
	separator_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_grid.add_child(separator_area)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 1)
	separator_area.add_child(spacer1)

	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 1)
	separator_area.add_child(separator)

	var vs_label = Label.new()
	vs_label.text = "VS"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.add_theme_font_override("font", chinese_font)
	vs_label.add_theme_font_size_override("font_size", 18)
	vs_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	separator_area.add_child(vs_label)

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

	# 底部区域
	var bottom_section = VBoxContainer.new()
	bottom_section.size_flags_vertical = Control.SIZE_SHRINK_END
	main_battle_area.add_child(bottom_section)

	# 创建顶部信息区
	create_top_info_section(top_section, battle_mode)

	# 创建底部控制区
	create_bottom_controls_section(bottom_section)

## 创建顶部信息区
func create_top_info_section(parent: VBoxContainer, battle_mode: String):
	# 模式显示标签
	var mode_info_label = Label.new()
	mode_info_label.text = "当前模式: %s" % battle_mode.to_upper()
	mode_info_label.add_theme_font_override("font", chinese_font)
	mode_info_label.add_theme_font_size_override("font_size", 18)
	mode_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_info_label.add_theme_color_override("font_color", get_theme_color_for_mode(battle_mode))
	parent.add_child(mode_info_label)

	var spacer_top = Control.new()
	var spacer_height = int(5 * current_scale_factor)
	spacer_top.custom_minimum_size = Vector2(0, spacer_height)
	parent.add_child(spacer_top)

	# 顶部信息栏
	var top_info = HBoxContainer.new()
	var info_height = int(30 * current_scale_factor)
	top_info.custom_minimum_size = Vector2(0, info_height)
	parent.add_child(top_info)

	# 回合信息标签
	turn_info_label = Label.new()
	turn_info_label.text = "第 1 回合 - 玩家回合"
	turn_info_label.add_theme_font_override("font", chinese_font)
	turn_info_label.add_theme_font_size_override("font_size", 20)
	top_info.add_child(turn_info_label)

	# 技能点和行动点显示
	var skill_points_container = VBoxContainer.new()
	skill_points_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_points_container.add_theme_constant_override("separation", 5)
	top_info.add_child(skill_points_container)

	enemy_skill_points_label = Label.new()
	enemy_skill_points_label.text = "敌方技能点: 4/6"
	enemy_skill_points_label.add_theme_font_override("font", chinese_font)
	enemy_skill_points_label.add_theme_font_size_override("font_size", 16)
	enemy_skill_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_skill_points_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	skill_points_container.add_child(enemy_skill_points_label)

	player_skill_points_label = Label.new()
	player_skill_points_label.text = "我方技能点: 4/6"
	player_skill_points_label.add_theme_font_override("font", chinese_font)
	player_skill_points_label.add_theme_font_size_override("font_size", 16)
	player_skill_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_skill_points_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	skill_points_container.add_child(player_skill_points_label)

	# 行动点显示
	player_actions_label = Label.new()
	player_actions_label.text = "行动剩余: 3/3"
	player_actions_label.add_theme_font_override("font", chinese_font)
	player_actions_label.add_theme_font_size_override("font_size", 16)
	player_actions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_actions_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	skill_points_container.add_child(player_actions_label)

	enemy_actions_label = Label.new()
	enemy_actions_label.text = "敌方剩余: 3/3"
	enemy_actions_label.add_theme_font_override("font", chinese_font)
	enemy_actions_label.add_theme_font_size_override("font_size", 16)
	enemy_actions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_actions_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	skill_points_container.add_child(enemy_actions_label)

	# 金币显示
	gold_info_label = Label.new()
	gold_info_label.text = "💰 我方: 10 | 敌方: 10"
	gold_info_label.add_theme_font_override("font", chinese_font)
	gold_info_label.add_theme_font_size_override("font_size", 16)
	gold_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_info_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	skill_points_container.add_child(gold_info_label)

	# 战斗状态标签
	battle_status_label = Label.new()
	battle_status_label.text = "选择攻击或发动技能"
	battle_status_label.add_theme_font_override("font", chinese_font)
	battle_status_label.add_theme_font_size_override("font_size", 16)
	battle_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_info.add_child(battle_status_label)

## 创建底部控制区
func create_bottom_controls_section(parent: VBoxContainer):
	var viewport_size = battle_scene.get_viewport().get_visible_rect().size
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080

	var bottom_controls = HBoxContainer.new()
	var bottom_height = 48 if is_full_hd else 52
	bottom_controls.custom_minimum_size = Vector2(0, bottom_height)

	var bottom_margin = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_bottom", 10 if is_full_hd else 10)
	bottom_margin.add_child(bottom_controls)
	parent.add_child(bottom_margin)

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

	cancel_skill_button = Button.new()
	cancel_skill_button.text = "取消技能"
	cancel_skill_button.custom_minimum_size = Vector2(120, 48)
	cancel_skill_button.visible = false
	cancel_skill_button.name = "CancelSkillButton"
	left_buttons.add_child(cancel_skill_button)

	buy_equipment_button = Button.new()
	buy_equipment_button.text = "💰购买装备(15)"
	buy_equipment_button.custom_minimum_size = Vector2(140, 48)
	buy_equipment_button.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	left_buttons.add_child(buy_equipment_button)

	craft_equipment_button = Button.new()
	craft_equipment_button.text = "🔨合成装备(10)"
	craft_equipment_button.custom_minimum_size = Vector2(140, 48)
	craft_equipment_button.add_theme_color_override("font_color", Color(1.0, 0.65, 0.0))
	left_buttons.add_child(craft_equipment_button)

	# 右侧按钮组
	var right_buttons = HBoxContainer.new()
	right_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_buttons.alignment = BoxContainer.ALIGNMENT_END
	bottom_controls.add_child(right_buttons)

	detail_button = Button.new()
	detail_button.text = "详情"
	detail_button.custom_minimum_size = Vector2(120, 48)
	right_buttons.add_child(detail_button)

	back_to_menu_button = Button.new()
	back_to_menu_button.text = "返回主菜单"
	back_to_menu_button.custom_minimum_size = Vector2(120, 48)
	right_buttons.add_child(back_to_menu_button)

## 创建消息区域内容
func create_message_area_content():
	var message_title = Label.new()
	message_title.text = "战斗记录"
	message_title.add_theme_font_override("font", chinese_font)
	message_title.add_theme_font_size_override("font_size", 16)
	message_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_area.add_child(message_title)

	var message_script = load("res://scripts/battle/BattleMessageSystem.gd")
	if message_script:
		message_system = message_script.new()
		message_system.size_flags_vertical = Control.SIZE_EXPAND_FILL
		message_system.add_theme_font_size_override("font_size", 14)
		message_area.add_child(message_system)
	else:
		print("❌ 无法加载 BattleMessageSystem 脚本")

## 更新布局以适应新尺寸
func update_layout_for_new_size(battle_mode: String):
	print("更新UI布局 (缩放: %.2f)" % current_scale_factor)

	if message_area:
		var message_width = int(320 * current_scale_factor)
		message_width = clamp(message_width, 280, 400)
		message_area.custom_minimum_size = Vector2(message_width, 0)

	update_font_sizes()
	update_button_sizes()
	update_card_area_layout(battle_mode)

## 更新字体大小
func update_font_sizes():
	if turn_info_label:
		var title_font_size = clamp(int(18 * current_scale_factor), 14, 24)
		turn_info_label.add_theme_font_size_override("font_size", title_font_size)

	if battle_status_label:
		var status_font_size = clamp(int(16 * current_scale_factor), 12, 20)
		battle_status_label.add_theme_font_size_override("font_size", status_font_size)

	if player_skill_points_label and enemy_skill_points_label:
		var skill_font_size = clamp(int(16 * current_scale_factor), 14, 20)
		player_skill_points_label.add_theme_font_size_override("font_size", skill_font_size)
		enemy_skill_points_label.add_theme_font_size_override("font_size", skill_font_size)

	if message_system:
		var message_font_size = clamp(int(14 * current_scale_factor), 12, 18)
		message_system.add_theme_font_size_override("font_size", message_font_size)

## 更新按钮尺寸
func update_button_sizes():
	var viewport_size = battle_scene.get_viewport().get_visible_rect().size
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080

	var button_width = int(100 * current_scale_factor)
	var button_height = int(40 * current_scale_factor)

	if is_full_hd:
		button_width = 100
		button_height = 40
	else:
		button_width = clamp(button_width, 80, 150)
		button_height = clamp(button_height, 30, 60)

	var buttons = [end_turn_button, use_skill_button, back_to_menu_button, detail_button, cancel_skill_button]
	for btn in buttons:
		if btn and is_instance_valid(btn):
			btn.custom_minimum_size = Vector2(button_width, button_height)

## 更新卡牌区域布局
func update_card_area_layout(battle_mode: String):
	var viewport_size = battle_scene.get_viewport().get_visible_rect().size
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080
	var is_high_resolution = viewport_size.y >= 900

	var area_height = get_card_area_height_for_mode(battle_mode)
	area_height = int(area_height * current_scale_factor)

	var min_height = 180 if is_full_hd else (280 if is_high_resolution else 200)
	var max_height = 250 if is_full_hd else (460 if is_high_resolution else 400)
	area_height = clamp(area_height, min_height, max_height)

	var card_spacing = get_card_spacing_for_mode(battle_mode)
	card_spacing = int(card_spacing * current_scale_factor)

	var min_spacing = 50 if is_full_hd else (60 if is_high_resolution else 40)
	var max_spacing = 250 if is_full_hd else (280 if is_high_resolution else 200)
	card_spacing = clamp(card_spacing, min_spacing, max_spacing)

	if enemy_card_container and is_instance_valid(enemy_card_container):
		var enemy_area = enemy_card_container.get_parent()
		if enemy_area and is_instance_valid(enemy_area) and enemy_area is Control:
			enemy_area.custom_minimum_size.y = area_height
		enemy_card_container.add_theme_constant_override("separation", card_spacing)

	if player_card_container and is_instance_valid(player_card_container):
		var player_area = player_card_container.get_parent()
		if player_area and is_instance_valid(player_area) and player_area is Control:
			player_area.custom_minimum_size.y = area_height
		player_card_container.add_theme_constant_override("separation", card_spacing)

## 更新状态标签
func update_battle_status(message: String):
	if battle_status_label and is_instance_valid(battle_status_label):
		battle_status_label.text = message

## 更新回合信息
func update_turn_info(turn: int, is_player: bool):
	if turn_info_label and is_instance_valid(turn_info_label):
		var turn_text = "回合 %d - %s回合" % [turn, "玩家" if is_player else "敌人"]
		turn_info_label.text = turn_text

## 根据模式获取主题颜色
func get_theme_color_for_mode(battle_mode: String) -> Color:
	var mode_type = battle_mode.replace("online_", "")
	match mode_type:
		"1v1":
			return Color(1.0, 0.8, 0.2)  # 金色
		"2v2":
			return Color(0.2, 0.8, 1.0)  # 蓝色
		"3v3":
			return Color(1.0, 0.4, 0.8)  # 紫红色
		_:
			return Color(0.2, 0.8, 1.0)  # 默认蓝色

## 根据模式获取卡牌区域高度
func get_card_area_height_for_mode(battle_mode: String) -> int:
	var viewport_size = battle_scene.get_viewport().get_visible_rect().size
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080
	var is_high_resolution = viewport_size.y >= 900

	var mode_type = battle_mode.replace("online_", "")

	match mode_type:
		"1v1":
			return 185 if is_full_hd else (230 if is_high_resolution else 220)
		"2v2", "2v2_custom":
			return 185 if is_full_hd else (215 if is_high_resolution else 185)
		"3v3":
			return 185 if is_full_hd else (200 if is_high_resolution else 170)
		_:
			return 185 if is_full_hd else (215 if is_high_resolution else 185)

## 根据模式获取卡牌间距
func get_card_spacing_for_mode(battle_mode: String) -> int:
	var viewport_size = battle_scene.get_viewport().get_visible_rect().size
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080
	var is_high_resolution = viewport_size.x >= 1600

	var mode_type = battle_mode.replace("online_", "")

	match mode_type:
		"1v1":
			return 100 if is_full_hd else (200 if is_high_resolution else 150)
		"2v2", "2v2_custom":
			return 80 if is_full_hd else (150 if is_high_resolution else 100)
		"3v3":
			return 60 if is_full_hd else (120 if is_high_resolution else 80)
		_:
			return 80 if is_full_hd else (150 if is_high_resolution else 100)
