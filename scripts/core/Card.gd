class_name Card
extends Resource

## 卡牌基类
## 包含卡牌的基本属性和方法

@export var card_id: String = ""  ## 卡牌ID，用于唯一标识卡牌
@export var card_name: String = ""  ## 卡牌名称
@export var description: String = ""  ## 卡牌描述
@export var attack: int = 0  ## 攻击力
@export var health: int = 0  ## 生命值
@export var armor: int = 0  ## 护甲
@export var skill_name: String = ""  ## 技能名称
@export var skill_effect: String = ""  ## 技能效果描述
@export var skill_cost: int = 2  ## 技能消耗（技能点）
@export var skill_ends_turn: bool = false  ## 技能是否结束回合
@export var card_image: Texture2D  ## 卡牌图片

# 战斗相关属性
@export var max_health: int = 0  ## 最大生命值
@export var energy_cost: int = 1  ## 能量消耗
@export var can_attack: bool = true  ## 是否可以攻击
@export var shield: int = 0  ## 护盾值
@export var crit_rate: float = 0.05  ## 暴击率（默认5%，上限100%）
@export var crit_damage: float = 1.3  ## 暴击效果（默认130%，上限200%）
@export var damage_bonus: float = 0.0  ## 增伤值（默认0%）
@export var dodge_rate: float = 0.0  ## 闪避率（公孙离专用，默认0%）

# 被动技能相关
@export var passive_skill_name: String = ""  ## 被动技能名称
@export var passive_skill_effect: String = ""  ## 被动技能描述

# 状态效果
var status_effects: Array = []  ## 状态效果列表
var is_stunned: bool = false  ## 是否被眩晕
var is_poisoned: bool = false  ## 是否中毒
var poison_damage: int = 0  ## 中毒伤害
var stun_turns: int = 0  ## 眩晕剩余回合数

# 杨玉环被动技能相关属性
var yangyuhuan_skill_used: bool = false  ## 是否刚释放了主动技能

# 🎒 装备系统
var equipment: Array = []  ## 装备列表（最多2件）

## 构造函数
func _init(
	_card_name: String = "",
	_description: String = "",
	_attack: int = 0,
	_health: int = 0,
	_armor: int = 0,
	_skill_name: String = "",
	_skill_effect: String = "",
	_card_image: Texture2D = null,
	_passive_skill_name: String = "",
	_passive_skill_effect: String = "",
	_skill_cost: int = 2,
	_skill_ends_turn: bool = false
):
	card_name = _card_name
	description = _description
	attack = _attack
	health = _health
	max_health = _health  # 初始化最大生命值
	armor = _armor
	skill_name = _skill_name
	skill_effect = _skill_effect
	skill_cost = _skill_cost
	skill_ends_turn = _skill_ends_turn
	card_image = _card_image
	passive_skill_name = _passive_skill_name
	passive_skill_effect = _passive_skill_effect
	
	# 初始化战斗状态
	reset_battle_status()

## 获取卡牌完整信息的字符串表示
func get_card_info() -> String:
	var info = "名称: %s\n" % card_name
	info += "描述: %s\n" % description
	info += "攻击力: %d\n" % attack
	info += "生命值: %d\n" % health
	info += "护甲: %d\n" % armor
	if skill_name != "":
		info += "技能: %s - %s\n" % [skill_name, skill_effect]
	return info

## 检查卡牌是否有效（基本验证）
func is_valid() -> bool:
	return card_name != "" and attack >= 0 and health > 0

