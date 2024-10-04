extends Node2D

# Get directories for app and music paths
var base_dir = get_application_base_dir()
var external_music_path = base_dir + "/Music"

# Constants
var tracks_per_page = 20

# Playback Modes
enum PlaybackMode { NORMAL, SHUFFLE, PROGRAM }
var current_playback_mode = PlaybackMode.NORMAL

# Repeat Modes
enum RepeatMode { NO_REPEAT, REPEAT_ONE, REPEAT_ALL }
var repeat_mode = RepeatMode.NO_REPEAT

# Time Display Modes
enum TimeMode { ELAPSED, REMAINING_TRACK, REMAINING_TOTAL }
var time_mode = TimeMode.ELAPSED

# Seeking Parameters
var seeking_forward = false
var seeking_backward = false
var seek_speed = 4

# Shader Time
var shader_time = 0.0

# Track Management
var track_files = []
var original_order = []
var track_durations = []
var current_track_index = 0

# Shuffle Mode Variables
var shuffle_order = []
var current_shuffle_index = -1

# Program Mode Variables
var program_list = []
var current_program_position = -1

# Pagination
var current_page = 0

func _ready():
	randomize()
	print(external_music_path)
	$playbackButtons/play_button.grab_focus()
	assign_track_buttons()
	populate_tracks()
	original_order = track_files.duplicate()
	calculate_track_durations()
	update_track_visibility()

func _physics_process(delta):
	update_playback_mode_display()
	update_cursor_position()
	update_shader_time(delta)
	handle_seeking(delta)

# Track Assignment and Loading
func assign_track_buttons():
	var button_index = 1
	for button in get_tree().get_nodes_in_group("track_buttons"):
		var callable = Callable(self, "_on_track_button_pressed").bind(button_index)
		button.connect("pressed", callable)
		button_index += 1

