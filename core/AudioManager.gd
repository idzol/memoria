# [YOLO-METADATA] TARGET: res://core/AudioManager.gd
# [AI-CONTRACT]
# FILE: res://core/AudioManager.gd
# FEATURES: Music cross-fading, Battle Intensity percussion layering, SFX management.

extends Node
# class_name AudioManager

# [CORE-008] Dynamic Audio Manager Implementation
# Manages music logic and layering. Assets resolved via AudioData.gd

@onready var music_player_a = AudioStreamPlayer.new()
@onready var music_player_b = AudioStreamPlayer.new()
@onready var music_player_perc = AudioStreamPlayer.new()
@onready var sfx_player = AudioStreamPlayer.new()

const MUSIC_PATH = "res://assets/music/"
const SFX_PATH = "res://assets/sfx/"
const AudioSettingsScript = preload("res://core/AudioSettings.gd")
const SETTINGS_PATH = AudioSettingsScript.SETTINGS_PATH
const SETTINGS_SECTION_AUDIO = AudioSettingsScript.SETTINGS_SECTION_AUDIO
const AudioDataScript = preload("res://core/AudioData.gd")
const DEFAULT_AMBIENT_FADE_TIME := 3.0
const DEFAULT_AMBIENT_LOOP_DELAY := 0.0
const DEFAULT_AMBIENT_OVERLAP_SECONDS := -2.0

var current_track_id: String = ""
var intensity: float = 0.0
var global_master_volume: float = AudioSettingsScript.DEFAULT_MASTER_VOLUME
var global_music_volume: float = AudioSettingsScript.DEFAULT_MUSIC_VOLUME
var global_sfx_volume: float = AudioSettingsScript.DEFAULT_SFX_VOLUME
var queued_followup_track_id: String = ""
var queued_followup_fade_time: float = 2.0
var ambient_loop_delay_seconds: float = DEFAULT_AMBIENT_LOOP_DELAY
var track_playback_positions: Dictionary = {}

var _ambient_overlap_request_id: int = 0
var _active_music_player_index: int = -1
var _music_player_track_ids: Array[String] = ["", ""]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player_a)
	add_child(music_player_b)
	add_child(music_player_perc)
	add_child(sfx_player)

	music_player_a.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player_b.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player_perc.process_mode = Node.PROCESS_MODE_ALWAYS
	sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	music_player_a.bus = "Music"
	music_player_b.bus = "Music"
	music_player_perc.bus = "Percussion" 
	sfx_player.bus = "SFX"
	
	SignalBus.music_change_requested.connect(_on_music_change_requested)
	SignalBus.battle_intensity_changed.connect(_on_battle_intensity_changed)
	SignalBus.sfx_triggered.connect(_on_sfx_triggered)
	
	music_player_a.finished.connect(_on_music_player_finished.bind(0))
	music_player_b.finished.connect(_on_music_player_finished.bind(1))
	music_player_a.volume_db = -80.0
	music_player_b.volume_db = -80.0
	music_player_perc.volume_db = -80.0
	
	# Safety check: Ensure buses are not muted in the project's default state
	for bus_name in ["Master", "Music", "SFX"]:
		var idx = AudioServer.get_bus_index(bus_name)
		if idx != -1 and AudioServer.is_bus_mute(idx):
			AudioServer.set_bus_mute(idx, false)
	
	_load_audio_settings()
	_apply_all_global_volumes()

func set_master_volume(value: float):
	global_master_volume = clamp(value, 0.0, 1.0)
	_apply_all_global_volumes()
	_save_audio_settings()

func set_music_volume(value: float):
	global_music_volume = clamp(value, 0.0, 1.0)
	_apply_all_global_volumes()
	_save_audio_settings()

func set_sfx_volume(value: float):
	global_sfx_volume = clamp(value, 0.0, 1.0)
	_apply_all_global_volumes()
	_save_audio_settings()

func get_master_volume() -> float:
	return global_master_volume

func get_music_volume() -> float:
	return global_music_volume

func get_sfx_volume() -> float:
	return global_sfx_volume

