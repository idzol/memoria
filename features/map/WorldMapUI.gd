extends Control

# res://features/map/WorldMapUI.gd
# Shared overworld UI for both battle mode and story mode, using the battle-map layout.

@onready var node_container = %NodeContainer
@onready var biome_label = %BiomeLabel
@onready var phase_label = %PhaseLabel
@onready var day_button = %DayButton
@onready var tracker_text = %TrackerText
@onready var scroll_area = %MapArea
@onready var lines_container = %LinesContainer
@onready var avatar_button = %AvatarButton
@onready var story_button = %StoryButton
@onready var menu_icon_btn = %MenuIconBtn
@onready var zoom_out_button = %ZoomOutButton
@onready var zoom_in_button = %ZoomInButton
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
@onready var backtrack_dialog_speaker = %BacktrackDialogSpeaker
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
var worldmap_tile_background_settings = preload("res://features/map/WorldMapTileBackgroundSettings.gd")

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

const BASE_NODE_SIZE = Vector2(160, 160)
const BASE_TOP_PADDING = 120.0
const BACKTRACK_PROMPT = "You have a feeling you have been here before. An intense pain fills your mind as memory floods back"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "gameplay"
const TUTORIAL_TIPS_KEY := "tutorial_tips"
const RUN_LOG_KEY := "show_run_log"
const TUTORIAL_FLAGS_SECTION := "tutorial_flags"
const TUTORIAL_TOAST_DURATION := 10.0
const TUTORIAL_TOAST_COLOR := Color(0.4, 0.7, 1.0, 1.0)
const DIRECT_LAUNCH_BIOMES := ["home", "town", "forest", "ice_caves", "desert", "swamp", "abyss", "void", "the_core"]
const MIN_MAP_ZOOM := 0.6
const MAX_MAP_ZOOM := 2.2
const MAP_ZOOM_STEP := 0.2
const MAP_DRAG_DEADZONE := 4.0
const MIN_HEX_HORIZONTAL_PADDING := 60.0
const MIN_HEX_VERTICAL_PADDING := 0
const MAP_BOTTOM_SAFE_PADDING := 140.0
const FOG_OF_WAR_ICON_PATH := "res://assets/rooms/map/all_fog_of_war.png"
const CURRENT_CONNECTION_COLOR := Color(0.84, 0.9, 1.0, 0.95)
const CURRENT_CONNECTION_WIDTH := 10.0
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
var current_fit_scale: float = 1.0
var current_zoom_factor: float = 1.0
var current_node_size: Vector2 = BASE_NODE_SIZE
var current_node_half_size: Vector2 = BASE_NODE_SIZE * 0.5
var current_layer_spacing: float = BASE_NODE_SIZE.y
var current_row_spacing: float = BASE_NODE_SIZE.x
var current_horizontal_padding: float = 64.0
var current_vertical_padding: float = 30.0
var current_left_padding: float = 120.0
var current_top_padding: float = BASE_TOP_PADDING
@export_range(0.0, 128.0, 1.0) var map_container_padding_px: float = 48.0
@export_range(0.0, 128.0, 1.0) var map_background_side_margin_px: float = 400.0
@export_range(0.0, 96.0, 1.0) var tile_horizontal_padding_px: float = 0
@export_range(0.0, 96.0, 1.0) var tile_vertical_padding_px: float = 18.0
var _tutorial_active: bool = false
var _tutorial_id: String = ""
var _tutorial_target_mode: String = "node"
var _tutorial_overlay: Control = null
var _tutorial_message_label: Label = null
var _tutorial_hint_label: Label = null
var is_log_expanded: bool = false
var log_collapsed_global_rect: Rect2 = Rect2()
var _backtrack_prompt_visible: bool = false
var _pending_backtrack_target: Dictionary = {}
var _direct_launch_picker_overlay: Control = null
var _user_zoom_scale: float = MAX_MAP_ZOOM
var _zoom_anchor_ratio: Vector2 = Vector2(0.5, 0.5)
var _zoom_anchor_viewport_size: Vector2 = Vector2.ZERO
var _is_drag_panning: bool = false
var _drag_candidate_active: bool = false
var _drag_button_index: int = -1
var _drag_pan_origin: Vector2 = Vector2.ZERO
var _drag_pan_scroll_origin: Vector2 = Vector2.ZERO
var _suppress_click_after_drag: bool = false
var _raw_content_size: Vector2 = Vector2.ZERO
var _map_anchor_ratio: Vector2 = Vector2(0.5, 0.5)

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
	_ensure_tutorial_overlay()
	_ensure_direct_launch_picker_overlay()
	_setup_ui()
	_setup_battle_log_ui()
	if not SignalBus.run_log_updated.is_connected(_on_run_log_updated):
		SignalBus.run_log_updated.connect(_on_run_log_updated)

	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()

	if _should_show_direct_launch_biome_picker():
		await _ensure_run_map_ready()
		_show_direct_launch_biome_picker()
		return

	await _finalize_map_ready_state()

