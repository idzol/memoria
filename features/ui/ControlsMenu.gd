extends Control

# This script manages the Controls Page and default key allocations
# It handles keyboard/mouse behavior settings and UI feedback

@onready var controls_list = $ScrollContainer/VBoxContainer
@onready var back_button = $BackButton

# Default key allocations
var default_controls = {
	"move_forward": {"key": KEY_W, "label": "Move Forward"},
	"move_backward": {"key": KEY_S, "label": "Move Backward"},
	"move_left": {"key": KEY_A, "label": "Move Left"},
	"move_right": {"key": KEY_D, "label": "Move Right"},
	"jump": {"key": KEY_SPACE, "label": "Jump"},
	"interact": {"key": KEY_E, "label": "Interact"},
	"cancel": {"key": KEY_ESCAPE, "label": "Cancel / Back"}
}

func _ready():
	setup_ui()
	back_button.pressed.connect(_on_back_pressed)

func _input(event):
	# Global behavior: Escape always returns to menu from this sub-page
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()

func setup_ui():
	# Clear existing placeholder items
	for child in controls_list.get_children():
		child.queue_free()
	
	# Create entries for each default allocation
	for action in default_controls:
		var h_box = HBoxContainer.new()
		h_box.custom_minimum_size.y = 40
		
		var label = Label.new()
		label.text = default_controls[action]["label"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var key_button = Button.new()
		key_button.text = OS.get_keycode_string(default_controls[action]["key"])
		key_button.custom_minimum_size.x = 150
		
		h_box.add_child(label)
		h_box.add_child(key_button)
		controls_list.add_child(h_box)

func _on_back_pressed():
	# Path to your main menu scene
	var menu_path = "res://features/ui/MainMenu.tscn"
	if FileAccess.file_exists(menu_path):
		get_tree().change_scene_to_file(menu_path)
	else:
		# Fallback if scene is not yet created
		queue_free()