func _apply_all_global_volumes():
	# Final effective levels are derived from master * channel volume.
	var effective_music = global_master_volume * global_music_volume
	var effective_sfx = global_master_volume * global_sfx_volume
	
	# Keep master at unity so channel buses receive the computed effective levels.
	_apply_bus_volume("Master", 1.0)
	_apply_bus_volume("Music", effective_music)
	_apply_bus_volume("Percussion", effective_music)
	_apply_bus_volume("SFX", effective_sfx)
	_apply_runtime_player_volumes()

func _apply_runtime_player_volumes():
	var sfx_db = _to_db(global_master_volume * global_sfx_volume)
	for player_index in range(_music_player_track_ids.size()):
		var player: AudioStreamPlayer = _get_music_player(player_index)
		if is_instance_valid(player) and player.playing:
			player.volume_db = _get_track_target_volume_db(_music_player_track_ids[player_index])
	if is_instance_valid(music_player_perc):
		var music_db = _to_db(global_master_volume * global_music_volume)
		# Percussion still gets intensity layering on top, but base loudness follows music scaling.
		music_player_perc.volume_db = music_db if intensity <= 0.0 else _to_db((global_master_volume * global_music_volume) * intensity)
	if is_instance_valid(sfx_player):
		sfx_player.volume_db = sfx_db

func _load_audio_settings():
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_PATH)
	var defaults: Dictionary = AudioSettingsScript.get_default_audio_settings()
	if err != OK:
		global_master_volume = clamp(float(defaults.get("master_volume", global_master_volume)), 0.0, 1.0)
		global_music_volume = clamp(float(defaults.get("music_volume", global_music_volume)), 0.0, 1.0)
		global_sfx_volume = clamp(float(defaults.get("sfx_volume", global_sfx_volume)), 0.0, 1.0)
		return
	global_master_volume = clamp(float(cfg.get_value(SETTINGS_SECTION_AUDIO, "master_volume", defaults.get("master_volume", global_master_volume))), 0.0, 1.0)
	global_music_volume = clamp(float(cfg.get_value(SETTINGS_SECTION_AUDIO, "music_volume", defaults.get("music_volume", global_music_volume))), 0.0, 1.0)
	global_sfx_volume = clamp(float(cfg.get_value(SETTINGS_SECTION_AUDIO, "sfx_volume", defaults.get("sfx_volume", global_sfx_volume))), 0.0, 1.0)

func _save_audio_settings():
	var cfg = ConfigFile.new()
	cfg.set_value(SETTINGS_SECTION_AUDIO, "master_volume", global_master_volume)
	cfg.set_value(SETTINGS_SECTION_AUDIO, "music_volume", global_music_volume)
	cfg.set_value(SETTINGS_SECTION_AUDIO, "sfx_volume", global_sfx_volume)
	var err = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("AudioManager: Failed to save audio settings to " + SETTINGS_PATH)