func _notification(what):
	if what == NOTIFICATION_RESIZED and is_inside_tree() and node_container and map_content and scroll_area and not GameManager.run_map.is_empty():
		_sync_map_area_to_top_bar()
		_apply_background_zoom()
		_draw_map()
		_refresh_log_view()

func _input(event):
	if get_viewport().is_input_handled():
		return

	if _direct_launch_picker_overlay and _direct_launch_picker_overlay.visible:
		return

	if _handle_map_zoom_input(event):
		get_viewport().set_input_as_handled()
		return

	if _handle_map_drag_input(event):
		if _is_drag_panning:
			get_viewport().set_input_as_handled()
		return

	if _tutorial_active:
		if _is_tutorial_dismiss_input(event):
			_dismiss_tutorial_popup()
			get_viewport().set_input_as_handled()
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
		if _is_backtrack_progress_input(event):
			_confirm_backtrack_travel()
			var viewport := get_viewport()
			if viewport:
				viewport.set_input_as_handled()
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
	if background_texture:
		background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_texture.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background_texture.stretch_mode = TextureRect.STRETCH_TILE

	if avatar_button:
		avatar_button.pressed.connect(_on_avatar_pressed)
	if story_button:
		story_button.pressed.connect(_open_story_map)
	if menu_icon_btn:
		menu_icon_btn.pressed.connect(_toggle_in_game_menu)
	if zoom_out_button:
		zoom_out_button.pressed.connect(_zoom_out)
	if zoom_in_button:
		zoom_in_button.pressed.connect(_zoom_in)
	if day_button:
		day_button.pressed.connect(_toggle_day_info_panel)
	if scroll_area:
		var h_scroll_bar = scroll_area.get_h_scroll_bar()
		if h_scroll_bar and not h_scroll_bar.value_changed.is_connected(_on_map_scroll_changed):
			h_scroll_bar.value_changed.connect(_on_map_scroll_changed)
		var v_scroll_bar = scroll_area.get_v_scroll_bar()
		if v_scroll_bar and not v_scroll_bar.value_changed.is_connected(_on_map_scroll_changed):
			v_scroll_bar.value_changed.connect(_on_map_scroll_changed)

	_hide_info_toast()
	_hide_day_info_panel()
	_hide_backtrack_dialog()
	_configure_overlay_layers()
	_apply_background_zoom()

func _configure_overlay_layers():
	if info_toast_box:
		info_toast_box.z_index = 400
	if day_info_panel:
		day_info_panel.z_index = 410
	if battle_log_row:
		battle_log_row.z_index = 420
	if backtrack_dialog:
		backtrack_dialog.z_index = 500
		backtrack_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	if _tutorial_overlay:
		_tutorial_overlay.z_index = 600
		_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if _direct_launch_picker_overlay:
		_direct_launch_picker_overlay.z_index = 650
		_direct_launch_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

