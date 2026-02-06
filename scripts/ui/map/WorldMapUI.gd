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
var in_game_menu_scene = preload("res://scenes/ui/InGameMenu.tscn")
var generator_script = preload("res://scripts/logic/MapGenerator.gd")

var generator = null
var map_data = {}
var in_game_menu = null

# Constants for centering logic
const VERTICAL_PADDING = 600.0

func _ready():
	# Ensure GameManager is initialized if this is the start of a run
	if GameManager.player_grid_pos == Vector2i.ZERO:
		# Start at the bottom (Home)
		GameManager.player_grid_pos = Vector2i(2, -1)
	
	generator = generator_script.new()
	add_child(generator)
	
	# Instance the In-Game Menu
	in_game_menu = in_game_menu_scene.instantiate()
	add_child(in_game_menu)

	# Add extra space to the map content to allow centering at extreme top/bottom
	if map_content:
		map_content.custom_minimum_size.y += (VERTICAL_PADDING * 2)
	
	_generate_and_draw()
	
	if avatar_button:
		avatar_button.pressed.connect(_on_avatar_pressed)
	
	# Trigger the "From Bottom to Player" animation on start
	_scroll_to_player(true)

func _input(event):
	# Allow movement via Arrow Keys
	if event.is_action_pressed("ui_up"): _try_move(Vector2i(0, 1))
	elif event.is_action_pressed("ui_down"): _try_move(Vector2i(0, -1))
	elif event.is_action_pressed("ui_left"): _try_move(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"): _try_move(Vector2i(1, 0))

	# Toggle In-Game Menu on Escape
	if event.is_action_pressed("ui_cancel"):
		if in_game_menu:
			if in_game_menu.visible:
				in_game_menu.close()
			else:
				in_game_menu.open()

func _generate_and_draw():
	for n in node_layer.get_children(): n.queue_free()
	for l in lines_layer.get_children(): l.queue_free()
	
	map_data = generator.generate_new_map()
	var player_pos = GameManager.player_grid_pos
	# Using GameManager's tracked room states
	var completed = GameManager.world_state.rooms
	
	# 1. Draw Lines (Connectivity)
	for id in map_data:
		var node = map_data[id]
		var is_visited = completed.has(id) and completed[id].get("cleared", false)
		is_visited = is_visited or (node.layer == player_pos.y and node.column == player_pos.x)
		
		if is_visited:
			for target_id in node.connections:
				if map_data.has(target_id):
					_draw_connection(node.pos, map_data[target_id].pos)
	
	# 2. Draw Nodes
	for id in map_data:
		_create_node_instance(map_data[id], player_pos, completed)

func _draw_connection(p1, p2):
	var line = Line2D.new()
	line.add_point(p1)
	line.add_point(p2)
	line.width = 4.0
	line.default_color = Color(0.4, 0.4, 0.45, 0.6) 
	lines_layer.add_child(line)

func _create_node_instance(data, player_pos: Vector2i, completed: Dictionary):
	var n = node_scene.instantiate()
	node_layer.add_child(n)
	n.position = data.pos
	
	var is_player_here = (data.layer == player_pos.y and data.column == player_pos.x)
	var dist = abs(data.layer - player_pos.y) + abs(data.column - player_pos.x)
	
	var is_revealed = (dist <= 1) or (completed.has(data.id) and completed[data.id].visited) or (data.type == "home")
	var is_reachable = (dist == 1)
	
	if n.has_method("setup_advanced"):
		n.setup_advanced(
			data, 
			generator.get_difficulty_color(data.difficulty),
			is_revealed,
			is_reachable,
			is_player_here
		)
	
	n.node_clicked.connect(func(): _on_node_selected(data))

func _try_move(dir: Vector2i):
	var target_coord = GameManager.player_grid_pos + dir
	for id in map_data:
		var n = map_data[id]
		if n.layer == target_coord.y and n.column == target_coord.x:
			_on_node_selected(n)
			return

func _on_node_selected(data):
	var dist = abs(data.layer - GameManager.player_grid_pos.y) + abs(data.column - GameManager.player_grid_pos.x)
	if dist == 1:
		GameManager.player_grid_pos = Vector2i(data.column, data.layer)
		SignalBus.node_selected.emit(data)
		
		match data.type:
			"battle": get_tree().change_scene_to_file("res://scenes/combat/BattleScene.tscn")
			"shop": get_tree().change_scene_to_file("res://scenes/encounters/ShopScene.tscn")
			"rest": get_tree().change_scene_to_file("res://scenes/encounters/RestScene.tscn")
			"lore": get_tree().change_scene_to_file("res://scenes/encounters/LoreScene.tscn") # New route
			"trap": get_tree().change_scene_to_file("res://scenes/encounters/TrapScene.tscn") # New route
			_: get_tree().change_scene_to_file("res://scenes/encounters/EventScene.tscn")
			
func _scroll_to_player(is_first_load: bool = false):
	# Wait for layout to finalize
	await get_tree().process_frame
	
	# Player position, accounting for view centre 
	var player_y_pos = (GameManager.player_grid_pos.y) * -180 + 3300
	# var view_center = scroll_container.size.y / 2
	var target_scroll = int(player_y_pos)
	
	if is_first_load:
		# 1. Force scroll to the very bottom immediately
		var scroll_bar = scroll_container.get_v_scroll_bar()
		scroll_container.scroll_vertical = int(scroll_bar.max_value)
		
		# 2. Wait a moment so the player sees the "Home" starting point
		await get_tree().create_timer(0.2).timeout
		
		# 3. Smoothly scroll UP to where the player actually is
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(scroll_container, "scroll_vertical", target_scroll, 1.2)
	else:
		# Normal movement scroll
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(scroll_container, "scroll_vertical", target_scroll, 0.6)

func _on_avatar_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/CharacterScreen.tscn")
