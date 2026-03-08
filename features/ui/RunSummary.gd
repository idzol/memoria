extends Control

# res://features/ui/RunSummary.gd
# Displays final stats and handles mode-specific redirection.

@onready var result_title = %ResultTitle
@onready var level_label = %LevelLabel
@onready var rooms_label = %RoomsLabel
@onready var card_container = %CardContainer
@onready var item_container = %ItemContainer
@onready var menu_button = %MenuButton

const CardIconScene = preload("res://features/combat/CardIcon.tscn")

func _ready():
	_setup_summary()
	if menu_button:
		menu_button.pressed.connect(_on_exit_pressed)

func _setup_summary():
	# 1. Title Logic
	if GameManager.current_hp > 0:
		result_title.text = "RUN COMPLETED"
		result_title.modulate = Color.GOLD
	else:
		result_title.text = "DIVINITY LOST"
		result_title.modulate = Color.CRIMSON
	
	# 2. Basic Stats
	level_label.text = "Level %d %s" % [GameManager.player_level, GameManager.player_class]
	
	var rooms_cleared = 0
	for id in GameManager.world_state.rooms:
		if GameManager.world_state.rooms[id].get("cleared", false):
			rooms_cleared += 1
	rooms_label.text = "Rooms Conquered: %d" % rooms_cleared
	
	# 3. Populate Card Collection
	for child in card_container.get_children(): child.queue_free()
	for card_id in GameManager.active_deck:
		var ci = CardIconScene.instantiate()
		card_container.add_child(ci)
		var res = DataManager.get_resource("res://data/cards/" + card_id + ".tres")
		if res:
			ci.setup(res)
			ci.get_node("%BackFace").visible = false
			ci.get_node("%FrontFace").visible = true
			ci.is_face_up = true
	
	# 4. Populate Items
	for child in item_container.get_children(): child.queue_free()
	for item_id in GameManager.active_items:
		var lbl = Label.new()
		lbl.text = " • " + item_id.replace("_", " ").capitalize()
		lbl.add_theme_font_size_override("font_size", 18)
		item_container.add_child(lbl)

func _on_exit_pressed():
	if GameManager.is_battle_mode:
		# Return to Menu
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	else:
		# Return to Overworld and Reset to Home
		GameManager.player_grid_pos = Vector2i(2, 0) # Reset to home coord
		GameManager.current_hp = GameManager.max_hp # Partial restore for next attempt
		SaveManager.save_mid_run_state()
		get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")