func _ensure_tutorial_overlay():
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		return
	_tutorial_overlay = Control.new()
	_tutorial_overlay.name = "TutorialOverlay"
	_tutorial_overlay.visible = false
	_tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_tutorial_overlay)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.03, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_overlay.add_child(shade)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.1, 0.96)
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

	_tutorial_message_label = Label.new()
	_tutorial_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_message_label.add_theme_font_size_override("font_size", 28)
	_tutorial_message_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	vbox.add_child(_tutorial_message_label)

	_tutorial_hint_label = Label.new()
	_tutorial_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_hint_label.add_theme_font_size_override("font_size", 18)
	_tutorial_hint_label.add_theme_color_override("font_color", TUTORIAL_TOAST_COLOR)
	_tutorial_hint_label.text = LocalizationManager.translate("tutorial.continue_any_input", "Click or press any key to continue")
	vbox.add_child(_tutorial_hint_label)

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
	for l in lines_container.get_children():
		l.queue_free()
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

		var is_player_here = node_id == current_id
		var is_selected = node_id == selected_node_id
		var is_revealed = revealed_set.has(node_id)
		if not is_revealed:
			continue
		var state = GameManager.world_state.rooms.get(node_id, {})
		var is_cleared = state.get("cleared", false)
		var visual_data = _apply_worldmap_tile_background_settings(data)
		visual_data = _apply_story_room_visibility_art(visual_data, state, is_player_here)

		var node_ui = node_scene.instantiate()
		node_container.add_child(node_ui)
		var node_pos = _get_node_position(int(data.get("layer", 0)), int(data.get("column", 0)))
		node_ui.size = current_node_size
		node_ui.custom_minimum_size = current_node_size
		node_ui.position = node_pos
		node_ui.scale = Vector2.ONE
		node_ui.z_index = int(data.get("layer", 0)) * 10 + int(data.get("column", 0))
		node_positions_by_id[node_id] = node_pos

		node_ui.setup_biome_node(visual_data, grid_tex, is_cleared, is_player_here, is_revealed, adjacent_node_ids.has(node_id))
		if node_ui.has_method("set_highlight_state"):
			node_ui.set_highlight_state(is_player_here, is_selected)
		node_widgets_by_id[node_id] = node_ui
		node_ui.node_clicked.connect(_on_node_clicked)
		if node_ui.has_signal("node_double_clicked"):
			node_ui.node_double_clicked.connect(_on_node_double_clicked)

	_draw_current_adjacency_lines(current_id, revealed_set)
	_refresh_selection_highlight(current_id)
	if not GameManager.is_battle_mode:
		_begin_worldmap_tutorial_if_needed.call_deferred()

func _ensure_run_map_ready():
	if not GameManager.run_map.is_empty():
		return
	if GameManager.is_battle_mode:
		var battle_gen = preload("res://features/map/BattleMapGenerator.gd").new()
		GameManager.run_map = await battle_gen.generate_battle_map()
	else:
		var story_gen = preload("res://features/map/MapGenerator.gd").new()
		GameManager.run_map = await story_gen.generate_new_map()

func _finalize_map_ready_state():
	await _ensure_run_map_ready()
	if GameManager.player_grid_pos == Vector2i(-99, -99):
		if GameManager.is_battle_mode:
			GameManager.player_grid_pos = Vector2i(0, 0)
		else:
			GameManager.reset_to_home()
	_ensure_story_player_starts_at_biome_home()
	_sync_map_area_to_top_bar()
	_draw_map()
	var biome_track = AudioData.get_biome_track_id(_get_active_biome())
	if biome_track != "":
		SignalBus.music_change_requested.emit(biome_track, 1.5)
	_scroll_to_player()
	_begin_worldmap_tutorial_if_needed.call_deferred()

func _ensure_story_player_starts_at_biome_home():
	if GameManager.is_battle_mode or GameManager.run_map.is_empty():
		return
	var active_biome = _get_active_biome()
	if active_biome == "":
		return
	var current_id = _find_current_node_id()
	if current_id != "":
		var current_data = _get_map_entry_by_id(current_id)
		if not current_data.is_empty() and str(current_data.get("biome", "")) == active_biome:
			return
	var home_node = GameManager.get_story_biome_home_node(active_biome)
	if home_node.is_empty():
		var home_node_id = _find_biome_entry_node_id(active_biome)
		home_node = _get_map_entry_by_id(home_node_id)
	if home_node.is_empty():
		return
	_set_player_position_from_data(home_node)
	GameManager.player_biome = active_biome
	GameManager.set_selected_story_biome(active_biome)
	GameManager.current_node = home_node.duplicate(true)

func _apply_worldmap_tile_background_settings(data: Dictionary) -> Dictionary:
	var visual_data = data.duplicate(true)
	var icon_path = str(visual_data.get("custom_icon_path", ""))
	if icon_path == "":
		return visual_data
	var room_path = str(visual_data.get("room_resource_path", ""))
	var scale = worldmap_tile_background_settings.get_scale_for_room(room_path, icon_path)
	var offset = worldmap_tile_background_settings.get_offset_for_room(room_path, icon_path)
	visual_data["icon_scale_x"] = scale.x
	visual_data["icon_scale_y"] = scale.y
	visual_data["icon_offset_x"] = offset.x
	visual_data["icon_offset_y"] = offset.y
	return visual_data