func populate_tracks():
	track_files.clear()
	var dir = DirAccess.open(external_music_path)
	if dir:
		print("External playlist loaded from ", external_music_path)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".mp3") or file_name.ends_with(".ogg"):
				var full_path = external_music_path + "/" + file_name
				track_files.append(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Failed to open directory:", external_music_path)
		print("Loading default playlist.")
		load_default_playlist()
	original_order = track_files.duplicate()
	setup_tracks_after_loading()
	
func load_default_playlist():
	var default_tracks = [
		"res://Music/track_01.mp3",
		"res://Music/track_02.mp3",
		"res://Music/track_03.mp3",
		"res://Music/track_04.mp3"
	]
	for track_path in default_tracks:
		if ResourceLoader.exists(track_path):
			track_files.append(track_path)
		else:
			print("Failed to load internal resource: ", track_path)

func setup_tracks_after_loading():
	if track_files.size() > 0:
		calculate_track_durations()
		current_track_index = 0
		load_track()
		$AudioStreamPlayer.stop()
	else:
		print("No MP3 files found in the selected directory.")
		# Optionally, show a popup or message to the user

func calculate_track_durations():
	track_durations.clear()
	for track_path in track_files:
		var duration = get_track_duration(track_path)
		track_durations.append(duration if duration >= 0 else 0.0)

func get_track_duration(path: String) -> float:
	var music_stream = load_mp3(path)
	if music_stream:
		return music_stream.get_length()
	return -1.0

func load_mp3(path: String) -> AudioStream:
	if path.begins_with("res://"):
		var stream = ResourceLoader.load(path)
		if stream:
			return stream as AudioStream
		else:
			print("Failed to load resource:", path)
			return null
	else:
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var data = file.get_buffer(file.get_length())
			file.close()
			if data.size() == 0:
				print("File is empty:", path)
				return null
			var sound = AudioStreamMP3.new()
			sound.data = data
			return sound
		else:
			print("Failed to open file:", path)
			return null

# Playback Control Functions
func load_track():
	var track_index = get_current_track_index()
	if track_index == -1:
		print("Cannot load track: Invalid track index.")
		return
	if track_index >= track_files.size() or track_index < 0:
		print("Track index out of range.")
		return
	var track_path = track_files[track_index]
	var stream = load_mp3(track_path)
	if stream:
		$AudioStreamPlayer.stream = stream
		update_current_track_label()
	else:
		print("Failed to load stream for track: ", track_path)

func get_current_track_index() -> int:
	match current_playback_mode:
		PlaybackMode.NORMAL:
			return current_track_index
		PlaybackMode.SHUFFLE:
			if current_shuffle_index >= 0 and current_shuffle_index < shuffle_order.size():
				return shuffle_order[current_shuffle_index]
			else:
				print("Invalid shuffle index.")
				return -1
		PlaybackMode.PROGRAM:
			if current_program_position >= 0 and current_program_position < program_list.size():
				return program_list[current_program_position]
			else:
				print("Invalid program position.")
				return -1
		_:
			print("Unknown playback mode.")
			return -1  # Added default case to ensure all paths return a value

func _on_play_button_pressed():
	if not $AudioStreamPlayer.is_playing():
		if current_playback_mode == PlaybackMode.PROGRAM:
			if program_list.size() > 0:
				if current_program_position == -1:
					current_program_position = 0
				load_track()
				$AudioStreamPlayer.play()
			else:
				print("Program list is empty")
		elif current_playback_mode == PlaybackMode.SHUFFLE:
			if shuffle_order.size() > 0:
				if current_shuffle_index == -1:
					current_shuffle_index = 0
				load_track()
				$AudioStreamPlayer.play()
			else:
				print("Shuffle list is empty")
		else:
			load_track()
			$AudioStreamPlayer.play()

func _on_pause_button_pressed():
	$AudioStreamPlayer.stream_paused = !$AudioStreamPlayer.stream_paused

func _on_stop_button_pressed():
	$AudioStreamPlayer.stop()
	$time_label.text = "00        00"

func _on_next_button_pressed():
	match current_playback_mode:
		PlaybackMode.NORMAL:
			if current_track_index < track_files.size() - 1:
				current_track_index += 1
			else:
				if repeat_mode == RepeatMode.REPEAT_ALL:
					current_track_index = 0
				else:
					print("End of track list reached.")
					$AudioStreamPlayer.stop()
					return
		PlaybackMode.SHUFFLE:
			current_shuffle_index += 1
			if current_shuffle_index >= shuffle_order.size():
				if repeat_mode == RepeatMode.REPEAT_ALL:
					# Reshuffle the order when repeating
					var n = shuffle_order.size()
					for i in range(n - 1, 0, -1):
						var j = randi() % (i + 1)
						var temp = shuffle_order[i]
						shuffle_order[i] = shuffle_order[j]
						shuffle_order[j] = temp
					current_shuffle_index = 0
				else:
					print("End of shuffle list reached.")
					$AudioStreamPlayer.stop()
					return
			current_track_index = shuffle_order[current_shuffle_index]
		PlaybackMode.PROGRAM:
			current_program_position += 1
			if current_program_position >= program_list.size():
				if repeat_mode == RepeatMode.REPEAT_ALL:
					current_program_position = 0
				else:
					print("End of program list reached.")
					$AudioStreamPlayer.stop()
					return
	load_track()
	$AudioStreamPlayer.play()
	update_track_visibility()

func _on_previous_button_pressed():
	var current_position = $AudioStreamPlayer.get_playback_position()
	if current_position > 3.0:
		$AudioStreamPlayer.seek(0)
	else:
		match current_playback_mode:
			PlaybackMode.NORMAL:
				if current_track_index > 0:
					current_track_index -= 1
				else:
					print("Start of track list reached.")
					return
			PlaybackMode.SHUFFLE:
				if current_shuffle_index > 0:
					current_shuffle_index -= 1
				else:
					print("No previous track in shuffle history.")
					return
				current_track_index = shuffle_order[current_shuffle_index]
			PlaybackMode.PROGRAM:
				if current_program_position > 0:
					current_program_position -= 1
				else:
					print("Start of program list reached.")
					return
	load_track()
	$AudioStreamPlayer.play()
	update_track_visibility()

func _on_audio_stream_player_finished():
	if repeat_mode == RepeatMode.REPEAT_ONE:
		load_track()
		$AudioStreamPlayer.play()
	else:
		_on_next_button_pressed()
	update_track_visibility()

# Playback Mode Functions
func _on_shuffle_button_pressed():
	if current_playback_mode != PlaybackMode.SHUFFLE:
		if track_files.size() == 0:
			print("No tracks available to shuffle.")
			return  # Exit the function early
		current_playback_mode = PlaybackMode.SHUFFLE
		shuffle_order = range(track_files.size())
		
		# Implement the Fisher-Yates shuffle algorithm directly
		var n = shuffle_order.size()
		for i in range(n - 1, 0, -1):
			var j = randi() % (i + 1)
			var temp = shuffle_order[i]
			shuffle_order[i] = shuffle_order[j]
			shuffle_order[j] = temp
		
		current_shuffle_index = 0
		current_track_index = shuffle_order[current_shuffle_index]
		load_track()
		$AudioStreamPlayer.play()
	else:
		current_playback_mode = PlaybackMode.NORMAL
		current_track_index = 0
		current_shuffle_index = -1
	update_track_visibility()

func _on_program_button_pressed():
	if current_playback_mode != PlaybackMode.PROGRAM:
		current_playback_mode = PlaybackMode.PROGRAM
		program_list.clear()
		current_program_position = -1
		update_track_visibility()
		print("Program mode activated")
	else:
		current_playback_mode = PlaybackMode.NORMAL
		program_list.clear()
		current_program_position = -1
		current_track_index = 0
		load_track()
		update_track_visibility()
		print("Normal mode")

func add_to_program_list(track_index: int):
	program_list.append(track_index)
	if current_program_position == -1:
		current_program_position = 0
		load_track()
	update_track_visibility()
	print("Program list: ", program_list)

# UI Update Functions
func update_track_visibility():
	var track_buttons = get_tree().get_nodes_in_group("track_buttons")
	var start_index = current_page * tracks_per_page

	for i in range(tracks_per_page):
		if i >= track_buttons.size():
			break  # No more buttons to update

		var track_button = track_buttons[i]
		var orb = track_button.get_node("track_%02d_orb" % (i + 1))
		var orb_label = track_button.get_node("track_%02d_orb_label" % (i + 1))

		var track_index = start_index + i

		if track_index >= track_files.size():
			orb.visible = false
			orb_label.visible = false
			continue

		# Update the label with the correct track number
		orb_label.text = str(original_order.find(track_files[track_index]) + 1)
		orb_label.visible = true

		# Update orb visibility based on playback mode
		if current_playback_mode == PlaybackMode.NORMAL:
			orb.visible = track_index >= current_track_index
		elif current_playback_mode == PlaybackMode.SHUFFLE:
			var shuffled_index = shuffle_order.find(track_index)
			orb.visible = shuffled_index >= current_shuffle_index
		elif current_playback_mode == PlaybackMode.PROGRAM:
			if track_index in program_list:
				var program_index = program_list.find(track_index)
				orb.visible = program_index >= current_program_position
			else:
				orb.visible = false

func update_current_track_label():
	var track_index = get_current_track_index()
	if track_index != -1 and track_index < track_files.size():
		var original_index = original_order.find(track_files[track_index])
		$current_track_label.text = str(original_index + 1)
	else:
		$current_track_label.text = "--"

func update_playback_mode_display():
	match current_playback_mode:
		PlaybackMode.NORMAL:
			$current_playback_sprite.texture = load("res://Assets/continue_button_no_bg.png")
		PlaybackMode.SHUFFLE:
			$current_playback_sprite.texture = load("res://Assets/shuffle_button_no_bg.png")
		PlaybackMode.PROGRAM:
			$current_playback_sprite.texture = load("res://Assets/program_button_no_bg.png")

func update_repeat_label():
	match repeat_mode:
		RepeatMode.NO_REPEAT:
			$repeat_mode_sprite.visible = false
		RepeatMode.REPEAT_ONE:
			$repeat_mode_sprite.texture = load("res://Assets/repeat_button_one_no_bg.png")
			$repeat_mode_sprite.visible = true
		RepeatMode.REPEAT_ALL:
			$repeat_mode_sprite.texture = load("res://Assets/repeat_button_all_no_bg.png")
			$repeat_mode_sprite.visible = true

func update_elapsed_time_label():
	var elapsed_time = $AudioStreamPlayer.get_playback_position() if $AudioStreamPlayer.is_playing() else 0.0
	var minutes = 0
	var seconds = 0

	if time_mode == TimeMode.REMAINING_TRACK or time_mode == TimeMode.REMAINING_TOTAL:
		if not $AudioStreamPlayer.stream or $AudioStreamPlayer.stream.get_length() <= 0:
			print("Stream is not loaded or is invalid.")
			$time_label.text = "00        00"
			return

	match time_mode:
		TimeMode.ELAPSED:
			minutes = int(elapsed_time / 60)
			seconds = int(elapsed_time) % 60
		TimeMode.REMAINING_TRACK:
			var remaining_track_time = $AudioStreamPlayer.stream.get_length() - elapsed_time
			minutes = int(remaining_track_time / 60)
			seconds = int(remaining_track_time) % 60
		TimeMode.REMAINING_TOTAL:
			var total_remaining_time = get_total_remaining_time() - elapsed_time
			minutes = int(total_remaining_time / 60)
			seconds = int(total_remaining_time) % 60

	$time_label.text = "%02d        %02d" % [minutes, seconds]

# Navigation and Input Handling
func _on_unknown_button_pressed():
	var total_pages = ceil(float(track_files.size()) / tracks_per_page)
	if current_page < total_pages - 1:
		current_page += 1
	else:
		current_page = 0
	update_track_visibility()

func _on_track_button_pressed(track_number: int):
	var track_index = (current_page * tracks_per_page) + (track_number - 1)
	if track_index >= track_files.size():
		print("No track loaded at this position.")
		return

	if current_playback_mode == PlaybackMode.PROGRAM:
		add_to_program_list(track_index)
		print("Added track", track_index, "to program list.")
	else:
		current_track_index = track_index
		current_shuffle_index = shuffle_order.find(track_index) if current_playback_mode == PlaybackMode.SHUFFLE else -1
		current_program_position = -1
		load_track()
		$AudioStreamPlayer.play()

	update_track_visibility()

func _input(_event):
	if Input.is_action_just_pressed("ui_select"):
		$VisualiserLayer/Quasar.visible = !$VisualiserLayer/Quasar.visible

# Utility Functions
func get_application_base_dir() -> String:
	base_dir = ""
	if OS.get_name() == "macOS":
		var executable_path = OS.get_executable_path()
		base_dir = executable_path.get_base_dir().get_base_dir().get_base_dir().get_base_dir()
	else:
		base_dir = OS.get_executable_path().get_base_dir()
	print(OS.get_name())
	return base_dir

func get_total_remaining_time() -> float:
	var total_remaining_time = 0.0
	if current_playback_mode == PlaybackMode.PROGRAM:
		if current_program_position >= 0:
			for i in range(current_program_position, program_list.size()):
				var track_idx = program_list[i]
				if track_idx < track_durations.size():
					total_remaining_time += track_durations[track_idx]
	elif current_playback_mode == PlaybackMode.SHUFFLE:
		for i in range(current_shuffle_index + 1, shuffle_order.size()):
			var track_idx = shuffle_order[i]
			if track_idx < track_durations.size():
				total_remaining_time += track_durations[track_idx]
	else:
		for i in range(current_track_index, track_durations.size()):
			total_remaining_time += track_durations[i]
	return total_remaining_time

func update_cursor_position():
	var focused_node = get_viewport().gui_get_focus_owner()
	if focused_node:
		$cursor.global_position = focused_node.global_position + (focused_node.size * 0.5)

func update_shader_time(delta):
	if $AudioStreamPlayer.is_playing():
		shader_time += delta
		update_elapsed_time_label()
	if $VisualiserLayer/VisualiserRect.visible:
		$VisualiserLayer/VisualiserRect.material.set_shader_parameter("iTime", shader_time)

func handle_seeking(delta):
	if seeking_forward:
		$AudioStreamPlayer.seek($AudioStreamPlayer.get_playback_position() + delta * seek_speed)
	elif seeking_backward:
		$AudioStreamPlayer.seek($AudioStreamPlayer.get_playback_position() - delta * seek_speed)

# Repeat and Time Mode Controls
func _on_repeat_button_pressed():
	repeat_mode = ((repeat_mode + 1) % RepeatMode.size()) as RepeatMode
	update_repeat_label()

func _on_time_button_pressed():
	time_mode = (time_mode + 1) % TimeMode.size() as TimeMode
	update_elapsed_time_label()
	$time_remaining_orb.visible = (time_mode != TimeMode.ELAPSED)

# Seeking Controls
func _on_seek_backward_button_button_down():
	seeking_backward = true

func _on_seek_backward_button_button_up():
	seeking_backward = false

func _on_seek_forward_button_button_down():
	seeking_forward = true

func _on_seek_forward_button_button_up():
	seeking_forward = false

func _on_continue_button_pressed():
	current_playback_mode = PlaybackMode.NORMAL
	if repeat_mode != RepeatMode.NO_REPEAT:
		repeat_mode = RepeatMode.NO_REPEAT
		$repeat_mode_sprite.texture = load("res://Assets/repeat_button_no_bg.png")
		$repeat_mode_sprite.visible = false
	else:
		pass
	if current_track_index:
		var currently_playing_track = track_files[current_track_index]
		current_track_index = original_order.find(currently_playing_track)
	else: current_track_index = 0

	update_elapsed_time_label()
	update_track_visibility()

# Exit Function
func _on_exit_button_pressed():
	get_tree().quit()

func _on_custom_music_dir_pressed() -> void:
	$DirSelect.popup()

func _on_dir_select_dir_selected(dir_path) -> void:
	print("Directory selected:", dir_path)
	external_music_path = dir_path
	populate_tracks()
	original_order = track_files.duplicate()  # Update original_order
	reset_playback_state()
	load_track()  # Load the first track
	current_page = 0
	update_track_visibility()
	update_elapsed_time_label()
	
func reset_playback_state():
	current_track_index = 0
	current_shuffle_index = -1
	current_program_position = -1
	shuffle_order.clear()
	program_list.clear()
	current_playback_mode = PlaybackMode.NORMAL
	$AudioStreamPlayer.stop()
