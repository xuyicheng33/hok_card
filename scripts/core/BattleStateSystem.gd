extends RefCounted
class_name BattleStateSystem

## 战斗状态基类
class BattleState:
	var battle_manager
	
	func _init(manager):
		battle_manager = manager
	
	func enter():
		pass
	
	func exit():
		pass
	
	func execute_attack(_attacker, _target, _attacker_is_player):
		return {"success": false, "error": "method_not_implemented"}
	
	func execute_skill(_card, _skill_name, _targets, _is_player):
		return {"success": false, "error": "method_not_implemented"}
	
	func end_turn():
		pass

## 未开始状态
class NoneState extends BattleState:
	func enter():
		print("进入未开始状态")
	
	func execute_attack(_attacker, _target, _attacker_is_player):
		print("错误: 战斗未开始，无法执行攻击")
		return {"success": false, "error": "battle_not_started"}
	
	func execute_skill(_card, _skill_name, _targets, _is_player):
		print("错误: 战斗未开始，无法使用技能")
		return {"success": false, "error": "battle_not_started"}
	
	func end_turn():
		print("错误: 战斗未开始，无法结束回合")

## 准备状态
class PreparingState extends BattleState:
	func enter():
		print("进入准备状态")
	
	func execute_attack(_attacker, _target, _attacker_is_player):
		print("错误: 战斗准备中，无法执行攻击")
		return {"success": false, "error": "battle_preparing"}
	
	func execute_skill(_card, _skill_name, _targets, _is_player):
		print("错误: 战斗准备中，无法使用技能")
		return {"success": false, "error": "battle_preparing"}
	
	func end_turn():
		print("错误: 战斗准备中，无法结束回合")

## 玩家回合状态
class PlayerTurnState extends BattleState:
	func enter():
		print("进入玩家回合状态")
		
		# 🌐 在线模式：被动技能由服务器处理，客户端不触发
		if battle_manager.is_online_mode:
			print("🌐 在线模式：回合开始被动技能由服务器处理")
		else:
			# 单机模式：正常触发
			battle_manager.trigger_turn_start_passives(true)
	
	func execute_attack(attacker, target, attacker_is_player):
		if not attacker_is_player:
			print("错误: 当前是玩家回合，敌人无法攻击")
			return {"success": false, "error": "not_player_turn"}
		
		return battle_manager._execute_attack_internal(attacker, target, attacker_is_player)
	
	func execute_skill(card, skill_name, targets, is_player):
		if not is_player:
			print("错误: 当前是玩家回合，敌人无法使用技能")
			return {"success": false, "error": "not_player_turn"}
		
		return battle_manager._execute_skill_internal(card, skill_name, targets, is_player)
	
	func end_turn():
		print("玩家回合结束")
		battle_manager.start_new_turn(false)  # 切换到敌人回合

## 敌人回合状态
class EnemyTurnState extends BattleState:
	func enter():
		print("进入敌人回合状态")
		
		# 🌐 在线模式：被动技能由服务器处理，客户端不触发
		if battle_manager.is_online_mode:
			print("🌐 在线模式：回合开始被动技能由服务器处理")
		else:
			# 单机模式：正常触发
			battle_manager.trigger_turn_start_passives(false)
	
	func execute_attack(attacker, target, attacker_is_player):
		if attacker_is_player:
			print("错误: 当前是敌人回合，玩家无法攻击")
			return {"success": false, "error": "not_enemy_turn"}
		
		return battle_manager._execute_attack_internal(attacker, target, attacker_is_player)
	
	func execute_skill(card, skill_name, targets, is_player):
		if is_player:
			print("错误: 当前是敌人回合，玩家无法使用技能")
			return {"success": false, "error": "not_enemy_turn"}
		
		return battle_manager._execute_skill_internal(card, skill_name, targets, is_player)
	
	func end_turn():
		print("敌人回合结束")
		battle_manager.start_new_turn(true)  # 切换到玩家回合

## 战斗结束状态
class BattleEndState extends BattleState:
	func enter():
		print("进入战斗结束状态")
		var result = battle_manager.battle_result
		var victory = result.get("victory", false)
		print("战斗结果: %s" % ("胜利" if victory else "失败"))
	
	func execute_attack(_attacker, _target, _attacker_is_player):
		print("错误: 战斗已结束，无法执行攻击")
		return {"success": false, "error": "battle_ended"}
	
	func execute_skill(_card, _skill_name, _targets, _is_player):
		print("错误: 战斗已结束，无法使用技能")
		return {"success": false, "error": "battle_ended"}
	
	func end_turn():
		print("错误: 战斗已结束，无法结束回合")
