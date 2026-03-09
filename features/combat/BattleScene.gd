extends Node2D

# res://features/combat/BattleScene.gd
# Refactored for strict flip limits, proactive reshuffle, and extensible damage math.

# --- Layout Tuning (Adjust these in the Inspector) ---
@export_group("Environment Layout")
## Vertical position as a ratio of screen height (e.g. 0.2 is 20% from the bottom).
@export_range(0.0, 1.0) var ground_height_ratio: float = 0.2083 # ~150px from bottom on 720p (original baseline)
## Horizontal margin as a ratio of screen width (e.g. 0.1 is 10% from the edge).
@export_range(0.0, 0.5) var side_margin_ratio: float = 0.04 # ~51px from edge on 1280p (closer to edges)
## Vertical offset for the sprite texture center (usually half of sprite height).
@export var sprite_feet_offset: int = 0


@onready var grid = %GridContainer
@onready var log_box = %LogBox

# Status Bar References
@onready var biome_room_label = %BiomeRoomLabel
# @onready var conditions_container = %ConditionsContainer
@onready var round_label = %RoundLabel
@onready var energy_label = %EnergyLabel 
@onready var player_atk_val = %PlayerAtkVal
@onready var player_def_val = %PlayerDefVal
@onready var enemy_atk_val = %EnemyAtkVal
@onready var enemy_def_val = %EnemyDefVal

# Dynamic HP Bars
@onready var player_hp_bar = %PlayerHPBar
@onready var player_hp_text = %PlayerHPText
@onready var enemy_hp_bar = %EnemyHPBar
@onready var enemy_hp_text = %EnemyHPText

# UI Layers
@onready var dialog_overlay = %DialogOverlay
@onready var dialog_text = %DialogText
@onready var battle_ui = %UI 

# Unit Visuals
@onready var enemy_sprite = %EnemyPortraitSprite 
@onready var player_sprite = %PlayerSprite
@onready var background = get_node_or_null("%Background")
@onready var floor_rect = get_node_or_null("%FloorRect")

var card_scene = preload("res://features/combat/CardIcon.tscn")
var in_game_menu_scene = preload("res://features/ui/InGameMenu.tscn")

# --- Combat State ---
var flipped_cards: Array = []
var can_flip: bool = false 
var is_battle_over: bool = false
var difficulty: int = 0
var current_room_res: RoomData = null
var current_enemy_res: EnemyData = null
var in_game_menu = null
var is_cleared_room: bool = false

# Current Stats for Calculation
var p_hp: int = 1
var e_hp: int = 1
var max_e_hp: int = 1 

var p_atk: int = 0 # Base attack
var p_def: int = 0 # Base defense
var round_number: int = 1

var active_status_effects = {"player": [], "enemy": []} # e.g. ["vulnerable", "charged"]

func _ready():
	var node_data = GameManager.current_node
	difficulty = node_data["difficulty"] if "difficulty" in node_data else 1
	is_cleared_room = GameManager.is_room_cleared(str(node_data.get("id", "")))

	p_hp = GameManager.current_hp
	p_atk = GameManager.base_attack
	p_def = GameManager.base_defense

	if node_data.has("room_resource_path"):
		current_room_res = load(node_data.room_resource_path) as RoomData
		_apply_room_data(current_room_res)
	
	# Instance the In-Game Menu (Esc key)
	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()

	# Debug win / lose connections
	# if has_node("%DebugWinBtn"): %DebugWinBtn.pressed.connect(_debug_win)
	# if has_node("%DebugLoseBtn"): %DebugLoseBtn.pressed.connect(_debug_lose)

	_setup_player_spritesheet()
	if is_cleared_room:
		_setup_cleared_room_view()
	else:
		_setup_enemy_portrait()
		_init_encounter()
	
	# Music 
	SignalBus.music_change_requested.emit(AudioData.TRACKS["BATTLE_STANDARD"], 1.0)

	# Initial UI Sync
	_sync_status_bar()
	update_ui()
	_update_character_placement()
	get_viewport().size_changed.connect(_update_character_placement)

