extends Control

signal summary_pressed(biome: String)

const GRANITE_TEXTURE_PATH = "res://assets/rooms/scene/the_core_red_rock_vault_room.png"
const MAP_OFFSET = Vector2(36, 44)
const MAP_SPACING = Vector2(72, 60)
const PATH_COLOR = Color(0.96, 0.62, 0.26, 0.95)
const LOCKED_COLOR = Color(0.35, 0.35, 0.38, 0.5)
const ROOM_COLOR = Color(0.72, 0.72, 0.76, 0.9)
const ADJACENT_COLOR = Color(0.92, 0.83, 0.4, 1.0)
const HOME_COLOR = Color(0.47, 0.78, 1.0, 1.0)
const PLAYER_COLOR = Color(0.3, 0.64, 1.0, 1.0)
const COMPLETE_COLOR = Color(0.35, 0.78, 0.41, 1.0)
const PREVIEW_PADDING = Vector2(24, 24)

@export var embedded_mode: bool = false
@export var show_background: bool = true
@export var allow_navigation: bool = true

@onready var background_rect = $BG
@onready var center = $Center
@onready var tablet = $Center/Tablet
@onready var granite_rect = %GraniteRect
@onready var title_label = %TitleLabel
@onready var subtitle_label = %SubtitleLabel
@onready var preview_frame = %PreviewFrame
@onready var preview_layer = %PreviewLayer
@onready var open_button = %OpenButton

var asset_library: MapAssetData = preload("res://data/map/map_data.tres")
var display_biome: String = ""

func _ready():
	open_button.pressed.connect(_open_biome_map)
	if ResourceLoader.exists(GRANITE_TEXTURE_PATH):
		granite_rect.texture = load(GRANITE_TEXTURE_PATH)
		granite_rect.modulate = Color(0.8, 0.8, 0.84, 0.82)
	_apply_mode()
	_refresh_content()

func set_biome(biome: String):
	display_biome = biome
	if is_inside_tree():
		_refresh_content()

func _input(event):
	if embedded_mode:
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(GameManager.get_story_map_scene_path())
	elif event.is_action_pressed("ui_accept"):
		_open_biome_map()

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if embedded_mode:
			summary_pressed.emit(_get_biome())
		elif event.double_click:
			_open_biome_map()

func _apply_mode():
	background_rect.visible = show_background and not embedded_mode
	open_button.visible = allow_navigation and not embedded_mode
	if embedded_mode:
		custom_minimum_size = Vector2(300, 340)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tablet.custom_minimum_size = Vector2(300, 340)
		preview_frame.custom_minimum_size = Vector2(0, 200)
		title_label.add_theme_font_size_override("font_size", 22)
		subtitle_label.add_theme_font_size_override("font_size", 14)
	else:
		custom_minimum_size = Vector2.ZERO
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		tablet.custom_minimum_size = Vector2(640, 905)
		preview_frame.custom_minimum_size = Vector2(0, 620)
		title_label.add_theme_font_size_override("font_size", 30)

func _refresh_content():
	var biome = _get_biome()
	title_label.text = _get_title_for_biome(biome)
	subtitle_label.text = _get_subtitle_for_biome(biome)
	_redraw_preview()

func _redraw_preview():
	for child in preview_layer.get_children():
		child.queue_free()

	var biome = _get_biome()
	var nodes = GameManager.get_nodes_for_biome(biome)
	if nodes.is_empty():
		return

	var visible_ids = _get_visible_node_ids(biome)
	var bounds = _get_node_bounds(nodes)
	var layout = _get_preview_layout(bounds)
	var positions: Dictionary = {}
	for node in nodes:
		var node_id = str(node.get("id", ""))
		if not visible_ids.has(node_id):
			continue
		var layer = int(node.get("layer", 0)) - int(bounds["min_layer"])
		var col = int(node.get("column", 0)) - int(bounds["min_col"])
		positions[node_id] = Vector2(layer * layout["spacing_x"], col * layout["spacing_y"]) + Vector2(layout["offset_x"], layout["offset_y"])

	_draw_connections(nodes, positions, biome, visible_ids, float(layout["icon_scale"]))
	if GameManager.is_battle_mode and GameManager.is_biome_cleared(biome):
		_draw_battle_path(biome, positions)
	_draw_markers(nodes, positions, biome, visible_ids, float(layout["icon_scale"]))

func _draw_connections(nodes: Array[Dictionary], positions: Dictionary, biome: String, visible_ids: Dictionary, icon_scale: float):
	for node in nodes:
		var source_id = str(node.get("id", ""))
		if not visible_ids.has(source_id):
			continue
		var source_pos = positions.get(source_id, Vector2.ZERO)
		for raw_target in node.get("connections", []):
			var target_id = str(raw_target)
			if not visible_ids.has(target_id) or not positions.has(target_id) or source_id > target_id:
				continue
			var line = Line2D.new()
			line.width = max(2.0, 3.0 * icon_scale)
			line.default_color = _get_connection_color(source_id, target_id, biome)
			line.add_point(source_pos)
			line.add_point(positions[target_id])
			preview_layer.add_child(line)

