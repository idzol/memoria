extends Control

# res://features/map/MapNode.gd
# Handles the dual-state visuals (undiscovered vs discovered) for map nodes.
# Updated: Uses MapAssetData resource for icon lookups.

signal node_clicked(data)
signal node_double_clicked(data)

# Preload types and the specific asset library instance
# const MapAssetData = preload("res://data/resources/MapAssetData.gd")
var asset_library: MapAssetData = preload("res://data/map/map_data.tres")
var hex_mask_shader := preload("res://features/map/HexMask.gdshader")

@onready var icon_rect = %Icon
@onready var grid_texture_rect = %GridTexture
@onready var player_indicator = %PlayerIcon
@onready var fill = %Fill
@onready var border = %Border
@onready var hex_fill = %HexFill
@onready var hex_border = %HexBorder
@onready var room_name_label: Label = %RoomNameLabel

var node_data = null
var _is_hex_node: bool = false
var _is_player_here: bool = false
var _is_selected: bool = false
var _is_revealed: bool = false
var _is_background_node: bool = false
var _hex_icon_material: ShaderMaterial = null
var _hex_viewport: SubViewport = null
var _hex_viewport_root: Control = null
var _hex_viewport_icon: TextureRect = null
var _hex_output_rect: TextureRect = null

const DEFAULT_BORDER_COLOR = Color(0.58, 0.58, 0.62, 0.92)
const HIDDEN_FILL_COLOR = Color(0.06, 0.07, 0.08, 0.28)
const SELECTED_COLOR = Color(0.72, 0.92, 0.72, 0.96)
const SELECTED_FILL_COLOR = Color(0.72, 0.92, 0.72, 0.3)
const PLAYER_BORDER_COLOR = Color(0.08, 0.42, 0.14, 1.0)
const PLAYER_FILL_COLOR = Color(0.42, 0.84, 0.45, 0.3)
const HEX_CLEAR_FILL_COLOR = Color(0.0, 0.0, 0.0, 0.0)
const BACKGROUND_FILL_COLOR = Color(0.08, 0.08, 0.09, 0.74)
const HEX_ICON_SIZE_MULTIPLIER = 1.0
const HEX_ICON_BASE_HORIZONTAL_INSET = 0
const HEX_ICON_BASE_TOP_INSET = 0
const HEX_ICON_BASE_BOTTOM_INSET = 0
const DEFAULT_ICON_SCALE_X = 1.0
const DEFAULT_ICON_SCALE_Y = 1.0
const DEFAULT_ICON_OFFSET_X = 0.0
const DEFAULT_ICON_OFFSET_Y = 0.0
const DEFAULT_BACKGROUND_ICON_ALPHA = 0.6
const DEFAULT_FOREGROUND_ICON_ALPHA = 1.0
const HEX_BORDER_WIDTH = 5.0

func setup_biome_node(data: Dictionary, grid_tex: Texture2D, _is_cleared: bool, is_player_here: bool, is_revealed: bool, _is_reachable: bool):
	_resolve_ui_refs()
	_ensure_hex_mask_pipeline()
	node_data = data
	_is_hex_node = str(data.get("node_shape", "")) == "hex"
	_is_player_here = is_player_here
	_is_selected = false
	_is_revealed = is_revealed
	_is_background_node = str(data.get("type", "")) == "background" or not bool(data.get("passable", true))
	
	if grid_texture_rect:
		grid_texture_rect.texture = grid_tex
		grid_texture_rect.visible = not _is_hex_node and is_revealed

	if player_indicator:
		player_indicator.visible = is_player_here and not _is_hex_node

	if room_name_label:
		room_name_label.text = str(data.get("name", ""))
		room_name_label.visible = false
		room_name_label.modulate = Color(0.92, 0.92, 0.96, 0.92)
		if _is_hex_node:
			room_name_label.offset_top = size.y + 2.0
			room_name_label.offset_bottom = size.y + 28.0
	
	if is_revealed:
		visible = true
		var active_icon_rect := _get_active_icon_rect()
		if active_icon_rect:
			active_icon_rect.texture = _get_node_icon_texture(data)
			active_icon_rect.modulate = Color(1, 1, 1, _get_icon_alpha())
	else:
		var active_icon_rect := _get_active_icon_rect()
		if active_icon_rect:
			active_icon_rect.texture = null
			active_icon_rect.modulate = Color(1, 1, 1, 0)

	_apply_base_styles()
	_apply_icon_layout()
	_apply_icon_mask()
	_apply_visual_scale(float(data.get("node_visual_scale", 1.0)))
	call_deferred("_refresh_visual_transforms")
	set_highlight_state(is_player_here, false)

