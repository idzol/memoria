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
		_set_background("mystery")
		border.self_modulate = Color.GRAY
	else:
		# Revealed but maybe not reachable (dimmed)
		modulate.a = 1.0 if (is_reachable or is_player_here) else 0.6
		icon_rect.visible = true
		border.self_modulate = diff_color
		
		# Set assets
		_set_node_icon(data.type)
		_set_background(data.type)

func _set_node_icon(type: String):
	var path = ICON_MAP.get(type, "res://assets/trap.png")
	if ResourceLoader.exists(path):
		icon_rect.texture = load(path)
	else:
		icon_rect.texture = load("res://assets/trap.png")

func _set_background(type: String):
	# Look for background in res://assets/rooms/
	# Format: res://assets/rooms/[type].png
	var bg_path = "res://assets/rooms/" + type + ".png"
	
	# If specific background doesn't exist, try area backgrounds (ice, sand, etc) 
	# if provided in node_data, or fall back to default
	if !ResourceLoader.exists(bg_path):
		bg_path = "res://assets/wall.png" # The default fallback
		
	room_bg.texture = load(bg_path)

func _on_button_pressed():
	if node_data:
		node_clicked.emit(node_data)