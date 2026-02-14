extends Control

# res://scripts/ui/MapNode.gd
# Handles individual map node visuals, using a centralized room database for assets and metadata.

signal node_clicked(data)

# IMPORT: Centralized room and enemy data from GameData.gd
const GameData = preload("res://scripts/data/GameData.gd")

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
			room_bg.texture = load("res://assets/maps/default.png")
	else:
		# Revealed but maybe not reachable (dimmed)
		modulate.a = 1.0 if (is_reachable or is_player_here) else 0.6
		if icon_rect: icon_rect.visible = true
		if border: border.self_modulate = diff_color
		
		# Fetch specific room data from the database
		var room_info = _get_room_info(data)
		_apply_room_visuals(data, room_info)

func _get_room_info(data: Dictionary) -> Dictionary:
	var biome = data.get("biome", "town")
	var r_key = data.get("room_key", "default")
	
	# Reference GameData.ROOMS organized by Biome -> Room ID
	if GameData.ROOMS.has(biome):
		if GameData.ROOMS[biome].has(r_key):
			return GameData.ROOMS[biome][r_key]
		return GameData.ROOMS[biome].get("default", {})
	
	return {}

func _apply_room_visuals(data: Dictionary, info: Dictionary):
	var biome = data.get("biome", "town")
	var r_key = data.get("room_key", "default")
	
	# --- DYNAMIC ASSET RESOLUTION ---
	# Priority 1: Naming Convention (biome_id_world.png)
	# Priority 2: Database Override (info.icon)
	# Priority 3: Type-based Fallback
	
	var convention_path = "res://assets/map/%s_%s_world.png" % [biome, r_key]
	
	if icon_rect:
		if ResourceLoader.exists(convention_path):
			icon_rect.texture = load(convention_path)
		elif info.has("icon") and ResourceLoader.exists(info.icon):
			icon_rect.texture = load(info.icon)
		else:
			# Absolute fallback based on room type
			icon_rect.texture = _get_fallback_icon(data.get("type", "battle"))
			
	# Apply Background (The "Mini-View" on the map node)
	var bg_convention = "res://assets/rooms/%s_%s_bg.png" % [biome, r_key]
	if room_bg:
		if ResourceLoader.exists(bg_convention):
			room_bg.texture = load(bg_convention)
		elif info.has("bg") and ResourceLoader.exists(info.bg):
			room_bg.texture = load(info.bg)
		else:
			room_bg.texture = load("res://assets/maps/default.png")

func _get_fallback_icon(type: String) -> Texture2D:
	match type:
		"home": return load("res://assets/maps/home.png")
		"battle": return load("res://assets/sword.png")
		"shop": return load("res://assets/key.png")
		"rest": return load("res://assets/heart.png")
		"event": return load("res://assets/scroll.png")
		"boss": return load("res://assets/skull.png")
	return load("res://assets/trap.png")

func _on_button_pressed():
	if node_data:
		node_clicked.emit(node_data)
