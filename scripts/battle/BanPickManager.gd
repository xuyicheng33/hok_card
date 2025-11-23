class_name BanPickManager
extends Node

enum Phase {
	BLUE_PICK_1,
	RED_PICK_1,
	BLUE_BAN,
	RED_BAN,
	BLUE_PICK_2,
	RED_PICK_2,
	RED_PICK_3,
	BLUE_PICK_3,
	COMPLETE
}

var current_phase: Phase = Phase.BLUE_PICK_1
var blue_team: Array = []
var red_team: Array = []
var banned_cards: Array = []
var all_cards: Array = []

# 初始化卡牌
func initialize_cards():
	all_cards = CardDatabase.get_all_cards()
	print("初始化了%d张卡牌" % all_cards.size())

# 检查卡牌是否可用
func is_card_available(card_id: String) -> bool:
	return not banned_cards.has(card_id)

# 执行选择操作
func select_card(card) -> bool:
	if not is_card_available(card.card_id):
		# 弹出提示：无法选择已禁用的英雄
		return false
	
	print("当前阶段: %s (%d)" % [get_current_phase_description(), current_phase])
	
	match current_phase:
		Phase.BLUE_PICK_1, Phase.BLUE_PICK_2, Phase.BLUE_PICK_3:
			blue_team.append(card)
			print("蓝方选择了 %s，当前蓝方队伍数量: %d" % [card.card_name, blue_team.size()])
			advance_phase()
			return true
		Phase.RED_PICK_1, Phase.RED_PICK_2, Phase.RED_PICK_3:
			red_team.append(card)
			print("红方选择了 %s，当前红方队伍数量: %d" % [card.card_name, red_team.size()])
			advance_phase()
			return true
		_:
			print("错误: 当前阶段不是选择阶段")
			return false

# 执行禁用操作
func ban_card(card_id: String) -> bool:
	if not is_card_available(card_id):
		return false
	
	print("执行禁用操作: %s" % card_id)
	banned_cards.append(card_id)
	print("当前禁用卡牌数量: %d" % banned_cards.size())
	advance_phase()
	return true

# 推进到下一阶段
func advance_phase():
	current_phase += 1
	print("阶段推进到: %d" % current_phase)
	if current_phase > Phase.BLUE_PICK_3:
		current_phase = Phase.COMPLETE
		print("进入战斗完成阶段")
		# 进入战斗阶段
		start_battle()
	else:
		print("进入阶段: %s" % get_current_phase_description())

# 此函数已不再使用，因为红蓝双方已分别完成三张卡牌的选择
# func assign_remaining_hero():
# 	var remaining_cards = []
# 	for card in all_cards:
# 		var card_selected = false
# 		# 检查是否已被选择
# 		for blue_card in blue_team:
# 			if blue_card.card_id == card.card_id:
# 				card_selected = true
# 				break
# 		if not card_selected:
# 			for red_card in red_team:
# 				if red_card.card_id == card.card_id:
# 					card_selected = true
# 					break
# 		# 检查是否已被禁用
# 		if not card_selected and not banned_cards.has(card.card_id):
# 			remaining_cards.append(card)
# 	
# 	if remaining_cards.size() > 0:
# 		blue_team.append(remaining_cards[0])
# 		print("自动分配最后一个英雄给蓝方: %s" % remaining_cards[0].card_name)

# 开始战斗
func start_battle():
	print("开始战斗，蓝方队伍: %d张卡牌, 红方队伍: %d张卡牌" % [blue_team.size(), red_team.size()])
	
	# 接力打印每个队伍的卡牌
	print("蓝方队伍卡牌:")
	for card in blue_team:
		print(" - %s" % card.card_name)
	
	print("红方队伍卡牌:")
	for card in red_team:
		print(" - %s" % card.card_name)
	
	print("禁用卡牌:")
	for card_id in banned_cards:
		var card = CardDatabase.get_card(card_id)
		if card:
			print(" - %s" % card.card_name)
	
	# 传递选牌结果到BattleManager
	BattleManager.set_custom_teams(blue_team, red_team)
	# 设置战斗模式为3v3_bp
	Engine.set_meta("selected_battle_mode", "3v3_bp")
	# 切换到战斗场景
	get_tree().change_scene_to_file("res://scenes/main/BattleScene.tscn")

# 获取当前阶段描述
func get_current_phase_description() -> String:
	match current_phase:
		Phase.BLUE_PICK_1:
			return "蓝方首选一英雄"
		Phase.RED_PICK_1:
			return "红方首选一英雄"
		Phase.BLUE_BAN:
			return "蓝方禁用一英雄"
		Phase.RED_BAN:
			return "红方禁用一英雄"
		Phase.BLUE_PICK_2:
			return "蓝方再选一英雄"
		Phase.RED_PICK_2:
			return "红方选择第二个英雄"
		Phase.RED_PICK_3:
			return "红方选择第三个英雄"
		Phase.BLUE_PICK_3:
			return "蓝方选择最后一个英雄"
		_:
			return "未知阶段"
