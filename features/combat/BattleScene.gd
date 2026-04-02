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
@onready var biome_label = get_node_or_null("%BiomeLabel")
@onready var phase_label = get_node_or_null("%PhaseLabel")
@onready var tracker_text = get_node_or_null("%TrackerText")
@onready var avatar_button = get_node_or_null("%AvatarButton")
@onready var story_button = get_node_or_null("%StoryButton")
@onready var exit_button = get_node_or_null("%ExitButton")
@onready var status_bar = get_node_or_null("UI/MainLayout/StatusBar")

# Status Bar References
@onready var energy_pips = %EnergyPips
@onready var player_atk_val = %PlayerAtkVal
@onready var player_def_val = %PlayerDefVal
@onready var enemy_atk_val = %EnemyAtkVal
@onready var enemy_def_val = %EnemyDefVal
@onready var stage_layout_container = %StageLayoutContainer
@onready var stage_layout = get_node_or_null("UI/MainLayout/StageLayoutContainer/StageLayout")
@onready var arena_center = %ArenaCenter
@onready var player_column_ui = get_node_or_null("UI/MainLayout/StageLayoutContainer/StageLayout/PlayerColumnUI")
@onready var player_stats_hud = get_node_or_null("UI/MainLayout/StageLayoutContainer/StageLayout/PlayerColumnUI/StatsHUD")
@onready var enemy_column_ui = get_node_or_null("UI/MainLayout/StageLayoutContainer/StageLayout/EnemyColumnUI")
@onready var enemy_stats_hud = get_node_or_null("UI/MainLayout/StageLayoutContainer/StageLayout/EnemyColumnUI/StatsHUD")

# Dynamic HP Bars
@onready var player_hp_bar = %PlayerHPBar
@onready var player_hp_text = %PlayerHPText
@onready var enemy_hp_bar = %EnemyHPBar
@onready var enemy_hp_text = %EnemyHPText

# UI Layers
@onready var dialog_overlay = %DialogOverlay
@onready var dialog_overlay_bg = get_node_or_null("DialogOverlay/BG")
@onready var dialog_box = $DialogOverlay/VBox
@onready var dialog_speaker = %DialogSpeaker
@onready var dialog_text = %DialogText
@onready var battle_ui = %UI 

# Unit Visuals
@onready var enemy_sprite = %EnemyPortraitSprite 
@onready var player_sprite = %PlayerSprite
@onready var background = get_node_or_null("%Background")
@onready var floor_rect = get_node_or_null("%FloorRect")

var card_scene = preload("res://features/combat/CardIcon.tscn")
var full_card_scene = preload("res://features/combat/Card.tscn")
var victory_overlay_scene = preload("res://features/combat/VictoryScreen.tscn")
var in_game_menu_scene = preload("res://features/ui/InGameMenu.tscn")

# --- Combat State ---
var flipped_cards: Array = []
var can_flip: bool = false 
var is_battle_over: bool = false
var difficulty: int = 0
var current_room_res: RoomData = null
var current_enemy_res: EnemyData = null
var current_player_res: PlayerData = null
var current_object_res: ObjectData = null
var in_game_menu = null
var victory_overlay = null
var is_cleared_room: bool = false
var is_object_room: bool = false
var death_transition_in_progress: bool = false

# Current Stats for Calculation
var p_hp: int = 1
var e_hp: int = 1
var max_e_hp: int = 1 

var p_atk: int = 0 # Base attack
var p_def: int = 0 # Base defense
var temp_armor_bonus: int = 0 # Temporary defense from matched armor cards
var temp_enemy_armor_bonus: int = 0
var round_number: int = 1
var keyboard_selected_card_index: int = -1
var keyboard_selection_active: bool = false
var card_selection_style: StyleBoxFlat
var card_preview_layer: CanvasLayer = null
var victory_overlay_layer: CanvasLayer = null
var card_preview_root: Control = null
var card_preview_holder: CenterContainer = null
var active_preview_card: Control = null
var player_discard_root: Control = null
var player_discard_frame: Control = null
var player_discard_card_holder: CenterContainer = null
var player_discard_card_view: Control = null
var enemy_intent_root: Control = null
var enemy_intent_outline: Control = null
var enemy_intent_card_holder: CenterContainer = null
var enemy_intent_card_view: Control = null
var enemy_intent_preview_root: Control = null
var enemy_intent_preview_holder: CenterContainer = null
var active_enemy_intent_preview_card: Control = null
var current_enemy_intent_card_id: String = ""
var current_enemy_intent_card_res: CardData = null
var enemy_intent_preview_dismiss_requested: bool = false
var object_reward_preview_dismiss_requested: bool = false
var object_reward_preview_active: bool = false
var is_log_expanded: bool = false
var log_collapsed_global_rect: Rect2 = Rect2()
var _active_room_dialog_lines: Array[Dictionary] = []
var _room_dialog_index: int = -1
var _room_dialog_complete: bool = false
var _room_dialog_on_complete: Callable
var _dialog_box_expanded_height := 200.0
var _dialog_box_collapsed_height := 88.0
var tutorial_overlay_layer: CanvasLayer = null
var tutorial_overlay_root: Control = null
var tutorial_message_label: Label = null
var tutorial_hint_label: Label = null
var tutorial_resume_can_flip: bool = false
var tutorial_active: bool = false
var tutorial_id: String = ""

var active_status_effects = {"player": [], "enemy": []} # e.g. ["vulnerable", "charged"]
const ENERGY_PIP_FULL = Color(1.0, 0.86, 0.35, 1.0)
const ENERGY_PIP_EMPTY = Color(0.46, 0.35, 0.08, 1.0)
const CARD_SELECTION_OUTLINE = "KeyboardCardSelectionOutline"
const ACTION_ANIM_DURATION = 0.35
const ENEMY_INTENT_PREVIEW_SECONDS = 2.0
const ENEMY_DEFAULT_CARD_ID = "enemy_default"
const PLAYER_DISCARD_SIZE = Vector2(150.0, 216.0)
const ENEMY_INTENT_SIZE = Vector2(150.0, 216.0)
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "gameplay"
const RUN_LOG_KEY := "show_run_log"
const TUTORIAL_TIPS_KEY := "tutorial_tips"
const TUTORIAL_FLAGS_SECTION := "tutorial_flags"
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
const DIALOG_COLOR_PLAYER = Color(0.45, 0.68, 1.0, 1.0)
const DIALOG_COLOR_ENEMY = Color(1.0, 0.42, 0.42, 1.0)
const DIALOG_COLOR_NPC = Color(0.46, 0.9, 0.52, 1.0)
const DIALOG_COLOR_NARRATOR = Color(0.96, 0.96, 0.96, 1.0)
const DEFAULT_UNIT_HFRAMES = 8
const DEFAULT_UNIT_VFRAMES = 1
const DEFAULT_UNIT_TOTAL_FRAMES = 8
const DEFAULT_UNIT_FRAME_SPEED = 0.1
const ENERGY_PIP_CHAR = "▮"

const OBJECT_CARD_BACK_ICON_PATH = "res://assets/cards/back_icon/card_back_object_icon.png"
const TUTORIAL_HUT_ROOM_PATH = "res://data/rooms/tutorial/tutorial_hut.tres"
const TUTORIAL_WHARF_ROOM_PATH = "res://data/rooms/tutorial/tutorial_wharf.tres"
const OBJECT_FALLBACK_REWARD_KEYS = [
	"card:healing_herb",
	"card:bread",
	"card:electric_gel",
	"card:trap",
	"card:bomb",
	"card:gold_coins"
]

