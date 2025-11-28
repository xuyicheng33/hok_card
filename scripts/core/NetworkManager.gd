extends Node

## 网络管理器 - 处理在线对战的WebSocket连接
## MVP版本：支持房间创建、加入和基础游戏状态同步

# WebSocket客户端
var socket: WebSocketPeer
var connection_status: ConnectionStatus = ConnectionStatus.DISCONNECTED

# 服务器配置
var server_url: String = "ws://47.118.21.64:3000"  # 阿里云服务器
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
signal equipment_crafted(craft_data: Dictionary)  # 🔨 装备合成成功
signal craft_failed(error_message: String)  # 🔨 装备合成失败
signal opponent_crafted(craft_data: Dictionary)  # 🔨 对手合成装备通知（包含完整数据）
signal game_over(game_result: Dictionary)  # 🏆 游戏结束（服务器权威）
signal full_state_received(state_data: Dictionary)  # 🌐 完整状态同步
signal state_request_failed(error_message: String)  # 🌐 状态同步失败

# 🎯 英雄选择系统信号
signal pick_phase_started(pick_data: Dictionary)  # 选人阶段开始
signal pick_updated(pick_data: Dictionary)        # 选人更新
signal pick_complete(pick_data: Dictionary)       # 选人完成
signal pick_failed(error_message: String)         # 选人失败

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
		
		# 🎯 英雄选择阶段消息
		"pick_phase_start":
			print("🎯 选人阶段开始")
			var available = message.get("available_heroes", [])
			var current_team = message.get("current_team", "blue")
			print("   可选英雄: %d个" % available.size())
			print("   当前选人方: %s" % current_team)
			pick_phase_started.emit(message)
		
		"pick_update":
			var picked_hero = message.get("picked_hero", {})
			var picked_by = message.get("picked_by", "")
			var current_team = message.get("current_team", "")
			print("🎯 选人更新: %s 选择了 %s" % [picked_by, picked_hero.get("name", "")])
			print("   下一个选人方: %s" % current_team)
			pick_updated.emit(message)
		
		"pick_complete":
			var blue_picks = message.get("blue_picks", [])
			var red_picks = message.get("red_picks", [])
			print("🎯 选人完成!")
			print("   蓝方: %s" % ", ".join(blue_picks.map(func(h): return h.get("name", ""))))
			print("   红方: %s" % ", ".join(red_picks.map(func(h): return h.get("name", ""))))
			pick_complete.emit(message)
		
		"pick_failed":
			var error_msg = message.get("error", "选人失败")
			print("❌ 选人失败: %s" % error_msg)
			pick_failed.emit(error_msg)
		
		"opponent_action":
			print("收到对手操作: %s" % message.action)
			opponent_action_received.emit(message)
		
		"turn_changed":
			print("收到服务器回合变化: 第%d回合, 我的回合:%s" % [message.turn, message.is_my_turn])
			turn_changed.emit(message)
		
		"skill_points_updated":
			print("收到技能点更新: 房主%d, 客户端%d" % [message.host_skill_points, message.guest_skill_points])
			# ⭐ 同步奥义点（如果服务器提供）
			if message.has("blue_ougi_points") and message.has("red_ougi_points"):
				var blue_ougi = message.blue_ougi_points
				var red_ougi = message.red_ougi_points
				print("⭐ 同步奥义点: 蓝方⭐%d/5, 红方⭐%d/5" % [blue_ougi, red_ougi])
				# 同步到BattleManager
				if BattleManager:
					BattleManager.sync_ougi_points(
						blue_ougi if is_host else red_ougi,  # 我方
						red_ougi if is_host else blue_ougi   # 敌方
					)
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

		"ougi_used":
			# ⭐ 奥义使用成功
			var data = message.get("data", {})
			var hero_name = data.get("hero_name", "未知英雄")
			var description = data.get("description", "")
			print("⭐ 奥义发动: %s - %s" % [hero_name, description])

			# 同步奥义点
			if message.has("blue_ougi_points") and message.has("red_ougi_points"):
				var blue_ougi = message.blue_ougi_points
				var red_ougi = message.red_ougi_points
				print("⭐ 奥义点清空: 蓝方⭐%d/5, 红方⭐%d/5" % [blue_ougi, red_ougi])
				if BattleManager:
					BattleManager.sync_ougi_points(
						blue_ougi if is_host else red_ougi,
						red_ougi if is_host else blue_ougi
					)

			# TODO: 添加奥义使用成功的UI反馈
			# 例如：播放动画、显示消息等

		"use_ougi_failed":
			var error_msg = message.get("error", "奥义发动失败")
			print("❌ 奥义发动失败: %s" % error_msg)
			connection_error.emit("奥义发动失败: " + error_msg)
		
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
		
		"equipment_crafted":
			var hero_id = message.get("hero_id", "")
			var crafted_equip = message.get("crafted_equipment", {})
			var removed_materials = message.get("removed_materials", [])
			var remaining_gold = message.get("remaining_gold", 0)
			var hero_stats = message.get("hero_stats", {})
			print("🔨 装备合成成功: 英雄%s 获得%s" % [hero_id, crafted_equip.get("name", "")])
			print("   移除材料: %s" % str(removed_materials))
			print("   剩余金币: %d" % remaining_gold)
			equipment_crafted.emit(message)
		
		"craft_failed":
			var error_msg = message.get("error", "合成失败")
			print("❌ 装备合成失败: %s" % error_msg)
			craft_failed.emit(error_msg)
		
		"full_state":
			print("🌐 收到完整状态快照: 回合%d 当前玩家:%s" % [
				message.get("turn", 0),
				message.get("current_player", "unknown")
			])
			full_state_received.emit(message)
		
		"opponent_crafted":
			var team = message.get("team", "")
			var hero_id = message.get("hero_id", "")
			var crafted_equip = message.get("crafted_equipment", {})
			print("🔨 对手合成了装备 (队伍: %s, 英雄: %s, 装备: %s)" % [team, hero_id, crafted_equip.get("name", "未知")])
			opponent_crafted.emit(message)
		
		"game_over":
			var winner = message.get("winner", "")
			var winner_name = message.get("winner_name", "")
			var turns = message.get("turns", 0)
			var reason = message.get("reason", "unknown")
			var final_state = message.get("final_state", {})
			
			print("\n🏆═══════════════════════════════════════════════════════")
			print("   游戏结束！")
			print("   胜者: %s (%s)" % [winner_name, winner])
			print("   回合数: %d" % turns)
			print("   原因: %s" % reason)
			if final_state:
				print("   蓝方存活: %d/3 | 红方存活: %d/3" % [
					final_state.get("blue_alive", 0),
					final_state.get("red_alive", 0)
				])
			print("═══════════════════════════════════════════════════════\n")
			
			# 发送游戏结束信号
			game_over.emit(message)
		
		"error":
			var error_msg = message.get("message", "未知错误")
			print("服务器错误: %s" % error_msg)
			connection_error.emit(error_msg)
			# 如果是状态同步请求失败，转发到专用信号
			if message.get("reason", "") == "request_state":
				state_request_failed.emit(error_msg)
		
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

## 请求服务器返回完整状态（用于重建/校验）
func request_full_state() -> bool:
	return send_message({
		"type": "request_state",
		"room_id": room_id
	})

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

## 发送游戏操作 - 装备合成（阶段1：定向合成）
func send_craft_equipment(hero_id: String, material_ids: Array) -> bool:
	print("🔨 发送装备合成请求: 英雄%s, 材料%s" % [hero_id, material_ids])
	return send_game_action("craft_equipment", {
		"hero_id": hero_id,
		"material_ids": material_ids
	})

## 🎯 发送英雄选择请求
func send_pick_hero(hero_id: String) -> bool:
	if connection_status != ConnectionStatus.IN_ROOM:
		print("❌ 不在房间中，无法选人")
		return false
	
	var message = {
		"type": "pick_hero",
		"hero_id": hero_id
	}
	
	print("🎯 发送选人请求: %s" % hero_id)
	return send_message(message)

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
