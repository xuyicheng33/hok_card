extends Node

## 网络管理器 - 处理在线对战的WebSocket连接
## MVP版本：支持房间创建、加入和基础游戏状态同步

# WebSocket客户端
var socket: WebSocketPeer
var connection_status: ConnectionStatus = ConnectionStatus.DISCONNECTED

# 服务器配置
var server_url: String = "ws://121.199.78.133:3000"  # 阿里云服务器
# var server_url: String = "ws://localhost:3000"  # 本地测试

# 房间和玩家信息
var room_id: String = ""
var player_id: String = ""
var player_name: String = "玩家"
var is_host: bool = false
var opponent_name: String = ""

# 连接状态枚举
enum ConnectionStatus {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	IN_ROOM,
	IN_GAME
}

# 信号定义
signal connected_to_server()
signal disconnected_from_server()
signal connection_error(error_message: String)
signal room_created(room_data: Dictionary)
signal room_joined(room_data: Dictionary)
signal opponent_joined(opponent_data: Dictionary)
signal game_started(game_data: Dictionary)
signal opponent_action_received(action_data: Dictionary)
signal opponent_disconnected()
signal turn_changed(turn_data: Dictionary)  # 🎯 服务器权威回合变化
signal equipment_drawn(equipment_options: Array)  # 💰 装备抽取结果
signal item_equipped(equip_data: Dictionary)  # 🎒 装备成功

func _ready():
	print("网络管理器初始化...")
	set_process(false)

## 连接到服务器
func connect_to_server(custom_url: String = "") -> bool:
	if connection_status != ConnectionStatus.DISCONNECTED:
		print("已经连接或正在连接中")
		return false
	
	if custom_url != "":
		server_url = custom_url
	
	print("正在连接服务器: %s" % server_url)
	socket = WebSocketPeer.new()
	
	var error = socket.connect_to_url(server_url)
	if error != OK:
		print("连接失败，错误代码: %d" % error)
		connection_error.emit("连接失败")
		return false
	
	connection_status = ConnectionStatus.CONNECTING
	set_process(true)
	return true

## 断开连接
func disconnect_from_server():
	if socket:
		socket.close()
		socket = null
	connection_status = ConnectionStatus.DISCONNECTED
	set_process(false)
	room_id = ""
	player_id = ""
	is_host = false
	print("已断开服务器连接")
	disconnected_from_server.emit()

## 处理WebSocket消息
func _process(_delta):
	if not socket:
		return
	
	socket.poll()
	var state = socket.get_ready_state()
	
	match state:
		WebSocketPeer.STATE_OPEN:
			# 连接成功
			if connection_status == ConnectionStatus.CONNECTING:
				connection_status = ConnectionStatus.CONNECTED
				print("成功连接到服务器")
				connected_to_server.emit()
			
			# 接收消息
			while socket.get_available_packet_count():
				var packet = socket.get_packet()
				var json_string = packet.get_string_from_utf8()
				var message = JSON.parse_string(json_string)
				if message:
					handle_server_message(message)
				else:
					print("解析消息失败: %s" % json_string)
		
		WebSocketPeer.STATE_CLOSING:
			print("连接正在关闭...")
		
		WebSocketPeer.STATE_CLOSED:
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			print("连接已关闭，代码: %d, 原因: %s" % [code, reason])
			disconnect_from_server()

## 处理服务器消息
func handle_server_message(message: Dictionary):
	print("收到服务器消息: %s" % message.get("type", "unknown"))
	
	match message.type:
		"welcome":
			player_id = message.player_id
			print("分配的玩家ID: %s" % player_id)
		
		"room_created":
			room_id = message.room_id
			is_host = true
			connection_status = ConnectionStatus.IN_ROOM
			print("房间创建成功: %s" % room_id)
			room_created.emit(message)
		
		"room_joined":
			room_id = message.room_id
			is_host = false
			connection_status = ConnectionStatus.IN_ROOM
			print("成功加入房间: %s" % room_id)
			room_joined.emit(message)
		
		"opponent_joined":
			opponent_name = message.opponent_name
			print("对手加入: %s" % opponent_name)
			opponent_joined.emit(message)
		
		"game_start":
			connection_status = ConnectionStatus.IN_GAME
			print("游戏开始!")
			game_started.emit(message)
		
		"opponent_action":
			print("收到对手操作: %s" % message.action)
			opponent_action_received.emit(message)
		
		"turn_changed":
			print("收到服务器回合变化: 第%d回合, 我的回合:%s" % [message.turn, message.is_my_turn])
			turn_changed.emit(message)
		
		"skill_points_updated":
			print("收到技能点更新: 房主%d, 客户端%d" % [message.host_skill_points, message.guest_skill_points])
			# 直接发送到BattleManager处理
			if has_signal("skill_points_sync"):
				emit_signal("skill_points_sync", message)
			else:
				# 如果没有专门的信号，添加一个标记让turn_changed区分
				message["is_skill_points_only"] = true
				turn_changed.emit(message)
		
		"opponent_disconnected":
			print("对手已断开连接")
			opponent_disconnected.emit()
		
		"action_failed":
			var action = message.get("action", "unknown")
			var error_msg = message.get("error", "操作失败")
			print("❌ 操作失败 [%s]: %s" % [action, error_msg])
			connection_error.emit("操作失败: " + error_msg)
		
		"skill_failed":
			var error_msg = message.get("error", "技能释放失败")
			print("❌ 技能失败: %s" % error_msg)
			connection_error.emit("技能失败: " + error_msg)
		
		"equipment_drawn":
			var equipment_options = message.get("equipment_options", [])
			var remaining_gold = message.get("remaining_gold", 0)
			print("💰 装备抽取结果: %d个装备, 剩余金币:%d" % [equipment_options.size(), remaining_gold])
			equipment_drawn.emit(equipment_options)
		
		"item_equipped":
			var card_id = message.get("card_id", "")
			var equipment = message.get("equipment", {})
			var card_stats = message.get("card_stats", {})
			print("🎒 装备成功: 卡牍%s 装备%s" % [card_id, equipment.get("name", "")])
			item_equipped.emit(message)
		
		"buy_equipment_failed":
			var error_msg = message.get("error", "购买装备失败")
			print("❌ 购买装备失败: %s" % error_msg)
			connection_error.emit("购买装备失败: " + error_msg)
		
		"equip_failed":
			var error_msg = message.get("error", "装备失败")
			print("❌ 装备失败: %s" % error_msg)
			connection_error.emit("装备失败: " + error_msg)
		
		"gold_changed":
			var host_gold = message.get("host_gold", 0)
			var guest_gold = message.get("guest_gold", 0)
			var income_data = message.get("income_data", {})
			print("💰 收到金币变化: 房主💰%d | 客户端💰%d" % [host_gold, guest_gold])
			
			# 转发给BattleManager处理（通过turn_changed信号）
			var gold_update = {
				"host_gold": host_gold,
				"guest_gold": guest_gold,
				"gold_income": income_data,
				"is_gold_only": true  # 标记这只是金币更新
			}
			turn_changed.emit(gold_update)
		
		"error":
			var error_msg = message.get("message", "未知错误")
			print("服务器错误: %s" % error_msg)
			connection_error.emit(error_msg)
		
		_:
			print("未知消息类型: %s" % message.type)