## 复制卡牌（创建一个新的独立副本）
func duplicate_card() -> Card:
	# 调试复制过程
	if card_name == "公孙离":
		print(" [Card.duplicate] 复制公孙离")
		print("   原始 skill_effect长度: %d" % skill_effect.length())
		print("   原始 passive_skill_effect长度: %d" % passive_skill_effect.length())
	
	var new_card = Card.new(
		card_name,
		description,
		attack,
		health,
		armor,
		skill_name,
		skill_effect,
		card_image,
		passive_skill_name,
		passive_skill_effect,
		skill_cost,
		skill_ends_turn
	)
	
	# 验证复制结果
	if card_name == "公孙离":
		print("   新卡 skill_effect长度: %d" % new_card.skill_effect.length())
		print("   新卡 passive_skill_effect长度: %d" % new_card.passive_skill_effect.length())
	
	new_card.attack = attack
	new_card.health = health
	new_card.max_health = max_health
	new_card.armor = armor
	new_card.skill_name = skill_name
	new_card.skill_effect = skill_effect
	new_card.skill_cost = skill_cost
	new_card.skill_ends_turn = skill_ends_turn
	new_card.card_image = card_image
	new_card.energy_cost = energy_cost
	new_card.can_attack = can_attack
	new_card.shield = shield
	new_card.crit_rate = crit_rate
	new_card.crit_damage = crit_damage
	new_card.damage_bonus = damage_bonus
	new_card.passive_skill_name = passive_skill_name
	new_card.passive_skill_effect = passive_skill_effect
	# 注意：状态效果不复制，新卡牌应该是干净状态
	return new_card

## 治疗方法
## @param amount: 治疗量
## @param allow_overflow_shield: 是否允许溢出转化为护盾（仅朵莉亚被动使用）
func heal(amount: int, allow_overflow_shield: bool = false) -> void:
	var old_health = health
	health = min(max_health, health + amount)
	var actual_heal = health - old_health
	
	# 只有当明确允许且是朵莉亚时，才能将溢出转化为护盾
	var overflow = amount - actual_heal
	if overflow > 0 and allow_overflow_shield and card_name == "朵莉亚":
		add_shield(overflow)
		print("%s 治疗 %d，溢出 %d 转化为护盾" % [card_name, actual_heal, overflow])
	else:
		print("%s 治疗 %d 点生命值" % [card_name, actual_heal])

## 设置暴击率（含上限校验）
func set_crit_rate(new_rate: float) -> void:
	crit_rate = clamp(new_rate, 0.0, 1.0)  # 上限100%

func add_crit_rate(bonus_rate: float) -> void:
	set_crit_rate(crit_rate + bonus_rate)

## 设置暴击效果（含上限校验）
func set_crit_damage(new_damage: float) -> void:
	crit_damage = clamp(new_damage, 1.0, 2.0)  # 上限200%

func add_crit_damage(bonus_damage: float) -> void:
	set_crit_damage(crit_damage + bonus_damage)

## 设置增伤值
func set_damage_bonus(new_bonus: float) -> void:
	damage_bonus = new_bonus

func add_damage_bonus(bonus: float) -> void:
	damage_bonus += bonus

## 重置增伤值
func reset_damage_bonus() -> void:
	damage_bonus = 0.0

## 重置战斗状态
func reset_battle_status():
	status_effects.clear()
	is_stunned = false
	is_poisoned = false
	poison_damage = 0
	stun_turns = 0
	shield = 0
	health = max_health
	damage_bonus = 0.0  # 重置增伤值
	
	# 重置公孙离的被动技能增益
	if card_name == "公孙离":
		# 恢复原始攻击力（减去被动技能增加的部分）
		attack -= gongsunli_attack_bonus
		# 恢复原始暴击率（使用set_crit_rate方法确保不超过上限）
		set_crit_rate(crit_rate - gongsunli_crit_rate_bonus)
		# 重置增益属性
		gongsunli_dodge_bonus = 0.0
		gongsunli_attack_bonus = 0
		gongsunli_crit_rate_bonus = 0.0
	
	# 重置少司缘的被动技能相关属性 - 保留偋取点数
	# 注意：shaosiyuan_stolen_points不在此重置，需要维持不同回合之间的累积
	
	# 重置杨玉环的被动技能相关属性
	if card_name == "杨玉环":
		yangyuhuan_skill_used = false

