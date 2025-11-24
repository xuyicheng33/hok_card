class_name EquipmentCraftPopup
extends PopupPanel

## 🔨 装备合成弹窗
## 允许玩家选择英雄和装备材料进行合成

signal craft_confirmed(hero_id: String, material_ids: Array)

# UI组件引用
@onready var hero_list: ItemList = $Panel/VBoxContainer/HeroSelection/HeroList
@onready var material_slot_1: Button = $Panel/VBoxContainer/MaterialSelection/MaterialSlot1
@onready var material_slot_2: Button = $Panel/VBoxContainer/MaterialSelection/MaterialSlot2
@onready var recipe_preview: Label = $Panel/VBoxContainer/RecipePreview/PreviewLabel
@onready var gold_cost_label: Label = $Panel/VBoxContainer/CostInfo/GoldLabel
@onready var current_gold_label: Label = $Panel/VBoxContainer/CostInfo/CurrentGoldLabel
@onready var craft_button: Button = $Panel/VBoxContainer/ButtonContainer/CraftButton
@onready var cancel_button: Button = $Panel/VBoxContainer/ButtonContainer/CancelButton

# 数据
var player_cards: Array = []  # 玩家的英雄列表
var selected_hero: Card = null
var selected_materials: Array = []  # 选中的材料装备
var current_gold: int = 0

# 合成配方数据（从服务器获取或硬编码）
var recipes: Dictionary = {
	# 格式：材料1_材料2 -> 合成结果
	"basic_001_basic_001": {
		"name": "风暴巨剑",
		"description": "攻击力+50",
		"cost": 10
	},
	"basic_002_basic_004": {
		"name": "穿云弓",
		"description": "暴击率+15%, 增伤+5%",
		"cost": 10
	},
	"basic_001_basic_004": {
		"name": "速击之枪",
		"description": "攻击力+25, 增伤+7%",
		"cost": 10
	},
	"basic_002_basic_003": {
		"name": "狂暴双刃",
		"description": "暴击率+13%, 暴击效果+10%",
		"cost": 10
	},
	"basic_005_basic_001": {
		"name": "日冕",
		"description": "攻击力+25, 生命+250",
		"cost": 10
	},
	"basic_005_basic_005": {
		"name": "力量腰带",
		"description": "最大生命值+500",
		"cost": 10
	},
	"basic_001_basic_006": {
		"name": "荆棘护手",
		"description": "攻击力+25, 护甲+40",
		"cost": 10
	},
	"basic_005_basic_006": {
		"name": "守护者之铠",
		"description": "生命+300, 护甲+40",
		"cost": 10
	},
	"basic_007_basic_005": {
		"name": "熔炼之心",
		"description": "每回合+50HP, 生命+400",
		"cost": 10
	}
}

