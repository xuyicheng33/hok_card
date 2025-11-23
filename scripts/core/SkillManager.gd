extends Node

## 技能管理器
## 统一管理所有技能逻辑，提供模块化的技能系统
## 遵循项目规范：技能点在生效时扣除，支持扩展性

# 技能效果注册表
var skill_effects: Dictionary = {}
var initialized: bool = false

# 信号定义
signal skill_executed(caster_name: String, skill_name: String, target_name: String, result: Dictionary)
signal skill_failed(caster_name: String, skill_name: String, reason: String)

func _ready():
	print("技能管理器初始化...")
	initialize()

## 初始化技能系统
func initialize():
	if not initialized:
		register_default_skills()
		initialized = true
		print("技能管理器初始化完成")

## 注册默认技能效果
func register_default_skills():
	print("注册默认技能效果...")
	
	# 注册治疗技能
	register_skill_effect("heal", _execute_heal_effect)
	
	# 注册攻击力增强技能
	register_skill_effect("attack_buff", _execute_attack_buff_effect)
	
	# 注册暴击率增强技能
	register_skill_effect("crit_buff", _execute_crit_buff_effect)
	
	# 注册真实伤害技能
	register_skill_effect("true_damage", _execute_true_damage_effect)
	
	# 注册护盾和属性增强技能
	register_skill_effect("shield_and_buff", _execute_shield_and_buff_effect)
	
	# 注册大乔的真实伤害技能
	register_skill_effect("daqiao_true_damage", _execute_daqiao_true_damage_effect)
	
	# 注册少司缘的技能效果
	register_skill_effect("shaosiyuan_skill", _execute_shaosiyuan_skill_effect)
	
	# 注册杨玉环的技能效果
	register_skill_effect("yangyuhuan_skill", _execute_yangyuhuan_skill_effect)
	
	print("默认技能效果注册完成")

## 注册技能效果
## @param effect_name: 技能效果名称
## @param effect_function: 技能效果执行函数
func register_skill_effect(effect_name: String, effect_function: Callable):
	skill_effects[effect_name] = effect_function
	print("注册技能效果: %s" % effect_name)

## 执行技能（统一入口）
## @param caster: 施法者实体
## @param skill_name: 技能名称
## @param target: 目标实体（可选）
## @param params: 技能参数（可选）
func execute_skill(caster, skill_name: String, target = null, params: Dictionary = {}) -> Dictionary:
	print("SkillManager: 执行技能 %s -> %s" % [caster.get_card().card_name, skill_name])
	
	var caster_card = caster.get_card()
	var skill_cost = caster_card.skill_cost
	var is_player = caster.is_player()
	
	# 检查技能点是否足够（遵循规范：此时不扣除）
	if not BattleManager.can_use_skill(is_player, skill_cost):
		var error_msg = "技能点不足，无法发动技能"
		print("SkillManager: %s" % error_msg)
		skill_failed.emit(caster_card.card_name, skill_name, error_msg)
		return {"success": false, "error": error_msg}
	
	# 根据技能名称查找对应效果
	var skill_data = get_skill_data(caster_card.card_name, skill_name)
	if not skill_data:
		var error_msg = "未知的技能: %s" % skill_name
		print("SkillManager: %s" % error_msg)
		skill_failed.emit(caster_card.card_name, skill_name, error_msg)
		return {"success": false, "error": error_msg}
	
	# 执行技能效果
	var result = _execute_skill_internal(caster, target, skill_data, params)
	
	if result.success:
		# 技能成功执行，扣除技能点
		if not BattleManager.consume_skill_points(is_player, skill_cost):
			print("警告: 技能执行成功但技能点扣除失败")
		
		skill_executed.emit(
			caster_card.card_name, 
			skill_name, 
			target.get_card().card_name if target else "self",
			result
		)
		print("SkillManager: 技能 %s 执行成功" % skill_name)
	else:
		skill_failed.emit(caster_card.card_name, skill_name, result.get("error", "未知错误"))
		print("SkillManager: 技能 %s 执行失败: %s" % [skill_name, result.get("error", "")])
	
	return result

