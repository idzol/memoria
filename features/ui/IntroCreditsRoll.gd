extends Control

const NEXT_SCENE := "res://features/ui/IntroCinematic.tscn"
const FADE_IN_DURATION := 1.2
const HOLD_DURATION := 2.4
const FADE_OUT_DURATION := 1.0
const SKIP_FADE_OUT_DURATION := 0.35

@export var debug_bypass_intro_credits_roll: bool = true

@onready var image_rect: TextureRect = %ImageRect
@onready var skip_label: Label = %SkipLabel

var _is_exiting := false
var _roll_tween: Tween

func _ready():
	if debug_bypass_intro_credits_roll:
		_go_to_next_scene()
		return
	modulate = Color(1, 1, 1, 1)
	if image_rect:
		image_rect.modulate = Color(1, 1, 1, 0)
	if skip_label:
		skip_label.modulate = Color(1, 1, 1, 0.72)
	_play_roll()

func _input(event):
	if _is_exiting:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		_skip_roll()
	elif event is InputEventMouseButton and event.pressed:
		_skip_roll()
	elif event is InputEventJoypadButton and event.pressed:
		_skip_roll()

func _play_roll():
	_roll_tween = create_tween()
	_roll_tween.tween_property(image_rect, "modulate:a", 1.0, FADE_IN_DURATION)
	_roll_tween.tween_interval(HOLD_DURATION)
	_roll_tween.tween_property(image_rect, "modulate:a", 0.0, FADE_OUT_DURATION)
	_roll_tween.finished.connect(_go_to_next_scene)

func _skip_roll():
	if _is_exiting:
		return
	_is_exiting = true
	if _roll_tween:
		_roll_tween.kill()
	var tween = create_tween()
	tween.tween_property(image_rect, "modulate:a", 0.0, SKIP_FADE_OUT_DURATION)
	tween.finished.connect(_go_to_next_scene)

func _go_to_next_scene():
	if _is_exiting and get_tree() == null:
		return
	if _roll_tween:
		_roll_tween = null
	await SceneTransition.change_scene_to_file(NEXT_SCENE, 0.2)
