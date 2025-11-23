extends Panel

## 卡牌详细信息弹窗

var card_data: Card

var title_label: Label
var content_label: RichTextLabel
var close_button: Button

func _ready():
	# 创建UI
	setup_ui()
	print("🐛 [CardInfoPopup] _ready完成，UI已创建")

func setup_ui():
	# 设置面板样式
	custom_minimum_size = Vector2(400, 500)
	position = Vector2(460, 110)  # 居中显示
	
	# 创建标题
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.position = Vector2(10, 10)
	title_label.size = Vector2(380, 40)
	add_child(title_label)
	
	# 创建内容区域（使用RichTextLabel支持格式化）
	content_label = RichTextLabel.new()
	content_label.bbcode_enabled = true
	content_label.position = Vector2(10, 60)
	content_label.size = Vector2(380, 380)
	content_label.scroll_following = false
	add_child(content_label)
	
	# 创建关闭按钮
	close_button = Button.new()
	close_button.text = "关闭"
	close_button.position = Vector2(150, 450)
	close_button.size = Vector2(100, 40)
	close_button.pressed.connect(_on_close_pressed)
	add_child(close_button)

func show_card(card: Card):
	if not card:
		print("❌ CardInfoPopup: 卡牌为空")
		return
	
	# 🐛 验证UI组件
	if not title_label:
		print("❌ title_label未初始化！")
		return
	if not content_label:
		print("❌ content_label未初始化！")
		return
	
	card_data = card
	
	# 设置标题
	title_label.text = card.card_name
	print("🐛 标题已设置: %s" % title_label.text)
	
	# 🐛 详细调试输出
	print("============================================================")
	print("🐛 [CardInfoPopup] 显示卡牌详情")
	print("   卡牌名: [%s]" % card.card_name)
	print("   卡牌ID: [%s]" % card.card_id)
	print("   技能名: [%s] (长度:%d)" % [card.skill_name, card.skill_name.length()])
	print("   技能效果: [%s] (长度:%d)" % [card.skill_effect, card.skill_effect.length()])
	print("   被动名: [%s] (长度:%d)" % [card.passive_skill_name, card.passive_skill_name.length()])
	print("   被动效果: [%s] (长度:%d)" % [card.passive_skill_effect, card.passive_skill_effect.length()])
	print("============================================================")
	
	# 构建详细信息文本
	var info_text = ""
	
	# 基础属性
	info_text += "[b][color=yellow]═══ 基础属性 ═══[/color][/b]\n"
	info_text += "生命值: [color=green]%d/%d[/color]\n" % [card.health, card.max_health]
	info_text += "攻击力: [color=red]%d[/color]\n" % card.attack
	info_text += "护甲: [color=cyan]%d[/color]\n" % card.armor
	
	if card.shield > 0:
		info_text += "护盾: [color=aqua]%d[/color]\n" % card.shield
	
	info_text += "\n"
	
	# 暴击属性
	info_text += "[b][color=yellow]═══ 暴击属性 ═══[/color][/b]\n"
	info_text += "暴击率: [color=orange]%.1f%%[/color]\n" % (card.crit_rate * 100)
	info_text += "暴击效果: [color=orange]%.1f%%[/color]\n" % (card.crit_damage * 100)
	
	# 🐛 公孙离闪避率显示
	if card.card_name == "公孙离":
		print("🐛 公孙离特殊属性检查")
		if card.has_method("get_gongsunli_dodge_rate"):
			var dodge_rate = card.get_gongsunli_dodge_rate()
			if dodge_rate > 0:
				info_text += "闪避率: [color=lime]%.1f%%[/color]\n" % (dodge_rate * 100)
			print("🐛 公孙离闪避率: %.1f%%" % (dodge_rate * 100))
		else:
			print("🐛 公孙离没有get_gongsunli_dodge_rate方法")
	
	info_text += "\n"
	
	# 主动技能
	info_text += "[b][color=yellow]═══ 主动技能 ═══[/color][/b]\n"
	info_text += "[color=aqua]%s[/color] (消耗%d点)\n" % [card.skill_name, card.skill_cost]
	info_text += "%s\n" % card.skill_effect
	info_text += "\n"
	
	# 被动技能
	if card.passive_skill_name and card.passive_skill_name != "":
		info_text += "[b][color=yellow]═══ 被动技能 ═══[/color][/b]\n"
		info_text += "[color=magenta]%s[/color]\n" % card.passive_skill_name
		info_text += "%s\n" % card.passive_skill_effect
		info_text += "\n"
	
	# 当前状态
	info_text += "[b][color=yellow]═══ 当前状态 ═══[/color][/b]\n"
	
	if card.is_stunned:
		info_text += "[color=gray]眩晕 (剩余%d回合)[/color]\n" % card.stun_turns
	
	if card.is_poisoned:
		info_text += "[color=purple]中毒 (每回合%d伤害)[/color]\n" % card.poison_damage
	
	if card.damage_bonus > 0:
		info_text += "[color=red]增伤: +%.1f%%[/color]\n" % (card.damage_bonus * 100)
	
	# 特殊状态显示
	if card.card_name == "少司缘":
		var stolen = card.get_shaosiyuan_stolen_points() if card.has_method("get_shaosiyuan_stolen_points") else 0
		info_text += "[color=yellow]已偷取技能点: %d[/color]\n" % stolen
	
	if card.card_name == "杨玉环" and card.yangyuhuan_skill_used:
		info_text += "[color=pink]技能标记: 已激活[/color]\n"
	
	if not card.can_attack:
		info_text += "[color=gray]本回合无法攻击[/color]\n"
	
	if card.is_dead():
		info_text += "[color=darkred]【已阵亡】[/color]\n"
	
	# 设置内容
	print("🐛 准备设置RichTextLabel内容，文本长度: %d" % info_text.length())
	content_label.text = info_text
	print("🐛 RichTextLabel内容已设置")
	print("🐛 RichTextLabel可见性: %s" % content_label.visible)
	print("🐛 RichTextLabel尺寸: %s" % content_label.size)
	
	# 显示弹窗
	visible = true
	print("🐛 弹窗visible设置为true")

func _on_close_pressed():
	queue_free()
