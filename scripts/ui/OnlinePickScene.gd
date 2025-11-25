extends CanvasLayer

## 在线模式英雄选择场景
## 使用1-2-2-1选人顺序，由服务器控制

@onready var header_label: Label = $MainContainer/Header/HeaderLabel
@onready var turn_indicator: Label = $MainContainer/TurnIndicator/TurnLabel
@onready var card_grid: GridContainer = $MainContainer/ContentContainer/CardArea/CardGrid
@onready var blue_team_container: VBoxContainer = $MainContainer/ContentContainer/InfoArea/SelectedCards/TeamContainer/BlueTeamContainer/BlueTeam
@onready var red_team_container: VBoxContainer = $MainContainer/ContentContainer/InfoArea/SelectedCards/TeamContainer/RedTeamContainer/RedTeam
@onready var start_battle_button: Button = $MainContainer/ButtonContainer/StartBattleButton

# 预加载
var card_ui_scene = preload("res://scenes/components/BanPickCardUI.tscn")
var error_popup_scene = preload("res://scenes/ui/ErrorPopup.tscn")

# 状态
var available_heroes: Array = []
var blue_picks: Array = []
var red_picks: Array = []
var current_team: String = "blue"
var is_my_turn: bool = false
var card_ui_instances: Dictionary = {}  # hero_id -> card_ui

# 选人顺序显示
var pick_order_labels = ["蓝方选第1位", "红方选第1位", "红方选第2位", "蓝方选第2位", "蓝方选第3位", "红方选第3位"]
var current_pick_index: int = 0

func _ready():
	print("🎯 在线选人场景已加载")
	
	# 隐藏开始战斗按钮（由服务器控制）
	if start_battle_button:
		start_battle_button.visible = false
	
	# 更新标题
	if header_label:
		header_label.text = "英雄选择阶段"
	
	# 连接网络信号
	_connect_network_signals()
	
	# 监听窗口大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# 🎯 检查是否有保存的选人数据（场景切换时传递）
	if Engine.has_meta("pick_phase_data"):
		var pick_data = Engine.get_meta("pick_phase_data")
		Engine.remove_meta("pick_phase_data")  # 读取后清除
		print("🎯 [UI] 从Engine读取选人数据")
		_on_pick_phase_started(pick_data)

func _connect_network_signals():
	if not NetworkManager.pick_phase_started.is_connected(_on_pick_phase_started):
		NetworkManager.pick_phase_started.connect(_on_pick_phase_started)
	if not NetworkManager.pick_updated.is_connected(_on_pick_updated):
		NetworkManager.pick_updated.connect(_on_pick_updated)
	if not NetworkManager.pick_complete.is_connected(_on_pick_complete):
		NetworkManager.pick_complete.connect(_on_pick_complete)
	if not NetworkManager.pick_failed.is_connected(_on_pick_failed):
		NetworkManager.pick_failed.connect(_on_pick_failed)
	if not NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.connect(_on_game_started)

## 选人阶段开始
func _on_pick_phase_started(data: Dictionary):
	print("🎯 [UI] 收到选人阶段开始")
	
	available_heroes = data.get("available_heroes", [])
	blue_picks = []
	red_picks = []
	current_team = data.get("current_team", "blue")
	current_pick_index = data.get("current_pick_index", 0)
	
	# 判断是否轮到我
	var is_host = NetworkManager.is_host
	is_my_turn = (current_team == "blue" and is_host) or (current_team == "red" and not is_host)
	
	# 创建卡牌UI
	_create_card_grid()
	
	# 更新回合指示
	_update_turn_indicator()

## 选人更新
func _on_pick_updated(data: Dictionary):
	print("🎯 [UI] 收到选人更新")
	
	var picked_hero = data.get("picked_hero", {})
	var picked_by = data.get("picked_by", "")
	
	# 更新已选列表
	blue_picks = data.get("blue_picks", [])
	red_picks = data.get("red_picks", [])
	available_heroes = data.get("available_heroes", [])
	current_team = data.get("current_team", "")
	current_pick_index = data.get("current_pick_index", 0)
	
	# 判断是否轮到我
	var is_host = NetworkManager.is_host
	is_my_turn = (current_team == "blue" and is_host) or (current_team == "red" and not is_host)
	
	# 更新被选中的卡牌UI状态
	var hero_id = picked_hero.get("id", "")
	if hero_id != "" and card_ui_instances.has(hero_id):
		var card_ui = card_ui_instances[hero_id]
		if picked_by == "blue":
			card_ui.set_card_state(BanPickCardUI.CardState.SELECTED_BLUE)
		else:
			card_ui.set_card_state(BanPickCardUI.CardState.SELECTED_RED)
	
	# 更新队伍显示
	_update_team_display()
	
	# 更新回合指示
	_update_turn_indicator()

