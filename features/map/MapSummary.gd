extends Control

signal summary_pressed(biome: String)

const GRANITE_TEXTURE_PATH = "res://assets/maps/story/tablet_background.png"
const TABLET_ASPECT_RATIO = 640.0 / 905.0

const BASE_HEX_RADIUS = 12.0
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
var embedded_target_size: Vector2 = Vector2.ZERO

func _ready():
	open_button.pressed.connect(_open_biome_map)
	preview_frame.resized.connect(_queue_preview_refresh)
	if not resized.is_connected(_refresh_embedded_layout):
		resized.connect(_refresh_embedded_layout)
	if ResourceLoader.exists(GRANITE_TEXTURE_PATH):
		granite_rect.texture = load(GRANITE_TEXTURE_PATH)
		granite_rect.modulate = Color(0.8, 0.8, 0.84, 0.82)
	_apply_mode()
	_refresh_content.call_deferred()
	_refresh_embedded_layout.call_deferred()

func set_biome(biome: String):
	display_biome = biome
	if is_inside_tree():
		_refresh_content.call_deferred()

func set_embedded_target_size(target_size: Vector2):
	embedded_target_size = target_size
	if is_inside_tree():
		_refresh_embedded_layout()

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
		custom_minimum_size = Vector2.ZERO
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.add_theme_font_size_override("font_size", 22)
		subtitle_label.add_theme_font_size_override("font_size", 14)
		open_button.text = ""
		_set_control_tree_mouse_filter(self, Control.MOUSE_FILTER_IGNORE)
		_refresh_embedded_layout.call_deferred()
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
		positions[node_id] = _get_hex_preview_position(node, bounds, layout)

	_draw_markers(nodes, positions, biome, float(layout["hex_radius"]), float(layout["icon_scale"]))

func _draw_markers(nodes: Array[Dictionary], positions: Dictionary, biome: String, hex_radius: float, icon_scale: float):
	for node in nodes:
		if not _should_show_node(node, biome):
			continue
		var node_id = str(node.get("id", ""))
		if not positions.has(node_id):
			continue
		var center_pos: Vector2 = positions[node_id]
		var radius = max(7.0, hex_radius)
		var polygon = Polygon2D.new()
		polygon.polygon = _build_hex_polygon(center_pos, radius)
		polygon.color = _get_node_color(node, biome)
		preview_layer.add_child(polygon)

		var outline = Line2D.new()
		outline.width = max(1.0, 1.5 * icon_scale)
		outline.default_color = NODE_OUTLINE_COLOR
		outline.closed = true
		for point in polygon.polygon:
			outline.add_point(point)
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
	if not GameManager.is_battle_mode:
		return Color(0, 0, 0, 0)
	if GameManager.is_battle_mode and GameManager.is_biome_cleared(biome):
		return ROOM_COLOR
	return ROOM_COLOR

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
	var base_hex_width = BASE_HEX_RADIUS * 1.72
	var base_hex_height = BASE_HEX_RADIUS * 2.0
	var base_vertical_step = BASE_HEX_RADIUS * 1.5
	var base_width = float(max(0, row_count - 1)) * base_hex_width + base_hex_width + (base_hex_width * 0.5)
	var base_height = float(max(0, layer_count - 1)) * base_vertical_step + base_hex_height
	var scale_factor = clamp(min(usable_width / max(base_width, 1.0), usable_height / max(base_height, 1.0), 1.0), 0.18, 1.0)
	var hex_radius = BASE_HEX_RADIUS * scale_factor
	var spacing_x = base_hex_width * scale_factor
	var spacing_y = base_vertical_step * scale_factor
	var content_width = float(max(0, row_count - 1)) * spacing_x + spacing_x + (spacing_x * 0.5)
	var content_height = float(max(0, layer_count - 1)) * spacing_y + (hex_radius * 2.0)
	return {
		"spacing_x": spacing_x,
		"spacing_y": spacing_y,
		"hex_radius": hex_radius,
		"icon_scale": scale_factor,
		"offset_x": (frame_size.x - content_width) * 0.5,
		"offset_y": (frame_size.y - content_height) * 0.5,
		"content_width": content_width,
		"content_height": content_height
	}

func _get_embedded_height() -> float:
	return max(320.0, get_viewport_rect().size.y * 0.9)

func _refresh_embedded_layout():
	if not embedded_mode or not tablet or not preview_frame:
		return
	var available_size = embedded_target_size
	if available_size == Vector2.ZERO:
		available_size = size
	if available_size == Vector2.ZERO and get_parent() is Control:
		available_size = (get_parent() as Control).size
	if available_size == Vector2.ZERO:
		var fallback_height = _get_embedded_height()
		available_size = Vector2(fallback_height * TABLET_ASPECT_RATIO, fallback_height)
	var target_height = max(320.0, available_size.y)
	var target_width = target_height * TABLET_ASPECT_RATIO
	if available_size.x > 0.0 and target_width > available_size.x:
		target_width = available_size.x
		target_height = target_width / TABLET_ASPECT_RATIO
	tablet.custom_minimum_size = Vector2(target_width, target_height)
	preview_frame.custom_minimum_size = Vector2(0, target_height * 0.74)
	_queue_preview_refresh()

func _apply_preview_background(_biome: String, _layout: Dictionary):
	if not preview_bg:
		return
	var frame_size = preview_frame.size if preview_frame.size != Vector2.ZERO else preview_frame.custom_minimum_size
	preview_bg.position = Vector2.ZERO
	preview_bg.size = frame_size
	preview_bg.texture = null
	preview_bg.modulate = Color(1, 1, 1, 1)

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
		LocalizationManager.translate("mapsummary.subtitle.story", "Home and completed rooms remain visible on the minimap. Select to enter the biome map.")
	)

func _get_hex_preview_position(node: Dictionary, bounds: Dictionary, layout: Dictionary) -> Vector2:
	var relative_layer = int(node.get("layer", 0)) - int(bounds["min_layer"])
	var relative_column = int(node.get("column", 0)) - int(bounds["min_col"])
	var offset_x = float(layout["spacing_x"]) * 0.5 if posmod(relative_layer, 2) == 1 else 0.0
	return Vector2(
		relative_column * float(layout["spacing_x"]) + offset_x + float(layout["offset_x"]),
		relative_layer * float(layout["spacing_y"]) + float(layout["offset_y"])
	)

func _build_hex_polygon(center_pos: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center_pos + Vector2(0.0, -radius),
		center_pos + Vector2(radius * 0.86, -radius * 0.5),
		center_pos + Vector2(radius * 0.86, radius * 0.5),
		center_pos + Vector2(0.0, radius),
		center_pos + Vector2(-radius * 0.86, radius * 0.5),
		center_pos + Vector2(-radius * 0.86, -radius * 0.5)
	])

func _should_show_node(node: Dictionary, biome: String) -> bool:
	if str(node.get("type", "")) == "background":
		return false
	var node_id = str(node.get("id", ""))
	if node_id == GameManager.get_biome_home_node_id(biome) or bool(node.get("is_home", false)):
		return true
	var state = GameManager.world_state.rooms.get(node_id, {})
	if GameManager.is_battle_mode:
		return state.get("visited", false) or state.get("cleared", false)
	return true

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
