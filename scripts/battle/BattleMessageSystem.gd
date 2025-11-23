extends Control

## 战斗消息系统

# 预加载中文字体
var chinese_font = preload("res://assets/fonts/Arial Unicode.ttf")
## 记录和显示战斗过程中的所有行动和效果

# UI组件
var message_panel: Panel
var message_scroll: ScrollContainer
var message_list: VBoxContainer
var turn_label: Label
var history_button: Button

# 消息系统配置
var show_detailed_messages: bool = true  # 是否显示详细消息
var show_card_switching: bool = false    # 是否显示卡牌切换消息
var max_messages_per_turn: int = 15      # 每回合最大消息数(优化)
var enable_message_grouping: bool = true  # 是否启用消息分组
var show_timestamps: bool = false        # 是否显示时间戳

# 消息数据
var current_turn: int = 1
var turn_messages: Array = []  # 当前回合的消息
var all_messages: Array = []   # 所有历史消息
var message_history: Dictionary = {}  # 按回合存储的消息历史
var last_message_time: float = 0.0  # 上次消息时间
var last_message_text: String = ""  # 上次消息内容
var duplicate_threshold: float = 0.5  # 去重时间阈值（秒）

# 消息类型颜色 - 优化的配色方案
var message_colors = {
	"action": Color(0.9, 0.9, 0.9),     # 普通行动(浅灰)
	"attack": Color(1.0, 0.7, 0.3),     # 攻击(暖橙色)
	"damage": Color(1.0, 0.5, 0.5),     # 伤害(亮红色)
	"heal": Color(0.4, 0.9, 0.6),       # 治疗(翠绿色)
	"skill": Color(0.5, 0.8, 1.0),      # 技能(天蓝色)
	"passive": Color(0.9, 0.6, 1.0),    # 被动技能(淡紫色)
	"crit": Color(1.0, 0.9, 0.2),       # 暴击(金黄色)
	"dodge": Color(0.3, 1.0, 0.8),      # 闪避(蓝绿色)
	"turn": Color(0.7, 0.9, 1.0),       # 回合信息(淡蓝色)
	"death": Color(0.8, 0.4, 0.4),      # 死亡(深红色)
	"system": Color(1.0, 1.0, 1.0)      # 系统消息(纯白色，更醒目)
}

func _ready():
	setup_ui()
	reset_messages()

## 初始化UI
func setup_ui():
	# 设置自身属性
	custom_minimum_size = Vector2(320, 400)
	
	# 创建主面板 - 添加美化样式
	message_panel = Panel.new()
	add_child(message_panel)
	message_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 创建面板样式
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.4, 0.5, 0.8)
	message_panel.add_theme_stylebox_override("panel", panel_style)
	
	var main_container = VBoxContainer.new()
	message_panel.add_child(main_container)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 8)
	main_container.add_theme_constant_override("margin_left", 10)
	main_container.add_theme_constant_override("margin_right", 10)
	main_container.add_theme_constant_override("margin_top", 8)
	main_container.add_theme_constant_override("margin_bottom", 8)
	
	# 顶部标题区 - 美化设计
	var header_container = HBoxContainer.new()
	header_container.custom_minimum_size = Vector2(0, 40)
	main_container.add_child(header_container)
	
	# 回合标题 - 简洁样式
	turn_label = Label.new()
	turn_label.text = "第 1 回合"
	turn_label.add_theme_font_override("font", chinese_font)
	turn_label.add_theme_font_size_override("font_size", 18)
	turn_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	turn_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	turn_label.add_theme_constant_override("shadow_offset_x", 1)
	turn_label.add_theme_constant_override("shadow_offset_y", 1)
	turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(turn_label)
	
	# 历史查看按钮已移除
	
	# 添加分隔线
	var separator = HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.4, 0.5, 0.6, 0.6))
	main_container.add_child(separator)
	
	# 消息滚动区域 - 优化滚动体验
	message_scroll = ScrollContainer.new()
	message_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	message_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_container.add_child(message_scroll)
	
	# 消息列表 - 添加间距控制
	message_list = VBoxContainer.new()
	message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_list.add_theme_constant_override("separation", 4)
	message_scroll.add_child(message_list)

## 重置消息系统
func reset_messages():
	current_turn = 1
	turn_messages.clear()
	all_messages.clear()
	message_history.clear()
	last_message_time = 0.0
	last_message_text = ""
	update_turn_display()
	clear_message_display()

## 添加消息（优化版本）
func add_message(text: String, type: String = "action"):
	# 过滤空消息
	if text.strip_edges().is_empty():
		return
	
	# 检查是否应该显示该消息
	if not _should_show_message(text, type):
		return
	
	# 创建消息对象
	var message = {
		"text": text,
		"type": type,
		"turn": current_turn,
		"timestamp": Time.get_time_string_from_system()
	}
	
	# 检查每回合消息数量限制
	if turn_messages.size() >= max_messages_per_turn:
		# 移除最早的非重要消息
		_remove_oldest_non_important_message()
	
	turn_messages.append(message)
	all_messages.append(message)
	
	# 显示消息
	display_message(message)
	
	# 自动滚动到底部
	call_deferred("scroll_to_bottom")

## 判断是否应该显示该消息
func _should_show_message(text: String, _type: String) -> bool:
	# 卡牌切换消息过滤
	if not show_card_switching and "切换" in text:
		return false
	
	# 可以添加更多过滤规则
	return true