## 获取技能数据
func get_skill_data(card_name: String, skill_name: String) -> Dictionary:
	# 基于卡牌名称和技能名称返回技能配置
	match card_name:
		"朵莉亚":
			if skill_name == "人鱼之赐":
				return {
					"effect_type": "heal",
					"base_amount": 130,
					"target_required": true,
					"target_type": "ally"
				}
		"澜":
			if skill_name == "鲨之猎刃":
				return {
					"effect_type": "attack_buff",
					"base_amount": 100,
					"target_required": false,
					"target_type": "self"
				}
		"公孙离":
			if skill_name == "晚云落":
				return {
					"effect_type": "crit_buff", 
					"base_amount": 0.40,
					"target_required": false,
					"target_type": "self"
				}
		"孙尚香":
			if skill_name == "红莲爆弹":
				return {
					"effect_type": "true_damage",
					"base_damage": 75,
					"armor_reduction": 60,
					"target_required": true,
					"target_type": "enemy"
				}
		"瑶":
			if skill_name == "鹿灵守心":
				return {
					"effect_type": "shield_and_buff",
					"shield_base": 150,
					"shield_percentage": 0.08,
					"crit_buff": 0.05,
					"armor_buff": 20,
					"target_required": true,
					"target_type": "ally"
				}
		"大乔":
			if skill_name == "沧海之曜":
				return {
					"effect_type": "daqiao_true_damage",
					"target_required": false,
					"target_type": "all_enemies"
				}
		"少司缘":
			if skill_name == "两同心":
				return {
					"effect_type": "shaosiyuan_skill",
					"target_required": true,
					"target_type": "any"
				}
		"杨玉环":
			if skill_name == "惊鸿曲":
				return {
					"effect_type": "yangyuhuan_skill",
					"target_required": false,
					"target_type": "conditional"
				}
	
	return {}

## 内部技能执行逻辑
func _execute_skill_internal(caster, target, skill_data: Dictionary, params: Dictionary) -> Dictionary:
	var effect_type = skill_data.get("effect_type", "")
	
	if not skill_effects.has(effect_type):
		return {"success": false, "error": "未注册的技能效果: %s" % effect_type}
	
	var effect_function = skill_effects[effect_type]
	
	# 合并技能数据和参数
	var combined_params = skill_data.duplicate()
	combined_params.merge(params)
	
	# 执行技能效果
	return effect_function.call(caster, target, combined_params)

## ================== 技能效果实现 ==================

## 治疗效果
func _execute_heal_effect(caster, target, params: Dictionary) -> Dictionary:
	if not target:
		return {"success": false, "error": "治疗技能需要目标"}
	
	var heal_amount = params.get("base_amount", 100)
	var target_card = target.get_card()
	var old_health = target_card.health
	
	# 执行治疗
	target_card.heal(heal_amount)
	
	# 更新显示
	target.update_display()
	
	var actual_heal = target_card.health - old_health
	
	return {
		"success": true,
		"effect_type": "heal",
		"heal_amount": actual_heal,
		"target_name": target_card.card_name
	}

## 攻击力增强效果
func _execute_attack_buff_effect(caster, _target, params: Dictionary) -> Dictionary:
	var buff_amount = params.get("base_amount", 100)
	var caster_card = caster.get_card()
	var old_attack = caster_card.attack
	
	# 增加攻击力
	caster_card.attack += buff_amount
	
	# 更新显示
	caster.update_display()
	
	return {
		"success": true,
		"effect_type": "attack_buff",
		"old_attack": old_attack,
		"new_attack": caster_card.attack,
		"buff_amount": buff_amount
	}