func _ready():
	_setup_tutorial_overlay()
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
		is_object_room = (
			current_room_res != null
			and current_room_res.enemy_id == ""
			and current_room_res.object_id != ""
			and not bool(node_data.get("object_consumed", false))
		)
		if is_object_room:
			current_object_res = _load_object_resource(current_room_res.object_id)
	
	# Instance the In-Game Menu (Esc key)
	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()
	if avatar_button and not avatar_button.pressed.is_connected(_on_avatar_pressed):
		avatar_button.pressed.connect(_on_avatar_pressed)
	if has_node("%MenuIconBtn"):
		%MenuIconBtn.pressed.connect(_toggle_in_game_menu)
	if exit_button:
		exit_button.pressed.connect(_exit_cleared_room)
	if dialog_overlay_bg and not dialog_overlay_bg.gui_input.is_connected(_on_dialog_overlay_gui_input):
		dialog_overlay_bg.gui_input.connect(_on_dialog_overlay_gui_input)
	if dialog_box and not dialog_box.gui_input.is_connected(_on_dialog_overlay_gui_input):
		dialog_box.gui_input.connect(_on_dialog_overlay_gui_input)
	_configure_top_bar()
	if dialog_speaker:
		dialog_speaker.text = LocalizationManager.translate("dialog.speaker.narrator", "Narrator")
		dialog_speaker.add_theme_color_override("font_color", DIALOG_COLOR_NARRATOR)
	if dialog_text:
		dialog_text.add_theme_color_override("font_color", DIALOG_COLOR_NARRATOR)

	# Debug win / lose connections
	# if has_node("%DebugWinBtn"): %DebugWinBtn.pressed.connect(_debug_win)
	# if has_node("%DebugLoseBtn"): %DebugLoseBtn.pressed.connect(_debug_lose)

	_setup_player_spritesheet()
	if is_cleared_room:
		if is_object_room:
			_setup_object_portrait()
			_prepare_object_room_ui()
		_setup_cleared_room_view()
	elif is_object_room:
		_setup_object_portrait()
		_prepare_object_room_ui()
		battle_ui.show()
		dialog_overlay.hide()
		can_flip = true
		setup_board()
	else:
		_setup_enemy_portrait()
		_init_encounter()
	
	# Music 
	var battle_track = AudioData.TRACKS["OBJECT_STANDARD"] if is_object_room else AudioData.TRACKS["BATTLE_STANDARD"]
	SignalBus.music_change_requested.emit(battle_track, 1.0)

	# Initial UI Sync
	_sync_status_bar()
	update_ui()
	_setup_card_selection_style()
	_setup_card_preview_overlay()
	_setup_player_discard_ui()
	_setup_enemy_intent_ui()
	_setup_battle_log_ui()
	if not SignalBus.run_log_updated.is_connected(_on_run_log_updated):
		SignalBus.run_log_updated.connect(_on_run_log_updated)
	add_log("Battle begins.")
	_update_character_placement()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_maybe_show_room_tutorial()

