class_name SettingsMenu
extends Control

## 设置界面控制脚本
## 负责设置界面的所有交互逻辑和数据绑定

# 布局参数
var base_resolution := Vector2(1280, 720)  # 基准分辨率
var current_scale_factor: float = 1.0       # 当前缩放因子

# 音频设置控件
@onready var master_volume_slider: HSlider = $Background/MainContainer/TabContainer/音频/MasterVolumeContainer/MasterVolumeSlider
@onready var master_volume_value: Label = $Background/MainContainer/TabContainer/音频/MasterVolumeContainer/MasterVolumeValue
@onready var music_volume_slider: HSlider = $Background/MainContainer/TabContainer/音频/MusicVolumeContainer/MusicVolumeSlider
@onready var music_volume_value: Label = $Background/MainContainer/TabContainer/音频/MusicVolumeContainer/MusicVolumeValue
@onready var sfx_volume_slider: HSlider = $Background/MainContainer/TabContainer/音频/SfxVolumeContainer/SfxVolumeSlider
@onready var sfx_volume_value: Label = $Background/MainContainer/TabContainer/音频/SfxVolumeContainer/SfxVolumeValue
@onready var mute_checkbox: CheckBox = $Background/MainContainer/TabContainer/音频/MuteContainer/MuteCheckBox

# 显示设置控件
@onready var fullscreen_checkbox: CheckBox = $Background/MainContainer/TabContainer/显示/FullscreenContainer/FullscreenCheckBox
@onready var resolution_option: OptionButton = $Background/MainContainer/TabContainer/显示/ResolutionContainer/ResolutionOption
@onready var quality_option: OptionButton = $Background/MainContainer/TabContainer/显示/QualityContainer/QualityOption
@onready var vsync_checkbox: CheckBox = $Background/MainContainer/TabContainer/显示/VsyncContainer/VsyncCheckBox

# 游戏设置控件
@onready var animation_speed_slider: HSlider = $Background/MainContainer/TabContainer/游戏/AnimationSpeedContainer/AnimationSpeedSlider
@onready var animation_speed_value: Label = $Background/MainContainer/TabContainer/游戏/AnimationSpeedContainer/AnimationSpeedValue
@onready var auto_save_checkbox: CheckBox = $Background/MainContainer/TabContainer/游戏/AutoSaveContainer/AutoSaveCheckBox

# 按钮控件
@onready var apply_button: Button = $Background/MainContainer/ButtonArea/ApplyButton
@onready var reset_button: Button = $Background/MainContainer/ButtonArea/ResetButton
@onready var back_button: Button = $Background/MainContainer/ButtonArea/BackButton
@onready var music_player: Panel = $Background/MusicPlayer  # 音乐播放器引用