func _input(event):
	# Toggle In-Game Menu on Escape (ui_cancel)
	if event.is_action_pressed("ui_cancel"):
		if in_game_menu:
			if in_game_menu.visible: in_game_menu.close()
			else: in_game_menu.open()

	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		# PRESS 'B' TO TOGGLE BACKGROUND (Debugging hidden elements)
		if event.keycode == KEY_B:
			background.visible = !background.visible
			print("[DEBUG] Background Visibility: ", background.visible)
		
		# PRESS 'F' TO FORCE FLOOR REFRESH
		if event.keycode == KEY_F:
			_apply_room_data(current_room_res)


func _sync_stat_icons():
	# Sync Player Icons
	if player_atk_val: player_atk_val.text = str(p_atk)
	if player_def_val: player_def_val.text = str(p_def)
	
	# Sync Enemy Icons
	if current_enemy_res:
		enemy_atk_val.text = str(current_enemy_res.base_damage)
		enemy_def_val.text = str(current_enemy_res.armor)
	
	# Energy HUD
	if energy_label:
		energy_label.text = "⚡ ENERGY: %d" % GameManager.current_energy


func _sync_status_bar():
	# Biome | Room
	var biome_name = current_room_res.biome.capitalize() if current_room_res else "Unknown"
	var room_name = current_room_res.room_name if current_room_res else "Battle"
	biome_room_label.text = "%s  |  %s" % [biome_name, room_name]
	
	# Round
	round_label.text = "ROUND: %d" % round_number

# --- INPUT & FLOW ---
func _on_card_flipped(card):
	if is_battle_over or not can_flip:
		if is_instance_valid(card) and card.is_face_up and not card.is_matched:
			card.flip_back()
		return
	
	# ENERGY CHECK: Block more flips if energy is depleted
	if GameManager.current_energy <= 0:
		if is_instance_valid(card) and card.is_face_up and not card.is_matched:
			card.flip_back()
		return

	flipped_cards.append(card)
	
	# REDUCE ENERGY: Every click counts as a guess
	GameManager.current_energy = max(0, GameManager.current_energy - 1)
	_sync_stat_icons() # Update UI immediately
	
	_check_match()

func _check_match():
	flipped_cards = flipped_cards.filter(func(c): return is_instance_valid(c))
	
	# MULTI-TURN LOGIC: Look for the FIRST pair in the pool of turned cards
	var c1 = null
	var c2 = null
	
	for i in range(flipped_cards.size()):
		for j in range(i + 1, flipped_cards.size()):
			if flipped_cards[i].card_type == flipped_cards[j].card_type:
				c1 = flipped_cards[i]
				c2 = flipped_cards[j]
				break
		if c1: break
	
	if c1:
		# SUCCESS: Match Found
		can_flip = false 
		flipped_cards.erase(c1)
		flipped_cards.erase(c2)
		
		await get_tree().create_timer(0.4).timeout
		if not is_inside_tree() or is_battle_over: return
		if not (is_instance_valid(c1) and is_instance_valid(c2)): return
		
		c1.is_matched = true; c2.is_matched = true
		c1.modulate = Color(0.6, 1.2, 0.6); c2.modulate = Color(0.6, 1.2, 0.6)
		
		_process_combat_action(c1.card_type)
		update_ui()
		_check_win_loss()
		
		# Resolve the turn attempt since a match was found
		_resolve_turn_end()
		
	elif GameManager.current_energy <= 0:
		# FAILURE: Out of energy and no pairs exist in the turned cards
		can_flip = false
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree() or is_battle_over: return
		
		_enemy_turn()
		update_ui()
		_check_win_loss()
		_resolve_turn_end()

func _resolve_turn_end():
	if is_battle_over: return
	
	# Flip back any remaining unmatched cards in the current attempt pool
	for card in flipped_cards:
		if is_instance_valid(card):
			card.flip_back()
	flipped_cards.clear()
	
	# CHECK RESHUFFLE: Only if no pairs remain on board (ignoring energy)
	if _should_reshuffle():
		_trigger_reshuffle()
	else:
		# Reset energy for the next set of guesses
		GameManager.current_energy = GameManager.base_energy if "base_energy" in GameManager else 2
		_sync_stat_icons()
		can_flip = true
		_toggle_grid_interaction(true)

