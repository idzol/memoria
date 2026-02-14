extends Node2D

# res://scripts/ui/combat/BattleScene.gd
# Handles Dialog Flow -> Memory Match Combat -> Victory/Loss

# const GameData = preload("res://scripts/data/GameData.gd")

@onready var grid = %GridContainer
@onready var player_hp_label = %PlayerHP
@onready var enemy_hp_label = %EnemyHP
@onready var log_box = %LogBox

# Dialog UI
@onready var dialog_overlay = %DialogOverlay
@onready var dialog_text = %DialogText
@onready var room_title = %RoomTitle
@onready var option_container = %OptionContainer
@onready var battle_ui = %UI # The main battle interface

# Portraits
@onready var enemy_portrait_sprite = %EnemyPortraitSprite
@onready var player_portrait_sprite = %PlayerPortraitSprite

var card_scene = preload("res://scenes/combat/Card.tscn")

# --- Combat State ---
var flipped_cards = []
var can_flip = false # Blocked during dialog
var player_hp = 100
var enemy_hp = 100 
var textures = {}
var difficulty = 0
var current_room = {}
var active_tree = {}

func _ready():
	# 1. Initialize Room Data
	current_room = GameManager.current_node
	if current_room.is_empty():
		# Fallback for direct scene testing
		current_room = GameManager.get_random_room_for_area("forest")
	
	difficulty = current_room.get("difficulty", 1)
	player_hp = GameManager.world_state.get("current_hp", 100)
	
	if not grid:
		push_error("BattleScene Error: GridContainer not found.")
		return

	# PADDING: Increased separation to prevent card overlap
	grid.add_theme_constant_override("h_separation", 35)
	grid.add_theme_constant_override("v_separation", 35)
	
	# 2. Setup Debug Buttons
	%DebugWinBtn.pressed.connect(_on_win)
	%DebugLoseBtn.pressed.connect(_on_lose)
	
	# 3. Setup Portraits
	_setup_portraits()
	
	# 4. Start Dialog Flow
	_init_encounter()
	update_ui()

func _setup_portraits():
	# Load Enemy Portrait from GameData ENEMIES or NPCS
	var enemy_id = current_room.get("enemy", "")
	var npc_id = current_room.get("npc_id", "")
	
	var icon_path = "res://assets/skull.png"
	if GameData.ENEMIES.has(enemy_id):
		icon_path = GameData.ENEMIES[enemy_id].icon
		enemy_hp = GameData.ENEMIES[enemy_id].hp
	elif GameData.NPCS.has(npc_id):
		icon_path = GameData.NPCS[npc_id].icon
		enemy_hp = GameData.NPCS[npc_id].get("stats", {}).get("hp", 50)
	
	enemy_portrait_sprite.texture = load(icon_path)

func _init_encounter():
	battle_ui.hide()
	dialog_overlay.show()
	
	# Check for Dialog Tree
	var tree_id = current_room.get("dialog_tree", "")
	if GameData.DIALOG_TREES.has(tree_id):
		active_tree = GameData.DIALOG_TREES[tree_id]
		_display_tree_node("start")
	else:
		_setup_basic_dialog()

func _display_tree_node(node_id: String):
	var node = active_tree.get(node_id)
	if !node: return
	
	room_title.text = current_room.get("name", "Encounter")
	dialog_text.text = node.text
	
	# Clear Options
	for child in option_container.get_children(): child.queue_free()
	
	for opt in node.options:
		# Evaluate World State Conditions
		if opt.has("condition") and !GameManager.evaluate_condition(opt.condition):
			continue
			
		var btn = Button.new()
		btn.text = opt.text
		btn.pressed.connect(func(): _handle_dialog_choice(opt))
		option_container.add_child(btn)

func _handle_dialog_choice(opt: Dictionary):
	if opt.has("bonus_loot"):
		GameManager.add_item(opt.bonus_loot)
		add_log("Received item: " + opt.bonus_loot.capitalize())
		
	if opt.has("next_node"):
		_display_tree_node(opt.next_node)
	elif opt.get("action") == "battle":
		_start_combat()
	elif opt.get("action") == "victory":
		_on_win()

func _setup_basic_dialog():
	room_title.text = current_room.get("name", "Encounter")
	dialog_text.text = current_room.get("dialog", "An enemy approaches!")
	
	for child in option_container.get_children(): child.queue_free()
	var btn = Button.new()
	btn.text = "Fight!"
	btn.pressed.connect(_start_combat)
	option_container.add_child(btn)

func _start_combat():
	dialog_overlay.hide()
	battle_ui.show()
	can_flip = true
	setup_board()
	add_log("The memory manifests. Prepare yourself.")

# --- Combat Logic (Memory Match) ---
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

func _on_card_flipped(card):
	# RACE CONDITION PROTECTION: Ignore if two cards are already being processed
	if not can_flip or flipped_cards.size() >= 2:
		card.is_face_up = false # Reset state silently
		card.flip_back()
		return

	flipped_cards.append(card)
	if flipped_cards.size() == 2:
		can_flip = false # Block all further clicks
		_check_match()

func _apply_card_texture(card_node, type_name):
	var img_path = "res://assets/" + type_name + ".png"
	if not textures.has(type_name) and FileAccess.file_exists(img_path):
		textures[type_name] = load(img_path)
	
	if textures.has(type_name) and card_node.has_method("set_icon_texture"):
		card_node.set_icon_texture(textures[type_name])

func _check_match():
	var c1 = flipped_cards[0]
	var c2 = flipped_cards[1]
	
	# Comparison delay
	await get_tree().create_timer(1.5).timeout
	
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
		_enemy_turn()
	
	flipped_cards.clear()

	if enemy_hp <= 0:
		_on_win()
		
	elif _should_reshuffle():
		add_log("No pairs remain. Reshuffling memory...")
		await get_tree().create_timer(1.0).timeout
		setup_board()
		can_flip = true

	else:
		can_flip = true

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


func _damage_enemy(amt):
	enemy_hp -= amt
	add_log("Hit! Enemy takes %d damage." % amt)
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

func _enemy_turn():
	_damage_player(8 + difficulty)

func _flash_unit(overlay, color):
	if not overlay: return
	overlay.color = color
	overlay.color.a = 0.5
	create_tween().tween_property(overlay, "color:a", 0.0, 0.4)

func _on_win():
	# 1. Update state and roll loot
	GameManager.mark_room_cleared(current_room.id)
	
	# 2. Go to the IMMEDIATE victory screen
	get_tree().change_scene_to_file("res://scenes/combat/VictoryScreen.tscn")

func _on_lose():
	# Loss usually ends the run, so we might go to RunSummary or DeathScreen
	get_tree().change_scene_to_file("res://scenes/ui/RunSummary.tscn")

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