## 检查是否为重复消息
func _is_duplicate_message(text: String, timestamp: float) -> bool:
	# 如果是第一条消息，不去重
	if last_message_text == "":
		return false
	
	# 检查时间间隔
	var time_diff = timestamp - last_message_time
	if time_diff > duplicate_threshold:
		return false
	
	# 检查文本相似度
	if _are_messages_similar(text, last_message_text):
		return true
	
	return false

## 检查两条消息是否相似
func _are_messages_similar(msg1: String, msg2: String) -> bool:
	# 完全相同
	if msg1 == msg2:
		return true
	
	# 检查是否为相似的攻击消息（只是伤害数值不同）
	var attack_pattern1 = _extract_attack_pattern(msg1)
	var attack_pattern2 = _extract_attack_pattern(msg2)
	
	if attack_pattern1 != "" and attack_pattern2 != "":
		return attack_pattern1 == attack_pattern2
	
	return false

## 提取攻击消息的模式（移除伤害数值）
func _extract_attack_pattern(message: String) -> String:
	# 匹配攻击消息格式："A 攻击 B，造成 X 点伤害"
	var regex = RegEx.new()
	regex.compile(r"(.+) 攻击 (.+)，造成 \d+ 点伤害")
	var result = regex.search(message)
	if result:
		return "%s 攻击 %s" % [result.get_string(1), result.get_string(2)]
	
	# 匹配暴击消息格式："暴击！A 对 B 造成了 X 点暴击伤害"
	regex.compile(r"暴击！(.+) 对 (.+) 造成了 \d+ 点.+伤害")
	result = regex.search(message)
	if result:
		return "暴击 %s 对 %s" % [result.get_string(1), result.get_string(2)]
	
	# 匹配组合效果消息："(暴击+被动)A 对 B 造成 X 点伤害"
	regex.compile(r"\(.+\)(.+) 对 (.+) 造成 \d+ 点伤害")
	result = regex.search(message)
	if result:
		return "组合攻击 %s 对 %s" % [result.get_string(1), result.get_string(2)]
	
	# 匹配技能消息格式："A 发动技能「X」：Y"
	regex.compile(r"(.+) 发动技能「.+」：.+")
	result = regex.search(message)
	if result:
		return "%s 发动技能" % result.get_string(1)
	
	return ""

## 显示单条消息（简洁版）
func display_message(message: Dictionary):
	# 简洁的消息容器
	var message_label = RichTextLabel.new()
	message_label.bbcode_enabled = true
	message_label.fit_content = true
	message_label.custom_minimum_size = Vector2(290, 20)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.scroll_active = false
	
	# 获取颜色和格式化文本
	var color = message_colors.get(message.type, Color.WHITE)
	var formatted_text = _format_message_text(message.text, message.type, color)
	
	message_label.text = formatted_text
	message_list.add_child(message_label)

## 清空消息显示
func clear_message_display():
	for child in message_list.get_children():
		child.queue_free()

## 滚动到底部
func scroll_to_bottom():
	if message_scroll:
		message_scroll.scroll_vertical = message_scroll.get_v_scroll_bar().max_value

## 获取消息类型图标
func _get_message_icon(type: String) -> String:
	match type:
		"attack":
			return "[攻击]"
		"damage":
			return "[伤害]"
		"heal":
			return "[治疗]"
		"skill":
			return "[技能]"
		"passive":
			return "[被动]"
		"crit":
			return "[暴击]"
		"turn":
			return "[回合]"
		"death":
			return "[死亡]"
		"system":
			return "[系统]"
		_:
			return "•"

## 格式化消息文本（简洁版）
func _format_message_text(text: String, type: String, color: Color) -> String:
	var color_hex = "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]
	
	# 根据消息类型添加简单格式
	match type:
		"crit":
			return "[color=%s][b]%s[/b][/color]" % [color_hex, text]
		"death":
			return "[color=%s][b]%s[/b][/color]" % [color_hex, text]
		"turn":
			return "[color=%s][b]%s[/b][/color]" % [color_hex, text]
		"skill":
			return "[color=%s][i]%s[/i][/color]" % [color_hex, text]
		"system":
			# 系统消息使用更大的字体和更醒目的颜色
			return "[color=%s][b]%s[/b][/color]" % [color_hex, text]
		_:
			return "[color=%s]%s[/color]" % [color_hex, text]

## 移除最早的非重要消息
func _remove_oldest_non_important_message():
	# 重要消息类型，不会被移除
	var important_types = ["turn", "death", "crit"]
	
	for i in range(turn_messages.size() - 1, -1, -1):
		var msg = turn_messages[i]
		if msg.type not in important_types:
			turn_messages.remove_at(i)
			# 同时从显示中移除
			if i < message_list.get_child_count():
				message_list.get_child(i).queue_free()
			return