## 暴击率增强效果（支持溢出转换）
func _execute_crit_buff_effect(caster, _target, params: Dictionary) -> Dictionary:
	var buff_amount = params.get("base_amount", 0.5)
	var caster_card = caster.get_card()
	var old_crit_rate = caster_card.crit_rate
	var old_crit_damage = caster_card.crit_damage
	
	# 计算新的暴击率
	var new_crit_rate = old_crit_rate + buff_amount
	var overflow = 0.0
	var crit_damage_bonus = 0.0
	
	# 处理暴击率溢出（公孙离特有机制）
	if caster_card.card_name == "公孙离" and new_crit_rate > 1.0:
		overflow = new_crit_rate - 1.0
		new_crit_rate = 1.0
		# 公孙离的溢出转换比例为2:1
		crit_damage_bonus = overflow / 2.0
	elif new_crit_rate > 1.0:
		# 其他英雄的处理方式（不转换，直接限制在100%）
		overflow = new_crit_rate - 1.0
		new_crit_rate = 1.0
		crit_damage_bonus = 0.0
	
	# 应用暴击率变化
	caster_card.crit_rate = new_crit_rate
	
	# 应用暴击效果变化（如有溢出）
	var new_crit_damage = old_crit_damage
	if crit_damage_bonus > 0:
		new_crit_damage = old_crit_damage + crit_damage_bonus
		# 确保不超过暴击效果上限（2.0）
		new_crit_damage = min(new_crit_damage, 2.0)
		caster_card.crit_damage = new_crit_damage
	
	# 更新显示
	caster.update_display()
	
	return {
		"success": true,
		"effect_type": "crit_buff",
		"old_crit_rate": old_crit_rate,
		"new_crit_rate": new_crit_rate,
		"old_crit_damage": old_crit_damage,
		"new_crit_damage": new_crit_damage,
		"buff_amount": buff_amount,
		"overflow": overflow,
		"crit_damage_bonus": crit_damage_bonus
	}

## 检查技能是否需要目标选择
func requires_target_selection(card_name: String, skill_name: String) -> bool:
	var skill_data = get_skill_data(card_name, skill_name)
	return skill_data.get("target_required", false)

## 获取技能目标类型
func get_target_type(card_name: String, skill_name: String) -> String:
	var skill_data = get_skill_data(card_name, skill_name)
	return skill_data.get("target_type", "self")

## 验证目标是否有效
func is_valid_target(caster, target, card_name: String, skill_name: String) -> bool:
	var target_type = get_target_type(card_name, skill_name)
	
	match target_type:
		"ally":
			# 同阵营目标
			var same_side = (caster.is_player() and target.is_player()) or (not caster.is_player() and not target.is_player())
			return same_side and not target.get_card().is_dead()
		"enemy":
			# 敌对阵营目标
			var different_side = (caster.is_player() and not target.is_player()) or (not caster.is_player() and target.is_player())
			return different_side and not target.get_card().is_dead()
		"self":
			# 自己
			return target == caster
		"any":
			# 任意目标
			return not target.get_card().is_dead()
	
	return false

## 获取所有已注册的技能效果
func get_registered_effects() -> Array:
	return skill_effects.keys()

## 调试：打印所有技能数据
func debug_print_skills():
	print("=== 技能管理器调试信息 ===")
	print("已注册技能效果: %s" % str(get_registered_effects()))
	print("=========================")

## 真实伤害效果（孙尚香的红莲爆弹）
func _execute_true_damage_effect(caster, target, params: Dictionary) -> Dictionary:
	if not target:
		return {"success": false, "error": "真实伤害技能需要目标"}
	
	var damage_amount = params.get("base_damage", 50)
	var armor_reduction = params.get("armor_reduction", 50)
	var target_card = target.get_card()
	var caster_card = caster.get_card()
	
	# 1. 永久性减少护甲值
	var old_armor = target_card.armor
	target_card.armor = max(0, target_card.armor - armor_reduction)  # 护甲不能为负
	var actual_armor_reduction = old_armor - target_card.armor
	
	# 2. 造成真实伤害（无视护甲和护盾，但可以暴击）
	var final_damage = damage_amount
	var is_crit = false
	
	# 检查是否暴击
	if randf() < caster_card.crit_rate:
		is_crit = true
		final_damage = int(damage_amount * caster_card.crit_damage)
	
	# 直接减少生命值（真实伤害）
	var old_health = target_card.health
	target_card.health = max(0, target_card.health - final_damage)
	var actual_damage = old_health - target_card.health
	
	# 检查目标是否死亡并通知BattleManager
	if target_card.is_dead():
		# 发送死亡信号
		BattleManager.card_died.emit(target_card, not caster.is_player())
		
		# 从相应数组中移除死亡卡牌
		if caster.is_player():
			BattleManager.enemy_cards.erase(target_card)
		else:
			BattleManager.player_cards.erase(target_card)
		
		# 调用BattleScene中的实体销毁方法
		_notify_battle_scene_entity_destroyed(target_card)
	
	# 更新显示
	target.update_display()
	
	return {
		"success": true,
		"effect_type": "true_damage",
		"damage_amount": actual_damage,
		"armor_reduction": actual_armor_reduction,
		"is_crit": is_crit,
		"original_damage": damage_amount,
		"final_damage": final_damage,
		"target_name": target_card.card_name,
		"old_armor": old_armor,
		"new_armor": target_card.armor
	}