func _should_show_direct_launch_biome_picker() -> bool:
	return (
		OS.is_debug_build()
		and not GameManager.is_battle_mode
		and GameManager.run_map.is_empty()
		and GameManager.current_node.is_empty()
	)

func _ensure_direct_launch_picker_overlay():
	if _direct_launch_picker_overlay and is_instance_valid(_direct_launch_picker_overlay):
		return
	_direct_launch_picker_overlay = Control.new()
	_direct_launch_picker_overlay.name = "DirectLaunchBiomePicker"
	_direct_launch_picker_overlay.visible = false
	_direct_launch_picker_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_direct_launch_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_direct_launch_picker_overlay)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.03, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_direct_launch_picker_overlay.add_child(shade)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_direct_launch_picker_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.7, 1.0, 0.8)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Select Test Biome"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var body = Label.new()
	body.text = "WorldMap was launched directly. Choose a biome to simulate."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	for biome in DIRECT_LAUNCH_BIOMES:
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.text = biome.replace("_", " ").capitalize()
		button.pressed.connect(_on_direct_launch_biome_selected.bind(biome))
		vbox.add_child(button)

func _show_direct_launch_biome_picker():
	if _direct_launch_picker_overlay:
		_direct_launch_picker_overlay.visible = true
		_direct_launch_picker_overlay.move_to_front()

func _on_direct_launch_biome_selected(biome: String):
	if _direct_launch_picker_overlay:
		_direct_launch_picker_overlay.visible = false
	GameManager.unlock_biome(biome)
	if GameManager.get_nodes_for_biome(biome).is_empty() and GameManager.has_method("_ensure_story_biomes_generated"):
		GameManager._ensure_story_biomes_generated([biome])
	GameManager.enter_story_biome(biome, true)
	await _finalize_map_ready_state()

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

	tracker_text.text = _get_tracker_room_display_name(current_data)

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

func _get_tracker_room_display_name(node_data: Dictionary) -> String:
	if node_data.is_empty():
		return ""
	if not GameManager.is_battle_mode and _is_story_room_in_fog_of_war(node_data):
		return LocalizationManager.translate("worldmap.room.unknown", "Unknown")
	return _get_room_display_name(node_data)

func _is_story_room_in_fog_of_war(node_data: Dictionary) -> bool:
	if GameManager.is_battle_mode:
		return false
	if node_data.is_empty():
		return false
	if not bool(node_data.get("passable", true)) or str(node_data.get("type", "")) == "background":
		return false
	var node_id = str(node_data.get("id", ""))
	var current_id = _find_current_node_id()
	if node_id != "" and node_id == current_id:
		return false
	var state: Dictionary = GameManager.world_state.rooms.get(node_id, {})
	return not _is_story_room_visible_as_completed(node_data, state)

func _build_visible_node_set(current_id: String, biome: String) -> Dictionary:
	var visible_set: Dictionary = {}
	if GameManager.is_battle_mode:
		visible_set[current_id] = true
		for neighbor_id in _get_adjacent_node_ids(current_id, biome):
			visible_set[neighbor_id] = true
		return visible_set

	visible_set[current_id] = true
	for neighbor_id in _get_adjacent_node_ids(current_id, biome):
		visible_set[neighbor_id] = true

	var completed_ids: Array[String] = []
	for raw_id in GameManager.run_map.keys():
		var node_id = str(raw_id)
		var data = _get_map_entry_by_id(node_id)
		if data.is_empty():
			continue
		if str(data.get("biome", "")) != biome:
			continue
		var state = GameManager.world_state.rooms.get(node_id, {})
		if _is_story_room_visible_as_completed(data, state):
			visible_set[node_id] = true
			completed_ids.append(node_id)

	for completed_id in completed_ids:
		for neighbor_id in _get_adjacent_node_ids(completed_id, biome):
			visible_set[neighbor_id] = true

	return visible_set

func _apply_story_room_visibility_art(data: Dictionary, state: Dictionary, is_player_here: bool) -> Dictionary:
	if GameManager.is_battle_mode:
		return data
	var visual_data = data.duplicate(true)
	var node_type = str(visual_data.get("type", ""))
	var is_passable = bool(visual_data.get("passable", true))
	if not is_passable or node_type == "background":
		return visual_data
	var is_completed = _is_story_room_visible_as_completed(visual_data, state)
	if is_player_here or is_completed:
		return visual_data
	if node_type == "boss":
		visual_data["visual_impassable"] = true
		return visual_data
	if ResourceLoader.exists(FOG_OF_WAR_ICON_PATH):
		visual_data["custom_icon_path"] = FOG_OF_WAR_ICON_PATH
		visual_data["force_custom_icon"] = true
		visual_data["icon_scale_x"] = 1.0
		visual_data["icon_scale_y"] = 1.0
		visual_data["icon_offset_x"] = 0.0
		visual_data["icon_offset_y"] = 0.0
		visual_data["icon_alpha"] = 1.0
	return visual_data

