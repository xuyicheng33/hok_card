extends Node

# 测试杨玉环的实现
func _ready():
	print("开始测试杨玉环的实现...")
	test_yangyuhuan_implementation()
	print("杨玉环实现测试完成")

func test_yangyuhuan_implementation():
	# 获取卡牌数据库
	var card_database = get_node("/root/CardDatabase")
	if not card_database:
		print("错误: 无法获取卡牌数据库")
		return
	
	# 获取杨玉环卡牌
	var yangyuhuan_card = card_database.get_card("yangyuhuan_008")
	if not yangyuhuan_card:
		print("错误: 无法获取杨玉环卡牌")
		return
	
	print("成功获取杨玉环卡牌:")
	print("名称: %s" % yangyuhuan_card.card_name)
	print("描述: %s" % yangyuhuan_card.description)
	print("攻击力: %d" % yangyuhuan_card.attack)
	print("生命值: %d" % yangyuhuan_card.health)
	print("护甲: %d" % yangyuhuan_card.armor)
	print("暴击率: %.2f%%" % (yangyuhuan_card.crit_rate * 100))
	print("暴击效果: %.2f%%" % (yangyuhuan_card.crit_damage * 100))
	print("主动技能: %s" % yangyuhuan_card.skill_name)
	print("技能消耗: %d" % yangyuhuan_card.skill_cost)
	print("被动技能: %s" % yangyuhuan_card.passive_skill_name)
	
	# 测试杨玉环被动技能属性
	print("杨玉环被动技能属性测试:")
	print("yangyuhuan_skill_used: %s" % str(yangyuhuan_card.yangyuhuan_skill_used))
	
	# 测试重置战斗状态
	yangyuhuan_card.yangyuhuan_skill_used = true
	yangyuhuan_card.reset_battle_status()
	print("重置战斗状态后 yangyuhuan_skill_used: %s" % str(yangyuhuan_card.yangyuhuan_skill_used))
	
	# 测试技能管理器
	var skill_manager = get_node("/root/SkillManager")
	if not skill_manager:
		print("错误: 无法获取技能管理器")
		return
	
	# 检查技能是否已注册
	var registered_effects = skill_manager.get_registered_effects()
	print("已注册的技能效果: %s" % str(registered_effects))
	
	if "yangyuhuan_skill" in registered_effects:
		print("杨玉环技能效果已成功注册")
	else:
		print("错误: 杨玉环技能效果未注册")
	
	# 测试技能数据
	var skill_data = skill_manager.get_skill_data("杨玉环", "惊鸿曲")
	if skill_data:
		print("杨玉环技能数据:")
		print("  effect_type: %s" % skill_data.get("effect_type", ""))
		print("  target_required: %s" % str(skill_data.get("target_required", false)))
		print("  target_type: %s" % skill_data.get("target_type", ""))
	else:
		print("错误: 无法获取杨玉环技能数据")
	
	print("杨玉环实现测试完成")