extends Control

# res://features/map/BattleMapUI.gd
# Linear map display for Battle Mode.
# Updated: Hand-drawn centered connection lines and visibility culling.

@onready var node_container = %NodeContainer
@onready var lines_container = %LinesContainer
@onready var biome_label = %BiomeLabel
@onready var phase_label = %PhaseLabel
@onready var tracker_text = %TrackerText
@onready var scroll_area = %MapArea
@onready var avatar_button = %AvatarButton
@onready var menu_icon_btn = %MenuIconBtn
@onready var map_content = $MapArea/MapContent

# Assets & Resources
var node_scene = preload("res://features/map/MapNode.tscn")
var in_game_menu_scene = preload("res://features/ui/InGameMenu.tscn")

# Dialogs
var travel_dialog: ConfirmationDialog

# State
var in_game_menu = null
var node_widgets_by_id: Dictionary = {}
var node_positions_by_id: Dictionary = {}
var reachable_node_ids: Array[String] = []
var selected_reachable_index: int = -1
var visible_min_layer: int = 0
var visible_max_layer: int = 0

# Node dimensions from MapNode.tscn to calculate center
const NODE_HALF_SIZE = Vector2(90, 90)
const LAYER_SPACING = 360.0
const ROW_SPACING = 230.0
const MAP_LEFT_PADDING = 220.0
const MAP_TOP_PADDING = 300.0
const JITTER_X_RANGE = 34.0
const JITTER_Y_RANGE = 28.0
const SELECTED_BORDER_COLOR = Color(1, 1, 1, 1)

func _ready():
	_setup_ui()

	# If map doesn't exist (e.g. direct scene run), generate a temporary one
	if GameManager.run_map.is_empty():
		var gen = preload("res://features/map/BattleMapGenerator.gd").new()
		GameManager.run_map = await gen.generate_battle_map()

	_draw_map()

	# Instance the In-Game Menu (Esc key)
	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()

	# Music 
	SignalBus.music_change_requested.emit(AudioData.TRACKS["TOWN"], 1.0)

	_scroll_to_player()


func _input(event):
	if get_viewport().is_input_handled():
		return

	# Toggle In-Game Menu on Escape
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
	if travel_dialog and travel_dialog.visible:
		return
	
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_accept"):
		_activate_selected_node()


func _setup_ui():

	# MODAL: MOVE CHARACTER
	travel_dialog = ConfirmationDialog.new()
	travel_dialog.title = "VENTURE?"
	travel_dialog.dialog_text = "Confirm you want to travel into the unknown?"
	travel_dialog.ok_button_text = "YES"
	add_child(travel_dialog)
	
	scroll_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_area.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	if avatar_button:
		avatar_button.pressed.connect(_on_avatar_pressed)

	if menu_icon_btn:
		menu_icon_btn.pressed.connect(_toggle_in_game_menu)

func _toggle_in_game_menu():
	if in_game_menu:
		if in_game_menu.visible:
			in_game_menu.close()
		else:
			in_game_menu.open()


