extends Control

## 2v2卡牌选择系统
## 实现先手决定、卡牌选择流程和战斗准备

# 预加载中文字体
var chinese_font = preload("res://assets/fonts/Arial Unicode.ttf")

# 基准分辨率和缩放因子
var base_resolution := Vector2(1280, 720)
var current_scale_factor: float = 1.0

# UI组件
var title_label: Label
var status_label: Label
var cards_container: HBoxContainer
var selection_info_label: Label
var confirm_button: Button
var back_button: Button

# 用于自适应布局的容器
var main_container: VBoxContainer
var scroll_container: ScrollContainer
var content_container: VBoxContainer
var button_area: HBoxContainer

# 选择状态
enum SelectionPhase {
	DETERMINING_FIRST,  # 决定先手
	PLAYER1_PICK,       # 玩家1选择
	PLAYER2_PICK,       # 玩家2选择
	SELECTION_COMPLETE  # 选择完成
}

var current_phase: SelectionPhase = SelectionPhase.DETERMINING_FIRST
var first_player: int = 1  # 1或2，表示先手玩家
var current_player: int = 1
var picks_remaining: int = 0

# 卡牌数据
var available_cards: Array = []
var card_uis: Array = []
var selected_cards: Dictionary = {"player1": [], "player2": []}
var current_selection: Array = []

# 信号
signal card_selection_completed(player1_cards: Array, player2_cards: Array, first_player: int)

func _ready():
	# 监听窗口大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# 初始化自适应布局
	calculate_scale_factor()
	
	setup_ui()
	initialize_cards()
	start_selection_process()

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
	print("更新卡牌选择界面布局")
	
	# 重新设置UI元素的尺寸和字体大小
	update_ui_elements()

## 更新UI元素尺寸和字体大小
func update_ui_elements():
	if not is_inside_tree():
		return
	
	# 更新标题字体大小
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(32 * current_scale_factor))
	
	# 更新状态标签字体大小
	if status_label:
		status_label.add_theme_font_size_override("font_size", int(18 * current_scale_factor))
	
	# 更新选择信息标签字体大小
	if selection_info_label:
		selection_info_label.add_theme_font_size_override("font_size", int(16 * current_scale_factor))
	
	# 更新按钮尺寸
	if confirm_button:
		confirm_button.custom_minimum_size = Vector2(int(120 * current_scale_factor), int(40 * current_scale_factor))
		confirm_button.add_theme_font_size_override("font_size", int(16 * current_scale_factor))
	
	if back_button:
		back_button.custom_minimum_size = Vector2(int(100 * current_scale_factor), int(40 * current_scale_factor))
		back_button.add_theme_font_size_override("font_size", int(16 * current_scale_factor))
	
	# 更新卡牌UI尺寸
	for card_ui in card_uis:
		if is_instance_valid(card_ui):
			card_ui.custom_minimum_size = Vector2(int(160 * current_scale_factor), int(220 * current_scale_factor))
			
			var card_button = card_ui.get_meta("card_button", null)
			if card_button:
				card_button.custom_minimum_size = Vector2(int(150 * current_scale_factor), int(180 * current_scale_factor))

