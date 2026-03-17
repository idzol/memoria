# [YOLO-METADATA] TARGET: res://core/AudioManager.gd
# [AI-CONTRACT]
# FILE: res://core/AudioManager.gd
# FEATURES: Music cross-fading, Battle Intensity percussion layering, SFX management.

extends Node
# class_name AudioManager

# [CORE-008] Dynamic Audio Manager Implementation
# Manages music logic and layering. Assets resolved via AudioData.gd

@onready var music_player_base = AudioStreamPlayer.new()
@onready var music_player_perc = AudioStreamPlayer.new() 
@onready var sfx_player = AudioStreamPlayer.new()

var current_track_id: String = ""
var intensity: float = 0.0
var global_master_volume: float = 1.0
var global_music_volume: float = 1.0
var global_sfx_volume: float = 1.0

const MUSIC_PATH = "res://assets/music/"
const SFX_PATH = "res://assets/sfx/"
const SETTINGS_PATH = "user://settings.cfg"
const SETTINGS_SECTION_AUDIO = "audio"
const AudioDataScript = preload("res://core/AudioData.gd")

func _ready():
	add_child(music_player_base)
	add_child(music_player_perc)
	add_child(sfx_player)
	
	music_player_base.bus = "Music"
	music_player_perc.bus = "Percussion" 
	sfx_player.bus = "SFX"
	
	SignalBus.music_change_requested.connect(_on_music_change_requested)
	SignalBus.battle_intensity_changed.connect(_on_battle_intensity_changed)
	SignalBus.sfx_triggered.connect(_on_sfx_triggered)
	
	music_player_base.finished.connect(_on_track_finished)
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
	var music_db = _to_db(global_master_volume * global_music_volume)
	var sfx_db = _to_db(global_master_volume * global_sfx_volume)
	if is_instance_valid(music_player_base):
		music_player_base.volume_db = music_db
	if is_instance_valid(music_player_perc):
		# Percussion still gets intensity layering on top, but base loudness follows music scaling.
		music_player_perc.volume_db = music_db if intensity <= 0.0 else _to_db((global_master_volume * global_music_volume) * intensity)
	if is_instance_valid(sfx_player):
		sfx_player.volume_db = sfx_db

func _load_audio_settings():
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	global_master_volume = clamp(float(cfg.get_value(SETTINGS_SECTION_AUDIO, "master_volume", global_master_volume)), 0.0, 1.0)
	global_music_volume = clamp(float(cfg.get_value(SETTINGS_SECTION_AUDIO, "music_volume", global_music_volume)), 0.0, 1.0)
	global_sfx_volume = clamp(float(cfg.get_value(SETTINGS_SECTION_AUDIO, "sfx_volume", global_sfx_volume)), 0.0, 1.0)

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
	var actual_id = AudioDataScript.get_track_id(track_id)
	
	if actual_id == current_track_id: return
	
	# Attempt to load layered version first, then fallback to standard
	var base_stream = load(MUSIC_PATH + actual_id + ".ogg")
	
	# var perc_stream = load(MUSIC_PATH + actual_id + "_perc.ogg")
	
	if not base_stream:
		push_warning("Audio: Could not load track " + actual_id + " at " + MUSIC_PATH)
		return
		
	# Skip fade-out wait if this is the first track
	if current_track_id != "":
		var fade_out = create_tween().set_parallel(true)
		fade_out.tween_property(music_player_base, "volume_db", -80.0, fade_time)
		fade_out.tween_property(music_player_perc, "volume_db", -80.0, fade_time)
		await fade_out.finished
	
	current_track_id = actual_id
	music_player_base.stream = base_stream
	# music_player_perc.stream = perc_stream
	
	# Set looping
	if base_stream is AudioStreamOggVorbis:
		base_stream.loop = actual_id.ends_with("_ambient") or actual_id.contains("menu")
	
	music_player_base.volume_db = -80.0
	music_player_base.play()
	
	if music_player_perc.stream:
		music_player_perc.volume_db = -80.0
		music_player_perc.play()
	
	# Fade In
	var fade_in = create_tween().set_parallel(true)
	fade_in.tween_property(music_player_base, "volume_db", _to_db(global_master_volume * global_music_volume), fade_time)
	
	# Sync percussion to current intensity
	_on_battle_intensity_changed(intensity)

func _on_track_finished():
	if not current_track_id.ends_with("_ambient"):
		var ambient_id = current_track_id + "_ambient"
		if FileAccess.file_exists(MUSIC_PATH + ambient_id + ".ogg"):
			_on_music_change_requested(ambient_id, 4.0)
			return
	
	music_player_base.play()
	if music_player_perc.stream:
		music_player_perc.play()

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
