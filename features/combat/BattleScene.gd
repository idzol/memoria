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
@onready var battle_log_row = %BattleLogRow
@onready var log_left_spacer = %LeftSpacer
@onready var log_box = %LogBox
@onready var log_display = %LogDisplay
@onready var log_right_spacer = %RightSpacer

# Status Bar References
@onready var biome_room_label = %BiomeRoomLabel
# @onready var conditions_container = %ConditionsContainer
@onready var round_label = %RoundLabel
@onready var energy_pips = %EnergyPips
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
var full_card_scene = preload("res://features/combat/Card.tscn")
var in_game_menu_scene = preload("res://features/ui/InGameMenu.tscn")

# --- Combat State ---
var flipped_cards: Array = []
var can_flip: bool = false 
var is_battle_over: bool = false
var difficulty: int = 0
var current_room_res: RoomData = null
var current_enemy_res: EnemyData = null
var current_player_res: PlayerData = null
var in_game_menu = null
var is_cleared_room: bool = false
var death_transition_in_progress: bool = false

# Current Stats for Calculation
var p_hp: int = 1
var e_hp: int = 1
var max_e_hp: int = 1 

var p_atk: int = 0 # Base attack
var p_def: int = 0 # Base defense
var temp_armor_bonus: int = 0 # Temporary defense from matched armor cards
var round_number: int = 1
var keyboard_selected_card_index: int = -1
var keyboard_selection_active: bool = false
var card_selection_style: StyleBoxFlat
var card_preview_layer: CanvasLayer = null
var card_preview_root: Control = null
var card_preview_holder: CenterContainer = null
var active_preview_card: Control = null
var is_log_expanded: bool = false
var log_collapsed_global_rect: Rect2 = Rect2()

var active_status_effects = {"player": [], "enemy": []} # e.g. ["vulnerable", "charged"]
const ENERGY_PIP_FULL = Color(1.0, 0.86, 0.35, 1.0)
const ENERGY_PIP_EMPTY = Color(0.46, 0.35, 0.08, 1.0)
const CARD_SELECTION_OUTLINE = "KeyboardCardSelectionOutline"
const ACTION_ANIM_DURATION = 0.35
const LOG_COLLAPSED_HEIGHT = 32.0
const LOG_EXPANDED_LINE_COUNT = 10
const LOG_LINE_HEIGHT = 22.0
const LOG_EXPANDED_PADDING = 12.0
const LOG_ROW_SEPARATION = 0
const LOG_SIDE_SPACER_WIDTH = 0.0
const PREVIEW_AFTER_FLIP_GUARD_MS = 160
const LOG_COLOR_GOOD = Color(0.62, 1.0, 0.62, 1.0)
const LOG_COLOR_BAD = Color(1.0, 0.58, 0.58, 1.0)
const LOG_COLOR_NEUTRAL = Color(0.86, 0.86, 0.86, 1.0)
const ENERGY_PIP_CHAR = "▮"

