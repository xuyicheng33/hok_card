extends Node

## 战斗管理器
## 管理回合制卡牌战斗的整个流程
## 使用状态模式重构

# 自定义队伍变量
var custom_blue_team: Array = []
var custom_red_team: Array = []
var use_custom_teams: bool = false

# 战斗状态枚举（保留用于兼容性）
enum BattleStateEnum {
	NONE,           # 未开始
	PREPARING,      # 准备阶段
	BATTLE,         # 战斗进行中
	PLAYER_TURN,    # 玩家回合
	ENEMY_TURN,     # 敌人回合
	BATTLE_END,     # 战斗结束
	VICTORY,        # 胜利
	DEFEAT          # 失败
}

# 当前战斗状态
var current_state_name: String = "none"
var current_state = null
var states: Dictionary = {}

# 战斗参与者
var player_cards: Array = []
var enemy_cards: Array = []
var entity_card_map: Dictionary = {}  # 实体到卡牌的映射

# 当前回合信息
var current_turn: int = 1
var current_player: bool = true  # true = 玩家回合, false = 敌人回合

# 技能点系统
var player_skill_points: int = 4  # 玩家技能点
var enemy_skill_points: int = 4   # 敌人技能点
var max_skill_points: int = 6     # 技能点上限

# 🎯 行动点系统（新增）
var actions_per_turn: int = 3     # 每回合行动次数
var player_actions_used: int = 0  # 玩家已使用行动次数
var enemy_actions_used: int = 0   # 敌人已使用行动次数

# 战斗结果
var battle_result: Dictionary = {}

# 战斗消息系统引用
var message_system = null

# 在线模式支持
var is_online_mode: bool = false  # 是否为在线对战模式
var is_my_turn: bool = false      # 是否是我的回合（在线模式有效）
var waiting_for_opponent: bool = false  # 等待对手操作

# 信号定义
signal battle_started()
signal battle_ended(result: Dictionary)
signal turn_changed(is_player_turn: bool)
signal state_changed(new_state)
signal card_died(card: Card, is_player: bool)
signal skill_points_changed(player_points: int, enemy_points: int)
signal actions_changed(player_actions: int, enemy_actions: int)  # 🎯 行动点变化信号
signal passive_skill_triggered(card: Card, skill_name: String, effect: String, details: Dictionary)
signal skill_executed(skill_data: Dictionary)  # 🌐 在线模式技能执行信号

# 设置自定义队伍
func set_custom_teams(blue: Array, red: Array):
	custom_blue_team = blue
	custom_red_team = red
	use_custom_teams = true
	print("已设置自定义队伍 - 蓝方: %d张卡牌, 红方: %d张卡牌" % [blue.size(), red.size()])

func _ready():
	print("战斗管理器初始化...")
	_init_states()
	reset_battle()
	_connect_network_signals()
	print("战斗管理器就绪")

## 连接网络管理器信号
func _connect_network_signals():
	if NetworkManager:
		NetworkManager.opponent_action_received.connect(_on_opponent_action_received)
		NetworkManager.turn_changed.connect(_on_server_turn_changed)
		print("已连接网络管理器信号")

## 初始化所有状态
func _init_states():
	# 创建状态实例
	states = {
		"none": BattleStateSystem.NoneState.new(self),
		"preparing": BattleStateSystem.PreparingState.new(self),
		"player_turn": BattleStateSystem.PlayerTurnState.new(self),
		"enemy_turn": BattleStateSystem.EnemyTurnState.new(self),
		"battle_end": BattleStateSystem.BattleEndState.new(self)
	}
	
	# 设置初始状态
	current_state = states["none"]

## 重置战斗状态
func reset_battle():
	print("重置战斗状态")
	change_to_state("none")
	player_cards.clear()
	enemy_cards.clear()
	entity_card_map.clear()
	current_turn = 0  # 🔄 从0开始，第一次start_new_turn会变成1
	current_player = true
	battle_result.clear()
	
	# 重置技能点
	player_skill_points = 4
	enemy_skill_points = 4
	
	# 🎯 重置行动点
	player_actions_used = 0
	enemy_actions_used = 0
	
	# 🎯 发送初始化信号（让UI显示初始值）
	actions_changed.emit(player_actions_used, enemy_actions_used)

## 开始战斗
func start_battle(player_deck: Array, enemy_deck: Array) -> bool:
	print("开始战斗...")
	
	# 安全性检查
	if not player_deck or player_deck.is_empty():
		print("错误: 玩家卡牌为空")
		return false
	
	if not enemy_deck or enemy_deck.is_empty():
		print("错误: 敌人卡牌为空")
		return false
	
	# 初始化战斗数据
	player_cards = player_deck.duplicate()
	enemy_cards = enemy_deck.duplicate()
	
	# 验证卡牌有效性
	for card in player_cards:
		if not card or not card.is_valid():
			print("错误: 玩家卡牌无效 - %s" % (card.card_name if card else "null"))
			return false
	
	for card in enemy_cards:
		if not card or not card.is_valid():
			print("错误: 敌人卡牌无效 - %s" % (card.card_name if card else "null"))
			return false
	
	# 设置战斗状态
	change_to_state("preparing")
	
	print("战斗初始化成功")
	print("玩家卡牌数量: %d" % player_cards.size())
	print("敌人卡牌数量: %d" % enemy_cards.size())
	
	# 延迟开始第一回合，确保界面准备就绪
	call_deferred("start_first_turn")
	
	battle_started.emit()
	return true

## 开始第一回合
func start_first_turn():
	print("开始第一回合")
	
	# 🔢 设置回合数为1（从第1回合开始）
	current_turn = 1
	
	# 🌐 在线模式：根据is_my_turn设置初始回合
	if is_online_mode:
		current_player = is_my_turn
		print("🌐 在线模式第 %d 回合: %s先手" % [current_turn, "我方" if is_my_turn else "对方"])
	else:
		current_player = true  # 单机模式玩家先手
	
	# 发送回合变化信号
	turn_changed.emit(current_player)
	
	# 切换到对应回合状态
	if current_player:
		change_to_state("player_turn")
	else:
		change_to_state("enemy_turn")

## 改变战斗状态
func change_to_state(new_state_name: String):
	if current_state_name == new_state_name:
		return
	
	var old_state_name = current_state_name
	
	# 退出当前状态
	if current_state:
		current_state.exit()
	
	# 更新状态
	current_state_name = new_state_name
	current_state = states[new_state_name]
	
	# 进入新状态
	current_state.enter()
	
	print("战斗状态变化: %s -> %s" % [old_state_name, new_state_name])
	state_changed.emit(new_state_name)
	
	# 为了兼容旧代码，也发送枚举状态
	var enum_state = _get_enum_state_from_name(new_state_name)
	state_changed.emit(enum_state)

## 执行卡牌攻击（公共接口）
func execute_attack(attacker: Card, target: Card, attacker_is_player: bool) -> Dictionary:
	# 在线模式：检查是否是我的回合
	if is_online_mode:
		# 🎯 简化回合检查：直接判断当前回合数是否对应我的回合
		var current_turn_num = current_turn
		var is_host_turn = (current_turn_num % 2 == 1)  # 奇数回合是房主
		var should_be_my_turn = (NetworkManager.is_host and is_host_turn) or (not NetworkManager.is_host and not is_host_turn)
		
		if not should_be_my_turn:
			print("在线模式：不是你的回合（第%d回合），无法操作" % current_turn_num)
			return {"success": false, "error": "not_your_turn"}
		
		# 🎮 在线模式：只发送操作到服务器，不执行本地计算
		if NetworkManager:
			NetworkManager.send_attack(attacker.card_id, target.card_id)
			print("🎮 已发送攻击到服务器，等待结果...")
			return {"success": true}  # 返回成功，等待服务器结果
	
	# 单机模式：执行本地攻击
	var result = current_state.execute_attack(attacker, target, attacker_is_player)
	return result

