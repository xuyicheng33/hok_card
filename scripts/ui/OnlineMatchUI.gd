extends Control

## 在线对战匹配UI
## 提供创建房间、加入房间功能

# 预加载中文字体
var chinese_font = preload("res://assets/fonts/Arial Unicode.ttf")

# UI组件
var status_label: Label
var room_id_display: Label
var create_room_button: Button
var join_room_button: Button
var room_id_input: LineEdit
var player_name_input: LineEdit
var start_game_button: Button
var back_button: Button
var waiting_label: Label

# 状态
var is_waiting_opponent: bool = false

func _ready():
	print("在线对战UI初始化...")
	setup_ui()
	connect_signals()

## 创建UI
func setup_ui():
	# 设置为全屏
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 背景
	var background = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.15, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# 主容器
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(600, 500)
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)
	
	# 标题
	var title = Label.new()
	title.text = "在线对战"
	title.add_theme_font_override("font", chinese_font)
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# 状态标签
	status_label = Label.new()
	status_label.text = "未连接到服务器"
	status_label.add_theme_font_override("font", chinese_font)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	main_container.add_child(status_label)
	
	# 房间ID显示
	room_id_display = Label.new()
	room_id_display.text = ""
	room_id_display.add_theme_font_override("font", chinese_font)
	room_id_display.add_theme_font_size_override("font_size", 24)
	room_id_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_id_display.add_theme_color_override("font_color", Color.CYAN)
	room_id_display.visible = false
	main_container.add_child(room_id_display)
	
	# 等待对手标签
	waiting_label = Label.new()
	waiting_label.text = "等待对手加入..."
	waiting_label.add_theme_font_override("font", chinese_font)
	waiting_label.add_theme_font_size_override("font_size", 20)
	waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting_label.visible = false
	main_container.add_child(waiting_label)
	
	main_container.add_child(create_spacer(20))
	
	# 玩家名称输入
	var name_container = HBoxContainer.new()
	name_container.add_theme_constant_override("separation", 10)
	main_container.add_child(name_container)
	
	var name_label = Label.new()
	name_label.text = "玩家名称:"
	name_label.add_theme_font_override("font", chinese_font)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.custom_minimum_size = Vector2(120, 0)
	name_container.add_child(name_label)
	
	player_name_input = LineEdit.new()
	player_name_input.text = "玩家%d" % randi_range(1000, 9999)
	player_name_input.add_theme_font_override("font", chinese_font)
	player_name_input.custom_minimum_size = Vector2(300, 40)
	player_name_input.placeholder_text = "输入你的名字"
	name_container.add_child(player_name_input)
	
	# 创建房间按钮
	create_room_button = Button.new()
	create_room_button.text = "创建房间"
	create_room_button.add_theme_font_override("font", chinese_font)
	create_room_button.add_theme_font_size_override("font_size", 20)
	create_room_button.custom_minimum_size = Vector2(400, 60)
	main_container.add_child(create_room_button)
	
	main_container.add_child(create_spacer(10))
	
	# 加入房间区域
	var join_container = VBoxContainer.new()
	join_container.add_theme_constant_override("separation", 10)
	main_container.add_child(join_container)
	
	var join_label = Label.new()
	join_label.text = "或加入现有房间:"
	join_label.add_theme_font_override("font", chinese_font)
	join_label.add_theme_font_size_override("font_size", 16)
	join_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_container.add_child(join_label)
	
	room_id_input = LineEdit.new()
	room_id_input.add_theme_font_override("font", chinese_font)
	room_id_input.custom_minimum_size = Vector2(400, 40)
	room_id_input.placeholder_text = "输入房间ID"
	room_id_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_container.add_child(room_id_input)
	
	join_room_button = Button.new()
	join_room_button.text = "加入房间"
	join_room_button.add_theme_font_override("font", chinese_font)
	join_room_button.add_theme_font_size_override("font_size", 20)
	join_room_button.custom_minimum_size = Vector2(400, 60)
	join_container.add_child(join_room_button)
	
	main_container.add_child(create_spacer(20))
	
	# 开始游戏按钮（房主可见）
	start_game_button = Button.new()
	start_game_button.text = "开始游戏"
	start_game_button.add_theme_font_override("font", chinese_font)
	start_game_button.add_theme_font_size_override("font_size", 22)
	start_game_button.custom_minimum_size = Vector2(400, 70)
	start_game_button.visible = false
	main_container.add_child(start_game_button)
	
	# 返回按钮
	back_button = Button.new()
	back_button.text = "返回主菜单"
	back_button.add_theme_font_override("font", chinese_font)
	back_button.add_theme_font_size_override("font_size", 18)
	back_button.custom_minimum_size = Vector2(200, 50)
	main_container.add_child(back_button)