## 护盾和属性增强效果（瑶的鹿灵守心）
func _execute_shield_and_buff_effect(caster, target, params: Dictionary) -> Dictionary:
	if not target:
		return {"success": false, "error": "护盾技能需要目标"}
	
	var caster_card = caster.get_card()
	var target_card = target.get_card()
	
	# 记录目标强化前的属性
	var old_crit_rate = target_card.crit_rate
	var old_armor = target_card.armor
	var old_shield = target_card.shield
	
	# 计算护盾值：基础值 + 瑶当前生命值的百分比
	var shield_amount = params.get("shield_base", 150)
	var shield_percentage = params.get("shield_percentage", 0.08)
	var calculated_shield = int(caster_card.health * shield_percentage)
	shield_amount += calculated_shield
	
	# 添加护盾
	target_card.add_shield(shield_amount)
	
	# 增加暴击率
	var crit_buff = params.get("crit_buff", 0.05)
	target_card.add_crit_rate(crit_buff)
	
	# 增加护甲
	var armor_buff = params.get("armor_buff", 20)
	target_card.armor += armor_buff
	
	# 更新显示
	target.update_display()
	
	return {
		"success": true,
		"effect_type": "shield_and_buff",
		"shield_amount": shield_amount,
		"crit_buff": crit_buff,
		"armor_buff": armor_buff,
		"target_name": target_card.card_name,
		"base_shield": params.get("shield_base", 150),
		"health_percentage": shield_percentage * 100,
		"calculated_shield": calculated_shield,
		"yao_health": caster_card.health,
		# 增加更多属性数据用于消息显示
		"old_crit_rate": old_crit_rate,
		"new_crit_rate": target_card.crit_rate,
		"old_armor": old_armor,
		"new_armor": target_card.armor,
		"old_shield": old_shield,
		"new_shield": target_card.shield,
		"target_current_crit_rate": target_card.crit_rate * 100, # 转为百分比
		"target_current_armor": target_card.armor,
		"target_current_shield": target_card.shield
	}

