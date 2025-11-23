extends CanvasLayer

# Ban/Pick场景脚本

@onready var header_label: Label = $MainContainer/Header/HeaderLabel
@onready var turn_indicator: Label = $MainContainer/TurnIndicator/TurnLabel
@onready var card_grid: GridContainer = $MainContainer/ContentContainer/CardArea/CardGrid
@onready var blue_team_container: VBoxContainer = $MainContainer/ContentContainer/InfoArea/SelectedCards/TeamContainer/BlueTeamContainer/BlueTeam
@onready var red_team_container: VBoxContainer = $MainContainer/ContentContainer/InfoArea/SelectedCards/TeamContainer/RedTeamContainer/RedTeam
@onready var blue_bans_container: VBoxContainer = $MainContainer/ContentContainer/InfoArea/BannedCards/BansContainer/BlueBansContainer/BlueBans
@onready var red_bans_container: VBoxContainer = $MainContainer/ContentContainer/InfoArea/BannedCards/BansContainer/RedBansContainer/RedBans
@onready var start_battle_button: Button = $MainContainer/ButtonContainer/StartBattleButton

var ban_pick_manager: BanPickManager
var card_ui_scene = preload("res://scenes/components/BanPickCardUI.tscn")
var card_ui_instances: Array = []
var error_popup_scene = preload("res://scenes/ui/ErrorPopup.tscn")

func _ready():
	print("Ban/Pick场景已加载")
	initialize_ban_pick()
	
	# 监听窗口大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# 初始化时调整布局
	call_deferred("adjust_layout")

func initialize_ban_pick():
	# 创建BanPickManager实例
	ban_pick_manager = BanPickManager.new()
	add_child(ban_pick_manager)
	
	# 初始化卡牌
	ban_pick_manager.initialize_cards()
	
	# 创建卡牌UI
	create_card_grid()
	
	# 更新UI
	update_turn_indicator()
	
	# 连接按钮信号
	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_pressed)

func create_card_grid():
	# 确保card_grid节点存在
	if not card_grid:
		print("错误: card_grid节点未找到")
		return
		
	# 清空现有卡牌
	for child in card_grid.get_children():
		child.queue_free()
	card_ui_instances.clear()
	
	# 创建卡牌UI实例
	for card in ban_pick_manager.all_cards:
		var card_ui = card_ui_scene.instantiate()
		card_ui.set_card(card)
		card_ui.card_clicked.connect(_on_card_clicked)
		card_grid.add_child(card_ui)
		card_ui_instances.append(card_ui)
	
	# 调整卡牌网格布局
	adjust_card_grid_layout()

func update_turn_indicator():
	if not turn_indicator:
		return
	
	var phase_description = ban_pick_manager.get_current_phase_description()
	turn_indicator.text = "当前回合: %s" % phase_description

func _on_card_clicked(card_ui):
	if not card_ui or not card_ui.get_card():
		return
	
	var card = card_ui.get_card()
	
	# 根据当前阶段处理点击
	match ban_pick_manager.current_phase:
		BanPickManager.Phase.BLUE_PICK_1, BanPickManager.Phase.BLUE_PICK_2, BanPickManager.Phase.BLUE_PICK_3:
			# 蓝方选择
			if ban_pick_manager.select_card(card):
				card_ui.set_card_state(BanPickCardUI.CardState.SELECTED_BLUE)
				update_turn_indicator()
				# 更新队伍显示
				update_team_display()
			else:
				show_error_message("无法选择已禁用的英雄")
		BanPickManager.Phase.RED_PICK_1, BanPickManager.Phase.RED_PICK_2, BanPickManager.Phase.RED_PICK_3:
			# 红方选择
			if ban_pick_manager.select_card(card):
				card_ui.set_card_state(BanPickCardUI.CardState.SELECTED_RED)
				update_turn_indicator()
				# 更新队伍显示
				update_team_display()
			else:
				show_error_message("无法选择已禁用的英雄")
		BanPickManager.Phase.BLUE_BAN, BanPickManager.Phase.RED_BAN:
			# 禁用阶段
			if ban_pick_manager.ban_card(card.card_id):
				card_ui.set_card_state(BanPickCardUI.CardState.BANNED)
				update_turn_indicator()
				# 更新禁用显示
				update_ban_display()
			else:
				show_error_message("无法禁用已禁用的英雄")

