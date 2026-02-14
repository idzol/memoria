extends Control

# res://scripts/ui/IntroCinematic.gd
# Handles the introduction cinematic and the spacebar skip logic.

@onready var video_player = %VideoPlayer
@onready var skip_prompt = %SkipPrompt

func _ready():
	# 1. Setup Video (You must provide a valid video file at this path)
	var video_path = "res://assets/video/intro.ogv"
	
	if FileAccess.file_exists(video_path):
		video_player.stream = load(video_path)
		video_player.finished.connect(_on_intro_finished)
		video_player.play()
	else:
		# Fallback if video is missing during development
		_display_placeholder_intro()

func _input(event):
	# Listen for Spacebar (ui_accept) to skip
	if event.is_action_pressed("ui_accept"):
		_on_intro_finished()

func _on_intro_finished():
	# Stop further input processing to prevent multiple triggers
	set_process_input(false)
	
	# Smooth fade transition to the World Map
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	
	# Ensure logic is scoped within this function or a lambda
	tween.finished.connect(func():
		get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")
	)

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