func _input(event):
	if tutorial_active:
		if _is_tutorial_dismiss_input(event):
			_dismiss_tutorial_overlay()
			get_viewport().set_input_as_handled()
		return
	if _is_enemy_intent_preview_visible():
		var is_key_press = event is InputEventKey and event.pressed and not event.is_echo()
		var is_mouse_press = event is InputEventMouseButton and event.pressed
		if is_key_press or is_mouse_press:
			_request_enemy_intent_preview_dismiss()
			_hide_enemy_intent_preview()
			get_viewport().set_input_as_handled()
			return

	if is_log_expanded and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _is_point_inside_log(event.position):
			is_log_expanded = false
			_refresh_log_view()
			get_viewport().set_input_as_handled()
			return

	if _is_card_preview_visible():
		if object_reward_preview_active:
			var is_key_press = event is InputEventKey and event.pressed and not event.is_echo()
			var is_mouse_press = event is InputEventMouseButton and event.pressed
			if is_key_press or is_mouse_press:
				object_reward_preview_dismiss_requested = true
				get_viewport().set_input_as_handled()
			return
		if (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_accept"):
			_hide_card_preview()
			return

	# Escape toggles the in-game menu.
	if event.is_action_pressed("ui_cancel"):
		_toggle_in_game_menu()
		return

	# Dialog overlay: Enter accepts the primary option (e.g. "Enter Combat").
	if _is_room_dialog_active() and _is_narration_progress_input(event):
		_handle_dialog_overlay_progress_input()
		return
	if dialog_overlay and dialog_overlay.visible and _is_narration_progress_input(event):
		_handle_dialog_overlay_progress_input()
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
	get_tree().change_scene_to_file(GameManager.get_active_biome_map_scene_path())

func _on_avatar_pressed():
	GameManager.profile_return_scene = GameManager.get_active_biome_map_scene_path()
	get_tree().change_scene_to_file("res://features/ui/CharacterScreen.tscn")

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
	if _is_room_dialog_active():
		_advance_room_dialog()
		return
	if not has_node("%OptionContainer"):
		return
	for child in %OptionContainer.get_children():
		if child is Button and child.visible and not child.disabled:
			(child as Button).pressed.emit()
			return

func _dialog_has_primary_option() -> bool:
	if not has_node("%OptionContainer"):
		return false
	for child in %OptionContainer.get_children():
		if child is Button and child.visible and not child.disabled:
			return true
	return false

func _is_dialog_box_expanded() -> bool:
	return dialog_box != null and (dialog_box.offset_bottom - dialog_box.offset_top) > (_dialog_box_collapsed_height + 1.0)

func _is_narration_progress_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.is_echo()
	if event is InputEventMouseButton:
		return event.pressed
	return false

func _should_close_cleared_room_overlay() -> bool:
	if not is_cleared_room or dialog_overlay == null or not dialog_overlay.visible or dialog_text == null:
		return false
	var cleared_text = LocalizationManager.translate("dialog.room.cleared", "You see nothing further of note here.")
	return dialog_text.text == cleared_text

func _handle_dialog_overlay_progress_input():
	if _is_room_dialog_active():
		_advance_room_dialog()
	elif _should_close_cleared_room_overlay():
		dialog_overlay.hide()
	elif _dialog_has_primary_option():
		_activate_dialog_primary_option()
	elif _is_dialog_box_expanded():
		_configure_dialog_box(false)
	elif dialog_overlay:
		dialog_overlay.hide()
	get_viewport().set_input_as_handled()

func _on_dialog_overlay_gui_input(event: InputEvent):
	if dialog_overlay == null or not dialog_overlay.visible:
		return
	if not _is_narration_progress_input(event):
		return
	_handle_dialog_overlay_progress_input()

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
	if is_object_room:
		if enemy_atk_val:
			enemy_atk_val.text = "-"
		if enemy_def_val:
			enemy_def_val.text = "-"
	elif current_enemy_res:
		enemy_atk_val.text = str(current_enemy_res.base_damage)
		enemy_def_val.text = str(current_enemy_res.armor + temp_enemy_armor_bonus)
	
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
	var biome_name = current_room_res.biome.capitalize() if current_room_res else "Unknown"
	var room_name = current_room_res.room_name if current_room_res else "Battle"
	if biome_label:
		biome_label.text = biome_name
	if tracker_text:
		tracker_text.text = room_name
	if phase_label:
		phase_label.text = "ROUND: %d" % round_number

func _configure_top_bar():
	if status_bar:
		status_bar.visible = true
	if avatar_button:
		avatar_button.disabled = false
		avatar_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if has_node("%MenuIconBtn"):
		var menu_icon_btn = %MenuIconBtn
		if menu_icon_btn is BaseButton:
			menu_icon_btn.disabled = false
		menu_icon_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if story_button:
		story_button.disabled = true
		story_button.modulate = Color(0.6, 0.6, 0.6, 1.0)
		story_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if energy_pips:
		energy_pips.visible = true
	if exit_button:
		exit_button.visible = false
		exit_button.text = LocalizationManager.translate("dialog.exit_overworld", "Exit to Overworld")

func _set_combat_ui_visibility(show_stage: bool, show_log: bool = true):
	if battle_ui:
		battle_ui.show()
	if status_bar:
		status_bar.visible = true
	if stage_layout_container:
		stage_layout_container.visible = true
		stage_layout_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stage_layout:
		stage_layout.modulate.a = 1.0 if show_stage else 0.0
	if battle_log_row:
		battle_log_row.visible = show_log
	_pin_log_to_bottom_row()

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
		if is_object_room:
			_show_reward_preview_for_key(card.card_type, false)
		else:
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
		if is_object_room:
			await _play_object_reward_focus_preview(c1.card_type)
			await _resolve_object_match(c1.card_type)
			return
		_process_combat_action(c1.card_type)
		update_ui()
		if e_hp <= 0:
			var lethal_card_res = _load_card_data(c1.card_type)
			if lethal_card_res:
				_refresh_player_discard_preview(lethal_card_res)
			_hide_card_preview()
			_check_win_loss()
			return
		await _show_card_preview_for_id(c1.card_type, true, true)
		_check_win_loss()
		
		# Resolve the turn attempt since a match was found
		_resolve_turn_end()
		
	elif GameManager.current_energy <= 0:
		# FAILURE: Out of energy and no pairs exist in the turned cards
		can_flip = false
		add_log("No cards matched.")
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree() or is_battle_over: return
		if is_object_room:
			_resolve_turn_end()
		else:
			await _enemy_turn()
			update_ui()
			_check_win_loss()
			_resolve_turn_end()

func _resolve_turn_end():
	if is_battle_over: return
	_clear_keyboard_card_selection()
	
	# Flip back any remaining unmatched cards in the current attempt pool
	_flip_back_unmatched_face_up_cards()
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
		_flip_back_unmatched_face_up_cards()
		flipped_cards.clear()
		
		await get_tree().create_timer(0.8).timeout
		_trigger_reshuffle()
	elif _should_reshuffle():
		_trigger_reshuffle()
	else:
		_flip_back_unmatched_face_up_cards()
		can_flip = true
		_toggle_grid_interaction(true)

func _toggle_grid_interaction(enabled: bool):
	for card in grid.get_children():
		if card is TextureButton:
			card.disabled = not enabled or card.is_matched

func _flip_back_unmatched_face_up_cards():
	for card in grid.get_children():
		if card is TextureButton and is_instance_valid(card) and card.is_face_up and not card.is_matched:
			card.flip_back()

# --- DAMAGE CALCULATION (Extensible) ---
func _process_combat_action(card_id: String):
	var res = DataManager.get_resource("res://data/cards/" + card_id + ".tres")
	if not res: return
	var localized_card_name = LocalizationManager.localized_resource_name(res, res.name)
	
	var type = "magical" if card_id in ["frost", "lightning", "bomb", "scroll"] else "physical"
	
	if res.value > 0:
		if res.type == "attack":
			_play_unit_sheet_temporarily(player_sprite, current_player_res, "attack_sheet", ACTION_ANIM_DURATION)
			_play_unit_sheet_temporarily(enemy_sprite, current_enemy_res, "defend_sheet", ACTION_ANIM_DURATION)
			var enemy_armor = (current_enemy_res.armor if current_enemy_res else 0) + temp_enemy_armor_bonus
			var final_dmg = _calculate_final_damage(res.value, type, "player", "enemy")
			e_hp = max(0, e_hp - final_dmg)
			var raw_damage = res.value + (p_atk if type == "physical" else 0)
			var negated = max(0, raw_damage - final_dmg) if type == "physical" else 0
			add_log("%s card matched." % localized_card_name)
			if type == "physical":
				add_log("Enemy armour negates %d damage." % min(enemy_armor, negated))
				if temp_enemy_armor_bonus > 0:
					add_log("Enemy guard breaks after the hit.")
					temp_enemy_armor_bonus = 0
					_sync_stat_icons()
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
			add_log("Matched %s: Restored %d HP." % [localized_card_name, res.value])
			_flash_unit(%PlayerFlash, Color.SEA_GREEN)
			SignalBus.battle_intensity_changed.emit(0.5)
			SignalBus.sfx_triggered.emit(AudioData.SFX["HEAL"])

		elif res.type == "armor":
			temp_armor_bonus += int(res.value)
			add_log("Matched %s: +%d armor for the next hit." % [localized_card_name, int(res.value)])
			_flash_unit(%PlayerFlash, Color.SEA_GREEN)
			SignalBus.battle_intensity_changed.emit(0.5)
			SignalBus.sfx_triggered.emit(AudioData.SFX["SHIELD"])

func _resolve_object_match(reward_key: String):
	var reward = _parse_reward_key(reward_key)
	if reward.is_empty():
		return
	var reward_kind = str(reward.get("kind", "card"))
	var reward_id = str(reward.get("id", ""))
	if reward_kind == "item":
		GameManager.add_item(reward_id)
		var item_data = _load_item_data(reward_id)
		var item_name = item_data.name if item_data else reward_id.replace("_", " ").capitalize()
		add_log("You found %s." % item_name)
	else:
		await _apply_object_card_effect(reward_id)
	if not is_inside_tree() or p_hp <= 0:
		return
	GameManager.current_hp = p_hp
	GameManager.register_room_interaction_complete(GameManager.current_node, true)
	is_cleared_room = true
	await get_tree().create_timer(0.2).timeout
	if is_inside_tree():
		_setup_cleared_room_view()

func _apply_object_card_effect(card_id: String):
	var card_res = _load_card_data(card_id)
	if card_res == null:
		return
	var localized_name = LocalizationManager.localized_resource_name(card_res, card_res.name)
	match card_id:
		"gold_coins":
			var gold_gain = max(1, int(card_res.value))
			GameManager.gold += gold_gain
			GameManager.world_state.global.gold = GameManager.gold
			add_log("%s grants %d gold." % [localized_name, gold_gain])
			return
		"electric_gel":
			GameManager.current_energy = max(GameManager.current_energy, GameManager.base_energy + 1)
			add_log("%s surges through you. Energy rises." % localized_name)
			return

	match String(card_res.type):
		"heal", "heal_large":
			p_hp = min(GameManager.player_hp_total, p_hp + int(card_res.value))
			add_log("%s restores %d HP." % [localized_name, int(card_res.value)])
			_flash_unit(%PlayerFlash, Color.SEA_GREEN)
		"treasure":
			var treasure_gain = max(1, int(card_res.value))
			GameManager.gold += treasure_gain
			GameManager.world_state.global.gold = GameManager.gold
			add_log("%s grants %d gold." % [localized_name, treasure_gain])
		_:
			var incoming_damage = max(1, int(card_res.value))
			p_hp = max(0, p_hp - incoming_damage)
			add_log("%s hits you for %d damage." % [localized_name, incoming_damage])
			_flash_unit(%PlayerFlash, Color.ORANGE_RED)
			if p_hp <= 0:
				await _handle_player_death_transition()

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
		var arm = (current_enemy_res.armor if current_enemy_res else 0) + temp_enemy_armor_bonus
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
	if current_enemy_intent_card_res == null:
		_roll_next_enemy_intent_card()
	if current_enemy_intent_card_res == null:
		return
	await _play_enemy_intent_preview(current_enemy_intent_card_res)
	if is_battle_over:
		return
	_execute_enemy_card(current_enemy_intent_card_res)
	_roll_next_enemy_intent_card()

func _execute_enemy_card(card_res: CardData):
	if card_res == null:
		return
	var localized_name = LocalizationManager.localized_resource_name(card_res, card_res.name)
	match String(card_res.type):
		"attack":
			_play_unit_sheet_temporarily(enemy_sprite, current_enemy_res, "attack_sheet", ACTION_ANIM_DURATION)
			_play_unit_sheet_temporarily(player_sprite, current_player_res, "defend_sheet", ACTION_ANIM_DURATION)
			var final_dmg = _calculate_final_damage(int(card_res.value), "physical", "enemy", "player")
			var enemy_raw = int(card_res.value) + (int(current_enemy_res.base_damage) if current_enemy_res else 0)
			var enemy_negated = max(0, enemy_raw - final_dmg)
			p_hp = max(0, p_hp - final_dmg)
			add_log("Enemy reveals %s." % localized_name)
			add_log("Enemy deals %d damage." % enemy_raw)
			add_log("Your armour negates %d damage." % enemy_negated)
			add_log("You receive %d damage." % final_dmg)
			if temp_armor_bonus > 0:
				add_log("Armor bonus breaks after the hit.")
				temp_armor_bonus = 0
				_sync_stat_icons()
			_flash_unit(%PlayerFlash, Color.CRIMSON)
		"armor":
			temp_enemy_armor_bonus += int(card_res.value)
			add_log("Enemy reveals %s." % localized_name)
			add_log("Enemy gains %d armor." % int(card_res.value))
			_play_unit_sheet_temporarily(enemy_sprite, current_enemy_res, "defend_sheet", ACTION_ANIM_DURATION)
			_flash_unit(%EnemyFlash, Color.SEA_GREEN)
		_:
			add_log("Enemy reveals %s." % localized_name)
			add_log("Enemy hesitates and does nothing.")
	_sync_stat_icons()

func _get_enemy_card_pool_ids() -> Array[String]:
	if current_enemy_res and not current_enemy_res.enemy_cards.is_empty():
		return current_enemy_res.enemy_cards.duplicate()
	return [ENEMY_DEFAULT_CARD_ID]

func _load_enemy_card_resource(card_id: String) -> CardData:
	if card_id == "":
		return null
	var res_path = "res://data/cards/%s.tres" % card_id
	if not ResourceLoader.exists(res_path):
		return null
	return load(res_path) as CardData

func _roll_next_enemy_intent_card():
	current_enemy_intent_card_id = ""
	current_enemy_intent_card_res = null
	var pool_ids = _get_enemy_card_pool_ids()
	if pool_ids.is_empty():
		_refresh_enemy_intent_preview()
		return
	var weighted_cards: Array[Dictionary] = []
	var total_weight = 0.0
	for card_id in pool_ids:
		var card_res = _load_enemy_card_resource(str(card_id))
		if card_res == null:
			continue
		var card_power = max(1, int(card_res.card_power))
		var weight = 1.0 / float(card_power)
		total_weight += weight
		weighted_cards.append({"id": str(card_id), "res": card_res, "weight": weight})
	if weighted_cards.is_empty():
		_refresh_enemy_intent_preview()
		return
	var roll = randf() * total_weight
	var running = 0.0
	for entry in weighted_cards:
		running += float(entry["weight"])
		if roll <= running:
			current_enemy_intent_card_id = str(entry["id"])
			current_enemy_intent_card_res = entry["res"] as CardData
			break
	if current_enemy_intent_card_res == null:
		var fallback = weighted_cards[0]
		current_enemy_intent_card_id = str(fallback["id"])
		current_enemy_intent_card_res = fallback["res"] as CardData
	_refresh_enemy_intent_preview()

func _setup_enemy_intent_ui():
	if enemy_intent_root or not battle_ui:
		return
	enemy_intent_root = Control.new()
	enemy_intent_root.name = "EnemyIntentRoot"
	enemy_intent_root.custom_minimum_size = ENEMY_INTENT_SIZE
	enemy_intent_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enemy_intent_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_intent_root.z_index = 20
	if enemy_column_ui:
		enemy_column_ui.add_child(enemy_intent_root)
	else:
		battle_ui.add_child(enemy_intent_root)

	enemy_intent_outline = _create_card_slot_frame()
	enemy_intent_root.add_child(enemy_intent_outline)

	enemy_intent_card_holder = CenterContainer.new()
	enemy_intent_card_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enemy_intent_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_intent_root.add_child(enemy_intent_card_holder)

	enemy_intent_preview_root = Control.new()
	enemy_intent_preview_root.visible = false
	enemy_intent_preview_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enemy_intent_preview_root.mouse_filter = Control.MOUSE_FILTER_STOP
	enemy_intent_preview_root.z_index = 300
	battle_ui.add_child(enemy_intent_preview_root)
	enemy_intent_preview_root.gui_input.connect(_on_enemy_intent_preview_gui_input)

	var dimmer = ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.28)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	enemy_intent_preview_root.add_child(dimmer)

	enemy_intent_preview_holder = CenterContainer.new()
	enemy_intent_preview_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enemy_intent_preview_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	enemy_intent_preview_root.add_child(enemy_intent_preview_holder)
	_position_enemy_intent_ui()
	_refresh_enemy_intent_preview()
	if is_object_room:
		enemy_intent_root.visible = false

