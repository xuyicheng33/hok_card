class_name AllCardsDetailPopup
extends Control

## 所有卡牌详情弹窗
## 显示战场上所有卡牌的详细属性信息

@onready var popup_panel: Panel = $PopupPanel
@onready var close_button: Button = $PopupPanel/CloseButton
@onready var cards_container: HBoxContainer = $PopupPanel/Content/CardsContainer

## 设置所有卡牌详情并显示弹窗
func setup_details(player_entities: Array, enemy_entities: Array):
	# 等待节点准备就绪
	if not is_node_ready():
		await ready
	
	# 清空现有内容
	for child in cards_container.get_children():
		child.queue_free()
	
	print("设置卡牌详情弹窗 - 玩家卡牌数量: %d, 敌方卡牌数量: %d" % [player_entities.size(), enemy_entities.size()])
	
	# 添加玩家卡牌详情
	for entity in player_entities:
		if entity and entity.card_data:
			print("处理玩家卡牌: %s" % entity.card_data.card_name)
			if entity.card_data.card_image:
				print("  图片存在: %s" % str(entity.card_data.card_image))
			else:
				print("  图片不存在")
			var card_detail = create_card_detail(entity.card_data, true)
			cards_container.add_child(card_detail)
		else:
			print("跳过无效的玩家实体")
	
	# 添加敌方卡牌详情
	for entity in enemy_entities:
		if entity and entity.card_data:
			print("处理敌方卡牌: %s" % entity.card_data.card_name)
			if entity.card_data.card_image:
				print("  图片存在: %s" % str(entity.card_data.card_image))
			else:
				print("  图片不存在")
			var card_detail = create_card_detail(entity.card_data, false)
			cards_container.add_child(card_detail)
		else:
			print("跳过无效的敌方实体")
	
	# 显示弹窗动画
	show_popup()

