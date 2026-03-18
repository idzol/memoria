extends Control

# res://features/map/MapNode.gd
# Handles the dual-state visuals (undiscovered vs discovered) for map nodes.
# Updated: Uses MapAssetData resource for icon lookups.

signal node_clicked(data)
signal node_double_clicked(data)

# Preload types and the specific asset library instance
# const MapAssetData = preload("res://data/resources/MapAssetData.gd")
var asset_library: MapAssetData = preload("res://data/map/map_data.tres")

@onready var icon_rect = %Icon
@onready var grid_texture_rect = %GridTexture
@onready var player_indicator = %PlayerIcon
@onready var fill = %Fill
@onready var border = %Border
@onready var room_name_label: Label = %RoomNameLabel

var node_data = null

func setup_biome_node(data: Dictionary, grid_tex: Texture2D, _is_cleared: bool, is_player_here: bool, is_revealed: bool, _is_reachable: bool):
	node_data = data
	
	# 1. Update Grid Background (Always visible if revealed)
	if grid_texture_rect:
		grid_texture_rect.texture = grid_tex
	
	# 2. Update Player Avatar
	if player_indicator:
		player_indicator.visible = is_player_here

	if room_name_label:
		room_name_label.text = str(data.get("name", ""))
		room_name_label.visible = is_revealed and room_name_label.text != ""
		room_name_label.modulate = Color(0.92, 0.92, 0.96, 0.92)
	
	# 3. Icon Logic
	if is_revealed:
		visible = true
		icon_rect.texture = _get_node_icon_texture(data)
		icon_rect.modulate = Color.WHITE
	else:
		# Hidden rooms still keep their outline, but suppress iconography until adjacent.
		icon_rect.texture = null
		icon_rect.modulate = Color(1, 1, 1, 0)

	_apply_base_styles()
	_apply_visual_scale(float(data.get("node_visual_scale", 1.0)))
	set_highlight_state(is_player_here, false)

func set_highlight_state(is_player_here: bool, is_selected: bool):
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

func _apply_visual_scale(scale_factor: float):
	var clamped_scale = clamp(scale_factor, 0.8, 1.2)
	var visual_scale = Vector2.ONE * clamped_scale
	if icon_rect:
		icon_rect.pivot_offset = icon_rect.size * 0.5
		icon_rect.scale = visual_scale
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
	if GameManager.is_battle_mode:
		if str(data.get("type", "")) == "home" or bool(data.get("is_home", false)):
			return _get_type_icon_texture("home")
		return _get_type_icon_texture(str(data.get("type", "mystery")))

	var custom_icon_path = str(data.get("custom_icon_path", ""))
	if custom_icon_path != "" and ResourceLoader.exists(custom_icon_path):
		var custom_icon = load(custom_icon_path) as Texture2D
		if custom_icon:
			return custom_icon

	if str(data.get("type", "")) == "home" or bool(data.get("is_home", false)):
		return _get_type_icon_texture("home")

	return _get_type_icon_texture(str(data.get("type", "mystery")))

func _on_button_pressed():
	if node_data:
		node_clicked.emit(node_data)

func _on_button_gui_input(event):
	if not node_data:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		node_double_clicked.emit(node_data)