func _ready():
	# 连接按钮信号
	if craft_button:
		craft_button.pressed.connect(_on_craft_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if hero_list:
		hero_list.item_selected.connect(_on_hero_selected)
	if material_slot_1:
		material_slot_1.pressed.connect(func(): _on_material_slot_pressed(0))
	if material_slot_2:
		material_slot_2.pressed.connect(func(): _on_material_slot_pressed(1))
	
	_update_craft_button_state()

## 显示弹窗
func show_popup(cards: Array, gold: int):
	player_cards = cards
	current_gold = gold
	selected_hero = null
	selected_materials = []
	
	_refresh_hero_list()
	_clear_material_slots()
	_update_gold_display()
	_update_craft_button_state()
	
	popup_centered()

## 刷新英雄列表
func _refresh_hero_list():
	if not hero_list:
		return
	
	hero_list.clear()
	for card in player_cards:
		if card and card.health > 0:
			var equipment_count = 0
			if card.equipment:
				equipment_count = card.equipment.size()
			var text = "%s (装备: %d/2)" % [card.card_name, equipment_count]
			hero_list.add_item(text)

## 英雄选择事件
func _on_hero_selected(index: int):
	if index < 0 or index >= player_cards.size():
		return
	
	selected_hero = player_cards[index]
	selected_materials = []
	_clear_material_slots()
	_update_recipe_preview()
	_update_craft_button_state()
	
	print("选中英雄: %s" % selected_hero.card_name)

## 材料槽点击事件
func _on_material_slot_pressed(slot_index: int):
	if not selected_hero:
		_show_error("请先选择英雄！")
		return
	
	if not selected_hero.equipment or selected_hero.equipment.size() == 0:
		_show_error("该英雄没有装备！")
		return
	
	# 显示装备选择菜单
	_show_equipment_selection_menu(slot_index)

## 显示装备选择菜单
func _show_equipment_selection_menu(slot_index: int):
	var popup = PopupMenu.new()
	add_child(popup)
	
	# 添加装备选项
	var available_equipments = []
	for equip in selected_hero.equipment:
		# 跳过已选择的装备
		var is_selected = false
		for selected in selected_materials:
			if selected and selected.get("id") == equip.get("id"):
				is_selected = true
				break
		
		if not is_selected:
			available_equipments.append(equip)
			var equip_name = equip.get("name", "未知装备")
			popup.add_item(equip_name)
	
	if available_equipments.is_empty():
		_show_error("没有可用的装备材料！")
		popup.queue_free()
		return
	
	# 连接选择信号
	popup.index_pressed.connect(func(idx):
		if idx >= 0 and idx < available_equipments.size():
			_select_material(slot_index, available_equipments[idx])
		popup.queue_free()
	)
	
	# 显示在材料槽按钮旁边
	var slot_button = material_slot_1 if slot_index == 0 else material_slot_2
	var button_pos = slot_button.global_position
	popup.position = Vector2i(button_pos.x, button_pos.y + slot_button.size.y)
	popup.popup()

## 选择材料
func _select_material(slot_index: int, equipment: Dictionary):
	# 确保数组有足够的空间
	while selected_materials.size() <= slot_index:
		selected_materials.append(null)
	
	selected_materials[slot_index] = equipment
	
	# 更新UI
	var slot_button = material_slot_1 if slot_index == 0 else material_slot_2
	slot_button.text = equipment.get("name", "未知")
	
	print("选择材料 %d: %s" % [slot_index + 1, equipment.get("name", "未知")])
	
	_update_recipe_preview()
	_update_craft_button_state()

## 清空材料槽
func _clear_material_slots():
	if material_slot_1:
		material_slot_1.text = "选择装备"
	if material_slot_2:
		material_slot_2.text = "选择装备"
	selected_materials = []

## 更新配方预览
func _update_recipe_preview():
	if not recipe_preview:
		return
	
	# 检查是否选择了2个材料
	if selected_materials.size() != 2 or not selected_materials[0] or not selected_materials[1]:
		recipe_preview.text = "请选择2个装备材料"
		if gold_cost_label:
			gold_cost_label.text = "合成费用: --"
		return
	
	# 获取材料ID
	var mat1_id = selected_materials[0].get("id", "")
	var mat2_id = selected_materials[1].get("id", "")
	
	# 查找配方（顺序无关）
	var recipe_key_1 = "%s_%s" % [mat1_id, mat2_id]
	var recipe_key_2 = "%s_%s" % [mat2_id, mat1_id]
	
	var recipe = null
	if recipes.has(recipe_key_1):
		recipe = recipes[recipe_key_1]
	elif recipes.has(recipe_key_2):
		recipe = recipes[recipe_key_2]
	
	if recipe:
		recipe_preview.text = "✨ %s\n%s" % [recipe.name, recipe.description]
		if gold_cost_label:
			gold_cost_label.text = "合成费用: 💰%d" % recipe.cost
	else:
		recipe_preview.text = "❌ 这两个装备无法合成"
		if gold_cost_label:
			gold_cost_label.text = "合成费用: --"

## 更新金币显示
func _update_gold_display():
	if current_gold_label:
		current_gold_label.text = "当前金币: 💰%d" % current_gold

## 更新合成按钮状态
func _update_craft_button_state():
	if not craft_button:
		return
	
	var can_craft = false
	
	# 检查条件
	if selected_hero and selected_materials.size() == 2 and selected_materials[0] and selected_materials[1]:
		# 检查配方是否存在
		var mat1_id = selected_materials[0].get("id", "")
		var mat2_id = selected_materials[1].get("id", "")
		var recipe_key_1 = "%s_%s" % [mat1_id, mat2_id]
		var recipe_key_2 = "%s_%s" % [mat2_id, mat1_id]
		
		if recipes.has(recipe_key_1) or recipes.has(recipe_key_2):
			# 检查金币是否足够
			var cost = 10  # 默认费用
			if recipes.has(recipe_key_1):
				cost = recipes[recipe_key_1].cost
			elif recipes.has(recipe_key_2):
				cost = recipes[recipe_key_2].cost
			
			if current_gold >= cost:
				can_craft = true
	
	craft_button.disabled = not can_craft

## 合成按钮点击
func _on_craft_pressed():
	if not selected_hero or selected_materials.size() != 2:
		return
	
	# 获取材料ID
	var material_ids = [
		selected_materials[0].get("id", ""),
		selected_materials[1].get("id", "")
	]
	
	print("🔨 发起合成请求: 英雄 %s, 材料 %s" % [selected_hero.id, material_ids])
	
	# 发射信号
	craft_confirmed.emit(selected_hero.id, material_ids)
	
	# 关闭弹窗
	hide()

## 取消按钮点击
func _on_cancel_pressed():
	hide()

## 显示错误提示
func _show_error(message: String):
	print("❌ %s" % message)
	# TODO: 显示错误弹窗