## 开始新回合（修复版本 - 解决回合显示顺序问题）
func start_new_turn(turn_number: int, player_name: String = ""):
	# 保存当前回合的消息
	if not turn_messages.is_empty():
		message_history[current_turn] = turn_messages.duplicate()
	
	current_turn = turn_number
	turn_messages.clear()
	update_turn_display()
	
	# 第一回合玩家回合处理（回合 1，玩家方）
	if turn_number == 1 and player_name == "玩家":
		# 首先添加战斗开始消息
		add_battle_start()
		
		# 然后添加第一回合玩家回合信息，使用更清晰的格式
		add_message("┌────────────────────────────────────┐", "turn")
		add_message("│            第 %d 回合（玩家回合）           │" % current_turn, "turn")
		add_message("└────────────────────────────────────┘", "turn")
	
	# 第一回合敌方回合处理（回合 1，敌方）
	elif turn_number == 1 and player_name == "敌方":
		add_message("┌────────────────────────────────────┐", "turn")
		add_message("│            第 %d 回合（敌方回合）           │" % current_turn, "turn")
		add_message("└────────────────────────────────────┘", "turn")
	
	# 非第一回合的处理（回合 > 1）
	else:
		# 根据玩家名称添加分隔线
		if player_name != "":
			add_message("\n┌────────────────────────────────────┐", "turn")
			add_message("│            第 %d 回合（%s回合）           │" % [current_turn, player_name], "turn")
			add_message("└────────────────────────────────────┘", "turn")
		else:
			add_message("\n┌────────────────────────────────────┐", "turn")
			add_message("│              第 %d 回合              │" % current_turn, "turn")
			add_message("└────────────────────────────────────┘", "turn")

## 添加回合开始消息（已弃用 - 使用start_new_turn中的集成版本）
func add_turn_start(_turn_number: int, player_name: String):
	# 此方法已不再使用，回合信息现在直接集成在回合分隔线中
	pass

## 添加攻击消息（增强版，显示详细计算过程）
func add_attack(attacker: String, target: String, damage: int, details: Dictionary = {}):
	if details.is_empty():
		add_message("%s 攻击 %s，造成 %d 点伤害" % [attacker, target, damage], "attack")
	else:
		# 显示详细计算过程
		var detail_text = "%s 攻击 %s：" % [attacker, target]
		var base_damage = details.get("base_damage", 0)
		var armor = details.get("target_armor", 0)
		
		detail_text += "\n  基础伤害计算：攻击力%d - 护甲%d = %d" % [details.get("attacker_attack", 0), armor, base_damage]
		
		if details.get("is_critical", false):
			var crit_damage = details.get("crit_damage", 1.3)
			detail_text += "\n  暴击：%d × %.1f = %d" % [base_damage, crit_damage, damage]
		
		if details.get("has_damage_bonus", false):
			var bonus_percent = details.get("damage_bonus_percent", 0)
			detail_text += "\n  增伤：%d × (1 + %.0f%%) = %d" % [base_damage, bonus_percent, damage]
		
		detail_text += "\n  最终造成 %d 点伤害" % damage
		add_message(detail_text, "attack")

## 添加暴击攻击消息（增强版，显示详细计算过程）
func add_critical_attack(attacker: String, target: String, damage: int, details: Dictionary = {}):
	if details.is_empty():
		add_message("暴击！%s 对 %s 造成 %d 点伤害" % [attacker, target, damage], "crit")
	else:
		# 显示详细暴击计算过程
		var detail_text = "暴击！%s 对 %s 造成伤害：" % [attacker, target]
		var base_damage = details.get("base_damage", 0)
		var crit_damage = details.get("crit_damage", 1.3)
		
		detail_text += "\n  基础伤害：%d" % base_damage
		detail_text += "\n  暴击倍率：%.1f" % crit_damage
		detail_text += "\n  暴击伤害：%d × %.1f = %d" % [base_damage, crit_damage, damage]
		
		if details.get("has_damage_bonus", false):
			var bonus_percent = details.get("damage_bonus_percent", 0)
			detail_text += "\n  增伤后：%d × (1 + %.0f%%) = %d" % [int(damage/crit_damage), bonus_percent, damage]
		
		detail_text += "\n  最终造成 %d 点暴击伤害" % damage
		add_message(detail_text, "crit")