func _is_story_room_visible_as_completed(node_data: Dictionary, state: Dictionary) -> bool:
	if bool(node_data.get("is_home", false)) or str(node_data.get("type", "")) == "home":
		return true
	return bool(state.get("completed", false))

func _draw_current_adjacency_lines(current_id: String, revealed_set: Dictionary):
	if not lines_container or current_id == "" or not node_positions_by_id.has(current_id):
		return
	var current_center = _get_rendered_node_center(current_id)
	for target_id in adjacent_node_ids:
		if not revealed_set.has(target_id):
			continue
		if not node_positions_by_id.has(target_id):
			continue
		var target_center = _get_rendered_node_center(target_id)
		var segment = Line2D.new()
		segment.width = CURRENT_CONNECTION_WIDTH
		segment.default_color = CURRENT_CONNECTION_COLOR
		segment.begin_cap_mode = Line2D.LINE_CAP_ROUND
		segment.end_cap_mode = Line2D.LINE_CAP_ROUND
		segment.add_point(current_center)
		segment.add_point(target_center)
		lines_container.add_child(segment)

func _get_rendered_node_center(node_id: String) -> Vector2:
	if node_widgets_by_id.has(node_id):
		var node_widget = node_widgets_by_id[node_id]
		if node_widget is Control:
			var widget := node_widget as Control
			return (widget.position + (widget.size * 0.5)) * current_node_scale
	return (node_positions_by_id.get(node_id, Vector2.ZERO) + current_node_half_size) * current_node_scale

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
	if _suppress_click_after_drag:
		_suppress_click_after_drag = false
		return
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
	if _suppress_click_after_drag:
		_suppress_click_after_drag = false
		return
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

	if _is_backtrack(target_id):
		await _travel_to_boss_node(target_data)
		return

	_travel_to_node(target_data)

func _travel_to_node(target_data: Dictionary):
	_set_player_position_from_data(target_data)
	GameManager.player_biome = str(target_data.get("biome", GameManager.player_biome))
	GameManager.set_selected_story_biome(GameManager.player_biome)
	_draw_map()
	_scroll_to_player()
	var node_id := str(target_data.get("id", ""))
	var room_state: Dictionary = GameManager.world_state.rooms.get(node_id, {})
	if bool(room_state.get("completed", false)):
		selected_node_id = node_id
		_refresh_selection_highlight(node_id)
		return
	_enter_room(target_data)

func _show_backtrack_dialog():
	if not backtrack_dialog:
		return
	_backtrack_prompt_visible = true
	backtrack_dialog.move_to_front()
	backtrack_dialog.visible = true
	if backtrack_dialog_speaker:
		backtrack_dialog_speaker.text = LocalizationManager.translate("dialog.speaker.narrator", "Narrator")
		backtrack_dialog_speaker.add_theme_color_override("font_color", LOG_COLOR_BAD)
	if backtrack_dialog_text:
		backtrack_dialog_text.text = LocalizationManager.translate("worldmap.backtrack_prompt", BACKTRACK_PROMPT)
		backtrack_dialog_text.add_theme_color_override("font_color", LOG_COLOR_BAD)
	if backtrack_dialog_hint:
		backtrack_dialog_hint.text = LocalizationManager.translate("tutorial.continue_any_input", "Click or press any key to continue")

func _travel_to_boss_node(target_data: Dictionary):
	_pending_backtrack_target = target_data.duplicate(true)
	_show_backtrack_dialog()
 
func _confirm_backtrack_travel():
	if _pending_backtrack_target.is_empty():
		_hide_backtrack_dialog()
		return
	var target_data = _pending_backtrack_target.duplicate(true)
	_hide_backtrack_dialog()
	_set_player_position_from_data(target_data)
	GameManager.player_biome = str(target_data.get("biome", GameManager.player_biome))
	GameManager.set_selected_story_biome(GameManager.player_biome)
	_draw_map()
	_scroll_to_player()
	_enter_room(_build_boss_node(target_data))

