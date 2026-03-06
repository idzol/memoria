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

const MUSIC_PATH = "res://assets/music/"
const SFX_PATH = "res://assets/sfx/"

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

func _on_music_change_requested(track_id: String, fade_time: float = 2.0):
	var actual_id = AudioData.get_track_id(track_id)
	
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
	fade_in.tween_property(music_player_base, "volume_db", 0.0, fade_time)
	
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
	
	# FIX: Prevent NaN/Inf errors by ensuring a minimum value before db conversion
	# linear_to_db(0) returns -inf, which breaks Tweens using TRANS_SINE
	var target_db = linear_to_db(max(intensity, 0.0001))
	if target_db < -79.0: target_db = -80.0
	
	var tween = create_tween()
	tween.tween_property(music_player_perc, "volume_db", target_db, 0.8).set_trans(Tween.TRANS_SINE)

func _on_sfx_triggered(sfx_id: String):
	var actual_sfx = AudioData.get_sfx_id(sfx_id)
	var path = SFX_PATH + actual_sfx + ".wav"
	
	if not FileAccess.file_exists(path):
		return
		
	var sfx_stream = load(path)
	if sfx_stream:
		var temp_player = AudioStreamPlayer.new()
		add_child(temp_player)
		temp_player.stream = sfx_stream
		temp_player.bus = "SFX"
		temp_player.play()
		temp_player.finished.connect(temp_player.queue_free)