func update_team_display():
	# 更新蓝方队伍显示
	for child in blue_team_container.get_children():
		child.queue_free()
	
	for card in ban_pick_manager.blue_team:
		var label = Label.new()
		label.text = card.card_name
		label.add_theme_color_override("font_color", Color(0.4, 0.6, 1, 1))  # 蓝色
		blue_team_container.add_child(label)
	
	# 更新红方队伍显示
	for child in red_team_container.get_children():
		child.queue_free()
	
	for card in ban_pick_manager.red_team:
		var label = Label.new()
		label.text = card.card_name
		label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))  # 红色
		red_team_container.add_child(label)

func update_ban_display():
	# 清空禁用显示容器
	for child in blue_bans_container.get_children():
		child.queue_free()
	for child in red_bans_container.get_children():
		child.queue_free()
	
	# 红蓝两方的禁用卡片分开显示
	if ban_pick_manager.current_phase > BanPickManager.Phase.BLUE_BAN:
		# 蓝方禁用
		if ban_pick_manager.banned_cards.size() > 0:
			var card = CardDatabase.get_card(ban_pick_manager.banned_cards[0])
			if card:
				var label = Label.new()
				label.text = card.card_name
				label.add_theme_color_override("font_color", Color(0.4, 0.6, 1, 1))  # 蓝色
				blue_bans_container.add_child(label)
	
	if ban_pick_manager.current_phase > BanPickManager.Phase.RED_BAN:
		# 红方禁用
		if ban_pick_manager.banned_cards.size() > 1:
			var card = CardDatabase.get_card(ban_pick_manager.banned_cards[1])
			if card:
				var label = Label.new()
				label.text = card.card_name
				label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))  # 红色
				red_bans_container.add_child(label)

func _on_start_battle_pressed():
	# 直接开始战斗（用于测试）
	ban_pick_manager.start_battle()

func show_error_message(message: String):
	var popup = error_popup_scene.instantiate()
	popup.set_message(message)
	add_child(popup)
	popup.popup_centered()

# 响应窗口大小变化
func _on_viewport_size_changed():
	print("窗口大小变化，调整布局")
	adjust_layout()

# 调整整体布局
func adjust_layout():
	# 确保节点已初始化
	if not is_node_ready():
		await ready
	
	# 调整卡牌网格布局
	adjust_card_grid_layout()
	
	# 将卡牌区域整体向屏幕中心移动
	adjust_content_position()
	
	# 调整头部和按钮大小
	adjust_header_and_buttons()
	
	# 将整体布局向屏幕中心移动
	var main_container = $MainContainer
	if main_container:
		var viewport_size = get_viewport().get_visible_rect().size
		
		# 根据屏幕高度调整上下边距
		var window_height = viewport_size.y
		var content_height = main_container.get_minimum_size().y
		
		# 计算并设置上下边距，使内容垂直居中
		var top_margin = max(0, (window_height - content_height) / 2 * 0.1)  # 上边距为差值的10%
		
		# 调整主容器的边距
		main_container.add_theme_constant_override("margin_top", top_margin)
		
		print("将整体布局向屏幕中心移动 - 屏幕高度: %d, 内容高度: %d, 上边距: %d" % [window_height, content_height, top_margin])

