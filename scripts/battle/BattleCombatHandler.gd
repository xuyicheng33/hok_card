class_name BattleCombatHandler
extends RefCounted

## 战斗执行处理器 - 负责攻击执行、回合管理、战斗结果处理
## 从BattleScene.gd拆分而来，专注于战斗流程逻辑

# 主场景引用
var battle_scene: Control

# 状态引用（从主场景获取）
var player_cards: Array:
	get: return battle_scene.player_cards if battle_scene else []
var enemy_cards: Array:
	get: return battle_scene.enemy_cards if battle_scene else []
var player_entities: Array:
	get: return battle_scene.player_entities if battle_scene else []
var enemy_entities: Array:
	get: return battle_scene.enemy_entities if battle_scene else []
var selected_card:
	get: return battle_scene.selected_card if battle_scene else null
	set(value): if battle_scene: battle_scene.selected_card = value
var is_selecting_target: bool:
	get: return battle_scene.is_selecting_target if battle_scene else false
	set(value): if battle_scene: battle_scene.is_selecting_target = value
var is_using_skill: bool:
	get: return battle_scene.is_using_skill if battle_scene else false
	set(value): if battle_scene: battle_scene.is_using_skill = value
var message_system:
	get: return battle_scene.ui_manager.message_system if (battle_scene and battle_scene.ui_manager) else null

func _init(scene: Control):
	battle_scene = scene
	print("BattleCombatHandler 初始化完成")

## 执行攻击
func execute_attack(attacker: Node, target: Node):
	# 重置选择状态
	reset_selection()

	# 播放攻击动画并等待完成
	var target_pos = target.global_position
	await attacker.play_attack_animation(target_pos)

	# 确保位置重置
	if attacker.original_position != Vector2.ZERO:
		attacker.position = attacker.original_position

	# 确定攻击者是否为玩家方
	var attacker_is_player = BattleManager.is_player_turn()

	# 执行战斗管理器的攻击逻辑（在线模式只发送意图）
	var result = BattleManager.execute_attack(attacker.get_card(), target.get_card(), attacker_is_player)

	# 🌐 在线模式：攻击意图已发送，等待服务器结果
	if BattleManager.is_online_mode:
		print("🌐 在线模式：攻击意图已发送")
		var should_end = BattleManager.use_action(attacker_is_player)
		if should_end:
			battle_scene.call_deferred("end_turn")
		return

	# 单机模式：处理本地攻击结果
	if result.success:
		target.update_display()

		if message_system:
			# 记录被动技能触发
			if result.lan_passive_triggered:
				var passive_details = {"damage_bonus": 0.3}
				message_system.add_passive_skill(attacker.get_card().card_name, "狩猎", "目标生命值低于50%，增伤+30%", passive_details)

			# 处理闪避
			if result.is_dodged:
				var dodge_details = {
					"dodge_rate": target.get_card().get_gongsunli_dodge_rate() if target.get_card().card_name == "公孙离" else 0.3
				}
				message_system.add_dodge(target.get_card().card_name, attacker.get_card().card_name, result.get("original_damage", result.final_damage), dodge_details)
			else:
				# 准备攻击详情
				var attack_details = {
					"attacker_attack": result.attacker.attack,
					"target_armor": result.target.armor,
					"base_damage": result.base_damage,
					"is_critical": result.is_critical,
					"crit_damage": result.crit_damage,
					"has_damage_bonus": result.has_damage_bonus,
					"damage_bonus_percent": result.get("damage_bonus_percent", 0)
				}

				# 组合效果消息
				var effects = []
				if result.is_critical:
					effects.append("暴击")
				if result.has_damage_bonus:
					effects.append("被动")

				if not effects.is_empty():
					message_system.add_combo_attack(attacker.get_card().card_name, target.get_card().card_name, result.final_damage, effects, attack_details)
				else:
					message_system.add_attack(attacker.get_card().card_name, target.get_card().card_name, result.final_damage, attack_details)

			# 记录死亡
			if result.target_dead:
				message_system.add_death(target.get_card().card_name)

		# 触发死亡动画
		if result.target_dead:
			target.take_damage(0)

	# 使用行动点，检查是否应该结束回合
	var should_end = BattleManager.use_action(attacker_is_player)
	if should_end:
		battle_scene.call_deferred("end_turn")

