extends Node2D

# Track Management
var track_files = []
var original_order = []
var track_durations = []
var current_track_index = 0

# Playback Modes
enum PlaybackMode { NORMAL, SHUFFLE, PROGRAM }
var current_playback_mode = PlaybackMode.NORMAL

# Shuffle Mode
var played_tracks = []
var shuffle_order = []
var shuffle_history = []
var current_shuffle_index = -1

# Program Mode
var program_list = []
var current_program_position = 0  # New variable to track position in program_list

# Time Display
enum TimeMode { ELAPSED, REMAINING_TRACK, REMAINING_TOTAL }
var time_mode := TimeMode.ELAPSED

# Repeat Mode
enum RepeatMode { NO_REPEAT, REPEAT_ONE, REPEAT_ALL }
var repeat_mode := RepeatMode.NO_REPEAT

# Seeking
var seeking_forward = false
var seeking_backward = false
var seek_speed = 4

# Shader Time
var shader_time = 0.0

func _ready():
	$playbackButtons/play_button.grab_focus()
	assign_tracks()
	populate_tracks()
	original_order = track_files.duplicate()
	calculate_track_durations()
	update_track_visibility()

func assign_tracks():
	var button_index = 1
	for button in get_tree().get_nodes_in_group("track_buttons"):
		var callable = Callable(self, "_on_track_button_pressed").bind(button_index)
		button.connect("pressed", callable)
		button_index += 1

func populate_tracks():
	track_files.clear()

	# External music folder path
	var external_music_path = OS.get_executable_path().get_base_dir() + "/Music"
	var external_music_directory = DirAccess.open(external_music_path)
	
	if external_music_directory:
		print("External playlist loaded")
		external_music_directory.list_dir_begin()
		var file_name = external_music_directory.get_next()
		while file_name != "":
			if file_name.ends_with(".mp3"):
				var full_path = external_music_path + "/" + file_name
				track_files.append(full_path)
			file_name = external_music_directory.get_next()
		external_music_directory.list_dir_end()
	else:
		# Fallback to internal resources (res://)
		print("Default playlist loaded")
		var default_tracks = [
			"res://Music/01 - Opening the Portal.mp3",
			"res://Music/02 - Liminal Phasing.mp3",
			"res://Music/03 - Megadalene.mp3",
			"res://Music/04 - Closing The Portal (Avec Batterie).mp3"
		]
		for track_path in default_tracks:
			if ResourceLoader.exists(track_path):
				track_files.append(track_path)
			else:
				print("Failed to load internal resource: ", track_path)

	setup_tracks_after_loading()

func setup_tracks_after_loading():
	if track_files.size() > 0:
		load_track(0)
		$AudioStreamPlayer.stop()
		calculate_track_durations()

func calculate_track_durations():
	track_durations.clear()
	for track_path in track_files:
		var duration = get_track_duration(track_path)
		if duration >= 0:
			track_durations.append(duration)
		else:
			track_durations.append(0)

func _physics_process(delta):
	cursor_movement()

	if $AudioStreamPlayer.is_playing():
		shader_time += delta
		update_elapsed_time_label()
		if $VisualiserLayer/VisualiserRect.visible:
			$VisualiserLayer/VisualiserRect.material.set_shader_parameter("iTime", shader_time)

	if seeking_forward:
		$AudioStreamPlayer.seek($AudioStreamPlayer.get_playback_position() + delta * seek_speed)
	elif seeking_backward:
		$AudioStreamPlayer.seek($AudioStreamPlayer.get_playback_position() - delta * seek_speed)

func cursor_movement():
	var focused_node = get_viewport().gui_get_focus_owner()
	if focused_node:
		$cursor.global_position = focused_node.global_position + (focused_node.size * 0.5)

func load_track(track_index: int):
	if current_playback_mode == PlaybackMode.PROGRAM:
		# Ensure current_program_position is valid
		if current_program_position >= program_list.size() or current_program_position < 0:
			print("Program position out of range.")
			return
		track_index = program_list[current_program_position]
	elif current_playback_mode == PlaybackMode.SHUFFLE:
		if current_track_index >= track_files.size() or current_track_index < 0:
			print("Shuffle track index out of range.")
			return
		track_index = current_track_index
	else:
		if track_index >= track_files.size() or track_index < 0:
			print("Track index out of range.")
			return

	var track_path = track_files[track_index]
	var stream = load_mp3(track_path)
	if stream:
		$AudioStreamPlayer.stream = stream
		current_track_index = track_index  # Update current_track_index
		update_current_track_label()
	else:
		print("Failed to load stream for track: ", track_path)

func load_mp3(path: String) -> AudioStream:
	if path.begins_with("res://"):  # Internal resource
		return ResourceLoader.load(path) as AudioStream
	else:  # External file
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var sound = AudioStreamMP3.new()
			sound.data = file.get_buffer(file.get_length())
			file.close()
			return sound
	return null

