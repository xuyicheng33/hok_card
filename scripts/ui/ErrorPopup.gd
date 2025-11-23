class_name ErrorPopup
extends PopupPanel

@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel
@onready var ok_button: Button = $Panel/VBoxContainer/ButtonContainer/OKButton

func _ready():
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)

func set_message(message: String):
	if message_label:
		message_label.text = message

func _on_ok_pressed():
	hide()
	queue_free()