func _post_resolution_check():
	if is_battle_over: return
	
	if GameManager.current_energy <= 0:
		add_log("Out of energy! Turn ends.")
		for card in flipped_cards:
			if is_instance_valid(card):
				card.flip_back()
		flipped_cards.clear()
		
		await get_tree().create_timer(0.8).timeout
		_trigger_reshuffle()
	elif _should_reshuffle():
		_trigger_reshuffle()
	else:
		can_flip = true
		_toggle_grid_interaction(true)

func _toggle_grid_interaction(enabled: bool):
	for card in grid.get_children():
		if card is TextureButton:
			card.disabled = not enabled or card.is_matched

# --- DAMAGE CALCULATION (Extensible) ---
func _process_combat_action(card_id: String):
	var res = DataManager.get_resource("res://data/cards/" + card_id + ".tres")
	if not res: return
	
	var type = "magical" if card_id in ["frost", "lightning", "bomb", "scroll"] else "physical"
	
	if res.value > 0:
		if res.type == "attack":
			var final_dmg = _calculate_final_damage(res.value, type, "player", "enemy")
			e_hp = max(0, e_hp - final_dmg)
			add_log("Matched %s: Dealt %d damage." % [res.name, final_dmg])
			_flash_unit(%EnemyFlash, Color.CRIMSON)
			SignalBus.battle_intensity_changed.emit(0.5)
			SignalBus.sfx_triggered.emit(AudioData.SFX["SWORD"])

		elif res.type == "trap":
			var trap_dmg = res.value
			p_hp = max(0, p_hp - trap_dmg)
			add_log("Matched %s: Took %d damage." % [res.name, res.value])
			_flash_unit(%PlayerFlash, Color.ORANGE_RED)
			SignalBus.battle_intensity_changed.emit(0.5)
			SignalBus.sfx_triggered.emit(AudioData.SFX["TRAP"])

		elif res.type == "heal":
			p_hp = min(GameManager.max_hp, p_hp + res.value)
			add_log("Matched %s: Restored %d HP." % [res.name, res.value])
			_flash_unit(%PlayerFlash, Color.SEA_GREEN)
			SignalBus.battle_intensity_changed.emit(0.5)
			SignalBus.sfx_triggered.emit(AudioData.SFX["HEAL"])

		# Block 
		# SignalBus.battle_intensity_changed.emit(0.5)
		# SignalBus.sfx_triggered.emit(AudioData.SFX["SHIELD"])

func _calculate_final_damage(card_val: int, type: String, attacker: String, defender: String) -> int:
	var total = card_val
	
	# A. Add Base Stats
	if attacker == "player":
		if type == "physical": total += p_atk 
		else: total += 0 # Placeholder for spell 
	else:
		# Enemy scaling
		var enemy_base = current_enemy_res.base_damage if current_enemy_res else 5
		total += enemy_base
		
	# B. Subtract Defense
	if defender == "enemy":
		var arm = current_enemy_res.armor if current_enemy_res else 0
		var res = 0 # Placeholder for enemy magic resist
		total -= (arm if type == "physical" else res)
	else:
		# Player defense
		total -= p_def 
		
	# C. Status Effect Multipliers
	if active_status_effects[defender].has("vulnerable"):
		total = int(total * 1.5)
	if active_status_effects[attacker].has("charged"):
		total += 10
		active_status_effects[attacker].erase("charged") # Consume charge
		
	return max(1, total) # Ensure at least 1 damage is dealt

func _enemy_turn():
	# Simple enemy attack using the same formula logic
	var base_dmg = current_enemy_res.base_damage
	var final_dmg = _calculate_final_damage(base_dmg, "physical", "enemy", "player")
	p_hp -= final_dmg
	add_log("Enemy strikes for %d damage." % final_dmg)
	_flash_unit(%PlayerFlash, Color.CRIMSON)

# --- BOARD MANAGEMENT ---
func _should_reshuffle() -> bool:
	var counts = {}
	var unmatched_count = 0
	
	for card in grid.get_children():
		if is_instance_valid(card) and not card.is_matched:
			unmatched_count += 1
			# Traps are unmatchable in this pool, so we only count pairs for other types
			if card.card_type != "trap":
				var current_count = counts[card.card_type] if card.card_type in counts else 0
				counts[card.card_type] = current_count + 1
	
	# If only 1 card (like the trap) is left, it's impossible to match.
	if unmatched_count <= 1:
		return true

	# If no card type has at least 2 instances remaining, no pairs exist.
	for type in counts:
		if counts[type] >= 2: 
			return false
			
	return true

