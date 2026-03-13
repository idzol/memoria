extends Control

# res://features/map/WorldMapUI.gd
# Shared overworld UI for both battle mode and story mode, using the battle-map layout.

@onready var node_container = %NodeContainer
@onready var lines_container = %LinesContainer
@onready var biome_label = %BiomeLabel
@onready var phase_label = %PhaseLabel
@onready var tracker_text = %TrackerText
@onready var scroll_area = %MapArea
@onready var avatar_button = %AvatarButton
@onready var story_button = %StoryButton
@onready var menu_icon_btn = %MenuIconBtn
@onready var map_content = $MapArea/MapContent
@onready var info_toast_box = %InfoToastBox
@onready var info_toast_label = %InfoToastLabel
@onready var background_texture = %BGTexture

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

const NODE_HALF_SIZE = Vector2(90, 90)
const LAYER_SPACING = 240.0
const ROW_SPACING = 220.0
const MAP_LEFT_PADDING = 240.0
const MAP_TOP_PADDING = 220.0
const DOTTED_COLOR = Color(0.68, 0.68, 0.72, 0.85)
const BACKTRACK_PROMPT = "You have a feeling you have been here before. An intense pain fills your mind as memory floods back"

func _ready():
	_setup_ui()

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

	_draw_map()

	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()

	SignalBus.music_change_requested.emit(AudioData.TRACKS["TOWN"], 1.0)
	_scroll_to_player()

func _input(event):
	if get_viewport().is_input_handled():
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
	scroll_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_area.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	if avatar_button:
		avatar_button.pressed.connect(_on_avatar_pressed)
	if story_button:
		story_button.pressed.connect(_open_story_map)
	if menu_icon_btn:
		menu_icon_btn.pressed.connect(_toggle_in_game_menu)

	_hide_info_toast()

func _toggle_in_game_menu():
	if not in_game_menu:
		return
	if in_game_menu.visible:
		in_game_menu.close()
	else:
		in_game_menu.open()

func _draw_map():
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

	var drawn_pairs: Dictionary = {}
	for source_id in revealed_set.keys():
		var source_id_str = str(source_id)
		var source_data = _get_map_entry_by_id(source_id_str)
		if source_data.is_empty() or not node_positions_by_id.has(source_id_str):
			continue
		for raw_target_id in source_data.get("connections", []):
			var target_id = _resolve_map_key(raw_target_id)
			if target_id == "" or not revealed_set.has(target_id):
				continue
			if not node_positions_by_id.has(target_id):
				continue
			var pair_key = _make_pair_key(source_id_str, target_id)
			if drawn_pairs.has(pair_key):
				continue
			drawn_pairs[pair_key] = true
			_draw_hand_drawn_dotted_line(
				node_positions_by_id[source_id_str] + NODE_HALF_SIZE,
				node_positions_by_id[target_id] + NODE_HALF_SIZE
			)

	_refresh_selection_highlight(current_id)

func _update_header_labels(current_data: Dictionary):
	var biome_key = str(current_data.get("biome", "town"))
	var biome_name = biome_key.replace("_", " ").capitalize()
	biome_label.text = biome_name

	if GameManager.is_battle_mode:
		var biome_index = int(current_data.get("biome_index", 0))
		var grid_size = biome_index + 2
		phase_label.text = "%dx%d GRID" % [grid_size, grid_size]
	else:
		phase_label.text = "STORY MAP"

	tracker_text.text = "%s [%d,%d]" % [biome_name, int(current_data.get("layer", 0)), int(current_data.get("column", 0))]

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
		if state.get("visited", false) or state.get("cleared", false) or state.get("completed", false) or str(data.get("type", "")) == "home":
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
	adjacent_node_ids = _get_adjacent_node_ids(current_id, biome)
	if adjacent_node_ids.is_empty():
		selected_node_id = ""
		return
	if selected_node_id == "" or not adjacent_node_ids.has(selected_node_id):
		selected_node_id = adjacent_node_ids[0]

func _refresh_selection_highlight(current_id: String):
	for id_key in node_widgets_by_id.keys():
		var node_ui = node_widgets_by_id[id_key]
		if not is_instance_valid(node_ui):
			continue
		if node_ui.has_method("set_highlight_state"):
			node_ui.set_highlight_state(id_key == current_id, id_key == selected_node_id)

func _move_selection_by_direction(dir: Vector2i):
	if adjacent_node_ids.is_empty():
		return
	var current_id = _find_current_node_id()
	if current_id == "":
		return

	var current_data = _get_map_entry_by_id(current_id)
	if current_data.is_empty():
		return

	var origin_id = selected_node_id if selected_node_id != "" else current_id
	var origin_data = _get_map_entry_by_id(origin_id)
	if origin_data.is_empty():
		origin_data = current_data

	var best_id = ""
	var best_score = INF
	for candidate_id in adjacent_node_ids:
		var candidate_data = _get_map_entry_by_id(candidate_id)
		if candidate_data.is_empty():
			continue
		var dx = int(candidate_data.get("layer", 0)) - int(origin_data.get("layer", 0))
		var dy = int(candidate_data.get("column", 0)) - int(origin_data.get("column", 0))
		if dir.x < 0 and dx >= 0:
			continue
		if dir.x > 0 and dx <= 0:
			continue
		if dir.y < 0 and dy >= 0:
			continue
		if dir.y > 0 and dy <= 0:
			continue
		var score = abs(dx) + abs(dy) + (abs(dy) if dir.x != 0 else abs(dx)) * 0.25
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
	_attempt_travel(selected_node_id)