## 执行技能（公共接口）
func execute_skill(card: Card, skill_name: String, targets: Array, is_player: bool) -> Dictionary:
	# 在线模式检查
	if is_online_mode:
		# 🎯 简化回合检查：直接判断当前回合数是否对应我的回合
		var current_turn_num = current_turn
		var is_host_turn = (current_turn_num % 2 == 1)  # 奇数回合是房主
		var should_be_my_turn = (NetworkManager.is_host and is_host_turn) or (not NetworkManager.is_host and not is_host_turn)
		
		if not should_be_my_turn:
			print("在线模式：不是你的回合（第%d回合），无法使用技能" % current_turn_num)
			return {"success": false, "error": "not_your_turn"}
		
		# 🎮 在线模式：只发送操作到服务器
		if NetworkManager:
			# 检查技能点（不消耗，等服务器确认）
			var skill_cost = card.skill_cost
			if not can_use_skill(is_player, skill_cost):
				print("技能点不足")
				return {"success": false, "error": "insufficient_skill_points"}
			
			# 准备目标参数
			var target_id = ""
			var is_ally = false
			
			if targets.size() > 0:
				var target = targets[0]
				target_id = target.card_id
				# 判断目标是否是友方
				is_ally = is_card_in_player_side(target) == is_card_in_player_side(card)
			
			# 发送技能到服务器
			NetworkManager.send_skill(card.card_id, skill_name, target_id, is_ally)
			print("🎮 已发送技能到服务器: %s -> %s (友方:%s)" % [skill_name, target_id if target_id else "无目标", is_ally])
			return {"success": true}
	
	# 单机模式：调用内部技能逻辑
	return _execute_skill_internal(card, skill_name, targets, is_player)