## 初始化UI组件
func setup_ui():
	print("设置2v2卡牌选择UI...")
	
	# 移除原有的固定布局，创建自适应布局
	for child in get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# 创建主容器
	main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(20 * current_scale_factor))
	main_container.add_theme_constant_override("separation", int(15 * current_scale_factor))
	add_child(main_container)
	
	# 创建背景
	var background = ColorRect.new()
	background.color = Color(0.2, 0.2, 0.3, 1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(background)
	
	# 标题区域
	var title_area = VBoxContainer.new()
	title_area.add_theme_constant_override("separation", int(5 * current_scale_factor))
	main_container.add_child(title_area)
	
	# 标题
	title_label = Label.new()
	title_label.text = "2v2 卡牌选择"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", chinese_font)
	title_label.add_theme_font_size_override("font_size", int(32 * current_scale_factor))
	title_area.add_child(title_label)
	
	# 状态标签
	status_label = Label.new()
	status_label.text = "正在决定先手..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_override("font", chinese_font)
	status_label.add_theme_font_size_override("font_size", int(18 * current_scale_factor))
	title_area.add_child(status_label)
	
	# 分隔符
	var separator = HSeparator.new()
	main_container.add_child(separator)
	
	# 内容滚动容器，解决内容溢出问题
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_container.add_child(scroll_container)
	
	# 内容容器
	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", int(15 * current_scale_factor))
	scroll_container.add_child(content_container)
	
	# 卡牌区域
	var card_area = VBoxContainer.new()
	card_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(card_area)
	
	# 卡牌容器
	cards_container = HBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_container.add_theme_constant_override("separation", int(10 * current_scale_factor))
	card_area.add_child(cards_container)
	
	# 信息区域
	var info_area = VBoxContainer.new()
	content_container.add_child(info_area)
	
	# 选择信息标签
	selection_info_label = Label.new()
	selection_info_label.text = "选择信息将在这里显示"
	selection_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_info_label.add_theme_font_override("font", chinese_font)
	selection_info_label.add_theme_font_size_override("font_size", int(16 * current_scale_factor))
	info_area.add_child(selection_info_label)
	
	# 按钮区域
	button_area = HBoxContainer.new()
	button_area.alignment = BoxContainer.ALIGNMENT_CENTER
	button_area.add_theme_constant_override("separation", int(20 * current_scale_factor))
	main_container.add_child(button_area)
	
	# 确认按钮
	confirm_button = Button.new()
	confirm_button.text = "确认选择"
	confirm_button.disabled = true
	confirm_button.custom_minimum_size = Vector2(int(120 * current_scale_factor), int(40 * current_scale_factor))
	confirm_button.add_theme_font_override("font", chinese_font)
	confirm_button.add_theme_font_size_override("font_size", int(16 * current_scale_factor))
	confirm_button.pressed.connect(_on_confirm_pressed)
	button_area.add_child(confirm_button)
	
	# 返回按钮
	back_button = Button.new()
	back_button.text = "返回"
	back_button.custom_minimum_size = Vector2(int(100 * current_scale_factor), int(40 * current_scale_factor))
	back_button.add_theme_font_override("font", chinese_font)
	back_button.add_theme_font_size_override("font_size", int(16 * current_scale_factor))
	back_button.pressed.connect(_on_back_pressed)
	button_area.add_child(back_button)
	
	print("UI组件设置完成")

## 显示卡牌选择界面
func display_cards():
	print("显示卡牌选择界面...")
	print("当前可选卡牌数量: %d" % available_cards.size())
	
	# 清空现有卡牌UI
	for ui in card_uis:
		if is_instance_valid(ui):
			ui.queue_free()
	card_uis.clear()
	
	# 验证卡牌数据有效性
	if available_cards.is_empty():
		print("警告: 没有可用卡牌")
		return
	
	# 创建卡牌UI
	for i in range(available_cards.size()):
		var card = available_cards[i]
		if not card:
			print("警告: 第%d张卡牌为空" % i)
			continue
			
		var card_ui = create_card_ui(card, i)
		if card_ui:
			cards_container.add_child(card_ui)
			card_uis.append(card_ui)
			print("创建卡牌UI: %s (索引: %d)" % [card.card_name, i])
	
	print("卡牌UI创建完成，共%d个UI组件" % card_uis.size())

## 创建单张卡牌UI
func create_card_ui(card: Card, index: int) -> Control:
	if not card:
		print("错误: 卡牌数据为空")
		return null
	
	print("创建卡牌UI: %s (索引: %d)" % [card.card_name, index])
	
	# 验证卡牌数据完整性
	if not card.card_name or card.card_name.is_empty():
		print("警告: 卡牌名称为空")
		return null
	
	# 创建卡牌容器
	var card_container = VBoxContainer.new()
	card_container.custom_minimum_size = Vector2(int(160 * current_scale_factor), int(220 * current_scale_factor))
	card_container.add_theme_constant_override("separation", int(5 * current_scale_factor))
	
	# 创建卡牌按钮
	var card_button = Button.new()
	card_button.custom_minimum_size = Vector2(int(150 * current_scale_factor), int(180 * current_scale_factor))
	card_button.text = ""
	
	# 创建卡牌内容容器
	var card_content = VBoxContainer.new()
	card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_content.add_theme_constant_override("separation", int(2 * current_scale_factor))
	
	# 卡牌图片
	var card_image = TextureRect.new()
	card_image.custom_minimum_size = Vector2(int(120 * current_scale_factor), int(80 * current_scale_factor))
	card_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 加载卡牌图片
	var image_name = ""
	match card.card_name:
		"朵莉亚":
			image_name = "duoliya"
		"澜":
			image_name = "lan"
		"公孙离":
			image_name = "gongsunli"
		"孙尚香":
			image_name = "sunshangxiang"
		_:
			image_name = card.card_name.to_lower()
	
	var image_path = "res://assets/images/cards/%s.png" % image_name
	if ResourceLoader.exists(image_path):
		var texture = load(image_path)
		card_image.texture = texture
	else:
		print("警告: 卡牌图片不存在: %s" % image_path)
	
	# 卡牌名称
	var name_label = Label.new()
	name_label.text = card.card_name if card.card_name else "未知卡牌"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", chinese_font)
	name_label.add_theme_font_size_override("font_size", int(14 * current_scale_factor))
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 卡牌属性
	var stats_label = Label.new()
	var attack_value = card.attack if "attack" in card else 0
	var health_value = card.health if "health" in card else 0
	stats_label.text = "攻击: %d | 生命: %d" % [attack_value, health_value]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_override("font", chinese_font)
	stats_label.add_theme_font_size_override("font_size", int(10 * current_scale_factor))
	stats_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 技能信息
	var skill_label = Label.new()
	var skill_name = card.skill_name if "skill_name" in card and card.skill_name else "未知技能"
	skill_label.text = "技能: %s" % skill_name
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.add_theme_font_override("font", chinese_font)
	skill_label.add_theme_font_size_override("font_size", int(9 * current_scale_factor))
	skill_label.add_theme_color_override("font_color", Color.CYAN)
	skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 组装UI
	card_content.add_child(card_image)
	card_content.add_child(name_label)
	card_content.add_child(stats_label)
	card_content.add_child(skill_label)
	
	card_button.add_child(card_content)
	card_container.add_child(card_button)
	
	# 连接点击事件
	card_button.pressed.connect(_on_card_selected.bind(index))
	
	# 设置用户数据
	card_container.set_meta("card_index", index)
	card_container.set_meta("card_button", card_button)
	card_container.set_meta("selected", false)
	
	print("卡牌UI创建成功: %s" % card.card_name)
	return card_container

## 更新选择UI状态
func update_selection_ui():
	# 安全检查：确保UI组件已初始化
	if not status_label or not is_instance_valid(status_label):
		print("警告: status_label未初始化，无法更新UI")
		return
	
	if not selection_info_label or not is_instance_valid(selection_info_label):
		print("警告: selection_info_label未初始化，无法更新UI")
		return
	
	match current_phase:
		SelectionPhase.PLAYER1_PICK:
			status_label.text = "玩家%d 的回合 - 请选择 1 张卡牌" % current_player
			selection_info_label.text = "先手玩家选择阶段：从 4 张卡牌中选择 1 张"
		SelectionPhase.PLAYER2_PICK:
			status_label.text = "玩家%d 的回合 - 请选择 2 张卡牌" % current_player
			selection_info_label.text = "后手玩家选择阶段：从剩余卡牌中选择 2 张"
		SelectionPhase.SELECTION_COMPLETE:
			status_label.text = "卡牌选择完成！"
			selection_info_label.text = "准备进入战斗..."
	
	# 更新确认按钮状态
	if confirm_button and is_instance_valid(confirm_button):
		var can_confirm = (picks_remaining == 0) or (current_selection.size() == picks_remaining)
		confirm_button.disabled = not can_confirm
		
		# 更新按钮尺寸
		confirm_button.custom_minimum_size = Vector2(int(120 * current_scale_factor), int(40 * current_scale_factor))
	
	if back_button and is_instance_valid(back_button):
		back_button.custom_minimum_size = Vector2(int(100 * current_scale_factor), int(40 * current_scale_factor))

## 初始化可选卡牌
func initialize_cards():
	print("初始化2v2可选卡牌...")
	
	# 从CardDatabase获取所有卡牌
	var card_database = get_node("/root/CardDatabase")
	if card_database:
		available_cards = card_database.get_all_cards()
		print("从CardDatabase加载了%d张可选卡牌" % available_cards.size())
	else:
		print("警告: 无法获取CardDatabase，使用备用卡牌")
		# 直接创建4张卡牌
		available_cards = [
			create_fallback_card(0),    # 朵莉亚
			create_fallback_card(1),    # 澜
			create_fallback_card(2),    # 公孙离
			create_fallback_card(3)     # 孙尚香
		]
	
	print("初始化了%d张可选卡牌" % available_cards.size())

## 加载卡牌图片资源的辅助函数
func load_card_image(card_name: String) -> Texture2D:
	var image_name = ""
	match card_name:
		"朵莉亚":
			image_name = "duoliya"
		"澜":
			image_name = "lan"
		"公孙离":
			image_name = "gongsunli"
		"孙尚香":
			image_name = "sunshangxiang"
		_:
			image_name = card_name.to_lower()
	
	var image_path = "res://assets/images/cards/%s.png" % image_name
	if ResourceLoader.exists(image_path):
		return load(image_path)
	else:
		print("警告: 卡牌图片不存在: %s" % image_path)
		return null

## 创建备用卡牌
func create_fallback_card(index: int) -> Card:
	match index:
		0:
			var card_image = load_card_image("朵莉亚")
			return Card.new("朵莉亚", "可爱的朵朵。", 300, 900, 300, "人鱼之赐", "为选择的队友恢复130点生命值。", card_image, "欢歌", "每回合开始时，为朵莉亚自己恢复75点生命值，如果恢复到满生命值，溢出的部分将会转化为自己的护盾值。", 1, false)
		1:
			var card_image = load_card_image("澜")
			return Card.new("澜", "确认目标。", 400, 700, 250, "鲨之猎刃", "增加自己攻击力100点。", card_image, "狩猎", "当选中的攻击目标生命值低于其最大生命值的50%时，澜对他造成的伤害额外增加30%。", 2, false)
		2:
			var card_image = load_card_image("公孙离")
			return Card.new("公孙离", "送你冰心一片。", 600, 600, 150, "晚云落", "增加自己35%暴击率。", card_image, "霜叶舞", "敌方在选择公孙离为攻击单位时，公孙离有30%的概率闪避此次攻击，即受到0点伤害。", 3, false)
		3:
			var card_image = load_card_image("孙尚香")
			return Card.new("孙尚香", "本小姐才是你在废墟中唯一的信仰。", 550, 625, 175, "红莲爆弹", "选择一名敌方单位，永久性的减少其50点护甲值，并对其造成50点真实伤害。", card_image, "千金重弩", "每次普通攻击命中敌人时，都会获得1点技能点。", 1, true)
		_:
			return Card.new("未知卡牌", "备用卡牌", 300, 300, 100, "未知技能", "未知效果", null, "", "", 2, false)

## 开始选择流程
func start_selection_process():
	print("开始2v2卡牌选择流程...")
	
	# 随机决定先手
	determine_first_player()

## 随机决定先手玩家
func determine_first_player():
	print("随机决定先手玩家...")
	current_phase = SelectionPhase.DETERMINING_FIRST
	
	# 安全检查：确保status_label已初始化
	if status_label and is_instance_valid(status_label):
		status_label.text = "正在决定先手..."
	else:
		print("警告: status_label未初始化")
		# 尝试重新获取引用
		await get_tree().process_frame
		setup_ui()
		await get_tree().process_frame
	
	# 创建随机决定动画效果
	await get_tree().create_timer(1.0).timeout
	
	# 随机选择先手（50%概率）
	first_player = randi() % 2 + 1
	
	print("先手玩家决定：玩家%d" % first_player)
	
	# 再次安全检查
	if status_label and is_instance_valid(status_label):
		status_label.text = "玩家%d 获得先手权！" % first_player
	
	await get_tree().create_timer(1.5).timeout
	
	# 开始卡牌选择
	start_card_picking()

## 开始卡牌选择
func start_card_picking():
	print("开始卡牌选择阶段...")
	
	# 显示所有卡牌
	display_cards()
	
	# 开始第一阶段：先手玩家选择1张
	current_player = first_player
	picks_remaining = 1
	current_phase = SelectionPhase.PLAYER1_PICK
	
	update_selection_ui()

## 处理卡牌选择
func _on_card_selected(card_index: int):
	# 安全检查
	if card_index < 0 or card_index >= available_cards.size():
		print("错误: 卡牌索引越界: %d" % card_index)
		return
	
	if card_index >= card_uis.size():
		print("错误: 卡牌UI索引越界: %d" % card_index)
		return
	
	var card_ui = card_uis[card_index]
	var is_selected = card_ui.get_meta("selected", false)
	
	if is_selected:
		# 取消选择
		deselect_card(card_index)
	else:
		# 选择卡牌
		select_card(card_index)

## 选择卡牌
func select_card(card_index: int):
	# 安全检查
	if card_index < 0 or card_index >= available_cards.size() or card_index >= card_uis.size():
		print("错误: 无效的卡牌索引: %d" % card_index)
		return
	
	# 检查是否已达到选择上限
	if current_selection.size() >= picks_remaining:
		# 先取消之前的选择
		if current_selection.size() > 0:
			deselect_card(current_selection[0])
	
	# 添加到当前选择
	current_selection.append(card_index)
	
	# 更新UI
	var card_ui = card_uis[card_index]
	var card_button = card_ui.get_meta("card_button")
	card_button.modulate = Color.GREEN
	card_ui.set_meta("selected", true)
	
	update_selection_ui()

## 取消选择卡牌
func deselect_card(card_index: int):
	# 安全检查
	if card_index < 0 or card_index >= available_cards.size() or card_index >= card_uis.size():
		print("错误: 无效的卡牌索引: %d" % card_index)
		return
	
	# 从当前选择中移除
	current_selection.erase(card_index)
	
	# 更新UI
	var card_ui = card_uis[card_index]
	var card_button = card_ui.get_meta("card_button")
	card_button.modulate = Color.WHITE
	card_ui.set_meta("selected", false)
	
	update_selection_ui()

## 确认选择
func _on_confirm_pressed():
	if current_selection.size() != picks_remaining:
		print("选择数量不正确: %d/%d" % [current_selection.size(), picks_remaining])
		return
	
	print("确认选择: 玩家%d 选择了 %d 张卡牌" % [current_player, current_selection.size()])
	
	# 记录选择（按索引从大到小排序，避免删除时索引混乱）
	var sorted_selection = current_selection.duplicate()
	sorted_selection.sort()
	sorted_selection.reverse()  # 从大到小排序
	
	var player_key = "player%d" % current_player
	for card_index in current_selection:
		selected_cards[player_key].append(available_cards[card_index])
		print("  - %s" % available_cards[card_index].card_name)
	
	# 从可选卡牌中移除已选择的（从大到小删除，避免索引混乱）
	for card_index in sorted_selection:
		available_cards.remove_at(card_index)
		card_uis[card_index].queue_free()
		card_uis.remove_at(card_index)
	
	# 重新显示剩余卡牌
	await get_tree().process_frame
	display_cards()
	
	current_selection.clear()
	
	# 进入下一阶段
	proceed_to_next_phase()

## 进入下一选择阶段
func proceed_to_next_phase():
	match current_phase:
		SelectionPhase.PLAYER1_PICK:
			# 切换到玩家2选择2张
			current_player = 3 - first_player  # 如果先手是1，则后手是2；反之亦然
			picks_remaining = 2
			current_phase = SelectionPhase.PLAYER2_PICK
			update_selection_ui()
			
		SelectionPhase.PLAYER2_PICK:
			# 自动分配剩余卡牌给先手玩家
			var first_player_key = "player%d" % first_player
			if available_cards.size() > 0:
				selected_cards[first_player_key].append(available_cards[0])
				print("自动分配给玩家%d: %s" % [first_player, available_cards[0].card_name])
			
			current_phase = SelectionPhase.SELECTION_COMPLETE
			complete_selection()

## 完成选择
func complete_selection():
	print("卡牌选择完成！")
	update_selection_ui()
	
	# 清空卡牌显示
	for ui in card_uis:
		if is_instance_valid(ui):
			ui.queue_free()
	card_uis.clear()
	
	# 显示最终选择结果
	show_final_selection()
	
	# 等待一段时间后自动进入战斗
	await get_tree().create_timer(3.0).timeout
	start_battle()

## 显示最终选择结果
func show_final_selection():
	# 安全检查
	if not selection_info_label or not is_instance_valid(selection_info_label):
		print("警告: selection_info_label未初始化，无法显示选择结果")
		return
	
	var result_text = "选择结果:\n\n"
	
	for player_num in [1, 2]:
		var player_key = "player%d" % player_num
		result_text += "玩家%d (%s):\n" % [player_num, "先手" if player_num == first_player else "后手"]
		
		for card in selected_cards[player_key]:
			result_text += "  • %s\n" % card.card_name
		result_text += "\n"
	
	selection_info_label.text = result_text

## 开始战斗
func start_battle():
	print("准备进入战斗...")
	
	# 发送选择完成信号
	card_selection_completed.emit(
		selected_cards["player1"],
		selected_cards["player2"],
		first_player
	)
	
	# 设置全局战斗数据
	Engine.set_meta("battle_mode", "2v2_custom")
	Engine.set_meta("player1_cards", selected_cards["player1"])
	Engine.set_meta("player2_cards", selected_cards["player2"])
	Engine.set_meta("first_player", first_player)
	
	# 切换到战斗场景
	get_tree().change_scene_to_file("res://scenes/main/BattleScene.tscn")

## 返回主菜单
func _on_back_pressed():
	print("返回战斗模式选择")
	get_tree().change_scene_to_file("res://scenes/modes/BattleModeSelection.tscn")
