extends Control

# 测试新布局的脚本

func _ready():
	# 创建一个测试按钮
	var test_button = Button.new()
	test_button.text = "测试新布局"
	test_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	test_button.pressed.connect(_on_test_button_pressed)
	add_child(test_button)

func _on_test_button_pressed():
	# 加载所有卡牌详情弹窗场景
	var popup_scene = preload("res://scenes/ui/AllCardsDetailPopup.tscn")
	if not popup_scene:
		print("错误: 无法加载AllCardsDetailPopup场景")
		return
	
	# 创建弹窗实例
	var popup = popup_scene.instantiate()
	if not popup:
		print("错误: 无法实例化AllCardsDetailPopup")
		return
	
	# 添加到场景树
	add_child(popup)
	
	# 创建一些测试数据
	var test_player_entities = []
	var test_enemy_entities = []
	
	# 创建测试卡牌数据
	var card_scene = preload("res://scripts/core/Card.gd")
	if card_scene:
		# 创建玩家卡牌
		var player_card1 = card_scene.new("朵莉亚", "可爱的朵朵。", 300, 500, 100, "人鱼之赐", "为选择的队友恢复130点生命值。")
		player_card1.passive_skill_name = "欢歌"
		player_card1.passive_skill_effect = "每回合开始时，为朵莉亚自己恢复75点生命值，如果恢复到满生命值，溢出的部分将会转化为自己的护盾值。"
		player_card1.crit_rate = 0.1
		player_card1.crit_damage = 1.5
		player_card1.damage_bonus = 0.2
		player_card1.shield = 50
		
		var player_card2 = card_scene.new("澜", "确认目标。", 400, 400, 50, "鲨之猎刃", "增加自己攻击力100点。")
		player_card2.passive_skill_name = "狩猎"
		player_card2.passive_skill_effect = "当澜攻击生命值低于50%的目标时，造成的伤害提升30%。"
		player_card2.crit_rate = 0.15
		player_card2.crit_damage = 1.8
		player_card2.damage_bonus = 0.3
		player_card2.shield = 30
		
		var player_card3 = card_scene.new("曜", "星辰之力，与我同在！", 450, 450, 75, "星辰跃迁", "曜向指定方向位移并强化下一次普通攻击。")
		player_card3.passive_skill_name = "星辰之力"
		player_card3.passive_skill_effect = "曜的技能命中敌人会积累星辰之力，每层星辰之力提升其5%的移动速度和10点攻击力。"
		player_card3.crit_rate = 0.12
		player_card3.crit_damage = 1.6
		player_card3.damage_bonus = 0.25
		player_card3.shield = 40
		
		# 创建敌方卡牌
		var enemy_card1 = card_scene.new("公孙离", "送你冰心一片。", 400, 300, 0, "晚云落", "增加自己50%暴击率。")
		enemy_card1.passive_skill_name = "霜叶舞"
		enemy_card1.passive_skill_effect = "公孙离有30%的概率闪避敌人的攻击，闪避成功后提升自身10%攻击力和5%暴击率，持续到战斗结束。"
		enemy_card1.crit_rate = 0.2
		enemy_card1.crit_damage = 2.0
		enemy_card1.damage_bonus = 0.1
		enemy_card1.shield = 20
		
		var enemy_card2 = card_scene.new("瑶", "有只小鹿飞走了。", 280, 850, 200, "鹿灵守心", "使一名友方英雄获得150点护盾值。")
		enemy_card2.passive_skill_name = "山鬼白鹿"
		enemy_card2.passive_skill_effect = "当瑶受到伤害时，会为全场生命值最低的友方英雄添加(80+瑶当前生命值的2%)点护盾值。"
		enemy_card2.crit_rate = 0.05
		enemy_card2.crit_damage = 1.3
		enemy_card2.damage_bonus = 0.05
		enemy_card2.shield = 100
		
		var enemy_card3 = card_scene.new("马可波罗", "冒险旅途中，一切都是风景。", 380, 350, 25, "漫游之枪", "马可波罗向指定方向连续射击。")
		enemy_card3.passive_skill_name = "边路游侠"
		enemy_card3.passive_skill_effect = "马可波罗的普通攻击会叠加层数，每层提升其3点物理攻击，最多叠加5层。"
		enemy_card3.crit_rate = 0.18
		enemy_card3.crit_damage = 1.7
		enemy_card3.damage_bonus = 0.15
		enemy_card3.shield = 30
		
		# 创建实体对象
		var battle_entity_scene = preload("res://scripts/battle/BattleEntity.gd")
		if battle_entity_scene:
			var player_entity1 = battle_entity_scene.new()
			player_entity1.card_data = player_card1
			test_player_entities.append(player_entity1)
			
			var player_entity2 = battle_entity_scene.new()
			player_entity2.card_data = player_card2
			test_player_entities.append(player_entity2)
			
			var player_entity3 = battle_entity_scene.new()
			player_entity3.card_data = player_card3
			test_player_entities.append(player_entity3)
			
			var enemy_entity1 = battle_entity_scene.new()
			enemy_entity1.card_data = enemy_card1
			test_enemy_entities.append(enemy_entity1)
			
			var enemy_entity2 = battle_entity_scene.new()
			enemy_entity2.card_data = enemy_card2
			test_enemy_entities.append(enemy_entity2)
			
			var enemy_entity3 = battle_entity_scene.new()
			enemy_entity3.card_data = enemy_card3
			test_enemy_entities.append(enemy_entity3)
	
	# 设置所有卡牌详情
	popup.setup_details(test_player_entities, test_enemy_entities)