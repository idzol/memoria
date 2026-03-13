extends Control

const GRANITE_TEXTURE_PATH = "res://assets/rooms/scene/the_core_red_rock_vault_room.png"

@onready var granite_rect = %GraniteRect
@onready var title_label = %TitleLabel
@onready var subtitle_label = %SubtitleLabel
@onready var preview_layer = %PreviewLayer
@onready var open_button = %OpenButton

const MAP_OFFSET = Vector2(36, 44)
const MAP_SPACING = Vector2(72, 60)

func _ready():
	var biome = GameManager.selected_story_biome
	title_label.text = "%s Map Summary" % biome.replace("_", " ").capitalize()
	subtitle_label.text = "Visited and cleared rooms are etched here. Select to enter the biome map."
	open_button.pressed.connect(_open_biome_map)
	if ResourceLoader.exists(GRANITE_TEXTURE_PATH):
		granite_rect.texture = load(GRANITE_TEXTURE_PATH)
		granite_rect.modulate = Color(0.8, 0.8, 0.84, 0.82)
	_redraw_preview()

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		_open_biome_map()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(GameManager.get_story_map_scene_path())
	elif event.is_action_pressed("ui_accept"):
		_open_biome_map()

func _redraw_preview():
	for child in preview_layer.get_children():
		child.queue_free()

	var biome = GameManager.selected_story_biome
	var nodes = GameManager.get_nodes_for_biome(biome)
	if nodes.is_empty():
		return

	var min_layer = 999999
	var max_layer = -999999
	var min_col = 999999
	var max_col = -999999
	for node in nodes:
		var layer = int(node.get("layer", 0))
		var col = int(node.get("column", 0))
		min_layer = min(min_layer, layer)
		max_layer = max(max_layer, layer)
		min_col = min(min_col, col)
		max_col = max(max_col, col)

	var positions: Dictionary = {}
	for node in nodes:
		var node_id = str(node.get("id", ""))
		var layer = int(node.get("layer", 0)) - min_layer
		var col = int(node.get("column", 0)) - min_col
		positions[node_id] = Vector2(layer * MAP_SPACING.x, col * MAP_SPACING.y) + MAP_OFFSET

	for node in nodes:
		var source_id = str(node.get("id", ""))
		var source_pos = positions.get(source_id, Vector2.ZERO)
		for raw_target in node.get("connections", []):
			var target_id = str(raw_target)
			if not positions.has(target_id):
				continue
			if source_id > target_id:
				continue
			var line = Line2D.new()
			line.width = 3.0
			line.default_color = Color(0.22, 0.22, 0.24, 0.7)
			line.add_point(source_pos)
			line.add_point(positions[target_id])
			preview_layer.add_child(line)

	for node in nodes:
		var node_id = str(node.get("id", ""))
		var marker = ColorRect.new()
		marker.size = Vector2(18, 18)
		marker.position = positions[node_id] - Vector2(9, 9)
		marker.color = _get_node_color(node)
		preview_layer.add_child(marker)

func _get_node_color(node: Dictionary) -> Color:
	var node_id = str(node.get("id", ""))
	var state = GameManager.world_state.rooms.get(node_id, {})
	if str(node.get("biome", "")) == GameManager.player_biome:
		if GameManager.is_battle_mode and GameManager.player_grid_pos == Vector2i(int(node.get("layer", -1)), int(node.get("column", -1))):
			return Color(0.45, 0.68, 1.0, 1.0)
		if not GameManager.is_battle_mode and GameManager.player_grid_pos == Vector2i(int(node.get("column", -1)), int(node.get("layer", -1))):
			return Color(0.45, 0.68, 1.0, 1.0)
	if state.get("cleared", false):
		return Color(0.35, 0.78, 0.41, 1.0)
	if state.get("visited", false):
		return Color(0.93, 0.78, 0.34, 1.0)
	if node_id == GameManager.get_biome_home_node_id(str(node.get("biome", ""))):
		return Color(0.45, 0.68, 1.0, 1.0)
	return Color(0.72, 0.72, 0.76, 0.9)

func _open_biome_map():
	var biome = GameManager.selected_story_biome
	GameManager.enter_story_biome(biome, true)
	get_tree().change_scene_to_file(GameManager.get_active_biome_map_scene_path())