## 添加状态效果
func add_status_effect(effect: String):
	if effect not in status_effects:
		status_effects.append(effect)
		print("%s 获得状态效果: %s" % [card_name, effect])

## 移除状态效果
func remove_status_effect(effect: String):
	if effect in status_effects:
		status_effects.erase(effect)
		print("%s 失去状态效果: %s" % [card_name, effect])

## 检查是否有特定状态效果
func has_status_effect(effect: String) -> bool:
	return effect in status_effects

## 施放眩晕
func apply_stun(turns: int):
	is_stunned = true
	stun_turns = max(stun_turns, turns)
	add_status_effect("眩晕")
	can_attack = false
	print("%s 被眩晕 %d 回合" % [card_name, turns])

## 施放中毒
func apply_poison(damage: int, _turns: int = 3):
	is_poisoned = true
	poison_damage = damage
	add_status_effect("中毒")
	print("%s 中毒，每回合损失 %d 生命值" % [card_name, damage])

## 添加护盾
func add_shield(amount: int):
	shield += amount
	print("%s 获得 %d 护盾值（当前: %d）" % [card_name, amount, shield])

## 处理回合开始事件
func process_turn_start():
	print("%s 回合开始处理" % card_name)
	
	# 被动技能现在由BattleManager统一处理，避免重复触发
	# trigger_passive_turn_start() # 已移除，由BattleManager.process_all_passive_skills()统一处理
	
	# 处理眩晕
	if is_stunned:
		stun_turns -= 1
		if stun_turns <= 0:
			is_stunned = false
			can_attack = true
			remove_status_effect("眩晕")
			print("%s 从眩晕中恢复" % card_name)
	
	# 处理中毒
	if is_poisoned:
		take_damage(poison_damage)
		print("%s 受到中毒伤害: %d" % [card_name, poison_damage])

## 处理回合结束事件
func process_turn_end():
	print("%s 回合结束处理" % card_name)
	# 可以在这里添加回合结束时的效果处理

## 受到伤害（新的伤害计算逻辑）
## 参数damage为最终伤害（已经考虑了暴击和护甲减免）
func take_damage(damage: int) -> int:
	var remaining_damage = damage
	
	# 先消耗护盾
	if shield > 0:
		var shield_absorbed = min(shield, remaining_damage)
		shield -= shield_absorbed
		remaining_damage -= shield_absorbed
		print("%s 护盾吸收 %d 伤害（剩余护盾: %d）" % [card_name, shield_absorbed, shield])
	
	# 剩余伤害作用于生命值
	if remaining_damage > 0:
		health = max(0, health - remaining_damage)
		print("%s 受到 %d 伤害，剩余生命值: %d" % [card_name, remaining_damage, health])
		return remaining_damage
	
	return 0

## 检查是否可以攻击
func can_perform_attack() -> bool:
	return can_attack and not is_stunned and not is_dead()

## 获取当前有效攻击力
func get_effective_attack() -> int:
	# 可以在这里添加buff/debuff的影响
	return attack

## 计算对目标的攻击伤害（包含暴击判定、增伤和护甲减免）
func calculate_damage_to(target: Card) -> Dictionary:
	if not target:
		return {"success": false, "error": "invalid_target"}
	
	# 1. 计算基础伤害（新公式：攻击力 × 200/(护甲+200)）
	var base_damage = get_effective_attack() * (200.0 / (target.armor + 200.0))
	
	# 2. 判定是否暴击
	var is_critical = randf() < crit_rate
	
	# 3. 计算暴击伤害
	var crit_damage_value = float(base_damage)  # 显式转换为浮点数
	if is_critical:
		crit_damage_value = crit_damage_value * crit_damage
	
	# 4. 计算增伤后的伤害
	var final_damage = crit_damage_value
	if damage_bonus > 0:
		final_damage = crit_damage_value * (1.0 + damage_bonus)
	
	# 5. 四舍五入处理并转换为整数
	final_damage = round(final_damage)
	
	# 返回伤害计算结果
	return {
		"success": true,
		"base_damage": base_damage,
		"crit_damage_value": int(crit_damage_value),
		"final_damage": int(final_damage),
		"is_critical": is_critical,
		"has_damage_bonus": damage_bonus > 0,
		"damage_bonus_percent": damage_bonus * 100,
		"crit_rate": crit_rate,
		"crit_damage": crit_damage,
		"attacker_name": card_name,
		"target_name": target.card_name
	}

