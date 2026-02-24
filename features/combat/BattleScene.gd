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
@onready var enemy_sprite = %EnemyPortraitSprite 
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
var current_enemy_res: EnemyData = null
var current_player_res: PlayerData = null

var active_tree = {}


func _ready():
	# 1. LOAD RESOURCE DATA
	var node_data = GameManager.current_node
	
	if node_data.has("room_resource_path") and FileAccess.file_exists(node_data.room_resource_path):
		current_room_res = load(node_data.room_resource_path) as RoomData
		_apply_room_data(current_room_res)
	else:
		# Fallback for manual scene testing
		var fallback_path = "res://data/rooms/town/town_village_gate.tres"
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
	
	# Debug win / lose connections
	if has_node("%DebugWinBtn"): %DebugWinBtn.pressed.connect(_on_win)
	if has_node("%DebugLoseBtn"): %DebugLoseBtn.pressed.connect(_on_lose)
	
	# 3. SETUP ENCOUNTER
	_setup_player_spritesheet()

	if not _setup_portraits():
		_handle_initialization_error("The guardian of this area has vanished into the void. Proceed to claim your rewards.")
		return

	# 4. START FLOW		
	_init_encounter()
	update_ui()

# --- SETUP METHODS ---
func _setup_player_spritesheet():
	# Identify the correct PlayerData resource based on class and stage
	# Format: res://data/players/[class]/[class]_[stage].tres
	var p_class = GameManager.player_class.to_lower()
	var p_stage = "base" # Logic here to determine stage based on progress/items
	
	var p_path = "res://data/players/%s/%s_%s.tres" % [p_class, p_class, p_stage]
	
	if ResourceLoader.exists(p_path):
		current_player_res = load(p_path) as PlayerData
		_apply_unit_visuals(player_sprite, current_player_res)
	else:
		push_warning("BattleScene: Player Resource missing: " + p_path)

func _setup_portraits() -> bool:
	# Returns true if enemy loaded successfully, false otherwise.
	if current_room_res and current_room_res.enemy_id != "":
		var e_path = "res://data/enemies/%s.tres" % current_room_res.enemy_id
		if ResourceLoader.exists(e_path):
			current_enemy_res = load(e_path) as EnemyData
			if current_enemy_res:
				# SAFE ACCESS: Property only accessed after we verify resource is not Nil
				enemy_hp = current_enemy_res.hp + (difficulty * 15)
				_apply_unit_visuals(enemy_sprite, current_enemy_res)
				return true

	push_error("BattleScene: Failed to load Enemy Resource.")
	return false

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
	if current_enemy_id: current_enemy_id = res.enemy_id
	if room_title: room_title.text = res.room_name
	if dialog_text: dialog_text.text = res.initial_dialog
	
	if background:
		if res.background_texture:
			background.texture = res.background_texture
		else:
			# Graceful fallback for missing room background
			background.texture = null
			background.modulate = Color(0.1, 0.1, 0.1) # Darken the empty space

func _handle_initialization_error(message: String):
	# Forces the scene into a non-crashing state and offers a way out
	battle_ui.visible = false
	dialog_overlay.visible = true
	dialog_text.text = message
	
	for child in option_container.get_children(): child.queue_free()
	var btn = Button.new()
	btn.text = "Claim Victory & Loot"
	btn.custom_minimum_size.y = 60
	btn.pressed.connect(_on_win)
	option_container.add_child(btn)


func _apply_unit_visuals(sprite: Node, res: Resource):
	if not sprite: return

	var sheet = res.get("idle_sheet") if res else null
	
	if sprite is Sprite2D:
		if sheet:
			sprite.texture = sheet
			sprite.hframes = res.get("hframes")
			sprite.vframes = res.get("vframes")
			_animate_unit(sprite, res.get("total_frames"), res.get("frame_speed"))
		else:
			# Visual placeholder for missing data
			sprite.texture = load("res://icon.svg")
			sprite.modulate = Color(1, 0, 0, 0.4)
			sprite.hframes = 1
			sprite.vframes = 1

func _animate_unit(sprite: Sprite2D, total: int, speed: float):
	var frame = 0
	var dir = 1
	while sprite and is_inside_tree():
		sprite.frame = frame
		if total > 1:
			if frame >= total - 1: dir = -1
			elif frame <= 0: dir = 1
			frame += dir
		await get_tree().create_timer(speed).timeout

func _init_encounter():
	battle_ui.hide()
	dialog_overlay.show()
	
	# Check if the resource specified a custom narrative branching tree
	var tree_id = ""
	if current_room_res: 
		tree_id = current_room_res.dialog_tree_id
	
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