func _resolve_ui_refs():
	if icon_rect == null:
		icon_rect = get_node_or_null("%Icon")
	if grid_texture_rect == null:
		grid_texture_rect = get_node_or_null("%GridTexture")
	if player_indicator == null:
		player_indicator = get_node_or_null("%PlayerIcon")
	if fill == null:
		fill = get_node_or_null("%Fill")
	if border == null:
		border = get_node_or_null("%Border")
	if hex_fill == null:
		hex_fill = get_node_or_null("%HexFill")
	if hex_border == null:
		hex_border = get_node_or_null("%HexBorder")
	if room_name_label == null:
		room_name_label = get_node_or_null("%RoomNameLabel") as Label
	if not resized.is_connected(_refresh_visual_transforms):
		resized.connect(_refresh_visual_transforms)

func _ensure_hex_mask_pipeline():
	if _hex_viewport != null and is_instance_valid(_hex_viewport):
		return
	_hex_viewport = SubViewport.new()
	_hex_viewport.name = "HexViewport"
	_hex_viewport.transparent_bg = true
	_hex_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hex_viewport.disable_3d = true
	add_child(_hex_viewport)

	_hex_viewport_root = Control.new()
	_hex_viewport_root.name = "HexViewportRoot"
	_hex_viewport_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hex_viewport.add_child(_hex_viewport_root)

	_hex_viewport_icon = TextureRect.new()
	_hex_viewport_icon.name = "HexViewportIcon"
	_hex_viewport_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hex_viewport_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hex_viewport_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hex_viewport_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hex_viewport_root.add_child(_hex_viewport_icon)

	_hex_output_rect = TextureRect.new()
	_hex_output_rect.name = "HexOutput"
	_hex_output_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hex_output_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hex_output_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hex_output_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_hex_output_rect.texture = _hex_viewport.get_texture()
	add_child(_hex_output_rect)
	move_child(_hex_output_rect, icon_rect.get_index())

func _get_active_icon_rect() -> TextureRect:
	if _is_hex_node and _hex_viewport_icon != null:
		return _hex_viewport_icon
	return icon_rect

func set_highlight_state(is_player_here: bool, is_selected: bool):
	_is_player_here = is_player_here
	_is_selected = is_selected
	if _is_hex_node:
		_update_hex_visuals()
		return
	if not border or not fill:
		return
	_apply_base_styles()
	var border_style = border.get_theme_stylebox("panel") as StyleBoxFlat
	var fill_style = fill.get_theme_stylebox("panel") as StyleBoxFlat
	if not border_style or not fill_style:
		return

	var selected_color = Color(0.72, 0.92, 0.72, 0.92)
	var player_color = Color(0.42, 0.84, 0.45, 0.94)
	fill_style.bg_color = Color(0, 0, 0, 0)
	if is_selected:
		fill_style.bg_color = Color(selected_color.r, selected_color.g, selected_color.b, 0.78)
	if is_player_here:
		fill_style.bg_color = Color(player_color.r, player_color.g, player_color.b, 0.82)

	border_style.border_color = Color(0.58, 0.58, 0.62, 0.92)
	if is_selected:
		border_style.border_color = selected_color
	if is_player_here:
		border_style.border_color = player_color

func _apply_base_styles():
	if _is_hex_node:
		if icon_rect:
			icon_rect.visible = false
		if _hex_output_rect:
			_hex_output_rect.visible = true
		if border:
			border.visible = false
		if fill:
			fill.visible = false
		if hex_fill:
			hex_fill.visible = true
		if hex_border:
			hex_border.visible = true
		_update_hex_visuals()
		return
	if icon_rect:
		icon_rect.visible = true
	if _hex_output_rect:
		_hex_output_rect.visible = false
	if border:
		border.visible = true
		_ensure_style(border, false)
		var border_style = border.get_theme_stylebox("panel") as StyleBoxFlat
		if border_style:
			border_style.draw_center = false
			border_style.border_color = Color(0.58, 0.58, 0.62, 0.92)
	if fill:
		fill.visible = true
		_ensure_style(fill, true)
		var fill_style = fill.get_theme_stylebox("panel") as StyleBoxFlat
		if fill_style:
			fill_style.draw_center = true
			fill_style.bg_color = Color(0, 0, 0, 0)
			fill_style.border_width_left = 0
			fill_style.border_width_top = 0
			fill_style.border_width_right = 0
			fill_style.border_width_bottom = 0
	if hex_fill:
		hex_fill.visible = false
	if hex_border:
		hex_border.visible = false

