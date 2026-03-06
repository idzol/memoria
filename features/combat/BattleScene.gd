extends Node2D

# res://features/combat/BattleScene.gd
# Refactored for strict flip limits, proactive reshuffle, and extensible damage math.

@onready var grid = %GridContainer
@onready var log_box = %LogBox

# Status Bar References
@onready var biome_room_label = %BiomeRoomLabel
@onready var player_stats_label = %PlayerStatsLabel
@onready var conditions_container = %ConditionsContainer
@onready var round_label = %RoundLabel
@onready var settings_btn = %SettingsBtn

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

var card_scene = preload("res://features/combat/CardIcon.tscn")

# --- Combat State ---
var flipped_cards: Array = []
var can_flip: bool = false 
var is_battle_over: bool = false
var difficulty: int = 0
var current_room_res: RoomData = null
var current_enemy_res: EnemyData = null

# Current Stats for Calculation
var p_hp: int = 100
var e_hp: int = 100
var p_atk: int = 10 # Base attack
var p_def: int = 5  # Base defense
var round_number: int = 1

var active_status_effects = {"player": [], "enemy": []} # e.g. ["vulnerable", "charged"]

func _ready():
	var node_data = GameManager.current_node
	difficulty = node_data.get("difficulty", 1)
	p_hp = GameManager.current_hp
	
	if node_data.has("room_resource_path"):
		current_room_res = load(node_data.room_resource_path) as RoomData
		_apply_room_data(current_room_res)
	
	# Debug win / lose connections
	if has_node("%DebugWinBtn"): %DebugWinBtn.pressed.connect(_debug_win)
	if has_node("%DebugLoseBtn"): %DebugLoseBtn.pressed.connect(_debug_lose)

	# Connect Settings
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	_sync_status_bar()
	_setup_player_spritesheet()
	_setup_enemy_portrait()
	_init_encounter()
	
	# Music 
	SignalBus.music_change_requested.emit(AudioData.TRACKS["BATTLE_STANDARD"], 1.0)

	# Initial UI Sync
	_sync_status_bar()
	update_ui()


func _sync_status_bar():
	# Biome | Room
	var biome_name = current_room_res.biome.capitalize() if current_room_res else "Unknown"
	var room_name = current_room_res.room_name if current_room_res else "Battle"
	biome_room_label.text = "%s  |  %s" % [biome_name, room_name]
	
	# Stats
	player_stats_label.text = "ATK: %d   DEF: %d" % [p_atk, p_def]
	
	# Round
	round_label.text = "ROUND: %d" % round_number

# --- INPUT & FLOW ---
func _on_card_flipped(card):
	# Block if busy or over
	if is_battle_over or not can_flip or flipped_cards.size() >= 2:
		if card.is_face_up and not card.is_matched:
			card.flip_back()
		return
	
	flipped_cards.append(card)

	# If we hit 2 cards, lock everything instantly
	if flipped_cards.size() == 2:
		can_flip = false 
		_toggle_grid_interaction(false) 
		_check_match()