func _draw_map():
	# Clear previous instances
	for n in node_container.get_children(): n.queue_free()
	for l in lines_container.get_children(): l.queue_free()
	node_widgets_by_id.clear()
	node_positions_by_id.clear()
	
	var map = GameManager.run_map
	var p_pos = GameManager.player_grid_pos
	var visible_set: Dictionary = _build_visible_node_set(map)
	
	var current_layer = max(0, GameManager.player_grid_pos.x)
	var biome_num = floor(current_layer / 10.0) + 1
	var phase_num = (current_layer % 10) + 1
	
	tracker_text.text = "%d - %d" % [biome_num, phase_num]
	biome_label.text = "BIOME %d" % biome_num
	phase_label.text = "PHASE %d" % phase_num

	visible_min_layer = p_pos.x
	visible_max_layer = GameManager.player_grid_pos.x

	var visible_ids = visible_set.keys()
	for id_key in visible_ids:
		var data_for_bounds = _get_map_entry_by_id(str(id_key))
		if data_for_bounds.is_empty():
			continue
		var layer = int(data_for_bounds.layer)
		visible_min_layer = min(visible_min_layer, layer)
		visible_max_layer = max(visible_max_layer, layer)

	_update_map_content_bounds()

	for id_key in visible_ids:
		var data = _get_map_entry_by_id(str(id_key))
		if data.is_empty():
			continue
		
		var node_ui = node_scene.instantiate()
		node_container.add_child(node_ui)
		
		# Position node (Forward is Right)
		var node_pos = _get_node_position(id_key, int(data.layer), int(data.column))
		node_ui.position = node_pos
		node_positions_by_id[id_key] = node_pos
		
		var is_player_here = (data.layer == p_pos.x and data.column == p_pos.y)
		var is_reachable = (data.layer == p_pos.x + 1)
		var is_cleared = GameManager.world_state.rooms.has(id_key) and GameManager.world_state.rooms[id_key].cleared
		
		node_ui.setup_biome_node(data, null, is_cleared, is_player_here, true, is_reachable)
		node_widgets_by_id[id_key] = node_ui
		var border = node_ui.get_node_or_null("%Border")
		if border:
			border.visible = false
		# Keep all visible nodes readable; do not shade past icons.
		node_ui.modulate = Color.WHITE
		
		node_ui.node_clicked.connect(_on_node_clicked)

	# Draw connections after all node positions are known.
	for id_key in visible_ids:
		var data = _get_map_entry_by_id(str(id_key))
		if data.is_empty():
			continue
		if not node_positions_by_id.has(str(id_key)):
			continue
		var from_pos: Vector2 = node_positions_by_id[str(id_key)]
		for target_id in data.get("connections", []):
			var resolved_target_id = _resolve_map_key(target_id)
			if resolved_target_id == "":
				continue
			if not visible_set.has(resolved_target_id):
				continue
			if not node_positions_by_id.has(resolved_target_id):
				continue
			_draw_hand_drawn_dotted_line(
				from_pos + NODE_HALF_SIZE,
				node_positions_by_id[resolved_target_id] + NODE_HALF_SIZE
			)
	
	_rebuild_keyboard_targets()
	_refresh_keyboard_selection_highlight()

func _build_visible_node_set(map: Dictionary) -> Dictionary:
	var visible_set: Dictionary = {}
	var visited_set: Dictionary = {}
	
	# Visited/cleared rooms from persistent world state.
	for raw_room_id in GameManager.world_state.rooms.keys():
		var room_id = str(raw_room_id)
		var state = GameManager.world_state.rooms[raw_room_id]
		if state.get("visited", false) or state.get("cleared", false):
			visited_set[room_id] = true
	
	# Ensure current player node is always visible.
	var current_id = _find_current_node_id()
	if current_id != "":
		visited_set[current_id] = true
	
	# Fallback for fresh runs.
	if visited_set.is_empty() and map.has("node_0_0"):
		visited_set["node_0_0"] = true
	
	# Always show visited nodes.
	for visited_id in visited_set.keys():
		visible_set[str(visited_id)] = true
	
	# Show one-hop adjacent nodes:
	# 1) outgoing from visited nodes
	# 2) incoming into visited nodes
	for visited_id in visited_set.keys():
		var visited_id_str = str(visited_id)
		var visited_data = _get_map_entry_by_id(visited_id_str)
		if not visited_data.is_empty():
			for raw_target_id in visited_data.get("connections", []):
				var target_id = _resolve_map_key(raw_target_id)
				if target_id != "":
					visible_set[target_id] = true
		for raw_other_id in map.keys():
			var other_id = str(raw_other_id)
			var other_data = map[raw_other_id]
			for raw_conn in other_data.get("connections", []):
				if _resolve_map_key(raw_conn) == visited_id_str:
					visible_set[other_id] = true
					break
	
	return visible_set