## 大乔的真实伤害技能（沧海之曜）
func _execute_daqiao_true_damage_effect(caster, _target, params: Dictionary) -> Dictionary:
	var caster_card = caster.get_card()
	
	# 获取所有敌方卡牌
	var enemy_cards = []
	if caster.is_player():
		# 获取敌方卡牌（通过BattleManager）
		enemy_cards = BattleManager.get_alive_enemy_cards()
	else:
		# 获取敌方卡牌（通过BattleManager）
		enemy_cards = BattleManager.get_alive_player_cards()
	
	if enemy_cards.is_empty():
		return {"success": false, "error": "没有敌方目标"}
	
	# 记录伤害结果
	var damage_results = []
	var total_damage = 0
	
	# 获取大乔自己的已损生命值
	var caster_lost_health = caster_card.get_lost_health()
	
	# 对每个敌方英雄造成真实伤害
	for enemy_card in enemy_cards:
		if enemy_card and not enemy_card.is_dead():
			# 计算伤害：(大乔自己的已损生命值+攻击力)/5
			var damage = int((caster_lost_health + caster_card.attack) / 5)
			
			# 造成真实伤害（无视护甲和护盾，但可以暴击）
			var final_damage = damage
			var is_crit = false
			var crit_damage_value = 1.3 # 默认暴击倍率
			
			# 检查是否暴击
			if randf() < caster_card.crit_rate:
				is_crit = true
				crit_damage_value = caster_card.crit_damage
				final_damage = int(damage * crit_damage_value)
			
			# 直接减少生命值（真实伤害）
			var old_health = enemy_card.health
			enemy_card.health = max(0, enemy_card.health - final_damage)
			var actual_damage = old_health - enemy_card.health
			
			# 检查目标是否死亡并通知BattleManager
			if enemy_card.is_dead():
				# 发送死亡信号
				BattleManager.card_died.emit(enemy_card, not caster.is_player())
				
				# 从相应数组中移除死亡卡牌
				if caster.is_player():
					BattleManager.enemy_cards.erase(enemy_card)
				else:
					BattleManager.player_cards.erase(enemy_card)
				
				# 调用BattleScene中的实体销毁方法
				_notify_battle_scene_entity_destroyed(enemy_card)
			
			# 更新显示
			# 通过全局访问BattleScene并更新显示
			_update_battle_entity_display(enemy_card)
			
			total_damage += actual_damage
			
			# 记录伤害结果
			damage_results.append({
				"target_name": enemy_card.card_name,
				"damage": actual_damage,
				"is_crit": is_crit,
				"lost_health": caster_lost_health,  # 大乔自己的已损生命值
				"base_damage": damage,
				"final_damage": final_damage,
				"caster_attack": caster_card.attack,
				"crit_damage": crit_damage_value
			})
	
	return {
		"success": true,
		"effect_type": "daqiao_true_damage",
		"total_damage": total_damage,
		"damage_results": damage_results,
		"target_count": enemy_cards.size()
	}

## 更新战斗实体显示的辅助方法
func _update_battle_entity_display(card: Card):
	# 通过全局访问BattleScene并更新特定卡牌的显示
	var battle_scene = get_tree().get_root().get_node("BattleScene")
	if battle_scene and battle_scene.has_method("update_card_entity_display"):
		battle_scene.update_card_entity_display(card)

## 少司缘的"两同心"技能效果
func _execute_shaosiyuan_skill_effect(caster, target, params: Dictionary) -> Dictionary:
	if not target:
		return {"success": false, "error": "两同心技能需要目标"}
	
	var caster_card = caster.get_card()
	var target_card = target.get_card()
	
	# 判断目标是友方还是敌方
	var is_ally = (caster.is_player() and target.is_player()) or (not caster.is_player() and not target.is_player())
	
	# 获取少司缘的偷取点数
	var stolen_points = caster_card.get_shaosiyuan_stolen_points()
	var points = min(4, stolen_points)  # 用于计算的点数上限为4
	
	if is_ally:
		# 缘起（生）：治疗友方单位
		var heal_amount = 100 + points * 40
		
		# 记录治疗前的状态
		var old_health = target_card.health
		var old_shield = target_card.shield
		
		# 执行治疗
		target_card.heal(heal_amount)
		
		# 更新显示
		target.update_display()
		
		var actual_heal = target_card.health - old_health
		
		return {
			"success": true,
			"effect_type": "shaosiyuan_heal",
			"heal_amount": actual_heal,
			"base_heal": 100,
			"points": points,
			"point_multiplier": 40,
			"target_name": target_card.card_name,
			"old_health": old_health,
			"new_health": target_card.health,
			"old_shield": old_shield,
			"new_shield": target_card.shield
		}
	else:
		# 缘灭（灭）：对敌方造成真实伤害
		var base_damage = 150  # 基础伤害值
		var calculated_damage = base_damage + points * 50  # 实际计算的伤害值
		
		# 造成真实伤害（无视护甲和护盾，但可以暴击和增伤）
		var final_damage = float(calculated_damage)
		var is_crit = false
		var crit_damage_value = 1.3 # 默认暴击倍率
		
		# 检查是否暴击
		if randf() < caster_card.crit_rate:
			is_crit = true
			crit_damage_value = caster_card.crit_damage
			final_damage = final_damage * crit_damage_value
		
		# 应用增伤
		if caster_card.damage_bonus > 0:
			final_damage = final_damage * (1.0 + caster_card.damage_bonus)
		
		# 四舍五入处理
		final_damage = round(final_damage)
		
		# 直接减少生命值（真实伤害）
		var old_health = target_card.health
		target_card.health = max(0, target_card.health - int(final_damage))
		var actual_damage = old_health - target_card.health
		
		# 检查目标是否死亡并通知BattleManager
		if target_card.is_dead():
			# 发送死亡信号
			BattleManager.card_died.emit(target_card, not caster.is_player())
			
			# 从相应数组中移除死亡卡牌
			if caster.is_player():
				BattleManager.enemy_cards.erase(target_card)
			else:
				BattleManager.player_cards.erase(target_card)
			
			# 调用BattleScene中的实体销毁方法
			_notify_battle_scene_entity_destroyed(target_card)
		
		# 更新显示
		target.update_display()
		
		return {
			"success": true,
			"effect_type": "shaosiyuan_damage",
			"damage_amount": actual_damage,
			"base_damage": base_damage,  # 基础伤害值150
			"calculated_damage": calculated_damage,  # 计算后的伤害值
			"points": points,
			"point_multiplier": 50,
			"is_crit": is_crit,
			"crit_damage": crit_damage_value,
			"has_damage_bonus": caster_card.damage_bonus > 0,
			"damage_bonus_percent": caster_card.damage_bonus * 100,
			"final_damage": int(final_damage),
			"target_name": target_card.card_name,
			"old_health": old_health,
			"new_health": target_card.health
		}