func _check_match():
	var c1 = flipped_cards[0]
	var c2 = flipped_cards[1]
	
	# Small delay to let player process the icons
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree() or is_battle_over: return
	
	if c1.card_type == c2.card_type:
		# SUCCESS: Match
		c1.is_matched = true; c2.is_matched = true
		c1.modulate = Color(0.6, 1.2, 0.6)
		c2.modulate = Color(0.6, 1.2, 0.6)
		_process_combat_action(c1.card_type)
	else:
		# FAILURE: Flip back
		c1.flip_back()
		c2.flip_back()
		_enemy_turn()
		
	flipped_cards.clear()
	update_ui()
	_check_win_loss()
	
	# AUTO-RESHUFFLE CHECK: Triggered after the match state is resolved
	if not is_battle_over:
		if _should_reshuffle():
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
	var data = CardDatabase.get_card(card_id)
	var stats = data.get("stats", {})
	
	# Identify Damage Type (Physical vs Magical)
	var type = "physical"
	if card_id in ["frost", "lightning", "bomb", "scroll"]: type = "magical"
	
	# 1. Damage Execution
	if stats.get("damage", 0) > 0:
		var final_dmg = _calculate_final_damage(stats.damage, type, "player", "enemy")
		e_hp = max(0, e_hp - final_dmg)
		add_log("Matched %s: Dealt %d %s damage." % [data.name, final_dmg, type])
		_flash_unit(%EnemyFlash, Color.CRIMSON)
		# Increase intensity to 0.5 to bring in the drums
		SignalBus.battle_intensity_changed.emit(0.5)
		SignalBus.sfx_triggered.emit(AudioData.SFX["SWORD"])

	# 2. Heal Execution
	if stats.get("heal", 0) > 0:
		var heal_amt = stats.heal
		p_hp = min(GameManager.max_hp, p_hp + heal_amt)
		add_log("Matched %s: Restored %d HP." % [data.name, heal_amt])
		_flash_unit(%PlayerFlash, Color.SEA_GREEN)
		# Increase intensity to 0.5 to bring in the drums
		SignalBus.battle_intensity_changed.emit(0.5)
		SignalBus.sfx_triggered.emit(AudioData.SFX["HEAL"])

	# 3. Trap Execution
	if stats.get("trap", 0) > 0:
		var trap_dmg = stats.trap
		p_hp = max(0, p_hp - trap_dmg)
		add_log("Mimic Triggered! Took %d damage." % trap_dmg)
		_flash_unit(%PlayerFlash, Color.ORANGE_RED)
		SignalBus.battle_intensity_changed.emit(0.5)
		SignalBus.sfx_triggered.emit(AudioData.SFX["TRAP"])

	# # 4. Block 
	# # Increase intensity to 0.5 to bring in the drums
	# SignalBus.battle_intensity_changed.emit(0.5)
	# SignalBus.sfx_triggered.emit(AudioData.SFX["SHIELD"])

func _calculate_final_damage(card_val: int, type: String, attacker: String, defender: String) -> int:
	var total = card_val
	
	# A. Add Base Stats
	if attacker == "player":
		# Archivists might have higher spell power, Berserkers higher physical
		if type == "physical": total += 5 # Placeholder for Player STR
		else: total += 3 # Placeholder for Player INT
	else:
		# Enemy scaling
		total += difficulty * 2
	
	# B. Subtract Defense
	if defender == "enemy":
		var arm = current_enemy_res.armor if current_enemy_res else 0
		var res = 2 # Placeholder for enemy magic resist
		total -= (arm if type == "physical" else res)
	else:
		# Player defense
		total -= 2 # Placeholder for basic player armor
		
	# C. Status Effect Multipliers
	if active_status_effects[defender].has("vulnerable"):
		total = int(total * 1.5)
	if active_status_effects[attacker].has("charged"):
		total += 10
		active_status_effects[attacker].erase("charged") # Consume charge
		
	return max(1, total) # Ensure at least 1 damage is dealt

func _enemy_turn():
	# Simple enemy attack using the same formula logic
	var base_dmg = 8 + difficulty
	var final_dmg = _calculate_final_damage(base_dmg, "physical", "enemy", "player")
	p_hp -= final_dmg
	add_log("Enemy strikes for %d damage." % final_dmg)
	_flash_unit(%PlayerFlash, Color.CRIMSON)

# --- BOARD MANAGEMENT ---
func _should_reshuffle() -> bool:
	var counts = {}
	var unmatched_count = 0
	
	for card in grid.get_children():
		if not card.is_matched:
			unmatched_count += 1
			# Traps are unmatchable in this pool, so we only count pairs for other types
			if card.card_type != "trap":
				counts[card.card_type] = counts.get(card.card_type, 0) + 1
	
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

func _check_win_loss():
	if is_battle_over: return
	if e_hp <= 0:
		is_battle_over = true
		GameManager.current_hp = p_hp
		GameManager.mark_room_cleared(GameManager.current_node.id)
		get_tree().call_deferred("change_scene_to_file", "res://features/combat/VictoryScreen.tscn")
	elif p_hp <= 0:
		is_battle_over = true
		get_tree().call_deferred("change_scene_to_file", "res://features/ui/RunSummary.tscn")


