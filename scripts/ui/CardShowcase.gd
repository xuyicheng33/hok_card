extends Control

## 卡牌展示场景
## 支持多卡牌切换展示

@onready var card_ui_scene = preload("res://scenes/ui/CardUI.tscn")
@onready var card_container: Control = $CardContainer
@onready var prev_button: Button = $Controls/ButtonContainer/PrevButton
@onready var next_button: Button = $Controls/ButtonContainer/NextButton
@onready var back_to_menu_button: Button = $Controls/BackToMenuButton
@onready var card_info_label: Label = $Controls/CardInfoLabel

## 当前显示的卡牌索引
var current_card_index: int = 0
## 所有可用的卡牌ID列表
var available_cards: Array = []
## 当前显示的卡牌UI组件
var current_card_ui: CardUI

func _ready():
	print("开始卡牌展示场景...")
	setup_card_showcase()
	
	# 连接按钮信号
	prev_button.pressed.connect(_on_prev_button_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)

func setup_card_showcase():
	# 获取所有可用卡牌
	available_cards = CardDatabase.get_all_card_ids()
	
	if available_cards.is_empty():
		print("错误: 没有可用的卡牌")
		return
	
	print("找到 %d 张卡牌: %s" % [available_cards.size(), available_cards])
	
	# 显示第一张卡牌
	show_card_at_index(0)
	
	# 更新按钮状态
	update_button_states()

## 显示指定索引的卡牌
func show_card_at_index(index: int):
	if index < 0 or index >= available_cards.size():
		return
	
	# 清理之前的卡牌UI
	if current_card_ui:
		current_card_ui.queue_free()
		current_card_ui = null
	
	# 获取卡牌数据
	var card_id = available_cards[index]
	var card_data = CardDatabase.get_card(card_id)
	
	if not card_data:
		print("错误: 无法获取卡牌数据 %s" % card_id)
		return
	
	# 创建新的卡牌UI
	current_card_ui = card_ui_scene.instantiate()
	card_container.add_child(current_card_ui)
	
	# 设置卡牌位置（居中）
	current_card_ui.position = Vector2(
		(card_container.size.x - 150) / 2,
		(card_container.size.y - 230) / 2
	)
	
	# 设置卡牌数据
	current_card_ui.set_card(card_data)
	current_card_ui.set_interactive(true)
	
	# 更新当前索引
	current_card_index = index
	
	# 更新信息显示
	update_card_info_display(card_data)
	
	print("显示卡牌: %s (%d/%d)" % [card_data.card_name, index + 1, available_cards.size()])

## 更新卡牌信息显示
func update_card_info_display(card: Card):
	if card_info_label:
		var info_text = "%s (%d/%d)" % [card.card_name, current_card_index + 1, available_cards.size()]
		info_text += "\n点击卡牌查看详情 | 使用左右按钮切换"
		card_info_label.text = info_text

## 更新按钮状态
func update_button_states():
	if prev_button:
		prev_button.disabled = (current_card_index <= 0)
	
	if next_button:
		next_button.disabled = (current_card_index >= available_cards.size() - 1)

## 上一张卡牌按钮事件
func _on_prev_button_pressed():
	if current_card_index > 0:
		show_card_at_index(current_card_index - 1)
		update_button_states()

## 下一张卡牌按钮事件
func _on_next_button_pressed():
	if current_card_index < available_cards.size() - 1:
		show_card_at_index(current_card_index + 1)
		update_button_states()

## 返回主菜单按钮事件
func _on_back_to_menu_pressed():
	print("返回主菜单")
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

## 处理键盘输入
func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_on_prev_button_pressed()
			KEY_RIGHT, KEY_D:
				_on_next_button_pressed()
			KEY_ESCAPE:
				_on_back_to_menu_pressed()

## 窗口尺寸改变时重新定位卡牌
func _on_resized():
	if current_card_ui and card_container:
		current_card_ui.position = Vector2(
			(card_container.size.x - 150) / 2,
			(card_container.size.y - 230) / 2
		)