func _rebuild_keyboard_targets():
	reachable_node_ids.clear()
	selected_reachable_index = -1
	
	var map = GameManager.run_map
	var current_id = _find_current_node_id()
	if current_id == "":
		return
	
	var current_data = _get_map_entry_by_id(current_id)
	if current_data.is_empty():
		return
	for raw_target_id in current_data.get("connections", []):
		var target_id = _resolve_map_key(raw_target_id)
		if target_id == "":
			continue
		var target = _get_map_entry_by_id(target_id)
		if target.is_empty():
			continue
		if int(target.layer) == GameManager.player_grid_pos.x + 1:
			reachable_node_ids.append(target_id)
	
	# Fallback for linear layouts with missing connection metadata.
	if reachable_node_ids.is_empty():
		for id in map:
			var id_key = str(id)
			var data = _get_map_entry_by_id(id_key)
			if data.is_empty():
				continue
			if int(data.layer) == GameManager.player_grid_pos.x + 1:
				reachable_node_ids.append(id_key)
	
	reachable_node_ids.sort_custom(func(a, b):
		var a_data = _get_map_entry_by_id(a)
		var b_data = _get_map_entry_by_id(b)
		if a_data.is_empty() or b_data.is_empty():
			return a < b
		return int(a_data.column) < int(b_data.column)
	)
	if not reachable_node_ids.is_empty():
		selected_reachable_index = 0

func _find_current_node_id() -> String:
	var p_pos = GameManager.player_grid_pos
	for id in GameManager.run_map:
		var data = GameManager.run_map[id]
		if int(data.layer) == p_pos.x and int(data.column) == p_pos.y:
			return str(id)
	return ""

func _resolve_map_key(raw_key) -> String:
	if GameManager.run_map.has(raw_key):
		return str(raw_key)
	var as_string = str(raw_key)
	if GameManager.run_map.has(as_string):
		return as_string
	if as_string.is_valid_int():
		var as_int = int(as_string)
		if GameManager.run_map.has(as_int):
			return str(as_int)
	return ""

func _get_map_entry_by_id(id_key: String) -> Dictionary:
	for raw_key in GameManager.run_map:
		if str(raw_key) == id_key:
			return GameManager.run_map[raw_key]
	return {}

func _move_selection(step: int):
	if reachable_node_ids.is_empty():
		return
	selected_reachable_index = posmod(selected_reachable_index + step, reachable_node_ids.size())
	_refresh_keyboard_selection_highlight()

func _activate_selected_node():
	if reachable_node_ids.is_empty():
		return
	if selected_reachable_index < 0 or selected_reachable_index >= reachable_node_ids.size():
		return
	var selected_id = reachable_node_ids[selected_reachable_index]
	var selected_data = _get_map_entry_by_id(selected_id)
	if selected_data.is_empty():
		return
	_on_node_clicked(selected_data)

func _refresh_keyboard_selection_highlight():
	for id_key in node_widgets_by_id.keys():
		var node_ui = node_widgets_by_id[id_key]
		if not is_instance_valid(node_ui):
			continue
		var border = node_ui.get_node_or_null("%Border")
		if border:
			border.visible = false

	if reachable_node_ids.is_empty():
		return
	if selected_reachable_index < 0 or selected_reachable_index >= reachable_node_ids.size():
		return
	var selected_id = reachable_node_ids[selected_reachable_index]
	if not node_widgets_by_id.has(selected_id):
		return
	var selected_node = node_widgets_by_id[selected_id]
	if not is_instance_valid(selected_node):
		return
	var selected_border = selected_node.get_node_or_null("%Border")
	if selected_border:
		selected_border.visible = true
		selected_border.modulate = SELECTED_BORDER_COLOR

func _update_map_content_bounds():
	if not map_content:
		return
	var layer_count = max(1, visible_max_layer - visible_min_layer + 1)
	var content_width = float(layer_count * LAYER_SPACING + (MAP_LEFT_PADDING * 2.0))
	var viewport_width = max(1.0, scroll_area.size.x)
	map_content.custom_minimum_size.x = max(content_width, viewport_width)

func _get_node_position(id_key: String, layer: int, column: int) -> Vector2:
	var relative_layer = layer - visible_min_layer
	var jitter = _get_node_jitter(id_key)
	return Vector2(
		relative_layer * LAYER_SPACING + MAP_LEFT_PADDING + jitter.x,
		column * ROW_SPACING + MAP_TOP_PADDING + jitter.y
	)

