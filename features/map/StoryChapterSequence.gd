extends Control

@onready var title_label = %TitleLabel
@onready var body_label = %BodyLabel
@onready var text_viewport = %TextViewport
@onready var story_block = %StoryBlock
@onready var continue_hint = %ContinueHint
@onready var video_player: VideoStreamPlayer = %VideoPlayer
@onready var cutscene_music_player: AudioStreamPlayer = %CutsceneMusicPlayer

const SCROLL_SPEED := 30.0
const MUSIC_FADE_OUT_SECONDS := 0.45
const PRE_CHAPTER_MUSIC_FADE_OUT_SECONDS := 0.8
const DEFAULT_VIDEO_ASPECT_RATIO := 16.0 / 9.0
const VIDEO_ROOT_DIRS := [
	"res://assets/video/",
	"res://asset/video/"
]
const STORY_PLACEHOLDERS := {
	"tutorial": {
		"title": "Introduction",
		"body": "
Upon the desolate heights of the crags,
The youth did cast aside the treasures of the immortals, 
For the polished bronze had become to him as heavy stones without meaning. 
He looked upon the shield and saw only the passing of clouds,
Finding no reflection of his former purpose within its metallic depths. 
Like a traveler who sheds a heavy cloak in the heat of noon,
He abandoned the instruments of his fate against the jagged rocks, 
Choosing instead the path that led downward to the salt-spray and the common soil of men.

He descended into the village, 
Where the air was thick with the scent of drying kelp and the labor of the forge. 
There, his tools were put to the base service of the hearth and the pier, 
Its keen edge used to pry the stubborn barnacle from rotted wood. 

Dictys the fisherman looked upon the lad, 
And saw a silent drifter with eyes clouded by the mist of forgetting.
As the golden thread of destiny snapped, 
The boy stood upon the stone quay, 
Casting his line into the grey expanse, 
Knowing at last the peace of a man,
Who has traded myth for the simple hunger of the sea."
	},
	"town": {
		"title": "Town",
		"body": "Placeholder chapter text.\n\nThe town gathers fragments into pattern.\nFaces, doors, and lantern light begin to suggest a life once lived.\nSomething important was left here, and the streets seem to know it."
	},
	"forest": {
		"title": "Forest",
		"body": "Placeholder chapter text.\n\nThe forest remembers through roots and shadow.\nIt keeps old roads buried under moss, waiting for someone brave enough to listen.\nEvery clearing feels like a memory trying to return."
	},
	"ice_caves": {
		"title": "Ice Caves",
		"body": "Placeholder chapter text.\n\nThe cold preserves what fear tried to hide.\nIn the ice, silence sharpens every thought into something brittle and true.\nWhat was buried here did not stay buried by accident."
	},
	"desert": {
		"title": "Desert",
		"body": "Placeholder chapter text.\n\nThe desert strips comfort from every answer.\nHere, memory survives as heat shimmer and stubborn will.\nThe horizon keeps retreating, as if daring you to keep going."
	},
	"swamp": {
		"title": "Swamp",
		"body": "Placeholder chapter text.\n\nThe swamp does not forget.\nIt folds old choices back into the path and asks whether you can carry them this time.\nEven the still water feels like it is watching."
	},
	"abyss": {
		"title": "Abyss",
		"body": "Placeholder chapter text.\n\nBelow the last light, the world changes its rules.\nThe abyss is a place of pressure, distance, and truths that surface too late.\nStill, something in the dark is calling you deeper."
	},
	"void": {
		"title": "Void",
		"body": "Placeholder chapter text.\n\nThe void is less a place than a wound in meaning.\nShapes and names loosen here, drifting apart under unseen tides.\nTo cross it, you will need to decide what cannot be surrendered."
	},
	"the_core": {
		"title": "The Core",
		"body": "Placeholder chapter text.\n\nAt the center of all this ruin, something still burns.\nThe core holds the oldest memory and the final answer.\nWhatever waits there has been waiting for you all along."
	}
}

enum SequencePhase {
	VIDEO,
	TEXT,
	FINISHING
}

var _scroll_complete: bool = false
var _phase: SequencePhase = SequencePhase.VIDEO
var _is_finishing: bool = false
var _active_biome: String = ""

@export_range(0.1, 4.0, 0.001) var video_aspect_ratio: float = DEFAULT_VIDEO_ASPECT_RATIO

func _ready():
	if DataManager and DataManager.has_method("pause_for_cutscene"):
		DataManager.pause_for_cutscene()
	continue_hint.text = "Press any key or click to continue"
	if not resized.is_connected(_layout_story_block):
		resized.connect(_layout_story_block)
	_active_biome = GameManager.get_pending_story_sequence_biome()
	var content = STORY_PLACEHOLDERS.get(_active_biome, {
		"title": _active_biome.replace("_", " ").capitalize(),
		"body": "Placeholder chapter text."
	})
	title_label.text = str(content.get("title", "Story Chapter"))
	body_label.text = str(content.get("body", "Placeholder chapter text."))
	await _start_cutscene_video_and_music()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_fit_video_player()

func _exit_tree():
	if DataManager and DataManager.has_method("resume_after_cutscene"):
		DataManager.resume_after_cutscene()