## 增强版本：添加被动技能触发消息（显示详细效果）
func add_passive_skill(character: String, skill_name: String, effect: String, details: Dictionary = {}):
	# 对朵莉亚的被动技能进行特殊处理，确保技能名称和效果正确
	var display_effect = effect
	if character == "朵莉亚" and skill_name == "欢歌":
		# 🔧 根据服务器数据判断显示内容
		var heal_amount = details.get("heal_amount", 0)
		var overflow_shield = details.get("overflow_shield", 0)
		
		if heal_amount > 0 and overflow_shield > 0:
			# 恢复生命 + 溢出护盾
			display_effect = "恢复%d点生命值，溢出%d点转为护盾" % [heal_amount, overflow_shield]
		elif heal_amount == 0 and overflow_shield > 0:
			# 满血，全部转护盾
			display_effect = "生命值已满，获得%d点护盾" % overflow_shield
		elif heal_amount > 0 and overflow_shield == 0:
			# 只恢复生命
			display_effect = "恢复%d点生命值" % heal_amount
		else:
			# 满血且无溢出
			display_effect = "生命值已满"
	elif character == "澜" and skill_name == "狩猎":
		display_effect = "目标生命值低于50%，增伤+30%"
	elif character == "孙尚香" and skill_name == "千金重弩":
		display_effect = "攻击命中获得1点技能点"
	elif character == "公孙离" and skill_name == "霜叶舞":
		# 公孙离的被动技能有两种效果，根据effect内容区分
		if "成功闪避攻击" in effect:
			display_effect = "成功闪避攻击，获得攻击力+10和暴击率+5%"
		elif "攻击暴击触发" in effect:
			# 从effect中提取当前闪避概率
			var regex = RegEx.new()
			regex.compile(r"当前闪避概率([\d\.]+)%")
			var match_result = regex.search(effect)
			if match_result:
				var current_dodge_rate = match_result.get_string(1)
				display_effect = "攻击暴击，获得固定增益，闪避概率+5%%，当前闪避概率%s%%" % current_dodge_rate
			else:
				display_effect = "攻击暴击，获得固定增益，闪避概率+5%"
	elif character == "瑶" and skill_name == "山鬼白鹿":
		display_effect = "为生命值最低的友方英雄添加护盾"
	elif character == "少司缘" and skill_name == "怨离别":
		display_effect = "偷取敌方技能点"
	
	# 如果有详细信息，显示完整计算过程
	if not details.is_empty():
		var detail_text = "%s的被动技能「%s」发动：" % [character, skill_name]
		
		match skill_name:
			"山鬼白鹿":
				# 瑶被动技能护盾计算
				var target_ally = details.get("target_ally", "友方英雄")
				var base_shield = details.get("base_shield", 100)  # 🔧 正确的基础值
				var health_percent = details.get("health_percent", 3)  # 🔧 正确的百分比
				var yao_health = details.get("yao_health", 0)
				var calculated_shield = base_shield + int(yao_health * health_percent / 100.0)
				
				detail_text += "\n  为%s添加护盾：" % target_ally
				detail_text += "\n  基础护盾值：%d" % base_shield
				detail_text += "\n  瑶当前生命值：%d" % yao_health
				detail_text += "\n  计算公式：%d + %d × %d%% = %d" % [base_shield, yao_health, health_percent, calculated_shield]
				detail_text += "\n  最终护盾值：%d" % calculated_shield
			"霜叶舞":
				if "成功闪避" in effect or "闪避成功" in effect:
					detail_text += "\n  闪避成功，获得固定增益："
					detail_text += "\n  攻击力 +%d" % details.get("attack_bonus", 10)
					detail_text += "\n  暴击率 +%d%%" % int(details.get("crit_rate_bonus", 0.05) * 100)
					# 显示当前属性值
					if details.has("current_attack") and details.has("current_crit_rate"):
						detail_text += "\n  当前攻击力：%d" % details.get("current_attack", 0)
						detail_text += "\n  当前暴击率：%.1f%%" % details.get("current_crit_rate", 0)
				elif "攻击暴击" in effect:
					detail_text += "\n  攻击暴击，获得固定增益："
					detail_text += "\n  闪避概率 +%d%%" % int(details.get("dodge_bonus", 0.05) * 100)
					# 显示当前闪避率
					if details.has("current_dodge_rate"):
						detail_text += "\n  当前闪避概率：%.1f%%" % details.get("current_dodge_rate", 0)
						detail_text += "\n（最多可叠加至+20%闪避概率，最高50%）"
			"欢歌":
				var heal_amount = details.get("heal_amount", 0)
				var overflow_shield = details.get("overflow_shield", 0)
				
				# 根据不同情况显示不同消息
				if heal_amount > 0 and overflow_shield > 0:
					# 恢复生命 + 溢出护盾
					detail_text += "\n  恢复生命值：%d" % heal_amount
					detail_text += "\n  溢出%d点转化为护盾" % overflow_shield
				elif heal_amount == 0 and overflow_shield > 0:
					# 满血，全部转护盾
					detail_text += "\n  生命值已满，获得%d点护盾" % overflow_shield
				elif heal_amount > 0 and overflow_shield == 0:
					# 只恢复生命
					detail_text += "\n  恢复生命值：%d" % heal_amount
				else:
					# 满血且无溢出
					detail_text += "\n  生命值已满"
				
			"狩猎":
				var damage_bonus = details.get("damage_bonus", 0.3)
				detail_text += "\n  增伤效果：+%.0f%%" % (damage_bonus * 100)
			"千金重弩":
				var skill_points = details.get("skill_points_gained", 1)
				detail_text += "\n  获得技能点：%d" % skill_points
			"怨离别":
				# 少司缘被动技能详细信息
				if details.has("stolen_points"):
					var stolen_points = details.get("stolen_points", 0)
					var current_stolen_count = details.get("current_stolen_count", 0)
					detail_text += "\n  偺取数量：%d 点" % stolen_points
					detail_text += "\n  当前偋取点数计数：%d 点" % current_stolen_count
					detail_text += "\n  （偋取点数计数上限为4点，用于主动技能计算）"
				elif details.has("heal_amount"):
					var heal_amount = details.get("heal_amount", 0)
					detail_text += "\n  技能点池已满，改为恢复生命值：%d 点" % heal_amount
		
		add_message(detail_text, "passive")
	else:
		add_message("%s的被动技能「%s」发动：%s" % [character, skill_name, display_effect], "passive")

