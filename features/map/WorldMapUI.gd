extends Control

# res://features/map/WorldMapUI.gd
# Shared overworld UI for both battle mode and story mode, using the battle-map layout.

@onready var node_container = %NodeContainer
@onready var biome_label = %BiomeLabel
@onready var phase_label = %PhaseLabel
@onready var day_button = %DayButton
@onready var tracker_text = %TrackerText
@onready var scroll_area = %MapArea
@onready var avatar_button = %AvatarButton
@onready var story_button = %StoryButton
@onready var menu_icon_btn = %MenuIconBtn
@onready var map_content = $MapArea/MapContent
@onready var info_toast_box = %InfoToastBox
@onready var info_toast_label = %InfoToastLabel
@onready var background_texture = %BGTexture
@onready var day_info_panel = %DayInfoPanel
@onready var day_info_title = %DayInfoTitle
@onready var day_info_description = %DayInfoDescription
@onready var day_info_deities_heading = %DayInfoDeitiesHeading
@onready var day_info_deities = %DayInfoDeities
@onready var day_info_purpose_heading = %DayInfoPurposeHeading
@onready var day_info_purpose = %DayInfoPurpose
@onready var backtrack_dialog = %BacktrackDialog
@onready var backtrack_dialog_text = %BacktrackDialogText
@onready var backtrack_dialog_hint = %BacktrackDialogHint
@onready var top_bar = %TopBar
@onready var battle_log_row = %BattleLogRow
@onready var log_left_spacer = %LeftSpacer
@onready var log_box = %LogBox
@onready var log_display = %LogDisplay
@onready var log_right_spacer = %RightSpacer

var node_scene = preload("res://features/map/MapNode.tscn")
var in_game_menu_scene = preload("res://features/ui/InGameMenu.tscn")
var map_assets: MapAssetData = preload("res://data/map/map_data.tres")

var in_game_menu = null
var _info_toast_tween: Tween

var node_widgets_by_id: Dictionary = {}
var node_positions_by_id: Dictionary = {}
var adjacent_node_ids: Array[String] = []
var selected_node_id: String = ""
var visible_min_layer: int = 0
var visible_max_layer: int = 0
var visible_min_column: int = 0
var visible_max_column: int = 0

const BASE_NODE_SIZE = Vector2(180, 180)
const BASE_LAYER_SPACING = 135.0
const BASE_ROW_SPACING = 180.0
const BASE_TOP_PADDING = 120.0
const BACKTRACK_PROMPT = "You have a feeling you have been here before. An intense pain fills your mind as memory floods back"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "gameplay"
const TUTORIAL_TIPS_KEY := "tutorial_tips"
const RUN_LOG_KEY := "show_run_log"
const TUTORIAL_FLAGS_SECTION := "tutorial_flags"
const TUTORIAL_TOAST_DURATION := 10.0
const TUTORIAL_TOAST_COLOR := Color(0.4, 0.7, 1.0, 1.0)
const CULT_DAY_NAMES := [
	"Protodia",
	"Hoplidia",
	"Tridia",
	"Tetradia",
	"Pemptidia",
	"Hektidia",
	"Hebdomia",
	"Ogdoadia"
]

var current_node_scale: float = 1.0
var current_node_size: Vector2 = BASE_NODE_SIZE
var current_node_half_size: Vector2 = BASE_NODE_SIZE * 0.5
var current_layer_spacing: float = BASE_LAYER_SPACING
var current_row_spacing: float = BASE_ROW_SPACING
var current_left_padding: float = 120.0
var current_top_padding: float = BASE_TOP_PADDING
var _tutorial_active: bool = false
var _tutorial_id: String = ""
var _tutorial_target_mode: String = "node"
var is_log_expanded: bool = false
var log_collapsed_global_rect: Rect2 = Rect2()
var _backtrack_prompt_visible: bool = false

const LOG_COLLAPSED_HEIGHT = 32.0
const LOG_EXPANDED_LINE_COUNT = 10
const LOG_LINE_HEIGHT = 22.0
const LOG_EXPANDED_PADDING = 12.0
const LOG_ROW_SEPARATION = 0
const LOG_SIDE_SPACER_WIDTH = 0.0
const LOG_COLOR_GOOD = Color(0.62, 1.0, 0.62, 1.0)
const LOG_COLOR_BAD = Color(1.0, 0.58, 0.58, 1.0)
const LOG_COLOR_NEUTRAL = Color(0.86, 0.86, 0.86, 1.0)
func _ready():
	_setup_ui()
	_setup_battle_log_ui()
	if not SignalBus.run_log_updated.is_connected(_on_run_log_updated):
		SignalBus.run_log_updated.connect(_on_run_log_updated)

	if GameManager.run_map.is_empty():
		if GameManager.is_battle_mode:
			var battle_gen = preload("res://features/map/BattleMapGenerator.gd").new()
			GameManager.run_map = await battle_gen.generate_battle_map()
		else:
			var story_gen = preload("res://features/map/MapGenerator.gd").new()
			GameManager.run_map = await story_gen.generate_new_map()

	if GameManager.player_grid_pos == Vector2i(-99, -99):
		if GameManager.is_battle_mode:
			GameManager.player_grid_pos = Vector2i(0, 0)
		else:
			GameManager.reset_to_home()

	_sync_map_area_to_top_bar()
	_draw_map()

	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()

	var biome_track = AudioData.get_biome_track_id(_get_active_biome())
	if biome_track != "":
		SignalBus.music_change_requested.emit(biome_track, 1.5)
	_scroll_to_player()
	_begin_worldmap_tutorial_if_needed.call_deferred()