func _position_enemy_intent_ui():
	if enemy_intent_root == null:
		return
	if enemy_column_ui and enemy_intent_root.get_parent() != enemy_column_ui:
		var previous_parent = enemy_intent_root.get_parent()
		if previous_parent:
			previous_parent.remove_child(enemy_intent_root)
		enemy_column_ui.add_child(enemy_intent_root)
	if enemy_column_ui and enemy_stats_hud:
		var target_index = enemy_stats_hud.get_index()
		if enemy_intent_root.get_index() != target_index:
			enemy_column_ui.move_child(enemy_intent_root, target_index)

func _setup_player_discard_ui():
	if player_discard_root or not battle_ui:
		return
	player_discard_root = Control.new()
	player_discard_root.name = "PlayerDiscardRoot"
	player_discard_root.custom_minimum_size = PLAYER_DISCARD_SIZE
	player_discard_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	player_discard_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_discard_root.z_index = 20
	if player_column_ui:
		player_column_ui.add_child(player_discard_root)
	else:
		battle_ui.add_child(player_discard_root)

	player_discard_frame = _create_card_slot_frame()
	player_discard_root.add_child(player_discard_frame)

	player_discard_card_holder = CenterContainer.new()
	player_discard_card_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_discard_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_discard_root.add_child(player_discard_card_holder)
	_position_player_discard_ui()

func _position_player_discard_ui():
	if player_discard_root == null:
		return
	if player_column_ui and player_discard_root.get_parent() != player_column_ui:
		var previous_parent = player_discard_root.get_parent()
		if previous_parent:
			previous_parent.remove_child(player_discard_root)
		player_column_ui.add_child(player_discard_root)
	if player_column_ui and player_stats_hud:
		var target_index = player_stats_hud.get_index()
		if player_discard_root.get_index() != target_index:
			player_column_ui.move_child(player_discard_root, target_index)

func _refresh_player_discard_preview(card_data: CardData):
	if player_discard_card_view and is_instance_valid(player_discard_card_view):
		player_discard_card_view.queue_free()
	player_discard_card_view = null
	if card_data == null or player_discard_card_holder == null:
		return
	var card_view = full_card_scene.instantiate()
	player_discard_card_view = card_view
	player_discard_card_holder.add_child(card_view)
	card_view.custom_minimum_size = PLAYER_DISCARD_SIZE
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
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _create_card_slot_frame() -> Panel:
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.18)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _refresh_enemy_intent_preview():
	if enemy_intent_card_view and is_instance_valid(enemy_intent_card_view):
		enemy_intent_card_view.queue_free()
	enemy_intent_card_view = null
	if not enemy_intent_card_holder or current_enemy_intent_card_res == null:
		return
	var card_view = full_card_scene.instantiate()
	enemy_intent_card_view = card_view
	enemy_intent_card_holder.add_child(card_view)
	card_view.custom_minimum_size = ENEMY_INTENT_SIZE
	if card_view.has_method("setup"):
		card_view.setup(current_enemy_intent_card_res)
	var back_face = card_view.get_node_or_null("%BackFace")
	if back_face:
		back_face.visible = false
	var front_face = card_view.get_node_or_null("%FrontFace")
	if front_face:
		front_face.visible = true
	card_view.is_face_up = true
	card_view.disabled = true
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _is_enemy_intent_preview_visible() -> bool:
	return enemy_intent_preview_root != null and enemy_intent_preview_root.visible

func _play_enemy_intent_preview(card_res: CardData):
	if card_res == null or enemy_intent_preview_root == null or enemy_intent_preview_holder == null:
		return
	if active_enemy_intent_preview_card and is_instance_valid(active_enemy_intent_preview_card):
		active_enemy_intent_preview_card.queue_free()
		active_enemy_intent_preview_card = null

	var card_view = full_card_scene.instantiate()
	active_enemy_intent_preview_card = card_view
	enemy_intent_preview_holder.add_child(card_view)
	card_view.custom_minimum_size = Vector2(280, 420)
	if card_view.has_method("setup"):
		card_view.setup(card_res)
	var back_face = card_view.get_node_or_null("%BackFace")
	if back_face:
		back_face.visible = false
	var front_face = card_view.get_node_or_null("%FrontFace")
	if front_face:
		front_face.visible = true
	card_view.is_face_up = true
	card_view.disabled = false

	enemy_intent_preview_root.visible = true
	enemy_intent_preview_dismiss_requested = false
	card_view.top_level = true
	card_view.z_index = 310
	var start_rect = enemy_intent_root.get_global_rect() if enemy_intent_root else Rect2(Vector2(960, 40), Vector2(120, 180))
	var viewport_rect = get_viewport_rect()
	var target_size = Vector2(280, 420)
	var target_pos = viewport_rect.size * 0.5 - (target_size * 0.5)
	card_view.global_position = start_rect.get_center() - (target_size * 0.2)
	card_view.scale = Vector2(0.32, 0.32)
	card_view.modulate = Color(1, 1, 1, 0.9)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_view, "global_position", target_pos, 0.25)
	tween.parallel().tween_property(card_view, "scale", Vector2.ONE, 0.25)
	await tween.finished
	if not is_inside_tree() or not is_instance_valid(card_view):
		_hide_enemy_intent_preview()
		return

	var elapsed = 0.0
	while elapsed < ENEMY_INTENT_PREVIEW_SECONDS and not enemy_intent_preview_dismiss_requested and _is_enemy_intent_preview_visible() and is_inside_tree():
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05

	if not is_inside_tree() or not is_instance_valid(card_view):
		_hide_enemy_intent_preview()
		return
	if not _is_enemy_intent_preview_visible():
		return

	var end_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	end_tween.tween_property(card_view, "global_position", start_rect.get_center() - (target_size * 0.2), 0.22)
	end_tween.parallel().tween_property(card_view, "scale", Vector2(0.32, 0.32), 0.22)
	end_tween.parallel().tween_property(card_view, "modulate:a", 0.0, 0.22)
	await end_tween.finished
	_hide_enemy_intent_preview()

func _request_enemy_intent_preview_dismiss():
	if _is_enemy_intent_preview_visible():
		enemy_intent_preview_dismiss_requested = true

func _hide_enemy_intent_preview():
	enemy_intent_preview_dismiss_requested = false
	if enemy_intent_preview_root:
		enemy_intent_preview_root.visible = false
	if active_enemy_intent_preview_card and is_instance_valid(active_enemy_intent_preview_card):
		active_enemy_intent_preview_card.queue_free()
	active_enemy_intent_preview_card = null

func _on_enemy_intent_preview_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_request_enemy_intent_preview_dismiss()
		get_viewport().set_input_as_handled()

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
	await _animate_board_reset_before_reshuffle()
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree() and not is_battle_over:
		setup_board()
		can_flip = true
		_toggle_grid_interaction(true)