func _get_node_jitter(id_key: String) -> Vector2:
	var base_hash = hash("battle_map_jitter_" + id_key)
	var x_seed = abs(base_hash % 997)
	var y_seed = abs((int(base_hash / 997)) % 991)
	var x = (float(x_seed) / 996.0) * (JITTER_X_RANGE * 2.0) - JITTER_X_RANGE
	var y = (float(y_seed) / 990.0) * (JITTER_Y_RANGE * 2.0) - JITTER_Y_RANGE
	return Vector2(x, y)


func _draw_hand_drawn_dotted_line(p1: Vector2, p2: Vector2):
	var dir = (p2 - p1).normalized()
	var dist = p1.distance_to(p2)
	var current_dist = 0.0
	while current_dist < dist:
		var segment = Line2D.new()
		segment.width = 6.0
		segment.default_color = Color(0.2, 0.12, 0.05, 0.8)
		segment.begin_cap_mode = Line2D.LINE_CAP_ROUND
		var jitter_s = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		var jitter_e = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		segment.add_point(p1 + dir * current_dist + jitter_s)
		segment.add_point(p1 + dir * min(current_dist + 10.0, dist) + jitter_e)
		lines_container.add_child(segment)
		current_dist += 22.0


func _draw_line(p1: Vector2, p2: Vector2, layer_diff: int):
	var line = Line2D.new()
	line.width = 6.0
	# Dotted Brown Hand-Drawn Color
	line.default_color = Color(0.35, 0.22, 0.1, 0.6) 
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	
	# Hand-drawn variation logic
	var segments = 12
	for i in range(segments + 1):
		var t = float(i) / segments
		var pos = p1.lerp(p2, t)
		
		# Jitter intermediate points to create a "sketched" look
		if i > 0 and i < segments:
			var jitter = Vector2(randf_range(-6, 6), randf_range(-6, 6))
			pos += jitter
			
		line.add_point(pos)
	
	# Hide lines if source node is blacked out
	if layer_diff >= 2: 
		line.default_color.a = 0.0
	
	lines_container.add_child(line)

func _on_node_clicked(data: Dictionary):
	var clicked_id = str(data.get("id", ""))
	if clicked_id != "":
		var idx = reachable_node_ids.find(clicked_id)
		if idx != -1:
			selected_reachable_index = idx
			_refresh_keyboard_selection_highlight()
	
	var p_pos = GameManager.player_grid_pos
	if data.layer == p_pos.x and data.column == p_pos.y:
		_enter_room(data)
		return
	if data.layer != p_pos.x + 1:
		return

	# travel_dialog.dialog_text = "VENTURE?"
	for c in travel_dialog.confirmed.get_connections(): travel_dialog.confirmed.disconnect(c.callable)
	travel_dialog.confirmed.connect(func():
		GameManager.player_grid_pos = Vector2i(data.layer, data.column)
		_draw_map()
		_scroll_to_player()
		_enter_room(data)
	)
	travel_dialog.popup_centered()

func _enter_room(data: Dictionary):
	GameManager.current_node = data
	SignalBus.node_selected.emit(data)
	match data.type:
		"battle": get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")
		"treasure": get_tree().change_scene_to_file("res://features/encounters/TreasureScene.tscn")
		"rest": get_tree().change_scene_to_file("res://features/encounters/RestScene.tscn")
		"event": get_tree().change_scene_to_file("res://features/encounters/EventScene.tscn")

func _scroll_to_player():
	await get_tree().process_frame
	var relative_layer = GameManager.player_grid_pos.x - visible_min_layer
	var target_x = (relative_layer * LAYER_SPACING) - (size.x / 2.0) + MAP_LEFT_PADDING
	var max_scroll = max(0.0, map_content.custom_minimum_size.x - scroll_area.size.x)
	target_x = clamp(target_x, 0.0, max_scroll)
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(scroll_area, "scroll_horizontal", int(max(0, target_x)), 0.5)

func _on_avatar_pressed():
	get_tree().change_scene_to_file("res://features/ui/CharacterScreen.tscn")
