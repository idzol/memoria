extends Control

# res://features/map/MapNode.gd
# Handles individual map node visuals, using a centralized room database for assets and metadata.

signal node_clicked(data)

@onready var room_bg = %RoomBackground
@onready var icon_rect = %Icon
@onready var border = %Border
@onready var player_icon = %PlayerIcon
@onready var button = $Button

var node_data = null

func setup_advanced(data, diff_color: Color, is_revealed: bool, is_reachable: bool, is_player_here: bool):
	node_data = data
	
	# 1. Update Player indicator
	if player_icon:
		player_icon.visible = is_player_here
	
	# 2. Update Button interaction
	if button:
		button.disabled = not (is_reachable or is_player_here)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if !button.disabled else Control.CURSOR_ARROW

	# 3. Handle Visibility and Fog of War
	if !is_revealed:
		modulate.a = 0.2
		if icon_rect: icon_rect.visible = false
		if border: border.self_modulate = Color.GRAY
		if room_bg:
			# Fallback for hidden rooms
			room_bg.texture = load("res://assets/maps/default.png")
	else:
		modulate.a = 1.0 if (is_reachable or is_player_here) else 0.6
		if icon_rect: icon_rect.visible = true
		if border: border.self_modulate = diff_color
		
		# 4. LOAD RESOURCE DATA
		# Attempt to load the resource path provided by the MapGenerator
		var res_path = data.get("room_resource_path", "")
		var room_res: RoomData = null
		if res_path != "" and ResourceLoader.exists(res_path):
			room_res = load(res_path) as RoomData
		
		_apply_room_visuals(data, room_res)

func _apply_room_visuals(data: Dictionary, res: RoomData):
	# Priority 1: Direct Resource properties (Hand-crafted art)
	# Priority 2: Biome-based naming conventions (Legacy Support)
	# Priority 3: Type-based Fallbacks (Engine icons)
	
	var biome = data.get("biome", "town")
	var r_key = data.get("room_key", "default")
	
	# Handle Icon (The map marker)
	if icon_rect:
		if res and res.map_icon:
			icon_rect.texture = res.map_icon
		else:
			# Try naming convention fallback
			var convention_path = "res://assets/maps/%s_%s_world.png" % [biome, r_key]
			if ResourceLoader.exists(convention_path):
				icon_rect.texture = load(convention_path)
			else:
				# Absolute fallback based on room type string
				icon_rect.texture = _get_fallback_icon(data.get("type", "battle"))
			
	# Handle Background (The "Mini-View" inside the map node)
	if room_bg:
		if res and res.background_texture:
			room_bg.texture = res.background_texture
		else:
			# Try background naming convention
			var bg_convention = "res://assets/rooms/%s_%s_bg.png" % [biome, r_key]
			if ResourceLoader.exists(bg_convention):
				room_bg.texture = load(bg_convention)
			else:
				room_bg.texture = load("res://assets/maps/default.png")


func _get_fallback_icon(type: String) -> Texture2D:
	match type:
		"home": return load("res://assets/maps/home.png")
		"battle": return load("res://assets/sword.png")
		"shop": return load("res://assets/key.png")
		"rest": return load("res://assets/heart.png")
		"event": return load("res://assets/scroll.png")
		"lore": return load("res://assets/scroll.png")
		"trap": return load("res://assets/trap.png")
		"boss": return load("res://assets/skull.png")
	return load("res://assets/trap.png")

func _on_button_pressed():
	if node_data:
		node_clicked.emit(node_data)
