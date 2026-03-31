extends Control

# res://features/encounters/EventScene.gd
# Narrative encounter logic utilizing Room and NPC resources.

@export_group("Environment Layout")
@export_range(0.0, 1.0) var ground_height_ratio: float = 0.2083 # ~150px from bottom on 720p
@export_range(0.0, 0.5) var side_margin_ratio: float = 0.04 # ~51px from edge on 1280p
@export var sprite_feet_offset: int = 0

@onready var background = %Background
@onready var floor_rect = get_node_or_null("%FloorRect")
@onready var room_title = %RoomTitle
@onready var biome_label = get_node_or_null("%BiomeLabel")
@onready var phase_label = get_node_or_null("%PhaseLabel")
@onready var tracker_text = get_node_or_null("%TrackerText")
@onready var avatar_button = get_node_or_null("%AvatarButton")
@onready var story_button = get_node_or_null("%StoryButton")
@onready var menu_icon_btn = get_node_or_null("%MenuIconBtn")
@onready var energy_pips = get_node_or_null("%EnergyPips")
@onready var battle_log_row = %BattleLogRow
@onready var log_left_spacer = %LeftSpacer
@onready var log_box = %LogBox
@onready var log_display = %LogDisplay
@onready var log_right_spacer = %RightSpacer
@onready var dialog_panel = $UI/SafeZone/StageLayout/NarrativeCenter/DialogPanel
@onready var dialog_speaker = %DialogSpeaker
@onready var dialog_text = %DialogText
@onready var choice_container = %ChoiceContainer
@onready var npc_name_label = %NPCName
@onready var player_sprite = %PlayerSprite
@onready var npc_sprite = %NPCSprite
@onready var exit_button = %ExitButton

var in_game_menu_scene = preload("res://features/ui/InGameMenu.tscn")
var in_game_menu = null
var current_room_res: RoomData = null
var current_npc_res: NPCData = null
var _active_dialog_lines: Array[Dictionary] = []
var _dialog_index: int = -1
var _dialog_sequence_complete: bool = false
var _dialog_panel_expanded_height := 200
var _dialog_panel_collapsed_height := 88
var is_log_expanded: bool = false
var log_collapsed_global_rect: Rect2 = Rect2()

const LOG_COLLAPSED_HEIGHT = 32.0
const LOG_EXPANDED_LINE_COUNT = 10
const LOG_LINE_HEIGHT = 22.0
const LOG_EXPANDED_PADDING = 12.0
const LOG_ROW_SEPARATION = 0
const LOG_SIDE_SPACER_WIDTH = 0.0
const LOG_COLOR_PLAYER = Color(0.62, 1.0, 0.62, 1.0)
const LOG_COLOR_NPC = Color(0.6, 0.75, 1.0, 1.0)
const LOG_COLOR_NEUTRAL = Color(0.86, 0.86, 0.86, 1.0)
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "gameplay"
const RUN_LOG_KEY := "show_run_log"
const BG_SCALING_FIXED := "fixed"
const BG_SCALING_PROPORTIONAL := "proportional"