## 杨玉环的"惊鸿曲"技能效果
func _execute_yangyuhuan_skill_effect(caster, _target, params: Dictionary) -> Dictionary:
	var caster_card = caster.get_card()
	
	# 标记主动技能已使用，下次普攻触发被动技能
	caster_card.yangyuhuan_skill_used = true
	
	# 判断当前生命值状态
	var health_percentage = float(caster_card.health) / float(caster_card.max_health)
	var is_high_health = health_percentage >= 0.5
	
	if is_high_health:
		# 【惊鸿·伤】(当自身生命值 ≥ 50%时): 对所有敌方单位造成"(0.3 * 攻击力 + 0.2 * 已损生命值)"点真实伤害
		return _execute_yangyuhuan_damage_effect(caster, params)
	else:
		# 【惊鸿·愈】(当自身生命值 < 50%时): 为所有己方单位恢复"(0.3 * 攻击力 + 0.2 * 当前生命值)"点生命值
		return _execute_yangyuhuan_heal_effect(caster, params)

## 杨玉环的真实伤害效果
func _execute_yangyuhuan_damage_effect(caster, params: Dictionary) -> Dictionary:
	var caster_card = caster.get_card()
	
	# 获取所有敌方卡牌
	var enemy_cards = []
	if caster.is_player():
		# 获取敌方卡牌（通过BattleManager）
		enemy_cards = BattleManager.get_alive_enemy_cards()
	else:
		# 获取敌方卡牌（通过BattleManager）
		enemy_cards = BattleManager.get_alive_player_cards()
	
	if enemy_cards.is_empty():
		return {"success": false, "error": "没有敌方目标"}
	
	# 记录伤害结果
	var damage_results = []
	var total_damage = 0
	
	# 计算伤害：(0.3 * 攻击力 + 0.2 * 已损生命值)
	var lost_health = caster_card.get_lost_health()
	var damage = int(0.3 * caster_card.attack + 0.2 * lost_health)
	
	# 对每个敌方英雄造成真实伤害
	for enemy_card in enemy_cards:
		if enemy_card and not enemy_card.is_dead():
			# 造成真实伤害（无视护甲和护盾，但可以暴击）
			var final_damage = damage
			var is_crit = false
			var crit_damage_value = 1.3 # 默认暴击倍率
			
			# 检查是否暴击
			if randf() < caster_card.crit_rate:
				is_crit = true
				crit_damage_value = caster_card.crit_damage
				final_damage = int(damage * crit_damage_value)
			
			# 直接减少生命值（真实伤害）
			var old_health = enemy_card.health
			enemy_card.health = max(0, enemy_card.health - final_damage)
			var actual_damage = old_health - enemy_card.health
			
			# 检查目标是否死亡并通知BattleManager
			if enemy_card.is_dead():
				# 发送死亡信号
				BattleManager.card_died.emit(enemy_card, not caster.is_player())
				
				# 从相应数组中移除死亡卡牌
				if caster.is_player():
					BattleManager.enemy_cards.erase(enemy_card)
				else:
					BattleManager.player_cards.erase(enemy_card)
				
				# 调用BattleScene中的实体销毁方法
				_notify_battle_scene_entity_destroyed(enemy_card)
			
			# 更新显示
			# 通过全局访问BattleScene并更新显示
			_update_battle_entity_display(enemy_card)
			
			total_damage += actual_damage
			
			# 记录伤害结果
			damage_results.append({
				"target_name": enemy_card.card_name,
				"damage": actual_damage,
				"is_crit": is_crit,
				"lost_health": lost_health,  # 杨玉环自己的已损生命值
				"base_damage": damage,
				"final_damage": final_damage,
				"caster_attack": caster_card.attack,
				"crit_damage": crit_damage_value
			})
	
	# 检查战斗是否结束
	BattleManager.check_battle_end()
	
	return {
		"success": true,
		"effect_type": "yangyuhuan_damage",
		"total_damage": total_damage,
		"damage_results": damage_results,
		"target_count": enemy_cards.size(),
		"is_high_health": true
	}