## 内部攻击执行逻辑（被状态类调用）
func _execute_attack_internal(attacker: Card, target: Card, attacker_is_player: bool) -> Dictionary:
	print("执行攻击: %s -> %s" % [attacker.card_name, target.card_name])
	
	# 安全性检查
	if not attacker or not target:
		print("错误: 攻击者或目标为空")
		return {"success": false, "error": "invalid_cards"}
	
	if attacker.is_dead() or target.is_dead():
		print("错误: 攻击者或目标已死亡")
		return {"success": false, "error": "dead_cards"}
	
	# 检查澜的被动技能条件
	var lan_passive_triggered = false
	if attacker.card_name == "澜" and attacker.check_lan_passive_condition(target):
		lan_passive_triggered = true
		attacker.trigger_lan_passive()
		print("澜的被动技能触发：目标%s生命值(%d)小于等于最大生命值的50%(%d)" % [
			target.card_name, target.health, target.max_health * 0.5
		])
	
	# 计算伤害（使用新的暴击系统和增伤系统）
	var damage_result = attacker.calculate_damage_to(target)
	
	# 重置澜的增伤值（攻击结束后）
	if lan_passive_triggered:
		attacker.reset_damage_bonus()
	
	if not damage_result.success:
		print("错误: 伤害计算失败")
		return {"success": false, "error": "damage_calculation_failed"}
	
	var final_damage = damage_result.final_damage
	var is_critical = damage_result.is_critical
	var base_damage = damage_result.base_damage
	var has_damage_bonus = damage_result.has_damage_bonus
	
	# 闪避判定（在伤害计算完毕后、实际应用伤害前）
	var is_dodged = false
	var original_damage = final_damage  # 保存原始伤害用于消息显示
	if target.check_gongsunli_dodge():
		is_dodged = true
		final_damage = 0  # 闪避成功，伤害归零
		print("闪避成功！%s 免受了来自 %s 的攻击" % [target.card_name, attacker.card_name])
		
		# 发送公孙离被动技能触发信号 - 使用更明确的消息表述
		if target.card_name == "公孙离":
			passive_skill_triggered.emit(target, "霜叶舞", "成功闪避攻击，获得攻击力和暴击率提升", {})
	
	# 应用伤害
	var actual_damage = target.take_damage(final_damage)
	
	# 大乔被动技能：受到致命伤害时触发
	if target.card_name == "大乔" and target.health <= 0 and target.can_use_daqiao_passive():
		# 触发大乔被动技能
		target.trigger_daqiao_passive()
		
		# 增加己方技能点
		var skill_points_gained = 3
		var is_target_player = is_card_in_player_side(target)
		var old_skill_points = player_skill_points if is_target_player else enemy_skill_points
		var max_skill_points = 6
		
		if is_target_player:
			player_skill_points = min(max_skill_points, player_skill_points + skill_points_gained)
		else:
			enemy_skill_points = min(max_skill_points, enemy_skill_points + skill_points_gained)
		
		var new_skill_points = player_skill_points if is_target_player else enemy_skill_points
		var actual_gained_points = new_skill_points - old_skill_points
		
		# 处理技能点溢出转换为护盾
		var overflow_points = max(0, old_skill_points + skill_points_gained - max_skill_points)
		var shield_amount = 0
		if overflow_points > 0:
			shield_amount = overflow_points * 150
			target.add_shield(shield_amount)
			print("大乔被动技能：技能点溢出%d点，转换为%d点护盾" % [overflow_points, shield_amount])
			
			# 发送大乔被动技能触发信号（包含溢出转换护盾信息）
			passive_skill_triggered.emit(target, "宿命之海", "生命值恢复至1点，获得%d点技能点，溢出%d点转换为%d点护盾" % [actual_gained_points, overflow_points, shield_amount], {})
		else:
			# 发送大乔被动技能触发信号
			passive_skill_triggered.emit(target, "宿命之海", "生命值恢复至1点，获得%d点技能点" % actual_gained_points, {})
		
		# 发送技能点变化信号
		skill_points_changed.emit(player_skill_points, enemy_skill_points)
		
		# 发送更详细的被动技能触发信号，包含技能点和护盾转换的详细信息
		if message_system:
			var passive_details = {
				"skill_points_gained": skill_points_gained,
				"overflow_points": overflow_points,
				"shield_amount": shield_amount,
				"old_skill_points": old_skill_points,
				"new_skill_points": new_skill_points,
				"max_skill_points": max_skill_points,
				"actual_gained_points": actual_gained_points
			}
			passive_skill_triggered.emit(target, "宿命之海", "生命值恢复至1点，获得%d点技能点%s" % [
				actual_gained_points, 
				"，溢出%d点转换为%d点护盾" % [overflow_points, shield_amount] if overflow_points > 0 else ""
			], passive_details)

	# 🦌 瑶的被动技能：山鬼白鹿（受到伤害时为绝对血量最低的友方添加护盾）
	if target.card_name == "瑶" and actual_damage > 0:
		# 查找全场绝对血量最低的友方英雄（包括瑶自己）
		var lowest_health_ally = null
		var lowest_health = 999999
		
		# 检查所有存活的友方卡牌
		var ally_cards = get_alive_player_cards() if is_card_in_player_side(target) else get_alive_enemy_cards()
		for ally_card in ally_cards:
			if not ally_card.is_dead() and ally_card.health < lowest_health:
				lowest_health = ally_card.health
				lowest_health_ally = ally_card
		
		# 如果找到了生命值最低的友方英雄，则为其添加护盾
		if lowest_health_ally:
			# 计算护盾值：基础值100 + 瑶当前生命值的3%
			var shield_amount = int(100 + target.health * 0.03)
			lowest_health_ally.add_shield(shield_amount)
			print("🦌 瑶被动「山鬼白鹿」触发：为%s添加%d点护盾（当前护盾:%d）" % [
				lowest_health_ally.card_name, shield_amount, lowest_health_ally.shield
			])
			
			# 发送瑶被动技能触发信号
			passive_skill_triggered.emit(target, "山鬼白鹿", "为%s添加%d点护盾" % [lowest_health_ally.card_name, shield_amount], {})
	
	# 公孙离被动技能：如果攻击暴击，则增加闪避概率
	if attacker.card_name == "公孙离" and is_critical and not is_dodged:
		attacker.add_gongsunli_dodge_bonus(0.05)  # 增加5%闪避概率
		print("公孙离攻击暴击，闪避概率增加5%")
		
		# 发送公孙离被动技能触发信号 - 使用更明确的消息表述
		var current_dodge_rate = attacker.get_gongsunli_dodge_rate() * 100
		passive_skill_triggered.emit(attacker, "霜叶舞", "攻击暴击触发闪避概率提升，当前闪避概率%.1f%%%%" % current_dodge_rate, {})
	
	# 输出详细的伤害信息
	var damage_info = ""
	if is_dodged:
		# 闪避成功情况
		damage_info = "闪避！%s 成功闪避了 %s 的攻击（原伤害: %d）" % [
			target.card_name, attacker.card_name, damage_result.final_damage
		]
	elif is_critical and has_damage_bonus:
		damage_info = "暴击+被动！%s 对 %s 造成了 %d 伤害（基础: %d, 暴击: %.0f%%%%, 增伤: +%.0f%%%%）" % [
			attacker.card_name, target.card_name, final_damage, base_damage, 
			damage_result.crit_damage * 100, damage_result.damage_bonus_percent
		]
	elif is_critical:
		damage_info = "暴击！%s 对 %s 造成了 %d 暴击伤害（基础: %d, 暴击倍率: %.0f%%%%）" % [
			attacker.card_name, target.card_name, final_damage, base_damage, damage_result.crit_damage * 100
		]
	elif has_damage_bonus:
		damage_info = "被动技能！%s 对 %s 造成了 %d 伤害（基础: %d, 增伤: +%.0f%%%%）" % [
			attacker.card_name, target.card_name, final_damage, base_damage, damage_result.damage_bonus_percent
		]
	else:
		damage_info = "普通攻击: %s 对 %s 造成了 %d 伤害" % [
			attacker.card_name, target.card_name, final_damage
		]
	print(damage_info)
	
	# 构建攻击结果
	var result = {
		"success": true,
		"attacker": attacker,
		"target": target,
		"base_damage": base_damage,
		"final_damage": final_damage,
		"original_damage": original_damage,
		"actual_damage": actual_damage,
		"is_critical": is_critical,
		"has_damage_bonus": has_damage_bonus,
		"is_dodged": is_dodged,
		"lan_passive_triggered": lan_passive_triggered,
		"crit_rate": damage_result.crit_rate,
		"crit_damage": damage_result.crit_damage,
		"damage_info": damage_info,
		"target_dead": target.is_dead(),
		"attacker_attack": attacker.attack,
		"target_armor": target.armor,
		"damage_bonus_percent": damage_result.damage_bonus_percent
	}
	
	# 检查目标是否死亡
	if target.is_dead():
		print("目标死亡: %s" % target.card_name)
		card_died.emit(target, not attacker_is_player)
		
		# 从相应数组中移除死亡卡牌
		if attacker_is_player:
			enemy_cards.erase(target)
		else:
			player_cards.erase(target)
		
		# 通知BattleScene销毁实体
		_notify_battle_scene_entity_destroyed(target)
	
	# 孙尚香被动技能：千金重弩（每次普通攻击命中敌人时有70%概率获得1点技能点）
	if attacker.card_name == "孙尚香" and not is_dodged and final_damage > 0:
		# 攻击命中且造成伤害，70%概率触发被动技能
		if randf() < 0.7:  # 70%概率
			var skill_points_gained = 1
			if attacker_is_player:
				player_skill_points = min(max_skill_points, player_skill_points + skill_points_gained)
				print("孙尚香被动技能触发：获得%d点技能点（当前: %d）" % [skill_points_gained, player_skill_points])
			else:
				enemy_skill_points = min(max_skill_points, enemy_skill_points + skill_points_gained)
				print("孙尚香被动技能触发：获得%d点技能点（当前: %d）" % [skill_points_gained, enemy_skill_points])
			
			# 发送技能点变化信号
			skill_points_changed.emit(player_skill_points, enemy_skill_points)
			
			# 发送被动技能触发信号
			passive_skill_triggered.emit(attacker, "千金重弩", "获得%d点技能点" % skill_points_gained, {})
			
			# 在返回结果中添加被动技能信息
			result["sunshangxiang_passive_triggered"] = true
			result["skill_points_gained"] = skill_points_gained
		else:
			print("孙尚香被动技能未触发（概率判定失败）")
			# 被动技能未触发的情况下，也要在结果中记录
			result["sunshangxiang_passive_triggered"] = false
			result["skill_points_gained"] = 0
	
	# 杨玉环被动技能：霓裳风华（释放主动技能后，下一次普通攻击会额外对一名随机敌方造成主目标70%的伤害）
	if attacker.card_name == "杨玉环" and attacker.yangyuhuan_skill_used:
		# 重置标记
		attacker.yangyuhuan_skill_used = false
		
		# 额外伤害为目标最终伤害的70%
		var additional_damage = int(final_damage * 0.7)
		
		# 获取所有存活的敌方卡牌（除了主目标）
		var all_enemies = get_alive_enemy_cards() if attacker_is_player else get_alive_player_cards()
		var other_enemies = []
		for enemy in all_enemies:
			if enemy != target:
				other_enemies.append(enemy)
		
		# 如果还有其他敌方单位
		if not other_enemies.is_empty():
			# 随机选择一个敌方单位
			var random_enemy = other_enemies[randi() % other_enemies.size()]
			
			# 对随机敌方造成额外伤害
			var old_health = random_enemy.health
			random_enemy.health = max(0, random_enemy.health - additional_damage)
			var actual_additional_damage = old_health - random_enemy.health
			
			# 更新显示
			_update_battle_entity_display(random_enemy)
			
			print("杨玉环被动技能触发：对%s造成%d额外伤害" % [random_enemy.card_name, actual_additional_damage])
			
			# 发送被动技能触发信号
			passive_skill_triggered.emit(attacker, "霓裳风华", "对%s造成%d额外伤害" % [random_enemy.card_name, actual_additional_damage], {})
			
			# 在返回结果中添加被动技能信息
			result["yangyuhuan_passive_triggered"] = true
			result["additional_damage"] = actual_additional_damage
			result["additional_target"] = random_enemy.card_name
		else:
			# 没有其他敌方单位
			result["yangyuhuan_passive_triggered"] = false
			result["additional_damage"] = 0
			result["additional_target"] = ""
	else:
		# 没有触发被动技能
		result["yangyuhuan_passive_triggered"] = false
		result["additional_damage"] = 0
		result["additional_target"] = ""
	
	# 检查战斗是否结束
	call_deferred("check_battle_end")
	
	return result

## 检查战斗是否结束
func check_battle_end():
	# 如果已经在战斗结束状态，不再检查
	if current_state_name == "battle_end":
		return
	
	# 检查玩家卡牌是否全部死亡
	if player_cards.is_empty():
		print("玩家卡牌全部死亡，战斗失败")
		end_battle(false)
		return
	
	# 检查敌人卡牌是否全部死亡
	if enemy_cards.is_empty():
		print("敌人卡牌全部死亡，战斗胜利")
		end_battle(true)
		return

## 结束战斗
func end_battle(is_victory: bool):
	print("战斗结束: %s" % ("胜利" if is_victory else "失败"))
	
	# 设置战斗结果
	battle_result = {
		"victory": is_victory,
		"turns": current_turn,
		"remaining_player_cards": player_cards.size(),
		"remaining_enemy_cards": enemy_cards.size()
	}
	
	# 切换到战斗结束状态
	change_to_state("battle_end")
	
	# 发送战斗结束信号
	battle_ended.emit(battle_result)