## 选人完成
func _on_pick_complete(data: Dictionary):
	print("🎯 [UI] 选人完成！")
	
	blue_picks = data.get("blue_picks", [])
	red_picks = data.get("red_picks", [])
	
	# 更新队伍显示
	_update_team_display()
	
	# 更新指示
	if turn_indicator:
		turn_indicator.text = "选人完成！即将开始游戏..."

## 选人失败
func _on_pick_failed(error_msg: String):
	print("❌ [UI] 选人失败: %s" % error_msg)
	_show_error_message(error_msg)

## 游戏开始 - 切换到战斗场景
func _on_game_started(data: Dictionary):
	print("🎮 [UI] 游戏开始，切换到战斗场景")
	
	# 🎯 根据服务器发送的卡牌数量判断战斗模式
	var blue_count = data.get("blue_cards_count", 3)
	var red_count = data.get("red_cards_count", 3)
	var online_battle_mode = "online_3v3"  # 默认3v3
	
	if blue_count == 3 and red_count == 3:
		online_battle_mode = "online_3v3"
	elif blue_count == 2 and red_count == 2:
		online_battle_mode = "online_2v2"
	elif blue_count == 1 and red_count == 1:
		online_battle_mode = "online_1v1"
	
	print("🎮 在线模式: %s (蓝方%d张 vs 红方%d张)" % [online_battle_mode, blue_count, red_count])
	
	# 🎯 保存服务器发送的卡牌数据到全局，供BattleScene使用
	if data.has("blue_cards") and data.has("red_cards"):
		Engine.set_meta("online_blue_cards", data.blue_cards)
		Engine.set_meta("online_red_cards", data.red_cards)
		print("📦 保存卡牌数据: 蓝方%d张, 红方%d张" % [data.blue_cards.size(), data.red_cards.size()])
	else:
		print("⚠️ 警告：服务器未发送卡牌数据！")
	
	# 🌐 确保NetworkManager状态正确
	NetworkManager.connection_status = NetworkManager.ConnectionStatus.IN_GAME
	
	# 🛡️ 设置BattleManager
	if BattleManager != null:
		BattleManager.is_online_mode = true
		BattleManager.is_my_turn = NetworkManager.is_host
		Engine.set_meta("online_battle_mode", online_battle_mode)
		print("🌐 在线模式设置: is_host=%s, mode=%s" % [NetworkManager.is_host, online_battle_mode])
	
	# 断开信号连接
	_disconnect_network_signals()
	
	# 切换到战斗场景
	get_tree().change_scene_to_file("res://scenes/main/BattleScene.tscn")

func _disconnect_network_signals():
	if NetworkManager.pick_phase_started.is_connected(_on_pick_phase_started):
		NetworkManager.pick_phase_started.disconnect(_on_pick_phase_started)
	if NetworkManager.pick_updated.is_connected(_on_pick_updated):
		NetworkManager.pick_updated.disconnect(_on_pick_updated)
	if NetworkManager.pick_complete.is_connected(_on_pick_complete):
		NetworkManager.pick_complete.disconnect(_on_pick_complete)
	if NetworkManager.pick_failed.is_connected(_on_pick_failed):
		NetworkManager.pick_failed.disconnect(_on_pick_failed)
	if NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.disconnect(_on_game_started)

