extends Control

signal summary_pressed(biome: String)

const GRANITE_TEXTURE_PATH = "res://assets/maps/story/tablet_background.png"
const TABLET_ASPECT_RATIO = 640.0 / 905.0

const MAP_SPACING = Vector2(72, 60)
const PATH_COLOR = Color(0.96, 0.62, 0.26, 0.95)
const LOCKED_COLOR = Color(0.35, 0.35, 0.38, 0.5)
const ROOM_COLOR = Color(0.72, 0.72, 0.76, 0.75)
const HOME_COLOR = Color(0.47, 0.78, 1.0, 1.0)
const COMPLETE_COLOR = Color(0.35, 0.78, 0.41, 1.0)
const PREVIEW_PADDING = Vector2(24, 24)
const NODE_OUTLINE_COLOR = Color(0.58, 0.58, 0.62, 0.92)

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
@onready var preview_bg = %PreviewBG
@onready var open_button = %OpenButton

var display_biome: String = ""

func _ready():
	open_button.pressed.connect(_open_biome_map)
	preview_frame.resized.connect(_queue_preview_refresh)
	if ResourceLoader.exists(GRANITE_TEXTURE_PATH):
		granite_rect.texture = load(GRANITE_TEXTURE_PATH)
		granite_rect.modulate = Color(0.8, 0.8, 0.84, 0.82)
	_apply_mode()
	_refresh_content.call_deferred()

func set_biome(biome: String):
	display_biome = biome
	if is_inside_tree():
		_refresh_content.call_deferred()

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
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var embedded_height = _get_embedded_height()
		var embedded_width = embedded_height * TABLET_ASPECT_RATIO
		custom_minimum_size = Vector2(embedded_width, embedded_height)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tablet.custom_minimum_size = Vector2(embedded_width, embedded_height)
		preview_frame.custom_minimum_size = Vector2(0, embedded_height * 0.74)
		title_label.add_theme_font_size_override("font_size", 22)
		subtitle_label.add_theme_font_size_override("font_size", 14)
		open_button.text = ""
		_set_control_tree_mouse_filter(self, Control.MOUSE_FILTER_IGNORE)
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2.ZERO
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		tablet.custom_minimum_size = Vector2(640, 905)
		preview_frame.custom_minimum_size = Vector2(0, 620)
		title_label.add_theme_font_size_override("font_size", 30)
		open_button.text = LocalizationManager.translate("mapsummary.open", "Open Biome Map")

func _refresh_content():
	var biome = _get_biome()
	title_label.text = _get_title_for_biome(biome)
	subtitle_label.text = _get_subtitle_for_biome(biome)
	_redraw_preview()

func _queue_preview_refresh():
	if not is_inside_tree():
		return
	_refresh_content.call_deferred()

func _redraw_preview():
	for child in preview_layer.get_children():
		child.queue_free()

	var biome = _get_biome()
	var nodes = GameManager.get_nodes_for_biome(biome)
	if nodes.is_empty():
		return

	var bounds = _get_node_bounds(nodes)
	var layout = _get_preview_layout(bounds)
	_apply_preview_background(biome, layout)
	var positions: Dictionary = {}
	for node in nodes:
		var node_id = str(node.get("id", ""))
		var layer = int(node.get("layer", 0)) - int(bounds["min_layer"])
		var col = int(node.get("column", 0)) - int(bounds["min_col"])
		positions[node_id] = Vector2(layer * layout["spacing_x"], col * layout["spacing_y"]) + Vector2(layout["offset_x"], layout["offset_y"])

	_draw_connections(nodes, positions, biome, float(layout["icon_scale"]))
	if GameManager.is_battle_mode and GameManager.is_biome_cleared(biome):
		_draw_battle_path(biome, positions)
	_draw_markers(nodes, positions, biome, float(layout["icon_scale"]))

func _draw_connections(nodes: Array[Dictionary], positions: Dictionary, biome: String, icon_scale: float):
	for node in nodes:
		var source_id = str(node.get("id", ""))
		var source_pos = positions.get(source_id, Vector2.ZERO)
		for raw_target in node.get("connections", []):
			var target_id = str(raw_target)
			if not positions.has(target_id) or source_id > target_id:
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