func _ready():
	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()

	exit_button.pressed.connect(_on_exit_pressed)
	if dialog_panel and not dialog_panel.gui_input.is_connected(_on_dialog_panel_gui_input):
		dialog_panel.gui_input.connect(_on_dialog_panel_gui_input)
	if avatar_button:
		avatar_button.pressed.connect(_open_character_screen)
	if story_button:
		story_button.pressed.connect(_open_story_line)
	if menu_icon_btn:
		menu_icon_btn.pressed.connect(_toggle_in_game_menu)
	_configure_top_bar()
	_setup_battle_log_ui()
	if not SignalBus.run_log_updated.is_connected(_on_run_log_updated):
		SignalBus.run_log_updated.connect(_on_run_log_updated)
	_load_encounter_data()
	_fit_floor_to_container_width()
	_update_character_placement()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _input(event):
	if get_viewport().is_input_handled():
		return
	if is_log_expanded and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _is_point_inside_log(event.position):
			is_log_expanded = false
			_refresh_log_view()
			get_viewport().set_input_as_handled()
			return
	if _is_dialog_sequence_active() and _is_narration_progress_input(event):
		_advance_dialog_sequence()
		get_viewport().set_input_as_handled()
		return
	if _is_narration_progress_input(event) and _can_collapse_dialog_panel():
		_configure_dialog_panel(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _handle_menu_cancel():
			return
		_on_exit_pressed()

func _on_dialog_panel_gui_input(event: InputEvent):
	if not _is_narration_progress_input(event):
		return
	if _is_dialog_sequence_active():
		_advance_dialog_sequence()
		get_viewport().set_input_as_handled()
		return
	if _can_collapse_dialog_panel():
		_configure_dialog_panel(false)
		get_viewport().set_input_as_handled()

func _handle_menu_cancel() -> bool:
	if not in_game_menu or not in_game_menu.visible:
		return false
	if in_game_menu.has_method("handle_cancel"):
		return in_game_menu.handle_cancel()
	in_game_menu.close()
	return true

func _toggle_in_game_menu():
	if not in_game_menu:
		return
	if in_game_menu.visible:
		in_game_menu.close()
	else:
		in_game_menu.open()

func _load_encounter_data():
	var node = GameManager.current_node
	if not node.has("room_resource_path"): return
	
	current_room_res = load(node.room_resource_path) as RoomData
	if not current_room_res: return
	
	# 1. Visuals
	room_title.text = current_room_res.room_name
	if biome_label:
		biome_label.text = str(current_room_res.biome).capitalize()
	if phase_label:
		phase_label.text = LocalizationManager.translate("worldmap.phase.event", "EVENT")
	if tracker_text:
		tracker_text.text = current_room_res.room_name
	dialog_speaker.text = LocalizationManager.translate("dialog.speaker.narrator", "Narrator")
	exit_button.text = LocalizationManager.translate("dialog.exit_overworld", "Exit to Overworld")
	_apply_room_environment(current_room_res)
	_request_scene_music()
	_configure_dialog_panel(true)
		
	# 2. Player Spritesheet (same setup as BattleScene)
	_setup_player_spritesheet()
	
	# 3. NPC Logic
	if current_room_res.npc_id != "":
		GameManager.mark_npc_met(current_room_res.npc_id)
		var npc_path = "res://data/npcs/%s.tres" % current_room_res.npc_id
		if ResourceLoader.exists(npc_path):
			current_npc_res = load(npc_path) as NPCData
			_setup_npc(current_npc_res)
		else:
			_setup_empty_npc()
	else:
		_setup_empty_npc()

func _request_scene_music():
	if not current_room_res:
		return
	var room_type = str(current_room_res.type)
	if room_type != "home":
		return
	var biome = str(current_room_res.biome if current_room_res.biome != "" else GameManager.player_biome)
	var biome_track = AudioData.get_biome_track_id(biome)
	if biome_track != "":
		SignalBus.music_change_requested.emit(biome_track, 1.5)

func _setup_npc(data: NPCData):
	npc_name_label.text = data.name
	npc_name_label.visible = true
	_setup_unit_visuals(npc_sprite, data)
	npc_sprite.flip_h = true
	_start_room_dialog()

func _setup_empty_npc():
	npc_name_label.visible = false
	npc_sprite.visible = false
	_start_room_dialog()

func _start_room_dialog():
	var room_lines = RoomDialogService.resolve_room_dialog(current_room_res, GameManager.current_node, current_npc_res)
	if not room_lines.is_empty():
		_begin_dialog_sequence(room_lines)
		return
	if current_npc_res and current_npc_res.dialog_tree_id != "" and GameData.DIALOG_TREES.has(current_npc_res.dialog_tree_id):
		_display_dialog_node(current_npc_res.dialog_tree_id, "start")
		return
	dialog_speaker.text = _get_narrator_name()
	dialog_text.text = current_npc_res.initial_greeting if current_npc_res else current_room_res.initial_dialog
	_append_dialog_log(dialog_speaker.text, dialog_text.text)
	choice_container.visible = false
	exit_button.visible = true
	_configure_dialog_panel(false)

func _begin_dialog_sequence(lines: Array[Dictionary]):
	_active_dialog_lines = lines
	_dialog_index = -1
	_dialog_sequence_complete = false
	exit_button.visible = false
	choice_container.visible = false
	for child in choice_container.get_children():
		child.queue_free()
	_configure_dialog_panel(true)
	_advance_dialog_sequence()

func _is_dialog_sequence_active() -> bool:
	return not _active_dialog_lines.is_empty() and not _dialog_sequence_complete

func _advance_dialog_sequence():
	if not _is_dialog_sequence_active():
		return
	_dialog_index += 1
	if _dialog_index >= _active_dialog_lines.size():
		_complete_dialog_sequence()
		return
	var line = _active_dialog_lines[_dialog_index]
	dialog_speaker.text = str(line.get("speaker_name", _get_narrator_name()))
	dialog_text.text = str(line.get("text", ""))
	_append_dialog_log(dialog_speaker.text, dialog_text.text)

func _complete_dialog_sequence():
	_dialog_sequence_complete = true
	exit_button.visible = true
	choice_container.visible = false
	_configure_dialog_panel(false)

func _configure_dialog_panel(expanded: bool):
	if not dialog_panel:
		return
	dialog_panel.custom_minimum_size.y = _dialog_panel_expanded_height if expanded else _dialog_panel_collapsed_height

func _display_dialog_node(tree_id: String, node_id: String):
	var tree = GameData.DIALOG_TREES[tree_id]
	if not tree.has(node_id): return
	
	var node = tree[node_id]
	dialog_speaker.text = current_npc_res.name if current_npc_res else _get_narrator_name()
	dialog_text.text = node.text
	_append_dialog_log(dialog_speaker.text, dialog_text.text)
	choice_container.visible = true
	exit_button.visible = true
	_configure_dialog_panel(true)
	
	for child in choice_container.get_children(): child.queue_free()
	
	for opt in node.options:
		var btn = Button.new()
		btn.text = opt.text
		btn.custom_minimum_size.y = 50
		if opt.has("next_node"):
			btn.pressed.connect(func():
				_append_dialog_log(LocalizationManager.translate("dialog.speaker.player", "You"), opt.text)
				_display_dialog_node(tree_id, opt.next_node)
			)
		else:
			btn.pressed.connect(func():
				_append_dialog_log(LocalizationManager.translate("dialog.speaker.player", "You"), opt.text)
				_on_exit_pressed()
			)
		choice_container.add_child(btn)

func _setup_unit_visuals(sprite: Sprite2D, res: Resource):
	if not sprite or not res: return
	
	var sheet = res.get("idle_sheet")
	if sheet:
		sprite.texture = sheet
		sprite.hframes = res.get("hframes")
		sprite.vframes = res.get("vframes")
		sprite.scale = _get_room_character_scale()
		sprite.offset.y = sprite_feet_offset
		_update_character_placement()
		_animate_unit(sprite, res.get("total_frames"), res.get("frame_speed"))
	else:
		sprite.visible = false

func _setup_player_spritesheet():
	var idle_tex = load("res://assets/player/base_idle.png")
	if idle_tex:
		player_sprite.texture = idle_tex
		player_sprite.hframes = 6
		player_sprite.vframes = 6
		player_sprite.scale = _get_room_character_scale()
		player_sprite.offset.y = sprite_feet_offset
		_update_character_placement()
		_animate_unit(player_sprite, 8, 0.12)

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

func _apply_room_environment(res: RoomData):
	if background:
		background.stretch_mode = _get_background_stretch_mode(res)
		if res.background_texture:
			background.texture = res.background_texture
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
	var npc_half_w = _get_sprite_half_width(npc_sprite)
	var player_half_h = _get_sprite_half_height(player_sprite)
	var npc_half_h = _get_sprite_half_height(npc_sprite)
	if player_sprite:
		player_sprite.offset.y = sprite_feet_offset
		player_sprite.position = Vector2(
			edge_margin + player_half_w,
			floor_mid_y - player_half_h - player_sprite.offset.y
		)
	if npc_sprite and npc_sprite.visible:
		npc_sprite.offset.y = sprite_feet_offset
		npc_sprite.position = Vector2(
			v_size.x - edge_margin - npc_half_w,
			floor_mid_y - npc_half_h - npc_sprite.offset.y
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

func _on_exit_pressed():

	# 1. Branching return path
	get_tree().change_scene_to_file(GameManager.get_active_biome_map_scene_path())

func _open_character_screen():
	GameManager.profile_return_scene = "res://features/encounters/EventScene.tscn"
	get_tree().change_scene_to_file("res://features/ui/CharacterScreen.tscn")

func _open_story_line():
	SceneTransition.change_scene_to_file(GameManager.get_story_line_scene_path())

func _configure_top_bar():
	if energy_pips:
		energy_pips.visible = false
	if exit_button:
		exit_button.text = LocalizationManager.translate("dialog.exit_overworld", "Exit to Overworld")

func _get_narrator_name() -> String:
	return LocalizationManager.translate("dialog.speaker.narrator", "Narrator")

func _can_collapse_dialog_panel() -> bool:
	if choice_container and choice_container.visible and choice_container.get_child_count() > 0:
		return false
	return dialog_panel != null and dialog_panel.custom_minimum_size.y > _dialog_panel_collapsed_height

func _is_narration_progress_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.is_echo()
	if event is InputEventMouseButton:
		return event.pressed
	return false

func _append_dialog_log(speaker: String, text: String):
	GameManager.add_run_log("%s: %s" % [speaker, text])

func _on_run_log_updated():
	_apply_log_visibility()
	_rebuild_log_entries()

func _get_log_entry_color(text: String) -> Color:
	var lower = text.to_lower()
	if lower.begins_with(LocalizationManager.translate("dialog.speaker.player", "You").to_lower() + ":"):
		return LOG_COLOR_PLAYER
	if lower.begins_with(LocalizationManager.translate("dialog.speaker.npc", "NPC").to_lower() + ":") or (current_npc_res and lower.begins_with(current_npc_res.name.to_lower() + ":")):
		return LOG_COLOR_NPC
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
