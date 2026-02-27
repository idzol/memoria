extends Control

# res://features/ui/CharacterScreen.gd
# Manages the dual-tab interface for Deck Building and Item Equipment.
# Updated: Integrated stacked bar/text layout and full-card representation.

const CardData = preload("res://data/resources/CardData.gd")
const CardScene = preload("res://features/combat/Card.tscn")

@onready var deck_grid = %DeckGrid
@onready var item_grid = %ItemGrid
@onready var deck_count_label = %DeckCount
@onready var item_count_label = %ItemCount
@onready var class_label = %ClassName

# Bars and Labels
@onready var hp_bar = %HPBar
@onready var hp_text = %HPText
@onready var xp_bar = %XPBar
@onready var xp_text = %XPText

# Secondary Stats
@onready var atk_label = %AtkLabel
@onready var def_label = %DefLabel
@onready var gold_label = %GoldLabel
@onready var back_button = %BackButton

const CARDS_ROOT = "res://data/cards/"
const ITEMS_ROOT = "res://data/items/"

func _ready():
	_update_stats_ui()
	_populate_deck_tab()
	_populate_inventory_tab()
	_update_counters()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _update_stats_ui():
	# Character Identity & Level
	var p_lvl = GameManager.player_level
	class_label.text = "%s (Lvl %d)" % [GameManager.player_class, p_lvl]
	
	# Vitality (Health)
	hp_bar.max_value = GameManager.max_hp
	hp_bar.value = GameManager.current_hp
	hp_text.text = "%d / %d" % [GameManager.current_hp, GameManager.max_hp]
	
	# Memory (Experience)
	# Threshold logic: 100 XP per level
	var max_xp = GameManager.player_level * 100 
	xp_bar.max_value = max_xp
	xp_bar.value = GameManager.player_xp
	xp_text.text = "%d / %d" % [GameManager.player_xp, max_xp]
	
	# Combat Stats
	atk_label.text = "ATTACK: %d" % GameManager.player_attack
	def_label.text = "DEFENSE: %d" % GameManager.player_defense
	gold_label.text = "GOLD: %d" % GameManager.gold

# --- DECK MANAGEMENT ---

func _populate_deck_tab():
	for child in deck_grid.get_children(): child.queue_free()
	
	for card_id in GameManager.player_cards:
		var path = CARDS_ROOT + card_id + ".tres"
		if ResourceLoader.exists(path):
			var res = load(path) as CardData
			_add_card_to_grid(deck_grid, card_id, res, "deck")

# --- INVENTORY MANAGEMENT ---

func _populate_inventory_tab():
	for child in item_grid.get_children(): child.queue_free()
	
	# Pool of discovered items
	for item_id in GameManager.player_items:
		var path = ITEMS_ROOT + item_id + ".tres"
		if ResourceLoader.exists(path):
			var res = load(path) as CardData
			_add_card_to_grid(item_grid, item_id, res, "item")

# --- SHARED GRID LOGIC ---

func _add_card_to_grid(container: GridContainer, id: String, res: CardData, mode: String):
	# INSTANTIATE FULL CARD
	var card_ui = CardScene.instantiate()
	container.add_child(card_ui)
	
	# Visual scaling for management views
	card_ui.custom_minimum_size = Vector2(160, 240)
	card_ui.scale = Vector2(0.9, 0.9)
	card_ui.setup(res)
	
	# Force face-up and disable standard flip animation
	card_ui.get_node("%BackFace").visible = false
	card_ui.get_node("%FrontFace").visible = true
	card_ui.is_face_up = true
	
	_update_selection_visuals(card_ui, id, mode)
	
	# Override interaction (clicking toggles deck status instead of flipping)
	card_ui.pressed.disconnect(card_ui._on_pressed)
	if mode == "deck":
		card_ui.pressed.connect(_on_deck_card_clicked.bind(card_ui, id))
	else:
		card_ui.pressed.connect(_on_inventory_item_clicked.bind(card_ui, id))

func _on_deck_card_clicked(node: Control, id: String):
	var deck = GameManager.active_deck
	if id in deck:
		if deck.size() > 3: deck.erase(id)
	else:
		if deck.size() < 12: deck.append(id)
	
	_update_selection_visuals(node, id, "deck")
	_update_counters()
	SaveManager.save_mid_run_state()

func _on_inventory_item_clicked(node: Control, id: String):
	if not "active_items" in GameManager:
		GameManager.set("active_items", [])
	
	var active = GameManager.active_items
	if id in active:
		active.erase(id)
	else:
		if active.size() < 3:
			active.append(id)
			
	_update_selection_visuals(node, id, "item")
	_update_counters()
	SaveManager.save_mid_run_state()

func _update_selection_visuals(node: Control, id: String, mode: String):
	var is_active = false
	if mode == "deck":
		is_active = id in GameManager.active_deck
	else:
		var active_items = GameManager.get("active_items")
		is_active = id in (active_items if active_items != null else [])
		
	if is_active:
		node.modulate = Color.WHITE
		node.self_modulate = Color(0.5, 0.8, 1.0) # Blue highlight
	else:
		node.modulate = Color(0.6, 0.6, 0.6, 0.8) # Dimmed
		node.self_modulate = Color.WHITE

func _update_counters():
	deck_count_label.text = "Active Pairs: %d / 12" % GameManager.active_deck.size()
	
	var active_items = GameManager.get("active_items")
	var item_count = active_items.size() if active_items != null else 0
	item_count_label.text = "Equipped: %d / 3" % item_count

func _on_back_pressed():
	if GameManager.active_deck.size() < 3:
		return 
	get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")