func _draw_markers(nodes: Array[Dictionary], positions: Dictionary, biome: String, icon_scale: float):
	for node in nodes:
		var node_id = str(node.get("id", ""))
		var marker_bg = ColorRect.new()
		var marker_size = max(6.0, 14.0 * icon_scale)
		marker_bg.size = Vector2(marker_size, marker_size)
		marker_bg.position = positions[node_id] - Vector2(marker_size * 0.5, marker_size * 0.5)
		marker_bg.color = _get_node_color(node, biome)
		preview_layer.add_child(marker_bg)

		var outline = Panel.new()
		outline.position = marker_bg.position
		outline.size = marker_bg.size
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.add_theme_stylebox_override("panel", _build_outline_style())
		preview_layer.add_child(outline)

func _get_node_color(node: Dictionary, biome: String) -> Color:
	var node_id = str(node.get("id", ""))
	var state = GameManager.world_state.rooms.get(node_id, {})
	if node_id == GameManager.get_biome_home_node_id(biome) or bool(node.get("is_home", false)):
		return HOME_COLOR
	if GameManager.is_battle_mode and (state.get("visited", false) or state.get("cleared", false)):
		return COMPLETE_COLOR
	if not GameManager.is_battle_mode and state.get("completed", false):
		return COMPLETE_COLOR
	if GameManager.is_battle_mode and GameManager.is_biome_cleared(biome):
		return ROOM_COLOR
	return ROOM_COLOR

func _get_connection_color(source_id: String, target_id: String, biome: String) -> Color:
	if GameManager.is_battle_mode and GameManager.is_biome_cleared(biome):
		return Color(0.28, 0.28, 0.32, 0.8)
	return Color(0.24, 0.24, 0.28, 0.5)

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
	var base_width = float(max(0, layer_count - 1)) * MAP_SPACING.x + 14.0
	var base_height = float(max(0, row_count - 1)) * MAP_SPACING.y + 14.0
	var scale_factor = clamp(min(usable_width / max(base_width, 1.0), usable_height / max(base_height, 1.0), 1.0), 0.18, 1.0)
	var spacing_x = MAP_SPACING.x * scale_factor
	var spacing_y = MAP_SPACING.y * scale_factor
	var content_width = float(max(0, layer_count - 1)) * spacing_x + max(8.0, 18.0 * scale_factor)
	var content_height = float(max(0, row_count - 1)) * spacing_y + max(8.0, 18.0 * scale_factor)
	return {
		"spacing_x": spacing_x,
		"spacing_y": spacing_y,
		"icon_scale": scale_factor,
		"offset_x": (frame_size.x - content_width) * 0.5,
		"offset_y": (frame_size.y - content_height) * 0.5,
		"content_width": content_width,
		"content_height": content_height
	}

func _get_embedded_height() -> float:
	return max(320.0, get_viewport_rect().size.y * 0.9)

func _apply_preview_background(biome: String, layout: Dictionary):
	if not preview_bg:
		return
	var frame_size = preview_frame.size if preview_frame.size != Vector2.ZERO else preview_frame.custom_minimum_size
	preview_bg.position = Vector2.ZERO
	preview_bg.size = frame_size
	preview_bg.texture = null
	preview_bg.modulate = Color(1, 1, 1, 1)

func _build_outline_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.draw_center = false
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = NODE_OUTLINE_COLOR
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _get_biome() -> String:
	return display_biome if display_biome != "" else GameManager.selected_story_biome

func _get_title_for_biome(biome: String) -> String:
	if biome == "home":
		return LocalizationManager.translate("mapsummary.title.home", "Home Map Summary")
	return LocalizationManager.format("mapsummary.title.default", {"biome": biome.replace("_", " ").capitalize()}, "{biome} Map Summary")

func _get_subtitle_for_biome(biome: String) -> String:
	if GameManager.is_battle_mode:
		return LocalizationManager.translate("mapsummary.subtitle.battle", "Completed biomes reveal every room and the run path.")
	return LocalizationManager.translate(
		"mapsummary.subtitle.%s" % biome,
		LocalizationManager.translate("mapsummary.subtitle.story", "Completed rooms stay visible between runs. Select to enter the biome map.")
	)

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
		if GameManager.open_story_biome_intro_if_needed(biome):
			return
		GameManager.enter_story_biome(biome, true)
	get_tree().change_scene_to_file(GameManager.get_active_biome_map_scene_path())

func _set_control_tree_mouse_filter(node: Node, filter_mode: Control.MouseFilter):
	if node is Control:
		(node as Control).mouse_filter = filter_mode
	for child in node.get_children():
		_set_control_tree_mouse_filter(child, filter_mode)
