extends Node2D

# res://features/combat/BattleScene.gd
# Refactored to load data from RoomData Resources (.tres)

@onready var grid = %GridContainer
@onready var player_hp_label = %PlayerHP
@onready var enemy_hp_label = %EnemyHP
@onready var log_box = %LogBox

# Dialog UI
@onready var dialog_overlay = %DialogOverlay
@onready var dialog_text = %DialogText
@onready var room_title = %RoomTitle
@onready var option_container = %OptionContainer
@onready var battle_ui = %UI 

# Portraits & Background
@onready var enemy_portrait_sprite = %EnemyPortraitSprite
@onready var player_sprite = %PlayerSprite
@onready var idle_timer = %IdleTimer
@onready var background = get_node_or_null("%Background")

var card_scene = preload("res://features/combat/Card.tscn")

# --- Animation State ---
var is_animating_idle: bool = false
var current_anim_frame: int = 0
const TOTAL_ANIM_FRAMES = 18
const FRAME_STEP_TIME = 0.08 # Approx 12 FPS for the blink/idle


# --- Combat State ---
var flipped_cards = []
var can_flip = false 
var player_hp = 100
var enemy_hp = 100 
var textures = {}
var difficulty = 0
var current_enemy_id: String = ""
var current_room_res: RoomData = null
var active_tree = {}

func _ready():
	# 1. LOAD RESOURCE DATA
	var node_data = GameManager.current_node
	
	if node_data.has("room_resource_path") and FileAccess.file_exists(node_data.room_resource_path):
		current_room_res = load(node_data.room_resource_path) as RoomData
		_apply_room_data(current_room_res)
	else:
		# Fallback for manual scene testing (Ensure this path exists)
		var fallback_path = "res://data/rooms/default_battle.tres"
		if FileAccess.file_exists(fallback_path):
			current_room_res = load(fallback_path) as RoomData
			_apply_room_data(current_room_res)
		else:
			push_warning("BattleScene: No RoomData resource found. Using empty defaults.")

	# 2. INITIALIZE LOGIC
	difficulty = node_data.get("difficulty", 1)
	player_hp = GameManager.current_hp
	
	if not grid:
		push_error("BattleScene Error: GridContainer not found.")
		return

	grid.add_theme_constant_override("h_separation", 35)
	grid.add_theme_constant_override("v_separation", 35)
	
	# Debug win / lose 
	%DebugWinBtn.pressed.connect(_on_win)
	%DebugLoseBtn.pressed.connect(_on_lose)
	
	# 3. SETUP ENCOUNTER
	_setup_player_spritesheet()
	_setup_portraits()

	# 4. Start Flow		
	_init_encounter()
	update_ui()


func _setup_player_spritesheet():
	# CONFIG: 6 Columns, 34 Frames total. Cells are 240x360.
	var sheet_path = "res://assets/player/idle.png"
	if ResourceLoader.exists(sheet_path):
		player_sprite.texture = load(sheet_path)
		player_sprite.hframes = 6
		player_sprite.vframes = 6   
		player_sprite.frame = 0
		
		# Connect the 30s trigger timer
		if not idle_timer.timeout.is_connected(_play_idle_animation):
			idle_timer.timeout.connect(_play_idle_animation)
	else:
		push_warning("BattleScene: Player spritesheet missing at: " + sheet_path)

func _play_idle_animation():
	if is_animating_idle: return
	is_animating_idle = true
	current_anim_frame = 0
	_cycle_frame()


func _cycle_frame():
	if current_anim_frame < TOTAL_ANIM_FRAMES:
		player_sprite.frame = current_anim_frame
		current_anim_frame += 1
		# Recursive step for manual frame control
		get_tree().create_timer(FRAME_STEP_TIME).timeout.connect(_cycle_frame)
	else:
		# Animation finished, return to static first frame
		player_sprite.frame = 0
		is_animating_idle = false


func _apply_room_data(res: RoomData):
	if not res: return
	room_title.text = res.room_name
	dialog_text.text = res.initial_dialog
	current_enemy_id = res.enemy_id
	
	if background and res.background_texture:
		background.texture = res.background_texture

func _setup_portraits():
	# Load Enemy Portrait/Stats from GameData using ID from the Resource
	var icon_path = "res://assets/card/trap.png"
	
	if GameData.ENEMIES.has(current_enemy_id):
		var data = GameData.ENEMIES[current_enemy_id]
		icon_path = data.icon
		enemy_hp = data.hp + (difficulty * 15)
	
	# Enemy default
	enemy_portrait_sprite.texture = load(icon_path)
	# player_portrait_sprite.texture = load("res://assets/enemy/base.png")

func _init_encounter():
	battle_ui.hide()
	dialog_overlay.show()
	
	# Check if the resource specified a custom narrative branching tree
	var tree_id = ""
	if current_room_res: tree_id = current_room_res.dialog_tree_id
	
	if tree_id != "" and GameData.DIALOG_TREES.has(tree_id):
		active_tree = GameData.DIALOG_TREES[tree_id]
		_display_tree_node("start")
	else:
		_setup_basic_dialog()

func _display_tree_node(node_id: String):
	var node = active_tree.get(node_id)
	if !node: return
	
	dialog_text.text = node.text
	for child in option_container.get_children(): child.queue_free()
	
	for opt in node.options:
		var btn = Button.new()
		btn.text = opt.text
		btn.pressed.connect(func(): _handle_dialog_choice(opt))
		option_container.add_child(btn)

