extends Control

signal credits_finished

# Configuration
@export var scroll_speed: float = 50.0 
@export var resume_delay: float = 2.0 
@export var title_font_size: int = 64
@export var header_font_size: int = 32
@export var name_font_size: int = 24

# References
@onready var scroll_container: ScrollContainer = $Scroll
@onready var credits_list: VBoxContainer = $Scroll/CreditsList

# State
var is_auto_scrolling: bool = true
var time_since_interaction: float = 0.0
var current_scroll_f: float = 0.0 # Track scroll as float to avoid integer truncation

var credits_data = {
	"title": "MEMORIA CREDITS",
	"dedication": "To Katrina, the love and witness of my life. Without you, life is black and white.",
	"sections": [
		{ "header": "Producer", "names": ["Paul Kubik"] },
		
		{ "header": "Storyline", "names": ["Paul Kubik"] },
		{ "header": "Development", "names": ["Paul Kubik"] },
		{ "header": "Design", "names": ["Paul Kubik"] },
		
		{ "header": "Engine", "names": ["Godot"] },

		{ "header": "Guest Voices", "names": ["Katrina Fernandez"] },

		{ "header": "Special Thanks", "names": ["Crepes", "Ursus", "Katmariedez"] }
	]
}

func _ready():
	# Ensure the node can process input
	set_process_input(true)
	# Hide scrollbar visually but keep mechanics
	scroll_container.get_v_scroll_bar().modulate.a = 0
	setup_credits()

func _input(event):
	# Handle Escape key globally
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		on_credits_finished()

func setup_credits():
	# Start Spacer
	add_spacer(get_viewport_rect().size.y)
	
	# Title
	var title_label = Label.new()
	title_label.text = credits_data["title"]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", title_font_size)
	credits_list.add_child(title_label)
	
	# Dedication
	var dedication = Label.new()
	dedication.text = credits_data["dedication"]
	dedication.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dedication.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dedication.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	credits_list.add_child(dedication)
	
	add_spacer(100)
	
	# Sections
	for section in credits_data["sections"]:
		var header = Label.new()
		header.text = section["header"]
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", header_font_size)
		header.add_theme_color_override("font_color", Color(0.83, 0.68, 0.21))
		credits_list.add_child(header)
		
		for name_str in section["names"]:
			var n_label = Label.new()
			n_label.text = name_str
			n_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n_label.add_theme_font_size_override("font_size", name_font_size)
			credits_list.add_child(n_label)
		
		add_spacer(60)
		
	# End Spacer (Scroll until no longer visible)
	add_spacer(get_viewport_rect().size.y)

func add_spacer(height: float):
	var s = Control.new()
	s.custom_minimum_size.y = height
	credits_list.add_child(s)

func _process(delta):
	if is_auto_scrolling:
		current_scroll_f += scroll_speed * delta
		scroll_container.scroll_vertical = int(current_scroll_f)
		
		# Check if we've reached the absolute end of the list
		# We use the size of the container minus the viewport height
		if scroll_container.scroll_vertical >= (credits_list.size.y - scroll_container.size.y) and credits_list.size.y > 0:
			is_auto_scrolling = false
			on_credits_finished()
	else:
		time_since_interaction += delta
		if time_since_interaction >= resume_delay:
			is_auto_scrolling = true
			# Sync float tracker with manual position
			current_scroll_f = float(scroll_container.scroll_vertical)

func _gui_input(event):
	# Detection of manual scrolling
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			is_auto_scrolling = false
			time_since_interaction = 0.0

func on_credits_finished():
	credits_finished.emit()
	
	# Update this path to match your actual main menu scene
	var main_menu_path = "res://features/ui/MainMenu.tscn"
	
	if FileAccess.file_exists(main_menu_path):
		get_tree().change_scene_to_file(main_menu_path)
	else:
		print("DEBUG: Credits finished, but MainMenu.tscn was not found at: ", main_menu_path)
		# If you are testing, you might want to print the current scene tree to find the right path
		# get_tree().quit()