func _hide_backtrack_dialog():
	_backtrack_prompt_visible = false
	_pending_backtrack_target = {}
	if backtrack_dialog:
		backtrack_dialog.visible = false

func _is_backtrack_progress_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.is_echo()
	if event is InputEventMouseButton:
		return event.pressed
	return false

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
	if target_id == "":
		return false
	var target_data = _get_map_entry_by_id(target_id)
	if target_data.is_empty():
		return false
	if _is_home_node(target_data):
		return false
	if str(target_data.get("type", "")) == "boss":
		return false
	var room_state = GameManager.world_state.rooms.get(target_id, {})
	if bool(room_state.get("completed", false)):
		return false
	return GameManager.get_room_visit_count_this_run(target_id) >= 1

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
	var min_row_offset = _get_row_offset_for_layer(visible_min_layer)
	var max_row_offset = min_row_offset
	for layer in range(visible_min_layer, visible_max_layer + 1):
		var row_offset = _get_row_offset_for_layer(layer)
		min_row_offset = min(min_row_offset, row_offset)
		max_row_offset = max(max_row_offset, row_offset)
	var content_width = float(max(0, column_count - 1)) * current_row_spacing + current_node_size.x + (max_row_offset - min_row_offset) + (map_container_padding_px * 2.0)
	var content_height = float(max(0, layer_count - 1)) * current_layer_spacing + current_node_size.y + map_container_padding_px + max(map_container_padding_px, MAP_BOTTOM_SAFE_PADDING)
	_raw_content_size = Vector2(content_width, content_height)
	var scaled_content_size = Vector2(
		max(scroll_area.size.x, content_width * current_node_scale),
		max(scroll_area.size.y, content_height * current_node_scale)
	)
	map_content.custom_minimum_size = scaled_content_size
	if node_container:
		node_container.custom_minimum_size = _raw_content_size
		node_container.size = _raw_content_size
		node_container.position = Vector2.ZERO
		node_container.pivot_offset = Vector2.ZERO
		node_container.scale = Vector2.ONE * current_node_scale
	if lines_container:
		lines_container.position = Vector2.ZERO
		lines_container.scale = Vector2.ONE
	_apply_background_zoom()

func _get_node_position(layer: int, column: int) -> Vector2:
	var content_width = max(0.0, _raw_content_size.x - (map_container_padding_px * 2.0))
	var content_height = max(0.0, _raw_content_size.y - (map_container_padding_px * 2.0))
	var center_layer = (float(visible_min_layer) + float(visible_max_layer)) * 0.5
	var center_column = (float(visible_min_column) + float(visible_max_column)) * 0.5
	var center_layer_offset = _get_row_offset_for_layer(int(round(center_layer)))
	var offset_x = _get_row_offset_for_layer(layer) - center_layer_offset
	return Vector2(
		map_container_padding_px + content_width * 0.5 - current_node_half_size.x + (float(column) - center_column) * current_row_spacing + offset_x,
		map_container_padding_px + content_height * 0.5 - current_node_half_size.y + (float(layer) - center_layer) * current_layer_spacing
	)

func _get_row_offset_for_layer(layer: int) -> float:
	return (current_node_size.x * 0.5) + current_horizontal_padding if posmod(layer, 2) == 1 else 0.0

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
	tracker_text.text = _get_tracker_room_display_name(display_data)

func _scroll_to_player():
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_inside_tree() or scroll_area == null:
		return
	var current_id = _find_current_node_id()
	if current_id == "" or not node_positions_by_id.has(current_id):
		return
	var content_size = map_content.custom_minimum_size if map_content else Vector2.ZERO
	var node_center = (node_positions_by_id[current_id] + current_node_half_size) * current_node_scale
	var node_widget = node_widgets_by_id.get(current_id, null)
	if node_widget is Control:
		var widget_position: Vector2 = node_widget.position * current_node_scale
		var widget_size: Vector2 = node_widget.size * current_node_scale
		node_center = widget_position + (widget_size * 0.5)
	var target_scroll = node_center - (scroll_area.size * 0.5)
	scroll_area.scroll_horizontal = int(round(clamp(target_scroll.x, 0.0, max(0.0, content_size.x - scroll_area.size.x))))
	scroll_area.scroll_vertical = int(round(clamp(target_scroll.y, 0.0, max(0.0, content_size.y - scroll_area.size.y))))
	_update_map_anchor_ratio()
	_sync_background_pan_to_scroll()

