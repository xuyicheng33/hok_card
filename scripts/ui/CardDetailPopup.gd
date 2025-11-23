class_name CardDetailPopup
extends Control

## 卡牌详情弹窗
## 适配3:4比例图片显示

@onready var popup_panel: Panel = $PopupPanel
@onready var close_button: Button = $PopupPanel/CloseButton
@onready var card_image: TextureRect = $PopupPanel/Content/CardImage
@onready var card_name: Label = $PopupPanel/Content/Info/CardName
@onready var description: Label = $PopupPanel/Content/Info/Description
@onready var attack_value: Label = $PopupPanel/Content/Stats/AttackStat/AttackValue
@onready var health_value: Label = $PopupPanel/Content/Stats/HealthStat/HealthValue
@onready var armor_value: Label = $PopupPanel/Content/Stats/ArmorStat/ArmorValue
@onready var skill_name: Label = $PopupPanel/Content/SkillInfo/SkillName
@onready var skill_effect: Label = $PopupPanel/Content/SkillInfo/SkillEffect

## 设置卡牌详情并显示弹窗
func setup_card_details(card: Card):
	if not card:
		print("警告: 卡牌数据为空")
		return
	
	# 等待节点准备就绪
	if not is_node_ready():
		await ready
	
	# 更新卡牌信息
	if card.card_image and card_image:
		card_image.texture = card.card_image
	
	if card_name:
		card_name.text = card.card_name
	
	if description:
		description.text = card.description
	
	if attack_value:
		attack_value.text = str(card.attack)
	
	if health_value:
		health_value.text = str(card.health)
	
	if armor_value:
		armor_value.text = str(card.armor)
	
	if skill_name:
		skill_name.text = card.skill_name
	
	if skill_effect:
		skill_effect.text = card.skill_effect
	
	# 显示弹窗动画
	show_popup()

## 显示弹窗动画
func show_popup():
	# 设置初始状态
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	# 播放出现动画
	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_callback(_on_popup_shown)

## 弹窗显示完成
func _on_popup_shown():
	# 连接关闭按钮信号
	if close_button and not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

## 关闭按钮点击事件
func _on_close_button_pressed():
	close_popup()

## 关闭弹窗
func close_popup():
	# 播放消失动画
	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.2)
	tween.tween_callback(queue_free)

## 处理点击背景关闭
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 检查是否点击在弹窗面板外
			var local_pos = popup_panel.global_transform.affine_inverse() * event.global_position
			if not popup_panel.get_rect().has_point(local_pos):
				close_popup()
	elif event is InputEventScreenTouch:
		if event.pressed:
			# 检查是否点击在弹窗面板外
			var local_pos = popup_panel.global_transform.affine_inverse() * event.position
			if not popup_panel.get_rect().has_point(local_pos):
				close_popup()

## 处理键盘输入（ESC关闭）
func _unhandled_input(event):
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			close_popup()

func _ready():
	# 设置全屏覆盖
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