func _animate_board_reset_before_reshuffle():
	var face_up_cards: Array = []
	for card in grid.get_children():
		if card is TextureButton and is_instance_valid(card) and card.is_face_up:
			face_up_cards.append(card)
	if face_up_cards.is_empty():
		return

	for card in face_up_cards:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(card, "scale:x", 0.0, 0.1)
		tween.tween_callback(func():
			if not is_instance_valid(card):
				return
			card.is_face_up = false
			if card.front_face:
				card.front_face.visible = false
			if card.back_face:
				card.back_face.visible = true
			card.z_index = 0
		)
		tween.tween_property(card, "scale:x", 1.0, 0.1)

	await get_tree().create_timer(0.22).timeout

# --- UTILS & VISUALS ---

func _init_encounter():
	battle_ui.hide()
	dialog_overlay.show()
	_configure_dialog_box(true)
	for child in %OptionContainer.get_children(): child.queue_free()
	var room_lines = RoomDialogService.resolve_room_dialog(current_room_res, GameManager.current_node)
	if not room_lines.is_empty():
		_begin_room_dialog(room_lines, _show_enter_combat_button)
		return
	_show_enter_combat_button()

func _setup_cleared_room_view():
	can_flip = false
	if grid:
		grid.visible = false
	is_log_expanded = false
	_restore_log_to_collapsed_row()
	_set_combat_ui_visibility(false, true)
	_refresh_log_view()
	dialog_overlay.show()
	_configure_dialog_box(true)
	if enemy_sprite:
		enemy_sprite.visible = false
	if has_node("%EnemyFlash"):
		%EnemyFlash.visible = false
	for child in %OptionContainer.get_children():
		child.queue_free()
	if is_object_room:
		dialog_speaker.text = LocalizationManager.translate("dialog.speaker.narrator", "Narrator")
		dialog_text.text = LocalizationManager.translate("dialog.room.cleared", "This room has already been cleared.")
		_append_dialog_log(dialog_speaker.text, dialog_text.text)
		_show_exit_cleared_room_button()
		return
	var room_lines = RoomDialogService.resolve_room_dialog(current_room_res, GameManager.current_node)
	if not room_lines.is_empty():
		_begin_room_dialog(room_lines, _show_exit_cleared_room_button)
		return
	dialog_speaker.text = LocalizationManager.translate("dialog.speaker.narrator", "Narrator")
	dialog_text.text = LocalizationManager.translate("dialog.room.cleared", "This room has already been cleared.")
	_append_dialog_log(dialog_speaker.text, dialog_text.text)
	_show_exit_cleared_room_button()

func _exit_cleared_room():
	# Cleared-room "Exit to Overworld" should always return to the world map view.
	GameManager.consume_pending_post_battle_scene(GameManager.get_active_biome_map_scene_path())
	SceneTransition.change_scene_to_file(GameManager.get_active_biome_map_scene_path())

func _begin_room_dialog(lines: Array[Dictionary], on_complete: Callable):
	_active_room_dialog_lines = lines
	_room_dialog_index = -1
	_room_dialog_complete = false
	_room_dialog_on_complete = on_complete
	for child in %OptionContainer.get_children():
		child.queue_free()
	dialog_overlay.show()
	_configure_dialog_box(true)
	_advance_room_dialog()

func _is_room_dialog_active() -> bool:
	return not _active_room_dialog_lines.is_empty() and not _room_dialog_complete

func _advance_room_dialog():
	if not _is_room_dialog_active():
		return
	_room_dialog_index += 1
	if _room_dialog_index >= _active_room_dialog_lines.size():
		_room_dialog_complete = true
		_active_room_dialog_lines.clear()
		_configure_dialog_box(false)
		if _room_dialog_on_complete.is_valid():
			_room_dialog_on_complete.call()
		return
	var line = _active_room_dialog_lines[_room_dialog_index]
	dialog_speaker.text = str(line.get("speaker_name", LocalizationManager.translate("dialog.speaker.narrator", "Narrator")))
	dialog_text.text = str(line.get("text", ""))
	_apply_dialog_speaker_style(str(line.get("speaker_role", "narrator")), line.get("speaker_color", DIALOG_COLOR_NARRATOR))
	_append_dialog_log(dialog_speaker.text, dialog_text.text, str(line.get("speaker_role", "narrator")), line.get("speaker_color", DIALOG_COLOR_NARRATOR))

func _apply_dialog_speaker_style(speaker_role: String, speaker_color = DIALOG_COLOR_NARRATOR):
	var resolved_color: Color = speaker_color if speaker_color is Color else Color.from_string(str(speaker_color), _get_dialog_speaker_default_color(speaker_role))
	if dialog_speaker:
		dialog_speaker.add_theme_color_override("font_color", resolved_color)
	if dialog_text:
		dialog_text.add_theme_color_override("font_color", resolved_color)

func _get_dialog_speaker_default_color(speaker_role: String) -> Color:
	match speaker_role:
		"player":
			return DIALOG_COLOR_PLAYER
		"npc":
			return DIALOG_COLOR_NPC
		"enemy":
			return DIALOG_COLOR_ENEMY
		_:
			return DIALOG_COLOR_NARRATOR

func _configure_dialog_box(expanded: bool):
	if not dialog_box:
		return
	var target_height = _dialog_box_expanded_height if expanded else _dialog_box_collapsed_height
	dialog_box.offset_top = -target_height * 0.5
	dialog_box.offset_bottom = target_height * 0.5

func _show_enter_combat_button():
	_room_dialog_on_complete = Callable()
	_hide_exit_button()
	for child in %OptionContainer.get_children():
		child.queue_free()
	_configure_dialog_box(false)
	var btn = Button.new()
	btn.text = LocalizationManager.translate("dialog.enter_combat", "Enter Combat")
	btn.custom_minimum_size.y = 50
	btn.pressed.connect(func():
		dialog_overlay.hide()
		_set_combat_ui_visibility(true, true)
		can_flip = true
		setup_board()
	)
	%OptionContainer.add_child(btn)

func _show_exit_cleared_room_button():
	_room_dialog_on_complete = Callable()
	for child in %OptionContainer.get_children():
		child.queue_free()
	_configure_dialog_box(false)
	_set_combat_ui_visibility(false, false)
	_pin_log_to_bottom_row()
	if exit_button:
		exit_button.visible = true

func _hide_exit_button():
	if exit_button:
		exit_button.visible = false

func _append_dialog_log(speaker: String, text: String, speaker_role: String = "narrator", speaker_color = DIALOG_COLOR_NARRATOR):
	var resolved_color: Color = speaker_color if speaker_color is Color else Color.from_string(str(speaker_color), _get_dialog_speaker_default_color(speaker_role))
	GameManager.add_run_log({
		"text": "%s: %s" % [speaker, text],
		"speaker": speaker,
		"speaker_role": speaker_role,
		"speaker_color": resolved_color.to_html()
	})

func _check_win_loss():
	if is_battle_over: return
	
	if e_hp <= 0:
		is_battle_over = true
		if not is_object_room:
			SignalBus.music_change_requested.emit("", 1.0)
		GameManager.register_room_victory(GameManager.current_node, p_hp)
		var xp_reward = current_enemy_res.xp_reward if current_enemy_res else 0
		var return_scene = get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else ""
		GameManager.award_player_xp(xp_reward, return_scene)
		GameManager.add_run_log(
			LocalizationManager.format(
				"log.battle.victory",
				{"room": current_room_res.room_name if current_room_res else LocalizationManager.translate("log.battle.enemy", "enemy")},
				"Victory in {room}."
			)
		)
		await _fade_out_enemy_after_defeat()
		if not is_inside_tree():
			return
		_show_victory_overlay()
			
	elif p_hp <= 0:
		is_battle_over = true
		if death_transition_in_progress:
			return
		await _handle_player_death_transition()

func _handle_player_death_transition():
	if death_transition_in_progress:
		return
	death_transition_in_progress = true
	p_hp = 0
	GameManager.current_hp = 0
	update_ui(true)
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return
	if not GameManager.is_battle_mode:
		# Story mode: return to the current biome's permanent home, then show DeathScreen.
		GameManager.begin_new_story_run(GameManager.player_biome if GameManager.player_biome != "" else "town")
	await _fade_to_black_and_change_scene("res://features/ui/DeathScreen.tscn")


func update_ui(instant: bool = false):
	# Dynamic Text update
	player_hp_text.text = "%d / %d" % [p_hp, GameManager.player_hp_total]
	enemy_hp_text.text = current_object_res.name if is_object_room and current_object_res else "HP: %d" % e_hp
	
	# Dynamic Bar update with Tween
	var duration = 0.0 if instant else 0.4
	
	if player_hp_bar:
		player_hp_bar.max_value = GameManager.player_hp_total
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(player_hp_bar, "value", p_hp, duration)
	
	if enemy_hp_bar and not is_object_room:
		enemy_hp_bar.max_value = max_e_hp
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(enemy_hp_bar, "value", e_hp, duration)

	_sync_stat_icons()
	if phase_label:
		phase_label.text = "ROUND: %d" % round_number
	
	