## 杨玉环的治疗效果
func _execute_yangyuhuan_heal_effect(caster, params: Dictionary) -> Dictionary:
	var caster_card = caster.get_card()
	
	# 获取所有己方卡牌
	var ally_cards = []
	if caster.is_player():
		# 获取己方卡牌（通过BattleManager）
		ally_cards = BattleManager.get_alive_player_cards()
	else:
		# 获取己方卡牌（通过BattleManager）
		ally_cards = BattleManager.get_alive_enemy_cards()
	
	if ally_cards.is_empty():
		return {"success": false, "error": "没有己方目标"}
	
	# 记录治疗结果
	var heal_results = []
	var total_heal = 0
	
	# 计算治疗量：(0.3 * 攻击力 + 0.2 * 当前生命值)
	var current_health = caster_card.health
	var heal_amount = int(0.3 * caster_card.attack + 0.2 * current_health)
	
	# 为每个己方英雄恢复生命值
	for ally_card in ally_cards:
		if ally_card and not ally_card.is_dead():
			# 记录治疗前的状态
			var old_health = ally_card.health
			var old_shield = ally_card.shield
			
			# 执行治疗
			ally_card.heal(heal_amount)
			
			# 更新显示
			# 通过全局访问BattleScene并更新显示
			_update_battle_entity_display(ally_card)
			
			var actual_heal = ally_card.health - old_health
			total_heal += actual_heal
			
			# 记录治疗结果
			heal_results.append({
				"target_name": ally_card.card_name,
				"heal_amount": actual_heal,
				"base_heal": heal_amount,
				"current_health": current_health,  # 杨玉环自己的当前生命值
				"caster_attack": caster_card.attack,
				"old_health": old_health,
				"new_health": ally_card.health,
				"old_shield": old_shield,
				"new_shield": ally_card.shield
			})
	
	return {
		"success": true,
		"effect_type": "yangyuhuan_heal",
		"total_heal": total_heal,
		"heal_results": heal_results,
		"target_count": ally_cards.size(),
		"is_high_health": false
	}

## 通知BattleScene销毁实体的辅助方法
func _notify_battle_scene_entity_destroyed(card: Card):
	# 通过全局访问BattleScene并通知实体销毁
	var battle_scene = get_tree().get_root().get_node("BattleScene")
	if battle_scene and battle_scene.has_method("destroy_card_entity"):
		battle_scene.destroy_card_entity(card)
