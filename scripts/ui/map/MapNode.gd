extends Control

# res://scripts/ui/MapNode.gd
# Handles individual map node visuals, including dynamic backgrounds and icons.

signal node_clicked(data)

@onready var room_bg = %RoomBackground
@onready var icon_rect = %Icon
@onready var border = %Border
@onready var player_icon = %PlayerIcon
@onready var button = $Button

var node_data = null

# Map node types to their specific asset paths
const ICON_MAP = {
	"home": "res://assets/maps/home.png",
	"battle": "res://assets/sword.png",
	"shop": "res://assets/key.png",
	"rest": "res://assets/heart.png",
	"event": "res://assets/scroll.png",
	"boss": "res://assets/skull.png"
}

# Map node types: alternate method  
func _get_type_icon(type: String) -> String:
	match type:
		"home": return "🏡"
		"battle": return "⚔️"
		"shop": return "💰"
		"rest": return "🔥"
		"event": return "❓"
		"boss": return "💀"
		"lore": return "📜"
		"trap": return "🕸️"
		_: return "•"

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
		icon_rect.visible = false
		border.self_modulate = Color.GRAY
		if room_bg:
			room_bg.texture = load("res://assets/wall.png")
		
	else:
		# Revealed but maybe not reachable (dimmed)
		modulate.a = 1.0 if (is_reachable or is_player_here) else 0.6
		icon_rect.visible = true
		border.self_modulate = diff_color
		# icon_label.text = _get_type_icon(data.get("type", "battle"))

		# Set assets
		_set_node_icon(data.type)

		# ASSET ASSIGNMENT LOGIC:
		# Looks for res://assets/rooms/{biome}_{room_key}.png
		# Example: res://assets/rooms/town_t1.png
		_update_background_texture(data)

func _set_node_icon(type: String):
	var path = ICON_MAP.get(type, "res://assets/trap.png")
	if ResourceLoader.exists(path):
		icon_rect.texture = load(path)
	else:
		icon_rect.texture = load("res://assets/trap.png")

func _update_background_texture(data):

	if not room_bg: return
	
	var biome = data.get("biome", "forest")
	var r_key = data.get("room_key", "default")
	var path = "res://assets/rooms/%s_%s.png" % [biome, r_key]
	
	if ResourceLoader.exists(path):
		room_bg.texture = load(path)
	else:
		# Fallback to a generic biome wall or default wall
		var fallback = "res://assets/wall.png"
		room_bg.texture = load(fallback)

func _on_button_pressed():
	if node_data:
		node_clicked.emit(node_data)