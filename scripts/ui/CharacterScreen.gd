extends Control

# res://scripts/ui/CharacterScreen.gd

@onready var card_grid = %CardGrid
@onready var deck_count_label = %DeckCount
@onready var class_label = %ClassName
@onready var hp_label = %HPLabel
@onready var gold_label = %GoldLabel
@onready var back_button = %BackButton

const CARD_DATA = {
	"sword": {"name": "Blade of Memory", "desc": "Deals 15 damage to the enemy."},
	"shield": {"name": "Ego Barrier", "desc": "Prevents the next 10 damage taken."},
	"heart": {"name": "Vital Spark", "desc": "Heals 20 HP instantly."},
	"frost": {"name": "Freeze Frame", "desc": "Freezes 2 cards face-up for 1 turn."},
	"scroll": {"name": "Ancient Text", "desc": "Reveals 3 random cards for 1 second."},
	"trap": {"name": "Dread Mimic", "desc": "Deals 15 damage to YOU when matched."},
	"axe": {"name": "Heavy Cleaver", "desc": "Deals 25 damage but breaks a match."},
	"potion": {"name": "Mist Tonic", "desc": "Heals 10 HP and grants 1 Peek Charge."},
	"bomb": {"name": "Chain Blast", "desc": "Damages enemy and reveals neighbors."},
	"lightning": {"name": "Storm Surge", "desc": "Deals 20 damage to all enemies."},
	"bandage": {"name": "Quick Fix", "desc": "Heals 12 HP. Cheap but effective."},
	"dagger": {"name": "Hidden Spike", "desc": "Deals 10 damage. High crit chance."}
}

func _ready():
	_update_stats_ui()
	_populate_inventory()
	_update_deck_counter()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _update_stats_ui():
	# In GDScript 4, Object.get() only takes 1 argument. 
	# We use a ternary or check for null to provide a default.
	if class_label: 
		var p_class = GameManager.get("player_class")
		class_label.text = p_class if p_class != null else "Hero"
		
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
	if not card_grid: return
	
	for child in card_grid.get_children():
		child.queue_free()
	
	# Safety check: Get property and fallback to empty array if null
	var inventory = GameManager.get("player_inventory")
	if inventory == null: inventory = []
	
	if inventory.is_empty() and OS.is_debug_build():
		push_warning("GameManager.player_inventory is empty or missing. Check GameManager.gd variables.")
	
	# Only show discovered cards
	for card_id in inventory:
		if CARD_DATA.has(card_id):
			var card_ui = _create_card_ui(card_id)
			card_grid.add_child(card_ui)

func _create_card_ui(id: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 140)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	var name_lbl = Label.new()
	name_lbl.text = CARD_DATA[id].name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 18)
	hbox.add_child(name_lbl)
	
	var check = CheckBox.new()
	var active_deck = GameManager.get("active_deck")
	if active_deck == null: active_deck = []
	
	check.button_pressed = id in active_deck
	check.toggled.connect(_on_card_toggled.bind(id, style))
	hbox.add_child(check)
	
	if check.button_pressed:
		style.border_color = Color(0.4, 0.8, 1.0)
		style.bg_color = Color(0.1, 0.2, 0.3)
	
	var desc_lbl = Label.new()
	desc_lbl.text = CARD_DATA[id].desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_lbl)
	
	return panel

func _on_card_toggled(is_active: bool, style: StyleBoxFlat, id: String):
	var active_deck = GameManager.get("active_deck")
	if active_deck == null: return # Should not happen if initialized
	
	if is_active:
		if active_deck.size() >= 12:
			# Safety check: Refresh to uncheck if over limit
			_populate_inventory()
			return
			
		if not id in active_deck:
			active_deck.append(id)
			style.border_color = Color(0.4, 0.8, 1.0)
			style.bg_color = Color(0.1, 0.2, 0.3)
	else:
		active_deck.erase(id)
		style.border_color = Color(0.3, 0.3, 0.35)
		style.bg_color = Color(0.15, 0.15, 0.18)
		
	_update_deck_counter()
	SaveManager.save_mid_run_state()

func _update_deck_counter():
	if not deck_count_label: return
	var active_deck = GameManager.get("active_deck")
	var count = active_deck.size() if active_deck != null else 0
	deck_count_label.text = "Active Pairs: %d / 12" % count
	deck_count_label.modulate = Color.GREEN if count == 12 else Color.GOLD

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")
