extends Control

# res://features/ui/CharacterSelect.gd

func _ready():	
	if has_node("%ArchivistBtn"):
		%ArchivistBtn.pressed.connect(_select_class.bind("Archivist"))
	if has_node("%BerserkerBtn"):
		%BerserkerBtn.pressed.connect(_select_class.bind("Berserker"))
	if has_node("%IllusionistBtn"):
		%IllusionistBtn.pressed.connect(_select_class.bind("Illusionist"))
	if has_node("%BackBtn"):
		%BackBtn.pressed.connect(_on_back)

func _select_class(selected_class: String):
	# 1. Basic Identity
	GameManager.player_class = selected_class
	GameManager.player_level = 1
	
	# 2. Starting Stats
	match selected_class:
		"Archivist": GameManager.max_hp = 90
		"Berserker": GameManager.max_hp = 120
		"Illusionist": GameManager.max_hp = 100
	
	GameManager.current_hp = GameManager.max_hp
	GameManager.gold = 50
	
	# 3. Starting Profile (Abilities)
	# Centralized initialization of the starting moveset
	var starting_set = ["fist", "kick", "block"]
	GameManager.player_inventory = starting_set.duplicate()
	GameManager.active_deck = starting_set.duplicate()
	
	# 4. Enter the Dungeon
	GameManager.start_actual_run()

func _on_back():
	get_tree().change_scene_to_file("res://features/ui/MainMenu.tscn")