## 添加主动技能消息（增强版，显示详细效果）
func add_active_skill(character: String, skill_name: String, effect: String, details: Dictionary = {}):
	if not details.is_empty():
		var detail_text = "%s 发动技能「%s」：" % [character, skill_name]
		
		match skill_name:
			"鹿灵守心":
				# 瑶主动技能护盾计算
				var target_name = details.get("target_name", "目标")
				var base_shield = details.get("base_shield", 150)
				var health_percent = details.get("health_percent", 8)
				var yao_health = details.get("yao_health", 0)
				var calculated_shield = base_shield + int(yao_health * health_percent / 100.0)
				var crit_buff = details.get("crit_buff", 0.05)
				var armor_buff = details.get("armor_buff", 20)
				
				detail_text += "\n  为%s添加护盾：" % target_name
				detail_text += "\n  基础护盾值：%d" % base_shield
				detail_text += "\n  瑶当前生命值：%d" % yao_health
				detail_text += "\n  计算公式：%d + %d × %d%% = %d" % [base_shield, yao_health, health_percent, calculated_shield]
				detail_text += "\n  最终护盾值：%d" % calculated_shield
				
				# 添加目标强化后的属性信息
				detail_text += "\n  属性强化效果："
				detail_text += "\n  暴击率 +%.0f%%" % (crit_buff * 100)
				detail_text += "\n  护甲 +%d" % armor_buff
				
				# 显示强化后的属性值（如果提供）
				if details.has("target_current_crit_rate") and details.has("target_current_armor"):
					detail_text += "\n  强化后暴击率：%.1f%%" % details.get("target_current_crit_rate", 0)
					detail_text += "\n  强化后护甲：%d" % details.get("target_current_armor", 0)
					# 添加护盾值信息
					if details.has("target_current_shield"):
						detail_text += "\n  当前护盾值：%d" % details.get("target_current_shield", 0)
				
			"人鱼之赐":
				var heal_amount = details.get("heal_amount", 130)
				detail_text += "\n  恢复目标生命值：%d" % heal_amount
				
				# 显示治疗后的生命值（如果提供）
				if details.has("target_current_health") and details.has("target_max_health"):
					detail_text += "\n  治疗后生命值：%d/%d" % [
						details.get("target_current_health", 0),
						details.get("target_max_health", 0)
					]
				
			"鲨之猎刃":
				var attack_buff = details.get("attack_buff", 100)
				detail_text += "\n  永久提升攻击力：%d" % attack_buff
				
				# 显示提升后的攻击力（如果提供）
				if details.has("current_attack"):
					detail_text += "\n  提升后攻击力：%d" % details.get("current_attack", 0)
				
			"晚云落":
				var crit_rate_buff = details.get("crit_rate_buff", 0.4)
				detail_text += "\n  永久提升暴击率：%.0f%%" % (crit_rate_buff * 100)
				
				# 显示溢出情况
				if details.get("crit_damage_bonus", 0) > 0:
					var crit_damage_bonus = details.get("crit_damage_bonus", 0)
					detail_text += "\n  暴击率溢出转换为暴击效果：+%.0f%%" % (crit_damage_bonus * 100)
				
				# 显示提升后的属性值（如果提供）
				if details.has("current_crit_rate") and details.has("current_crit_damage"):
					detail_text += "\n  提升后暴击率：%.1f%%" % details.get("current_crit_rate", 0)
					detail_text += "\n  提升后暴击效果：%.1f%%" % (details.get("current_crit_damage", 0) * 100)
				
			"红莲爆弹":
				var damage = details.get("damage_amount", 75)
				var armor_reduction = details.get("armor_reduction", 60)
				detail_text += "\n  永久减少目标护甲：%d" % armor_reduction
				
				# 显示减少后的护甲值（如果提供）
				if details.has("target_current_armor"):
					detail_text += "\n  减少后目标护甲：%d" % details.get("target_current_armor", 0)
				
				detail_text += "\n  造成真实伤害：%d" % damage
				if details.get("is_crit", false):
					detail_text += "（暴击）"
		
		add_message(detail_text, "skill")
	else:
		add_message("%s 发动技能「%s」：%s" % [character, skill_name, effect], "skill")

## 真实伤害技能专用消息（增强版，显示详细计算过程）
func add_true_damage_skill(caster: String, target: String, skill_name: String, damage: int, armor_reduction: int, is_crit: bool = false, details: Dictionary = {}):
	if not details.is_empty():
		# 护甲减少消息
		var armor_detail = "%s 的「%s」效果：" % [caster, skill_name]
		armor_detail += "\n  永久减少 %s 的护甲值：%d" % [target, armor_reduction]
		add_message(armor_detail, "skill")
		
		# 真实伤害消息
		var damage_detail = "%s 的「%s」对 %s 造成真实伤害：" % [caster, skill_name, target]
		var base_damage = details.get("base_damage", damage)
		
		damage_detail += "\n  基础真实伤害：%d" % base_damage
		
		if is_crit:
			var crit_damage = details.get("crit_damage", 1.3)
			damage_detail += "\n  暴击倍率：%.1f" % crit_damage
			damage_detail += "\n  暴击伤害：%d × %.1f = %d" % [base_damage, crit_damage, damage]
			damage_detail = "暴击！" + damage_detail
			add_message(damage_detail, "crit")
		else:
			damage_detail += "\n  最终造成 %d 点真实伤害" % damage
			add_message(damage_detail, "skill")
	else:
		# 护甲减少消息
		if armor_reduction > 0:
			add_message("%s 的「%s」永久减少了 %s %d 点护甲值" % [caster, skill_name, target, armor_reduction], "skill")
		
		# 真实伤害消息
		var damage_text = "%s 的「%s」对 %s 造成 %d 点真实伤害" % [caster, skill_name, target, damage]
		if is_crit:
			damage_text = "暴击！" + damage_text
			add_message(damage_text, "crit")
		else:
			add_message(damage_text, "skill")