func _trigger_reshuffle():
	can_flip = false
	_toggle_grid_interaction(false)
	add_log("The path is blocked. Shuffling memories...")
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree() and not is_battle_over:
		setup_board()
		can_flip = true
		_toggle_grid_interaction(true)

# --- UTILS & VISUALS ---

func _init_encounter():
	battle_ui.hide()
	dialog_overlay.show()
	for child in %OptionContainer.get_children(): child.queue_free()
	var btn = Button.new()
	btn.text = "Enter Combat"; btn.custom_minimum_size.y = 50
	btn.pressed.connect(func():
		dialog_overlay.hide(); battle_ui.show()
		can_flip = true; setup_board()
	)
	%OptionContainer.add_child(btn)

func _setup_cleared_room_view():
	battle_ui.hide()
	dialog_overlay.show()
	if enemy_sprite:
		enemy_sprite.visible = false
	if has_node("%EnemyFlash"):
		%EnemyFlash.visible = false
	for child in %OptionContainer.get_children():
		child.queue_free()
	dialog_text.text = "This room has already been cleared."
	var exit_btn = Button.new()
	exit_btn.text = "Exit to Overworld"
	exit_btn.custom_minimum_size.y = 50
	exit_btn.pressed.connect(_exit_cleared_room)
	%OptionContainer.add_child(exit_btn)

func _exit_cleared_room():
	if GameManager.is_battle_mode:
		get_tree().change_scene_to_file("res://features/map/BattleMap.tscn")
	else:
		get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")

func _check_win_loss():
	if is_battle_over: return
	
	if e_hp <= 0:
		is_battle_over = true
		GameManager.current_hp = p_hp
		var xp_reward = current_enemy_res.xp_reward if current_enemy_res else 0
		var xp_result = GameManager.add_player_xp(xp_reward)
		GameManager.mark_room_cleared(GameManager.current_node.id)
		if xp_result.get("leveled_up", false):
			GameManager.level_up_return_scene = "res://features/combat/VictoryScreenBattleMode.tscn" if GameManager.is_battle_mode else "res://features/combat/VictoryScreen.tscn"
			get_tree().call_deferred("change_scene_to_file", "res://features/ui/CharacterLevelUp.tscn")
			return
		
		# GLOBAL ROUTING: Battle Mode vs standard World Mode
		if GameManager.is_battle_mode:
			# Experience gain logic could be added here
			get_tree().call_deferred("change_scene_to_file", "res://features/combat/VictoryScreenBattleMode.tscn")
		else:
			get_tree().call_deferred("change_scene_to_file", "res://features/combat/VictoryScreen.tscn")
			
	elif p_hp <= 0:
		is_battle_over = true
		if GameManager.is_battle_mode:
			# In battle mode, death just sends you back to map (or specific restart)
			get_tree().call_deferred("change_scene_to_file", "res://features/map/BattleMapUI.tscn")
		else:
			get_tree().call_deferred("change_scene_to_file", "res://features/ui/RunSummary.tscn")


func update_ui(instant: bool = false):
	# Dynamic Text update
	player_hp_text.text = "%d / %d" % [p_hp, GameManager.max_hp]
	enemy_hp_text.text = "HP: %d" % e_hp
	
	# Dynamic Bar update with Tween
	var duration = 0.0 if instant else 0.4
	
	if player_hp_bar:
		player_hp_bar.max_value = GameManager.max_hp
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(player_hp_bar, "value", p_hp, duration)
	
	if enemy_hp_bar:
		enemy_hp_bar.max_value = max_e_hp
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(enemy_hp_bar, "value", e_hp, duration)

	_sync_stat_icons()
	round_label.text = "ROUND: %d" % round_number
	
func add_log(text):
	var lbl = Label.new(); lbl.text = "> " + text; log_box.add_child(lbl)
	# Auto-scroll logic if needed
	
func _flash_unit(overlay, color):
	if not overlay: return
	overlay.color = color; overlay.color.a = 0.5
	create_tween().tween_property(overlay, "color:a", 0.0, 0.4)