func _ready():
	var node_data = GameManager.current_node
	_ensure_player_deck_not_empty()
	_ensure_safe_energy_defaults()
	difficulty = node_data["difficulty"] if "difficulty" in node_data else 1
	is_cleared_room = GameManager.is_room_cleared(str(node_data.get("id", "")))
	GameManager.recalculate_player_totals()

	p_hp = GameManager.current_hp
	p_atk = GameManager.player_attack_total
	p_def = GameManager.player_defense_total

	if node_data.has("room_resource_path"):
		current_room_res = load(node_data.room_resource_path) as RoomData
		_apply_room_data(current_room_res)
	
	# Instance the In-Game Menu (Esc key)
	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()
	if has_node("%MenuIconBtn"):
		%MenuIconBtn.pressed.connect(_toggle_in_game_menu)

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
	_setup_card_selection_style()
	_setup_card_preview_overlay()
	_setup_battle_log_ui()
	add_log("Battle begins.")
	_update_character_placement()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _input(event):
	if is_log_expanded and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _is_point_inside_log(event.position):
			is_log_expanded = false
			_refresh_log_view()
			get_viewport().set_input_as_handled()
			return

	if _is_card_preview_visible():
		if (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_accept"):
			_hide_card_preview()
			return

	# Escape toggles the in-game menu.
	if event.is_action_pressed("ui_cancel"):
		_toggle_in_game_menu()
		return

	# Dialog overlay: Enter accepts the primary option (e.g. "Enter Combat").
	if dialog_overlay and dialog_overlay.visible and event.is_action_pressed("ui_accept"):
		_activate_dialog_primary_option()
		return

	if _can_handle_keyboard_card_input():
		if event.is_action_pressed("ui_left"):
			_move_keyboard_card_selection(-1)
			return
		if event.is_action_pressed("ui_right"):
			_move_keyboard_card_selection(1)
			return
		if event.is_action_pressed("ui_up"):
			_move_keyboard_card_selection(-grid.columns)
			return
		if event.is_action_pressed("ui_down"):
			_move_keyboard_card_selection(grid.columns)
			return
		if event.is_action_pressed("ui_accept"):
			_activate_keyboard_selected_card()
			return

	if event is InputEventKey and event.pressed and not event.is_echo():
		_clear_keyboard_card_selection()
	elif event is InputEventMouseButton and event.pressed:
		_clear_keyboard_card_selection()

	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		# PRESS 'B' TO TOGGLE BACKGROUND (Debugging hidden elements)
		if event.keycode == KEY_B:
			background.visible = !background.visible
			print("[DEBUG] Background Visibility: ", background.visible)
		
		# PRESS 'F' TO FORCE FLOOR REFRESH
		if event.keycode == KEY_F:
			_apply_room_data(current_room_res)

func _toggle_in_game_menu():
	if in_game_menu:
		if in_game_menu.visible:
			in_game_menu.close()
		else:
			in_game_menu.open()
			_clear_keyboard_card_selection()

func _handle_menu_cancel() -> bool:
	if not in_game_menu or not in_game_menu.visible:
		return false
	if in_game_menu.has_method("handle_cancel"):
		return in_game_menu.handle_cancel()
	in_game_menu.close()
	return true

func _exit_to_overworld_from_battle():
	if GameManager.is_battle_mode:
		get_tree().change_scene_to_file("res://features/map/BattleMap.tscn")
	else:
		get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")

func _is_current_room_cleared() -> bool:
	if is_cleared_room:
		return true
	var node_data = GameManager.current_node
	var room_id = str(node_data.get("id", ""))
	if room_id == "":
		return false
	return GameManager.is_room_cleared(room_id)

func _setup_card_selection_style():
	if card_selection_style:
		return
	card_selection_style = StyleBoxFlat.new()
	card_selection_style.draw_center = true
	card_selection_style.bg_color = Color(0, 0, 0, 0)
	card_selection_style.border_width_left = 4
	card_selection_style.border_width_top = 4
	card_selection_style.border_width_right = 4
	card_selection_style.border_width_bottom = 4
	card_selection_style.border_color = Color(0.1, 0.75, 0.28, 1.0)

func _can_handle_keyboard_card_input() -> bool:
	if is_battle_over or not can_flip:
		return false
	if not battle_ui or not battle_ui.visible:
		return false
	if in_game_menu and in_game_menu.visible:
		return false
	if dialog_overlay and dialog_overlay.visible:
		return false
	return true

func _move_keyboard_card_selection(step: int):
	var cards = _get_grid_cards()
	if cards.is_empty():
		_clear_keyboard_card_selection()
		return
	var child_count = cards.size()
	var first_idx = _find_first_navigable_card_index(cards)
	if first_idx == -1:
		_clear_keyboard_card_selection()
		return
	# First arrow press should reveal/select the top-left available card.
	if keyboard_selected_card_index < 0:
		keyboard_selected_card_index = first_idx
		keyboard_selection_active = true
		_refresh_keyboard_card_outline()
		return
	var start_idx = keyboard_selected_card_index
	var next_idx = start_idx
	var safety = 0
	while safety < child_count:
		next_idx = posmod(next_idx + step, child_count)
		var card = cards[next_idx]
		if _is_navigable_card(card):
			keyboard_selected_card_index = next_idx
			keyboard_selection_active = true
			_refresh_keyboard_card_outline()
			return
		safety += 1

func _activate_keyboard_selected_card():
	var cards = _get_grid_cards()
	if cards.is_empty():
		_clear_keyboard_card_selection()
		return
	if keyboard_selected_card_index < 0 or keyboard_selected_card_index >= cards.size():
		return
	var card = cards[keyboard_selected_card_index]
	if not _is_navigable_card(card):
		return
	card.flip()
	_clear_keyboard_card_selection()

func _clear_keyboard_card_selection():
	keyboard_selection_active = false
	keyboard_selected_card_index = -1
	_refresh_keyboard_card_outline()

func _refresh_keyboard_card_outline():
	var cards = _get_grid_cards()
	for card in cards:
		if not is_instance_valid(card):
			continue
		var existing = card.get_node_or_null(CARD_SELECTION_OUTLINE)
		if existing:
			existing.queue_free()
	if not keyboard_selection_active:
		return
	if keyboard_selected_card_index < 0 or keyboard_selected_card_index >= cards.size():
		return
	var selected_card = cards[keyboard_selected_card_index]
	if not is_instance_valid(selected_card):
		return
	var outline = Panel.new()
	outline.name = CARD_SELECTION_OUTLINE
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outline.grow_horizontal = Control.GROW_DIRECTION_BOTH
	outline.grow_vertical = Control.GROW_DIRECTION_BOTH
	outline.z_index = 100
	outline.offset_left = 0
	outline.offset_top = 0
	outline.offset_right = 0
	outline.offset_bottom = 0
	outline.add_theme_stylebox_override("panel", card_selection_style)
	selected_card.add_child(outline)

func _activate_dialog_primary_option():
	if not has_node("%OptionContainer"):
		return
	for child in %OptionContainer.get_children():
		if child is Button and child.visible and not child.disabled:
			(child as Button).pressed.emit()
			return

func _get_grid_cards() -> Array:
	var result: Array = []
	for child in grid.get_children():
		if child is TextureButton:
			result.append(child)
	return result

func _find_first_navigable_card_index(cards: Array) -> int:
	for i in range(cards.size()):
		if _is_navigable_card(cards[i]):
			return i
	return -1

func _is_navigable_card(card) -> bool:
	return is_instance_valid(card) and not card.disabled and not card.is_matched and not card.is_face_up


func _sync_stat_icons():
	# Sync Player Icons
	if player_atk_val: player_atk_val.text = str(p_atk)
	if player_def_val: player_def_val.text = str(p_def + temp_armor_bonus)
	
	# Sync Enemy Icons
	if current_enemy_res:
		enemy_atk_val.text = str(current_enemy_res.base_damage)
		enemy_def_val.text = str(current_enemy_res.armor)
	
	# Energy HUD
	_render_energy_pips()

func _render_energy_pips():
	if not energy_pips:
		return
	var max_energy = GameManager.base_energy if "base_energy" in GameManager else 2
	var current_energy = clamp(GameManager.current_energy, 0, max_energy)
	while energy_pips.get_child_count() > max_energy:
		energy_pips.get_child(energy_pips.get_child_count() - 1).queue_free()
	while energy_pips.get_child_count() < max_energy:
		var pip = Label.new()
		pip.text = ENERGY_PIP_CHAR
		pip.add_theme_font_size_override("font_size", 22)
		energy_pips.add_child(pip)
	for i in range(energy_pips.get_child_count()):
		var pip_node = energy_pips.get_child(i) as Label
		if pip_node:
			pip_node.modulate = ENERGY_PIP_FULL if i < current_energy else ENERGY_PIP_EMPTY


func _sync_status_bar():
	# Biome | Room
	var biome_name = current_room_res.biome.capitalize() if current_room_res else "Unknown"
	var room_name = current_room_res.room_name if current_room_res else "Battle"
	biome_room_label.text = "%s  |  %s" % [biome_name, room_name]
	
	# Round
	round_label.text = "ROUND: %d" % round_number

# --- INPUT & FLOW ---
func _on_card_flipped(card):
	_clear_keyboard_card_selection()
	if is_instance_valid(card):
		card.set_meta("preview_guard_until_ms", Time.get_ticks_msec() + PREVIEW_AFTER_FLIP_GUARD_MS)
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

func _on_card_pressed(card):
	if not is_instance_valid(card):
		return
	if _is_card_preview_visible():
		_hide_card_preview()
		return
	var guard_until = int(card.get_meta("preview_guard_until_ms", 0))
	if Time.get_ticks_msec() < guard_until:
		return
	if card.is_face_up:
		_show_card_preview_for_id(card.card_type, false)

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
		_show_card_preview_for_id(c1.card_type, true)
		
		_process_combat_action(c1.card_type)
		update_ui()
		_check_win_loss()
		
		# Resolve the turn attempt since a match was found
		_resolve_turn_end()
		
	elif GameManager.current_energy <= 0:
		# FAILURE: Out of energy and no pairs exist in the turned cards
		can_flip = false
		add_log("No cards matched.")
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree() or is_battle_over: return
		
		_enemy_turn()
		update_ui()
		_check_win_loss()
		_resolve_turn_end()

func _resolve_turn_end():
	if is_battle_over: return
	_clear_keyboard_card_selection()
	
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
			_play_unit_sheet_temporarily(player_sprite, current_player_res, "attack_sheet", ACTION_ANIM_DURATION)
			_play_unit_sheet_temporarily(enemy_sprite, current_enemy_res, "defend_sheet", ACTION_ANIM_DURATION)
			var enemy_armor = current_enemy_res.armor if current_enemy_res else 0
			var final_dmg = _calculate_final_damage(res.value, type, "player", "enemy")
			e_hp = max(0, e_hp - final_dmg)
			var raw_damage = res.value + (p_atk if type == "physical" else 0)
			var negated = max(0, raw_damage - final_dmg) if type == "physical" else 0
			add_log("%s card matched." % res.name)
			if type == "physical":
				add_log("Enemy armour negates %d damage." % min(enemy_armor, negated))
			add_log("You deal %d damage." % final_dmg)
			_flash_unit(%EnemyFlash, Color.CRIMSON)
			SignalBus.battle_intensity_changed.emit(0.5)
			SignalBus.sfx_triggered.emit(AudioData.SFX["SWORD"])

		elif res.type == "trap":
			_play_unit_sheet_temporarily(player_sprite, current_player_res, "defend_sheet", ACTION_ANIM_DURATION)
			var trap_dmg = max(1, int(res.value) - (p_def + temp_armor_bonus))
			var trap_negated = max(0, int(res.value) - trap_dmg)
			p_hp = max(0, p_hp - trap_dmg)
			add_log("Trap deals %d damage." % int(res.value))
			add_log("Your armour negates %d damage." % trap_negated)
			add_log("You receive %d damage." % trap_dmg)
			if temp_armor_bonus > 0:
				add_log("Armor bonus breaks after the hit.")
				temp_armor_bonus = 0
				_sync_stat_icons()
			_flash_unit(%PlayerFlash, Color.ORANGE_RED)
			SignalBus.battle_intensity_changed.emit(0.5)
			SignalBus.sfx_triggered.emit(AudioData.SFX["TRAP"])

		elif res.type == "heal":
			p_hp = min(GameManager.player_hp_total, p_hp + res.value)
			add_log("Matched %s: Restored %d HP." % [res.name, res.value])
			_flash_unit(%PlayerFlash, Color.SEA_GREEN)
			SignalBus.battle_intensity_changed.emit(0.5)
			SignalBus.sfx_triggered.emit(AudioData.SFX["HEAL"])

		elif res.type == "armor":
			temp_armor_bonus += int(res.value)
			add_log("Matched %s: +%d armor for the next hit." % [res.name, int(res.value)])
			_flash_unit(%PlayerFlash, Color.GOLD)
			SignalBus.battle_intensity_changed.emit(0.5)
			SignalBus.sfx_triggered.emit(AudioData.SFX["SHIELD"])

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
		total -= (p_def + temp_armor_bonus)
		
	# C. Status Effect Multipliers
	if active_status_effects[defender].has("vulnerable"):
		total = int(total * 1.5)
	if active_status_effects[attacker].has("charged"):
		total += 10
		active_status_effects[attacker].erase("charged") # Consume charge
		
	return max(1, total) # Ensure at least 1 damage is dealt

func _enemy_turn():
	# Simple enemy attack using the same formula logic
	# Pass 0 here because _calculate_final_damage already injects enemy base attack.
	_play_unit_sheet_temporarily(enemy_sprite, current_enemy_res, "attack_sheet", ACTION_ANIM_DURATION)
	_play_unit_sheet_temporarily(player_sprite, current_player_res, "defend_sheet", ACTION_ANIM_DURATION)
	var final_dmg = _calculate_final_damage(0, "physical", "enemy", "player")
	var enemy_raw = int(current_enemy_res.base_damage) if current_enemy_res else final_dmg
	var enemy_negated = max(0, enemy_raw - final_dmg)
	p_hp -= final_dmg
	add_log("Enemy deals %d damage." % enemy_raw)
	add_log("Your armour negates %d damage." % enemy_negated)
	add_log("You receive %d damage." % final_dmg)
	if temp_armor_bonus > 0:
		add_log("Armor bonus breaks after the hit.")
		temp_armor_bonus = 0
		_sync_stat_icons()
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
	_clear_keyboard_card_selection()
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
		GameManager.register_room_victory(GameManager.current_node, p_hp)
		var xp_reward = current_enemy_res.xp_reward if current_enemy_res else 0
		var xp_result = GameManager.add_player_xp(xp_reward)
		var default_victory_scene = "res://features/combat/VictoryScreenBattleMode.tscn" if GameManager.is_battle_mode else "res://features/combat/VictoryScreen.tscn"
		var return_scene = GameManager.peek_pending_post_battle_scene(default_victory_scene)
		if xp_result.get("leveled_up", false):
			GameManager.level_up_return_scene = GameManager.consume_pending_post_battle_scene(default_victory_scene) if return_scene != default_victory_scene else default_victory_scene
			await get_tree().create_timer(1.5).timeout
			if not is_inside_tree():
				return
			get_tree().call_deferred("change_scene_to_file", "res://features/ui/CharacterLevelUp.tscn")
			return
		
		await get_tree().create_timer(1.5).timeout
		if not is_inside_tree():
			return
		get_tree().call_deferred("change_scene_to_file", GameManager.consume_pending_post_battle_scene(default_victory_scene))
			
	elif p_hp <= 0:
		is_battle_over = true
		if death_transition_in_progress:
			return
		death_transition_in_progress = true
		GameManager.current_hp = max(0, p_hp)
		if GameManager.is_battle_mode:
			# Battle mode: show DeathScreen, then RunSummary
			await _fade_to_black_and_change_scene("res://features/ui/DeathScreen.tscn")
		else:
			# Story mode: reset run state, then show DeathScreen, then WorldMap
			GameManager.reset_to_home()
			GameManager.current_hp = GameManager.player_hp_total
			GameManager.current_node = {}
			await _fade_to_black_and_change_scene("res://features/ui/DeathScreen.tscn")


func update_ui(instant: bool = false):
	# Dynamic Text update
	player_hp_text.text = "%d / %d" % [p_hp, GameManager.player_hp_total]
	enemy_hp_text.text = "HP: %d" % e_hp
	
	# Dynamic Bar update with Tween
	var duration = 0.0 if instant else 0.4
	
	if player_hp_bar:
		player_hp_bar.max_value = GameManager.player_hp_total
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(player_hp_bar, "value", p_hp, duration)
	
	if enemy_hp_bar:
		enemy_hp_bar.max_value = max_e_hp
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(enemy_hp_bar, "value", e_hp, duration)

	_sync_stat_icons()
	round_label.text = "ROUND: %d" % round_number
	
	
func add_log(text):
	var lbl = Label.new()
	lbl.text = "> " + text
	lbl.clip_text = true
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.add_theme_color_override("font_color", _get_log_entry_color(text))
	log_box.add_child(lbl)

	_refresh_log_view()
	call_deferred("_scroll_log_to_latest")

func _get_log_entry_color(text: String) -> Color:
	var t = text.to_lower()
	if "you deal" in t or "card matched" in t:
		return LOG_COLOR_GOOD
	if "trap deals" in t or "enemy deals" in t or "you receive" in t:
		return LOG_COLOR_BAD
	return LOG_COLOR_NEUTRAL

func _setup_battle_log_ui():
	if not log_display or not battle_log_row:
		return
	_apply_log_horizontal_constants()
	battle_log_row.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_log_row.custom_minimum_size.y = LOG_COLLAPSED_HEIGHT
	if not battle_log_row.gui_input.is_connected(_on_battle_log_row_gui_input):
		battle_log_row.gui_input.connect(_on_battle_log_row_gui_input)
	log_display.visible = true
	log_display.z_index = 120
	log_display.mouse_filter = Control.MOUSE_FILTER_PASS
	log_display.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_display.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var terminal_bg = StyleBoxFlat.new()
	terminal_bg.bg_color = Color(0.06, 0.06, 0.06, 1.0)
	terminal_bg.border_width_left = 2
	terminal_bg.border_width_top = 2
	terminal_bg.border_width_right = 2
	terminal_bg.border_width_bottom = 2
	terminal_bg.border_color = Color(0.22, 0.22, 0.22, 1.0)
	terminal_bg.corner_radius_top_left = 4
	terminal_bg.corner_radius_top_right = 4
	terminal_bg.corner_radius_bottom_left = 4
	terminal_bg.corner_radius_bottom_right = 4
	log_display.add_theme_stylebox_override("panel", terminal_bg)
	log_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_display.custom_minimum_size.y = LOG_COLLAPSED_HEIGHT
	is_log_expanded = false
	_refresh_log_view()

func _on_battle_log_row_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_log_expanded = not is_log_expanded
		_refresh_log_view()
		get_viewport().set_input_as_handled()

func _refresh_log_view():
	if not log_display:
		return
	log_display.visible = true
	var expanded_height = (LOG_EXPANDED_LINE_COUNT * LOG_LINE_HEIGHT) + LOG_EXPANDED_PADDING
	if is_log_expanded:
		if not log_display.top_level:
			log_collapsed_global_rect = log_display.get_global_rect()
			log_display.top_level = true
			log_display.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		var viewport_size = get_viewport_rect().size
		log_display.size = Vector2(viewport_size.x, expanded_height)
		log_display.global_position = Vector2(
			0.0,
			log_collapsed_global_rect.position.y - expanded_height + LOG_COLLAPSED_HEIGHT
		)
	else:
		_restore_log_to_collapsed_row()
	log_display.mouse_filter = Control.MOUSE_FILTER_STOP if is_log_expanded else Control.MOUSE_FILTER_PASS
	log_display.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if is_log_expanded else ScrollContainer.SCROLL_MODE_DISABLED
	if not is_log_expanded:
		log_display.scroll_vertical = 0
	for i in range(log_box.get_child_count()):
		var child = log_box.get_child(i)
		if child is Label:
			child.visible = is_log_expanded or i == log_box.get_child_count() - 1

func _scroll_log_to_latest():
	if not log_display:
		return
	var max_vscroll = max(0, int(log_box.size.y - log_display.size.y))
	log_display.scroll_vertical = max_vscroll

func _restore_log_to_collapsed_row():
	if not log_display:
		return
	log_display.top_level = false
	log_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_display.position = Vector2.ZERO
	log_display.custom_minimum_size = Vector2(0.0, LOG_COLLAPSED_HEIGHT)

func _apply_log_horizontal_constants():
	if battle_log_row:
		battle_log_row.add_theme_constant_override("separation", LOG_ROW_SEPARATION)
	if log_left_spacer:
		log_left_spacer.custom_minimum_size.x = LOG_SIDE_SPACER_WIDTH
	if log_right_spacer:
		log_right_spacer.custom_minimum_size.x = LOG_SIDE_SPACER_WIDTH

func _is_point_inside_log(global_point: Vector2) -> bool:
	if not log_display or not log_display.visible:
		return false
	return log_display.get_global_rect().has_point(global_point)
	
func _flash_unit(overlay, color):
	if not overlay: return
	overlay.color = color; overlay.color.a = 0.5
	create_tween().tween_property(overlay, "color:a", 0.0, 0.4)

# --- VISUAL HELPERS ---
func _setup_player_spritesheet():
	var p_path = "res://data/player/base.tres"
	if ResourceLoader.exists(p_path):
		current_player_res = load(p_path) as PlayerData
	if current_player_res:
		_apply_unit_visuals(player_sprite, current_player_res)
		return
	var idle_tex = load("res://assets/player/base_idle.png")
	if idle_tex:
		player_sprite.texture = idle_tex
		player_sprite.hframes = 6
		player_sprite.vframes = 6
		player_sprite.scale = Vector2(1.0, 1.0)
		player_sprite.offset.y = sprite_feet_offset
		_start_unit_animation(player_sprite, 8, 0.12)

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


func _animate_unit(sprite: Sprite2D, total: int, speed: float, anim_token: int):
	var frame = 0; var dir = 1
	while sprite and is_inside_tree() and int(sprite.get_meta("anim_token", -1)) == anim_token:
		sprite.frame = frame
		if total > 1:
			if frame >= total - 1: dir = -1
			elif frame <= 0: dir = 1
			frame += dir
		await get_tree().create_timer(speed).timeout

func _start_unit_animation(sprite: Sprite2D, total: int, speed: float):
	if not sprite:
		return
	var next_token = int(sprite.get_meta("anim_token", 0)) + 1
	sprite.set_meta("anim_token", next_token)
	_animate_unit(sprite, max(1, total), max(0.01, speed), next_token)

func _apply_unit_visuals(sprite: Sprite2D, res: Resource):
	if not sprite or not res: return
	var sheet = res.get("idle_sheet")
	if sheet:
		_apply_unit_sheet(sprite, res, sheet)
		_start_unit_animation(sprite, _get_unit_total_frames(res), _get_unit_frame_speed(res))
		_update_character_placement()

func _apply_unit_sheet(sprite: Sprite2D, res: Resource, sheet: Texture2D):
	if not sprite or not res or not sheet:
		return
	sprite.texture = sheet
	var h = res.get("hframes")
	sprite.hframes = h if h != null else 8
	var v = res.get("vframes")
	sprite.vframes = v if v != null else 1
	sprite.scale = Vector2(1.0, 1.0)
	sprite.offset.y = sprite_feet_offset

func _get_unit_total_frames(res: Resource) -> int:
	var total = res.get("total_frames")
	return total if total != null else 8

func _get_unit_frame_speed(res: Resource) -> float:
	var speed = res.get("frame_speed")
	return speed if speed != null else 0.1

func _play_unit_sheet_temporarily(sprite: Sprite2D, res: Resource, sheet_key: String, duration: float = ACTION_ANIM_DURATION):
	if not sprite or not res:
		return
	var action_sheet = res.get(sheet_key)
	if not action_sheet:
		return
	_apply_unit_sheet(sprite, res, action_sheet)
	_start_unit_animation(sprite, _get_unit_total_frames(res), _get_unit_frame_speed(res))
	_queue_unit_idle_restore(sprite, res, duration)

func _queue_unit_idle_restore(sprite: Sprite2D, res: Resource, duration: float):
	if not sprite or not res:
		return
	var next_restore_token = int(sprite.get_meta("restore_token", 0)) + 1
	sprite.set_meta("restore_token", next_restore_token)
	_restore_unit_idle_after_delay(sprite, res, duration, next_restore_token)

func _restore_unit_idle_after_delay(sprite: Sprite2D, res: Resource, duration: float, restore_token: int):
	await get_tree().create_timer(max(0.01, duration)).timeout
	if not is_inside_tree() or not sprite:
		return
	if int(sprite.get_meta("restore_token", -1)) != restore_token:
		return
	var idle_sheet = res.get("idle_sheet")
	if not idle_sheet:
		return
	_apply_unit_sheet(sprite, res, idle_sheet)
	_start_unit_animation(sprite, _get_unit_total_frames(res), _get_unit_frame_speed(res))
		
func setup_board():
	_clear_keyboard_card_selection()

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
	var card_dim = _get_card_dimension_for_grid(size)
	for card_id in final_grid_ids:
		var c = card_scene.instantiate(); grid.add_child(c)
		c.custom_minimum_size = Vector2(card_dim, card_dim)
		var res_path = "res://data/cards/%s.tres" % card_id
		if FileAccess.file_exists(res_path): c.setup(load(res_path))
		else: c.card_type = card_id
		c.card_flipped.connect(_on_card_flipped)
		c.pressed.connect(_on_card_pressed.bind(c))

	# Final UI updates 
	_sync_stat_icons()

func _get_card_dimension_for_grid(columns: int) -> float:
	var usable_size = min(grid.size.x, grid.size.y)
	if usable_size <= 0.0:
		usable_size = 450.0
	var h_sep = float(grid.get_theme_constant("h_separation"))
	var total_separation = h_sep * float(columns - 1)
	var raw_size = (usable_size - total_separation) / float(columns)
	return max(56.0, floor(raw_size))
	

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
			floor_rect.stretch_mode = TextureRect.STRETCH_SCALE
			floor_rect.visible = true
			_fit_floor_to_container_width()
		else:
			# Fallback if specific file is missing
			print("[BattleScene] Floor texture missing: ", floor_path)
			floor_rect.visible = false

func _on_viewport_resized():
	_fit_floor_to_container_width()
	_update_character_placement()
	_refresh_log_view()

func _fit_floor_to_container_width():
	if not floor_rect or not floor_rect.texture:
		return
	var view_size = get_viewport_rect().size
	if view_size.x <= 0.0:
		return
	var tex_size = floor_rect.texture.get_size()
	if tex_size.x <= 0.0:
		return
	var scaled_height = (view_size.x / tex_size.x) * tex_size.y
	floor_rect.offset_top = -scaled_height
	floor_rect.offset_bottom = 0.0


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

func _fade_to_black_and_change_scene(scene_path: String):
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	
	var fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	fade_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fade_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	fade_layer.add_child(fade_rect)
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.6)
	await tween.finished
	if is_inside_tree():
		get_tree().change_scene_to_file(scene_path)

