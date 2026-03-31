extends Control

# res://features/ui/IntroCinematic.gd
# Handles the introduction cinematic and the spacebar skip logic.

const MAIN_MENU_SCENE := "res://features/ui/MainMenu.tscn"
const INTRO_FADE_IN_DURATION := 0.45
const OUTRO_FADE_DURATION := 0.45
const DEFAULT_VIDEO_ASPECT_RATIO := 16.0 / 9.0

@export var debug_bypass_intro_cinematic: bool = false
@export_range(0.1, 4.0, 0.001) var video_aspect_ratio: float = DEFAULT_VIDEO_ASPECT_RATIO

@onready var video_player = %VideoPlayer
@onready var skip_prompt = %SkipPrompt
@onready var black_overlay: ColorRect = %BlackOverlay

var _is_finishing := false

func _ready():
	if DataManager and DataManager.has_method("pause_for_cutscene"):
		DataManager.pause_for_cutscene()

	if debug_bypass_intro_cinematic:
		_go_to_main_menu()
		return

	# 1. Setup Video (You must provide a valid video file at this path)
	var video_path = "res://assets/video/intro_cutscene.ogv"
	if black_overlay:
		black_overlay.color = Color(0, 0, 0, 1)
	
	if FileAccess.file_exists(video_path):
		video_player.stream = load(video_path)
		video_player.finished.connect(_on_intro_finished)
		_fit_video_player()
		video_player.play()
	else:
		# Fallback if video is missing during development
		_display_placeholder_intro()

	_fade_in_from_black()

func _exit_tree():
	if DataManager and DataManager.has_method("resume_after_cutscene"):
		DataManager.resume_after_cutscene()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_fit_video_player()

func _input(event):
	# Listen for Spacebar (ui_accept) to skip
	if event.is_action_pressed("ui_accept"):
		_on_intro_finished()
	elif event is InputEventKey and event.pressed and not event.is_echo():
		_on_intro_finished()
	elif event is InputEventMouseButton and event.pressed:
		_on_intro_finished()
	elif event is InputEventJoypadButton and event.pressed:
		_on_intro_finished()

func _on_intro_finished():
	if _is_finishing:
		return
	_is_finishing = true
	# Stop further input processing to prevent multiple triggers
	set_process_input(false)
	
	# Smooth fade transition to black before the scene handoff.
	var tween = create_tween()
	tween.tween_property(black_overlay, "color:a", 1.0, OUTRO_FADE_DURATION)
	tween.finished.connect(_go_to_main_menu)

func _fade_in_from_black():
	if not black_overlay:
		return
	var tween = create_tween()
	tween.tween_property(black_overlay, "color:a", 0.0, INTRO_FADE_IN_DURATION)

func _fit_video_player():
	if not is_instance_valid(video_player):
		return

	var safe_aspect_ratio = video_aspect_ratio if video_aspect_ratio > 0.0 else DEFAULT_VIDEO_ASPECT_RATIO
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var target_size = viewport_size
	var viewport_aspect_ratio = viewport_size.x / viewport_size.y

	if viewport_aspect_ratio > safe_aspect_ratio:
		target_size.x = viewport_size.y * safe_aspect_ratio
	else:
		target_size.y = viewport_size.x / safe_aspect_ratio

	video_player.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	video_player.position = (viewport_size - target_size) * 0.5
	video_player.size = target_size

func _go_to_main_menu():
	await SceneTransition.change_scene_to_file(MAIN_MENU_SCENE, 0.2)

func _display_placeholder_intro():
	# Visual fallback for testing without a raw video file
	if skip_prompt:
		skip_prompt.text = "VIDEO MISSING - PRESS SPACE TO CONTINUE"
	
	var lbl = Label.new()
	lbl.text = "THE MEMORIES ARE FADING...\n\n(Cinematic Sequence Placeholder)"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# FIXED: In Godot 4, use add_theme_font_size_override instead of direct property assignment
	lbl.add_theme_font_size_override("font_size", 32)
	
	add_child(lbl)
	
	# Center the placeholder label
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
