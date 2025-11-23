# BattleManager技能同步辅助函数
# 这些函数用于应用服务器计算的技能结果

extends Node

## 应用治疗结果
static func apply_heal_result(battle_manager, data: Dictionary):
	var target_id = data.get("target_id", "")
	var heal_amount = data.get("heal_amount", 0)
	var target_health = data.get("target_health", 0)
	
	var target = battle_manager._find_card_by_id(target_id)
	if target:
		target.health = target_health
		print("🌐 应用治疗: %s 恢复%d生命值 → %d" % [target.card_name, heal_amount, target_health])

## 应用攻击力增强结果
static func apply_attack_buff_result(battle_manager, data: Dictionary):
	var caster_id = data.get("caster_id", "")
	var new_attack = data.get("new_attack", 0)
	
	var caster = battle_manager._find_card_by_id(caster_id)
	if caster:
		caster.attack = new_attack
		print("🌐 应用攻击增强: %s 攻击力 → %d" % [caster.card_name, new_attack])

## 应用暴击率增强结果
static func apply_crit_buff_result(battle_manager, data: Dictionary):
	var caster_id = data.get("caster_id", "")
	var new_crit_rate = data.get("new_crit_rate", 0.0)
	var new_crit_damage = data.get("new_crit_damage", 1.3)
	
	var caster = battle_manager._find_card_by_id(caster_id)
	if caster:
		caster.crit_rate = new_crit_rate
		caster.crit_damage = new_crit_damage
		print("🌐 应用暴击增强: %s 暴击率%.1f%% 暴击效果%.1f%%" % [
			caster.card_name, new_crit_rate * 100, new_crit_damage * 100
		])

## 应用孙尚香技能结果（减护甲+真实伤害）
static func apply_sunshangxiang_skill_result(battle_manager, data: Dictionary):
	var target_id = data.get("target_id", "")
	var target_armor = data.get("target_armor", 0)
	var target_health = data.get("target_health", 0)
	var target_dead = data.get("target_dead", false)
	
	var target = battle_manager._find_card_by_id(target_id)
	if target:
		target.armor = target_armor
		target.health = target_health
		print("🌐 应用孙尚香技能: %s 护甲→%d 生命值→%d" % [target.card_name, target_armor, target_health])
		
		if target_dead and not target.is_dead():
			# 处理死亡
			_handle_card_death(battle_manager, target)

## 应用护盾和增强结果
static func apply_shield_buff_result(battle_manager, data: Dictionary):
	var target_id = data.get("target_id", "")
	var target_shield = data.get("target_shield", 0)
	var new_crit_rate = data.get("new_crit_rate", 0.0)
	var new_armor = data.get("new_armor", 0)
	
	var target = battle_manager._find_card_by_id(target_id)
	if target:
		target.shield = target_shield
		target.crit_rate = new_crit_rate
		target.armor = new_armor
		print("🌐 应用护盾增强: %s 护盾%d 暴击率%.1f%% 护甲%d" % [
			target.card_name, target_shield, new_crit_rate * 100, new_armor
		])

## 应用单体伤害结果
static func apply_single_damage_result(battle_manager, data: Dictionary):
	var target_id = data.get("target_id", "")
	var damage = data.get("damage", 0)
	var target_health = data.get("target_health", 0)
	var target_dead = data.get("target_dead", false)
	
	var target = battle_manager._find_card_by_id(target_id)
	if target:
		target.health = target_health
		print("🌐 应用伤害: %s 受到%d伤害 → %d生命值" % [target.card_name, damage, target_health])
		
		if target_dead:
			_handle_card_death(battle_manager, target)

## 应用AOE伤害结果
static func apply_aoe_damage_result(battle_manager, data: Dictionary):
	var results = data.get("results", [])
	
	for result in results:
		var target_id = result.get("target_id", "")
		var damage = result.get("damage", 0)
		var target_health = result.get("target_health", 0)
		var target_dead = result.get("target_dead", false)
		
		var target = battle_manager._find_card_by_id(target_id)
		if target:
			target.health = target_health
			print("🌐 AOE伤害: %s 受到%d伤害 → %d生命值" % [target.card_name, damage, target_health])
			
			if target_dead:
				_handle_card_death(battle_manager, target)

## 应用AOE治疗结果
static func apply_aoe_heal_result(battle_manager, data: Dictionary):
	var results = data.get("results", [])
	
	for result in results:
		var target_id = result.get("target_id", "")
		var heal_amount = result.get("heal_amount", 0)
		var target_health = result.get("target_health", 0)
		
		var target = battle_manager._find_card_by_id(target_id)
		if target:
			target.health = target_health
			print("🌐 AOE治疗: %s 恢复%d生命值 → %d" % [target.card_name, heal_amount, target_health])

## 处理卡牌死亡
static func _handle_card_death(battle_manager, card: Card):
	print("🌐 卡牌死亡: %s" % card.card_name)
	
	# 发送死亡信号
	var is_player = battle_manager.is_card_in_player_side(card)
	battle_manager.card_died.emit(card, not is_player)
	
	# 从卡牌列表中移除
	if is_player:
		battle_manager.player_cards.erase(card)
	else:
		battle_manager.enemy_cards.erase(card)
	
	# 检查战斗是否结束
	battle_manager.call_deferred("check_battle_end")
