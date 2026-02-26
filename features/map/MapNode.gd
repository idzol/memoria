extends Control

# res://features/map/MapNode.gd
# Handles the dual-state visuals (undiscovered vs discovered) for map nodes.
# Updated: Uses MapAssetData resource for icon lookups.

signal node_clicked(data)

# Preload types and the specific asset library instance
# const MapAssetData = preload("res://data/resources/MapAssetData.gd")
var asset_library: MapAssetData = preload("res://data/map/map_data.tres")

@onready var icon_rect = %Icon
@onready var grid_texture_rect = %GridTexture
@onready var player_indicator = %PlayerIcon
@onready var border = %Border

var node_data = null

func setup_biome_node(data: Dictionary, grid_tex: Texture2D, is_cleared: bool, is_player_here: bool, is_revealed: bool, is_reachable: bool):
	node_data = data
	
	# 1. Update Grid Background (Always visible if revealed)
	if grid_texture_rect:
		grid_texture_rect.texture = grid_tex
	
	# 2. Update Player Avatar
	if player_indicator:
		player_indicator.visible = is_player_here
	
	# 3. Icon Logic
	if is_revealed:
		visible = true
		if is_cleared:
			# Show specific hand-crafted icon from the Room Resource metadata
			if data.get("custom_icon_path", "") != "":
				icon_rect.texture = load(data.custom_icon_path)
			else:
				icon_rect.texture = _get_type_icon_texture(data.type)
			modulate = Color.WHITE
		else:
			# Revealed but not cleared: Show generic type icon (Sword, Scroll, etc.)
			icon_rect.texture = _get_type_icon_texture(data.type)
			modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		# Fog of War: If not revealed, node is semi-transparent or hidden
		icon_rect.texture = null
		modulate = Color(1, 1, 1, 0.1)

	# 4. Border Polish
	if border:
		if is_player_here:
			border.modulate = Color.CYAN
		elif is_reachable:
			border.modulate = Color.WHITE
		else:
			border.modulate = Color(1, 1, 1, 0.2)

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

func _on_button_pressed():
	if node_data:
		node_clicked.emit(node_data)