func _on_node_clicked(data: Dictionary):
	var node_id = str(data.get("id", ""))
	if node_id == "":
		return
	if adjacent_node_ids.has(node_id):
		selected_node_id = node_id
		_refresh_selection_highlight(_find_current_node_id())

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

	if GameManager.is_battle_mode and _is_backtrack(target_id) and not _is_home_node(target_data):
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

func _show_backtrack_toast():
	if _info_toast_tween:
		_info_toast_tween.kill()
	info_toast_label.text = BACKTRACK_PROMPT
	info_toast_box.visible = true
	info_toast_box.modulate = Color(1, 1, 1, 0)
	_info_toast_tween = create_tween()
	_info_toast_tween.tween_property(info_toast_box, "modulate:a", 1.0, 0.12)
	_info_toast_tween.tween_interval(1.4)
	_info_toast_tween.tween_property(info_toast_box, "modulate:a", 0.0, 0.4)
	_info_toast_tween.finished.connect(_hide_info_toast)

func _travel_to_boss_node(target_data: Dictionary):
	_show_backtrack_toast()
	await get_tree().create_timer(1.1).timeout
	_set_player_position_from_data(target_data)
	GameManager.player_biome = str(target_data.get("biome", GameManager.player_biome))
	GameManager.set_selected_story_biome(GameManager.player_biome)
	_draw_map()
	_scroll_to_player()
	_enter_room(_build_boss_node(target_data))

func _hide_info_toast():
	if info_toast_box:
		info_toast_box.visible = false
		info_toast_box.modulate = Color(1, 1, 1, 0)
	if info_toast_label:
		info_toast_label.text = ""

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
	var state = GameManager.world_state.rooms.get(target_id, {})
	return state.get("visited", false) or state.get("cleared", false)

func _is_home_node(node_data: Dictionary) -> bool:
	return bool(node_data.get("is_home", false)) or str(node_data.get("type", "")) == "home"

func _enter_room(data: Dictionary):
	GameManager.current_node = data
	SignalBus.node_selected.emit(data)

	var room_path = str(data.get("room_resource_path", ""))
	var room_res: RoomData = null
	if room_path != "" and ResourceLoader.exists(room_path):
		room_res = load(room_path) as RoomData
	var room_type = str(data.get("type", "battle"))
	if room_res:
		room_type = str(room_res.type)

	match room_type:
		"battle", "boss":
			get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")
		"rest":
			get_tree().change_scene_to_file("res://features/encounters/RestScene.tscn")
		"shop":
			get_tree().change_scene_to_file("res://features/encounters/ShopScene.tscn")
		"event", "home", "lore", "npc":
			get_tree().change_scene_to_file("res://features/encounters/EventScene.tscn")
		_:
			get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")

func _find_current_node_id() -> String:
	for raw_key in GameManager.run_map.keys():
		var data = GameManager.run_map[raw_key]
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

	for raw_target_id in data.get("connections", []):
		var target_id = _resolve_map_key(raw_target_id)
		if target_id == "":
			continue
		var target_data = _get_map_entry_by_id(target_id)
		if target_data.is_empty():
			continue
		if str(target_data.get("biome", "")) != biome:
			continue
		if not results.has(target_id):
			results.append(target_id)

	results.sort()
	return results

func _make_pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]

func _update_map_content_bounds():
	if not map_content:
		return
	var layer_count = max(1, visible_max_layer - visible_min_layer + 1)
	var row_count = max(1, visible_max_column - visible_min_column + 1)
	var content_width = float(layer_count) * LAYER_SPACING + (MAP_LEFT_PADDING * 2.0)
	var content_height = float(row_count) * ROW_SPACING + (MAP_TOP_PADDING * 2.0)
	map_content.custom_minimum_size = Vector2(
		max(content_width, scroll_area.size.x),
		max(content_height, scroll_area.size.y)
	)

func _get_node_position(layer: int, column: int) -> Vector2:
	var relative_layer = layer - visible_min_layer
	var relative_column = column - visible_min_column
	return Vector2(
		relative_layer * LAYER_SPACING + MAP_LEFT_PADDING,
		relative_column * ROW_SPACING + MAP_TOP_PADDING
	)

func _draw_hand_drawn_dotted_line(p1: Vector2, p2: Vector2):
	var dir = (p2 - p1).normalized()
	var dist = p1.distance_to(p2)
	var current_dist = 0.0
	while current_dist < dist:
		var segment = Line2D.new()
		segment.width = 4.0
		segment.default_color = DOTTED_COLOR
		segment.begin_cap_mode = Line2D.LINE_CAP_ROUND
		segment.end_cap_mode = Line2D.LINE_CAP_ROUND
		segment.add_point(p1 + dir * current_dist)
		segment.add_point(p1 + dir * min(current_dist + 9.0, dist))
		lines_container.add_child(segment)
		current_dist += 18.0

func _scroll_to_player():
	await get_tree().process_frame
	var layer_offset = _get_player_layer() - visible_min_layer
	var col_offset = _get_player_column() - visible_min_column
	var target_x = layer_offset * LAYER_SPACING + MAP_LEFT_PADDING - (scroll_area.size.x * 0.5)
	var target_y = col_offset * ROW_SPACING + MAP_TOP_PADDING - (scroll_area.size.y * 0.5)
	var max_scroll_x = max(0.0, map_content.custom_minimum_size.x - scroll_area.size.x)
	var max_scroll_y = max(0.0, map_content.custom_minimum_size.y - scroll_area.size.y)
	target_x = clamp(target_x, 0.0, max_scroll_x)
	target_y = clamp(target_y, 0.0, max_scroll_y)
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(scroll_area, "scroll_horizontal", int(target_x), 0.35)
	tween.parallel().tween_property(scroll_area, "scroll_vertical", int(target_y), 0.35)

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
	get_tree().change_scene_to_file(GameManager.get_story_map_scene_path())

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