func _handle_dialog_choice(opt: Dictionary):
	if opt.has("next_node"):
		_display_tree_node(opt.next_node)
	elif opt.get("action") == "battle":
		_start_combat()
	else:
		_on_win()

func _setup_basic_dialog():
	for child in option_container.get_children(): child.queue_free()
	var btn = Button.new()
	btn.text = "Engage in Combat"
	btn.pressed.connect(_start_combat)
	option_container.add_child(btn)

func _start_combat():
	dialog_overlay.hide()
	battle_ui.show()
	can_flip = true
	setup_board()
	add_log("The board manifests. Current enemy: %s" % current_enemy_id.capitalize())

# --- Board Logic ---

func setup_board():
	for child in grid.get_children(): child.queue_free()
		
	var size = clampi(2 + floor(difficulty / 2.0), 2, 6)
	grid.columns = size
	var total_slots = size * size
	var pair_count = floor(total_slots / 2.0)
	
	# DYNAMIC POOL: Pull specifically from player's inventory deck
	var player_deck = GameManager.active_deck.duplicate()
	player_deck.shuffle()
	
	# Select unique types from active deck to make pairs
	var selected_types = player_deck.slice(0, pair_count)
	
	# If deck is too small, pad with basic 'fist'
	while selected_types.size() < pair_count:
		selected_types.append("fist")
	
	var deck = []
	for t in selected_types:
		deck.append(t); deck.append(t)
		
	# Fill odd center slot
	if deck.size() < total_slots:
		deck.append("trap")
		
	deck.shuffle()
	
	# Calculate sizing for square container
	var card_width = floor((550.0 - (35.0 * (size + 1.0))) / float(size))
	
	for type_name in deck:
		var new_card = card_scene.instantiate()
		grid.add_child(new_card)
		new_card.card_type = type_name
		new_card.card_flipped.connect(_on_card_flipped)
		new_card.custom_minimum_size = Vector2(card_width, card_width * 1.4)
		_apply_card_texture(new_card, type_name)

func _apply_card_texture(card_node, type_name):
	var data = CardDatabase.get_card(type_name)
	if data and card_node.has_method("set_icon_texture"):
		card_node.set_icon_texture(load(data.icon))

func _on_card_flipped(card):
	if not can_flip or flipped_cards.size() >= 2:
		card.flip_back()
		return

	flipped_cards.append(card)
	if flipped_cards.size() == 2:
		can_flip = false
		_check_match()

func _check_match():
	var c1 = flipped_cards[0]; var c2 = flipped_cards[1]
	await get_tree().create_timer(1.2).timeout
	
	if c1.card_type == c2.card_type:
		c1.is_matched = true; c2.is_matched = true
		c1.modulate = Color(0.6, 1.0, 0.6); c2.modulate = Color(0.6, 1.0, 0.6)
		c1.z_index = 0; c2.z_index = 0
		c1.scale = Vector2.ONE; c2.scale = Vector2.ONE
		
		_process_match_action(c1.card_type)
	else:
		c1.flip_back(); c2.flip_back()
		_enemy_turn()
	
	flipped_cards.clear()
	update_ui()

	if enemy_hp <= 0:
		_on_win()
	elif _should_reshuffle():
		add_log("No pairs remain. Reshuffling...")
		await get_tree().create_timer(1.0).timeout
		setup_board()
		can_flip = true
	else:
		can_flip = true

func _should_reshuffle() -> bool:
	var counts = {}
	for card in grid.get_children():
		if not card.is_matched and card.card_type != "trap":
			counts[card.card_type] = counts.get(card.card_type, 0) + 1
	for type in counts:
		if counts[type] >= 2: return false
	return true

func _process_match_action(type):
	var data = CardDatabase.get_card(type)
	var stats = data.get("stats", {})
	
	if stats.get("damage", 0) > 0:
		enemy_hp -= stats.damage
		_flash_unit(%EnemyFlash, Color.CRIMSON)
	if stats.get("heal", 0) > 0:
		player_hp = min(GameManager.max_hp, player_hp + stats.heal)
		_flash_unit(%PlayerFlash, Color.SEA_GREEN)
	if stats.get("trap", 0) > 0:
		player_hp -= stats.trap
		_flash_unit(%PlayerFlash, Color.CRIMSON)

func _enemy_turn():
	var dmg = 8 + difficulty
	player_hp -= dmg
	add_log("Enemy attacks for %d damage." % dmg)
	_flash_unit(%PlayerFlash, Color.CRIMSON)
	if player_hp <= 0: _on_lose()

func _flash_unit(overlay, color):
	if not overlay: return
	overlay.color = color; overlay.color.a = 0.5
	create_tween().tween_property(overlay, "color:a", 0.0, 0.4)

func update_ui():
	player_hp_label.text = "%d/%d" % [player_hp, GameManager.max_hp]
	enemy_hp_label.text = "HP: %d" % enemy_hp

func add_log(text):
	if log_box:
		var lbl = Label.new()
		lbl.text = "> " + text; lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_box.add_child(lbl)
		await get_tree().process_frame
		var scroll = log_box.get_parent().get_parent()
		if scroll is ScrollContainer: scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _on_win():
	GameManager.current_hp = player_hp
	GameManager.mark_room_cleared(GameManager.current_node.id)
	get_tree().change_scene_to_file("res://features/combat/VictoryScreen.tscn")

func _on_lose():
	get_tree().change_scene_to_file("res://features/ui/RunSummary.tscn")