## 获取战斗状态信息
func get_battle_status() -> String:
	var status = "["
	if is_stunned:
		status += "眩晕(%d) " % stun_turns
	if is_poisoned:
		status += "中毒(%d) " % poison_damage
	if shield > 0:
		status += "护盾(%d) " % shield
	for effect in status_effects:
		status += effect + " "
	status = status.strip_edges() + "]"
	return status if status != "[]" else ""

## 获取完整的战斗信息
func get_battle_info() -> String:
	var info = get_card_info()
	var battle_status = get_battle_status()
	if battle_status != "":
		info += "战斗状态: %s\n" % battle_status
	return info

## 检查卡牌是否已死亡
func is_dead() -> bool:
	return health <= 0

## 检查是否有被动技能
func has_passive_skill() -> bool:
	return passive_skill_name != ""

## 触发被动技能（回合开始）
func trigger_passive_turn_start() -> void:
	if not has_passive_skill():
		return
	
	match card_name:
		"朵莉亚":
			trigger_duoliya_passive()
		"澜":
			# 澜的被动技能在攻击时触发，不在回合开始时触发
			pass
		"公孙离":
			# 公孙离的被动技能在受到攻击时触发，不在回合开始时触发
			pass
		"少司缘":
			# 少司缘的被动技能由BattleManager统一处理，不在这里触发
			pass
		_:
			print("未知的被动技能: %s" % card_name)

## 朵莉亚的被动技能：欢歌
func trigger_duoliya_passive() -> void:
	print("%s 被动技能「%s」发动！" % [card_name, passive_skill_name])
	heal(50, true)  # 只有朵莉亚的被动才能转化护盾
	print("%s 被动技能后状态 - 生命值: %d/%d, 护盾: %d" % [card_name, health, max_health, shield])

## 检查澜的被动技能条件（目标生命值小于等于50%）
func check_lan_passive_condition(target: Card) -> bool:
	if not target or target.max_health <= 0:
		return false
	
	var half_health = target.max_health * 0.5
	return target.health <= half_health

## 触发澜的被动技能（增伤）
func trigger_lan_passive() -> void:
	print("%s 被动技能「%s」发动！增伤+30%" % [card_name, passive_skill_name])
	add_damage_bonus(0.3)  # 增加30%伤害

## 公孙离的被动技能：霜叶舞（闪避判定）
# 添加公孙离被动技能相关的属性
var gongsunli_dodge_bonus: float = 0.0  # 闪避概率增益
var gongsunli_attack_bonus: int = 0    # 攻击力增益
var gongsunli_crit_rate_bonus: float = 0.0  # 暴击率增益

func check_gongsunli_dodge() -> bool:
	if card_name != "公孙离" or not has_passive_skill():
		return false
	
	# 30%基础概率 + 闪避增益（最多20%）
	var dodge_rate = 0.30 + gongsunli_dodge_bonus
	var is_dodge = randf() < dodge_rate
	
	if is_dodge:
		print("%s 被动技能「%s」发动！成功闪避攻击！" % [card_name, passive_skill_name])
		# 闪避成功后增加攻击力和暴击率
		gongsunli_attack_bonus += 10
		attack += 10
		gongsunli_crit_rate_bonus += 0.05
		set_crit_rate(crit_rate + 0.05)  # 使用set_crit_rate方法来增加暴击率，确保应用上限校验
		print("%s 闪避成功，获得增益：攻击力+%d，暴击率+%d%%" % [card_name, 10, 5])
	else:
		print("%s 被动技能「%s」判定失败，未能闪避" % [card_name, passive_skill_name])
	
	return is_dodge

