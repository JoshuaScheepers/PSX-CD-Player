extends Node2D

var track_files = []
var current_track_index = 0
var previous_track_index = 0

enum TimeMode { ELAPSED, REMAINING_TRACK, REMAINING_TOTAL }
var time_mode := TimeMode.ELAPSED
var track_durations := []

enum RepeatMode { NO_REPEAT, REPEAT_ONE, REPEAT_ALL }
var repeat_mode := RepeatMode.NO_REPEAT
var original_order = []

var shuffle = false

var seeking_forward = false
var seeking_backward = false
var seek_speed = 4

var shader_time = 0.0

func _ready():
	$playbackButtons/play_button.grab_focus()
	assign_tracks()
	populate_tracks()
	original_order = track_files.duplicate()
	calculate_track_durations()
	update_track_visibility()

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
	$cursor.global_position = focused_node.global_position + (focused_node.size * 0.5)

func populate_tracks():
	track_files.clear()
	track_durations.clear()
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
				track_durations.append(get_track_duration(full_path))
			file_name = external_music_directory.get_next()
		external_music_directory.list_dir_end()
	else:
		print("Default playlist loaded")
		var default_tracks = [
			"res://Music/01 - Opening the Portal.mp3",
			"res://Music/02 - Liminal Phasing.mp3",
			"res://Music/03 - Megadalene.mp3",
			"res://Music/04 - Closing The Portal (Avec Batterie).mp3"
		]
		for track_path in default_tracks:
			track_files.append(track_path)
			track_durations.append(get_track_duration(track_path))

	setup_tracks_after_loading()

func setup_tracks_after_loading():
	if track_files.size() > 0:
		load_track(0)
		$AudioStreamPlayer.stop()

func assign_tracks():
	var button_index = 1
	for button in get_tree().get_nodes_in_group("track_buttons"):
		var callable = Callable(self, "_on_track_button_pressed").bind(button_index)
		button.connect("pressed", callable)
		button_index += 1

func load_track(track_index: int):
	var track_list = track_files
	if track_index >= track_list.size():
		print("Track index out of range.")
		return

	var track_path = track_list[track_index]
	var stream = load_mp3(track_path)
	if stream:
		$AudioStreamPlayer.stream = stream
		update_current_track_label()
	else:
		print("Failed to load stream for track: ", track_path)

func load_mp3(path: String) -> AudioStream:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var sound = AudioStreamMP3.new()
		sound.data = file.get_buffer(file.get_length())
		file.close()
		return sound
	else:
		print("Failed to load MP3: ", path)
		return null

func update_track_visibility():
	var track_buttons = get_tree().get_nodes_in_group("track_buttons")
	# Loop through each button and corresponding orb and label
	for i in range(track_buttons.size()):
		var track_button = track_buttons[i]
		var orb_name = "track_%02d_orb" % (i + 1)
		var orb_label_name = "track_%02d_orb_label" % (i + 1)

		var orb = track_button.get_node_or_null(orb_name)
		var orb_label = track_button.get_node_or_null(orb_label_name)

		if orb:
			orb.visible = i < track_files.size()  # Make orb visible if its index is less than the number of tracks loaded
		if orb_label:
			orb_label.visible = i < track_files.size()  # Similarly for the label

func update_current_track_label():
	var original_index = original_order.find(track_files[current_track_index])
	$current_track_label.text = str(original_index + 1)

func update_elapsed_time_label():
	var elapsed_time = 0.0
	if $AudioStreamPlayer.is_playing():
		elapsed_time = $AudioStreamPlayer.get_playback_position()

	var remaining_track_time = 0.0
	var total_time = get_total_remaining_time()

	var minutes = 0
	var seconds = 0

	if $AudioStreamPlayer.stream and $AudioStreamPlayer.stream.get_length() > 0:
		remaining_track_time = $AudioStreamPlayer.stream.get_length() - elapsed_time
		minutes = int(remaining_track_time / 60)
		seconds = int(remaining_track_time) % 60
	else:
		print("Stream is not loaded or is invalid.")

	match time_mode:
		TimeMode.ELAPSED:
			minutes = int(elapsed_time / 60)
			seconds = int(elapsed_time) % 60
		TimeMode.REMAINING_TRACK:
			pass
		TimeMode.REMAINING_TOTAL:
			total_time -= elapsed_time
			minutes = int(total_time / 60)
			seconds = int(total_time) % 60

	$time_label.text = "%02d        %02d" % [minutes, seconds]

