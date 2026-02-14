extends Control

# res://features/ui/DeathScreen.gd

@onready var wake_up_button = %WakeUpButton
@onready var anim_player = %AnimationPlayer

func _ready():
	# Ensure the cursor is visible and interaction is enabled
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if wake_up_button:
		wake_up_button.pressed.connect(_on_wake_up_pressed)

func _on_wake_up_pressed():
	# 1. Restore Player Health to Maximum
	# Accessing GameManager via Autoload
	GameManager.current_hp = GameManager.max_hp
	
	# 2. Reset progress for the "Day" (Resetting current floor/nodes)
	# This simulates starting back at the 'village' or start of the map
	GameManager.completed_nodes = []
	GameManager.current_level = 1
	# Resetting current location to the starting "Home" node (ID 0)
	GameManager.current_node_id = 0
	
	# 3. Save the state so the player doesn't lose persistent progress
	SaveManager.save_mid_run_state()
	
	# 4. Fade out and return to the map using a robust transition
	_fade_and_exit()

func _fade_and_exit():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	
	# Using await instead of a lambda prevents common "Expected end of file" parser errors
	await tween.finished
	get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")