## 发送消息到服务器
func send_message(message: Dictionary) -> bool:
	if not socket or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("未连接到服务器，无法发送消息")
		return false
	
	var json_string = JSON.stringify(message)
	var error = socket.send_text(json_string)
	
	if error != OK:
		print("发送消息失败，错误代码: %d" % error)
		return false
	
	return true

## 创建房间
func create_room(battle_mode: String = "2v2", player_name_input: String = "玩家1") -> bool:
	if connection_status != ConnectionStatus.CONNECTED:
		print("请先连接服务器")
		return false
	
	player_name = player_name_input
	return send_message({
		"type": "create_room",
		"player_name": player_name,
		"battle_mode": battle_mode
	})

## 加入房间
func join_room(room_id_input: String, player_name_input: String = "玩家2") -> bool:
	if connection_status != ConnectionStatus.CONNECTED:
		print("请先连接服务器")
		return false
	
	player_name = player_name_input
	return send_message({
		"type": "join_room",
		"room_id": room_id_input,
		"player_name": player_name
	})

## 发送游戏操作 - 攻击（仅发送操作意图，服务器计算）
func send_attack(attacker_card_id: String, target_card_id: String) -> bool:
	# 🎮 只发送操作意图，结果由服务器计算
	return send_game_action("attack", {
		"attacker_id": attacker_card_id,
		"target_id": target_card_id
	})

## 发送游戏操作 - 使用技能（仅发送操作意图）
func send_skill(caster_card_id: String, skill_name: String, target_card_id: String = "", is_ally: bool = false) -> bool:
	# 🎮 只发送操作意图，结果由服务器计算
	var skill_data = {
		"caster_id": caster_card_id,
		"skill_name": skill_name
	}
	
	# 添加目标（如果有）
	if target_card_id != "":
		skill_data["target_id"] = target_card_id
		skill_data["is_ally"] = is_ally
	
	return send_game_action("skill", skill_data)

## 发送游戏操作 - 结束回合
func send_end_turn() -> bool:
	return send_game_action("end_turn", {})

## 发送游戏操作的通用方法
func send_game_action(action_type: String, data: Dictionary) -> bool:
	print("🌐 准备发送游戏操作: %s, 当前状态: %s" % [action_type, get_status_text()])
	
	if connection_status != ConnectionStatus.IN_GAME:
		print("❌ 游戏未开始，无法发送操作 (状态: %d)" % connection_status)
		return false
	
	var message = {
		"type": "game_action",
		"room_id": room_id,
		"action": action_type,
		"data": data
	}
	
	print("🌐 发送操作消息: %s" % JSON.stringify(message))
	var success = send_message(message)
	
	if success:
		print("✅ 操作消息发送成功")
	else:
		print("❌ 操作消息发送失败")
	
	return success

## 获取连接状态文本
func get_status_text() -> String:
	match connection_status:
		ConnectionStatus.DISCONNECTED:
			return "未连接"
		ConnectionStatus.CONNECTING:
			return "连接中..."
		ConnectionStatus.CONNECTED:
			return "已连接"
		ConnectionStatus.IN_ROOM:
			return "在房间中"
		ConnectionStatus.IN_GAME:
			return "游戏中"
		_:
			return "未知状态"

## 是否可以进行游戏操作
func can_send_action() -> bool:
	return connection_status == ConnectionStatus.IN_GAME and socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN
