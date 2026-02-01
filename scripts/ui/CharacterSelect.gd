extends Control

# res://scripts/ui/CharacterSelect.gd

func _ready():	
	# Connecting buttons using Unique Names (%)
	# Ensure these are enabled in the CharacterSelect.tscn scene tree!
	if has_node("%ArchivistBtn"):
		%ArchivistBtn.pressed.connect(_select_class.bind("Archivist"))
	if has_node("%BerserkerBtn"):
		%BerserkerBtn.pressed.connect(_select_class.bind("Berserker"))
	if has_node("%IllusionistBtn"):
		%IllusionistBtn.pressed.connect(_select_class.bind("Illusionist"))
	if has_node("%BackBtn"):
		%BackBtn.pressed.connect(_on_back)

# FIXED: Renamed 'class_name' to 'selected_class' to avoid reserved keyword conflict
func _select_class(selected_class: String):
	GameManager.player_class = selected_class
	
	# Set initial HP/Stats based on class
	match selected_class:
		"Archivist": 
			GameManager.max_hp = 90
		"Berserker": 
			GameManager.max_hp = 120
		"Illusionist": 
			GameManager.max_hp = 100
	
	GameManager.current_hp = GameManager.max_hp
	GameManager.start_actual_run()

func _on_back():
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