func update_ui(instant: bool = false):
	# Dynamic Text update
	player_hp_text.text = "%d / %d" % [p_hp, GameManager.max_hp]
	enemy_hp_text.text = "HP: %d" % e_hp
	
	# Dynamic Bar update with Tween
	var duration = 0.0 if instant else 0.4
	
	var p_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	p_tween.tween_property(player_hp_bar, "value", (float(p_hp) / GameManager.max_hp) * 100, duration)
	
	var max_e = current_enemy_res.hp + (difficulty * 15) if current_enemy_res else 100
	var e_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	e_tween.tween_property(enemy_hp_bar, "value", (float(e_hp) / max_e) * 100, duration)

func add_log(text):
	var lbl = Label.new(); lbl.text = "> " + text; log_box.add_child(lbl)
	# Auto-scroll logic if needed
	
func _flash_unit(overlay, color):
	if not overlay: return
	overlay.color = color; overlay.color.a = 0.5
	create_tween().tween_property(overlay, "color:a", 0.0, 0.4)

func _on_settings_pressed():
	# Assuming settings overlay is preloaded or in a manager
	var settings = preload("res://features/ui/SettingsOverlay.tscn").instantiate()
	get_tree().root.add_child(settings)
	# battle_ui.hide()
	
# --- VISUAL HELPERS ---

func _setup_player_spritesheet():
	var idle_tex = load("res://assets/player/base_idle.png")
	if idle_tex:
		player_sprite.texture = idle_tex
		player_sprite.hframes = 8
		player_sprite.vframes = 1
		# Force 2x Size (Scale 1.0 relative to previous 0.5)
		player_sprite.scale = Vector2(1.0, 1.0)
		_animate_unit(player_sprite, 8, 0.12)

func _setup_enemy_portrait():
	if current_room_res and current_room_res.enemy_id != "":
		var e_path = "res://data/enemies/%s.tres" % current_room_res.enemy_id
		if ResourceLoader.exists(e_path):
			current_enemy_res = load(e_path) as EnemyData
			if current_enemy_res:
				e_hp = current_enemy_res.hp + (difficulty * 15)
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
		
func setup_board():
	for child in grid.get_children(): child.queue_free()
	var size = 3
	if difficulty >= 3: size = 4
	if difficulty >= 6: size = 5
	grid.columns = size
	
	var total_slots = size * size
	var pair_count = floor(total_slots / 2.0)
	var deck_pool = GameManager.active_deck.duplicate()
	deck_pool.shuffle()
	
	while deck_pool.size() < pair_count: deck_pool.append("sword")
	
	var selected_ids = deck_pool.slice(0, pair_count)
	var final_grid_ids = []
	for id in selected_ids:
		final_grid_ids.append(id); final_grid_ids.append(id)
	
	if final_grid_ids.size() < total_slots: final_grid_ids.append("trap")
	final_grid_ids.shuffle()
	
	var card_dim = floor((450.0 - (12.0 * (size + 1.0))) / float(size))
	for card_id in final_grid_ids:
		var c = card_scene.instantiate(); grid.add_child(c)
		c.custom_minimum_size = Vector2(card_dim, card_dim)
		var res_path = "res://data/cards/%s.tres" % card_id
		if FileAccess.file_exists(res_path): c.setup(load(res_path))
		else: c.card_type = card_id
		c.card_flipped.connect(_on_card_flipped)

func _apply_room_data(res: RoomData):
	%RoomTitle.text = res.room_name
	%DialogText.text = res.initial_dialog
	if background and res.background_texture: background.texture = res.background_texture

func _debug_win():
	get_tree().call_deferred("change_scene_to_file", "res://features/combat/VictoryScreen.tscn")

func _debug_lose():
	get_tree().call_deferred("change_scene_to_file", "res://features/ui/RunSummary.tscn")
