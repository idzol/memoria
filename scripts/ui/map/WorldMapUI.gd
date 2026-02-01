extends Control

# res://scripts/ui/map/WorldMapUI.gd
# Manages input, scrolling, and proximity-based Fog of War.

@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var map_content: Control = %MapContent
@onready var lines_layer: Node2D = %Lines
@onready var node_layer: Node2D = %Nodes
@onready var avatar_button: Button = %AvatarButton
@onready var discovery_overlay = %DiscoveryOverlay

var node_scene = preload("res://scenes/map/MapNode.tscn")
var generator_script = preload("res://scripts/logic/MapGenerator.gd")
var generator = null
var map_data = {}

func _ready():
	# Ensure GameManager is initialized if this is the start of a run
	if GameManager.player_grid_pos == Vector2i.ZERO:
		GameManager.player_grid_pos = Vector2i(2, -1)
	
	generator = generator_script.new()
	add_child(generator)
	
	_generate_and_draw()
	
	if avatar_button:
		avatar_button.pressed.connect(_on_avatar_pressed)
	
	await get_tree().process_frame
	_scroll_to_player()

func _input(event):
	# Allow movement via Arrow Keys
	if event.is_action_pressed("ui_up"): _try_move(Vector2i(0, 1))
	elif event.is_action_pressed("ui_down"): _try_move(Vector2i(0, -1))
	elif event.is_action_pressed("ui_left"): _try_move(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"): _try_move(Vector2i(1, 0))

func _generate_and_draw():
	# Clear previous instances
	for n in node_layer.get_children(): n.queue_free()
	for l in lines_layer.get_children(): l.queue_free()
	
	map_data = generator.generate_new_map()
	var player_pos = GameManager.player_grid_pos
	var completed = GameManager.completed_nodes
	
	# 1. Draw Lines (Connectivity)
	for id in map_data:
		var node = map_data[id]
		# Connections are revealed if the node is visited or the player is currently there
		var is_visited = (id in completed) or (node.layer == player_pos.y and node.column == player_pos.x)
		if is_visited:
			for target_id in node.connections:
				if map_data.has(target_id):
					_draw_connection(node.pos, map_data[target_id].pos)
	
	# 2. Draw Nodes with Fog of War Logic
	for id in map_data:
		var node_data = map_data[id]
		_create_node_instance(node_data, player_pos, completed)

func _draw_connection(p1, p2):
	var line = Line2D.new()
	line.add_point(p1)
	line.add_point(p2)
	line.width = 4.0
	line.default_color = Color(0.4, 0.4, 0.45, 0.6) 
	lines_layer.add_child(line)

func _create_node_instance(data, player_pos: Vector2i, completed: Array):
	var n = node_scene.instantiate()
	node_layer.add_child(n)
	n.position = data.pos
	
	# Logical proximity (Manhattan distance)
	var is_player_here = (data.layer == player_pos.y and data.column == player_pos.x)
	var dist = abs(data.layer - player_pos.y) + abs(data.column - player_pos.x)
	
	# Fog of War Logic
	# Reveal = You are on it, you've beaten it, or it's next to you.
	var is_revealed = (dist <= 1) or (data.id in completed) or (data.type == "home")
	# Reachable = Distance of exactly 1 from player
	var is_reachable = (dist == 1)
	
	if n.has_method("setup_advanced"):
		n.setup_advanced(
			data, 
			generator.get_difficulty_color(data.difficulty),
			is_revealed,
			is_reachable,
			is_player_here
		)
	
	# Use a lambda to pass the data directly to the callback
	n.node_clicked.connect(func(): _on_node_selected(data))

func _try_move(dir: Vector2i):
	var target_coord = GameManager.player_grid_pos + dir
	# Find node at target coordinate using our data dictionary
	for id in map_data:
		var n_data = map_data[id] 
		if n_data.layer == target_coord.y and n_data.column == target_coord.x:
			_on_node_selected(n_data) 
			return

func _on_node_selected(data):
	if data == null: return
	
	# Movement logic check (Manhattan distance)
	var dist = abs(data.layer - GameManager.player_grid_pos.y) + abs(data.column - GameManager.player_grid_pos.x)
	
	if dist == 1:
		# 1. Update Global State
		GameManager.player_grid_pos = Vector2i(data.column, data.layer)
		
		# 2. Emit signal for saving/persistence
		SignalBus.node_selected.emit(data)
		
		# 3. Handle Scene Transitions based on node type
		match data.type:
			"battle":
				get_tree().change_scene_to_file("res://scenes/combat/BattleScene.tscn")
			"event":
				get_tree().change_scene_to_file("res://scenes/encounters/EventScene.tscn")
			"shop":
				get_tree().change_scene_to_file("res://scenes/encounters/ShopScene.tscn")
			"rest":
				get_tree().change_scene_to_file("res://scenes/encounters/RestScene.tscn")
			_:
				# For "home" or "town", just refresh the UI to show the new position
				_generate_and_draw()
	elif dist == 0:
		# Already on this node
		pass

func _scroll_to_player():
	var player_y_pos = GameManager.player_grid_pos.y * -180 + 3300 
	var view_center = scroll_container.size.y / 2
	scroll_container.scroll_vertical = int(player_y_pos - view_center)

func _on_avatar_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/CharacterScreen.tscn")