func _draw_battle_path(biome: String, positions: Dictionary):
	var path: Array = GameManager.get_biome_run_path(biome)
	if path.size() < 2:
		return
	var polyline = Line2D.new()
	polyline.width = 5.0
	polyline.default_color = PATH_COLOR
	polyline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	polyline.end_cap_mode = Line2D.LINE_CAP_ROUND
	for step in path:
		var step_vec = _to_grid_vector(step)
		var node_id = _find_node_id_by_grid(step_vec)
		if node_id == "" or not positions.has(node_id):
			continue
		polyline.add_point(positions[node_id])
	if polyline.get_point_count() >= 2:
		preview_layer.add_child(polyline)

func _draw_markers(nodes: Array[Dictionary], positions: Dictionary, biome: String, visible_ids: Dictionary, icon_scale: float):
	for node in nodes:
		var node_id = str(node.get("id", ""))
		if not visible_ids.has(node_id):
			continue
		var marker_bg = ColorRect.new()
		var marker_size = 18.0 * icon_scale
		marker_bg.size = Vector2(marker_size, marker_size)
		marker_bg.position = positions[node_id] - Vector2(marker_size * 0.5, marker_size * 0.5)
		marker_bg.color = _get_node_color(node, biome)
		preview_layer.add_child(marker_bg)

		var icon_texture = _get_node_icon_texture(node)
		if icon_texture:
			var icon = Sprite2D.new()
			icon.texture = icon_texture
			icon.position = positions[node_id]
			icon.scale = Vector2.ONE * (0.18 * icon_scale)
			preview_layer.add_child(icon)

func _get_node_color(node: Dictionary, biome: String) -> Color:
	var node_id = str(node.get("id", ""))
	var state = GameManager.world_state.rooms.get(node_id, {})
	if _is_player_node(node):
		return PLAYER_COLOR
	if node_id == GameManager.get_biome_home_node_id(biome) or bool(node.get("is_home", false)):
		return HOME_COLOR
	if state.get("completed", false) or state.get("cleared", false):
		return COMPLETE_COLOR
	if not GameManager.is_battle_mode and _get_story_adjacent_node_ids(biome).has(node_id):
		return ADJACENT_COLOR
	if not GameManager.is_battle_mode:
		return ROOM_COLOR if _is_story_visible(node_id) else LOCKED_COLOR
	if GameManager.is_biome_cleared(biome):
		return ROOM_COLOR
	if state.get("visited", false):
		return ADJACENT_COLOR
	return LOCKED_COLOR

func _get_connection_color(source_id: String, target_id: String, biome: String) -> Color:
	if GameManager.is_battle_mode and GameManager.is_biome_cleared(biome):
		return Color(0.28, 0.28, 0.32, 0.8)
	if not GameManager.is_battle_mode and (_is_story_visible(source_id) and _is_story_visible(target_id)):
		return Color(0.28, 0.28, 0.32, 0.72)
	return Color(0.18, 0.18, 0.2, 0.35)

func _get_story_adjacent_node_ids(biome: String) -> Array[String]:
	if biome != GameManager.player_biome:
		return []
	var current_id = _find_current_node_id(biome)
	if current_id == "":
		return []
	var results: Array[String] = []
	var current_node = _get_node_by_id(current_id)
	for raw_target in current_node.get("connections", []):
		var target_id = str(raw_target)
		var target_node = _get_node_by_id(target_id)
		if target_node.is_empty() or str(target_node.get("biome", "")) != biome:
			continue
		results.append(target_id)
	return results

func _is_story_visible(node_id: String) -> bool:
	var state = GameManager.world_state.rooms.get(node_id, {})
	return state.get("completed", false)

func _is_player_node(node: Dictionary) -> bool:
	var layer = int(node.get("layer", -999))
	var column = int(node.get("column", -999))
	if GameManager.is_battle_mode:
		return GameManager.player_grid_pos == Vector2i(layer, column)
	return GameManager.player_grid_pos == Vector2i(column, layer)

func _find_current_node_id(biome: String) -> String:
	for raw_key in GameManager.run_map.keys():
		var data = GameManager.run_map[raw_key]
		if str(data.get("biome", "")) != biome:
			continue
		if _is_player_node(data):
			return str(raw_key)
	return ""

func _find_node_id_by_grid(grid_pos: Vector2i) -> String:
	for raw_key in GameManager.run_map.keys():
		var node = GameManager.run_map[raw_key]
		if int(node.get("layer", -999)) == grid_pos.x and int(node.get("column", -999)) == grid_pos.y:
			return str(raw_key)
	return ""

func _to_grid_vector(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-999, -999)

func _get_node_by_id(node_id: String) -> Dictionary:
	for raw_key in GameManager.run_map.keys():
		if str(raw_key) == node_id:
			return GameManager.run_map[raw_key]
	return {}

