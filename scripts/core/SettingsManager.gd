extends Node

## 全局设置管理器
## 管理游戏的所有设置选项，包括音频、显示、游戏和控制设置

# 设置文件路径
const SETTINGS_FILE_PATH = "user://settings.json"

# 默认设置
var default_settings = {
	"audio": {
		"master_volume": 80,
		"music_volume": 80,
		"sfx_volume": 80,
		"mute": false
	},
	"display": {
		"fullscreen": false,
		"resolution_width": 1920,
		"resolution_height": 1080,
		"quality_level": 2,
		"vsync": true
	},
	"game": {
		"animation_speed": 1.0,
		"auto_save": true
	}
}

# 当前设置
var current_settings = {}

# 信号
signal settings_changed(category: String, key: String, value)
signal settings_loaded()

func _ready():
	print("设置管理器初始化...")
	load_settings()
	apply_all_settings()
	print("设置管理器就绪")

## 加载设置
func load_settings():
	print("加载设置文件...")
	
	if FileAccess.file_exists(SETTINGS_FILE_PATH):
		var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_text)
			
			if parse_result == OK:
				var loaded_data = json.data
				# 合并加载的设置和默认设置
				current_settings = merge_settings(default_settings, loaded_data)
				print("设置加载成功")
			else:
				print("设置文件解析失败，使用默认设置")
				current_settings = default_settings.duplicate(true)
		else:
			print("无法打开设置文件，使用默认设置")
			current_settings = default_settings.duplicate(true)
	else:
		print("设置文件不存在，使用默认设置")
		current_settings = default_settings.duplicate(true)
	
	settings_loaded.emit()

## 保存设置
func save_settings():
	print("保存设置...")
	
	var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(current_settings)
		file.store_string(json_text)
		file.close()
		print("设置保存成功")
	else:
		print("保存设置失败")

## 合并设置（保留默认结构，更新已有值）
func merge_settings(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var result = defaults.duplicate(true)
	
	for category in loaded.keys():
		if result.has(category) and typeof(result[category]) == TYPE_DICTIONARY:
			for key in loaded[category].keys():
				if result[category].has(key):
					result[category][key] = loaded[category][key]
	
	return result

## 获取设置值
func get_setting(category: String, key: String, default_value = null):
	if current_settings.has(category) and current_settings[category].has(key):
		return current_settings[category][key]
	return default_value

## 设置值
func set_setting(category: String, key: String, value):
	if not current_settings.has(category):
		current_settings[category] = {}
	
	current_settings[category][key] = value
	settings_changed.emit(category, key, value)
	
	# 立即应用某些设置
	apply_setting(category, key, value)

## 应用单个设置
func apply_setting(category: String, key: String, value):
	match category:
		"audio":
			apply_audio_setting(key, value)
		"display":
			apply_display_setting(key, value)
		"game":
			apply_game_setting(key, value)

## 应用音频设置
func apply_audio_setting(key: String, value):
	match key:
		"master_volume":
			AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
		"music_volume":
			if MusicManager:
				var volume_db = linear_to_db(value / 100.0) if value > 0 else -80.0
				MusicManager.set_volume(volume_db)
		"sfx_volume":
			# SFX音量设置
			pass
		"mute":
			AudioServer.set_bus_mute(0, value)

## 应用显示设置
func apply_display_setting(key: String, value):
	match key:
		"fullscreen":
			if value:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"resolution_width", "resolution_height":
			# 分辨率设置
			var width = get_setting("display", "resolution_width")
			var height = get_setting("display", "resolution_height")
			DisplayServer.window_set_size(Vector2i(width, height))
		"quality_level":
			# 画质设置
			var quality_names = ["低", "中", "高", "极高"]
			print("画质设置: %s" % quality_names[value])
		"vsync":
			if value:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			else:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

## 应用游戏设置
func apply_game_setting(key: String, value):
	match key:
		"animation_speed":
			# 动画速度设置
			Engine.time_scale = value
		"auto_save":
			print("自动保存: %s" % ("开启" if value else "关闭"))


## 应用所有设置
func apply_all_settings():
	print("应用所有设置...")
	
	# 应用音频设置
	for key in current_settings.audio.keys():
		apply_audio_setting(key, current_settings.audio[key])
	
	# 应用显示设置
	for key in current_settings.display.keys():
		apply_display_setting(key, current_settings.display[key])
	
	# 应用游戏设置
	for key in current_settings.game.keys():
		apply_game_setting(key, current_settings.game[key])

## 重置设置
func reset_settings(category: String = ""):
	if category.is_empty():
		# 重置所有设置
		current_settings = default_settings.duplicate(true)
		print("所有设置已重置")
	else:
		# 重置特定分类
		if default_settings.has(category):
			current_settings[category] = default_settings[category].duplicate(true)
			print("已重置 %s 设置" % category)
	
	apply_all_settings()
	save_settings()

## 获取可用分辨率
func get_available_resolutions() -> Array:
	return [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440)
	]

## 获取分辨率名称
func get_resolution_names() -> Array:
	return ["1280 × 720", "1920 × 1080", "2560 × 1440"]

## 获取画质名称
func get_quality_names() -> Array:
	return ["低", "中", "高", "极高"]

## 获取所有设置（传递给设置界面）
func get_all_settings() -> Dictionary:
	return current_settings.duplicate(true)

## 重置为默认值
func reset_to_defaults():
	current_settings = default_settings.duplicate(true)
	apply_all_settings()
	print("设置已重置为默认值")