## 添加大乔沧海之曜技能的详细消息
func add_daqiao_skill(caster: String, skill_name: String, damage_results: Array, total_damage: int):
	var detail_text = "%s 发动技能「%s」：" % [caster, skill_name]
	
	# 显示对每个敌方目标的伤害计算过程
	for result in damage_results:
		var target_name = result.get("target_name", "敌方")
		var base_damage = result.get("base_damage", 0)
		var final_damage = result.get("final_damage", 0)
		var lost_health = result.get("lost_health", 0)
		var caster_attack = result.get("caster_attack", 300) # 默认大乔攻击力
		var is_crit = result.get("is_crit", false)
		
		detail_text += "\n  对 %s 造成伤害：" % target_name
		detail_text += "\n  计算公式：(大乔已损生命值%d + 攻击力%d) / 5 = %d" % [lost_health, caster_attack, base_damage]
		
		if is_crit:
			var crit_damage = result.get("crit_damage", 1.3)
			detail_text += "\n  暴击倍率：%.1f" % crit_damage
			detail_text += "\n  暴击伤害：%d × %.1f = %d" % [base_damage, crit_damage, final_damage]
			detail_text = "暴击！" + detail_text
		else:
			detail_text += "\n  最终造成 %d 点真实伤害" % final_damage
	
	detail_text += "\n  总伤害：%d" % total_damage
	add_message(detail_text, "skill")

## 添加大乔被动技能的详细消息
func add_daqiao_passive(character: String, skill_name: String, effect: String, details: Dictionary = {}):
	var detail_text = "%s 的被动技能「%s」发动：" % [character, skill_name]
	detail_text += "\n  %s" % effect
	
	# 如果有详细信息，显示技能点和护盾转换过程
	if not details.is_empty():
		var skill_points_gained = details.get("skill_points_gained", 3)
		var overflow_points = details.get("overflow_points", 0)
		var shield_amount = details.get("shield_amount", 0)
		var old_skill_points = details.get("old_skill_points", 0)
		var max_skill_points = details.get("max_skill_points", 6)
		
		detail_text += "\n  技能点变化：从 %d 点增加 %d 点" % [old_skill_points, skill_points_gained]
		detail_text += "\n  技能点上限：%d 点" % max_skill_points
		
		if overflow_points > 0:
			detail_text += "\n  溢出技能点：%d 点" % overflow_points
			detail_text += "\n  护盾转换：每溢出1点技能点转换为150点护盾值"
			detail_text += "\n  转换护盾值：%d × 150 = %d 点" % [overflow_points, shield_amount]
			detail_text += "\n  最终护盾值：%d 点" % shield_amount
		else:
			detail_text += "\n  未发生技能点溢出，无需转换护盾"
	
	add_message(detail_text, "passive")

## 添加治疗消息（增强版，显示详细信息）
func add_heal(character: String, target: String, amount: int, details: Dictionary = {}):
	if not details.is_empty():
		var detail_text = ""
		if character == target:
			detail_text = "%s 恢复生命值：" % character
		else:
			detail_text = "%s 为 %s 恢复生命值：" % [character, target]
		
		detail_text += "\n  治疗量：%d" % amount
		
		if details.get("overflow_shield", 0) > 0:
			var overflow = details.get("overflow_shield", 0)
			detail_text += "\n  溢出生命值转化为护盾：%d" % overflow
		
		add_message(detail_text, "heal")
	else:
		var text = ""
		if character == target:
			text = "%s 恢复了 %d 点生命值" % [character, amount]
		else:
			text = "%s 为 %s 恢复了 %d 点生命值" % [character, target, amount]
		add_message(text, "heal")

## 添加护盾消息（增强版，显示详细计算过程）
func add_shield(character: String, amount: int, details: Dictionary = {}):
	if not details.is_empty():
		var detail_text = "%s 获得护盾：" % character
		detail_text += "\n  护盾值：%d" % amount
		
		if details.get("calculation_details", "") != "":
			detail_text += "\n  计算过程：%s" % details.get("calculation_details", "")
		
		add_message(detail_text, "heal")
	else:
		add_message("%s 获得了 %d 点护盾" % [character, amount], "heal")

## 添加少司缘被动技能的详细消息
func add_shaosiyuan_passive(character: String, skill_name: String, effect: String, details: Dictionary = {}):
	var detail_text = "%s 的被动技能「%s」发动：" % [character, skill_name]
	detail_text += "\n  %s" % effect
	
	# 如果有详细信息，显示偷取点数和技能点变化过程
	if not details.is_empty():
		if details.has("stolen_points"):
			var stolen_points = details.get("stolen_points", 0)
			var current_stolen_count = details.get("current_stolen_count", 0)
			detail_text += "\n  偷取敌方技能点：%d 点" % stolen_points
			detail_text += "\n  当前偷取点数计数：%d 点" % current_stolen_count
			detail_text += "\n  （偷取点数计数上限为4点，用于主动技能计算）"
		elif details.has("heal_amount"):
			var heal_amount = details.get("heal_amount", 0)
			detail_text += "\n  技能点池已满，改为恢复生命值：%d 点" % heal_amount
	
	add_message(detail_text, "passive")