func _get_node_bounds(nodes: Array[Dictionary]) -> Dictionary:
	var min_layer = 999999
	var max_layer = -999999
	var min_col = 999999
	var max_col = -999999
	for node in nodes:
		min_layer = min(min_layer, int(node.get("layer", 0)))
		max_layer = max(max_layer, int(node.get("layer", 0)))
		min_col = min(min_col, int(node.get("column", 0)))
		max_col = max(max_col, int(node.get("column", 0)))
	return {
		"min_layer": min_layer,
		"max_layer": max_layer,
		"min_col": min_col,
		"max_col": max_col
	}

func _get_preview_layout(bounds: Dictionary) -> Dictionary:
	var frame_size = preview_frame.size if preview_frame.size != Vector2.ZERO else preview_frame.custom_minimum_size
	var layer_count = max(1, int(bounds["max_layer"]) - int(bounds["min_layer"]) + 1)
	var row_count = max(1, int(bounds["max_col"]) - int(bounds["min_col"]) + 1)
	var usable_width = max(80.0, frame_size.x - (PREVIEW_PADDING.x * 2.0))
	var usable_height = max(80.0, frame_size.y - (PREVIEW_PADDING.y * 2.0))
	var base_width = float(max(0, layer_count - 1)) * MAP_SPACING.x + 18.0
	var base_height = float(max(0, row_count - 1)) * MAP_SPACING.y + 18.0
	var scale_factor = clamp(min(usable_width / max(base_width, 1.0), usable_height / max(base_height, 1.0), 1.0), 0.32, 1.0)
	var spacing_x = MAP_SPACING.x * scale_factor
	var spacing_y = MAP_SPACING.y * scale_factor
	var content_width = float(max(0, layer_count - 1)) * spacing_x + (18.0 * scale_factor)
	var content_height = float(max(0, row_count - 1)) * spacing_y + (18.0 * scale_factor)
	return {
		"spacing_x": spacing_x,
		"spacing_y": spacing_y,
		"icon_scale": scale_factor,
		"offset_x": (frame_size.x - content_width) * 0.5,
		"offset_y": (frame_size.y - content_height) * 0.5
	}

func _get_visible_node_ids(biome: String) -> Dictionary:
	var visible_ids: Dictionary = {}
	if GameManager.is_battle_mode and GameManager.is_biome_cleared(biome):
		for node in GameManager.get_nodes_for_biome(biome):
			visible_ids[str(node.get("id", ""))] = true
		return visible_ids

	var current_id = _find_current_node_id(biome)
	if current_id != "":
		visible_ids[current_id] = true

	for node_id in _get_story_adjacent_node_ids(biome):
		visible_ids[node_id] = true

	var home_id = GameManager.get_biome_home_node_id(biome)
	if home_id != "":
		visible_ids[home_id] = true

	for node in GameManager.get_nodes_for_biome(biome):
		var node_id = str(node.get("id", ""))
		if _is_story_visible(node_id):
			visible_ids[node_id] = true

	return visible_ids

func _get_type_icon_texture(type: String) -> Texture2D:
	if not asset_library:
		return null
	var property_name = "map_icon_" + type.to_lower()
	if property_name in asset_library:
		var tex = asset_library.get(property_name)
		if tex:
			return tex
	return asset_library.map_icon_mystery

func _get_node_icon_texture(node: Dictionary) -> Texture2D:
	if str(node.get("type", "")) == "home" or bool(node.get("is_home", false)):
		return _get_type_icon_texture("home")
	if GameManager.is_battle_mode:
		return _get_type_icon_texture(str(node.get("type", "mystery")))
	var custom_icon_path = str(node.get("custom_icon_path", ""))
	if custom_icon_path != "" and ResourceLoader.exists(custom_icon_path):
		var custom_icon = load(custom_icon_path) as Texture2D
		if custom_icon:
			return custom_icon
	return _get_type_icon_texture(str(node.get("type", "mystery")))

func _get_biome() -> String:
	return display_biome if display_biome != "" else GameManager.selected_story_biome

func _get_title_for_biome(biome: String) -> String:
	if biome == "home":
		return "Home Map Summary"
	return "%s Map Summary" % biome.replace("_", " ").capitalize()

func _get_subtitle_for_biome(biome: String) -> String:
	if GameManager.is_battle_mode:
		return "Completed biomes reveal every room and the run path."
	if biome == GameManager.player_biome:
		return "Home, current location, adjacent rooms, and completed rooms are marked."
	return "Permanent rooms stay visible between runs. Select to enter the biome map."

func _open_biome_map():
	var biome = _get_biome()
	if embedded_mode or not allow_navigation:
		summary_pressed.emit(biome)
		return
	if GameManager.is_battle_mode:
		var biome_nodes = GameManager.get_nodes_for_biome(biome)
		if biome_nodes.is_empty():
			return
		var entry_node: Dictionary = {}
		for node in biome_nodes:
			if bool(node.get("is_home", false)):
				entry_node = node
				break
		if entry_node.is_empty():
			entry_node = biome_nodes[0]
		GameManager.player_biome = biome
		GameManager.player_grid_pos = Vector2i(int(entry_node.get("layer", 0)), int(entry_node.get("column", 0)))
	else:
		GameManager.enter_story_biome(biome, true)
	get_tree().change_scene_to_file(GameManager.get_active_biome_map_scene_path())