func _update_map_layout_scale():
	var layer_count = max(1, visible_max_layer - visible_min_layer + 1)
	var row_count = max(1, visible_max_column - visible_min_column + 1)
	var available_width = max(scroll_area.size.x, get_viewport_rect().size.x) - 96.0
	var available_height = max(scroll_area.size.y, get_viewport_rect().size.y) - 96.0
	var base_row_spacing = BASE_NODE_SIZE.x + tile_horizontal_padding_px
	var base_layer_spacing = BASE_NODE_SIZE.y + tile_vertical_padding_px
	var base_stagger_offset = (BASE_NODE_SIZE.x * 0.5) + tile_horizontal_padding_px
	var base_width = float(max(0, row_count - 1)) * base_row_spacing + BASE_NODE_SIZE.x + base_stagger_offset
	var base_height = float(max(0, layer_count - 1)) * base_layer_spacing + BASE_NODE_SIZE.y
	var width_scale = available_width / max(base_width, 1.0)
	var height_scale = available_height / max(base_height, 1.0)
	current_fit_scale = clamp(min(width_scale, height_scale, 1.0), 0.42, 1.0)
	current_zoom_factor = clamp(_user_zoom_scale, MIN_MAP_ZOOM, MAX_MAP_ZOOM)
	current_node_scale = current_fit_scale * current_zoom_factor
	current_node_size = BASE_NODE_SIZE
	current_node_half_size = current_node_size * 0.5
	current_horizontal_padding = max(MIN_HEX_HORIZONTAL_PADDING, tile_horizontal_padding_px)
	current_vertical_padding = max(MIN_HEX_VERTICAL_PADDING, tile_vertical_padding_px)
	current_layer_spacing = current_node_size.y + current_vertical_padding
	current_row_spacing = current_node_size.x + current_horizontal_padding
	current_left_padding = 0.0
	current_top_padding = 0.0
	_apply_background_zoom()

func _handle_map_zoom_input(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	if not event.pressed:
		return false
	if not _is_point_inside_map_area(event.position):
		return false
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_in()
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_out()
		return true
	return false

func _handle_map_drag_input(event: InputEvent) -> bool:
	if not scroll_area:
		return false
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE):
		if event.pressed and _is_point_inside_map_area(event.position):
			_begin_map_drag(event.position, event.button_index)
			return event.button_index == MOUSE_BUTTON_MIDDLE
		if not event.pressed and (_is_drag_panning or _drag_candidate_active):
			var handled_drag = _is_drag_panning
			_end_map_drag()
			return handled_drag
	if event is InputEventMouseMotion and (_is_drag_panning or _drag_candidate_active):
		var delta = event.position - _drag_pan_origin
		if not _is_drag_panning and delta.length() >= MAP_DRAG_DEADZONE:
			_is_drag_panning = true
			_suppress_click_after_drag = true
		if _is_drag_panning:
			_suppress_click_after_drag = true
			scroll_area.scroll_horizontal = int(round(_drag_pan_scroll_origin.x - delta.x))
			scroll_area.scroll_vertical = int(round(_drag_pan_scroll_origin.y - delta.y))
			_update_map_anchor_ratio()
			_sync_background_pan_to_scroll()
			return true
		return _drag_button_index == MOUSE_BUTTON_MIDDLE
	return false

func _begin_map_drag(position: Vector2, button_index: int):
	_drag_candidate_active = true
	_drag_button_index = button_index
	_is_drag_panning = false
	_suppress_click_after_drag = false
	_drag_pan_origin = position
	_drag_pan_scroll_origin = Vector2(scroll_area.scroll_horizontal, scroll_area.scroll_vertical)

func _end_map_drag():
	_is_drag_panning = false
	_drag_candidate_active = false
	_drag_button_index = -1

func _zoom_in():
	_set_map_zoom(_user_zoom_scale + MAP_ZOOM_STEP)

func _zoom_out():
	_set_map_zoom(_user_zoom_scale - MAP_ZOOM_STEP)

