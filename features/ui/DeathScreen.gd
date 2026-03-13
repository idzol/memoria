extends Control

# res://features/ui/DeathScreen.gd

@onready var wake_up_button = %WakeUpButton
@onready var anim_player = %AnimationPlayer
@onready var death_background = %DeathBackground
@onready var dimmer = $Dimmer
@onready var center_container = $CenterContainer

var _is_progressing: bool = false

func _ready():
	# Ensure the cursor is visible and interaction is enabled
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_random_background()
	_play_intro_fade()
	
	if wake_up_button:
		wake_up_button.pressed.connect(_on_wake_up_pressed)
		wake_up_button.grab_focus()

func _input(event):
	if _is_progressing:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_wake_up_pressed()
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_SPACE:
		_on_wake_up_pressed()

func _apply_random_background():
	if not death_background:
		return
	randomize()
	var n = randi_range(1, 3)
	var path = "res://assets/ui/end_day_%d.png" % n
	if ResourceLoader.exists(path):
		death_background.texture = load(path)

func _play_intro_fade():
	modulate = Color(1, 1, 1, 1)
	if anim_player:
		anim_player.stop()
	if dimmer:
		dimmer.color = Color(0, 0, 0, 1.0)
	if center_container:
		center_container.modulate = Color(1, 1, 1, 0.0)
	
	var tween = create_tween()
	if dimmer:
		tween.tween_property(dimmer, "color:a", 0.82, 0.8)
	if center_container:
		tween.parallel().tween_property(center_container, "modulate:a", 1.0, 0.7).set_delay(0.2)

func _on_wake_up_pressed():
	if _is_progressing:
		return
	_is_progressing = true
	# Save the latest death-state updates before transitioning.
	SaveManager.save_mid_run_state()
	
	# Fade out and route by game mode.
	_fade_and_exit()

func _fade_and_exit():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	
	# Using await instead of a lambda prevents common "Expected end of file" parser errors
	await tween.finished
	await get_tree().create_timer(1.5).timeout
	if GameManager.is_battle_mode:
		get_tree().change_scene_to_file("res://features/ui/RunSummary.tscn")
	else:
		get_tree().change_scene_to_file(GameManager.get_active_biome_map_scene_path())