func _apply_icon_layout():
	var active_icon_rect := _get_active_icon_rect()
	if not active_icon_rect:
		return
	if _is_hex_node:
		var inset_scale = 1.0 / HEX_ICON_SIZE_MULTIPLIER
		var horizontal_inset = HEX_ICON_BASE_HORIZONTAL_INSET * inset_scale
		var top_inset = HEX_ICON_BASE_TOP_INSET * inset_scale
		var bottom_inset = HEX_ICON_BASE_BOTTOM_INSET * inset_scale
		var offset = _get_icon_offset()
		active_icon_rect.offset_left = horizontal_inset + offset.x
		active_icon_rect.offset_top = top_inset + offset.y
		active_icon_rect.offset_right = -horizontal_inset + offset.x
		active_icon_rect.offset_bottom = -bottom_inset + offset.y
		active_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return
	var offset = _get_icon_offset()
	active_icon_rect.offset_left = 16.0 + offset.x
	active_icon_rect.offset_top = 16.0 + offset.y
	active_icon_rect.offset_right = -16.0 + offset.x
	active_icon_rect.offset_bottom = -16.0 + offset.y
	active_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _apply_icon_mask():
	if _is_hex_node:
		if _hex_icon_material == null:
			_hex_icon_material = ShaderMaterial.new()
			_hex_icon_material.shader = hex_mask_shader
		_update_hex_mask_params()
		if _hex_output_rect:
			_hex_output_rect.material = _hex_icon_material
		if icon_rect:
			icon_rect.material = null
		return
	if _hex_output_rect:
		_hex_output_rect.material = null
	if icon_rect:
		icon_rect.material = null

func _update_hex_mask_params():
	if _hex_icon_material == null:
		return
	var width = max(size.x, 1.0)
	var height = max(size.y, 1.0)
	_hex_icon_material.set_shader_parameter("pad_x", 1.0 / width)
	_hex_icon_material.set_shader_parameter("pad_y", 1.0 / height)
	if _hex_viewport:
		_hex_viewport.size = Vector2i(int(roundi(width)), int(roundi(height)))
	if _hex_viewport_root:
		_hex_viewport_root.size = Vector2(width, height)
	if _hex_output_rect:
		_hex_output_rect.size = Vector2(width, height)

func _apply_visual_scale(scale_factor: float):
	var clamped_scale = clamp(scale_factor, 0.8, 1.2)
	var visual_scale = Vector2.ONE * clamped_scale
	var active_icon_rect := _get_active_icon_rect()
	if active_icon_rect:
		active_icon_rect.pivot_offset = active_icon_rect.size * 0.5
		var icon_scale_x = float(node_data.get("icon_scale_x", DEFAULT_ICON_SCALE_X)) if node_data is Dictionary else DEFAULT_ICON_SCALE_X
		var icon_scale_y = float(node_data.get("icon_scale_y", DEFAULT_ICON_SCALE_Y)) if node_data is Dictionary else DEFAULT_ICON_SCALE_Y
		active_icon_rect.scale = Vector2(
			visual_scale.x * icon_scale_x,
			visual_scale.y * icon_scale_y
		)
	if border:
		border.pivot_offset = border.size * 0.5
		border.scale = visual_scale
	if fill:
		fill.pivot_offset = fill.size * 0.5
		fill.scale = visual_scale
	if grid_texture_rect:
		grid_texture_rect.pivot_offset = grid_texture_rect.size * 0.5
		grid_texture_rect.scale = visual_scale

func _ensure_style(panel: Panel, draw_center: bool):
	if not panel:
		return
	var existing = panel.get_theme_stylebox("panel")
	var style: StyleBoxFlat
	if existing is StyleBoxFlat:
		style = (existing as StyleBoxFlat).duplicate()
	else:
		style = StyleBoxFlat.new()
	style.draw_center = draw_center
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)