func _set_map_zoom(target_zoom: float):
	var clamped_zoom = clamp(target_zoom, MIN_MAP_ZOOM, MAX_MAP_ZOOM)
	if is_equal_approx(clamped_zoom, _user_zoom_scale):
		return
	_update_map_anchor_ratio()
	_zoom_anchor_ratio = _map_anchor_ratio
	_zoom_anchor_viewport_size = scroll_area.size if scroll_area else Vector2.ZERO
	_user_zoom_scale = clamped_zoom
	_draw_map()
	if not scroll_area or not map_content:
		return
	var new_content_size = map_content.custom_minimum_size
	var target_center = Vector2(
		new_content_size.x * _zoom_anchor_ratio.x,
		new_content_size.y * _zoom_anchor_ratio.y
	)
	scroll_area.scroll_horizontal = int(round(max(0.0, target_center.x - _zoom_anchor_viewport_size.x * 0.5)))
	scroll_area.scroll_vertical = int(round(max(0.0, target_center.y - _zoom_anchor_viewport_size.y * 0.5)))
	_update_map_anchor_ratio()
	_sync_background_pan_to_scroll()

func _is_point_inside_map_area(global_point: Vector2) -> bool:
	return scroll_area != null and scroll_area.get_global_rect().has_point(global_point)

func _apply_background_zoom():
	if not background_texture:
		return
	var content_size = map_content.custom_minimum_size if map_content else get_viewport_rect().size
	var viewport_size = scroll_area.size if scroll_area else get_viewport_rect().size
	var target_size = Vector2(
		max(content_size.x, viewport_size.x),
		max(content_size.y, viewport_size.y)
	) + Vector2.ONE * (map_background_side_margin_px * 2.0)
	var zoom = max(current_node_scale, 0.001)
	background_texture.scale = Vector2.ONE * zoom
	background_texture.size = target_size / zoom
	background_texture.pivot_offset = Vector2.ZERO
	_sync_background_pan_to_scroll()

func _sync_background_pan_to_scroll():
	if not background_texture or not scroll_area:
		return
	background_texture.position = scroll_area.global_position - Vector2(
		float(scroll_area.scroll_horizontal) + map_background_side_margin_px,
		float(scroll_area.scroll_vertical) + map_background_side_margin_px
	)

func _on_map_scroll_changed(_value: float):
	_update_map_anchor_ratio()
	_sync_background_pan_to_scroll()

func _update_map_anchor_ratio():
	if not scroll_area or not map_content:
		_map_anchor_ratio = Vector2(0.5, 0.5)
		return
	var content_size = map_content.custom_minimum_size
	var viewport_size = scroll_area.size
	_map_anchor_ratio = Vector2(0.5, 0.5)
	if content_size.x > 0.0:
		_map_anchor_ratio.x = clamp((float(scroll_area.scroll_horizontal) + viewport_size.x * 0.5) / content_size.x, 0.0, 1.0)
	if content_size.y > 0.0:
		_map_anchor_ratio.y = clamp((float(scroll_area.scroll_vertical) + viewport_size.y * 0.5) / content_size.y, 0.0, 1.0)

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
	SceneTransition.change_scene_to_file(GameManager.get_story_line_scene_path())

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
	var normalized_biome = "tutorial" if biome == "home" else biome
	var bg_prop = "map_%s_background" % normalized_biome
	if bg_prop in map_assets:
		background_texture.texture = map_assets.get(bg_prop)
		_apply_background_zoom()

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
	_tutorial_active = false
	if _tutorial_overlay:
		_tutorial_overlay.visible = false
	if _tutorial_id != "":
		_set_tutorial_seen(_tutorial_id)
	_tutorial_id = ""
	_tutorial_target_mode = "node"
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
	if _tutorial_active:
		_dismiss_tutorial_popup()
	_tutorial_id = tutorial_id
	_tutorial_target_mode = target_mode
	_tutorial_active = true
	if _tutorial_message_label:
		_tutorial_message_label.text = message
	if _tutorial_hint_label:
		_tutorial_hint_label.text = LocalizationManager.translate("tutorial.continue_any_input", "Click or press any key to continue")
	if _tutorial_overlay:
		_tutorial_overlay.visible = true
		_tutorial_overlay.move_to_front()
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

func _on_run_log_updated():
	_apply_log_visibility()
	_rebuild_log_entries()

func _get_log_entry_text(entry_data) -> String:
	if entry_data is Dictionary:
		return str((entry_data as Dictionary).get("text", ""))
	return str(entry_data)

func _get_log_entry_color(entry_data) -> Color:
	if entry_data is Dictionary:
		var entry_dict := entry_data as Dictionary
		if entry_dict.has("speaker_color"):
			return entry_dict["speaker_color"]
	var lower = _get_log_entry_text(entry_data).to_lower()
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
	print("[InfoLog][WorldMapUI] %s received %s -> %s | expanded=%s scroll=%d" % [
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