func add_log(text):
	GameManager.add_run_log(text)

func _on_run_log_updated():
	_apply_log_visibility()
	_rebuild_log_entries()

func _get_log_entry_color(entry_data) -> Color:
	if entry_data is Dictionary:
		var color_value = str((entry_data as Dictionary).get("speaker_color", ""))
		if color_value != "":
			return Color.from_string(color_value, LOG_COLOR_NEUTRAL)
	var t = _get_log_entry_text(entry_data).to_lower()
	if "you deal" in t or "card matched" in t:
		return LOG_COLOR_GOOD
	if "trap deals" in t or "enemy deals" in t or "you receive" in t:
		return LOG_COLOR_BAD
	return LOG_COLOR_NEUTRAL

func _get_log_entry_text(entry_data) -> String:
	if entry_data is Dictionary:
		return str((entry_data as Dictionary).get("text", ""))
	return str(entry_data)

func _setup_battle_log_ui():
	if not log_display or not battle_log_row:
		return
	_apply_log_horizontal_constants()
	battle_log_row.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_log_row.custom_minimum_size.y = LOG_COLLAPSED_HEIGHT
	if not battle_log_row.gui_input.is_connected(_on_battle_log_row_gui_input):
		battle_log_row.gui_input.connect(_on_battle_log_row_gui_input)
	if not log_display.gui_input.is_connected(_on_log_display_gui_input):
		log_display.gui_input.connect(_on_log_display_gui_input)
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
	_apply_log_visibility()
	_rebuild_log_entries()
	_refresh_log_view()

func _debug_log_ui_event(source: String, event: InputEvent, response: String):
	var event_name := event.get_class() if event else "UnknownEvent"
	print("[InfoLog][BattleScene] %s received %s -> %s | expanded=%s scroll=%d" % [
		source,
		event_name,
		response,
		str(is_log_expanded),
		int(log_display.scroll_vertical) if log_display else 0
	])

func _rebuild_log_entries():
	if not log_box:
		return
	for child in log_box.get_children():
		child.queue_free()
	for entry in GameManager.get_run_log():
		var lbl = Label.new()
		lbl.text = "> " + _get_log_entry_text(entry)
		lbl.clip_text = true
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.add_theme_color_override("font_color", _get_log_entry_color(entry))
		log_box.add_child(lbl)
	_refresh_log_view()
	call_deferred("_scroll_log_to_latest")

func _on_battle_log_row_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_log_expanded = not is_log_expanded
		_refresh_log_view()
		_debug_log_ui_event("BattleLogRow", event, "toggle_expand")
		get_viewport().set_input_as_handled()

func _on_log_display_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_log_expanded = not is_log_expanded
			_refresh_log_view()
			_debug_log_ui_event("LogDisplay", event, "toggle_expand")
			get_viewport().set_input_as_handled()
			return
		if is_log_expanded and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			log_display.scroll_vertical = max(0, log_display.scroll_vertical - int(LOG_LINE_HEIGHT * 2.0))
			_debug_log_ui_event("LogDisplay", event, "scroll_up")
			get_viewport().set_input_as_handled()
			return
		if is_log_expanded and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var max_vscroll = max(0, int(log_box.size.y - log_display.size.y))
			log_display.scroll_vertical = min(max_vscroll, log_display.scroll_vertical + int(LOG_LINE_HEIGHT * 2.0))
			_debug_log_ui_event("LogDisplay", event, "scroll_down")
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
			viewport_size.y - expanded_height
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

func _pin_log_to_bottom_row():
	is_log_expanded = false
	_restore_log_to_collapsed_row()
	if battle_log_row:
		battle_log_row.visible = _is_run_log_enabled()
		if battle_log_row.get_parent():
			battle_log_row.get_parent().move_child(battle_log_row, battle_log_row.get_parent().get_child_count() - 1)
	if log_display:
		log_display.visible = true
		log_display.mouse_filter = Control.MOUSE_FILTER_PASS
		log_display.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		log_display.scroll_vertical = 0

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

func _apply_log_visibility():
	var enabled = _is_run_log_enabled()
	if battle_log_row:
		battle_log_row.visible = enabled
	if not enabled:
		is_log_expanded = false

func _is_run_log_enabled() -> bool:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return true
	return bool(config.get_value(SETTINGS_SECTION, RUN_LOG_KEY, true))
	
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
		_sync_flash_overlay(player_sprite, %PlayerFlash)
		return
	var idle_tex = load("res://assets/player/base_idle.png")
	if idle_tex:
		player_sprite.texture = idle_tex
		player_sprite.hframes = 6
		player_sprite.vframes = 6
		player_sprite.scale = Vector2(1.0, 1.0)
		player_sprite.offset.y = sprite_feet_offset
		_sync_flash_overlay(player_sprite, %PlayerFlash)
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
			_roll_next_enemy_intent_card()

func _load_object_resource(object_id: String) -> ObjectData:
	var base_path = "res://data/objects/%s" % object_id
	for ext in [".res", ".tres"]:
		var full_path = base_path + ext
		if ResourceLoader.exists(full_path):
			return load(full_path) as ObjectData
	return null

func _setup_object_portrait():
	if enemy_sprite == null:
		return
	if current_object_res == null:
		enemy_sprite.visible = false
		return
	enemy_sprite.visible = true
	enemy_sprite.texture = current_object_res.object_image
	enemy_sprite.hframes = max(1, int(current_object_res.hframes))
	enemy_sprite.vframes = max(1, int(current_object_res.vframes))
	enemy_sprite.frame = 0
	enemy_sprite.scale = Vector2.ONE
	enemy_sprite.offset.y = sprite_feet_offset
	enemy_sprite.flip_h = false
	_sync_flash_overlay(enemy_sprite, %EnemyFlash)
	_start_unit_animation(enemy_sprite, max(1, int(current_object_res.total_frames)), max(0.01, float(current_object_res.frame_speed)))

func _prepare_object_room_ui():
	if enemy_stats_hud:
		enemy_stats_hud.visible = false
	if enemy_hp_bar:
		enemy_hp_bar.visible = false
	if enemy_hp_text:
		enemy_hp_text.visible = true
	if enemy_intent_root:
		enemy_intent_root.visible = false
	if enemy_atk_val:
		enemy_atk_val.text = ""
	if enemy_def_val:
		enemy_def_val.text = ""
	if enemy_hp_text:
		enemy_hp_text.text = ""
	if enemy_sprite:
		enemy_sprite.visible = current_object_res != null
	if has_node("%EnemyFlash"):
		%EnemyFlash.visible = false
	if arena_center:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.42, 0.22, 0.42)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.55, 0.84, 0.55, 0.55)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		arena_center.add_theme_stylebox_override("panel", style)


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
	sprite.hframes = _get_unit_hframes(res)
	sprite.vframes = _get_unit_vframes(res)
	sprite.scale = _get_room_character_scale()
	sprite.offset.y = sprite_feet_offset
	_sync_flash_overlay(sprite, %PlayerFlash if sprite == player_sprite else %EnemyFlash)

func _sync_flash_overlay(sprite: Sprite2D, overlay: ColorRect):
	if not sprite or not overlay or not sprite.texture:
		return
	var frame_width = float(sprite.texture.get_width()) / float(max(1, sprite.hframes))
	var frame_height = float(sprite.texture.get_height()) / float(max(1, sprite.vframes))
	var width_padding = frame_width * 0.08
	var height_padding = frame_height * 0.08
	overlay.offset_left = -frame_width * 0.5 - width_padding
	overlay.offset_top = -frame_height * 0.5 - height_padding
	overlay.offset_right = frame_width * 0.5 + width_padding
	overlay.offset_bottom = frame_height * 0.5 + height_padding

func _get_unit_hframes(res: Resource) -> int:
	var h = int(res.get("hframes")) if res != null else 0
	return h if h > 0 else DEFAULT_UNIT_HFRAMES

func _get_unit_vframes(res: Resource) -> int:
	var v = int(res.get("vframes")) if res != null else 0
	return v if v > 0 else DEFAULT_UNIT_VFRAMES

func _get_unit_total_frames(res: Resource) -> int:
	var total = int(res.get("total_frames")) if res != null else 0
	return total if total > 0 else DEFAULT_UNIT_TOTAL_FRAMES

func _get_unit_frame_speed(res: Resource) -> float:
	var speed = float(res.get("frame_speed")) if res != null else 0.0
	return speed if speed > 0.0 else DEFAULT_UNIT_FRAME_SPEED

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

	if is_object_room:
		_setup_object_board()
		_sync_stat_icons()
		return

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

