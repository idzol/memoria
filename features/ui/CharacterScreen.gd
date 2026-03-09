extends Control

# res://features/ui/CharacterScreen.gd
# Handles character progression, stat calculation, and dual-tab management.
# Updated: Dynamic level-based requirements for deck and items.

const CardData = preload("res://data/resources/CardData.gd")
const ItemData = preload("res://data/resources/ItemData.gd")
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
	# 1. Identity & Level
	var p_lvl = GameManager.player_level
	class_label.text = "%s (Lvl %d)" % [GameManager.player_class, p_lvl]
	
	# 2. STAT CALCULATION
	var totals = _calculate_total_stats()
	
	# 3. Vitality (Base + Item HP)
	var total_max_hp = GameManager.max_hp + totals.hp_bonus
	hp_bar.max_value = total_max_hp
	hp_bar.value = GameManager.current_hp
	hp_text.text = "%d / %d" % [GameManager.current_hp, total_max_hp]
	
	# 4. Memory (Experience)
	var max_xp = GameData.get_max_xp_for_level(GameManager.player_level)
	xp_bar.max_value = max_xp
	xp_bar.value = GameManager.player_xp
	xp_text.text = "%d / %d" % [GameManager.player_xp, max_xp]
	
	# 5. Combat Stats Display
	atk_label.text = "ATTACK: %d (%d+%d)" % [
		GameManager.player_attack + totals.atk_bonus,
		GameManager.player_attack,
		totals.atk_bonus
	]
	def_label.text = "DEFENSE: %d (%d+%d)" % [
		GameManager.player_defense + totals.def_bonus,
		GameManager.player_defense,
		totals.def_bonus
	]
	
	gold_label.text = "GOLD: %d" % GameManager.gold

func _calculate_total_stats() -> Dictionary:
	var bonuses = {"atk_bonus": 0, "def_bonus": 0, "hp_bonus": 0}
	
	var active_items = GameManager.get("active_items")
	var equipped_list = active_items if active_items != null else []
	
	for item_id in equipped_list:
		var path = ITEMS_ROOT + item_id + ".tres"
		if ResourceLoader.exists(path):
			var res = load(path) as ItemData
			if res:
				bonuses.atk_bonus += res.attack
				bonuses.def_bonus += res.armour
				bonuses.hp_bonus += res.hp
				
	return bonuses

# --- DECK MANAGEMENT ---

func _populate_deck_tab():
	for child in deck_grid.get_children(): child.queue_free()
	for card_id in GameManager.player_deck:
		var path = CARDS_ROOT + card_id + ".tres"
		if ResourceLoader.exists(path):
			var res = load(path) as CardData
			_add_card_to_grid(deck_grid, card_id, res, "deck")

# --- INVENTORY MANAGEMENT ---

func _populate_inventory_tab():
	for child in item_grid.get_children(): child.queue_free()
	
	# Reference the new starting item set if not already present
	# wood_splinter, mug_of_ale, iron_scrap
	for item_id in GameManager.player_items:
		var path = ITEMS_ROOT + item_id + ".tres"
		if ResourceLoader.exists(path):
			var res = load(path) as ItemData
			_add_card_to_grid(item_grid, item_id, res, "item")

# --- SHARED GRID LOGIC ---

func _add_card_to_grid(container: GridContainer, id: String, res: Resource, mode: String):
	var card_ui = CardScene.instantiate()
	container.add_child(card_ui)
	
	card_ui.custom_minimum_size = Vector2(160, 240)
	card_ui.scale = Vector2(0.9, 0.9)
	
	# Polymorphic setup based on resource type
	if res is CardData:
		card_ui.setup(res)
	elif res is ItemData:
		if card_ui.has_method("setup_item"):
			card_ui.setup_item(res)
	
	card_ui.get_node("%BackFace").visible = false
	card_ui.get_node("%FrontFace").visible = true
	card_ui.is_face_up = true
	
	_update_selection_visuals(card_ui, id, mode)
	
	card_ui.pressed.disconnect(card_ui._on_pressed)
	if mode == "deck":
		card_ui.pressed.connect(_on_deck_card_clicked.bind(card_ui, id))
	else:
		card_ui.pressed.connect(_on_inventory_item_clicked.bind(card_ui, id))

func _on_deck_card_clicked(node: Control, id: String):
	var deck = GameManager.active_deck
	var min_required = GameManager.player_level
	
	if id in deck:
		# Allow deselection only if we stay at or above the level requirement
		if deck.size() > min_required: 
			deck.erase(id)
	else:
		# Max pairs remains 12 for grid stability
		if deck.size() < 12: 
			deck.append(id)
	
	_update_selection_visuals(node, id, "deck")
	_update_counters()
	SaveManager.save_mid_run_state()

func _on_inventory_item_clicked(node: Control, id: String):
	if not "active_items" in GameManager:
		GameManager.set("active_items", [])
	
	var active = GameManager.active_items
	var max_slots = GameManager.player_level # Max items = Player Level
	
	if id in active:
		active.erase(id)
	else:
		if active.size() < max_slots:
			active.append(id)
			
	_update_selection_visuals(node, id, "item")
	_update_counters()
	_update_stats_ui() # Re-calculate profile stats when gear changes
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
		node.self_modulate = Color(0.5, 0.8, 1.0) 
	else:
		node.modulate = Color(0.6, 0.6, 0.6, 0.8) 
		node.self_modulate = Color.WHITE

func _update_counters():
	# DECK COUNTER: Min required is Level
	var deck_size = GameManager.active_deck.size()
	var min_pairs = GameManager.player_level
	deck_count_label.text = "Active Pairs: %d / %d" % [deck_size, min_pairs]
	
	if deck_size < min_pairs:
		deck_count_label.modulate = Color.TOMATO # Error feedback
	else:
		deck_count_label.modulate = Color.WHITE
		
	# ITEM COUNTER: Max allowed is Level
	var active_items = GameManager.get("active_items")
	var item_count = active_items.size() if active_items != null else 0
	var max_items = GameManager.player_level
	item_count_label.text = "Active Items: %d / %d" % [item_count, max_items]
	
	if item_count >= max_items:
		item_count_label.modulate = Color.GOLD # Full capacity feedback
	else:
		item_count_label.modulate = Color.WHITE

func _on_back_pressed():
	# 1. Validation check before allowing exit
	if GameManager.active_deck.size() < GameManager.player_level:
		deck_count_label.text = "LEVEL %d REQUIRES %d PAIRS!" % [GameManager.player_level, GameManager.player_level]
		return 
	
	# 2. Branching return path
	if GameManager.is_battle_mode:
		# Return to the linear testing map
		get_tree().change_scene_to_file("res://features/map/BattleMap.tscn")
	else:
		# Return to the procedural campaign map
		get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")