## 重置选择状态
func reset_selection():
	if selected_card:
		selected_card.set_selected(false)
		battle_scene.selected_card = null

	battle_scene.is_selecting_target = false
	battle_scene.is_using_skill = false

	# 隐藏取消技能按钮
	if battle_scene.ui_manager and battle_scene.ui_manager.cancel_skill_button:
		battle_scene.ui_manager.cancel_skill_button.visible = false

	# 重置所有卡牌的可攻击/可选择状态
	for i in range(player_cards.size() - 1, -1, -1):
		var entity = player_cards[i]
		if entity and is_instance_valid(entity):
			entity.set_targetable(false)
		else:
			player_cards.remove_at(i)

	for i in range(enemy_cards.size() - 1, -1, -1):
		var entity = enemy_cards[i]
		if entity and is_instance_valid(entity):
			entity.set_targetable(false)
		else:
			enemy_cards.remove_at(i)

	# 兼容旧数组
	for i in range(enemy_entities.size() - 1, -1, -1):
		var enemy = enemy_entities[i]
		if is_instance_valid(enemy):
			enemy.set_targetable(false)
		else:
			enemy_entities.remove_at(i)

	for i in range(player_entities.size() - 1, -1, -1):
		var player = player_entities[i]
		if is_instance_valid(player):
			player.set_targetable(false)
		else:
			player_entities.remove_at(i)

## 结束回合
func end_turn():
	print("结束回合")
	reset_selection()

	# 验证所有卡牌位置
	verify_all_card_positions()

	# 🌐 在线模式：只发送消息，等待服务器响应
	if BattleManager.is_online_mode and NetworkManager:
		NetworkManager.send_end_turn()
		print("🌐 已发送结束回合，等待服务器响应...")
		return

	# 单机模式：立即切换回合
	BattleManager.next_turn()

## 验证所有卡牌位置
func verify_all_card_positions():
	var fixed_count = 0

	for entity in player_cards:
		if entity and is_instance_valid(entity):
			if entity.verify_and_fix_position():
				fixed_count += 1

	for entity in enemy_cards:
		if entity and is_instance_valid(entity):
			if entity.verify_and_fix_position():
				fixed_count += 1

	for entity in player_entities:
		if is_instance_valid(entity):
			if entity.verify_and_fix_position():
				fixed_count += 1

	for entity in enemy_entities:
		if is_instance_valid(entity):
			if entity.verify_and_fix_position():
				fixed_count += 1

	if fixed_count > 0:
		print("已修复 %d 张卡牌位置" % fixed_count)

## 处理回合变化
func handle_turn_changed(is_player_turn: bool):
	var battle_info = BattleManager.get_battle_info()

	if battle_scene.ui_manager:
		battle_scene.ui_manager.update_turn_info(battle_info.turn, is_player_turn)

	# 消息系统记录回合开始
	if message_system:
		var player_name = "玩家" if is_player_turn else "敌方"
		message_system.start_new_turn(battle_info.turn, player_name)

	# 更新按钮和状态
	if battle_scene.ui_manager:
		var status_msg = ""
		if is_player_turn:
			var current_card = battle_scene.get_first_alive_player_card()
			status_msg = "%s的回合 - 选择攻击或发动技能" % (current_card.get_card().card_name if current_card else "玩家")
		else:
			var current_card = battle_scene.get_first_alive_enemy_card()
			status_msg = "%s的回合 - 选择攻击或发动技能" % (current_card.get_card().card_name if current_card else "敌方")

		battle_scene.ui_manager.update_battle_status(status_msg)

		if battle_scene.ui_manager.end_turn_button:
			battle_scene.ui_manager.end_turn_button.disabled = false
		if battle_scene.ui_manager.use_skill_button:
			battle_scene.ui_manager.use_skill_button.disabled = false
			battle_scene.ui_manager.use_skill_button.text = "发动技能"

	print("\n=== 第 %d 回合开始 ===" % battle_info.turn)
	print("当前回合: %s" % ("玩家" if is_player_turn else "敌方"))

	# 更新卡牌显示
	battle_scene.call_deferred("update_cards_display")

## 处理战斗结束
func handle_battle_ended(result: Dictionary):
	if message_system:
		message_system.add_battle_end(result.victory)

	var message = "战斗结束 - %s！" % ("胜利" if result.victory else "失败")

	if battle_scene.ui_manager:
		battle_scene.ui_manager.update_battle_status(message)
		if battle_scene.ui_manager.end_turn_button:
			battle_scene.ui_manager.end_turn_button.disabled = true