## 创建单个卡牌详情组件
func create_card_detail(card: Card, is_player: bool) -> Panel:
	print("创建卡牌详情组件: %s (玩家: %s)" % [card.card_name, str(is_player)])
	if card.card_image:
		print("  卡牌图片存在: %s" % str(card.card_image))
	else:
		print("  卡牌图片不存在")
	
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(180, 220)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 设置面板样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.2, 0.8, 1.0, 0.8) if is_player else Color(1.0, 0.4, 0.4, 0.8)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style_box)
	
	# 创建内容容器
	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("separation", 3)
	panel.add_child(container)
	
	# 卡牌名称
	var name_label = Label.new()
	name_label.text = card.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	container.add_child(name_label)
	
	# 卡牌图片
	var texture_rect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(80, 80)
	texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# 设置卡牌图片
	if card.card_image:
		texture_rect.texture = card.card_image
		print("  已设置纹理: %s" % str(card.card_image))
	else:
		# 如果没有图片，显示占位符文本
		texture_rect.hide()
		var placeholder_label = Label.new()
		placeholder_label.text = "无图片"
		placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		placeholder_label.custom_minimum_size = Vector2(80, 80)
		placeholder_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(placeholder_label)
		print("  显示占位符文本")
	
	container.add_child(texture_rect)
	
	# 分隔线
	var separator = HSeparator.new()
	container.add_child(separator)
	
	# 属性网格
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("separation", 2)
	stats_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(stats_grid)
	
	# 攻击力
	var attack_label = Label.new()
	attack_label.text = "攻击:"
	attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	attack_label.add_theme_font_size_override("font_size", 12)
	stats_grid.add_child(attack_label)
	
	var attack_value = Label.new()
	attack_value.text = str(card.attack)
	attack_value.add_theme_font_size_override("font_size", 12)
	attack_value.add_theme_color_override("font_color", Color(1, 0.5, 0.5, 1))
	stats_grid.add_child(attack_value)
	
	# 生命值
	var health_label = Label.new()
	health_label.text = "生命:"
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_label.add_theme_font_size_override("font_size", 12)
	stats_grid.add_child(health_label)
	
	var health_value = Label.new()
	health_value.text = str(card.health) + "/" + str(card.max_health)
	health_value.add_theme_font_size_override("font_size", 12)
	health_value.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))
	stats_grid.add_child(health_value)
	
	# 护甲
	var armor_label = Label.new()
	armor_label.text = "护甲:"
	armor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	armor_label.add_theme_font_size_override("font_size", 12)
	stats_grid.add_child(armor_label)
	
	var armor_value = Label.new()
	armor_value.text = str(card.armor)
	armor_value.add_theme_font_size_override("font_size", 12)
	armor_value.add_theme_color_override("font_color", Color(0.7, 0.7, 1, 1))
	stats_grid.add_child(armor_value)
	
	# 护盾
	var shield_label = Label.new()
	shield_label.text = "护盾:"
	shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shield_label.add_theme_font_size_override("font_size", 12)
	stats_grid.add_child(shield_label)
	
	var shield_value = Label.new()
	shield_value.text = str(card.shield)
	shield_value.add_theme_font_size_override("font_size", 12)
	shield_value.add_theme_color_override("font_color", Color(0.5, 0.8, 1, 1))
	stats_grid.add_child(shield_value)
	
	# 暴击率
	var crit_rate_label = Label.new()
	crit_rate_label.text = "暴击:"
	crit_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crit_rate_label.add_theme_font_size_override("font_size", 12)
	stats_grid.add_child(crit_rate_label)
	
	var crit_rate_value = Label.new()
	crit_rate_value.text = "%.0f%%" % (card.crit_rate * 100)
	crit_rate_value.add_theme_font_size_override("font_size", 12)
	crit_rate_value.add_theme_color_override("font_color", Color(1, 1, 0.5, 1))
	stats_grid.add_child(crit_rate_value)
	
	# 暴击效果
	var crit_damage_label = Label.new()
	crit_damage_label.text = "暴伤:"
	crit_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crit_damage_label.add_theme_font_size_override("font_size", 12)
	stats_grid.add_child(crit_damage_label)
	
	var crit_damage_value = Label.new()
	crit_damage_value.text = "%.0f%%" % (card.crit_damage * 100)
	crit_damage_value.add_theme_font_size_override("font_size", 12)
	crit_damage_value.add_theme_color_override("font_color", Color(1, 1, 0.5, 1))
	stats_grid.add_child(crit_damage_value)
	
	# 增伤值
	var damage_bonus_label = Label.new()
	damage_bonus_label.text = "增伤:"
	damage_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	damage_bonus_label.add_theme_font_size_override("font_size", 12)
	stats_grid.add_child(damage_bonus_label)
	
	var damage_bonus_value = Label.new()
	damage_bonus_value.text = "%.0f%%" % (card.damage_bonus * 100)
	damage_bonus_value.add_theme_font_size_override("font_size", 12)
	damage_bonus_value.add_theme_color_override("font_color", Color(1, 0.8, 0.5, 1))
	stats_grid.add_child(damage_bonus_value)
	
	# 闪避率（仅公孙离有）
	var dodge_rate_label = Label.new()
	dodge_rate_label.text = "闪避:"
	dodge_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dodge_rate_label.add_theme_font_size_override("font_size", 12)
	stats_grid.add_child(dodge_rate_label)
	
	var dodge_rate_value = Label.new()
	if card.card_name == "公孙离":
		dodge_rate_value.text = "%.0f%%" % (card.get_gongsunli_dodge_rate() * 100)
	else:
		dodge_rate_value.text = "0%"
	dodge_rate_value.add_theme_font_size_override("font_size", 12)
	dodge_rate_value.add_theme_color_override("font_color", Color(0.5, 1, 1, 1))
	stats_grid.add_child(dodge_rate_value)
	
	# 被动技能标题和效果
	if card.passive_skill_name != "" or card.passive_skill_effect != "":
		var passive_separator = HSeparator.new()
		container.add_child(passive_separator)
		
		# 显示被动技能名称（如果存在）
		if card.passive_skill_name != "":
			var passive_name_label = Label.new()
			passive_name_label.text = "被动: " + card.passive_skill_name
			passive_name_label.add_theme_font_size_override("font_size", 12)
			passive_name_label.add_theme_color_override("font_color", Color(0.8, 1, 0.8, 1))
			passive_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			container.add_child(passive_name_label)
		
		# 显示被动技能效果（如果存在）
		if card.passive_skill_effect != "":
			var passive_effect_label = Label.new()
			passive_effect_label.text = card.passive_skill_effect
			passive_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			passive_effect_label.add_theme_font_size_override("font_size", 10)
			passive_effect_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
			passive_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			container.add_child(passive_effect_label)
	
	# 主动技能标题和效果
	if card.skill_name != "" or card.skill_effect != "":
		var skill_separator = HSeparator.new()
		container.add_child(skill_separator)
		
		# 显示主动技能名称（如果存在）
		if card.skill_name != "":
			var skill_name_label = Label.new()
			skill_name_label.text = "技能: " + card.skill_name
			skill_name_label.add_theme_font_size_override("font_size", 12)
			skill_name_label.add_theme_color_override("font_color", Color(1, 1, 0.8, 1))
			skill_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			container.add_child(skill_name_label)
		
		# 显示主动技能效果（如果存在）
		if card.skill_effect != "":
			var skill_effect_label = Label.new()
			skill_effect_label.text = card.skill_effect
			skill_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			skill_effect_label.add_theme_font_size_override("font_size", 10)
			skill_effect_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
			skill_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			container.add_child(skill_effect_label)
	
	return panel

## 显示弹窗动画
func show_popup():
	# 设置初始状态
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	# 播放出现动画
	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_callback(_on_popup_shown)

## 弹窗显示完成
func _on_popup_shown():
	# 连接关闭按钮信号
	if close_button and not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

## 关闭按钮点击事件
func _on_close_button_pressed():
	close_popup()

## 关闭弹窗
func close_popup():
	# 播放消失动画
	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.2)
	tween.tween_callback(queue_free)

## 处理点击背景关闭
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 检查是否点击在弹窗面板外
			var local_pos = popup_panel.global_transform.affine_inverse() * event.global_position
			if not popup_panel.get_rect().has_point(local_pos):
				close_popup()
	elif event is InputEventScreenTouch:
		if event.pressed:
			# 检查是否点击在弹窗面板外
			var local_pos = popup_panel.global_transform.affine_inverse() * event.position
			if not popup_panel.get_rect().has_point(local_pos):
				close_popup()

## 处理键盘输入（ESC关闭）
func _unhandled_input(event):
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			close_popup()

func _ready():
	# 设置全屏覆盖
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)