func _setup_object_board():
	var size = 4
	if current_object_res:
		size = max(2, int(current_object_res.object_size))
	grid.columns = size
	var total_slots = size * size
	var pair_count = int(floor(float(total_slots) / 2.0))
	var final_grid_keys: Array[String] = []
	for _i in range(pair_count):
		var reward_key = _pick_weighted_object_reward_key()
		final_grid_keys.append(reward_key)
		final_grid_keys.append(reward_key)
	if final_grid_keys.size() < total_slots:
		final_grid_keys.append(_pick_weighted_object_reward_key())
	final_grid_keys.shuffle()

	var card_dim = _get_card_dimension_for_grid(size)
	for reward_key in final_grid_keys:
		var card_node = card_scene.instantiate()
		grid.add_child(card_node)
		card_node.custom_minimum_size = Vector2(card_dim, card_dim)
		_setup_object_card_node(card_node, reward_key)
		card_node.card_flipped.connect(_on_card_flipped)
		card_node.pressed.connect(_on_card_pressed.bind(card_node))

func _setup_object_card_node(card_node: TextureButton, reward_key: String):
	card_node.set_meta("forced_back_texture_path", OBJECT_CARD_BACK_ICON_PATH)
	var reward = _parse_reward_key(reward_key)
	if reward.is_empty():
		card_node.card_type = reward_key
		return
	match str(reward.get("kind", "card")):
		"item":
			var item_data = _load_item_data(str(reward.get("id", "")))
			if item_data and card_node.has_method("setup_item"):
				card_node.setup_item(item_data)
		_:
			var card_data = _load_card_data(str(reward.get("id", "")))
			if card_data and card_node.has_method("setup"):
				card_node.setup(card_data)
	card_node.card_type = reward_key

func _pick_weighted_object_reward_key() -> String:
	var weighted_rewards = _build_object_weighted_rewards()
	if weighted_rewards.is_empty():
		return OBJECT_FALLBACK_REWARD_KEYS[0]
	var total_weight = 0.0
	for entry in weighted_rewards:
		total_weight += float(entry.get("weight", 0.0))
	if total_weight <= 0.0:
		return str(weighted_rewards[0].get("key", OBJECT_FALLBACK_REWARD_KEYS[0]))
	var roll = randf() * total_weight
	var running = 0.0
	for entry in weighted_rewards:
		running += float(entry.get("weight", 0.0))
		if roll <= running:
			return str(entry.get("key", OBJECT_FALLBACK_REWARD_KEYS[0]))
	return str(weighted_rewards[0].get("key", OBJECT_FALLBACK_REWARD_KEYS[0]))

func _build_object_weighted_rewards() -> Array[Dictionary]:
	var weighted_rewards: Array[Dictionary] = []
	if current_object_res == null:
		for fallback_key in OBJECT_FALLBACK_REWARD_KEYS:
			weighted_rewards.append({"key": fallback_key, "weight": 1.0})
		return weighted_rewards

	var object_items = current_object_res.object_items
	var probabilities = current_object_res.object_probability
	if object_items.is_empty():
		for fallback_key in OBJECT_FALLBACK_REWARD_KEYS:
			weighted_rewards.append({"key": fallback_key, "weight": 1.0})
		return weighted_rewards

	if probabilities.is_empty():
		for raw_item in object_items:
			var reward_key = _normalize_reward_key(str(raw_item))
			if reward_key != "":
				weighted_rewards.append({"key": reward_key, "weight": 1.0})
		return weighted_rewards

	var probability_sum = 0.0
	for i in range(object_items.size()):
		var reward_key = _normalize_reward_key(str(object_items[i]))
		if reward_key == "":
			continue
		var weight = 0.0
		if i < probabilities.size():
			weight = max(0.0, float(probabilities[i]))
		weighted_rewards.append({"key": reward_key, "weight": weight})
		probability_sum += weight

	var remaining_weight = max(0.0, 1.0 - probability_sum)
	if remaining_weight > 0.0:
		var fallback_weight = remaining_weight / float(max(1, OBJECT_FALLBACK_REWARD_KEYS.size()))
		for fallback_key in OBJECT_FALLBACK_REWARD_KEYS:
			weighted_rewards.append({"key": fallback_key, "weight": fallback_weight})

	if weighted_rewards.is_empty():
		for fallback_key in OBJECT_FALLBACK_REWARD_KEYS:
			weighted_rewards.append({"key": fallback_key, "weight": 1.0})
	return weighted_rewards

func _normalize_reward_key(raw_value: String) -> String:
	var value = raw_value.strip_edges()
	if value == "":
		return ""
	if value.contains(":"):
		var parts = value.split(":", false, 1)
		if parts.size() == 2:
			return "%s:%s" % [parts[0].to_lower(), parts[1].strip_edges()]
	var item_id = value
	if ResourceLoader.exists("res://data/items/%s.tres" % item_id):
		return "item:%s" % item_id
	if ResourceLoader.exists("res://data/cards/%s.tres" % item_id):
		return "card:%s" % item_id
	return ""

func _parse_reward_key(reward_key: String) -> Dictionary:
	var normalized = reward_key.strip_edges()
	if normalized == "":
		return {}
	if normalized.contains(":"):
		var parts = normalized.split(":", false, 1)
		if parts.size() == 2:
			return {"kind": parts[0].to_lower(), "id": parts[1].strip_edges()}
	return {"kind": "card", "id": normalized}

func _load_card_data(card_id: String) -> CardData:
	var res_path = "res://data/cards/%s.tres" % card_id
	if not ResourceLoader.exists(res_path):
		return null
	return load(res_path) as CardData

func _load_item_data(item_id: String) -> ItemData:
	var res_path = "res://data/items/%s.tres" % item_id
	if not ResourceLoader.exists(res_path):
		return null
	return load(res_path) as ItemData

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
	if background:
		background.stretch_mode = _get_background_stretch_mode(res)
		if res.background_texture:
			background.texture = res.background_texture
	
	# 2. Dynamic Floor Loading (Bottom 200px)
	if floor_rect:
		var floor_texture = _get_room_floor_texture(res)
		if floor_texture:
			floor_rect.texture = floor_texture
			floor_rect.stretch_mode = TextureRect.STRETCH_SCALE
			floor_rect.visible = true
			_fit_floor_to_container_width()
		else:
			floor_rect.visible = false

func _get_background_stretch_mode(res: RoomData) -> int:
	if not res:
		return TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return TextureRect.STRETCH_KEEP_ASPECT_COVERED

func _get_room_character_scale() -> Vector2:
	if current_room_res and current_room_res.character_scaling != Vector2.ZERO:
		return current_room_res.character_scaling
	return Vector2.ONE

func _get_room_floor_texture(res: RoomData) -> Texture2D:
	if not res:
		return null
	if res.floor:
		return res.floor
	var biome = str(res.biome).strip_edges()
	if biome == "":
		return null
	var fallback_path = "res://assets/rooms/floor/%s_floor.png" % biome
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path) as Texture2D
	return null

func _on_viewport_resized():
	_fit_floor_to_container_width()
	_update_character_placement()
	_refresh_log_view()
	_position_player_discard_ui()
	_position_enemy_intent_ui()

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
	_show_victory_overlay()

func _debug_lose():
	SceneTransition.change_scene_to_file("res://features/ui/RunSummary.tscn")

func _fade_to_black_and_change_scene(scene_path: String):
	await SceneTransition.change_scene_to_file(scene_path, 0.6)

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

func _fade_out_enemy_after_defeat():
	if is_object_room:
		return
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if enemy_sprite:
		tween.parallel().tween_property(enemy_sprite, "modulate:a", 0.0, 0.6)
	if enemy_hp_bar:
		tween.parallel().tween_property(enemy_hp_bar, "modulate:a", 0.0, 0.4)
	if enemy_hp_text:
		tween.parallel().tween_property(enemy_hp_text, "modulate:a", 0.0, 0.4)
	if enemy_column_ui:
		tween.parallel().tween_property(enemy_column_ui, "modulate:a", 0.0, 0.4)
	if enemy_stats_hud:
		tween.parallel().tween_property(enemy_stats_hud, "modulate:a", 0.0, 0.4)
	await tween.finished

func _show_victory_overlay():
	if victory_overlay != null and is_instance_valid(victory_overlay):
		victory_overlay.queue_free()
	if victory_overlay_layer == null or not is_instance_valid(victory_overlay_layer):
		victory_overlay_layer = CanvasLayer.new()
		victory_overlay_layer.layer = 120
		add_child(victory_overlay_layer)
	victory_overlay = victory_overlay_scene.instantiate()
	victory_overlay.overlay_mode = true
	victory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_overlay_layer.add_child(victory_overlay)
	victory_overlay.populate_rewards(
		GameManager.pending_loot,
		GameManager.last_xp_gained,
		_get_victory_gold_amount(),
		current_enemy_res.name if current_enemy_res else ""
	)
	victory_overlay.continue_requested.connect(_on_victory_overlay_continue)

