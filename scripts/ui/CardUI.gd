class_name CardUI
extends Control

## 卡牌UI组件
## 基于3:4图片比例设计，尺寸150×230像素

@onready var card_image: TextureRect = $CardImage
@onready var card_name_label: Label = $CardName

## 当前显示的卡牌数据
var current_card: Card

## 卡牌详情弹窗场景
var card_detail_popup_scene = preload("res://scenes/ui/CardDetailPopup.tscn")

## 设置卡牌数据并更新UI显示
func set_card(card: Card):
	if not card:
		print("警告: 卡牌数据为空")
		return
	
	current_card = card
	update_card_display()

## 更新卡牌显示
func update_card_display():
	if not current_card:
		return
	
	# 等待节点准备就绪
	if not is_node_ready():
		await ready
	
	# 更新卡牌图片
	if current_card.card_image and card_image:
		card_image.texture = current_card.card_image
	
	# 更新卡牌名称
	if card_name_label:
		card_name_label.text = current_card.card_name

## 获取当前卡牌
func get_card() -> Card:
	return current_card

## 显示卡牌详情弹窗
func show_card_details():
	if not current_card:
		return
		
	var popup = card_detail_popup_scene.instantiate()
	get_tree().current_scene.add_child(popup)
	popup.setup_card_details(current_card)

## 处理点击输入
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_card_clicked()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_card_clicked()

## 卡牌点击事件
func _on_card_clicked():
	if not current_card:
		return
		
	print("卡牌被点击: %s" % current_card.card_name)
	show_card_details()

## 卡牌悬停事件（PC端）
func _on_card_mouse_entered():
	# 禁用悬停缩放效果
	pass

func _on_card_mouse_exited():
	# 禁用悬停缩放效果
	pass

## 设置卡牌交互状态
func set_interactive(interactive: bool):
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