# 调整卡牌网格布局
func adjust_card_grid_layout():
	if not card_grid:
		return
	
	# 获取当前窗口大小
	var viewport_size = get_viewport().get_visible_rect().size
	print("当前窗口大小: %s" % viewport_size)
	
	# 针对1920*1080分辨率进行优化
	var is_full_hd = viewport_size.x >= 1920 and viewport_size.y >= 1080
	
	# 设置卡牌网格间距
	var h_separation = 15  # 默认间距
	var v_separation = 20  # 默认间距
	
	if is_full_hd:
		# 在高分辨率下增大间距
		h_separation = 25
		v_separation = 30
	
	# 调整网格间距
	card_grid.add_theme_constant_override("h_separation", h_separation)
	card_grid.add_theme_constant_override("v_separation", v_separation)
	
	# 调整网格居中对齐
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 调整网格在卡牌区域中的位置
	var card_area = $MainContainer/ContentContainer/CardArea
	if card_area:
		var card_grid_label = $MainContainer/ContentContainer/CardArea/CardGridLabel
		if card_grid_label:
			card_grid_label.custom_minimum_size.y = 40
			card_grid_label.add_theme_font_size_override("font_size", 20)
	
	print("调整卡牌网格间距 - 水平间距: %d, 垂直间距: %d" % [h_separation, v_separation])

# 调整内容容器位置，将卡牌区域整体向屏幕中心移动
func adjust_content_position():
	var content_container = $MainContainer/ContentContainer
	if not content_container:
		return
	
	# 获取当前窗口大小
	var viewport_size = get_viewport().get_visible_rect().size
	
	# 根据窗口大小调整内容区域的margin
	var left_margin = viewport_size.x * 0.05  # 左侧边距为屏幕宽度5%
	var right_margin = viewport_size.x * 0.05  # 右侧边距为屏幕宽度5%
	
	# 设置内容容器的边距
	content_container.add_theme_constant_override("margin_left", left_margin)
	content_container.add_theme_constant_override("margin_right", right_margin)
	
	# 添加上下边距来实现垂直居中
	var top_margin = viewport_size.y * 0.08  # 上边距为屏幕高度8%
	content_container.add_theme_constant_override("margin_top", top_margin)
	
	# 调整卡牌区域与信息区域的比例
	var card_area = $MainContainer/ContentContainer/CardArea
	var info_area = $MainContainer/ContentContainer/InfoArea
	if card_area and info_area:
		card_area.size_flags_stretch_ratio = 2.5  # 增加卡牌区域的比例权重
		info_area.size_flags_stretch_ratio = 1.0  # 信息区域保持标准比例
	
	print("调整内容区域位置 - 左边距: %d, 右边距: %d, 上边距: %d" % [left_margin, right_margin, top_margin])

# 调整头部和按钮大小
func adjust_header_and_buttons():
	# 调整标题字体大小
	if header_label:
		header_label.add_theme_font_size_override("font_size", 28)
	
	# 调整回合指示器字体大小
	if turn_indicator:
		turn_indicator.custom_minimum_size.y = 40
	
	# 调整回合标签字体大小
	if turn_indicator and turn_indicator.get_node("TurnLabel"):
		turn_indicator.get_node("TurnLabel").add_theme_font_size_override("font_size", 20)
	
	# 调整按钮大小
	if start_battle_button:
		start_battle_button.custom_minimum_size = Vector2(240, 60)
		start_battle_button.add_theme_font_size_override("font_size", 22)
	
	# 调整间距占位空间
	var spacer1 = $MainContainer/Spacer1
	var spacer2 = $MainContainer/Spacer2
	var spacer3 = $MainContainer/Spacer3
	var spacer4 = $MainContainer/Spacer4
	
	if spacer1:
		spacer1.custom_minimum_size.y = 20
	
	if spacer2:
		spacer2.custom_minimum_size.y = 10
	
	if spacer3:
		spacer3.custom_minimum_size.y = 20
	
	if spacer4:
		spacer4.custom_minimum_size.y = 20
	
	# 调整主容器的间距
	var main_container = $MainContainer
	if main_container:
		main_container.add_theme_constant_override("separation", 5)