# --- VISUAL HELPERS ---
func _setup_player_spritesheet():
	var idle_tex = load("res://assets/player/base_idle.png")
	if idle_tex:
		player_sprite.texture = idle_tex
		player_sprite.hframes = 8
		player_sprite.vframes = 1
		player_sprite.scale = Vector2(1.0, 1.0)
		player_sprite.offset.y = sprite_feet_offset
		_animate_unit(player_sprite, 8, 0.12)

func _setup_enemy_portrait():
	var e_path = ""
	
	# 1. Attempt to resolve path from the current room metadata
	if current_room_res and current_room_res.enemy_id != "":
		e_path = "res://data/enemies/%s.tres" % current_room_res.enemy_id
	
	# 2. Default: If room has no enemy or resource is missing, load default enemy
	if e_path == "" or not ResourceLoader.exists(e_path):
		e_path = "res://data/enemies/pickpocket.tres"
		
	# 3. Final load and assignment
	if ResourceLoader.exists(e_path):
		current_enemy_res = load(e_path) as EnemyData
		if current_enemy_res:
			max_e_hp = current_enemy_res.hp
			e_hp = max_e_hp 
			if enemy_sprite:
				enemy_sprite.offset.y = sprite_feet_offset
				enemy_sprite.flip_h = true
				_apply_unit_visuals(enemy_sprite, current_enemy_res)


func _animate_unit(sprite: Sprite2D, total: int, speed: float):
	var frame = 0; var dir = 1
	while sprite and is_inside_tree():
		sprite.frame = frame
		if total > 1:
			if frame >= total - 1: dir = -1
			elif frame <= 0: dir = 1
			frame += dir
		await get_tree().create_timer(speed).timeout

func _apply_unit_visuals(sprite: Sprite2D, res: Resource):
	if not sprite or not res: return
	var sheet = res.get("idle_sheet")
	if sheet:
		sprite.texture = sheet
		
		var h = res.get("hframes")
		sprite.hframes = h if h != null else 8
		var v = res.get("vframes")
		sprite.vframes = v if v != null else 1
		
		# Set to 2x size (1.0 scale)
		sprite.scale = Vector2(1.0, 1.0)
		
		var total = res.get("total_frames")
		var speed = res.get("frame_speed")
		_animate_unit(sprite, total if total != null else 8, speed if speed != null else 0.1)
		_update_character_placement()
		
func setup_board():

	# Clear any existing tracking to prevent stale references 
	flipped_cards.clear()
	
	# ENERGY INITIALIZATION: Reset energy when a new board is generated
	GameManager.current_energy = GameManager.base_energy if "base_energy" in GameManager else 2
	round_number += 1

	for child in grid.get_children(): child.queue_free()

	# 1. Determine Grid Size
	var size = 3
	if difficulty >= 3: size = 4
	if difficulty >= 6: size = 5
	if difficulty >= 9: size = 6
	grid.columns = size
	
	var total_slots = size * size
	var pair_count = floor(total_slots / 2.0)
	
	# 2. Build the Deck Pool
	# Start with the player's active deck selection
	var deck_pool = GameManager.active_deck.duplicate()
	deck_pool.shuffle()

	# 3. Fill gaps from player deck (Rarity-Weighted)
	while deck_pool.size() < pair_count:
		var extra_card = _get_weighted_random_card_from_collection()
		if extra_card != "":
			deck_pool.append(extra_card)
		else:
			# Absolute safety fallback if player_deck is empty
			deck_pool.append("sword") 

	# 4. Create the Grid (Duplicate into pairs)
	var selected_ids = deck_pool.slice(0, pair_count)
	var final_grid_ids = []
	for id in selected_ids:
		final_grid_ids.append(id); final_grid_ids.append(id)
	
	# Add the Trap card if grid is odd (e.g. 3x3)
	if final_grid_ids.size() < total_slots: final_grid_ids.append("trap")
	final_grid_ids.shuffle()
	
	# 5. Instantiate Cards
	var card_dim = floor((450.0 - (12.0 * (size + 1.0))) / float(size))
	for card_id in final_grid_ids:
		var c = card_scene.instantiate(); grid.add_child(c)
		c.custom_minimum_size = Vector2(card_dim, card_dim)
		var res_path = "res://data/cards/%s.tres" % card_id
		if FileAccess.file_exists(res_path): c.setup(load(res_path))
		else: c.card_type = card_id
		c.card_flipped.connect(_on_card_flipped)

	# Final UI updates 
	_sync_stat_icons()
	