func _apply_bus_volume(bus_name: String, linear_volume: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	AudioServer.set_bus_volume_db(bus_idx, _to_db(linear_volume))

func _to_db(linear_volume: float) -> float:
	var v = clamp(linear_volume, 0.0, 1.0)
	if v <= 0.0001:
		return -80.0
	return linear_to_db(v)

func _on_music_change_requested(track_id: String, fade_time: float = 2.0):
	if track_id == "":
		_fade_out_to_silence(fade_time)
		return
	_play_music_track(track_id, fade_time, false)

func _fade_out_to_silence(fade_time: float = 2.0):
	_ambient_overlap_request_id += 1
	queued_followup_track_id = ""
	queued_followup_fade_time = DEFAULT_AMBIENT_FADE_TIME
	ambient_loop_delay_seconds = DEFAULT_AMBIENT_LOOP_DELAY

	var had_active_music := _has_active_music_player()
	if had_active_music and _is_valid_music_player_index(_active_music_player_index):
		var active_track_id: String = _music_player_track_ids[_active_music_player_index]
		if active_track_id != "":
			_store_track_position(active_track_id, _active_music_player_index)

	var fade_out = create_tween().set_parallel(true)
	for player_index in range(_music_player_track_ids.size()):
		var player: AudioStreamPlayer = _get_music_player(player_index)
		var track_id: String = _music_player_track_ids[player_index]
		if player == null or not player.playing:
			continue
		var fade = fade_out.tween_property(player, "volume_db", -80.0, fade_time)
		fade.set_trans(Tween.TRANS_EXPO if _is_ambient_track(track_id) else Tween.TRANS_SINE)
		fade.set_ease(Tween.EASE_IN)
	if is_instance_valid(music_player_perc) and music_player_perc.playing:
		var perc_fade = fade_out.tween_property(music_player_perc, "volume_db", -80.0, fade_time)
		perc_fade.set_trans(Tween.TRANS_SINE)
		perc_fade.set_ease(Tween.EASE_IN)

	if had_active_music or (is_instance_valid(music_player_perc) and music_player_perc.playing):
		await fade_out.finished
	_stop_music_to_silence()

func _play_music_track(track_id: String, fade_time: float = 2.0, allow_same_track_restart: bool = false):
	var actual_id: String = AudioDataScript.get_track_id(track_id)
	if actual_id == current_track_id and _has_active_music_player() and not allow_same_track_restart:
		return

	_ambient_overlap_request_id += 1
	queued_followup_track_id = ""
	queued_followup_fade_time = DEFAULT_AMBIENT_FADE_TIME
	ambient_loop_delay_seconds = DEFAULT_AMBIENT_LOOP_DELAY
	
	# Attempt to load layered version first, then fallback to standard
	var base_stream = load(MUSIC_PATH + actual_id + ".ogg")
	
	# var perc_stream = load(MUSIC_PATH + actual_id + "_perc.ogg")
	
	if not base_stream:
		push_warning("Audio: Could not load track " + actual_id + " at " + MUSIC_PATH)
		return

	var is_target_ambient: bool = _is_ambient_track(actual_id)
	var source_index: int = _active_music_player_index
	var target_index: int = _get_target_music_player_index()
	var source_track_id: String = ""
	var source_player: AudioStreamPlayer = null
	if _is_valid_music_player_index(source_index):
		source_track_id = _music_player_track_ids[source_index]
		source_player = _get_music_player(source_index)
		if _is_music_player_active(source_index):
			_store_track_position(source_track_id, source_index)
		else:
			source_index = -1
			source_track_id = ""
			source_player = null

	var target_player: AudioStreamPlayer = _get_music_player(target_index)
	if target_player == null:
		return

	target_player.stop()
	target_player.stream = base_stream
	target_player.volume_db = -80.0
	target_player.bus = "SFX" if is_target_ambient else "Music"
	_music_player_track_ids[target_index] = actual_id
	
	# Ambient replay is handled manually so we can apply a delay between loops.
	if base_stream is AudioStreamOggVorbis:
		base_stream.loop = _should_loop_track(actual_id)

	var followup_id = _get_followup_track_id(actual_id)
	if followup_id != "":
		queued_followup_track_id = followup_id
		queued_followup_fade_time = DEFAULT_AMBIENT_FADE_TIME
		_schedule_ambient_followup_overlap(actual_id, followup_id, queued_followup_fade_time, base_stream)
	elif is_target_ambient:
		_schedule_ambient_self_overlap(actual_id, DEFAULT_AMBIENT_FADE_TIME, base_stream)
	
	var resume_position: float = 0.0 if allow_same_track_restart else _consume_saved_track_position(actual_id)
	target_player.play(resume_position)
	_active_music_player_index = target_index
	current_track_id = actual_id
	
	# Fade In
	var fade_in = create_tween().set_parallel(true)
	var base_fade_in = fade_in.tween_property(target_player, "volume_db", _get_track_target_volume_db(actual_id), fade_time)
	base_fade_in.set_trans(Tween.TRANS_EXPO if is_target_ambient else Tween.TRANS_SINE)
	base_fade_in.set_ease(Tween.EASE_OUT)

	if source_player != null:
		_fade_out_and_reset_music_player(source_index, source_track_id, fade_time)
	
	# Sync percussion to current intensity
	_on_battle_intensity_changed(intensity)

func _on_music_player_finished(player_index: int):
	if not _is_valid_music_player_index(player_index):
		return
	var finished_track_id: String = _music_player_track_ids[player_index]
	if finished_track_id == "":
		return
	_clear_saved_track_position(finished_track_id)
	_reset_music_player(player_index)
	if player_index != _active_music_player_index or current_track_id != finished_track_id:
		return

	if queued_followup_track_id != "":
		var followup_id = queued_followup_track_id
		var followup_fade = queued_followup_fade_time
		queued_followup_track_id = ""
		queued_followup_fade_time = DEFAULT_AMBIENT_FADE_TIME
		_play_music_track(followup_id, followup_fade, false)
		return

	if current_track_id.ends_with("_ambient"):
		var ambient_track_id: String = current_track_id
		await get_tree().create_timer(ambient_loop_delay_seconds).timeout
		if current_track_id == ambient_track_id and not _is_music_player_active(player_index):
			_play_music_track(ambient_track_id, DEFAULT_AMBIENT_FADE_TIME, true)
		return

	_stop_music_to_silence()

func _should_loop_track(track_id: String) -> bool:
	return track_id == AudioDataScript.TRACKS["CREDITS"]

func _get_followup_track_id(track_id: String) -> String:
	if track_id.ends_with("_ambient"):
		return ""
	return AudioDataScript.get_ambient_track_id(track_id)

func _is_ambient_track(track_id: String) -> bool:
	return track_id.ends_with("_ambient")

func _schedule_ambient_followup_overlap(track_id: String, followup_id: String, fade_time: float, base_stream: Resource):
	var request_id: int = _ambient_overlap_request_id
	var track_length: float = _get_stream_length_seconds(base_stream)
	var overlap_offset: float = abs(DEFAULT_AMBIENT_OVERLAP_SECONDS)
	if track_length <= overlap_offset:
		return
	var overlap_delay: float = max(0.0, track_length - overlap_offset)
	_run_ambient_followup_overlap(request_id, track_id, followup_id, fade_time, overlap_delay)

func _run_ambient_followup_overlap(request_id: int, track_id: String, followup_id: String, fade_time: float, overlap_delay: float) -> void:
	await get_tree().create_timer(overlap_delay, true).timeout
	if request_id != _ambient_overlap_request_id:
		return
	if current_track_id != track_id:
		return
	if queued_followup_track_id != followup_id:
		return
	queued_followup_track_id = ""
	queued_followup_fade_time = DEFAULT_AMBIENT_FADE_TIME
	_play_music_track(followup_id, fade_time, false)

func _schedule_ambient_self_overlap(track_id: String, fade_time: float, base_stream: Resource):
	var request_id: int = _ambient_overlap_request_id
	var track_length: float = _get_stream_length_seconds(base_stream)
	var overlap_offset: float = abs(DEFAULT_AMBIENT_OVERLAP_SECONDS)
	if track_length <= overlap_offset:
		return
	var overlap_delay: float = max(0.0, track_length - overlap_offset)
	_run_ambient_self_overlap(request_id, track_id, fade_time, overlap_delay)

func _run_ambient_self_overlap(request_id: int, track_id: String, fade_time: float, overlap_delay: float) -> void:
	await get_tree().create_timer(overlap_delay, true).timeout
	if request_id != _ambient_overlap_request_id:
		return
	if current_track_id != track_id:
		return
	if not _has_active_music_player():
		return
	_play_music_track(track_id, fade_time, true)

func _get_stream_length_seconds(stream: Resource) -> float:
	if stream == null:
		return 0.0
	if stream.has_method("get_length"):
		return max(0.0, float(stream.get_length()))
	return 0.0

func _stop_music_to_silence():
	current_track_id = ""
	queued_followup_track_id = ""
	queued_followup_fade_time = DEFAULT_AMBIENT_FADE_TIME
	_active_music_player_index = -1
	for index in range(_music_player_track_ids.size()):
		_reset_music_player(index)
	if is_instance_valid(music_player_perc):
		music_player_perc.stop()
		music_player_perc.stream = null
		music_player_perc.volume_db = -80.0

func _store_track_position(track_id: String, player_index: int):
	if track_id == "":
		return
	var player: AudioStreamPlayer = _get_music_player(player_index)
	if player == null:
		return
	var playback_position = max(0.0, player.get_playback_position())
	track_playback_positions[track_id] = playback_position

func _consume_saved_track_position(track_id: String) -> float:
	if track_id == "" or not track_playback_positions.has(track_id):
		return 0.0
	var playback_position = float(track_playback_positions.get(track_id, 0.0))
	return max(0.0, playback_position)

func _clear_saved_track_position(track_id: String):
	if track_id == "":
		return
	track_playback_positions.erase(track_id)

func _get_track_target_volume_db(track_id: String) -> float:
	if _is_ambient_track(track_id):
		return _to_db(global_master_volume * global_sfx_volume)
	return _to_db(global_master_volume * global_music_volume)

func _fade_out_and_reset_music_player(player_index: int, expected_track_id: String, fade_time: float) -> void:
	var player: AudioStreamPlayer = _get_music_player(player_index)
	if player == null:
		return
	var is_ambient: bool = _is_ambient_track(expected_track_id)
	var fade_out = create_tween()
	var fade = fade_out.tween_property(player, "volume_db", -80.0, fade_time)
	fade.set_trans(Tween.TRANS_EXPO if is_ambient else Tween.TRANS_SINE)
	fade.set_ease(Tween.EASE_IN)
	await fade_out.finished
	if not _is_valid_music_player_index(player_index):
		return
	if _music_player_track_ids[player_index] != expected_track_id:
		return
	_reset_music_player(player_index)

func _reset_music_player(player_index: int):
	var player: AudioStreamPlayer = _get_music_player(player_index)
	if player == null:
		return
	player.stop()
	player.stream = null
	player.volume_db = -80.0
	_music_player_track_ids[player_index] = ""

func _get_music_players() -> Array[AudioStreamPlayer]:
	return [music_player_a, music_player_b]

func _get_music_player(player_index: int) -> AudioStreamPlayer:
	var players: Array[AudioStreamPlayer] = _get_music_players()
	if player_index < 0 or player_index >= players.size():
		return null
	return players[player_index]

func _is_valid_music_player_index(player_index: int) -> bool:
	return player_index >= 0 and player_index < _music_player_track_ids.size()

func _is_music_player_active(player_index: int) -> bool:
	var player: AudioStreamPlayer = _get_music_player(player_index)
	return player != null and player.playing

func _has_active_music_player() -> bool:
	return _is_music_player_active(_active_music_player_index)

func _get_target_music_player_index() -> int:
	if not _has_active_music_player():
		return _active_music_player_index if _is_valid_music_player_index(_active_music_player_index) else 0
	return 1 - _active_music_player_index

func _on_battle_intensity_changed(new_intensity: float):
	intensity = clamp(new_intensity, 0.0, 1.0)
	
	var effective_perc = (global_master_volume * global_music_volume) * intensity
	var target_db = _to_db(effective_perc)
	
	var tween = create_tween()
	tween.tween_property(music_player_perc, "volume_db", target_db, 0.8).set_trans(Tween.TRANS_SINE)

func _on_sfx_triggered(sfx_id: String):
	var actual_sfx = AudioDataScript.get_sfx_id(sfx_id)
	var path = SFX_PATH + actual_sfx + ".wav"
	
	if not FileAccess.file_exists(path):
		return
		
	var sfx_stream = load(path)
	if sfx_stream:
		var temp_player = AudioStreamPlayer.new()
		add_child(temp_player)
		temp_player.stream = sfx_stream
		temp_player.bus = "SFX"
		temp_player.volume_db = _to_db(global_master_volume * global_sfx_volume)
		temp_player.play()
		temp_player.finished.connect(temp_player.queue_free)
