extends Control

# res://features/ui/IntroCinematic.gd
# Handles the introduction cinematic and the spacebar skip logic.

const MAIN_MENU_SCENE := "res://features/ui/MainMenu.tscn"
const INTRO_FADE_IN_DURATION := 0.45
const OUTRO_FADE_DURATION := 0.45

@export var debug_bypass_intro_cinematic: bool = true

@onready var video_player = %VideoPlayer
@onready var skip_prompt = %SkipPrompt
@onready var black_overlay: ColorRect = %BlackOverlay

var _is_finishing := false

func _ready():
	if debug_bypass_intro_cinematic:
		_go_to_main_menu()
		return

	# 1. Setup Video (You must provide a valid video file at this path)
	var video_path = "res://assets/video/intro.ogv"
	if black_overlay:
		black_overlay.color = Color(0, 0, 0, 1)
	
	if FileAccess.file_exists(video_path):
		video_player.stream = load(video_path)
		video_player.finished.connect(_on_intro_finished)
		video_player.play()
	else:
		# Fallback if video is missing during development
		_display_placeholder_intro()

	_fade_in_from_black()

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
