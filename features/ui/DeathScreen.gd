extends Control

# res://features/ui/DeathScreen.gd

@onready var wake_up_button = %WakeUpButton
@onready var anim_player = %AnimationPlayer
@onready var death_background = %DeathBackground

func _ready():
	# Ensure the cursor is visible and interaction is enabled
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_random_background()
	
	if wake_up_button:
		wake_up_button.pressed.connect(_on_wake_up_pressed)

func _apply_random_background():
	if not death_background:
		return
	randomize()
	var n = randi_range(1, 3)
	var path = "res://assets/ui/end_day_%d.png" % n
	if ResourceLoader.exists(path):
		death_background.texture = load(path)

func _on_wake_up_pressed():
	# Save the latest death-state updates before transitioning.
	SaveManager.save_mid_run_state()
	
	# Fade out and route by game mode.
	_fade_and_exit()

func _fade_and_exit():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	
	# Using await instead of a lambda prevents common "Expected end of file" parser errors
	await tween.finished
	if GameManager.is_battle_mode:
		get_tree().change_scene_to_file("res://features/ui/RunSummary.tscn")
	else:
		get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")
