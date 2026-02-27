extends Control

# res://features/ui/DebugCharacterScreen.gd
# Development tool to manipulate player state and audit the full card library.

const CardData = preload("res://data/resources/CardData.gd")
const CardIconScene = preload("res://features/combat/CardIcon.tscn")

@onready var card_grid = %AllCardsGrid
@onready var hp_input = %HPInput
@onready var gold_input = %GoldInput
@onready var level_input = %LevelInput
@onready var class_dropdown = %ClassDropdown
@onready var status_label = %StatusLabel

const CARDS_PATH = "res://data/cards/"

func _ready():
	_setup_ui_defaults()
	_load_all_project_cards()
	
	# Connect Stat Listeners
	hp_input.value_changed.connect(func(v): GameManager.max_hp = int(v); GameManager.current_hp = int(v))
	gold_input.value_changed.connect(func(v): GameManager.gold = int(v))
	level_input.value_changed.connect(func(v): GameManager.player_level = int(v))
	class_dropdown.item_selected.connect(_on_class_selected)

func _setup_ui_defaults():
	hp_input.value = GameManager.max_hp
	gold_input.value = GameManager.gold
	level_input.value = GameManager.player_level
	
	# Setup Class Dropdown
	class_dropdown.clear()
	var classes = ["Archivist", "Berserker", "Illusionist"]
	for i in range(classes.size()):
		class_dropdown.add_item(classes[i])
		if classes[i] == GameManager.player_class:
			class_dropdown.selected = i

func _load_all_project_cards():
	for child in card_grid.get_children():
		child.queue_free()
		
	_scan_for_cards_recursive(CARDS_PATH)

func _scan_for_cards_recursive(path: String):
	var dir = DirAccess.open(path)
	if not dir: return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + file_name
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_for_cards_recursive(full_path + "/")
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			if res is CardData:
				_add_card_to_debug_grid(res)
		file_name = dir.get_next()

func _add_card_to_debug_grid(data: CardData):
	var container = VBoxContainer.new()
	var card_ui = CardIconScene.instantiate()
	container.add_child(card_ui)
	
	card_ui.setup(data)
	# Force face-up for audit
	card_ui.get_node("%BackFace").visible = false
	card_ui.get_node("%FrontFace").visible = true
	card_ui.is_face_up = true
	
	# Add Toggle Logic
	var btn = Button.new()
	btn.toggle_mode = true
	btn.text = "Add to Inv"
	btn.button_pressed = data.card_id in GameManager.player_inventory
	btn.toggled.connect(_on_card_toggled.bind(data.card_id))
	container.add_child(btn)
	
	card_grid.add_child(container)

func _on_card_toggled(is_active: bool, id: String):
	if is_active:
		if not id in GameManager.player_inventory:
			GameManager.player_inventory.append(id)
	else:
		GameManager.player_inventory.erase(id)
		GameManager.active_deck.erase(id)
	
	status_label.text = "Inventory Updated: " + id
	SaveManager.save_mid_run_state()

func _on_class_selected(index: int):
	GameManager.player_class = class_dropdown.get_item_text(index)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")

func _on_reset_run_pressed():
	GameManager.player_inventory = ["sword", "shield", "heart"]
	GameManager.active_deck = ["sword", "shield", "heart"]
	_load_all_project_cards()
	status_label.text = "Run Reset to Defaults"
