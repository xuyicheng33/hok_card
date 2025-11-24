class_name BattleEntity
extends Control

## 战斗实体类
## 在战斗场景中表示一张卡牌的UI和逻辑

# 预加载中文字体
var chinese_font = preload("res://assets/fonts/Arial Unicode.ttf")

# 卡牌数据
var card_data

# UI组件引用
var card_ui
var health_bar
var health_label  # 生命值标签
var attack_label
var armor_label  
var shield_label
var status_container
var equipment_container  # 🎒 装备图标容器

# 战斗状态
var is_player_card: bool = true
var is_selected: bool = false
var is_targetable: bool = true
var is_attacking: bool = false

# 位置和动画
var original_position
var original_scale

# 信号
signal card_clicked(entity)
signal card_hovered(entity)
signal card_unhovered(entity)
signal health_changed(entity, old_health, new_health)
signal died(entity)

func _ready():
	print("战斗实体初始化: %s" % (card_data.card_name if card_data else "未知"))
	
	# 设置基础属性
	# 根据分辨率适应卡牌尺寸
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_factor = min(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	scale_factor = clamp(scale_factor, 0.7, 2.0)  # 限制缩放范围
	
	# 高分辨率下设置更小的卡牌尺寸
	var is_high_resolution = viewport_size.y >= 900
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080
	
	# 根据分辨率设置基础尺寸
	var base_width = 0
	var base_height = 0
	
	if is_full_hd:
		# 1920*1080分辨率下设置更美观的卡牌尺寸，与卡牌展示界面保持一致的比例
		base_width = 120  # 比之前的95稍大一些
		base_height = 183  # 比之前的145稍大一些
	elif is_high_resolution:
		base_width = 120  # 比之前的95稍大一些
		base_height = 183  # 比之前的145稍大一些
	else:
		base_width = 120  # 比之前的95稍大一些
		base_height = 183  # 比之前的145稍大一些
	
	# 计算适应后的尺寸
	var adapted_width = int(base_width * scale_factor)
	var adapted_height = int(base_height * scale_factor)
	
	# 应用尺寸
	custom_minimum_size = Vector2(adapted_width, adapted_height)
	
	# 延迟初始化，确保节点准备就绪
	call_deferred("setup_ui")

## 初始化UI组件
func setup_ui():
	print("设置战斗实体UI: %s" % (card_data.card_name if card_data else "未知"))
	
	# 安全性检查
	if not card_data:
		print("错误: 卡牌数据为空")
		return
	
	# 创建主容器
	var main_container = VBoxContainer.new()
	add_child(main_container)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 创建简单的卡牌显示
	create_simple_card_ui(main_container)
	
	# 创建战斗信息UI
	create_battle_info_ui(main_container)
	
	# 设置交互
	setup_interactions()
	
	# 延迟更多帧来存储原始位置，确保布局完成
	call_deferred("_wait_for_layout_then_store_position")
	
	# 更新显示
	update_display()

## 创建卡牌面板样式
func create_card_panel_style():
	var style_box = StyleBoxFlat.new()
	
	# 基础设置
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.3)  # 淡色半透明背景，让图片更突出
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	# 边框设置
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	
	# 根据阵营设置不同的边框颜色
	if is_player_card:
		style_box.border_color = Color(0.2, 0.8, 1.0, 0.8)  # 蓝色边框（玩家）
	else:
		style_box.border_color = Color(1.0, 0.4, 0.4, 0.8)  # 红色边框（敌人）
	
	# 移除内边距，让图片能够铺满整个卡牌
	style_box.content_margin_left = 0
	style_box.content_margin_top = 0
	style_box.content_margin_right = 0
	style_box.content_margin_bottom = 0
	
	return style_box