func _get_weighted_random_card_from_collection() -> String:
	var collection = GameManager.player_deck # The total list of owned card IDs
	if collection.is_empty(): return ""
	
	# Weight Map based on Card Rarity
	var weights = {
		"common": 100,
		"uncommon": 50,
		"rare": 20,
		"epic": 10,
		"unique": 5
	}
	
	var candidates = []
	var total_weight = 0
	
	for card_id in collection:
		var res = DataManager.get_resource("res://data/cards/" + card_id + ".tres")
		var rarity = "common"
		if res and "rarity" in res:
			rarity = res.rarity.to_lower()
		
		var w = weights[rarity] if rarity in weights else 10
		candidates.append({"id": card_id, "weight": w})
		total_weight += w
		
	# Random roll within total weight
	var roll = randi() % total_weight
	var current_sum = 0
	for item in candidates:
		current_sum += item.weight
		if roll < current_sum:
			return item.id
			
	return collection.pick_random()

func _apply_room_data(res: RoomData):
	if has_node("%RoomTitle"): %RoomTitle.text = res.room_name
	if has_node("%DialogText"): %DialogText.text = res.initial_dialog
	
	# 1. Load Background
	if background and res.background_texture: 
		background.texture = res.background_texture
	
	# 2. Dynamic Floor Loading (Bottom 200px)
	if floor_rect:
		var biome = res.biome if res.biome != "" else "town"
		# Adjusted path to match standard project structure
		var floor_path = "res://assets/rooms/floor/%s_floor.png" % biome.to_lower()
		if ResourceLoader.exists(floor_path):
			floor_rect.texture = load(floor_path)
			floor_rect.visible = true
		else:
			# Fallback if specific file is missing
			print("[BattleScene] Floor texture missing: ", floor_path)
			floor_rect.visible = false


func _update_character_placement():
	var v_size = get_viewport_rect().size
	var floor_mid_y = _get_floor_midline_y(v_size)
	var edge_margin = v_size.x * side_margin_ratio
	var player_half_w = _get_sprite_half_width(player_sprite)
	var enemy_half_w = _get_sprite_half_width(enemy_sprite)
	var player_half_h = _get_sprite_half_height(player_sprite)
	var enemy_half_h = _get_sprite_half_height(enemy_sprite)
	
	if player_sprite: 
		player_sprite.offset.y = sprite_feet_offset
		player_sprite.position = Vector2(
			edge_margin + player_half_w,
			floor_mid_y - player_half_h - player_sprite.offset.y
		)
		
	if enemy_sprite: 
		enemy_sprite.offset.y = sprite_feet_offset
		enemy_sprite.position = Vector2(
			v_size.x - edge_margin - enemy_half_w,
			floor_mid_y - enemy_half_h - enemy_sprite.offset.y
		)

func _get_sprite_half_width(sprite: Sprite2D) -> float:
	if not sprite or not sprite.texture:
		return 0.0
	var frame_count = max(1, sprite.hframes)
	var frame_width = float(sprite.texture.get_width()) / float(frame_count)
	return (frame_width * abs(sprite.scale.x)) * 0.5

func _get_sprite_half_height(sprite: Sprite2D) -> float:
	if not sprite or not sprite.texture:
		return 0.0
	var frame_count = max(1, sprite.vframes)
	var frame_height = float(sprite.texture.get_height()) / float(frame_count)
	return (frame_height * abs(sprite.scale.y)) * 0.5

func _get_floor_midline_y(view_size: Vector2) -> float:
	if floor_rect and floor_rect.visible:
		var floor_bounds = floor_rect.get_global_rect()
		return floor_bounds.position.y + (floor_bounds.size.y * 0.5)
	return view_size.y * (1.0 - ground_height_ratio)

func _debug_win():
	get_tree().call_deferred("change_scene_to_file", "res://features/combat/VictoryScreen.tscn")

func _debug_lose():
	get_tree().call_deferred("change_scene_to_file", "res://features/ui/RunSummary.tscn")