## 添加少司缘主动技能的详细消息
func add_shaosiyuan_skill(caster: String, skill_name: String, target: String, effect_type: String, details: Dictionary = {}):
	var detail_text = "%s 发动技能「%s」：" % [caster, skill_name]
	
	if not details.is_empty():
		if effect_type == "shaosiyuan_heal":
			# 缘起（生）治疗效果
			var heal_amount = details.get("heal_amount", 0)
			var base_heal = details.get("base_heal", 100)
			var points = details.get("points", 0)
			var point_multiplier = details.get("point_multiplier", 40)
			
			detail_text += "\n  选择目标：%s（友方）" % target
			detail_text += "\n  发动效果：缘起（生）"
			detail_text += "\n  治疗量计算：基础治疗%d + min(4, 偷取点数%d) × %d = %d" % [base_heal, points, point_multiplier, heal_amount]
			detail_text += "\n  为 %s 恢复 %d 点生命值" % [target, heal_amount]
			
			# 显示治疗后的生命值和护盾值
			if details.has("old_health") and details.has("new_health"):
				detail_text += "\n  生命值：%d → %d" % [details.get("old_health", 0), details.get("new_health", 0)]
			if details.has("old_shield") and details.has("new_shield"):
				detail_text += "\n  护盾值：%d → %d" % [details.get("old_shield", 0), details.get("new_shield", 0)]
				
		elif effect_type == "shaosiyuan_damage":
			# 缘灭（灭）伤害效果
			var damage_amount = details.get("damage_amount", 0)
			var base_damage = details.get("base_damage", 150)
			var points = details.get("points", 0)
			var calculated_damage = details.get("calculated_damage", base_damage + points * 50)
			var point_multiplier = details.get("point_multiplier", 50)
			var is_crit = details.get("is_crit", false)
			var crit_damage = details.get("crit_damage", 1.3)
			var has_damage_bonus = details.get("has_damage_bonus", false)
			var damage_bonus_percent = details.get("damage_bonus_percent", 0)
			
			detail_text += "\n  选择目标：%s（敌方）" % target
			detail_text += "\n  发动效果：缘灭（灭）"
						
			# 显示基础伤害计算
			detail_text += "\n  基础伤害计算：%d + min(4, 偷取点数%d) × %d = %d" % [base_damage, points, point_multiplier, calculated_damage]
			
			if is_crit and has_damage_bonus:
				var crit_value = int(calculated_damage * crit_damage)
				detail_text += "\n  暴击伤害：%d × %.1f = %d" % [calculated_damage, crit_damage, crit_value]
				detail_text += "\n  增伤后：%d × (1 + %.0f%%) = %d" % [crit_value, damage_bonus_percent, damage_amount]
				detail_text = "暴击！" + detail_text
			elif is_crit:
				var crit_value = int(calculated_damage * crit_damage)
				detail_text += "\n  暴击伤害：%d × %.1f = %d" % [calculated_damage, crit_damage, damage_amount]
				detail_text = "暴击！" + detail_text
			elif has_damage_bonus:
				detail_text += "\n  增伤后：%d × (1 + %.0f%%) = %d" % [calculated_damage, damage_bonus_percent, damage_amount]
			else:
				detail_text += "\n  最终造成 %d 点真实伤害" % damage_amount
			
			# 显示伤害后的生命值
			if details.has("old_health") and details.has("new_health"):
				detail_text += "\n  %s 生命值：%d → %d" % [target, details.get("old_health", 0), details.get("new_health", 0)]
	
	add_message(detail_text, "skill")

## 闪避消息（增强版，显示详细信息）
func add_dodge(defender: String, attacker: String, original_damage: int, details: Dictionary = {}):
	if not details.is_empty():
		var detail_text = "闪避！%s 成功闪避了 %s 的攻击：" % [defender, attacker]
		detail_text += "\n  原始伤害：%d" % original_damage
		detail_text += "\n  闪避概率：%.0f%%" % (details.get("dodge_rate", 0.3) * 100)
		add_message(detail_text, "dodge")
	else:
		add_message("闪避！%s 成功闪避了 %s 的攻击（原伤害: %d）" % [defender, attacker, original_damage], "dodge")

## 增强版本：添加组合效果消息（显示详细计算过程）
func add_combo_attack(attacker: String, target: String, damage: int, effects: Array, details: Dictionary = {}):
	if not details.is_empty():
		var effect_text = ""
		if not effects.is_empty():
			effect_text = "(%s)" % "+".join(effects)
		
		var detail_text = "%s%s 对 %s 造成伤害：" % [effect_text, attacker, target]
		var base_damage = details.get("base_damage", 0)
		var armor = details.get("target_armor", 0)
		
		detail_text += "\n  基础伤害计算：攻击力%d - 护甲%d = %d" % [details.get("attacker_attack", 0), armor, base_damage]
		
		if "暴击" in effects:
			var crit_damage = details.get("crit_damage", 1.3)
			var crit_damage_value = int(base_damage * crit_damage)
			detail_text += "\n  暴击：%d × %.1f = %d" % [base_damage, crit_damage, crit_damage_value]
		
		if "暴击" in effects and "被动" in effects:
			var bonus_percent = details.get("damage_bonus_percent", 0)
			var crit_damage_value = int(base_damage * details.get("crit_damage", 1.3))
			detail_text += "\n  增伤：%d × (1 + %.0f%%) = %d" % [crit_damage_value, bonus_percent, damage]
		elif "被动" in effects:
			var bonus_percent = details.get("damage_bonus_percent", 0)
			detail_text += "\n  增伤：%d × (1 + %.0f%%) = %d" % [base_damage, bonus_percent, damage]
		
		detail_text += "\n  最终造成 %d 点伤害" % damage
		
		var message_type = "crit" if "暴击" in effects else "damage"
		add_message(detail_text, message_type)
	else:
		var effect_text = ""
		if not effects.is_empty():
			effect_text = "(%s)" % "+".join(effects)
		
		var message_type = "crit" if "暴击" in effects else "damage"
		add_message("%s%s 对 %s 造成 %d 点伤害" % [effect_text, attacker, target, damage], message_type)

