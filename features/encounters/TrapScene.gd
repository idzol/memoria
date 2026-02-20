extends Node2D

# res://features/encounters/TrapScene.gd
# Logic: Find 2 Escape cards. Every other card is a Trap that deals damage.

const GameData = preload("res://core/GameData.gd")

@onready var grid = %GridContainer
@onready var player_hp_label = %PlayerHP
@onready var progress_label = %ProgressLabel
@onready var status_label = %StatusLabel
@onready var log_box = %LogBox
@onready var player_portrait_sprite = %PlayerPortraitSprite

var card_scene = preload("res://features/combat/Card.tscn")

# --- Trap State ---
var escapes_found = 0
var can_click = true
var difficulty = 1
var player_hp = 100
var current_room = {}

func _ready():
	# 1. Initialize Data
	current_room = GameManager.current_node
	difficulty = current_room.get("difficulty", 1)
	player_hp = GameManager.current_hp
	
	# 2. Setup UI
	_setup_visuals()
	_update_ui_text()
	
	# 3. Setup Board
	setup_trap_board()
	add_log("The ground trembles. Find the escape mechanisms quickly.")

func _setup_visuals():
	var player_path = "res://assets/player/base.png"
	if ResourceLoader.exists(player_path):
		player_portrait_sprite.texture = load(player_path)
	
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 30)

func setup_trap_board():
	for child in grid.get_children(): child.queue_free()
	
	# Increase grid size based on difficulty
	var size = 2 # 2x2 (4 slots)
	if difficulty >= 3: size = 3 # 3x3 (9 slots)
	if difficulty >= 6: size = 4 # 4x4 (16 slots)
	
	grid.columns = size
	var total_slots = size * size
	
	# Build deck: 2 Escapes, rest are Traps
	var deck = []
	deck.append("key") # Escape 1
	deck.append("scroll") # Escape 2 (knowledge is the way out)
	
	while deck.size() < total_slots:
		deck.append("trap")
	
	deck.shuffle()
	
	for type_name in deck:
		var new_card = card_scene.instantiate()
		grid.add_child(new_card)
		new_card.card_type = type_name
		new_card.card_flipped.connect(_on_card_flipped)
		
		# Adjust sizing
		var card_width = 140 if size == 2 else (100 if size == 3 else 80)
		new_card.custom_minimum_size = Vector2(card_width, card_width * 1.3)
		
		_apply_card_texture(new_card, type_name)

func _apply_card_texture(card_node, type_name):
	var img_path = "res://assets/" + type_name + ".png"
	if ResourceLoader.exists(img_path):
		card_node.set_icon_texture(load(img_path))

func _on_card_flipped(card):
	if not can_click or card.is_matched: 
		card.flip_back()
		return
	
	if card.card_type == "key" or card.card_type == "scroll":
		# Found an Escape
		escapes_found += 1
		card.is_matched = true # Keep it flipped
		card.modulate = Color(0.5, 1.0, 0.5)
		add_log("Escape mechanism triggered! (%d/2)" % escapes_found)
		
		if escapes_found >= 2:
			_on_victory()
	else:
		# Hit a Trap
		can_click = false
		_trigger_trap_damage()
		await get_tree().create_timer(0.8).timeout
		card.flip_back()
		can_click = true
	
	_update_ui_text()

func _trigger_trap_damage():
	var damage = 10 + (difficulty * 2)
	player_hp -= damage
	add_log("Trap sprung! Took %d damage." % damage)
	_flash_unit(%PlayerFlash, Color.CRIMSON)
	
	if player_hp <= 0:
		GameManager.current_hp = 0
		get_tree().change_scene_to_file("res://features/ui/RunSummary.tscn")

func _flash_unit(overlay, color):
	overlay.color = color
	overlay.color.a = 0.5
	create_tween().tween_property(overlay, "color:a", 0.0, 0.4)

func _on_victory():
	can_click = false
	add_log("The way is clear. You escape the trap.")
	await get_tree().create_timer(1.0).timeout
	GameManager.current_hp = player_hp
	GameManager.mark_room_cleared(current_room.id)
	get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")

func _update_ui_text():
	player_hp_label.text = "HP: %d/%d" % [player_hp, GameManager.max_hp]
	progress_label.text = "Escapes Found: %d/2" % escapes_found
	
	if difficulty < 3: status_label.text = "DANGER: MODERATE"
	elif difficulty < 6: status_label.text = "DANGER: HIGH"
	else: status_label.text = "DANGER: EXTREME"

func add_log(text):
	var lbl = Label.new()
	lbl.text = "> " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_box.add_child(lbl)
	await get_tree().process_frame
	var scroll = log_box.get_parent()
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value