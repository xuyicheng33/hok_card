class_name UIAdaptationHelper
extends Node

## UI自适应布局辅助类
## 提供窗口大小变化处理和自适应布局功能

# 布局参数
var base_resolution := Vector2(1280, 720)  # 基准分辨率
var current_scale_factor: float = 1.0       # 当前缩放因子

## 计算缩放因子
func calculate_scale_factor(viewport_size: Vector2) -> float:
	var scale_factor = min(viewport_size.x / base_resolution.x, viewport_size.y / base_resolution.y)
	# 限制缩放范围，避免过小或过大
	scale_factor = clamp(scale_factor, 0.5, 2.0)
	return scale_factor

## 更新消息区域布局
func update_message_area_layout(message_area, scale_factor: float):
	if message_area:
		var message_width = int(320 * scale_factor)
		message_width = clamp(message_width, 250, 400)
		message_area.custom_minimum_size = Vector2(message_width, 0)

## 更新字体大小
func update_font_sizes(turn_info_label, battle_status_label, player_skill_points_label, enemy_skill_points_label, scale_factor: float):
	# 更新顶部信息区域的字体大小
	if turn_info_label:
		var title_font_size = int(16 * scale_factor)
		title_font_size = clamp(title_font_size, 12, 22)
		turn_info_label.add_theme_font_size_override("font_size", title_font_size)
	
	if battle_status_label:
		var status_font_size = int(14 * scale_factor)
		status_font_size = clamp(status_font_size, 10, 18)
		battle_status_label.add_theme_font_size_override("font_size", status_font_size)
	
	# 更新技能点标签字体大小
	if player_skill_points_label:
		var skill_font_size = int(14 * scale_factor)
		skill_font_size = clamp(skill_font_size, 10, 16)
		player_skill_points_label.add_theme_font_size_override("font_size", skill_font_size)
	
	if enemy_skill_points_label:
		var skill_font_size = int(14 * scale_factor)
		skill_font_size = clamp(skill_font_size, 10, 16)
		enemy_skill_points_label.add_theme_font_size_override("font_size", skill_font_size)

## 更新按钮尺寸
func update_button_sizes(end_turn_button, use_skill_button, back_to_menu_button, get_cancel_skill_button_func, scale_factor: float):
	# 计算自适应按钮尺寸
	var button_width = int(100 * scale_factor)
	var button_height = int(40 * scale_factor)
	button_width = clamp(button_width, 80, 150)
	button_height = clamp(button_height, 30, 60)
	
	if end_turn_button:
		end_turn_button.custom_minimum_size = Vector2(button_width, button_height)
	
	if use_skill_button:
		use_skill_button.custom_minimum_size = Vector2(button_width, button_height)
	
	if back_to_menu_button:
		back_to_menu_button.custom_minimum_size = Vector2(button_width, button_height)
	
	# 更新取消技能按钮
	var cancel_button = get_cancel_skill_button_func.call()
	if cancel_button:
		cancel_button.custom_minimum_size = Vector2(button_width, button_height)

## 更新卡牌区域布局
func update_card_area_layout(enemy_card_container, player_card_container, get_card_area_height_for_mode_func, get_card_spacing_for_mode_func, scale_factor: float):
	# 根据战斗模式和缩放因子调整卡牌区域高度
	var area_height = get_card_area_height_for_mode_func.call()
	area_height = int(area_height * scale_factor)
	area_height = clamp(area_height, 200, 400)
	
	# 更新卡牌间距
	var card_spacing = get_card_spacing_for_mode_func.call()
	card_spacing = int(card_spacing * scale_factor)
	card_spacing = clamp(card_spacing, 40, 200)
	
	# 更新敌人卡牌区域
	if enemy_card_container:
		enemy_card_container.add_theme_constant_override("separation", card_spacing)
	
	# 更新玩家卡牌区域
	if player_card_container:
		player_card_container.add_theme_constant_override("separation", card_spacing)