func _ensure_player_deck_not_empty():
	var fallback_deck: Array = ["sword", "shield", "heart"]
	if GameManager.player_deck.is_empty():
		GameManager.player_deck = fallback_deck.duplicate()
	if GameManager.active_deck.is_empty():
		GameManager.active_deck = fallback_deck.duplicate()

func _ensure_safe_energy_defaults():
	if GameManager.base_energy <= 0:
		GameManager.base_energy = 2

func _setup_card_preview_overlay():
	if card_preview_layer:
		return
	card_preview_layer = CanvasLayer.new()
	card_preview_layer.layer = 90
	add_child(card_preview_layer)

	card_preview_root = Control.new()
	card_preview_root.visible = false
	card_preview_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_preview_root.mouse_filter = Control.MOUSE_FILTER_STOP
	card_preview_layer.add_child(card_preview_root)

	var dimmer = ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.35)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	card_preview_root.add_child(dimmer)

	card_preview_holder = CenterContainer.new()
	card_preview_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_preview_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	card_preview_root.add_child(card_preview_holder)

func _is_card_preview_visible() -> bool:
	return card_preview_root != null and card_preview_root.visible

func _show_card_preview_for_id(card_id: String, animate_in: bool = false):
	if card_id == "" or not full_card_scene:
		return
	var res_path = "res://data/cards/%s.tres" % card_id
	if not ResourceLoader.exists(res_path):
		return
	var card_data = load(res_path) as CardData
	if not card_data:
		return

	if active_preview_card and is_instance_valid(active_preview_card):
		active_preview_card.queue_free()
		active_preview_card = null

	var card_view = full_card_scene.instantiate()
	active_preview_card = card_view
	card_preview_holder.add_child(card_view)
	card_view.custom_minimum_size = Vector2(280, 420)
	card_view.scale = Vector2(1.0, 1.0)
	if card_view.has_method("setup"):
		card_view.setup(card_data)
	var back_face = card_view.get_node_or_null("%BackFace")
	if back_face:
		back_face.visible = false
	var front_face = card_view.get_node_or_null("%FrontFace")
	if front_face:
		front_face.visible = true
	card_view.is_face_up = true
	card_view.disabled = true
	card_preview_root.visible = true

	if animate_in:
		card_view.modulate.a = 0.0
		card_view.scale = Vector2(0.82, 0.82)
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card_view, "modulate:a", 1.0, 0.18)
		tween.parallel().tween_property(card_view, "scale", Vector2(1.04, 1.04), 0.16)
		tween.tween_property(card_view, "scale", Vector2(1.0, 1.0), 0.10)

func _hide_card_preview():
	if not card_preview_root:
		return
	card_preview_root.visible = false
	if active_preview_card and is_instance_valid(active_preview_card):
		active_preview_card.queue_free()
	active_preview_card = null