func create_spacer(height: int) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

## 连接信号
func connect_signals():
	# 按钮信号
	create_room_button.pressed.connect(_on_create_room_pressed)
	join_room_button.pressed.connect(_on_join_room_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# 网络管理器信号
	NetworkManager.connected_to_server.connect(_on_connected_to_server)
	NetworkManager.disconnected_from_server.connect(_on_disconnected_from_server)
	NetworkManager.connection_error.connect(_on_connection_error)
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.opponent_joined.connect(_on_opponent_joined)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.opponent_disconnected.connect(_on_opponent_disconnected)
	
	# 🎯 选人阶段信号
	NetworkManager.pick_phase_started.connect(_on_pick_phase_started)
	
	# 自动连接服务器
	call_deferred("auto_connect")

func auto_connect():
	status_label.text = "正在连接服务器..."
	if not NetworkManager.connect_to_server():
		status_label.text = "连接失败，请检查服务器"

## 创建房间
func _on_create_room_pressed():
	if player_name_input.text.strip_edges() == "":
		show_message("请输入玩家名称")
		return
	
	create_room_button.disabled = true
	join_room_button.disabled = true
	
	if NetworkManager.create_room("2v2", player_name_input.text):
		status_label.text = "正在创建房间..."
	else:
		show_message("创建房间失败")
		create_room_button.disabled = false
		join_room_button.disabled = false

## 加入房间
func _on_join_room_pressed():
	var room_id = room_id_input.text.strip_edges()
	if room_id == "":
		show_message("请输入房间ID")
		return
	
	if player_name_input.text.strip_edges() == "":
		show_message("请输入玩家名称")
		return
	
	create_room_button.disabled = true
	join_room_button.disabled = true
	
	if NetworkManager.join_room(room_id, player_name_input.text):
		status_label.text = "正在加入房间..."
	else:
		show_message("加入房间失败")
		create_room_button.disabled = false
		join_room_button.disabled = false

## 开始游戏（仅房主）
func _on_start_game_pressed():
	# TODO: 通知服务器开始游戏
	NetworkManager.send_message({
		"type": "start_game",
		"room_id": NetworkManager.room_id
	})

## 返回主菜单
func _on_back_pressed():
	NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/main/MainMenuNew.tscn")

## 网络事件处理
func _on_connected_to_server():
	status_label.text = "已连接到服务器"
	status_label.add_theme_color_override("font_color", Color.GREEN)

func _on_disconnected_from_server():
	status_label.text = "已断开连接"
	status_label.add_theme_color_override("font_color", Color.RED)
	create_room_button.disabled = false
	join_room_button.disabled = false

func _on_connection_error(error_message: String):
	show_message("连接错误: " + error_message)
	status_label.text = "连接错误"
	create_room_button.disabled = false
	join_room_button.disabled = false

func _on_room_created(room_data: Dictionary):
	room_id_display.text = "房间ID: " + NetworkManager.room_id
	room_id_display.visible = true
	waiting_label.visible = true
	is_waiting_opponent = true
	status_label.text = "房间已创建，等待对手..."
	
	# 房主显示开始按钮（但禁用直到对手加入）
	start_game_button.visible = true
	start_game_button.disabled = true

func _on_room_joined(room_data: Dictionary):
	room_id_display.text = "房间ID: " + NetworkManager.room_id
	room_id_display.visible = true
	status_label.text = "已加入房间，等待房主开始游戏..."
	create_room_button.visible = false
	join_room_button.visible = false
	room_id_input.visible = false

func _on_opponent_joined(opponent_data: Dictionary):
	waiting_label.visible = false
	status_label.text = "对手已加入: " + NetworkManager.opponent_name
	is_waiting_opponent = false
	
	# 不再需要手动启用开始按钮，服务器会自动进入选人阶段
	# if NetworkManager.is_host:
	#	start_game_button.disabled = false

## 🎯 选人阶段开始 - 跳转到选人界面
func _on_pick_phase_started(pick_data: Dictionary):
	print("🎯 [UI] 收到选人阶段开始信号，跳转到选人界面")
	status_label.text = "进入英雄选择..."
	
	# 保存选人数据供新场景使用
	Engine.set_meta("pick_phase_data", pick_data)
	
	# 切换到选人场景
	get_tree().change_scene_to_file("res://scenes/modes/OnlinePickScene.tscn")

func _on_game_started(game_data: Dictionary):
	print("游戏即将开始...")
	status_label.text = "游戏开始！"
	
	# 🎯 根据服务器发送的卡牌数量判断战斗模式
	var blue_count = game_data.get("blue_cards_count", 2)
	var red_count = game_data.get("red_cards_count", 2)
	var online_battle_mode = "online_2v2"  # 默认2v2
	
	if blue_count == 3 and red_count == 3:
		online_battle_mode = "online_3v3"
	elif blue_count == 2 and red_count == 2:
		online_battle_mode = "online_2v2"
	elif blue_count == 1 and red_count == 1:
		online_battle_mode = "online_1v1"
	
	print("🎮 在线模式: %s (蓝方%d张 vs 红方%d张)" % [online_battle_mode, blue_count, red_count])
	
	# 🎯 保存服务器发送的卡牌数据到全局，供BattleScene使用
	if game_data.has("blue_cards") and game_data.has("red_cards"):
		Engine.set_meta("online_blue_cards", game_data.blue_cards)
		Engine.set_meta("online_red_cards", game_data.red_cards)
		print("📦 保存卡牌数据: 蓝方%d张, 红方%d张" % [game_data.blue_cards.size(), game_data.red_cards.size()])
	else:
		print("⚠️ 警告：服务器未发送卡牌数据！")
	
	# 🌐 确保NetworkManager状态正确
	NetworkManager.connection_status = NetworkManager.ConnectionStatus.IN_GAME
	
	# 延迟设置，确保AutoLoad完全加载
	await get_tree().process_frame
	
	# 🛡️ 使用call_deferred延迟设置BattleManager
	if BattleManager != null:
		BattleManager.call_deferred("set", "is_online_mode", true)
		BattleManager.call_deferred("set", "is_my_turn", NetworkManager.is_host)
		# 🎯 设置战斗模式（用于UI布局）
		Engine.set_meta("online_battle_mode", online_battle_mode)
		print("🌐 在线模式设置: is_host=%s, mode=%s" % [NetworkManager.is_host, online_battle_mode])
	else:
		print("⚠️ BattleManager暂时不可用，将在场景切换后设置")
	
	# 跳转到战斗场景
	await get_tree().create_timer(0.5).timeout
	
	# 确保在切换场景前设置标志
	if BattleManager != null:
		BattleManager.is_online_mode = true
		BattleManager.is_my_turn = NetworkManager.is_host
	
	get_tree().change_scene_to_file("res://scenes/main/BattleScene.tscn")

func _on_opponent_disconnected():
	show_message("对手已断开连接")
	status_label.text = "对手已断开"

## 显示消息
func show_message(message: String):
	print(message)
	# TODO: 可以添加更好的消息提示UI
	status_label.text = message
