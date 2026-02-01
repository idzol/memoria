extends Control

# res://scripts/ui/MapNode.gd

signal node_clicked(data)

@onready var button = $Button
@onready var icon_label = $Button/Icon
@onready var border = $Border
@onready var player_icon = %PlayerIcon # NEW unique name

var node_data = null

func setup_map_state(data, diff_color: Color, is_player: bool, is_revealed: bool, is_reachable: bool):
	node_data = data
	
	if player_icon:
		player_icon.visible = is_player
	
	if is_revealed:
		visible = true
		modulate.a = 1.0 if (is_reachable or is_player) else 0.5
		icon_label.text = _get_type_icon(data.type)
		border.modulate = diff_color
	else:
		# Fog of War: Hidden or mysterious
		visible = true
		modulate.a = 0.2
		icon_label.text = "?"
		border.modulate = Color.GRAY

	if button:
		button.disabled = not is_reachable

func _get_type_icon(type: String) -> String:
	match type:
		"home": return "🏡"
		"battle": return "⚔️"
		"shop": return "💰"
		"rest": return "🔥"
		"event": return "❓"
		"boss": return "💀"
		_: return "•"

func _on_button_pressed():
	if node_data:
		node_clicked.emit(node_data)