func update_track_visibility():
	var track_buttons = get_tree().get_nodes_in_group("track_buttons")
	for i in range(track_buttons.size()):
		var track_button = track_buttons[i]
		var orb_name = "track_%02d_orb" % (i + 1)
		var orb_label_name = "track_%02d_orb_label" % (i + 1)

		var orb = track_button.get_node_or_null(orb_name)
		var orb_label = track_button.get_node_or_null(orb_label_name)

		if orb:
			if i < track_files.size():  # Only consider loaded tracks
				match current_playback_mode:
					PlaybackMode.NORMAL:
						orb.visible = i >= current_track_index
					PlaybackMode.SHUFFLE:
						orb.visible = (i == current_track_index) or (i not in played_tracks)
					PlaybackMode.PROGRAM:
						orb.visible = i in program_list
			else:
				orb.visible = false  # Hide orbs for non-loaded tracks

		if orb_label:
			orb_label.visible = i < track_files.size()

func update_current_track_label():
	var original_index = original_order.find(track_files[current_track_index])
	$current_track_label.text = str(original_index + 1)

func update_elapsed_time_label():
	var elapsed_time = 0.0
	if $AudioStreamPlayer.is_playing():
		elapsed_time = $AudioStreamPlayer.get_playback_position()

	var minutes = 0
	var seconds = 0

	if time_mode == TimeMode.REMAINING_TRACK or time_mode == TimeMode.REMAINING_TOTAL:
		if not $AudioStreamPlayer.stream or $AudioStreamPlayer.stream.get_length() <= 0:
			print("Stream is not loaded or is invalid.")
			$time_label.text = "00      00"
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
			var total_remaining_time = get_total_remaining_time()
			total_remaining_time -= elapsed_time
			minutes = int(total_remaining_time / 60)
			seconds = int(total_remaining_time) % 60

	$time_label.text = "%02d        %02d" % [minutes, seconds]

func _on_play_button_pressed():
	if not $AudioStreamPlayer.is_playing():
		if current_playback_mode == PlaybackMode.PROGRAM:
			if program_list.size() > 0:
				current_program_position = 0  # Start from the beginning of the program list
				load_track(program_list[current_program_position])
				$AudioStreamPlayer.play()
			else:
				print("Program list is empty")
				return
		else:
			load_track(current_track_index)
			$AudioStreamPlayer.play()

func _on_pause_button_pressed():
	$AudioStreamPlayer.stream_paused = !$AudioStreamPlayer.stream_paused

func _on_stop_button_pressed():
	$AudioStreamPlayer.stop()
	$time_label.text = "00      00"

func _on_next_button_pressed():
	match current_playback_mode:
		PlaybackMode.NORMAL:
			if current_track_index < (track_files.size()) - 1:
				current_track_index += 1
			else:
				if repeat_mode == RepeatMode.REPEAT_ALL:
					current_track_index = 0
				else:
					print("End of track list reached.")
					$AudioStreamPlayer.stop()
					return
		PlaybackMode.SHUFFLE:
			var next_track = get_next_shuffle_track()
			if next_track == -1:
				print("Shuffle playback finished.")
				$AudioStreamPlayer.stop()
				return
			current_track_index = next_track
			played_tracks.append(current_track_index)
		PlaybackMode.PROGRAM:
			if current_program_position < program_list.size() - 1:
				current_program_position += 1
				load_track(program_list[current_program_position])
				$AudioStreamPlayer.play()
			else:
				if repeat_mode == RepeatMode.REPEAT_ALL:
					current_program_position = 0
					load_track(program_list[current_program_position])
					$AudioStreamPlayer.play()
				else:
					print("End of program list reached.")
					$AudioStreamPlayer.stop()
					return
			return  # Exit early since load and play are already called

	load_track(current_track_index)
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
				if shuffle_history.size() > 1:
					shuffle_history.pop_back()  # Remove current track
					current_track_index = shuffle_history.pop_back()  # Get previous track
					if played_tracks.size() > 0:
						played_tracks.pop_back()  # Remove the last played track
				else:
					print("No previous track in shuffle history.")
					return
			PlaybackMode.PROGRAM:
				if current_program_position > 0:
					current_program_position -= 1
					load_track(program_list[current_program_position])
					$AudioStreamPlayer.play()
				else:
					print("Start of program list reached.")
					return
				return  # Exit early since load and play are already called

	load_track(current_track_index)
	$AudioStreamPlayer.play()
	update_track_visibility()

func _on_seek_backward_button_button_down():
	seeking_backward = true

func _on_seek_backward_button_button_up():
	seeking_backward = false

func _on_seek_forward_button_button_down():
	seeking_forward = true

func _on_seek_forward_button_button_up():
	seeking_forward = false

func _on_audio_stream_player_finished():
	if repeat_mode == RepeatMode.REPEAT_ONE:
		load_track(current_track_index)
		$AudioStreamPlayer.play()
	else:
		_on_next_button_pressed()
	update_track_visibility()