func add_death(character: String):
	add_message("%s 被击败了" % character, "death")

func add_custom(text: String, type: String = "action"):
	add_message(text, type)

## 添加战斗开始消息
func add_battle_start():
	add_message("⚔⚔⚔ 战斗开始 ⚔⚔⚔", "system")

## 更新回合显示
func update_turn_display():
	if turn_label and is_instance_valid(turn_label):
		turn_label.text = "第 %d 回合" % current_turn

## 添加战斗结束消息
func add_battle_end(victory: bool):
	var result = "胜利" if victory else "失败"
	add_message("战斗结束 - %s" % result, "system")

## 添加杨玉环主动技能的详细消息
func add_yangyuhuan_skill(caster: String, skill_name: String, is_high_health: bool, results: Array, total_value: int):
	var detail_text = "%s 发动技能「%s」：" % [caster, skill_name]
	
	if is_high_health:
		# 【惊鸿·伤】模式
		detail_text += "\n  【惊鸿·伤】模式（生命值≥50%）"
		detail_text += "\n  对所有敌方单位造成真实伤害"
		
		# 显示对每个敌方目标的伤害计算过程
		for result in results:
			var target_name = result.get("target_name", "敌方")
			var base_damage = result.get("base_damage", 0)
			var final_damage = result.get("final_damage", 0)
			var is_crit = result.get("is_crit", false)
			var lost_health = result.get("lost_health", 0)
			var caster_attack = result.get("caster_attack", 400) # 默认杨玉环攻击力
			
			detail_text += "\n  对 %s 造成伤害：" % target_name
			detail_text += "\n  计算公式：(0.3 × 攻击力%d + 0.2 × 已损生命值%d) = %d" % [caster_attack, lost_health, base_damage]
			
			if is_crit:
				var crit_damage = result.get("crit_damage", 1.3)
				detail_text += "\n  暴击倍率：%.1f" % crit_damage
				detail_text += "\n  暴击伤害：%d × %.1f = %d" % [base_damage, crit_damage, final_damage]
			else:
				detail_text += "\n  最终造成 %d 点真实伤害" % final_damage
		
		detail_text += "\n  总伤害：%d" % total_value
	else:
		# 【惊鸿·愈】模式
		detail_text += "\n  【惊鸿·愈】模式（生命值<50%）"
		detail_text += "\n  为所有己方单位恢复生命值"
		
		# 显示对每个己方目标的治疗计算过程
		for result in results:
			var target_name = result.get("target_name", "己方")
			var base_heal = result.get("base_heal", 0)
			var current_health = result.get("current_health", 0)
			var caster_attack = result.get("caster_attack", 400) # 默认杨玉环攻击力
			var actual_heal = result.get("heal_amount", 0)
			
			detail_text += "\n  为 %s 恢复生命值：" % target_name
			detail_text += "\n  计算公式：(0.3 × 攻击力%d + 0.2 × 当前生命值%d) = %d" % [caster_attack, current_health, base_heal]
			detail_text += "\n  实际恢复：%d 点" % actual_heal
			
			# 显示治疗后的生命值
			if result.has("old_health") and result.has("new_health"):
				detail_text += "\n  生命值：%d → %d" % [result.get("old_health", 0), result.get("new_health", 0)]
		
		detail_text += "\n  总恢复量：%d" % total_value
	
	add_message(detail_text, "skill")

## 添加杨玉环被动技能的详细消息
func add_yangyuhuan_passive(character: String, skill_name: String, effect: String, details: Dictionary = {}):
	var detail_text = "%s 的被动技能「%s」发动：" % [character, skill_name]
	
	# 格式化原始效果描述
	detail_text += "\n  %s" % effect
	
	# 如果有详细信息，显示伤害计算过程
	if not details.is_empty():
		if details.has("additional_damage") and details.has("additional_target"):
			var additional_damage = details.get("additional_damage", 0)
			var additional_target = details.get("additional_target", "")
			var main_target_damage = details.get("main_target_damage", 0)
			
			detail_text += "\n  释放主动技能后，下一次普通攻击触发额外伤害"
			detail_text += "\n  对主目标造成伤害：%d" % main_target_damage
			detail_text += "\n  额外伤害计算：%d × 70%% = %d" % [main_target_damage, additional_damage]
			detail_text += "\n  随机目标：%s" % additional_target
			detail_text += "\n  最终额外伤害：%d" % additional_damage
	
	add_message(detail_text, "passive")
