extends Node

## 全局音乐管理器
## 管理背景音乐的播放，确保场景切换时保持连续性

var background_music: AudioStreamPlayer
var current_music_path: String = ""
var is_music_playing: bool = false
var debug_mode: bool = true

# 添加用户暂停状态跟踪
var user_paused: bool = false

func _ready():
	print("全局音乐管理器初始化...")
	
	# 创建全局音乐播放器
	background_music = AudioStreamPlayer.new()
	background_music.volume_db = -10.0
	background_music.autoplay = false  # 不自动播放
	add_child(background_music)
	
	# 监听播放结束事件
	background_music.finished.connect(_on_music_finished)
	
	print("全局音乐管理器就绪")
	
	# 延迟加载主菜单音乐，确保资源系统就绪
	call_deferred("_load_main_menu_music")

## 加载主菜单音乐
func _load_main_menu_music():
	# 🔇 测试模式：跳过自动播放音乐
	print("🔇 测试模式：已禁用自动播放音乐")
	# if current_music_path == "":
	# 	play_music("res://assets/music/bgm.mp3")

## 播放背景音乐
func play_music(music_path: String, _loop: bool = true):
	# 如果已经在播放相同的音乐，不需要重新加载
	if current_music_path == music_path and is_music_playing and not background_music.stream_paused:
		if debug_mode:
			print("音乐管理器: 音乐已在播放: %s" % music_path)
		return
	
	if debug_mode:
		print("音乐管理器: 尝试播放音乐: %s" % music_path)
	
	# 检查音乐资源是否存在
	if not ResourceLoader.exists(music_path):
		print("警告: 音乐文件不存在 %s" % music_path)
		return
	
	# 加载音乐资源
	var music_resource = load(music_path)
	if not music_resource:
		print("警告: 音乐文件加载失败 %s" % music_path)
		return
	
	# 停止当前音乐
	if is_music_playing:
		background_music.stop()
	
	# 设置新音乐
	background_music.stream = music_resource
	current_music_path = music_path
	
	# 播放音乐
	background_music.play()
	is_music_playing = true
	user_paused = false  # 重置用户暂停状态
	
	if debug_mode:
		print("音乐管理器: 音乐播放成功: %s" % music_path)

## 音乐播放结束事件
func _on_music_finished():
	if debug_mode:
		print("音乐管理器: 音乐播放完成")
	
	# 如果需要循环播放
	if is_music_playing and current_music_path != "":
		background_music.play()
		if debug_mode:
			print("音乐管理器: 重新开始播放")

## 停止音乐
func stop_music():
	if is_music_playing:
		background_music.stop()
		is_music_playing = false
		current_music_path = ""
		user_paused = false
		if debug_mode:
			print("音乐管理器: 音乐已停止")

## 暂停音乐
func pause_music():
	if is_music_playing and background_music.playing:
		background_music.stream_paused = true
		user_paused = true  # 标记为用户暂停
		if debug_mode:
			print("音乐管理器: 音乐已暂停")

## 恢复音乐
func resume_music():
	if is_music_playing:
		background_music.stream_paused = false
		user_paused = false  # 重置用户暂停状态
		if debug_mode:
			print("音乐管理器: 音乐已恢复")

## 设置音量
func set_volume(volume_db: float):
	background_music.volume_db = volume_db
	if debug_mode:
		print("音乐管理器: 音乐音量设置为: %f dB" % volume_db)

## 检查是否正在播放
func is_playing() -> bool:
	# 检查播放器是否存在
	if not background_music:
		return false
	
	# 检查是否有流数据
	if not background_music.stream:
		return false
	
	# 检查实际播放状态
	var actually_playing = background_music.playing and not background_music.stream_paused
	
	return actually_playing

## 获取当前播放的音乐路径
func get_current_music_path() -> String:
	return current_music_path

## 设置用户暂停状态
func set_user_paused(paused: bool):
	user_paused = paused