func _process(delta: float):
	if _phase != SequencePhase.TEXT:
		return
	if _scroll_complete or not story_block or not text_viewport:
		return
	story_block.position.y -= SCROLL_SPEED * delta
	if story_block.position.y + story_block.size.y <= 0.0:
		_scroll_complete = true
		continue_hint.modulate.a = 1.0

func _input(event):
	var is_key_press = event is InputEventKey and event.pressed and not event.is_echo()
	var is_mouse_press = event is InputEventMouseButton and event.pressed
	if not (is_key_press or is_mouse_press):
		return
	match _phase:
		SequencePhase.VIDEO:
			_show_text_phase()
		SequencePhase.TEXT:
			_finish_sequence()
		_:
			return

func _layout_story_block():
	if not story_block or not text_viewport or not body_label:
		return
	var width = min(860.0, max(360.0, text_viewport.size.x - 120.0))
	story_block.custom_minimum_size.x = width
	body_label.custom_minimum_size.x = width
	await get_tree().process_frame
	var block_size = story_block.get_combined_minimum_size()
	story_block.size = block_size
	story_block.position = Vector2(
		(text_viewport.size.x - width) * 0.5,
		text_viewport.size.y
	)
	_scroll_complete = false
	continue_hint.modulate.a = 0.72

func _start_cutscene_video_and_music():
	if text_viewport:
		text_viewport.visible = false
	await _fade_out_existing_music_before_cutscene()
	if _try_play_cutscene_music():
		pass
	if not _try_play_cutscene_video():
		_show_text_phase()

func _fade_out_existing_music_before_cutscene() -> void:
	if AudioManager == null or not AudioManager.has_method("fade_out_current_music"):
		return
	await AudioManager.fade_out_current_music(PRE_CHAPTER_MUSIC_FADE_OUT_SECONDS)

func _show_text_phase():
	if _phase != SequencePhase.VIDEO:
		return
	_phase = SequencePhase.TEXT
	if video_player and video_player.is_playing():
		video_player.stop()
	if video_player:
		video_player.visible = false
	if text_viewport:
		text_viewport.visible = true
	continue_hint.text = "Press any key or click to return"
	_layout_story_block.call_deferred()

func _finish_sequence():
	if _is_finishing or not is_inside_tree():
		return
	_is_finishing = true
	_phase = SequencePhase.FINISHING
	await _fade_out_music()
	GameManager.finish_story_sequence()

func _fade_out_music() -> void:
	if cutscene_music_player == null or not cutscene_music_player.playing:
		return
	var start_volume = cutscene_music_player.volume_db
	var tween = create_tween()
	tween.tween_property(cutscene_music_player, "volume_db", -40.0, MUSIC_FADE_OUT_SECONDS)
	await tween.finished
	cutscene_music_player.stop()
	cutscene_music_player.volume_db = start_volume

func _resolve_cutscene_media_path(extension: String) -> String:
	if _active_biome == "":
		return ""
	for root in VIDEO_ROOT_DIRS:
		var candidate = "%s%s_cutscene.%s" % [root, _active_biome, extension]
		if ResourceLoader.exists(candidate):
			return candidate
	return ""

func _try_play_cutscene_music() -> bool:
	if cutscene_music_player == null:
		return false
	var music_path = _resolve_cutscene_media_path("mp3")
	if music_path == "":
		return false
	var music_stream = load(music_path) as AudioStream
	if music_stream == null:
		return false
	cutscene_music_player.stream = music_stream
	cutscene_music_player.play()
	return true

func _try_play_cutscene_video() -> bool:
	if video_player == null:
		return false
	var video_path = _resolve_cutscene_media_path("ogv")
	if video_path == "":
		return false
	var video_stream = load(video_path) as VideoStream
	if video_stream == null:
		return false
	video_player.stream = video_stream
	if not video_player.finished.is_connected(_on_video_finished):
		video_player.finished.connect(_on_video_finished)
	video_player.visible = true
	video_player.play()
	_fit_video_player()
	_fit_video_player.call_deferred()
	return true

func _on_video_finished():
	_show_text_phase()

func _fit_video_player():
	if video_player == null:
		return
	var safe_aspect_ratio = _get_video_aspect_ratio()
	var scene_size = size
	if scene_size.x <= 0.0 or scene_size.y <= 0.0:
		scene_size = get_viewport_rect().size
	if scene_size.x <= 0.0 or scene_size.y <= 0.0:
		return
	var target_size = scene_size
	var scene_aspect_ratio = scene_size.x / scene_size.y
	if scene_aspect_ratio > safe_aspect_ratio:
		target_size.x = scene_size.y * safe_aspect_ratio
	else:
		target_size.y = scene_size.x / safe_aspect_ratio
	video_player.expand = true
	video_player.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	video_player.position = (scene_size - target_size) * 0.5
	video_player.size = target_size

func _get_video_aspect_ratio() -> float:
	var fallback_ratio = video_aspect_ratio if video_aspect_ratio > 0.0 else DEFAULT_VIDEO_ASPECT_RATIO
	if video_player == null:
		return fallback_ratio
	var texture := video_player.get_video_texture()
	if texture:
		var size = texture.get_size()
		if size.x > 0.0 and size.y > 0.0:
			return size.x / size.y
	return fallback_ratio