func _on_time_button_pressed():
	time_mode = (time_mode + 1) % TimeMode.size() as TimeMode
	update_elapsed_time_label()
	$time_remaining_orb.visible = (time_mode != TimeMode.ELAPSED)

func _on_repeat_button_pressed():
	repeat_mode = ((repeat_mode + 1) % RepeatMode.size()) as RepeatMode
	update_repeat_label()

func update_repeat_label():
	match repeat_mode:
		RepeatMode.NO_REPEAT:
			print("NO REPEAT")
		RepeatMode.REPEAT_ONE:
			print("REPEAT ONE")
		RepeatMode.REPEAT_ALL:
			print("REPEAT ALL")

func get_total_remaining_time() -> float:
	var total_remaining_time = 0.0

	if current_playback_mode == PlaybackMode.PROGRAM:
		for i in range(current_program_position, program_list.size()):
			var track_idx = program_list[i]
			if track_idx < track_durations.size():
				total_remaining_time += track_durations[track_idx]
	elif current_playback_mode == PlaybackMode.SHUFFLE:
		for i in range(current_shuffle_index + 1, shuffle_order.size()):
			var track_idx = shuffle_order[i]
			if track_idx not in played_tracks and track_idx < track_durations.size():
				total_remaining_time += track_durations[track_idx]
	else:
		for i in range(current_track_index, track_durations.size()):
			total_remaining_time += track_durations[i]

	return total_remaining_time

func get_track_duration(path: String) -> float:
	var music_stream = load_mp3(path)
	if music_stream:
		return music_stream.get_length()
	return -1

func _on_shuffle_button_pressed():
	if current_playback_mode != PlaybackMode.SHUFFLE:
		current_playback_mode = PlaybackMode.SHUFFLE
		shuffle_order = range(track_files.size())
		shuffle_order.shuffle()
		played_tracks.clear()
		shuffle_history.clear()
		current_shuffle_index = 0
		current_track_index = shuffle_order[current_shuffle_index]
		shuffle_history.append(current_track_index)
		played_tracks.append(current_track_index)
		
		load_track(current_track_index)
		$AudioStreamPlayer.play()
	else:
		current_playback_mode = PlaybackMode.NORMAL
		played_tracks.clear()
	
	print("Shuffle mode: ", current_playback_mode == PlaybackMode.SHUFFLE)
	update_track_visibility()

func get_next_shuffle_track() -> int:
	if played_tracks.size() >= track_files.size():
		if repeat_mode == RepeatMode.REPEAT_ALL:
			played_tracks.clear()
			shuffle_order.shuffle()
			current_shuffle_index = -1
		else:
			print("All tracks have been played in shuffle mode.")
			return -1

	current_shuffle_index += 1
	if current_shuffle_index >= shuffle_order.size():
		shuffle_order.shuffle()
		current_shuffle_index = 0

	var next_track = shuffle_order[current_shuffle_index]
	while next_track in played_tracks:
		current_shuffle_index += 1
		if current_shuffle_index >= shuffle_order.size():
			shuffle_order.shuffle()
			current_shuffle_index = 0
		next_track = shuffle_order[current_shuffle_index]
	
	shuffle_history.append(next_track)
	return next_track

func _on_program_button_pressed():
	if current_playback_mode != PlaybackMode.PROGRAM:
		current_playback_mode = PlaybackMode.PROGRAM
		program_list.clear()
		current_program_position = 0  # Reset position
		update_track_visibility()
		print("Program mode activated")
	else:
		current_playback_mode = PlaybackMode.NORMAL
		program_list.clear()
		update_track_visibility()
		print("Normal mode")

func add_to_program_list(track_index: int):
	# Allow duplicates in program list
	program_list.append(track_index)
	update_track_visibility()
	print("Program list: ", program_list)

func _on_continue_button_pressed():
	current_playback_mode = PlaybackMode.NORMAL
	repeat_mode = RepeatMode.NO_REPEAT

	var currently_playing_track = track_files[current_track_index]
	current_track_index = original_order.find(currently_playing_track)

	update_elapsed_time_label()
	update_track_visibility()

func _on_exit_button_pressed():
	get_tree().quit()

func _input(_event):
	if Input.is_action_just_pressed("ui_select"):
		$VisualiserLayer/VisualiserRect.visible = !$VisualiserLayer/VisualiserRect.visible

func _on_track_button_pressed(track_number: int):
	var track_index = track_number - 1

	if track_index < track_files.size():
		if current_playback_mode == PlaybackMode.PROGRAM:
			# In program mode, add track to program list (allow duplicates)
			add_to_program_list(track_index)
		else:
			# In normal or shuffle mode, play the track directly
			current_track_index = track_index
			load_track(current_track_index)
			$AudioStreamPlayer.play()
			update_track_visibility()
	else:
		print("No track loaded at this position.")
