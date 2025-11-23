extends Panel

## 音乐播放器组件
## 提供可复用的音乐播放控制UI，可在多个场景中使用

# UI元素引用
var song_label: Label
var previous_button: Button
var play_pause_button: Button
var next_button: Button

# 播放状态
var is_playing: bool = false
var current_song: String = "未播放音乐"

# 播放列表支持
var playlist: Array = []
var current_song_index: int = 0

# 状态检查控制
var ignore_state_check: bool = false
var ignore_timer: float = 0.0

# 用户暂停状态跟踪
var user_paused: bool = false
var last_sync_time: float = 0.0

# 调试模式
var debug_mode: bool = true

func _ready():
	print("音乐播放器初始化...")
	
	# 获取UI元素引用
	song_label = $HBoxContainer/SongLabel
	previous_button = $HBoxContainer/PreviousButton
	play_pause_button = $HBoxContainer/PlayPauseButton
	next_button = $HBoxContainer/NextButton
	
	# 连接按钮事件
	previous_button.pressed.connect(_on_previous_pressed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
	# 初始化默认播放列表
	playlist = [
		"res://assets/music/bgm.mp3",
		"res://assets/music/春日影.mp3",
		"res://assets/music/迷星叫.mp3"
	]
	current_song = "背景音乐"
	
	# 设置初始状态
	sync_with_music_manager()
	
	# 添加处理函数检测音乐状态
	set_process(true)
	
	# 等待下一帧调整UI尺寸
	call_deferred("_adjust_ui_size")
	
	print("音乐播放器初始化完成")

## 调整UI尺寸
func _adjust_ui_size():
	# 根据面板尺寸调整字体大小
	var panel_size = get_size()
	var font_size = int(panel_size.y * 0.4)  # 字体大小为面板高度的40%
	
	if song_label:
		song_label.add_theme_font_size_override("font_size", font_size)
	
	if previous_button:
		previous_button.add_theme_font_size_override("font_size", font_size)
	
	if play_pause_button:
		play_pause_button.add_theme_font_size_override("font_size", font_size)
	
	if next_button:
		next_button.add_theme_font_size_override("font_size", font_size)
	
	print("音乐播放器: UI尺寸已调整，面板尺寸: %s, 字体大小: %d" % [panel_size, font_size])

## 每帧检查音乐状态
func _process(delta):
	# 如果状态检查被暂时忽略，处理计时器
	if ignore_state_check:
		ignore_timer -= delta
		if ignore_timer <= 0:
			ignore_state_check = false
			if debug_mode:
				print("音乐播放器: 恢复状态检查")
		return
	
	# 每秒同步一次状态
	if Time.get_ticks_msec() - last_sync_time > 1000:
		sync_with_music_manager()

## 与音乐管理器同步状态
func sync_with_music_manager():
	# 记录同步时间
	last_sync_time = Time.get_ticks_msec()
	
	# 获取当前实际播放状态
	var actual_playing = MusicManager.is_playing()
	var current_path = MusicManager.get_current_music_path()
	
	# 更新当前歌曲名
	if current_path != "":
		current_song = get_song_name_from_path(current_path)
	
	# 如果用户没有手动暂停，则同步播放状态
	# 最近500毫秒内的用户操作不会被同步覆盖
	if not user_paused or (Time.get_ticks_msec() - last_sync_time > 500):
		if is_playing != actual_playing:
			is_playing = actual_playing
			update_ui()
	elif debug_mode:
		print("音乐播放器: 尊重用户暂停状态，不同步播放状态")

## 更新UI显示
func update_ui():
	if song_label:
		song_label.text = current_song
	
	if play_pause_button:
		play_pause_button.text = "⏸" if is_playing else "▶"
	
	if debug_mode:
		print("音乐播放器: UI已更新 - 当前歌曲: %s, 播放状态: %s" % [current_song, "播放中" if is_playing else "已暂停"])

## 上一首按钮事件
func _on_previous_pressed():
	print("音乐播放器: 上一首")
	
	# 重置用户暂停状态
	user_paused = false
	
	# 暂时忽略状态检查
	ignore_state_check = true
	ignore_timer = 1.0  # 1秒内不检查状态
	
	if playlist.size() > 0:
		current_song_index = (current_song_index - 1 + playlist.size()) % playlist.size()
		var song_path = playlist[current_song_index]
		MusicManager.play_music(song_path)
		is_playing = true
		current_song = get_song_name_from_path(song_path)
		update_ui()

## 播放/暂停按钮事件 - 简化逻辑
func _on_play_pause_pressed():
	print("音乐播放器: 播放/暂停按钮被点击")
	
	# 记录操作时间
	last_sync_time = Time.get_ticks_msec()
	
	# 暂时忽略状态检查，防止被立即覆盖
	ignore_state_check = true
	ignore_timer = 1.0  # 1秒内不检查状态
	
	if is_playing:
		# 当前正在播放，执行暂停
		MusicManager.pause_music()
		is_playing = false
		user_paused = true  # 标记为用户暂停
		print("音乐播放器: 音乐已暂停")
	else:
		# 当前已暂停或未播放，执行播放/恢复
		if MusicManager.current_music_path == "":
			# 如果没有设置音乐，播放默认音乐
			if playlist.size() > 0:
				var song_path = playlist[current_song_index]
				MusicManager.play_music(song_path)
				current_song = get_song_name_from_path(song_path)
				print("音乐播放器: 开始播放 %s" % song_path)
		else:
			# 恢复当前音乐
			MusicManager.resume_music()
			print("音乐播放器: 恢复播放")
		
		is_playing = true
		user_paused = false  # 重置用户暂停状态
	
	# 立即更新UI
	update_ui()

## 下一首按钮事件
func _on_next_pressed():
	print("音乐播放器: 下一首")
	
	# 重置用户暂停状态
	user_paused = false
	
	# 暂时忽略状态检查
	ignore_state_check = true
	ignore_timer = 1.0  # 1秒内不检查状态
	
	if playlist.size() > 0:
		current_song_index = (current_song_index + 1) % playlist.size()
		var song_path = playlist[current_song_index]
		MusicManager.play_music(song_path)
		is_playing = true
		current_song = get_song_name_from_path(song_path)
		update_ui()

## 设置当前歌曲名
func set_current_song(song_name: String):
	current_song = song_name
	update_ui()

## 设置播放列表
func set_playlist(songs: Array):
	playlist = songs
	if playlist.size() > 0:
		current_song_index = 0
		current_song = get_song_name_from_path(playlist[0])
		update_ui()

## 从路径获取歌曲名
func get_song_name_from_path(song_path: String) -> String:
	var file_name = song_path.get_file()
	return file_name.rstrip("." + file_name.get_extension())

## 更新当前歌曲索引
func update_current_song_index():
	if playlist.size() > 0:
		for i in range(playlist.size()):
			if playlist[i] == MusicManager.current_music_path:
				current_song_index = i
				current_song = get_song_name_from_path(playlist[i])
				update_ui()
				break
