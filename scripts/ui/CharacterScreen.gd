extends Control

# res://scripts/ui/CharacterScreen.gd
# Handles inventory management, deck building, and player stats.

# IMPORT: Centralized card data
const CardDatabase = preload("res://scripts/core/CardDatabase.gd")

@onready var card_grid = %CardGrid
@onready var deck_count_label = %DeckCount
@onready var class_label = %ClassName
@onready var hp_label = %HPLabel
@onready var gold_label = %GoldLabel
@onready var back_button = %BackButton

func _ready():
	_update_stats_ui()
	_populate_inventory()
	_update_deck_counter()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _update_stats_ui():
	# Display Character Class and Level
	if class_label: 
		var p_class = GameManager.get("player_class")
		var p_lvl = GameManager.get("player_level")
		if p_lvl == null: p_lvl = 1 # Fallback for new runs
		
		class_label.text = "%s (Lvl %d)" % [
			p_class if p_class != null else "Hero",
			p_lvl
		]
		
	if hp_label: 
		var cur_hp = GameManager.get("current_hp")
		var m_hp = GameManager.get("max_hp")
		hp_label.text = "HP: %d / %d" % [
			cur_hp if cur_hp != null else 0, 
			m_hp if m_hp != null else 100
		]
		
	if gold_label: 
		var g = GameManager.get("gold")
		gold_label.text = "Gold: " + str(g if g != null else 0)

func _populate_inventory():
	# Clear the grid for a fresh render to update "greyed out" states
	for child in card_grid.get_children(): 
		child.queue_free()
	
	# Only loops through cards found in player_inventory (hiding undiscovered cards)
	for card_id in GameManager.player_inventory:
		var card_data = CardDatabase.get_card(card_id)
		if card_data:
			var card_ui = _create_card_ui(card_id, card_data)
			card_grid.add_child(card_ui)

func _create_card_ui(id: String, data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 160)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10); margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10); margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var hbox_main = HBoxContainer.new()
	hbox_main.add_theme_constant_override("separation", 15)
	margin.add_child(hbox_main)
	
	var tex_rect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(80, 120)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture = load(data.image)
	hbox_main.add_child(tex_rect)
	
	var vbox_text = VBoxContainer.new()
	vbox_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_main.add_child(vbox_text)
	
	var name_hbox = HBoxContainer.new()
	vbox_text.add_child(name_hbox)
	
	var name_lbl = Label.new()
	name_lbl.text = data.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_hbox.add_child(name_lbl)
	
	var check = CheckBox.new()
	var active_deck = GameManager.get("active_deck")
	var is_in_deck = id in active_deck
	check.button_pressed = is_in_deck
	
	# GREY OUT LOGIC: 
	# If we are at the minimum of 3 pairs, disable the check-boxes of cards currently in the deck.
	if active_deck.size() <= 3 and is_in_deck:
		check.disabled = true
		check.modulate.a = 0.5 # Visible "greyed out" effect
	
	# bind(style, id) results in call: _on_card_toggled(bool, StyleBoxFlat, String)
	check.toggled.connect(_on_card_toggled.bind(style, id))
	name_hbox.add_child(check)
	
	var desc_lbl = Label.new()
	desc_lbl.text = data.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox_text.add_child(desc_lbl)
	
	if check.button_pressed:
		style.border_color = Color(0.4, 0.8, 1.0)
		style.bg_color = Color(0.1, 0.15, 0.25)
	
	return panel

func _on_card_toggled(is_active: bool, style: StyleBoxFlat, id: String):
	var active_deck = GameManager.get("active_deck")
	if active_deck == null: return
	
	if is_active:
		# Max limit check
		if active_deck.size() >= 12:
			_populate_inventory()
			return
			
		if not id in active_deck:
			active_deck.append(id)
			style.border_color = Color(0.4, 0.8, 1.0)
			style.bg_color = Color(0.1, 0.2, 0.3)
	else:
		# MINIMUM REQUIREMENT CHECK
		if active_deck.size() <= 3:
			_populate_inventory()
			return
			
		active_deck.erase(id)
		style.border_color = Color(0.3, 0.3, 0.35)
		style.bg_color = Color(0.15, 0.15, 0.18)
		
	_update_deck_counter()
	_populate_inventory() # Refresh to update "greyed out" states of all other cards
	SaveManager.save_mid_run_state()

func _update_deck_counter():
	if not deck_count_label: return
	var active_deck = GameManager.get("active_deck")
	var count = active_deck.size() if active_deck != null else 0
	deck_count_label.text = "Active Pairs: %d / 12" % count
	
	# Visual feedback for minimum and maximum requirements
	if count <= 3:
		deck_count_label.modulate = Color.GOLD
	elif count == 12:
		deck_count_label.modulate = Color.GREEN
	else:
		deck_count_label.modulate = Color.SKY_BLUE

func _on_back_pressed():
	# Prevent leaving if the deck is too small (safety check)
	if GameManager.active_deck.size() < 3:
		deck_count_label.text = "MIN 3 PAIRS REQUIRED!"
		return
		
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")