func _on_next_button_pressed():
	previous_track_index = current_track_index

	turn_off_orb_for_finished_track(current_track_index)

	if current_track_index < (track_files.size()) - 1:
		current_track_index += 1
	else:
		if repeat_mode == RepeatMode.REPEAT_ALL:
			current_track_index = 0
		else:
			print("End of track list reached.")

	load_track(current_track_index)
	$AudioStreamPlayer.play()

	turn_on_orb_for_current_track(current_track_index)

func _on_previous_button_pressed():
	var current_position = $AudioStreamPlayer.get_playback_position()
	if current_position > 3.0:
		$AudioStreamPlayer.seek(0)
	else:
		if current_track_index > 0:
			previous_track_index = current_track_index
			current_track_index -= 1
		else:
			print("Start of track list reached.")

	load_track(current_track_index)
	$AudioStreamPlayer.play()

	turn_on_orb_for_current_track(current_track_index)

func _on_play_button_pressed():
	if not $AudioStreamPlayer.is_playing():
		load_track(current_track_index)
		$AudioStreamPlayer.play()

func _on_stop_button_pressed():
	$AudioStreamPlayer.stop()
	$time_label.text = "00        00"

func _on_pause_button_pressed():
	$AudioStreamPlayer.stream_paused = !$AudioStreamPlayer.stream_paused

func _on_seek_backward_button_button_down():
	seeking_backward = true

func _on_seek_backward_button_button_up():
	seeking_backward = false

func _on_seek_forward_button_button_down():
	seeking_forward = true

func _on_seek_forward_button_button_up():
	seeking_forward = false

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

func turn_off_orb_for_finished_track(track_index):
	var node_path = "trackNumbers/track_%02d_button/track_%02d_orb" % [track_index + 1, track_index + 1]
	var orb = get_node_or_null(node_path)
	orb.visible = false
	
func turn_on_orb_for_previous_track(track_index):
	var node_path = "trackNumbers/track_%02d_button/track_%02d_orb" % [track_index + 1, track_index + 1]
	var orb = get_node_or_null(node_path)
	orb.visible = true
	
func turn_on_orb_for_current_track(track_index):
	var node_path = "trackNumbers/track_%02d_button/track_%02d_orb" % [track_index + 1, track_index + 1]
	var orb = get_node_or_null(node_path)
	orb.visible = true  # Ensure the orb is visible for the current track

func _on_audio_stream_player_finished():
	var finished_track_index = current_track_index  # Save the current track index

	if repeat_mode == RepeatMode.REPEAT_ONE:
		load_track(finished_track_index)
		$AudioStreamPlayer.play()
	else:
		_on_next_button_pressed()  # Move to the next track
		
	turn_off_orb_for_finished_track(finished_track_index)  # Turn off orb after the next track is loaded

func _on_time_button_pressed():
	time_mode = (time_mode + 1) % TimeMode.size() as TimeMode
	update_elapsed_time_label()
	$time_remaining_orb.visible = (time_mode != TimeMode.ELAPSED)

func get_total_remaining_time() -> float:
	var total_remaining_time = 0.0
	if track_durations.size() == 0:
		return total_remaining_time

	for i in range(current_track_index, track_durations.size()):
		total_remaining_time += track_durations[i]

	return total_remaining_time

func calculate_track_durations():
	track_durations.clear()
	for track_path in track_files:
		var duration = get_track_duration(track_path)
		if duration >= 0:
			track_durations.append(duration)
		else:
			track_durations.append(0)

func get_track_duration(path: String) -> float:
	var music_stream = load_mp3(path)
	if music_stream:
		return music_stream.get_length()
	return -1

func _on_continue_button_pressed():
	repeat_mode = RepeatMode.NO_REPEAT

	var currently_playing_track = track_files[current_track_index]
	current_track_index = original_order.find(currently_playing_track)

	track_files = original_order.duplicate()

	update_elapsed_time_label()

func _on_exit_button_pressed():
	get_tree().quit()

func _input(_event):
	if Input.is_action_just_pressed("ui_select"):
		$VisualiserLayer/VisualiserRect.visible = !$VisualiserLayer/VisualiserRect.visible

func _on_track_button_pressed(track_number: int):
	current_track_index = track_number - 1
	load_track(current_track_index)
	$AudioStreamPlayer.play()

func _on_shuffle_button_pressed() -> void:
	if shuffle == false:
		shuffle = true
		track_files.shuffle()
	elif shuffle == true:
		shuffle = false
		track_files = original_order.duplicate()
	
	print(shuffle)
