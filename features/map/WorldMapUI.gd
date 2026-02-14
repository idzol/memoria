extends Control

# res://features/map/WorldMapUI.gd
# Manages input, scrolling, and proximity-based Fog of War.

@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var map_content: Control = %MapContent
@onready var lines_layer: Node2D = %Lines
@onready var node_layer: Node2D = %Nodes
@onready var avatar_button: Button = %AvatarButton
@onready var discovery_overlay = %DiscoveryOverlay

var node_scene = preload("res://features/map/MapNode.tscn")
var in_game_menu_scene = preload("res://features/ui/InGameMenu.tscn")
var generator_script = preload("res://features/map/MapGenerator.gd")

var generator = null
var map_data = {}
var in_game_menu = null

# UI for Travel Confirmation
var travel_dialog: ConfirmationDialog

# Constants for centering logic
const VERTICAL_PADDING = 600.0

func _ready():
	# Initialize Dialogs
	_setup_dialogs()

	# Ensure GameManager is initialized if this is the start of a run
	if GameManager.player_grid_pos == Vector2i(-99, -99):
		GameManager.reset_to_home()
	
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


func _setup_dialogs():
	# Procedurally create and add the confirmation dialog
	travel_dialog = ConfirmationDialog.new()
	travel_dialog.title = "Travel?"
	travel_dialog.ok_button_text = "Proceed"
	travel_dialog.cancel_button_text = "Stay"
	add_child(travel_dialog)

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
			_get_difficulty_color(data.difficulty), # FIXED: Now uses local helper
			is_revealed,
			is_reachable,
			is_player_here
		)
	
	n.node_clicked.connect(_on_node_selected)

func _get_difficulty_color(diff: int) -> Color:
	# Difficulty colors: Green -> Yellow -> Gold -> Orange -> Red -> Purple (Boss)
	var colors = [
		Color.SEA_GREEN,    # 0
		Color.GREEN_YELLOW, # 1
		Color.GOLD,         # 2
		Color.DARK_ORANGE,  # 3
		Color.ORANGE_RED,   # 4
		Color.CRIMSON,      # 5
		Color.MEDIUM_PURPLE # 6
	]
	return colors[clampi(diff, 0, colors.size() - 1)]

func _try_move(dir: Vector2i):
	var target_coord = GameManager.player_grid_pos + dir
	for id in map_data:
		var n = map_data[id]
		if n.layer == target_coord.y and n.column == target_coord.x:
			_on_node_selected(n)
			return

func _on_node_selected(data: Dictionary):
	var player_pos = GameManager.player_grid_pos
	var is_here = (data.column == player_pos.x and data.layer == player_pos.y)
	var dist = abs(data.layer - player_pos.y) + abs(data.column - player_pos.x)

	if is_here:
		# 1. ACTION: DRILL IN (Transition to room)
		_enter_node_scene(data)
	elif dist == 1:
		# 2. ACTION: CONFIRM TRAVEL
		_prompt_travel(data)
	else:
		# Optional: Feedback for unreachable nodes
		pass


func _prompt_travel(data: Dictionary):

	# If setup_dialogs failed for any reason
	if not travel_dialog:
		_setup_dialogs()

	var room_name = data.get("name", "Unknown Location")
	travel_dialog.dialog_text = "Travel to the %s?" % room_name
	
	# Disconnect previous if any
	for connection in travel_dialog.confirmed.get_connections():
		travel_dialog.confirmed.disconnect(connection.callable)
		
	travel_dialog.confirmed.connect(func():
		GameManager.player_grid_pos = Vector2i(data.column, data.layer)
		SignalBus.node_selected.emit(data)
		_scroll_to_player()
		_generate_and_draw() # Refresh visuals to update player icon and reachable status
	)
	travel_dialog.popup_centered()

func _enter_node_scene(data: Dictionary):
	match data.get("type", "battle"):
		"battle": get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")
		"shop": get_tree().change_scene_to_file("res://features/encounters/ShopScene.tscn")
		"rest": get_tree().change_scene_to_file("res://features/encounters/RestScene.tscn")
		"lore": get_tree().change_scene_to_file("res://featuresscenes/encounters/LoreScene.tscn")
		"trap": get_tree().change_scene_to_file("res://features/encounters/TrapScene.tscn")
		_: get_tree().change_scene_to_file("res://features/encounters/EventScene.tscn")

func _scroll_to_player(is_first_load: bool = false):
	await get_tree().process_frame
	
	var player_y_pos = (GameManager.player_grid_pos.y) * -180 + 3600
	var target_scroll = int(player_y_pos)
	
	if is_first_load:
		var scroll_bar = scroll_container.get_v_scroll_bar()
		scroll_container.scroll_vertical = int(scroll_bar.max_value)
		await get_tree().create_timer(0.2).timeout
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(scroll_container, "scroll_vertical", target_scroll, 1.2)
	else:
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(scroll_container, "scroll_vertical", target_scroll, 0.6)

func _on_avatar_pressed():
	get_tree().change_scene_to_file("res://features/ui/CharacterScreen.tscn")
