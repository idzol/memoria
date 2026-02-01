extends Node2D

# Paths updated to use Unique Names (%)
@onready var grid = %GridContainer
@onready var player_hp_label = %PlayerHP
@onready var enemy_hp_label = %EnemyHP
@onready var log_box = %LogBox

var card_scene = preload("res://scenes/combat/Card.tscn")

# --- Game State ---
var flipped_cards = []
var can_flip = true # Gating for race condition protection
var player_hp = 100
var enemy_hp = 100 
var textures = {}
var difficulty = 0

func _ready():
	difficulty = GameManager.current_node.get("difficulty", 0)
	player_hp = GameManager.current_hp
	
	if not grid:
		push_error("BattleScene Error: GridContainer not found.")
		return
	
	# PADDING: Increased separation to prevent card overlap
	grid.add_theme_constant_override("h_separation", 35)
	grid.add_theme_constant_override("v_separation", 35)
	
	setup_board()
	update_ui()
	
	add_log("The memory manifests. Prepare yourself.")

func setup_board():
	for child in grid.get_children():
		child.queue_free()
		
	var size = 3
	if difficulty >= 3: size = 4
	if difficulty >= 6: size = 5
	grid.columns = size
	
	var total_slots = size * size
	var pair_count = floor(total_slots / 2.0)
	
	var icon_pool = ["sword", "shield", "heart", "frost", "scroll", "trap", "axe", "potion", "bomb", "lightning", "bandage", "dagger"]
	icon_pool.shuffle()
	
	var selected_types = icon_pool.slice(0, pair_count)
	var deck = []
	for t in selected_types:
		deck.append(t)
		deck.append(t)
		
	if deck.size() < total_slots:
		deck.append("trap")
		
	deck.shuffle()
	
	for type_name in deck:
		var new_card = card_scene.instantiate()
		grid.add_child(new_card)
		new_card.card_type = type_name
		new_card.card_flipped.connect(_on_card_flipped)
		
		var card_width = 110 if size <= 3 else 85
		new_card.custom_minimum_size = Vector2(card_width, card_width * 1.4)
		
		_apply_card_texture(new_card, type_name)

func _apply_card_texture(card_node, type_name):
	var img_path = "res://assets/" + type_name + ".png"
	if not textures.has(type_name) and FileAccess.file_exists(img_path):
		textures[type_name] = load(img_path)
	
	if textures.has(type_name) and card_node.has_method("set_icon_texture"):
		card_node.set_icon_texture(textures[type_name])

func _on_card_flipped(card):
	# RACE CONDITION PROTECTION: Ignore if two cards are already being processed
	if not can_flip or flipped_cards.size() >= 2:
		card.is_face_up = false # Reset state silently
		card.flip_back()
		return

	flipped_cards.append(card)
	if flipped_cards.size() == 2:
		can_flip = false # Block all further clicks
		check_match()

func check_match():
	var c1 = flipped_cards[0]
	var c2 = flipped_cards[1]
	
	# Comparison delay
	await get_tree().create_timer(0.7).timeout
	
	if c1.card_type == c2.card_type:
		c1.is_matched = true
		c2.is_matched = true
		c1.modulate = Color(0.6, 1.0, 0.6)
		c2.modulate = Color(0.6, 1.0, 0.6)
		
		# Reset Match visuals (1x scale, base layer)
		c1.z_index = 0
		c2.z_index = 0
		c1.scale = Vector2.ONE
		c2.scale = Vector2.ONE
		
		process_combat_action(c1.card_type)
	else:
		c1.flip_back()
		c2.flip_back()
		enemy_turn()
	
	flipped_cards.clear()
	
	# RESHUFFLE LOGIC: If no matchable pairs remain (only debuffs or singletons)
	if _should_reshuffle():
		add_log("No pairs remain. Reshuffling memory...")
		await get_tree().create_timer(1.0).timeout
		setup_board()
	
	can_flip = true # Allow selection again
	update_ui()

func _should_reshuffle() -> bool:
	var type_counts = {}
	for card in grid.get_children():
		if not card.is_matched:
			# Skip "trap" (debuffs) if you want them to be excluded from pair counts
			# Or count all remaining unmatched cards.
			# Logic: If total remaining matchable pairs < 1, reshuffle.
			if card.card_type != "trap": 
				type_counts[card.card_type] = type_counts.get(card.card_type, 0) + 1
	
	# Check if any type has at least 2 cards remaining
	for type in type_counts:
		if type_counts[type] >= 2:
			return false # A pair still exists
			
	return true # Only debuffs or single items remain

func process_combat_action(type):
	match type:
		"sword", "axe", "dagger": _damage_enemy(15 + (difficulty * 2))
		"heart", "potion": _heal_player(20)
		"trap": _damage_player(15)

func _damage_enemy(amount: int):
	enemy_hp -= amount
	add_log("Hit! Enemy takes %d damage." % amount)
	_flash_unit(%EnemyFlash, Color.CRIMSON)

func _heal_player(amount: int):
	player_hp = min(GameManager.max_hp, player_hp + amount)
	add_log("Heal! +%d HP." % amount)
	_flash_unit(%PlayerFlash, Color.SEA_GREEN)

func _damage_player(amount: int):
	player_hp -= amount
	add_log("Enemy strike! %d damage." % amount)
	_flash_unit(%PlayerFlash, Color.CRIMSON)
	if player_hp <= 0: SignalBus.combat_lost.emit()

func enemy_turn():
	_damage_player(8 + difficulty)

func _flash_unit(overlay, color):
	if not overlay: return
	overlay.color = color
	overlay.color.a = 0.5
	create_tween().tween_property(overlay, "color:a", 0.0, 0.4)

func update_ui():
	if player_hp_label: player_hp_label.text = "HP: %d/%d" % [player_hp, GameManager.max_hp]
	if enemy_hp_label: enemy_hp_label.text = "HP: %d" % enemy_hp

func add_log(text):
	if log_box:
		var lbl = Label.new()
		lbl.text = "> " + text
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_box.add_child(lbl)
		await get_tree().process_frame
		var scroll = log_box.get_parent()
		if scroll is ScrollContainer:
			scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