## 内部技能执行逻辑（被状态类调用）
func _execute_skill_internal(card: Card, skill_name: String, targets: Array, is_player: bool) -> Dictionary:
	print("执行技能: %s 使用 %s" % [card.card_name, skill_name])
	
	# 安全性检查
	if not card or card.is_dead():
		print("错误: 技能施放者无效或已死亡")
		return {"success": false, "error": "invalid_caster"}
	
	# 检查技能点是否足够
	var skill_cost = card.skill_cost
	if is_player and player_skill_points < skill_cost:
		print("错误: 玩家技能点不足 (需要: %d, 当前: %d)" % [skill_cost, player_skill_points])
		return {"success": false, "error": "not_enough_skill_points"}
	elif not is_player and enemy_skill_points < skill_cost:
		print("错误: 敌人技能点不足 (需要: %d, 当前: %d)" % [skill_cost, enemy_skill_points])
		return {"success": false, "error": "not_enough_skill_points"}
	
	# 消耗技能点
	consume_skill_points(is_player, skill_cost)
	
	# TODO: 技能系统需要重构为服务器权威模式
	# 暂时返回成功，等待重构
	print("⚠️ 技能系统暂时简化，需要后续重构")
	
	var result = {
		"success": true,
		"skill_name": skill_name,
		"caster": card.card_name,
		"targets": targets.size()
	}
	
	# 检查战斗是否结束
	call_deferred("check_battle_end")
	
	return result

## 结束当前回合
func end_turn():
	current_state.end_turn()

## 开始新回合（优化版：全局统一回合数）
func start_new_turn(is_player_turn: bool):
	# 🔄 全局回合数+1
	current_turn += 1
	current_player = is_player_turn
	
	# 🌐 在线模式：判定当前回合是谁行动
	var turn_owner = ""
	if is_online_mode:
		# 回合1,3,5... = 房主
		# 回合2,4,6... = 客户端
		var is_host_turn = (current_turn % 2 == 1)
		var is_my_turn_now = (NetworkManager.is_host and is_host_turn) or (not NetworkManager.is_host and not is_host_turn)
		turn_owner = "房主" if is_host_turn else "客户端"
		print("🌐 全局回合 %d (%s行动)，本地是%s，%s" % [
			current_turn, 
			turn_owner,
			"房主" if NetworkManager.is_host else "客户端",
			"我方回合" if is_my_turn_now else "对方回合"
		])
	else:
		print("开始新回合: 第%d回合, %s回合" % [current_turn, "玩家" if is_player_turn else "敌人"])
	
	# 🌐 增加技能点 - 第1和第2回合不增加，从第3回合开始
	if current_turn > 2:
		# 在线模式：技能点由服务器管理，这里不处理
		if is_online_mode:
			print("🌐 在线模式，技能点由服务器管理")
		else:
			# 单机模式：从第3回合开始增加
			if is_player_turn:
				player_skill_points = min(max_skill_points, player_skill_points + 1)
			else:
				enemy_skill_points = min(max_skill_points, enemy_skill_points + 1)
			
			# 发送技能点变化信号
			skill_points_changed.emit(player_skill_points, enemy_skill_points)
	elif current_turn <= 2:
		print("第%d回合不增加技能点" % current_turn)
	
	# 🎯 重置行动点
	reset_actions(is_player_turn)
	
	# 发送回合变化信号
	turn_changed.emit(is_player_turn)
	
	# 切换到相应状态
	change_to_state("player_turn" if is_player_turn else "enemy_turn")

## 触发回合开始被动技能
func trigger_turn_start_passives(is_player_turn: bool):
	# 直接调用统一的被动技能处理方法
	process_all_passive_skills(is_player_turn)

## 为兼容旧代码添加的方法

## 检查当前是否为玩家回合
func is_player_turn() -> bool:
	return current_player

## 获取技能点信息
func get_skill_points_info() -> Dictionary:
	return {
		"player_points": player_skill_points,
		"enemy_points": enemy_skill_points,
		"max_points": max_skill_points
	}

## 检查是否可以使用技能
func can_use_skill(is_player: bool, skill_cost: int) -> bool:
	if is_player:
		return player_skill_points >= skill_cost
	else:
		return enemy_skill_points >= skill_cost

## 消耗技能点
func consume_skill_points(is_player: bool, skill_cost: int) -> bool:
	# 检查技能点是否足够
	if not can_use_skill(is_player, skill_cost):
		return false
	
	# 消耗技能点
	if is_player:
		player_skill_points -= skill_cost
	else:
		enemy_skill_points -= skill_cost
	
	# 发送技能点变化信号
	skill_points_changed.emit(player_skill_points, enemy_skill_points)
	return true

## 获取战斗信息
func get_battle_info() -> Dictionary:
	return {
		"turn": current_turn,
		"is_player_turn": current_player,
		"player_cards": player_cards.size(),
		"enemy_cards": enemy_cards.size(),
		"state": current_state_name
	}

## 更新战斗实体显示的辅助方法
func _update_battle_entity_display(card: Card):
	# 通过全局访问BattleScene并更新特定卡牌的显示
	var battle_scene = get_tree().get_root().get_node("BattleScene")
	if battle_scene and battle_scene.has_method("update_card_entity_display"):
		battle_scene.update_card_entity_display(card)

## 通知BattleScene销毁实体的辅助方法
func _notify_battle_scene_entity_destroyed(card: Card):
	# 通过全局访问BattleScene并通知实体销毁
	var battle_scene = get_tree().get_root().get_node("BattleScene")
	if battle_scene and battle_scene.has_method("destroy_card_entity"):
		battle_scene.destroy_card_entity(card)

## 结束当前回合并开始下一回合（兼容旧代码）
func next_turn():
	end_turn()

## 从状态名称获取枚举值（兼容旧代码）
func _get_enum_state_from_name(state_name: String) -> int:
	match state_name:
		"none": return BattleStateEnum.NONE
		"preparing": return BattleStateEnum.PREPARING
		"player_turn": return BattleStateEnum.PLAYER_TURN
		"enemy_turn": return BattleStateEnum.ENEMY_TURN
		"battle_end": return BattleStateEnum.BATTLE_END
		_: return BattleStateEnum.NONE