# 可用分辨率列表
var available_resolutions = [
	Vector2i(1920, 1080),
	Vector2i(1680, 1050),
	Vector2i(1600, 900),
	Vector2i(1440, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
	Vector2i(1024, 768)
]

func _ready():
	# 初始化界面
	setup_ui()
	
	# 连接信号
	connect_signals()
	
	# 加载当前设置
	load_current_settings()
	
	# 监听窗口大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# 初始化自适应布局
	call_deferred("initialize_adaptive_layout")

## 初始化UI
func setup_ui():
	# 设置分辨率选项
	setup_resolution_options()
	
	# 设置画质选项
	setup_quality_options()

## 设置分辨率选项
func setup_resolution_options():
	# 安全性检查：确保节点存在
	if not resolution_option or not is_instance_valid(resolution_option):
		print("警告: 分辨率选项节点不存在")
		return
	
	resolution_option.clear()
	for resolution in available_resolutions:
		var text = "%dx%d" % [resolution.x, resolution.y]
		resolution_option.add_item(text)

## 设置画质选项
func setup_quality_options():
	# 安全性检查：确保节点存在
	if not quality_option or not is_instance_valid(quality_option):
		print("警告: 画质选项节点不存在")
		return
	
	quality_option.clear()
	quality_option.add_item("低")
	quality_option.add_item("中")
	quality_option.add_item("高")
	quality_option.add_item("极高")

## 连接所有信号
func connect_signals():
	# 音频设置信号（安全性检查）
	if master_volume_slider and is_instance_valid(master_volume_slider):
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider and is_instance_valid(music_volume_slider):
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider and is_instance_valid(sfx_volume_slider):
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if mute_checkbox and is_instance_valid(mute_checkbox):
		mute_checkbox.toggled.connect(_on_mute_toggled)
	
	# 显示设置信号（安全性检查）
	if fullscreen_checkbox and is_instance_valid(fullscreen_checkbox):
		fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	if resolution_option and is_instance_valid(resolution_option):
		resolution_option.item_selected.connect(_on_resolution_selected)
	if quality_option and is_instance_valid(quality_option):
		quality_option.item_selected.connect(_on_quality_selected)
	if vsync_checkbox and is_instance_valid(vsync_checkbox):
		vsync_checkbox.toggled.connect(_on_vsync_toggled)
	
	# 游戏设置信号（安全性检查）
	if animation_speed_slider and is_instance_valid(animation_speed_slider):
		animation_speed_slider.value_changed.connect(_on_animation_speed_changed)
	if auto_save_checkbox and is_instance_valid(auto_save_checkbox):
		auto_save_checkbox.toggled.connect(_on_auto_save_toggled)
	
	# 按钮信号（安全性检查）
	if apply_button and is_instance_valid(apply_button):
		apply_button.pressed.connect(_on_apply_pressed)
	if reset_button and is_instance_valid(reset_button):
		reset_button.pressed.connect(_on_reset_pressed)
	if back_button and is_instance_valid(back_button):
		back_button.pressed.connect(_on_back_pressed)

## 加载当前设置到界面
func load_current_settings():
	var settings = SettingsManager.get_all_settings()
	
	# 音频设置
	master_volume_slider.value = settings.audio.master_volume
	music_volume_slider.value = settings.audio.music_volume
	sfx_volume_slider.value = settings.audio.sfx_volume
	mute_checkbox.button_pressed = settings.audio.mute
	
	# 更新音量显示
	_update_volume_display()
	
	# 显示设置
	fullscreen_checkbox.button_pressed = settings.display.fullscreen
	vsync_checkbox.button_pressed = settings.display.vsync
	
	# 设置分辨率选择
	var current_resolution = Vector2i(settings.display.resolution_width, settings.display.resolution_height)
	for i in range(available_resolutions.size()):
		if available_resolutions[i] == current_resolution:
			resolution_option.selected = i
			break
	
	# 设置画质选择
	quality_option.selected = settings.display.quality_level
	
	# 游戏设置
	animation_speed_slider.value = settings.game.animation_speed
	auto_save_checkbox.button_pressed = settings.game.auto_save
	
	# 更新动画速度显示
	_update_animation_speed_display()

## 音频设置信号处理
func _on_master_volume_changed(value: float):
	SettingsManager.set_setting("audio", "master_volume", value)
	_update_volume_display()
	# 实时应用音量设置
	if not SettingsManager.get_setting("audio", "mute"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value / 100.0))
	# 提供视觉反馈
	_flash_volume_feedback(master_volume_value)

func _on_music_volume_changed(value: float):
	SettingsManager.set_setting("audio", "music_volume", value)
	_update_volume_display()
	# 如果有音乐管理器，更新音乐音量
	if MusicManager and not SettingsManager.get_setting("audio", "mute"):
		var volume_db = linear_to_db(value / 100.0) if value > 0 else -80.0
		MusicManager.set_volume(volume_db)
	# 提供视觉反馈
	_flash_volume_feedback(music_volume_value)

func _on_sfx_volume_changed(value: float):
	SettingsManager.set_setting("audio", "sfx_volume", value)
	_update_volume_display()
	# 提供视觉反馈
	_flash_volume_feedback(sfx_volume_value)

func _on_mute_toggled(pressed: bool):
	SettingsManager.set_setting("audio", "mute", pressed)
	# 实时应用静音设置
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), pressed)

## 显示设置信号处理
func _on_fullscreen_toggled(pressed: bool):
	SettingsManager.set_setting("display", "fullscreen", pressed)