func _get_type_icon_texture(type: String) -> Texture2D:
	if not asset_library:
		return null
		
	# Dynamically map the room type string to the MapAssetData property names
	# e.g. "battle" -> "map_icon_battle"
	var property_name = "map_icon_" + type.to_lower()
	
	if property_name in asset_library:
		var tex = asset_library.get(property_name)
		if tex: return tex
	
	# Fallback to mystery icon if type is unknown or texture is null
	return asset_library.map_icon_mystery

func _get_node_icon_texture(data: Dictionary) -> Texture2D:
	var custom_icon_path = str(data.get("custom_icon_path", ""))
	if bool(data.get("force_custom_icon", false)) and custom_icon_path != "" and ResourceLoader.exists(custom_icon_path):
		var forced_icon = load(custom_icon_path) as Texture2D
		if forced_icon:
			return forced_icon

	if GameManager.is_battle_mode:
		if str(data.get("type", "")) == "home" or bool(data.get("is_home", false)):
			return _get_type_icon_texture("home")
		return _get_type_icon_texture(str(data.get("type", "mystery")))

	if custom_icon_path != "" and ResourceLoader.exists(custom_icon_path):
		var custom_icon = load(custom_icon_path) as Texture2D
		if custom_icon:
			return custom_icon

	if str(data.get("type", "")) == "home" or bool(data.get("is_home", false)):
		return _get_type_icon_texture("home")

	return _get_type_icon_texture(str(data.get("type", "mystery")))

func _get_icon_alpha() -> float:
	if not (node_data is Dictionary):
		return DEFAULT_FOREGROUND_ICON_ALPHA
	var fallback_alpha = DEFAULT_BACKGROUND_ICON_ALPHA if _is_background_node else DEFAULT_FOREGROUND_ICON_ALPHA
	return float(node_data.get("icon_alpha", fallback_alpha))

func _get_icon_offset() -> Vector2:
	if not (node_data is Dictionary):
		return Vector2.ZERO
	return Vector2(
		float(node_data.get("icon_offset_x", DEFAULT_ICON_OFFSET_X)),
		float(node_data.get("icon_offset_y", DEFAULT_ICON_OFFSET_Y))
	)

func _refresh_visual_transforms():
	if not is_inside_tree():
		return
	_apply_icon_layout()
	_update_hex_mask_params()
	_apply_visual_scale(float(node_data.get("node_visual_scale", 1.0)) if node_data is Dictionary else 1.0)
	_update_hex_visuals()

func _get_hex_points() -> PackedVector2Array:
	var pad = 1.0
	var left = pad
	var right = size.x - pad
	var top = pad
	var bottom = size.y - pad
	var mid_x = size.x * 0.5
	var upper_y = lerp(top, bottom, 0.25)
	var lower_y = lerp(top, bottom, 0.75)
	return PackedVector2Array([
		Vector2(mid_x, top),
		Vector2(right, upper_y),
		Vector2(right, lower_y),
		Vector2(mid_x, bottom),
		Vector2(left, lower_y),
		Vector2(left, upper_y)
	])

func _get_hex_fill_color() -> Color:
	if not _is_revealed:
		return HIDDEN_FILL_COLOR
	if _is_background_node:
		return BACKGROUND_FILL_COLOR
	if _is_player_here:
		return PLAYER_FILL_COLOR
	if _is_selected:
		return SELECTED_FILL_COLOR
	return HEX_CLEAR_FILL_COLOR

func _get_hex_border_color() -> Color:
	if _is_player_here:
		return PLAYER_BORDER_COLOR
	if _is_selected:
		return SELECTED_COLOR
	return DEFAULT_BORDER_COLOR

func _update_hex_visuals():
	if not _is_hex_node:
		return
	var points = _get_hex_points()
	if hex_fill:
		hex_fill.polygon = points
		hex_fill.color = _get_hex_fill_color()
	if hex_border:
		var border_points = points.duplicate()
		border_points.append(points[0])
		hex_border.points = border_points
		hex_border.default_color = _get_hex_border_color()
		hex_border.width = HEX_BORDER_WIDTH

func _on_button_pressed():
	if node_data:
		node_clicked.emit(node_data)

func _on_button_gui_input(event):
	if not node_data:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		node_double_clicked.emit(node_data)