## 处理所有卡牌的回合开始被动技能
func process_all_passive_skills(is_player_turn: bool):
	# 🌐 在线模式下，被动技能由服务器处理，客户端只接收结果
	if is_online_mode:
		print("⏭️ 在线模式：跳过本地被动技能计算，等待服务器推送")
		return
	
	var cards_to_process = player_cards if is_player_turn else enemy_cards
	
	for card in cards_to_process:
		if card and not card.is_dead() and card.has_passive_skill():
			match card.card_name:
				"朵莉亚":
					# 朵莉亚的被动技能在任何回合都触发
					var old_health = card.health
					var old_shield = card.shield
					card.trigger_duoliya_passive()
					
					# 计算溢出的护盾值
					var healed_amount = 75  # 朵莉亚固定恢复75点生命值
					var overflow_shield = 0
					
					# 如果生命值已满，计算溢出的护盾
					if old_health + healed_amount >= card.max_health:
						overflow_shield = card.shield - old_shield
						
						# 发送更详细的被动技能触发信号
						passive_skill_triggered.emit(card, "欢歌", "溢出%d点护盾" % overflow_shield, {
							"heal_amount": healed_amount,
							"overflow_shield": overflow_shield,
							"old_health": old_health,
							"new_health": card.health,
							"old_shield": old_shield,
							"new_shield": card.shield
						})
						
						print("朵莉亚被动技能「欢歌」发动：生命值 %d->%d (已满)，溢出%d点转为护盾 %d->%d" % [
							old_health, card.health, overflow_shield, old_shield, card.shield
						])
					else:
						# 普恢复生命值情况
						passive_skill_triggered.emit(card, "欢歌", "HP+75", {
							"heal_amount": healed_amount,
							"overflow_shield": 0,
							"old_health": old_health,
							"new_health": card.health,
							"old_shield": old_shield,
							"new_shield": card.shield
						})
						
						print("朵莉亚被动技能「欢歌」发动：生命值 %d->%d, 护盾 %d->%d" % [
							old_health, card.health, old_shield, card.shield
						])
				"澜":
					# 澜的"狩猎"被动：在攻击时触发，不在回合开始时处理
					pass
				"公孙离":
					# 公孙离的被动技能在受到攻击时触发，不在回合开始时触发
					pass
				"少司缘":
					# 少司缘的"怨离别"被动：每回合开始前有45%概率偷取敌方技能点
					if randf() < 0.45:  # 45%概率
						# 判断敌方是玩家还是敌人
						var is_enemy_player = not is_player_turn
						var enemy_skill_points = player_skill_points if is_enemy_player else enemy_skill_points
						var our_skill_points = enemy_skill_points if is_enemy_player else player_skill_points
						
						# 检查敌方是否有技能点可以偷取
						if enemy_skill_points > 0:
							# 偷取1点技能点
							if is_enemy_player:
								player_skill_points -= 1
							else:
								enemy_skill_points -= 1
							
							# 检查己方技能点池是否已满
							if our_skill_points < max_skill_points:
								# 技能点池未满，将偷取的点加入己方池
								if is_player_turn:
									player_skill_points += 1
								else:
									enemy_skill_points += 1
								
								# 增加少司缘的偋取点数计数（有上限）
								# 记录偋取前的点数，用于调试
								var old_points = card.get_shaosiyuan_stolen_points()
								card.add_shaosiyuan_stolen_points(1)
								
								# 从详细信息中获取当前的偋取点数计数
								var current_stolen_count = card.get_shaosiyuan_stolen_points()
								print("少司缘的偋取点数从 %d 增加到 %d" % [old_points, current_stolen_count])
																
								# 发送被动技能触发信号
								passive_skill_triggered.emit(card, "怨离别", "成功偋取1点技能点，当前偋取点数: %d" % current_stolen_count, {
									"stolen_points": 1,
									"current_stolen_count": current_stolen_count
								})
								
								print("少司缘被动技能「怨离别」发动：成功偷取1点技能点，当前偷取点数: %d" % card.get_shaosiyuan_stolen_points())
							else:
								# 技能点池已满，改为恢复100点生命值
								card.heal(100)
								
								# 记录偋取前的点数，用于调试
								var old_points = card.get_shaosiyuan_stolen_points()
								card.add_shaosiyuan_stolen_points(1)
								
								# 获取当前的偋取点数计数
								var current_stolen_count = card.get_shaosiyuan_stolen_points()
								print("少司缘的偋取点数从 %d 增加到 %d（生命值恢复模式）" % [old_points, current_stolen_count])
								
								# 发送被动技能触发信号
								passive_skill_triggered.emit(card, "怨离别", "成功偋取1点技能点，但技能点池已满，改为恢复100点生命值", {
									"stolen_points": 1,
									"heal_amount": 100,
									"current_stolen_count": current_stolen_count
								})
								
								print("少司缘被动技能「怨离别」发动：成功偷取1点技能点，但技能点池已满，改为恢复100点生命值")
							
							# 发送技能点变化信号
							skill_points_changed.emit(player_skill_points, enemy_skill_points)
						else:
							# 敌方没有技能点可以偷取
							print("少司缘被动技能「怨离别」发动：敌方没有技能点可以偷取")
					else:
						# 未触发被动技能
						print("少司缘被动技能「怨离别」未触发（概率判定失败）")
				_:
					print("未知的被动技能: %s" % card.card_name)

## 判断卡牌是否在玩家方
func is_card_in_player_side(card: Card) -> bool:
	# 检查卡牌是否在玩家数组中
	for player_card in player_cards:
		if player_card == card:
			return true
	return false

## 处理回合状态效果（眩晕、中毒等）
func process_turn_status_effects():
	print("处理回合状态效果...")
	
	# 处理所有卡牌的状态效果
	var all_cards = get_alive_player_cards() + get_alive_enemy_cards()
	for card in all_cards:
		if card and not card.is_dead():
			# 处理眩晕
			if card.is_stunned:
				card.stun_turns -= 1
				if card.stun_turns <= 0:
					card.is_stunned = false
					card.can_attack = true
					card.remove_status_effect("眩晕")
					print("%s 从眩晕中恢复" % card.card_name)
			
			# 处理中毒
			if card.is_poisoned:
				card.take_damage(card.poison_damage)
				print("%s 受到中毒伤害: %d" % [card.card_name, card.poison_damage])

## 获取存活的玩家卡牌
func get_alive_player_cards() -> Array:
	var alive_cards = []
	for card in player_cards:
		if card and not card.is_dead():
			alive_cards.append(card)
	return alive_cards

## 获取存活的敌人卡牌
func get_alive_enemy_cards() -> Array:
	var alive_cards = []
	for card in enemy_cards:
		if card and not card.is_dead():
			alive_cards.append(card)
	return alive_cards

## 处理对手操作（在线模式）
func _on_opponent_action_received(action_data: Dictionary):
	if not is_online_mode:
		return
	
	var from_player_id = action_data.get("from", "")
	var is_my_action = (from_player_id == NetworkManager.player_id)
	
	print("收到服务器操作: %s (来自: %s, 是否自己: %s)" % [action_data.action, from_player_id, is_my_action])
	
	# 🎯 同步行动点（如果服务器提供了）
	if action_data.has("blue_actions_used") and action_data.has("red_actions_used"):
		var blue_actions = action_data.get("blue_actions_used", 0)
		var red_actions = action_data.get("red_actions_used", 0)
		
		# ⚠️ 关键：如果是自己的操作，不同步（避免覆盖本地use_action的结果）
		# 只同步对方的操作
		if is_my_action:
			# 自己的操作：完全信任客户端的use_action结果，不同步
			print("🎯 自己的操作，不同步行动点（本地已更新）")
			# 注意：这里不发送actions_changed信号，因为use_action已经发送过了
		else:
			# 对方的操作：完全同步服务器的行动点
			if NetworkManager.is_host:
				# 房主收到客户端的操作：更新enemy（红方）
				player_actions_used = blue_actions
				enemy_actions_used = red_actions
			else:
				# 客户端收到房主的操作：更新enemy（蓝方）
				player_actions_used = red_actions
				enemy_actions_used = blue_actions
			
			print("🎯 对方操作，同步行动点: 我方%d/3, 敌方%d/3" % [player_actions_used, enemy_actions_used])
			actions_changed.emit(player_actions_used, enemy_actions_used)
	
	match action_data.action:
		"attack":
			# ✅ 攻击结果双方都需要处理（服务器权威）
			_handle_opponent_attack(action_data.data)
		"skill":
			# ✅ 技能结果双方都需要处理
			_handle_opponent_skill(action_data.data)
		_:
			print("未知的对手操作类型: %s" % action_data.action)

