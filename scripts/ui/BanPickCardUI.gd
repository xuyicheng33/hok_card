class_name BanPickCardUI
extends Control

## BP场景卡牌卡牌UI组件
## 基于3:4图片比例设计，尺寸180×270像素

@onready var card_image: TextureRect = $CardImage
@onready var card_name_label: Label = $CardName
@onready var status_overlay: Panel = $StatusOverlay
@onready var status_label: Label = $StatusOverlay/StatusLabel
@onready var background_panel: Panel = $Background

## 当前显示的卡牌数据
var current_card: Card

## 卡牌状态
enum CardState {
    AVAILABLE,    # 可用
    SELECTED_BLUE, # 蓝方已选
    SELECTED_RED,  # 红方已选
    BANNED        # 已禁用
}

var card_state: CardState = CardState.AVAILABLE

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
    
    # 更新状态显示
    update_state_display()

## 更新状态显示
func update_state_display():
    match card_state:
        CardState.AVAILABLE:
            status_overlay.visible = false
            # 设置默认背景
            background_panel.self_modulate = Color(1, 1, 1, 1)
        CardState.SELECTED_BLUE:
            status_overlay.visible = true
            status_label.text = "蓝方"
            status_overlay.self_modulate = Color(0.2, 0.4, 0.8, 0.8)  # 蓝色
            background_panel.self_modulate = Color(0.7, 0.8, 1, 1)  # 蓝色调
        CardState.SELECTED_RED:
            status_overlay.visible = true
            status_label.text = "红方"
            status_overlay.self_modulate = Color(0.8, 0.2, 0.2, 0.8)  # 红色
            background_panel.self_modulate = Color(1, 0.7, 0.7, 1)  # 红色调
        CardState.BANNED:
            status_overlay.visible = true
            status_label.text = "禁用"
            status_overlay.self_modulate = Color(0.5, 0.5, 0.5, 0.8)  # 灰色
            background_panel.self_modulate = Color(0.7, 0.7, 0.7, 1)  # 灰色调
            # 添加删除线效果
            if card_name_label:
                card_name_label.self_modulate = Color(0.5, 0.5, 0.5, 1)

## 获取当前卡牌
func get_card() -> Card:
    return current_card

## 设置卡牌状态
func set_card_state(state: CardState):
    card_state = state
    update_state_display()

## 获取卡牌状态
func get_card_state() -> CardState:
    return card_state

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
        
    print("BP卡牌被点击: %s" % current_card.card_name)
    # 发送信号给父节点处理
    emit_signal("card_clicked", self)

## 卡牌悬停事件（PC端）
func _on_card_mouse_entered():
    # 禁用悬停缩放效果
    pass

func _on_card_mouse_exited():
    # 禁用悬停缩放效果
    pass

## 信号定义
signal card_clicked(card_ui)