func _setup_tutorial_overlay():
	if tutorial_overlay_layer and is_instance_valid(tutorial_overlay_layer):
		return
	tutorial_overlay_layer = CanvasLayer.new()
	tutorial_overlay_layer.layer = 140
	add_child(tutorial_overlay_layer)

	tutorial_overlay_root = Control.new()
	tutorial_overlay_root.visible = false
	tutorial_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay_layer.add_child(tutorial_overlay_root)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.03, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay_root.add_child(shade)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_overlay_root.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.1, 0.97)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.7, 1.0, 0.8)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	tutorial_message_label = Label.new()
	tutorial_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_message_label.add_theme_font_size_override("font_size", 30)
	tutorial_message_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	vbox.add_child(tutorial_message_label)

	tutorial_hint_label = Label.new()
	tutorial_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_hint_label.add_theme_font_size_override("font_size", 18)
	tutorial_hint_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 1.0))
	tutorial_hint_label.text = LocalizationManager.translate("tutorial.continue_any_input", "Click or press any key to continue")
	vbox.add_child(tutorial_hint_label)

func _maybe_show_room_tutorial():
	if not _are_tutorial_tips_enabled() or current_room_res == null:
		return
	var room_path = str(current_room_res.resource_path)
	var message_key = ""
	var tutorial_flag = ""
	if room_path == TUTORIAL_HUT_ROOM_PATH:
		message_key = "tutorial.room.hut_intro"
		tutorial_flag = "tutorial_room_hut_intro"
	elif room_path == TUTORIAL_WHARF_ROOM_PATH:
		message_key = "tutorial.room.wharf_intro"
		tutorial_flag = "tutorial_room_wharf_intro"
	if tutorial_flag == "" or _has_seen_tutorial(tutorial_flag):
		return
	_show_tutorial_overlay(tutorial_flag, LocalizationManager.translate(message_key, ""))

func _show_tutorial_overlay(next_tutorial_id: String, message: String):
	if tutorial_overlay_root == null or message.strip_edges() == "":
		return
	tutorial_id = next_tutorial_id
	tutorial_active = true
	tutorial_resume_can_flip = can_flip
	can_flip = false
	tutorial_message_label.text = message
	tutorial_hint_label.text = LocalizationManager.translate("tutorial.continue_any_input", "Click or press any key to continue")
	tutorial_overlay_root.visible = true

func _dismiss_tutorial_overlay():
	tutorial_active = false
	if tutorial_overlay_root:
		tutorial_overlay_root.visible = false
	if tutorial_id != "":
		_set_tutorial_seen(tutorial_id)
	tutorial_id = ""
	can_flip = tutorial_resume_can_flip

func _is_tutorial_dismiss_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and not event.is_echo()
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return abs(event.axis_value) >= 0.2
	return false

func _are_tutorial_tips_enabled() -> bool:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return true
	return bool(config.get_value(SETTINGS_SECTION, TUTORIAL_TIPS_KEY, true))

func _has_seen_tutorial(seen_tutorial_id: String) -> bool:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return bool(config.get_value(TUTORIAL_FLAGS_SECTION, seen_tutorial_id, false))

func _set_tutorial_seen(seen_tutorial_id: String):
	if seen_tutorial_id == "":
		return
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(TUTORIAL_FLAGS_SECTION, seen_tutorial_id, true)
	config.save(SETTINGS_PATH)

func _get_victory_gold_amount() -> int:
	var total = 0
	for entry in GameManager.pending_loot:
		if entry is Dictionary and str(entry.get("id", "")) == "gold":
			total += int(entry.get("amount", 0))
	return total

func _on_victory_overlay_continue():
	if victory_overlay != null and is_instance_valid(victory_overlay):
		victory_overlay.queue_free()
		victory_overlay = null
	if victory_overlay_layer != null and is_instance_valid(victory_overlay_layer):
		victory_overlay_layer.queue_free()
		victory_overlay_layer = null
	var current_scene_path = get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else ""
	if GameManager.show_level_up_scene_if_needed(current_scene_path):
		return
	if not GameManager.is_battle_mode and GameManager._is_boss_room(GameManager.current_node):
		var cleared_biome = str(GameManager.current_node.get("biome", ""))
		GameManager.mark_biome_cleared(cleared_biome)
		SaveManager.save_mid_run_state()
		SceneTransition.change_scene_to_file(
			GameManager.consume_pending_post_battle_scene(GameManager.get_story_line_scene_path())
		)
		return
	if enemy_sprite:
		enemy_sprite.visible = false
	if enemy_hp_bar:
		enemy_hp_bar.visible = false
	if enemy_hp_text:
		enemy_hp_text.visible = false
	if enemy_column_ui:
		enemy_column_ui.visible = false
	if enemy_stats_hud:
		enemy_stats_hud.visible = false
	_setup_cleared_room_view()

func _is_card_preview_visible() -> bool:
	return card_preview_root != null and card_preview_root.visible

func _show_card_preview_for_id(card_id: String, animate_in: bool = false, fly_to_discard: bool = false):
	await _show_reward_preview_for_key("card:%s" % card_id, animate_in, fly_to_discard)

func _show_reward_preview_for_key(reward_key: String, animate_in: bool = false, fly_to_discard: bool = false):
	if reward_key == "" or not full_card_scene:
		return
	var reward = _parse_reward_key(reward_key)
	if reward.is_empty():
		return
	var kind = str(reward.get("kind", "card"))
	var reward_id = str(reward.get("id", ""))
	if reward_id == "":
		return
	var item_data: ItemData = null
	var card_data: CardData = null
	if kind == "item":
		item_data = _load_item_data(reward_id)
		if item_data == null:
			return
	else:
		card_data = _load_card_data(reward_id)
		if card_data == null:
			return

	if active_preview_card and is_instance_valid(active_preview_card):
		active_preview_card.queue_free()
		active_preview_card = null

	var card_view = full_card_scene.instantiate()
	active_preview_card = card_view
	card_preview_holder.add_child(card_view)
	if is_object_room:
		card_view.set_meta("forced_back_texture_path", OBJECT_CARD_BACK_ICON_PATH)
	card_view.custom_minimum_size = Vector2(280, 420)
	card_view.scale = Vector2(1.0, 1.0)
	if kind == "item":
		if card_view.has_method("setup_item"):
			card_view.setup_item(item_data)
	else:
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
		await tween.finished
	if fly_to_discard and kind == "card":
		if card_view == null or not is_instance_valid(card_view):
			return
		if active_preview_card != card_view:
			return
		await _fly_preview_card_to_discard(card_view, card_data)

func _play_object_reward_focus_preview(reward_key: String):
	object_reward_preview_active = true
	object_reward_preview_dismiss_requested = false
	await _show_reward_preview_for_key(reward_key, true, false)
	var elapsed = 0.0
	while elapsed < 3.0 and not object_reward_preview_dismiss_requested and is_inside_tree():
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
	object_reward_preview_active = false
	object_reward_preview_dismiss_requested = false
	_hide_card_preview()

func _hide_card_preview():
	if not card_preview_root:
		return
	card_preview_root.visible = false
	object_reward_preview_active = false
	object_reward_preview_dismiss_requested = false
	if active_preview_card and is_instance_valid(active_preview_card):
		active_preview_card.queue_free()
	active_preview_card = null

func _fly_preview_card_to_discard(card_view, card_data: CardData):
	if card_view == null or not is_instance_valid(card_view):
		return
	if player_discard_root == null or not is_instance_valid(player_discard_root):
		_hide_card_preview()
		return
	await get_tree().create_timer(0.16).timeout
	if card_view == null or not is_instance_valid(card_view):
		return
	if active_preview_card != card_view:
		return
	if player_discard_root == null or not is_instance_valid(player_discard_root):
		_hide_card_preview()
		return
	card_view.top_level = true
	card_view.z_index = 320
	var preview_size = Vector2(280.0, 420.0)
	var start_pos = get_viewport_rect().size * 0.5 - (preview_size * 0.5)
	card_view.global_position = start_pos
	var target_rect = player_discard_root.get_global_rect()
	var target_scale = min(target_rect.size.x / preview_size.x, target_rect.size.y / preview_size.y)
	var target_pos = target_rect.get_center() - ((preview_size * target_scale) * 0.5)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card_view, "global_position", target_pos, 0.28)
	tween.parallel().tween_property(card_view, "scale", Vector2(target_scale, target_scale), 0.28)
	await tween.finished
	if card_view == null or not is_instance_valid(card_view):
		return
	_refresh_player_discard_preview(card_data)
	_hide_card_preview()
