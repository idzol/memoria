extends Control

# res://features/map/BattleMapUI.gd
# Linear map display with progressive shadow for "rooms to the left" (past layers).

@onready var node_container = %NodeContainer
@onready var lines_container = %LinesContainer
@onready var biome_label = %BiomeLabel
@onready var phase_label = %PhaseLabel
@onready var tracker_text = %TrackerText

var node_scene = preload("res://features/map/MapNode.tscn")
var travel_dialog: ConfirmationDialog

func _ready():
	_setup_ui()
	_draw_map()

func _setup_ui():
	travel_dialog = ConfirmationDialog.new()
	travel_dialog.ok_button_text = "Venture Forward"
	add_child(travel_dialog)

func _draw_map():
	# Clear previous instances
	for n in node_container.get_children(): n.queue_free()
	for l in lines_container.get_children(): l.queue_free()
	
	var map = GameManager.run_map
	var p_pos = GameManager.player_grid_pos # x = layer
	
	# Update Top Info Bar
	# Layer 0 to 9 = Biome 1, Layer 10 to 19 = Biome 2...
	var current_layer = max(0, p_pos.x)
	var biome_num = floor(current_layer / 10.0) + 1
	var phase_num = (current_layer % 10) + 1
	
	tracker_text.text = "%d - %d" % [biome_num, phase_num]
	biome_label.text = "BIOME %d" % biome_num
	phase_label.text = "PHASE %d" % phase_num
	
	for id in map:
		var data = map[id]
		var layer_diff = p_pos.x - data.layer
		
		# OPTIMIZATION: Only instance rooms within visible range
		if layer_diff > 4 or layer_diff < -2: continue
		
		var node_ui = node_scene.instantiate()
		node_container.add_child(node_ui)
		
		# Layout: Vertical (Forward is Up) or Horizontal (Forward is Right)
		# Setting horizontal for "Rooms to the left" shadow logic
		node_ui.position = Vector2(data.layer * 280 + 200, data.column * 200 + 300)
		
		var is_player_here = (data.layer == p_pos.x and data.column == p_pos.y)
		var is_reachable = (data.layer == p_pos.x + 1)
		var is_cleared = GameManager.world_state.rooms.has(id) and GameManager.world_state.rooms[id].cleared
		
		node_ui.setup_biome_node(data, null, is_cleared, is_player_here, true, is_reachable)
		
		# --- PROGRESSIVE SHADOW LOGIC ---
		if layer_diff == 1:
			node_ui.modulate = Color(0.67, 0.67, 0.67, 1.0) # 33% Shadow
		elif layer_diff == 2:
			node_ui.modulate = Color(0.34, 0.34, 0.34, 1.0) # 66% Shadow
		elif layer_diff >= 3:
			node_ui.modulate = Color(0, 0, 0, 1.0) # 100% Shadow
		
		if not is_player_here and not is_reachable and not is_cleared:
			# Fog of War for future rooms
			if data.layer > p_pos.x + 1:
				node_ui.modulate.a = 0.1
		
		node_ui.node_clicked.connect(_on_node_clicked)
		
		# Lines to next rooms
		for target_id in data.connections:
			if map.has(target_id):
				var target = map[target_id]
				_draw_line(node_ui.position, Vector2(target.layer * 280 + 200, target.column * 200 + 300), layer_diff)

func _draw_line(p1, p2, layer_diff):
	var line = Line2D.new()
	line.add_point(p1); line.add_point(p2)
	line.width = 2.0
	line.default_color = Color(1, 1, 1, 0.15)
	
	if layer_diff >= 2: line.default_color.a = 0.0 # Hide lines to blacked out rooms
	lines_container.add_child(line)

func _on_node_clicked(data: Dictionary):
	var p_pos = GameManager.player_grid_pos
	
	# Current Room re-entry
	if data.layer == p_pos.x and data.column == p_pos.y:
		_enter_room(data)
		return
		
	# Move Forward only
	if data.layer != p_pos.x + 1:
		return

	travel_dialog.dialog_text = "Enter %s (%d-%d)?" % [data.name, floor(data.layer/10.0)+1, (data.layer%10)+1]
	for c in travel_dialog.confirmed.get_connections(): travel_dialog.confirmed.disconnect(c.callable)
	travel_dialog.confirmed.connect(func():
		GameManager.player_grid_pos = Vector2i(data.layer, data.column)
		_draw_map()
		_enter_room(data)
	); travel_dialog.popup_centered()

func _enter_room(data: Dictionary):
	GameManager.current_node = data
	match data.type:
		"battle": get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")
		"treasure": get_tree().change_scene_to_file("res://features/encounters/TreasureScene.tscn")
		"rest": get_tree().change_scene_to_file("res://features/encounters/RestScene.tscn")
		"event": get_tree().change_scene_to_file("res://features/encounters/EventScene.tscn")