## 获取公孙离的当前闪避概率（包括基础概率和增益）
func get_gongsunli_dodge_rate() -> float:
	if card_name == "公孙离":
		# 基础30% + 增益（最多20%）
		return min(0.30 + gongsunli_dodge_bonus, 0.50)  # 最多50%闪避概率
	return 0.0

## 重置公孙离的被动技能增益（用于测试或其他需要重置的场景）
func reset_gongsunli_bonuses() -> void:
	if card_name == "公孙离":
		attack -= gongsunli_attack_bonus
		set_crit_rate(crit_rate - gongsunli_crit_rate_bonus)  # 使用set_crit_rate方法
		gongsunli_dodge_bonus = 0.0
		gongsunli_attack_bonus = 0
		gongsunli_crit_rate_bonus = 0.0

## 增加公孙离的闪避概率（用于暴击后的增益）
func add_gongsunli_dodge_bonus(bonus: float) -> void:
	if card_name == "公孙离":
		var old_dodge_bonus = gongsunli_dodge_bonus
		var old_dodge_rate = get_gongsunli_dodge_rate()
		
		# 最多增加20%闪避概率
		gongsunli_dodge_bonus = min(gongsunli_dodge_bonus + bonus, 0.20)
		
		var new_dodge_rate = get_gongsunli_dodge_rate()
		print("%s 攻击暴击触发被动技能：闪避概率 %.1f%% -> %.1f%%（基础30%% + 增益%.1f%%）" % 
			[card_name, old_dodge_rate * 100, new_dodge_rate * 100, gongsunli_dodge_bonus * 100])

# 大乔被动技能相关属性
var daqiao_passive_used: bool = false  # 标记大乔被动技能是否已使用

## 检查大乔被动技能是否可用
func can_use_daqiao_passive() -> bool:
	return card_name == "大乔" and not daqiao_passive_used

## 触发大乔被动技能
func trigger_daqiao_passive() -> void:
	if not can_use_daqiao_passive():
		return
	
	print("%s 被动技能「%s」发动！" % [card_name, passive_skill_name])
	daqiao_passive_used = true  # 标记被动技能已使用
	health = 1  # 生命值设置为1点
	print("%s 生命值设置为1点" % card_name)

## 获取已损生命值
func get_lost_health() -> int:
	return max_health - health

# 少司缘被动技能相关属性
var shaosiyuan_stolen_points: int = 0  # 偷取点数计数器

## 重置少司缘的被动技能相关属性
func reset_shaosiyuan_bonuses() -> void:
	if card_name == "少司缘":
		shaosiyuan_stolen_points = 0

## 增加少司缘的偋取点数（有上限）
func add_shaosiyuan_stolen_points(points: int) -> void:
	if card_name == "少司缘":
		var old_points = shaosiyuan_stolen_points
		# 偽取点数计数上限为4点
		shaosiyuan_stolen_points = min(shaosiyuan_stolen_points + points, 4)
		print("%s 偽取点数增加 %d，从 %d 变为 %d 点" % [card_name, points, old_points, shaosiyuan_stolen_points])

## 获取少司缘的偷取点数
func get_shaosiyuan_stolen_points() -> int:
	if card_name == "少司缘":
		return shaosiyuan_stolen_points
	return 0

## 计算少司缘主动技能的治疗量
func calculate_shaosiyuan_heal_amount() -> int:
	if card_name == "少司缘":
		# 治疗量为 100 + min(4, 偷取点数) × 40
		var points = min(4, shaosiyuan_stolen_points)
		return 100 + points * 40
	return 0

## 计算少司缘主动技能的伤害量
func calculate_shaosiyuan_damage_amount() -> int:
	if card_name == "少司缘":
		# 伤害量为 150 + min(4, 偷取点数) × 50
		var points = min(4, shaosiyuan_stolen_points)
		return 150 + points * 50
	return 0