## 创建卡牌网格
func _create_card_grid():
	if not card_grid:
		print("错误: card_grid节点未找到")
		return
	
	# 清空现有卡牌
	for child in card_grid.get_children():
		child.queue_free()
	card_ui_instances.clear()
	
	# 创建卡牌UI实例（显示所有英雄，包括已选的）
	var all_heroes = _get_all_heroes()
	for hero in all_heroes:
		var card_ui = card_ui_scene.instantiate()
		
		# 创建临时卡牌数据
		var card_data = _create_card_from_hero(hero)
		card_ui.set_card(card_data)
		card_ui.card_clicked.connect(_on_card_clicked)
		card_grid.add_child(card_ui)
		
		# 保存引用
		var hero_id = hero.get("id", "")
		card_ui_instances[hero_id] = card_ui
		
		# 检查是否已被选择
		var is_picked_blue = blue_picks.any(func(h): return h.get("id") == hero_id)
		var is_picked_red = red_picks.any(func(h): return h.get("id") == hero_id)
		
		if is_picked_blue:
			card_ui.set_card_state(BanPickCardUI.CardState.SELECTED_BLUE)
		elif is_picked_red:
			card_ui.set_card_state(BanPickCardUI.CardState.SELECTED_RED)

func _get_all_heroes() -> Array:
	# 合并可选英雄和已选英雄
	var all_heroes = available_heroes.duplicate()
	for hero in blue_picks:
		var hero_id = hero.get("id", "")
		if not all_heroes.any(func(h): return h.get("id") == hero_id):
			all_heroes.append(hero)
	for hero in red_picks:
		var hero_id = hero.get("id", "")
		if not all_heroes.any(func(h): return h.get("id") == hero_id):
			all_heroes.append(hero)
	return all_heroes

func _create_card_from_hero(hero: Dictionary) -> Card:
	# 从服务器英雄数据创建本地Card对象
	var card = Card.new()
	card.card_id = hero.get("id", "")
	card.card_name = hero.get("name", "未知")
	# 加载卡牌详细数据
	var full_card = CardDatabase.get_card(hero.get("id", ""))
	if full_card:
		card.max_health = full_card.max_health
		card.health = full_card.max_health
		card.attack = full_card.attack
		card.armor = full_card.armor
		card.card_image = full_card.card_image
		card.skill_name = full_card.skill_name
		card.skill_cost = full_card.skill_cost
	return card

## 卡牌点击处理
func _on_card_clicked(card_ui):
	if not card_ui or not card_ui.get_card():
		return
	
	# 检查是否轮到我选
	if not is_my_turn:
		_show_error_message("还没轮到你选择")
		return
	
	var card = card_ui.get_card()
	var hero_id = card.card_id
	
	# 检查是否已被选择
	var is_picked = blue_picks.any(func(h): return h.get("id") == hero_id) or red_picks.any(func(h): return h.get("id") == hero_id)
	if is_picked:
		_show_error_message("该英雄已被选择")
		return
	
	# 发送选人请求到服务器
	print("🎯 [UI] 选择英雄: %s" % card.card_name)
	NetworkManager.send_pick_hero(hero_id)

## 更新回合指示
func _update_turn_indicator():
	if not turn_indicator:
		return
	
	var phase_text = ""
	if current_pick_index < pick_order_labels.size():
		phase_text = pick_order_labels[current_pick_index]
	else:
		phase_text = "选人完成"
	
	var my_team = "蓝方" if NetworkManager.is_host else "红方"
	var turn_text = "（轮到你选择！）" if is_my_turn else "（等待对方选择...）"
	
	turn_indicator.text = "%s %s" % [phase_text, turn_text]
	
	# 根据是否轮到我改变颜色
	if is_my_turn:
		turn_indicator.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))  # 绿色
	else:
		turn_indicator.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))  # 灰色

## 更新队伍显示
func _update_team_display():
	# 更新蓝方队伍显示
	if blue_team_container:
		for child in blue_team_container.get_children():
			child.queue_free()
		
		for hero in blue_picks:
			var label = Label.new()
			label.text = hero.get("name", "未知")
			label.add_theme_color_override("font_color", Color(0.4, 0.6, 1, 1))
			label.add_theme_font_size_override("font_size", 16)
			blue_team_container.add_child(label)
	
	# 更新红方队伍显示
	if red_team_container:
		for child in red_team_container.get_children():
			child.queue_free()
		
		for hero in red_picks:
			var label = Label.new()
			label.text = hero.get("name", "未知")
			label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
			label.add_theme_font_size_override("font_size", 16)
			red_team_container.add_child(label)

## 显示错误消息
func _show_error_message(message: String):
	if error_popup_scene:
		var popup = error_popup_scene.instantiate()
		popup.set_message(message)
		add_child(popup)
		popup.popup_centered()
	else:
		print("⚠️ %s" % message)

## 窗口大小变化
func _on_viewport_size_changed():
	pass  # 可以添加自适应布局逻辑