## 🎯 处理服务器权威回合变化
func _on_server_turn_changed(turn_data: Dictionary):
	if not is_online_mode:
		return
	
	# 检查是否只是技能点更新（不是真正的回合切换）
	var is_skill_points_only = turn_data.get("is_skill_points_only", false)
	
	var host_sp = turn_data.get("host_skill_points", 4)
	var guest_sp = turn_data.get("guest_skill_points", 4)
	
	# 🌟 应用服务器的技能点（完全由服务器控制）
	if NetworkManager.is_host:
		# 房主视角：我方=host，敌方=guest
		player_skill_points = host_sp
		enemy_skill_points = guest_sp
	else:
		# 客户端视角：我方=guest，敌方=host
		player_skill_points = guest_sp
		enemy_skill_points = host_sp
	
	print("🎯 服务器技能点同步: 我方%d, 敌方%d" % [player_skill_points, enemy_skill_points])
	
	# 发送技能点变化信号
	skill_points_changed.emit(player_skill_points, enemy_skill_points)
	
	# ⚠️ 如果只是技能点更新，不同步行动点！
	if is_skill_points_only:
		print("✅ 技能点更新完成（不同步行动点，不切换回合）")
		return
	
	# 🎯 只在真正的回合切换时同步行动点
	var blue_actions = turn_data.get("blue_actions_used", 0)
	var red_actions = turn_data.get("red_actions_used", 0)
	
	if NetworkManager.is_host:
		# 房主视角：我方=blue，敌方=red
		player_actions_used = blue_actions
		enemy_actions_used = red_actions
	else:
		# 客户端视角：我方=red，敌方=blue
		player_actions_used = red_actions
		enemy_actions_used = blue_actions
	
	print("🎯 回合切换，服务器行动点同步: 我方%d/3, 敌方%d/3" % [player_actions_used, enemy_actions_used])
	
	# 发送行动点变化信号
	actions_changed.emit(player_actions_used, enemy_actions_used)
	
	# 以下是真正的回合切换逻辑
	var new_turn = turn_data.get("turn", 1)
	var is_my_turn_now = turn_data.get("is_my_turn", false)
	
	print("🎯 服务器回合变化: 第%d回合, 我的回合:%s" % [new_turn, is_my_turn_now])
	
	# 🚫 如果战斗已结束，不要切换回合
	if current_state_name == "battle_end":
		print("⚠️ 战斗已结束，忽略回合切换")
		return
	
	# 直接应用服务器的决定
	current_turn = new_turn
	current_player = is_my_turn_now
	
	# ⏰ 先发送回合变化信号和切换状态
	turn_changed.emit(is_my_turn_now)
	change_to_state("player_turn" if is_my_turn_now else "enemy_turn")
	
	# 🎯 回合切换后再处理被动技能结果（显示在新回合内）
	var passive_results = turn_data.get("passive_results", [])
	if passive_results.size() > 0:
		print("🎯 新回合开始，处理 %d 个被动技能结果" % passive_results.size())
		for passive_result in passive_results:
			_apply_passive_skill_result(passive_result)
	
	print("✅ 回合切换完成: 第%d回合, %s, 技能点: 我方%d/对方%d" % [
		current_turn, 
		"我方回合" if current_player else "对方回合",
		player_skill_points,
		enemy_skill_points
	])

## 处理服务器广播的攻击结果（权威）
func _handle_opponent_attack(data: Dictionary):
	var attacker_id = data.get("attacker_id", "")
	var target_id = data.get("target_id", "")
	var damage = data.get("damage", 0)
	var is_critical = data.get("is_critical", false)
	var is_dodged = data.get("is_dodged", false)
	
	print("🎮 服务器攻击结果: %s -> %s (伤害:%d, 暴击:%s, 闪避:%s)" % [
		attacker_id, target_id, damage, is_critical, is_dodged
	])
	
	# 查找卡牌
	var attacker = _find_card_by_id(attacker_id)
	var target = _find_card_by_id(target_id)
	
	if not attacker or not target:
		print("❌ 无法找到卡牌 (攻击者:%s, 目标:%s)" % [attacker != null, target != null])
		return
	
	# 🎮 直接应用服务器的生命值（不调用take_damage，避免重复计算护盾）
	var old_health = target.health
	target.health = data.get("target_health", target.health)
	print("🎮 %s 受到 %d 伤害: %d → %d" % [
		target.card_name, damage, old_health, target.health
	])
	
	# 如果有护盾变化，也需要从服务器同步（如果服务器返回了shield信息）
	if data.has("target_shield"):
		target.shield = data.get("target_shield", 0)
		print("🎮 %s 护盾: %d" % [target.card_name, target.shield])
	
	# 🎯 应用服务器同步的卡牌属性（被动技能产生的变化）
	if data.has("attacker_stats"):
		var attacker_stats = data.attacker_stats
		attacker.attack = attacker_stats.attack
		attacker.crit_rate = attacker_stats.crit_rate
		attacker.crit_damage = attacker_stats.crit_damage
		if attacker.card_name == "公孙离" and attacker_stats.has("dodge_rate"):
			# 公孙离：从服务器的dodge_rate反推dodge_bonus
			var server_dodge_rate = attacker_stats.dodge_rate
			attacker.dodge_rate = server_dodge_rate
			# 闪避率 = 0.30基础 + bonus，所以 bonus = 总闪避率 - 0.30
			attacker.gongsunli_dodge_bonus = max(0.0, server_dodge_rate - 0.30)
			print("🎯 更新公孙离闪避: %.1f%% (bonus: %.1f%%)" % [
				server_dodge_rate * 100, attacker.gongsunli_dodge_bonus * 100
			])
		print("🎯 更新攻击者属性: %s ATK:%d 暴击:%.1f%%" % [
			attacker.card_name, attacker.attack, attacker.crit_rate * 100
		])
	
	if data.has("target_stats"):
		var target_stats = data.target_stats
		target.attack = target_stats.attack
		target.crit_rate = target_stats.crit_rate
		target.crit_damage = target_stats.crit_damage
		if target.card_name == "公孙离" and target_stats.has("dodge_rate"):
			# 公孙离：从服务器的dodge_rate反推dodge_bonus
			var server_dodge_rate = target_stats.dodge_rate
			target.dodge_rate = server_dodge_rate
			target.gongsunli_dodge_bonus = max(0.0, server_dodge_rate - 0.30)
			print("🎯 更新公孙离闪避: %.1f%% (bonus: %.1f%%)" % [
				server_dodge_rate * 100, target.gongsunli_dodge_bonus * 100
			])
		print("🎯 更新目标属性: %s ATK:%d 暴击:%.1f%%" % [
			target.card_name, target.attack, target.crit_rate * 100
		])
	
	# 🎨 更新UI
	if entity_card_map.has(target):
		var target_entity = entity_card_map[target]
		if target_entity and is_instance_valid(target_entity):
			target_entity.update_display()
			print("🎨 已更新UI: %s" % target.card_name)
	
	# 🎨 更新攻击者UI（如果有属性变化）
	if data.has("attacker_stats") and entity_card_map.has(attacker):
		var attacker_entity = entity_card_map[attacker]
		if attacker_entity and is_instance_valid(attacker_entity):
			attacker_entity.update_display()
	
	# 🎯 孙尚香被动技能：千金重弩（攻击命中后获得技能点）
	if data.get("passive_skill_triggered", false) and data.has("skill_point_change"):
		var skill_point_change = data.skill_point_change
		var team = skill_point_change.team
		var old_value = skill_point_change.old_value
		var new_value = skill_point_change.new_value
		
		print("⭐ 孙尚香被动「千金重弩」触发！技能点 %d → %d" % [old_value, new_value])
		
		# 更新对应阵营的技能点
		if team == "blue":
			player_skill_points = new_value if is_card_in_player_side(attacker) else player_skill_points
			enemy_skill_points = new_value if not is_card_in_player_side(attacker) else enemy_skill_points
		else:  # team == "red"
			player_skill_points = new_value if not is_card_in_player_side(attacker) else player_skill_points
			enemy_skill_points = new_value if is_card_in_player_side(attacker) else enemy_skill_points
		
		# 发送技能点更新信号（让BattleScene更新UI）
		skill_points_changed.emit(player_skill_points, enemy_skill_points)
		
		# 记录到消息系统
		if message_system:
			message_system.add_passive_skill(
				attacker.card_name,
				"千金重弩",
				"攻击命中，获得1点技能点",
				{}
			)
	
	# 🦌 瑶被动技能：山鬼白鹿（受伤时为最低血量友方提供护盾）
	if data.get("yao_passive_triggered", false) and data.has("yao_passive_target"):
		var yao_target_data = data.yao_passive_target
		var shield_amount = data.yao_shield_amount
		
		print("🦌 瑶被动「山鬼白鹿」触发！为%s提供%d点护盾" % [yao_target_data.name, shield_amount])
		
		# 查找受益的友方卡牌
		var beneficiary = _find_card_by_id(yao_target_data.id)
		if beneficiary:
			# 更新护盾值
			beneficiary.shield = yao_target_data.shield
			print("   %s 护盾更新: → %d" % [beneficiary.card_name, beneficiary.shield])
			
			# 更新UI
			if entity_card_map.has(beneficiary):
				var beneficiary_entity = entity_card_map[beneficiary]
				if beneficiary_entity and is_instance_valid(beneficiary_entity):
					beneficiary_entity.update_display()
			
			# 记录到消息系统
			if message_system:
				message_system.add_passive_skill(
					target.card_name,
					"山鬼白鹿",
					"受伤时为%s提供%d点护盾" % [beneficiary.card_name, shield_amount],
					{
						"target_name": beneficiary.card_name,
						"shield_amount": shield_amount,
						"total_shield": beneficiary.shield
					}
				)
	
	# 📝 记录到消息系统（如果存在）
	if message_system:
		if is_dodged:
			# 🎯 使用闪避前的原始伤害
			var original_damage = data.get("original_damage", damage)
			message_system.add_dodge(target.card_name, attacker.card_name, original_damage)
		elif is_critical:
			message_system.add_combo_attack(attacker.card_name, target.card_name, damage, ["暴击"])
		else:
			message_system.add_attack(attacker.card_name, target.card_name, damage)
		
		# 如果目标死亡，记录死亡消息
		if target.is_dead():
			message_system.add_death(target.card_name)
	
	# 🎯 处理死亡（服务器已经判定）
	if data.get("target_dead", false) or target.is_dead():
		print("💀 %s 被击败" % target.card_name)
		# 发送死亡信号
		var target_is_player = is_card_in_player_side(target)
		card_died.emit(target, not target_is_player)
		
		# 🔥 从卡牌列表中移除（否则check_battle_end检测不到）
		if target_is_player:
			player_cards.erase(target)
			print("🗑️ 从玩家列表移除: %s (剩余%d张)" % [target.card_name, player_cards.size()])
		else:
			enemy_cards.erase(target)
			print("🗑️ 从敌方列表移除: %s (剩余%d张)" % [target.card_name, enemy_cards.size()])
		
		# 延迟检查战斗结束
		call_deferred("check_battle_end")
	
	print("✅ 攻击结果应用完成")