func _on_resolution_selected(index: int):
	if index >= 0 and index < available_resolutions.size():
		var resolution = available_resolutions[index]
		SettingsManager.set_setting("display", "resolution_width", resolution.x)
		SettingsManager.set_setting("display", "resolution_height", resolution.y)
		# 显示分辨率预览
		_preview_resolution_change(resolution.x, resolution.y)

func _on_quality_selected(index: int):
	SettingsManager.set_setting("display", "quality_level", index)

func _on_vsync_toggled(pressed: bool):
	SettingsManager.set_setting("display", "vsync", pressed)

## 游戏设置信号处理
func _on_animation_speed_changed(value: float):
	SettingsManager.set_setting("game", "animation_speed", value)
	_update_animation_speed_display()
	# 实时应用动画速度设置
	Engine.time_scale = value
	# 提供视觉反馈
	_flash_volume_feedback(animation_speed_value)

func _on_auto_save_toggled(pressed: bool):
	SettingsManager.set_setting("game", "auto_save", pressed)

## 按钮信号处理
func _on_apply_pressed():
	print("应用设置")
	
	# 验证设置
	if not _validate_settings():
		print("设置验证失败，无法应用")
		return
	
	# 应用所有设置
	apply_all_settings()
	
	# 保存设置到文件
	SettingsManager.save_settings()
	
	# 显示确认反馈
	_show_apply_confirmation()

func _on_reset_pressed():
	print("重置设置")
	# 重置为默认值
	SettingsManager.reset_to_defaults()
	# 重新加载界面
	load_current_settings()

func _on_back_pressed():
	print("返回主菜单")
	# 保存当前设置
	SettingsManager.save_settings()
	# 返回主菜单
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

## 应用所有设置
func apply_all_settings():
	var settings = SettingsManager.get_all_settings()
	
	# 应用显示设置
	apply_display_settings(settings.display)
	
	# 应用音频设置
	apply_audio_settings(settings.audio)

## 应用显示设置
func apply_display_settings(display_settings):
	# 应用全屏设置
	if display_settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# 设置窗口大小
		var size = Vector2i(display_settings.resolution_width, display_settings.resolution_height)
		DisplayServer.window_set_size(size)
	
	# 应用垂直同步
	if display_settings.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

## 应用音频设置
func apply_audio_settings(audio_settings):
	# 应用主音量
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 
		linear_to_db(audio_settings.master_volume / 100.0) if not audio_settings.mute else -80.0)
	
	# 应用静音
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), audio_settings.mute)
	
	# 应用背景音乐音量
	if MusicManager:
		var music_volume_db = -80.0
		if not audio_settings.mute and audio_settings.music_volume > 0:
			music_volume_db = linear_to_db(audio_settings.music_volume / 100.0)
		MusicManager.set_volume(music_volume_db)

## 更新音量显示
func _update_volume_display():
	# 安全性检查：确保节点存在
	if master_volume_value and is_instance_valid(master_volume_value):
		master_volume_value.text = "%d%%" % master_volume_slider.value
	if music_volume_value and is_instance_valid(music_volume_value):
		music_volume_value.text = "%d%%" % music_volume_slider.value
	if sfx_volume_value and is_instance_valid(sfx_volume_value):
		sfx_volume_value.text = "%d%%" % sfx_volume_slider.value

## 更新动画速度显示
func _update_animation_speed_display():
	# 安全性检查：确保节点存在
	if animation_speed_value and is_instance_valid(animation_speed_value):
		animation_speed_value.text = "%.1fx" % animation_speed_slider.value

## 处理ESC键返回
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()

## 视觉反馈功能

## 音量设置反馈闪烁效果
func _flash_volume_feedback(node: Control):
	if not node:
		print("警告: 传入的节点为空")
		return
	
	# 安全性检查：确保节点是有效的Control类型
	if not is_instance_valid(node):
		print("警告: 传入的节点无效")
		return
	
	# 创建动画效果
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 颜色闪烁效果
	var original_color = node.modulate
	tween.tween_property(node, "modulate", Color(0.8, 0.9, 1, 1), 0.1)
	tween.tween_property(node, "modulate", original_color, 0.3).set_delay(0.1)
	
	# 缩放效果
	var original_scale = node.scale
	tween.tween_property(node, "scale", original_scale * 1.1, 0.1)
	tween.tween_property(node, "scale", original_scale, 0.3).set_delay(0.1)