## 创建简单的卡牌UI
func create_simple_card_ui(parent):
	print("创建卡牌UI，图片铺满卡牌面板")
	
	# 计算当前缩放因子
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_factor = min(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	scale_factor = clamp(scale_factor, 0.7, 2.0)  # 限制缩放范围
	
	# 检测分辨率
	var is_high_resolution = viewport_size.y >= 900
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080
	
	# 根据分辨率设置卡牌面板尺寸
	var panel_base_width = 0
	var panel_base_height = 0
	
	if is_full_hd:
		# 1920*1080分辨率下设置更美观的卡牌面板，与卡牌展示界面保持一致的比例
		panel_base_width = 120  # 比之前的95稍大一些
		panel_base_height = 183  # 比之前的145稍大一些
	elif is_high_resolution:
		panel_base_width = 120  # 比之前的95稍大一些
		panel_base_height = 183  # 比之前的145稍大一些
	else:
		panel_base_width = 120  # 比之前的95稍大一些
		panel_base_height = 183  # 比之前的145稍大一些
	
	# 计算适应后的尺寸
	var panel_width = int(panel_base_width * scale_factor)
	var panel_height = int(panel_base_height * scale_factor)
	
	var card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	# 添加边框效果以增强视觉效果
	card_panel.add_theme_stylebox_override("panel", create_card_panel_style())
	parent.add_child(card_panel)
	
	# 创建图片容器，铺满整个卡牌面板
	if card_data.card_image:
		# 创建一个容器来包裹图片，实现圆角效果
		var image_container = Control.new()
		image_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image_container.clip_contents = true  # 启用裁剪
		card_panel.add_child(image_container)
		
		var image_rect = TextureRect.new()
		image_rect.texture = card_data.card_image
		# 设置图片铺满整个容器
		image_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 保持比例，裁剪超出部分
		image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		image_container.add_child(image_rect)
		print("卡牌图片铺满面板设置成功: %s" % card_data.card_name)
		
		# 在图片上添加半透明的名称覆盖层
		var name_overlay = Panel.new()
		# 使用相对定位，让覆盖层始终在卡牌底部
		name_overlay.anchor_left = 0.0
		name_overlay.anchor_right = 1.0
		name_overlay.anchor_top = 0.75  # 从卡牌75%的位置开始
		name_overlay.anchor_bottom = 1.0
		name_overlay.offset_left = 0
		name_overlay.offset_right = 0
		name_overlay.offset_top = 0
		name_overlay.offset_bottom = 0
		# 创建半透明背景
		var overlay_style = StyleBoxFlat.new()
		overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.7)  # 加深半透明黑色
		# 添加圆角设计
		overlay_style.corner_radius_bottom_left = 6
		overlay_style.corner_radius_bottom_right = 6
		name_overlay.add_theme_stylebox_override("panel", overlay_style)
		image_container.add_child(name_overlay)
		
		# 卡牌名称标签
		var name_label = Label.new()
		name_label.text = card_data.card_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", chinese_font)
		name_label.add_theme_font_size_override("font_size", 18)  # 增大字体使更美观
		name_label.add_theme_color_override("font_color", Color.WHITE)
		# 添加阴影效果提高可读性
		name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		name_label.add_theme_constant_override("shadow_offset_x", 1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_label.add_theme_constant_override("margin_left", 5)
		name_label.add_theme_constant_override("margin_right", 5)
		name_overlay.add_child(name_label)
	else:
		# 如果没有图片，显示占位符铺满面板
		var placeholder = ColorRect.new()
		placeholder.color = Color(0.3, 0.3, 0.4, 1.0)
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_panel.add_child(placeholder)
		
		var placeholder_label = Label.new()
		placeholder_label.text = "无图片\n" + card_data.card_name
		placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder_label.add_theme_font_override("font", chinese_font)
		placeholder_label.add_theme_font_size_override("font_size", 16)  # 增大字体使更美观
		placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		placeholder.add_child(placeholder_label)
		print("卡牌无图片，使用占位符铺满面板: %s" % card_data.card_name)

## 创建战斗信息UI
func create_battle_info_ui(parent):
	print("创建战斗信息UI")
	
	# 计算当前缩放因子
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_factor = min(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	scale_factor = clamp(scale_factor, 0.7, 2.0)  # 限制缩放范围
	
	# 检测分辨率
	var is_high_resolution = viewport_size.y >= 900
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080
	
	# 根据分辨率设置信息区域尺寸
	var info_base_width = 0
	var info_base_height = 0
	
	if is_full_hd:
		# 1920*1080分辨率下设置更美观的信息区域
		info_base_width = 140  # 比之前的88稍大一些
		info_base_height = 60  # 比之前的35稍大一些
	elif is_high_resolution:
		info_base_width = 135  # 比之前的88稍大一些
		info_base_height = 60  # 比之前的35稍大一些
	else:
		info_base_width = 130  # 比之前的88稍大一些
		info_base_height = 45  # 比之前的35稍大一些
	
	# 计算适应后的尺寸
	var info_width = int(info_base_width * scale_factor)
	var info_height = int(info_base_height * scale_factor)
	
	# 创建战斗信息容器
	var battle_info_container = VBoxContainer.new()
	battle_info_container.custom_minimum_size = Vector2(info_width, info_height)
	parent.add_child(battle_info_container)
	
	# 血量条
	health_bar = ProgressBar.new()
	# 血条宽度也需要适应
	var bar_width = int(info_width * 0.9)  # 留出一点边距
	health_bar.custom_minimum_size = Vector2(bar_width, int(10 * scale_factor))
	health_bar.min_value = 0
	health_bar.max_value = card_data.max_health if card_data.max_health > 0 else card_data.health
	health_bar.value = card_data.health
	health_bar.show_percentage = false
	battle_info_container.add_child(health_bar)
	
	# 属性显示容器
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 2)
	battle_info_container.add_child(stats_container)
	
	# 主要属性行（攻击力和生命值）
	var main_stats_container = HBoxContainer.new()
	main_stats_container.add_theme_constant_override("separation", 8)
	stats_container.add_child(main_stats_container)
	
	# 攻击力标签
	attack_label = Label.new()
	attack_label.text = "⚔%d" % card_data.attack
	attack_label.custom_minimum_size = Vector2(45, 18)
	attack_label.add_theme_font_override("font", chinese_font)
	attack_label.add_theme_font_size_override("font_size", 15)
	main_stats_container.add_child(attack_label)
	
	# 生命值标签
	health_label = Label.new()
	health_label.text = "❤%d/%d" % [card_data.health, card_data.max_health if card_data.max_health > 0 else card_data.health]
	health_label.custom_minimum_size = Vector2(65, 18)
	health_label.add_theme_font_override("font", chinese_font)
	health_label.add_theme_font_size_override("font_size", 15)
	main_stats_container.add_child(health_label)
	
	# 次要属性行（护甲和护盾）
	var secondary_stats_container = HBoxContainer.new()
	secondary_stats_container.add_theme_constant_override("separation", 8)
	stats_container.add_child(secondary_stats_container)
	
	# 护甲标签（常驻显示）
	armor_label = Label.new()
	armor_label.text = "🛡%d" % card_data.armor
	armor_label.custom_minimum_size = Vector2(45, 18)
	armor_label.add_theme_font_override("font", chinese_font)
	armor_label.add_theme_font_size_override("font_size", 15)
	secondary_stats_container.add_child(armor_label)
	
	# 护盾标签（常驻显示）
	shield_label = Label.new()
	shield_label.text = "🔵%d" % card_data.shield
	shield_label.custom_minimum_size = Vector2(45, 18)
	shield_label.add_theme_font_override("font", chinese_font)
	shield_label.add_theme_font_size_override("font_size", 15)
	# 护盾值现在常驻显示，不再根据数值隐藏
	secondary_stats_container.add_child(shield_label)
	
	# 🎒 装备图标容器（始终创建，即使没有装备）
	equipment_container = HBoxContainer.new()
	equipment_container.add_theme_constant_override("separation", 3)
	equipment_container.alignment = BoxContainer.ALIGNMENT_CENTER
	equipment_container.custom_minimum_size = Vector2(0, 24)  # 固定高度，避免布局闪烁
	stats_container.add_child(equipment_container)
	
	# 初始化装备显示
	update_equipment_display()

## 更新装备显示
func update_equipment_display():
	if not equipment_container or not is_instance_valid(equipment_container):
		return
	
	# 清空现有图标
	for child in equipment_container.get_children():
		child.queue_free()
	
	# 如果有装备，添加图标
	if card_data and card_data.equipment and card_data.equipment.size() > 0:
		for equip in card_data.equipment:
			var equip_icon = create_equipment_icon(equip)
			if equip_icon:
				equipment_container.add_child(equip_icon)
		print("🎒 更新装备显示: %s 装备了 %d 件装备" % [card_data.card_name, card_data.equipment.size()])

## 创建装备小图标
func create_equipment_icon(equipment: Dictionary) -> TextureRect:
	if not equipment or not equipment.has("icon"):
		return null
	
	# 构建图标路径
	var icon_path = "res://assets/equipment/%s/%s" % [
		"攻击" if equipment.get("category") == "attack" else "防御",
		equipment.get("icon", "")
	]
	
	# 检查文件是否存在
	if not ResourceLoader.exists(icon_path):
		print("⚠️ 装备图标未找到:", icon_path)
		return null
	
	# 创建图标
	var icon = TextureRect.new()
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.tooltip_text = equipment.get("description", equipment.get("name", ""))
	
	return icon

## 设置交互
func setup_interactions():
	print("设置战斗实体交互")
	
	# 设置自身的输入处理
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

## 安全等待布局完成后存储位置
func _wait_for_layout_then_store_position():
	# 等待多帧确保布局完成
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 现在存储原始位置
	store_original_transform()
	print("存储原始位置: %s at %s" % [card_data.card_name if card_data else "未知", str(position)])
	
	# 额外验证：确保位置是有效的
	if position == Vector2.ZERO:
		print("警告: 存储的位置为零，等待更多帧")
		await get_tree().process_frame
		store_original_transform()
		print("重新存储位置: %s at %s" % [card_data.card_name if card_data else "未知", str(position)])

## 手动重新校准位置（在攻击结束后调用）
func recalibrate_position():
	if original_position != Vector2.ZERO:
		position = original_position
		print("重新校准位置: %s 设置为 %s" % [card_data.card_name if card_data else "未知", str(position)])
	else:
		# 如果没有存储原始位置，重新存储当前位置
		store_original_transform()
		print("警告: 原始位置未存储，重新存储当前位置: %s" % str(position))

## 存储原始变换
func store_original_transform():
	original_position = position
	original_scale = scale
	# 验证存储的位置是否有效
	if original_position == Vector2.ZERO:
		print("警告: 存储的位置为零 - %s" % (card_data.card_name if card_data else "未知"))

## 验证并修复位置（额外的安全检查）
func verify_and_fix_position():
	if original_position != Vector2.ZERO and position != original_position:
		print("修复位置偏差: %s 从 %s 修复到 %s" % [
			card_data.card_name if card_data else "未知",
			str(position),
			str(original_position)
		])
		position = original_position
		return true
	return false

## 设置卡牌数据
func set_card_data(card, is_player: bool = true):
	if not card:
		print("错误: 设置的卡牌数据为空")
		return
	
	card_data = card
	is_player_card = is_player
	
	print("设置卡牌数据: %s (玩家卡牌: %s)" % [card.card_name, str(is_player)])
	
	# 如果UI已经创建，更新显示
	if is_node_ready():
		call_deferred("update_display")

## 更新显示
func update_display():
	if not card_data:
		return
	
	print("更新战斗实体显示: %s" % card_data.card_name)
	
	# 更新血量条
	if health_bar and is_instance_valid(health_bar):
		health_bar.max_value = card_data.max_health if card_data.max_health > 0 else card_data.health
		health_bar.value = card_data.health
	
	# 更新属性标签
	if attack_label and is_instance_valid(attack_label):
		attack_label.text = "⚔%d" % card_data.attack
	
	if health_label and is_instance_valid(health_label):
		health_label.text = "❤%d/%d" % [card_data.health, card_data.max_health if card_data.max_health > 0 else card_data.health]
	
	if armor_label and is_instance_valid(armor_label):
		armor_label.text = "🛡%d" % card_data.armor
		# 护甲常驻显示，不再根据数值隐藏
	
	if shield_label and is_instance_valid(shield_label):
		shield_label.text = "🔵%d" % card_data.shield
		# 护盾常驻显示，不再根据数值隐藏
	
	# 更新装备显示
	update_equipment_display()
	
	# 更新可视状态
	update_visual_state()

## 更新可视状态
func update_visual_state():
	if not card_data:
		return
	
	# 死亡状态
	if card_data.is_dead():
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		return
	
	# 选中状态
	if is_selected:
		modulate = Color(1.2, 1.2, 1.0, 1.0)
	else:
		modulate = Color.WHITE

## 处理输入事件
func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_card_clicked()
	elif event is InputEventScreenTouch and event.pressed:
		_on_card_clicked()

## 卡牌点击处理
func _on_card_clicked():
	print("战斗实体被点击: %s" % (card_data.card_name if card_data else "未知"))
	card_clicked.emit(self)

## 鼠标悬停处理
func _on_mouse_entered():
	if not is_attacking:
		card_hovered.emit(self)
		create_tween().tween_property(self, "scale", original_scale * 1.05, 0.1)

func _on_mouse_exited():
	if not is_attacking:
		card_unhovered.emit(self)
		create_tween().tween_property(self, "scale", original_scale, 0.1)

## 设置选中状态
func set_selected(selected: bool):
	is_selected = selected
	update_visual_state()
	print("战斗实体选中状态: %s (%s)" % [str(selected), card_data.card_name if card_data else "未知"])

## 设置可攻击状态
func set_targetable(targetable: bool):
	is_targetable = targetable
	print("战斗实体可攻击状态: %s (%s)" % [str(targetable), card_data.card_name if card_data else "未知"])

## 执行攻击动画
func play_attack_animation(target_position):
	if is_attacking:
		return
	
	# 安全性检查：确保原始位置已被存储
	if original_position == Vector2.ZERO:
		print("警告: 原始位置未存储，重新存储: %s" % (card_data.card_name if card_data else "未知"))
		store_original_transform()
	
	is_attacking = true
	print("播放攻击动画: %s 从 %s 到 %s" % [
		card_data.card_name if card_data else "未知",
		str(original_position),
		str(target_position)
	])
	
	# 保存当前精确位置作为起点
	var start_position = position
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 移动到目标位置 - 计算准确的中间点
	var mid_position = start_position.lerp(target_position, 0.7)
	tween.tween_property(self, "position", mid_position, 0.15)
	tween.tween_property(self, "scale", original_scale * 1.2, 0.15)
	tween.tween_property(self, "scale", original_scale, 0.15).set_delay(0.15)
	
	# 返回原位置 - 使用原始存储的位置确保精确返回
	tween.tween_property(self, "position", original_position, 0.3).set_delay(0.3)
	
	await tween.finished
	is_attacking = false
	
	# 强制确保位置正确返回，使用多重检查
	position = original_position
	scale = original_scale
	
	# 额外延迟两帧以确保位置更新完成
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 最终位置验证
	if position.distance_to(original_position) > 1.0:
		print("修正显著位置偏差: %s 从 %s 修正到 %s" % [
			card_data.card_name if card_data else "未知", 
			str(position), 
			str(original_position)
		])
		position = original_position
	
	print("攻击动画完成: %s 返回位置 %s" % [
		card_data.card_name if card_data else "未知",
		str(position)
	])

## 播放受伤动画
func play_damage_animation():
	print("播放受伤动画: %s" % (card_data.card_name if card_data else "未知"))
	
	# 安全性检查：确保原始位置已被存储
	if original_position == Vector2.ZERO:
		store_original_transform()
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 红色闪烁
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1).set_delay(0.1)
	
	# 轻微震动，确保返回原位置
	var shake_offset = Vector2(5, 0)
	tween.tween_property(self, "position", original_position + shake_offset, 0.05)
	tween.tween_property(self, "position", original_position - shake_offset, 0.05).set_delay(0.05)
	tween.tween_property(self, "position", original_position, 0.05).set_delay(0.1)
	
	# 等待动画完成后确保位置正确
	await tween.finished
	position = original_position
	# 额外等待一帧确保位置更新
	await get_tree().process_frame
	if position != original_position:
		position = original_position
		print("受伤后修正位置: %s 设置为 %s" % [card_data.card_name if card_data else "未知", str(position)])

## 播放死亡动画
func play_death_animation():
	print("播放死亡动画: %s" % (card_data.card_name if card_data else "未知"))
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 缩放和透明度变化
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	
	await tween.finished
	died.emit(self)

## 受到伤害
func take_damage(damage: int):
	if not card_data:
		return
	
	var old_health = card_data.health
	var actual_damage = card_data.take_damage(damage)
	
	print("战斗实体受伤: %s 受到 %d 伤害" % [card_data.card_name, actual_damage])
	
	# 播放受伤动画
	play_damage_animation()
	
	# 更新显示
	update_display()
	
	# 发出血量变化信号
	health_changed.emit(self, old_health, card_data.health)
	
	# 检查是否死亡
	if card_data.is_dead():
		call_deferred("play_death_animation")

## 获取卡牌数据
func get_card():
	return card_data

## 检查是否为玩家卡牌
func is_player() -> bool:
	return is_player_card

## 检查是否可以被选择
func can_be_selected() -> bool:
	return card_data and not card_data.is_dead() and is_targetable

## 检查是否可以攻击
func can_attack() -> bool:
	return card_data and card_data.can_perform_attack() and not is_attacking