## 处理对手技能（应用服务器计算的结果）
func _handle_opponent_skill(data: Dictionary):
	print("🌐 处理技能结果: %s" % JSON.stringify(data))
	
	if not data.get("success", false):
		print("❌ 技能执行失败: %s" % data.get("error", "未知错误"))
		return
	
	var effect_type = data.get("effect_type", "")
	var caster_id = data.get("caster_id", "")
	
	print("🌐 应用技能效果: %s (%s)" % [effect_type, caster_id])
	
	# 根据技能效果类型应用结果
	match effect_type:
		"heal":
			_apply_heal_result(data)
		"attack_buff":
			_apply_attack_buff_result(data)
		"crit_buff":
			_apply_crit_buff_result(data)
		"true_damage_and_armor_reduction":
			_apply_sunshangxiang_skill_result(data)
		"shield_and_buff":
			_apply_shield_buff_result(data)
		"aoe_true_damage":
			_apply_aoe_damage_result(data)
		"shaosiyuan_heal":
			_apply_heal_result(data)
		"shaosiyuan_damage":
			_apply_single_damage_result(data)
		"yangyuhuan_damage":
			_apply_aoe_damage_result(data)
		"yangyuhuan_heal":
			_apply_aoe_heal_result(data)
		_:
			print("❌ 未知技能效果类型: %s" % effect_type)
	
	# 更新所有实体显示
	_update_all_entities_display()
	
	# 🎮 发送信号给BattleScene显示技能消息
	skill_executed.emit(data)
	
	print("✅ 技能结果应用完成")

## 根据卡牌ID查找卡牌
func _find_card_by_id(card_id: String) -> Card:
	# 在玩家卡牌中查找
	for card in player_cards:
		if card and card.card_id == card_id:
			return card
	
	# 在敌人卡牌中查找
	for card in enemy_cards:
		if card and card.card_id == card_id:
			return card
	
	return null

## ==================== 技能结果应用函数 ====================

## 应用治疗结果
func _apply_heal_result(data: Dictionary):
	var target_id = data.get("target_id", "")
	var heal_amount = data.get("heal_amount", 0)
	var target_health = data.get("target_health", 0)
	
	var target = _find_card_by_id(target_id)
	if target:
		var old_health = target.health
		target.health = target_health
		print("🌐 [治疗] %s: %d → %d (+%d)" % [target.card_name, old_health, target_health, heal_amount])
		print("   ✅ 客户端卡牌状态: %s HP:%d/%d" % [target.card_name, target.health, target.max_health])
		
		# 更新UI
		_update_battle_entity_display(target)
	else:
		print("无法找到目标卡牌: %s" % target_id)

## 应用攻击力增强结果
func _apply_attack_buff_result(data: Dictionary):
	var caster_id = data.get("caster_id", "")
	var old_attack = data.get("old_attack", 0)
	var new_attack = data.get("new_attack", 0)
	var buff_amount = data.get("buff_amount", 0)
	
	var caster = _find_card_by_id(caster_id)
	if caster:
		caster.attack = new_attack
		print("[攻击增强] %s: %d → %d (+%d)" % [caster.card_name, old_attack, new_attack, buff_amount])
		print("   客户端卡牌状态: %s ATK:%d" % [caster.card_name, caster.attack])
		print("   下次攻击将使用新攻击力%d计算伤害" % new_attack)
		
		# 更新UI
		_update_battle_entity_display(caster)
	else:
		print("无法找到施法者卡牌: %s" % caster_id)

## 应用暴击率增强结果
func _apply_crit_buff_result(data: Dictionary):
	var caster_id = data.get("caster_id", "")
	var old_crit_rate = data.get("old_crit_rate", 0.0)
	var new_crit_rate = data.get("new_crit_rate", 0.0)
	var old_crit_damage = data.get("old_crit_damage", 1.3)
	var new_crit_damage = data.get("new_crit_damage", 1.3)
	var overflow = data.get("overflow", 0.0)
	
	var caster = _find_card_by_id(caster_id)
	if caster:
		caster.crit_rate = new_crit_rate
		caster.crit_damage = new_crit_damage
		print("🌐 [暴击增强] %s: %.1f%% → %.1f%% (暴击率)" % [
			caster.card_name, old_crit_rate * 100, new_crit_rate * 100
		])
		print("   暴击效果: %.1f%% → %.1f%%" % [old_crit_damage * 100, new_crit_damage * 100])
		if overflow > 0:
			print("   💧 溢出转换: %.1f%% 暴击率转为 %.1f%% 暴击效果" % [overflow * 100, (overflow/2.0) * 100])
		print("   ✅ 客户端卡牌状态: %s 暴击%.1f%% 效果%.1f%%" % [
			caster.card_name, caster.crit_rate * 100, caster.crit_damage * 100
		])
		
		# 更新UI
		_update_battle_entity_display(caster)
	else:
		print("❌ [暴击增强] 找不到施法者卡牌: %s" % caster_id)