## 显示设置预览功能
func _preview_resolution_change(width: int, height: int):
	# 在设置界面显示分辨率预览信息
	var preview_text = "将应用分辨率: %dx%d" % [width, height]
	print(preview_text)
	
	# 可以在这里添加一个临时的提示标签

## 获取当前系统信息
func _get_system_info() -> Dictionary:
	return {
		"current_resolution": DisplayServer.window_get_size(),
		"is_fullscreen": DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"vsync_enabled": DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED,
		"master_volume_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	}

## 设置验证功能
func _validate_settings() -> bool:
	var settings = SettingsManager.get_all_settings()
	
	# 验证音量设置
	if settings.audio.master_volume < 0 or settings.audio.master_volume > 100:
		print("警告: 主音量设置超出范围")
		return false
	
	# 验证分辨率设置
	if settings.display.resolution_width < 640 or settings.display.resolution_height < 480:
		print("警告: 分辨率过低")
		return false
	
	# 验证动画速度
	if settings.game.animation_speed < 0.1 or settings.game.animation_speed > 5.0:
		print("警告: 动画速度设置超出范围")
		return false
	
	return true

## 设置应用确认
func _show_apply_confirmation():
	print("设置已应用并保存")
	# 可以在这里添加一个短暂的确认消息
	
	# 闪烁应用按钮（安全性检查）
	if apply_button and is_instance_valid(apply_button):
		_flash_volume_feedback(apply_button)

## 自适应布局功能

## 初始化自适应布局
func initialize_adaptive_layout():
	print("初始化设置界面自适应布局...")
	
	# 计算当前缩放因子
	calculate_scale_factor()
	
	# 应用自适应布局
	apply_adaptive_layout()

## 计算缩放因子
func calculate_scale_factor():
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_x = viewport_size.x / base_resolution.x
	var scale_y = viewport_size.y / base_resolution.y
	
	# 使用较小的缩放因子以保持尺寸比例
	current_scale_factor = min(scale_x, scale_y)
	# 限制缩放范围，避免过小或过大
	current_scale_factor = clamp(current_scale_factor, 0.8, 2.5)
	
	print("窗口尺寸: %s, 缩放因子: %.2f" % [viewport_size, current_scale_factor])

## 应用自适应布局
func apply_adaptive_layout():
	print("应用设置界面自适应布局...")
	
	# 等待节点就绪
	await get_tree().process_frame
	
	# 更新按钮尺寸
	update_button_sizes()
	
	# 更新标签字体大小
	update_label_font_sizes()
	
	# 更新滑块尺寸
	update_slider_sizes()
	
	# 更新复选框尺寸
	update_checkbox_sizes()
	
	# 更新选项按钮尺寸
	update_option_button_sizes()

## 更新按钮尺寸
func update_button_sizes():
	var buttons = [apply_button, reset_button, back_button]
	
	for button in buttons:
		if not button:
			continue
		
		# 计算新的按钮尺寸
		var base_width = 120
		var base_height = 50
		var new_width = int(base_width * current_scale_factor)
		var new_height = int(base_height * current_scale_factor)
		
		# 限制尺寸范围
		new_width = clamp(new_width, 100, 200)
		new_height = clamp(new_height, 40, 80)
		
		# 应用新尺寸
		button.custom_minimum_size = Vector2(new_width, new_height)
		
		# 更新字体大小
		var base_font_size = 16
		var scaled_font_size = int(base_font_size * current_scale_factor)
		scaled_font_size = clamp(scaled_font_size, 14, 28)
		button.add_theme_font_size_override("font_size", scaled_font_size)

## 更新标签字体大小
func update_label_font_sizes():
	# 获取所有标签节点
	var labels = [
		$Background/MainContainer/TabContainer/音频/MasterVolumeContainer/MasterVolumeLabel,
		$Background/MainContainer/TabContainer/音频/MasterVolumeContainer/MasterVolumeValue,
		$Background/MainContainer/TabContainer/音频/MusicVolumeContainer/MusicVolumeLabel,
		$Background/MainContainer/TabContainer/音频/MusicVolumeContainer/MusicVolumeValue,
		$Background/MainContainer/TabContainer/音频/SfxVolumeContainer/SfxVolumeLabel,
		$Background/MainContainer/TabContainer/音频/SfxVolumeContainer/SfxVolumeValue,
		$Background/MainContainer/TabContainer/音频/MuteContainer/MuteLabel,
		$Background/MainContainer/TabContainer/显示/FullscreenContainer/FullscreenLabel,
		$Background/MainContainer/TabContainer/显示/ResolutionContainer/ResolutionLabel,
		$Background/MainContainer/TabContainer/显示/QualityContainer/QualityLabel,
		$Background/MainContainer/TabContainer/显示/VsyncContainer/VsyncLabel,
		$Background/MainContainer/TabContainer/游戏/AnimationSpeedContainer/AnimationSpeedLabel,
		$Background/MainContainer/TabContainer/ゲーム/AnimationSpeedContainer/AnimationSpeedValue,
		$Background/MainContainer/TabContainer/ゲーム/AutoSaveContainer/AutoSaveLabel,
		$Background/MainContainer/TabContainer/音频/MuteContainer/MuteCheckBox,
		$Background/MainContainer/TabContainer/显示/FullscreenContainer/FullscreenCheckBox,
		$Background/MainContainer/TabContainer/显示/VsyncContainer/VsyncCheckBox,
		$Background/MainContainer/TabContainer/ゲーム/AutoSaveContainer/AutoSaveCheckBox
	]
	
	for label in labels:
		if not label:
			continue
		
		# 计算新的字体大小
		var base_font_size = 14
		var scaled_font_size = int(base_font_size * current_scale_factor)
		scaled_font_size = clamp(scaled_font_size, 12, 24)
		
		# 应用字体大小
		if label is Label:
			label.add_theme_font_size_override("font_size", scaled_font_size)
		elif label is CheckBox:
			label.add_theme_font_size_override("font_size", scaled_font_size)

## 更新滑块尺寸
func update_slider_sizes():
	var sliders = [
		master_volume_slider,
		music_volume_slider,
		sfx_volume_slider,
		animation_speed_slider
	]
	
	for slider in sliders:
		if not slider:
			continue
		
		# 计算新的滑块尺寸
		var base_height = 20
		var new_height = int(base_height * current_scale_factor)
		new_height = clamp(new_height, 15, 40)
		
		# 应用新尺寸
		slider.custom_minimum_size = Vector2(0, new_height)

## 更新复选框尺寸
func update_checkbox_sizes():
	var checkboxes = [
		mute_checkbox,
		fullscreen_checkbox,
		vsync_checkbox,
		auto_save_checkbox
	]
	
	for checkbox in checkboxes:
		if not checkbox:
			continue
		
		# 计算新的复选框尺寸
		var base_size = 20
		var new_size = int(base_size * current_scale_factor)
		new_size = clamp(new_size, 16, 32)
		
		# 应用新尺寸
		checkbox.custom_minimum_size = Vector2(new_size, new_size)

## 更新选项按钮尺寸
func update_option_button_sizes():
	var option_buttons = [
		resolution_option,
		quality_option
	]
	
	for option_button in option_buttons:
		if not option_button:
			continue
		
		# 计算新的选项按钮尺寸
		var base_height = 30
		var new_height = int(base_height * current_scale_factor)
		new_height = clamp(new_height, 25, 50)
		
		# 应用新尺寸
		option_button.custom_minimum_size = Vector2(0, new_height)
		
		# 更新字体大小
		var base_font_size = 14
		var scaled_font_size = int(base_font_size * current_scale_factor)
		scaled_font_size = clamp(scaled_font_size, 12, 24)
		option_button.add_theme_font_size_override("font_size", scaled_font_size)

## 窗口大小变化事件处理
func _on_viewport_size_changed():
	print("设置界面窗口大小发生变化")
	
	# 重新计算和应用布局
	calculate_scale_factor()
	apply_adaptive_layout()