func _notification(what):
	if what == NOTIFICATION_RESIZED and is_inside_tree() and node_container and map_content and scroll_area and not GameManager.run_map.is_empty():
		_sync_map_area_to_top_bar()
		_draw_map()
		_refresh_log_view()

func _input(event):
	if get_viewport().is_input_handled():
		return

	if is_log_expanded and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _is_point_inside_log(event.position):
			is_log_expanded = false
			_refresh_log_view()
			get_viewport().set_input_as_handled()
			return

	if day_info_panel and day_info_panel.visible:
		var is_key_press = event is InputEventKey and event.pressed and not event.is_echo()
		var is_mouse_click = event is InputEventMouseButton and event.pressed
		if event.is_action_pressed("ui_cancel") or is_key_press or is_mouse_click:
			_hide_day_info_panel()
			get_viewport().set_input_as_handled()
		return

	if _backtrack_prompt_visible:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			_hide_backtrack_dialog()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if in_game_menu and in_game_menu.visible:
			if in_game_menu.has_method("handle_cancel"):
				in_game_menu.handle_cancel()
			else:
				in_game_menu.close()
		else:
			_toggle_in_game_menu()
		get_viewport().set_input_as_handled()
		return

	if event.is_echo():
		return
	if in_game_menu and in_game_menu.visible:
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_W:
		_open_story_map()
		return

	if event.is_action_pressed("ui_left"):
		_move_selection_by_direction(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		_move_selection_by_direction(Vector2i(1, 0))
	elif event.is_action_pressed("ui_up"):
		_move_selection_by_direction(Vector2i(0, -1))
	elif event.is_action_pressed("ui_down"):
		_move_selection_by_direction(Vector2i(0, 1))
	elif event.is_action_pressed("ui_accept"):
		_activate_selected_node()

func _setup_ui():
	scroll_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_area.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	if avatar_button:
		avatar_button.pressed.connect(_on_avatar_pressed)
	if story_button:
		story_button.pressed.connect(_open_story_map)
	if menu_icon_btn:
		menu_icon_btn.pressed.connect(_toggle_in_game_menu)
	if day_button:
		day_button.pressed.connect(_toggle_day_info_panel)

	_hide_info_toast()
	_hide_day_info_panel()
	_hide_backtrack_dialog()

func _sync_map_area_to_top_bar():
	if not scroll_area or not top_bar:
		return
	scroll_area.offset_top = top_bar.size.y

func _toggle_in_game_menu():
	if not in_game_menu:
		return
	if in_game_menu.visible:
		in_game_menu.close()
	else:
		in_game_menu.open()

func _draw_map():
	if not node_container or not map_content or not scroll_area:
		return
	for n in node_container.get_children():
		n.queue_free()
	node_widgets_by_id.clear()
	node_positions_by_id.clear()

	var current_biome = _get_active_biome()
	var current_id = _find_current_node_id()
	if current_id == "":
		current_id = _find_biome_entry_node_id(current_biome)
		if current_id != "":
			var first_data = _get_map_entry_by_id(current_id)
			_set_player_position_from_data(first_data)

	if current_id == "":
		return

	var current_data = _get_map_entry_by_id(current_id)
	if current_data.is_empty():
		return

	current_biome = str(current_data.get("biome", current_biome))
	_apply_biome_visuals(current_biome)
	_rebuild_adjacent_targets(current_id, current_biome)
	_update_header_labels(current_data)
	var revealed_set = _build_visible_node_set(current_id, current_biome)
	_recalculate_map_bounds(current_biome)
	_update_map_layout_scale()
	_update_map_content_bounds()

	var grid_tex = _get_biome_grid_texture(current_biome)

	for raw_id in GameManager.run_map.keys():
		var node_id = str(raw_id)
		var data = _get_map_entry_by_id(node_id)
		if data.is_empty():
			continue
		if str(data.get("biome", "")) != current_biome:
			continue

		var node_ui = node_scene.instantiate()
		node_container.add_child(node_ui)
		var node_pos = _get_node_position(int(data.get("layer", 0)), int(data.get("column", 0)))
		node_ui.position = node_pos
		node_ui.scale = Vector2.ONE * current_node_scale
		node_ui.z_index = int(data.get("layer", 0)) * 10 + int(data.get("column", 0))
		node_positions_by_id[node_id] = node_pos

		var is_player_here = node_id == current_id
		var is_selected = node_id == selected_node_id
		var is_revealed = revealed_set.has(node_id)
		var state = GameManager.world_state.rooms.get(node_id, {})
		var is_cleared = state.get("cleared", false)

		node_ui.setup_biome_node(data, grid_tex, is_cleared, is_player_here, is_revealed, adjacent_node_ids.has(node_id))
		if node_ui.has_method("set_highlight_state"):
			node_ui.set_highlight_state(is_player_here, is_selected)
		node_widgets_by_id[node_id] = node_ui
		node_ui.node_clicked.connect(_on_node_clicked)
		if node_ui.has_signal("node_double_clicked"):
			node_ui.node_double_clicked.connect(_on_node_double_clicked)

	_refresh_selection_highlight(current_id)
	if not GameManager.is_battle_mode:
		_begin_worldmap_tutorial_if_needed.call_deferred()

func _update_header_labels(current_data: Dictionary):
	var biome_key = str(current_data.get("biome", "town"))
	var biome_name = biome_key.replace("_", " ").capitalize()
	biome_label.text = biome_name

	if GameManager.is_battle_mode:
		var biome_index = int(current_data.get("biome_index", 0))
		var grid_size = biome_index + 2
		phase_label.text = LocalizationManager.format("worldmap.phase.grid", {"size": grid_size}, "{size}x{size} GRID")
	else:
		phase_label.text = LocalizationManager.translate("worldmap.phase.story", "STORY MAP")
	_refresh_day_ui()

	tracker_text.text = _get_room_display_name(current_data)

func _refresh_day_ui():
	if not day_button:
		return
	var day_number = _get_current_day_number()
	var day_index = _get_day_cycle_index(day_number)
	var day_name = _get_day_name(day_index)
	day_button.text = LocalizationManager.format(
		"worldmap.day.button",
		{"day": day_number, "name": day_name},
		"Day {day}. {name}"
	)
	if day_info_panel and day_info_panel.visible:
		_populate_day_info(day_number, day_index)

func _get_current_day_number() -> int:
	return max(1, int(GameManager.world_state.global.get("current_day", 1)))

func _get_day_cycle_index(day_number: int) -> int:
	return posmod(day_number - 1, CULT_DAY_NAMES.size()) + 1

func _get_day_name(day_index: int) -> String:
	return LocalizationManager.translate(
		"worldmap.day.%d.name" % day_index,
		CULT_DAY_NAMES[clamp(day_index - 1, 0, CULT_DAY_NAMES.size() - 1)]
	)

func _toggle_day_info_panel():
	if not day_info_panel:
		return
	if day_info_panel.visible:
		_hide_day_info_panel()
		return
	var day_number = _get_current_day_number()
	var day_index = _get_day_cycle_index(day_number)
	_populate_day_info(day_number, day_index)
	day_info_panel.visible = true

func _hide_day_info_panel():
	if day_info_panel:
		day_info_panel.visible = false

func _populate_day_info(day_number: int, day_index: int):
	if not day_info_panel:
		return
	var day_name = _get_day_name(day_index)
	if day_info_title:
		day_info_title.text = LocalizationManager.format(
			"worldmap.day.button",
			{"day": day_number, "name": day_name},
			"Day {day}. {name}"
		)
	if day_info_description:
		day_info_description.text = LocalizationManager.translate(
			"worldmap.day.%d.description" % day_index,
			""
		)
	if day_info_deities_heading:
		day_info_deities_heading.text = LocalizationManager.translate("worldmap.day.deities", "Deities")
	if day_info_deities:
		day_info_deities.text = LocalizationManager.translate(
			"worldmap.day.%d.deities" % day_index,
			""
		)
	if day_info_purpose_heading:
		day_info_purpose_heading.text = LocalizationManager.translate("worldmap.day.purpose", "Purpose")
	if day_info_purpose:
		day_info_purpose.text = LocalizationManager.translate(
			"worldmap.day.%d.purpose" % day_index,
			""
		)

func _get_room_display_name(node_data: Dictionary) -> String:
	if str(node_data.get("type", "")) == "background":
		return ""
	var room_path = str(node_data.get("room_resource_path", ""))
	if room_path != "" and ResourceLoader.exists(room_path):
		var room_res = load(room_path) as RoomData
		if room_res and room_res.room_name != "":
			return room_res.room_name
	var explicit_name = str(node_data.get("name", ""))
	if explicit_name != "":
		return explicit_name
	var node_type = str(node_data.get("type", "room"))
	return node_type.replace("_", " ").capitalize()

func _build_visible_node_set(current_id: String, biome: String) -> Dictionary:
	var visible_set: Dictionary = {}
	visible_set[current_id] = true

	for neighbor_id in _get_adjacent_node_ids(current_id, biome):
		visible_set[neighbor_id] = true

	if GameManager.is_battle_mode:
		return visible_set

	for raw_id in GameManager.run_map.keys():
		var node_id = str(raw_id)
		var data = _get_map_entry_by_id(node_id)
		if data.is_empty():
			continue
		if str(data.get("biome", "")) != biome:
			continue
		var state = GameManager.world_state.rooms.get(node_id, {})
		if state.get("completed", false):
			visible_set[node_id] = true

	return visible_set

func _recalculate_map_bounds(biome: String):
	var first = true
	for raw_id in GameManager.run_map.keys():
		var node_id = str(raw_id)
		var data = _get_map_entry_by_id(node_id)
		if data.is_empty():
			continue
		if str(data.get("biome", "")) != biome:
			continue
		var layer = int(data.get("layer", 0))
		var column = int(data.get("column", 0))
		if first:
			visible_min_layer = layer
			visible_max_layer = layer
			visible_min_column = column
			visible_max_column = column
			first = false
		else:
			visible_min_layer = min(visible_min_layer, layer)
			visible_max_layer = max(visible_max_layer, layer)
			visible_min_column = min(visible_min_column, column)
			visible_max_column = max(visible_max_column, column)

func _rebuild_adjacent_targets(current_id: String, biome: String):
	adjacent_node_ids = _get_accessible_adjacent_node_ids(current_id, biome)
	var selectable_node_ids = _get_selectable_node_ids(current_id)
	if selectable_node_ids.is_empty():
		selected_node_id = current_id
		return
	if selected_node_id == "" or not selectable_node_ids.has(selected_node_id):
		selected_node_id = current_id if selectable_node_ids.has(current_id) else selectable_node_ids[0]
	_update_selected_room_title()

func _refresh_selection_highlight(current_id: String):
	for id_key in node_widgets_by_id.keys():
		var node_ui = node_widgets_by_id[id_key]
		if not is_instance_valid(node_ui):
			continue
		if node_ui.has_method("set_highlight_state"):
			node_ui.set_highlight_state(id_key == current_id, id_key == selected_node_id)
	_update_selected_room_title()

func _move_selection_by_direction(dir: Vector2i):
	var current_id = _find_current_node_id()
	if current_id == "":
		return
	var selectable_node_ids = _get_selectable_node_ids(current_id)
	if selectable_node_ids.is_empty():
		return

	var origin_id = selected_node_id if selected_node_id != "" else current_id
	if not node_positions_by_id.has(origin_id):
		return
	var origin_center = node_positions_by_id[origin_id] + current_node_half_size
	var input_direction = Vector2(dir.x, dir.y).normalized()

	var best_id = ""
	var best_score = INF
	for candidate_id in selectable_node_ids:
		if not node_positions_by_id.has(candidate_id):
			continue
		var candidate_center = node_positions_by_id[candidate_id] + current_node_half_size
		var delta = candidate_center - origin_center
		if delta.length_squared() <= 0.001:
			continue
		var alignment = input_direction.dot(delta.normalized())
		if alignment <= 0.1:
			continue
		var score = delta.length() + (1.0 - alignment) * 240.0
		if score < best_score:
			best_score = score
			best_id = candidate_id

	if best_id == "":
		return
	selected_node_id = best_id
	_refresh_selection_highlight(current_id)

func _activate_selected_node():
	if selected_node_id == "":
		return
	var current_id = _find_current_node_id()
	if selected_node_id == current_id:
		var current_data = _get_map_entry_by_id(current_id)
		if not current_data.is_empty():
			_enter_room(current_data)
		return
	_attempt_travel(selected_node_id)

func _on_node_clicked(data: Dictionary):
	var node_id = str(data.get("id", ""))
	if node_id == "":
		return
	var current_id = _find_current_node_id()
	if node_id == selected_node_id:
		if node_id == current_id:
			_enter_room(data)
			return
		if adjacent_node_ids.has(node_id):
			_attempt_travel(node_id)
			return
		selected_node_id = node_id
		_refresh_selection_highlight(current_id)
		return
	if node_id == current_id:
		selected_node_id = node_id
		_refresh_selection_highlight(current_id)
		return
	if adjacent_node_ids.has(node_id):
		selected_node_id = node_id
		_refresh_selection_highlight(current_id)

func _on_node_double_clicked(data: Dictionary):
	var node_id = str(data.get("id", ""))
	if node_id == "":
		return
	var current_id = _find_current_node_id()
	if node_id == current_id:
		_enter_room(data)
		return
	if not adjacent_node_ids.has(node_id):
		return
	selected_node_id = node_id
	_attempt_travel(node_id)

func _attempt_travel(target_id: String):
	if not adjacent_node_ids.has(target_id):
		return
	var target_data = _get_map_entry_by_id(target_id)
	if target_data.is_empty():
		return

	if _is_backtrack(target_id) and not _is_home_node(target_data):
		await _travel_to_boss_node(target_data)
		return

	_travel_to_node(target_data)

func _travel_to_node(target_data: Dictionary):
	_set_player_position_from_data(target_data)
	GameManager.player_biome = str(target_data.get("biome", GameManager.player_biome))
	GameManager.set_selected_story_biome(GameManager.player_biome)
	_draw_map()
	_scroll_to_player()
	_enter_room(target_data)

func _show_backtrack_dialog():
	if not backtrack_dialog:
		return
	_backtrack_prompt_visible = true
	backtrack_dialog.visible = true
	if backtrack_dialog_text:
		backtrack_dialog_text.text = LocalizationManager.translate("worldmap.backtrack_prompt", BACKTRACK_PROMPT)
	if backtrack_dialog_hint:
		backtrack_dialog_hint.text = LocalizationManager.translate("dialog.click_continue", "Click to continue")

func _travel_to_boss_node(target_data: Dictionary):
	_show_backtrack_dialog()
	while _backtrack_prompt_visible and is_inside_tree():
		await get_tree().process_frame
	_set_player_position_from_data(target_data)
	GameManager.player_biome = str(target_data.get("biome", GameManager.player_biome))
	GameManager.set_selected_story_biome(GameManager.player_biome)
	_draw_map()
	_scroll_to_player()
	_enter_room(_build_boss_node(target_data))

func _hide_backtrack_dialog():
	_backtrack_prompt_visible = false
	if backtrack_dialog:
		backtrack_dialog.visible = false

func _hide_info_toast():
	if info_toast_box:
		info_toast_box.visible = false
		info_toast_box.modulate = Color(1, 1, 1, 0)
	if info_toast_label:
		info_toast_label.text = ""

func _show_info_toast(message: String, duration: float, font_color: Color):
	if _info_toast_tween:
		_info_toast_tween.kill()
	_hide_info_toast()
	if not info_toast_box or not info_toast_label:
		return
	info_toast_label.text = message
	info_toast_label.add_theme_color_override("font_color", font_color)
	info_toast_box.visible = true
	info_toast_box.modulate = Color(1, 1, 1, 0)
	_info_toast_tween = create_tween()
	_info_toast_tween.tween_property(info_toast_box, "modulate:a", 1.0, 0.12)
	_info_toast_tween.tween_interval(duration)
	_info_toast_tween.tween_property(info_toast_box, "modulate:a", 0.0, 0.4)
	_info_toast_tween.finished.connect(_hide_info_toast)

func _build_boss_node(base_data: Dictionary) -> Dictionary:
	var out = base_data.duplicate(true)
	var biome_key = str(base_data.get("biome", "town"))
	var source_biome = "town" if biome_key == "home" else biome_key
	var boss_path = "res://data/rooms/%s/%s_boss.tres" % [source_biome, source_biome]
	if not ResourceLoader.exists(boss_path):
		var default_path = "res://data/rooms/%s/%s_default.tres" % [source_biome, source_biome]
		boss_path = default_path if ResourceLoader.exists(default_path) else "res://data/rooms/default_battle.tres"

	var boss_res = DataManager.get_resource(boss_path)
	out["id"] = "%s_boss" % str(base_data.get("id", "node"))
	out["type"] = "boss"
	out["room_resource_path"] = boss_path
	out["name"] = boss_res.room_name if boss_res and boss_res is RoomData else "%s Boss" % source_biome.capitalize()
	out["initial_dialog"] = BACKTRACK_PROMPT
	if boss_res and boss_res is RoomData and boss_res.map_icon:
		out["custom_icon_path"] = boss_res.map_icon.resource_path
	return out

func _is_backtrack(target_id: String) -> bool:
	return GameManager.has_visited_node_this_run(target_id)

func _is_home_node(node_data: Dictionary) -> bool:
	return bool(node_data.get("is_home", false)) or str(node_data.get("type", "")) == "home"

func _enter_room(data: Dictionary):
	if not bool(data.get("passable", true)) or str(data.get("type", "")) == "background":
		return
	var previous_node_id = str(GameManager.current_node.get("id", ""))
	GameManager.current_node = data
	var signal_data = data.duplicate(true)
	if str(data.get("id", "")) == previous_node_id:
		signal_data["skip_visit_record"] = true
	SignalBus.node_selected.emit(signal_data)

	var room_path = str(data.get("room_resource_path", ""))
	var room_res: RoomData = null
	if room_path != "" and ResourceLoader.exists(room_path):
		room_res = load(room_path) as RoomData
	var room_type = str(data.get("type", "battle"))
	if room_res:
		room_type = str(room_res.type)
	var room_name = room_res.room_name if room_res and room_res.room_name != "" else _get_room_display_name(data)
	var node_id = str(data.get("id", ""))
	var is_object_room = room_res != null and room_res.enemy_id == "" and room_res.object_id != ""
	var is_object_room_cleared = is_object_room and GameManager.is_room_cleared(node_id)
	GameManager.add_run_log(
		LocalizationManager.format(
			"log.room.enter",
			{"room": room_name},
			"Entered {room}."
		)
	)

	match room_type:
		"battle", "boss":
			get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")
		"rest":
			get_tree().change_scene_to_file("res://features/encounters/RestScene.tscn")
		"shop":
			get_tree().change_scene_to_file("res://features/encounters/ShopScene.tscn")
		"event", "home", "lore", "npc":
			if is_object_room and not is_object_room_cleared:
				get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")
			else:
				get_tree().change_scene_to_file("res://features/encounters/EventScene.tscn")
		_:
			get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")

func _find_current_node_id() -> String:
	var active_biome = _get_active_biome()
	for raw_key in GameManager.run_map.keys():
		var data = GameManager.run_map[raw_key]
		if not GameManager.is_battle_mode and str(data.get("biome", "")) != active_biome:
			continue
		if int(data.get("layer", -999)) == _get_player_layer() and int(data.get("column", -999)) == _get_player_column():
			return str(raw_key)
	return ""

func _find_biome_entry_node_id(biome: String) -> String:
	var home_node_id = GameManager.get_biome_home_node_id(biome) if not GameManager.is_battle_mode else ""
	if home_node_id != "":
		var home_node = _get_map_entry_by_id(home_node_id)
		if not home_node.is_empty():
			return home_node_id

	var first_id = ""
	var first_layer = INF
	var first_col = INF
	for raw_key in GameManager.run_map.keys():
		var data = GameManager.run_map[raw_key]
		if str(data.get("biome", "")) != biome:
			continue
		var layer = int(data.get("layer", 0))
		var col = int(data.get("column", 0))
		if layer < first_layer or (layer == first_layer and col < first_col):
			first_layer = layer
			first_col = col
			first_id = str(raw_key)
	return first_id

func _resolve_map_key(raw_key) -> String:
	if GameManager.run_map.has(raw_key):
		return str(raw_key)
	var as_string = str(raw_key)
	if GameManager.run_map.has(as_string):
		return as_string
	return ""

func _get_map_entry_by_id(id_key: String) -> Dictionary:
	for raw_key in GameManager.run_map.keys():
		if str(raw_key) == id_key:
			return GameManager.run_map[raw_key]
	return {}

func _get_adjacent_node_ids(node_id: String, biome: String) -> Array[String]:
	var results: Array[String] = []
	var data = _get_map_entry_by_id(node_id)
	if data.is_empty():
		return results
	var source_coord = Vector2i(int(data.get("layer", 0)), int(data.get("column", 0)))

	for raw_target_id in data.get("connections", []):
		var target_id = _resolve_map_key(raw_target_id)
		if target_id == "":
			continue
		var target_data = _get_map_entry_by_id(target_id)
		if target_data.is_empty():
			continue
		if str(target_data.get("biome", "")) != biome:
			continue
		var target_coord = Vector2i(int(target_data.get("layer", 0)), int(target_data.get("column", 0)))
		if not _is_hex_adjacent(source_coord, target_coord):
			continue
		if not results.has(target_id):
			results.append(target_id)

	results.sort()
	return results

func _get_accessible_adjacent_node_ids(node_id: String, biome: String) -> Array[String]:
	var results: Array[String] = []
	for target_id in _get_adjacent_node_ids(node_id, biome):
		var target_data = _get_map_entry_by_id(target_id)
		if target_data.is_empty():
			continue
		if not bool(target_data.get("passable", true)):
			continue
		var target_type = str(target_data.get("type", "room"))
		if target_type == "" or target_type == "background":
			continue
		results.append(target_id)
	return results

func _update_map_content_bounds():
	if not map_content or not scroll_area:
		return
	var layer_count = max(1, visible_max_layer - visible_min_layer + 1)
	var column_count = max(1, visible_max_column - visible_min_column + 1)
	var content_width = float(max(0, column_count - 1)) * current_row_spacing + current_node_size.x + current_row_spacing * 0.5 + 48.0
	var content_height = float(max(0, layer_count - 1)) * current_layer_spacing + current_node_size.y + 48.0
	map_content.custom_minimum_size = Vector2(
		max(scroll_area.size.x, content_width),
		max(scroll_area.size.y, content_height)
	)
	if node_container:
		node_container.custom_minimum_size = map_content.custom_minimum_size

func _get_node_position(layer: int, column: int) -> Vector2:
	var relative_layer = layer - visible_min_layer
	var relative_column = column - visible_min_column
	var content_width = max(scroll_area.size.x, map_content.custom_minimum_size.x)
	var content_height = max(scroll_area.size.y, map_content.custom_minimum_size.y)
	var nodes_span_x = float(max(0, visible_max_column - visible_min_column)) * current_row_spacing + current_row_spacing * 0.5
	var nodes_span_y = float(max(0, visible_max_layer - visible_min_layer)) * current_layer_spacing
	var start_x = (content_width - nodes_span_x - current_node_size.x) * 0.5
	var start_y = (content_height - nodes_span_y - current_node_size.y) * 0.5
	var offset_x = current_row_spacing * 0.5 if posmod(relative_layer, 2) == 0 else 0.0
	return Vector2(
		relative_column * current_row_spacing + offset_x + start_x,
		relative_layer * current_layer_spacing + start_y
	)

func _get_selectable_node_ids(current_id: String) -> Array[String]:
	var results: Array[String] = []
	if current_id != "":
		results.append(current_id)
	for node_id in adjacent_node_ids:
		if not results.has(node_id):
			results.append(node_id)
	return results

func _update_selected_room_title():
	if not tracker_text:
		return
	var display_id = selected_node_id
	if display_id == "":
		display_id = _find_current_node_id()
	var display_data = _get_map_entry_by_id(display_id)
	if display_data.is_empty():
		tracker_text.text = ""
		return
	tracker_text.text = _get_room_display_name(display_data)

func _scroll_to_player():
	await get_tree().process_frame
	scroll_area.scroll_horizontal = 0
	scroll_area.scroll_vertical = 0

func _update_map_layout_scale():
	var layer_count = max(1, visible_max_layer - visible_min_layer + 1)
	var row_count = max(1, visible_max_column - visible_min_column + 1)
	var available_width = max(scroll_area.size.x, get_viewport_rect().size.x) - 96.0
	var available_height = max(scroll_area.size.y, get_viewport_rect().size.y) - 96.0
	var base_width = float(max(0, row_count - 1)) * BASE_ROW_SPACING + BASE_NODE_SIZE.x + BASE_ROW_SPACING * 0.5
	var base_height = float(max(0, layer_count - 1)) * BASE_LAYER_SPACING + BASE_NODE_SIZE.y
	var width_scale = available_width / max(base_width, 1.0)
	var height_scale = available_height / max(base_height, 1.0)
	current_node_scale = clamp(min(width_scale, height_scale, 1.0), 0.42, 1.0)
	current_node_size = BASE_NODE_SIZE * current_node_scale
	current_node_half_size = current_node_size * 0.5
	current_layer_spacing = BASE_LAYER_SPACING * current_node_scale
	current_row_spacing = BASE_ROW_SPACING * current_node_scale
	current_left_padding = 0.0
	current_top_padding = 0.0

func _is_hex_adjacent(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return false
	var deltas_even = [
		Vector2i(-1, -1),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(1, -1),
		Vector2i(1, 0)
	]
	var deltas_odd = [
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(1, 0),
		Vector2i(1, 1)
	]
	var deltas = deltas_even if posmod(a.x, 2) == 0 else deltas_odd
	var delta = b - a
	for allowed in deltas:
		if delta == allowed:
			return true
	return false

func _on_avatar_pressed():
	GameManager.profile_return_scene = "res://features/map/WorldMap.tscn"
	get_tree().change_scene_to_file("res://features/ui/CharacterScreen.tscn")

func _open_story_map():
	var current_id = _find_current_node_id()
	if current_id != "":
		var current_data = _get_map_entry_by_id(current_id)
		if not current_data.is_empty():
			var biome = str(current_data.get("biome", GameManager.selected_story_biome))
			GameManager.set_selected_story_biome(biome)
	SceneTransition.change_scene_to_file(GameManager.get_story_map_scene_path())

func _get_active_biome() -> String:
	if GameManager.is_battle_mode:
		var current_id = _find_current_node_id()
		if current_id != "":
			var current_data = _get_map_entry_by_id(current_id)
			if not current_data.is_empty():
				return str(current_data.get("biome", "home"))
		return "home"
	return GameManager.selected_story_biome if GameManager.selected_story_biome != "" else GameManager.player_biome

func _get_player_layer() -> int:
	return GameManager.player_grid_pos.x if GameManager.is_battle_mode else GameManager.player_grid_pos.y

func _get_player_column() -> int:
	return GameManager.player_grid_pos.y if GameManager.is_battle_mode else GameManager.player_grid_pos.x

func _set_player_position_from_data(node_data: Dictionary):
	if node_data.is_empty():
		return
	if GameManager.is_battle_mode:
		GameManager.player_grid_pos = Vector2i(int(node_data.get("layer", 0)), int(node_data.get("column", 0)))
	else:
		GameManager.player_grid_pos = Vector2i(int(node_data.get("column", 0)), int(node_data.get("layer", 0)))

func _apply_biome_visuals(biome: String):
	if not background_texture or not map_assets:
		return
	var normalized_biome = "town" if biome == "home" else biome
	var bg_prop = "map_%s_background" % normalized_biome
	if bg_prop in map_assets:
		background_texture.texture = map_assets.get(bg_prop)

func _get_biome_grid_texture(biome: String) -> Texture2D:
	if not map_assets:
		return null
	var normalized_biome = "town" if biome == "home" else biome
	var grid_prop = "map_%s_grid" % normalized_biome
	if grid_prop in map_assets:
		return map_assets.get(grid_prop)
	return null

func _begin_worldmap_tutorial_if_needed():
	if _tutorial_active or GameManager.is_battle_mode or not _are_tutorial_tips_enabled():
		return
	if _get_active_biome() == "home" and not _has_seen_tutorial("worldmap_home_intro"):
		if adjacent_node_ids.is_empty():
			return
		selected_node_id = adjacent_node_ids[0]
		_refresh_selection_highlight(_find_current_node_id())
		_show_tutorial_popup(
			"worldmap_home_intro",
			LocalizationManager.translate(
				"worldmap.tutorial.home",
				"You start in the safety in your home, a call draws you.\nSelect an adjacent map to to travel"
			),
			"node"
		)
		return
	if GameManager.world_state.cards.owned.size() > 0 and not _has_seen_tutorial("worldmap_first_card_character"):
		_show_tutorial_popup(
			"worldmap_first_card_character",
			LocalizationManager.translate(
				"worldmap.tutorial.first_card",
				"As you regain memory, you can strengthen your resolve here"
			),
			"avatar"
		)
		return
	if GameManager.world_state.items.owned.size() > 0 and not _has_seen_tutorial("worldmap_first_item_character"):
		_show_tutorial_popup(
			"worldmap_first_item_character",
			LocalizationManager.translate(
				"worldmap.tutorial.first_item",
				"As you gain items, you can better equip yourself for the adventure"
			),
			"avatar"
		)
		return
	if not GameManager.is_battle_mode and GameManager.current_run_visited_nodes.size() >= 3 and not _has_seen_tutorial("worldmap_explore_warning"):
		_show_tutorial_popup(
			"worldmap_explore_warning",
			LocalizationManager.translate(
				"worldmap.tutorial.explore",
				"Continue to discover the world. Be careful returning to a place you have already been"
			),
			"node"
		)

func _dismiss_tutorial_popup():
	if _tutorial_id != "":
		_set_tutorial_seen(_tutorial_id)
	_tutorial_active = false
	_tutorial_id = ""
	_tutorial_target_mode = "node"
	if _info_toast_tween:
		_info_toast_tween.kill()
	_hide_info_toast()
	if avatar_button:
		avatar_button.remove_theme_stylebox_override("normal")
		avatar_button.remove_theme_stylebox_override("hover")
		avatar_button.remove_theme_stylebox_override("pressed")
		avatar_button.remove_theme_stylebox_override("focus")

func _are_tutorial_tips_enabled() -> bool:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return true
	return bool(config.get_value(SETTINGS_SECTION, TUTORIAL_TIPS_KEY, true))

func _has_seen_tutorial(tutorial_id: String) -> bool:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return bool(config.get_value(TUTORIAL_FLAGS_SECTION, tutorial_id, false))

func _set_tutorial_seen(tutorial_id: String):
	if tutorial_id == "":
		return
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(TUTORIAL_FLAGS_SECTION, tutorial_id, true)
	config.save(SETTINGS_PATH)

func _show_tutorial_popup(tutorial_id: String, message: String, target_mode: String):
	_dismiss_tutorial_popup()
	_tutorial_id = tutorial_id
	_tutorial_target_mode = target_mode
	_tutorial_active = true
	if target_mode == "avatar" and avatar_button:
		var highlight_style = StyleBoxFlat.new()
		highlight_style.bg_color = Color(0.18, 0.42, 0.2, 0.78)
		highlight_style.border_width_left = 2
		highlight_style.border_width_top = 2
		highlight_style.border_width_right = 2
		highlight_style.border_width_bottom = 2
		highlight_style.border_color = Color(0.8, 0.95, 0.82, 1.0)
		highlight_style.corner_radius_top_left = 12
		highlight_style.corner_radius_top_right = 12
		highlight_style.corner_radius_bottom_left = 12
		highlight_style.corner_radius_bottom_right = 12
		avatar_button.add_theme_stylebox_override("normal", highlight_style)
		avatar_button.add_theme_stylebox_override("hover", highlight_style)
		avatar_button.add_theme_stylebox_override("pressed", highlight_style)
		avatar_button.add_theme_stylebox_override("focus", highlight_style)
		_show_info_toast(message, TUTORIAL_TOAST_DURATION, TUTORIAL_TOAST_COLOR)
	_set_tutorial_seen(tutorial_id)
	_tutorial_active = false
	_tutorial_id = ""
	_tutorial_target_mode = "node"
	if target_mode == "avatar" and avatar_button:
		var clear_tween = create_tween()
		clear_tween.tween_interval(TUTORIAL_TOAST_DURATION)
		clear_tween.finished.connect(func():
			if avatar_button:
				avatar_button.remove_theme_stylebox_override("normal")
				avatar_button.remove_theme_stylebox_override("hover")
				avatar_button.remove_theme_stylebox_override("pressed")
				avatar_button.remove_theme_stylebox_override("focus")
		)

func _on_run_log_updated():
	_apply_log_visibility()
	_rebuild_log_entries()

func _get_log_entry_color(text: String) -> Color:
	var lower = text.to_lower()
	if "victory" in lower or "leveled up" in lower:
		return LOG_COLOR_GOOD
	if "trap" in lower or "receive" in lower or "damage" in lower:
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
	_apply_log_visibility()
	_rebuild_log_entries()
	_refresh_log_view()

func _rebuild_log_entries():
	if not log_box:
		return
	for child in log_box.get_children():
		child.queue_free()
	for entry in GameManager.get_run_log():
		var lbl = Label.new()
		lbl.text = "> " + entry
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
		log_display.global_position = Vector2(0.0, viewport_size.y - expanded_height)
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