## 应用被动技能结果
func _apply_passive_skill_result(data: Dictionary):
	var card_id = data.get("card_id", "")
	var card_name = data.get("card_name", "")
	var passive_name = data.get("passive_name", "")
	var effect = data.get("effect", {})
	
	print("⭐ [被动技能] %s 触发 %s" % [card_name, passive_name])
	print("   📦 服务器数据: %s" % JSON.stringify(effect))
	
	# 查找卡牌
	var card = _find_card_by_id(card_id)
	if not card:
		print("❌ 找不到卡牌: %s" % card_id)
		return
	
	# 应用效果
	if effect.has("new_health"):
		var old_health = card.health
		card.health = effect.new_health
		var heal_amount = effect.get("heal_amount", 0)
		print("   💚 生命恢复: %d → %d (+%d)" % [old_health, card.health, heal_amount])
	
	if effect.has("new_shield"):
		var overflow_shield = effect.get("overflow_shield", 0)
		card.shield = effect.new_shield
		if overflow_shield > 0:
			print("   🛡️ 溢出护盾: +%d (总护盾: %d)" % [overflow_shield, card.shield])
	
	# 更新UI
	_update_battle_entity_display(card)
	
	# 发送被动技能触发信号（传递详细信息）
	var details = {
		"heal_amount": effect.get("heal_amount", 0),
		"overflow_shield": effect.get("overflow_shield", 0)
	}
	
	# 根据被动技能类型构建消息
	var message = ""
	if passive_name == "欢歌":
		var heal_amount = effect.get("heal_amount", 0)
		var overflow_shield = effect.get("overflow_shield", 0)
		print("🔍 欢歌被动数据: heal=%d, shield=%d" % [heal_amount, overflow_shield])
		
		if heal_amount > 0 and overflow_shield > 0:
			# 恢复生命 + 溢出护盾
			message = "恢复%d生命值，溢出%d点转为护盾" % [heal_amount, overflow_shield]
		elif heal_amount == 0 and overflow_shield > 0:
			# 满血，全部转护盾
			message = "生命值已满，获得%d点护盾" % overflow_shield
		elif heal_amount > 0 and overflow_shield == 0:
			# 只恢复生命
			message = "恢复%d生命值" % heal_amount
		else:
			# 满血且无溢出（不应该发生）
			message = "生命值已满"
	else:
		message = "生命+%d 护盾+%d" % [
			effect.get("heal_amount", 0),
			effect.get("overflow_shield", 0)
		]
	
	# 🎯 发射信号，传递完整的details数据
	passive_skill_triggered.emit(card, passive_name, message, details)

## 应用孙尚香技能结果（减护甲+真实伤害）
func _apply_sunshangxiang_skill_result(data: Dictionary):
	var target_id = data.get("target_id", "")
	var target_armor = data.get("target_armor", 0)
	var target_health = data.get("target_health", 0)
	var target_shield = data.get("target_shield", 0)
	var target_dead = data.get("target_dead", false)
	
	var target = _find_card_by_id(target_id)
	if target:
		target.armor = target_armor
		target.health = target_health
		target.shield = target_shield  # 🛡️ 同步护盾（真伤不消耗，但需要显示）
		print("🌐 应用孙尚香技能: %s 护甲→%d 生命值→%d 护盾:%d" % [target.card_name, target_armor, target_health, target_shield])
		
		# 更新UI
		_update_battle_entity_display(target)
		
		if target_dead:
			_handle_skill_card_death(target)

## 应用护盾和增强结果
func _apply_shield_buff_result(data: Dictionary):
	var target_id = data.get("target_id", "")
	var target_shield = data.get("target_shield", 0)
	var new_crit_rate = data.get("new_crit_rate", 0.0)
	var new_armor = data.get("new_armor", 0)
	
	var target = _find_card_by_id(target_id)
	if target:
		target.shield = target_shield
		target.crit_rate = new_crit_rate
		target.armor = new_armor
		print("🌐 应用护盾增强: %s 护盾%d 暴击率%.1f%% 护甲%d" % [
			target.card_name, target_shield, new_crit_rate * 100, new_armor
		])
		
		# 更新UI
		_update_battle_entity_display(target)

## 应用单体伤害结果（少司缘等）
func _apply_single_damage_result(data: Dictionary):
	var target_id = data.get("target_id", "")
	var damage = data.get("damage", 0)
	var target_health = data.get("target_health", 0)
	var target_shield = data.get("target_shield", 0)
	var target_dead = data.get("target_dead", false)
	
	var target = _find_card_by_id(target_id)
	if target:
		target.health = target_health
		target.shield = target_shield  # 🛡️ 同步护盾
		print("🌐 应用伤害: %s 受到%d伤害 → %d生命值 护盾:%d" % [target.card_name, damage, target_health, target_shield])
		
		# 更新UI
		_update_battle_entity_display(target)
		
		if target_dead:
			_handle_skill_card_death(target)

## 应用AOE伤害结果
func _apply_aoe_damage_result(data: Dictionary):
	var results = data.get("results", [])
	
	for result in results:
		var target_id = result.get("target_id", "")
		var damage = result.get("damage", 0)
		var target_health = result.get("target_health", 0)
		var target_shield = result.get("target_shield", 0)
		var target_dead = result.get("target_dead", false)
		
		var target = _find_card_by_id(target_id)
		if target:
			target.health = target_health
			target.shield = target_shield  # 🛡️ 同步护盾
			print("🌐 AOE伤害: %s 受到%d伤害 → %d生命值" % [target.card_name, damage, target_health])
			
			# 更新UI
			_update_battle_entity_display(target)
			
			if target_dead:
				_handle_skill_card_death(target)

## 应用AOE治疗结果
func _apply_aoe_heal_result(data: Dictionary):
	var results = data.get("results", [])
	
	for result in results:
		var target_id = result.get("target_id", "")
		var heal_amount = result.get("heal_amount", 0)
		var target_health = result.get("target_health", 0)
		
		var target = _find_card_by_id(target_id)
		if target:
			target.health = target_health
			print("🌐 AOE治疗: %s 恢复%d生命值 → %d" % [target.card_name, heal_amount, target_health])
			
			# 更新UI
			_update_battle_entity_display(target)

## 处理技能导致的卡牌死亡
func _handle_skill_card_death(card: Card):
	print("🌐 技能击杀: %s" % card.card_name)
	
	# 发送死亡信号
	var is_player = is_card_in_player_side(card)
	card_died.emit(card, not is_player)
	
	# 从卡牌列表中移除
	if is_player:
		player_cards.erase(card)
	else:
		enemy_cards.erase(card)
	
	# 检查战斗是否结束
	call_deferred("check_battle_end")

## 更新所有实体显示
func _update_all_entities_display():
	# 触发显示更新信号（BattleScene会监听）
	for card in player_cards:
		if card:
			_update_battle_entity_display(card)
	
	for enemy in enemy_cards:
		if enemy:
			_update_battle_entity_display(enemy)

# ================================
# 🎯 行动点系统函数
# ================================

## 使用1次行动
func use_action(is_player: bool) -> bool:
	if is_player:
		player_actions_used += 1
		print("🎯 玩家使用行动：%d/%d" % [player_actions_used, actions_per_turn])
	else:
		enemy_actions_used += 1
		print("🎯 敌人使用行动：%d/%d" % [enemy_actions_used, actions_per_turn])
	
	# 发送行动点变化信号
	actions_changed.emit(player_actions_used, enemy_actions_used)
	
	# 检查是否达到行动上限
	var actions_used = player_actions_used if is_player else enemy_actions_used
	if actions_used >= actions_per_turn:
		print("🎯 行动次数已用尽！")
		return true  # 返回true表示应该结束回合
	
	return false

## 检查是否还能行动
func can_act(is_player: bool) -> bool:
	var actions_used = player_actions_used if is_player else enemy_actions_used
	return actions_used < actions_per_turn

## 获取剩余行动次数
func get_remaining_actions(is_player: bool) -> int:
	var actions_used = player_actions_used if is_player else enemy_actions_used
	return actions_per_turn - actions_used

## 重置行动点（在回合开始时调用）
func reset_actions(is_player: bool):
	if is_player:
		player_actions_used = 0
		print("🎯 重置玩家行动点：0/%d" % actions_per_turn)
	else:
		enemy_actions_used = 0
		print("🎯 重置敌人行动点：0/%d" % actions_per_turn)
	
	# 发送行动点变化信号
	actions_changed.emit(player_actions_used, enemy_actions_used)

## 获取当前行动点信息（用于UI显示）
func get_action_info() -> Dictionary:
	return {
		"player_used": player_actions_used,
		"enemy_used": enemy_actions_used,
		"max_actions": actions_per_turn,
		"player_remaining": get_remaining_actions(true),
		"enemy_remaining": get_remaining_actions(false)
	}
