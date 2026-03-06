extends Control

# res://features/map/WorldMapUI.gd
# Integrated World Map: Manages biome isolation, asset loading, and interactive travel.
# Fixed: Restored connection lines and proximity-based discovery for avatar/icons.

@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var map_content: Control = %MapContent
@onready var lines_layer: Node2D = %Lines
@onready var node_layer: Node2D = %Nodes
@onready var background_rect: TextureRect = %MapBackground
@onready var avatar_button: Button = %AvatarButton

# Assets & Resources
var node_scene = preload("res://features/map/MapNode.tscn")
var in_game_menu_scene = preload("res://features/ui/InGameMenu.tscn")
var generator_script = preload("res://features/map/MapGenerator.gd")
var map_assets: MapAssetData = preload("res://data/map/map_data.tres")

# State
var map_data = {}
var current_biome = "town"
var in_game_menu = null
var travel_dialog: ConfirmationDialog

# Constants for centering logic
const VERTICAL_PADDING = 600.0


func _ready():
	_setup_ui_features()

	# If map doesn't exist (e.g. direct scene run), generate a temporary one
	if GameManager.run_map.is_empty():
		var gen = preload("res://features/map/MapGenerator.gd").new()
		GameManager.run_map = gen.generate_new_map()

	# Ensure GameManager is initialized if this is the start of a run
	if GameManager.player_grid_pos == Vector2i(-99, -99):
		GameManager.reset_to_home()

	# Add extra space to the map content to allow centering at extreme top/bottom
	if map_content:
		map_content.custom_minimum_size.y += (VERTICAL_PADDING * 2)
	
	# Instance the In-Game Menu
	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()

	# Initial biome load (defaulting to town)
	load_biome_map("town")
	
	# Music 
	SignalBus.music_change_requested.emit(AudioData.TRACKS["TOWN"], 1.0)

	# Snap/Scroll to player position
	_scroll_to_player.call_deferred(true)
	

func _setup_ui_features():
	# Setup Travel Confirmation Dialog
	travel_dialog = ConfirmationDialog.new()
	travel_dialog.title = "Travel?"
	travel_dialog.ok_button_text = "Proceed"
	travel_dialog.cancel_button_text = "Stay"
	add_child(travel_dialog)
	
	# Avatar Button
	if avatar_button:
		avatar_button.pressed.connect(_on_avatar_pressed)

func _input(event):
	# Allow movement via Arrow Keys
	if event.is_action_pressed("ui_up"): _try_move(Vector2i(0, 1))
	elif event.is_action_pressed("ui_down"): _try_move(Vector2i(0, -1))
	elif event.is_action_pressed("ui_left"): _try_move(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"): _try_move(Vector2i(1, 0))

	# Toggle In-Game Menu on Escape
	if event.is_action_pressed("ui_cancel"):
		if in_game_menu:
			if in_game_menu.visible: in_game_menu.close()
			else: in_game_menu.open()

func _try_move(dir: Vector2i):
	var target_coord = GameManager.player_grid_pos + dir
	for id in map_data:
		var n = map_data[id]
		if n.layer == target_coord.y and n.column == target_coord.x:
			_on_node_selected(n)
			return

# --- BIOME & MAP GENERATION ---

func load_biome_map(biome_id: String):
	current_biome = biome_id
	_apply_biome_visuals(biome_id)
	_draw_map(biome_id)

func _apply_biome_visuals(biome: String):
	if not map_assets: return
	
	# Load Background for the whole map view from Resource
	var bg_prop = "map_%s_background" % biome
	if bg_prop in map_assets:
		background_rect.texture = map_assets.get(bg_prop)


func _draw_map(biome: String):
	# Clean up previous render
	for n in node_layer.get_children(): n.queue_free()
	for l in lines_layer.get_children(): l.queue_free()

	# Use cached map, player position, world state
	map_data = GameManager.run_map
	var player_pos = GameManager.player_grid_pos
	var completed = GameManager.world_state.rooms
	
	# 1. Draw Lines (Connectivity) - Only for the current biome
	for id in map_data:
		var node = map_data[id]
		if node.biome != biome: continue
		
		# Show lines if the player has visited the node or is currently there
		var is_visited = completed.has(id) and completed[id].cleared
		is_visited = is_visited or (node.layer == player_pos.y and node.column == player_pos.x)
		
		if is_visited:
			for target_id in node.connections:
				if map_data.has(target_id) and map_data[target_id].biome == biome:
					_draw_connection(node.pos, map_data[target_id].pos)
	
	# 2. Instance Nodes
	for id in map_data:
		var data = map_data[id]
		# Isolation Logic: Only show nodes belonging to the requested biome
		if data.biome == biome:
			_create_node_instance(data, player_pos, completed)

func _draw_connection(p1, p2):
	var line = Line2D.new()
	line.add_point(p1)
	line.add_point(p2)
	line.width = 4.0
	line.default_color = Color(0.4, 0.4, 0.45, 0.4) 
	lines_layer.add_child(line)

func _create_node_instance(data: Dictionary, player_pos: Vector2i, completed: Dictionary):
	var n = node_scene.instantiate()
	node_layer.add_child(n)
	n.position = data.pos
	
	var is_player_here = (data.layer == player_pos.y and data.column == player_pos.x)
	var dist = abs(data.layer - player_pos.y) + abs(data.column - player_pos.x)
	
	# Discovery Logic: Reveal if adjacent, previously visited, or starting area
	var is_revealed = (dist <= 1) or (completed.has(data.id) and completed[data.id].visited) or (data.type == "home")
	var is_reachable = (dist == 1)
	var is_cleared = completed.has(data.id) and completed[data.id].cleared
	
	# Find biome grid texture from MapAssetData
	var grid_tex = null
	var grid_prop = "map_%s_grid" % current_biome
	if map_assets and grid_prop in map_assets:
		grid_tex = map_assets.get(grid_prop)
	
	# Setup the node (Handles discovery vs generic icon logic)
	if n.has_method("setup_biome_node"):
		# Updated to include full revealed/reachable state for correct icon and avatar display
		n.setup_biome_node(data, grid_tex, is_cleared, is_player_here, is_revealed, is_reachable)
	
	n.node_clicked.connect(_on_node_selected)

# --- NAVIGATION & INTERACTION ---

func _on_node_selected(data: Dictionary):
	var player_pos = GameManager.player_grid_pos
	var is_here = (data.column == player_pos.x and data.layer == player_pos.y)
	var dist = abs(data.layer - player_pos.y) + abs(data.column - player_pos.x)

	if is_here:
		_enter_node_scene(data)
	elif dist == 1:
		_prompt_travel(data)

func _prompt_travel(data: Dictionary):
	var room_name = data.get("name", "Unknown Location")
	travel_dialog.dialog_text = "Travel to the %s?" % room_name
	
	for connection in travel_dialog.confirmed.get_connections():
		travel_dialog.confirmed.disconnect(connection.callable)
		
	travel_dialog.confirmed.connect(func():
		GameManager.player_grid_pos = Vector2i(data.column, data.layer)
		
		if not GameManager.world_state.rooms.has(data.id):
			GameManager.world_state.rooms[data.id] = {"visited": true, "cleared": false}
		
		_draw_map(current_biome)
		_scroll_to_player()
		_enter_node_scene(data)
	)
	travel_dialog.popup_centered()

func _enter_node_scene(data: Dictionary):
	if not is_inside_tree(): return

	var room_res = load(data.room_resource_path) as RoomData
	if not room_res: return

	GameManager.current_node = data
	SignalBus.node_selected.emit(data)
	
	if room_res.enemy_id != "" or room_res.type == "battle":
		get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")
	elif room_res.npc_id != "" or room_res.type == "event":
		get_tree().change_scene_to_file("res://features/encounters/EventScene.tscn")
	elif room_res.type == "shop":
		get_tree().change_scene_to_file("res://features/encounters/ShopScene.tscn")
	elif room_res.type == "rest":
		get_tree().change_scene_to_file("res://features/encounters/RestScene.tscn")
	else:
		get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")

func _scroll_to_player(is_first_load: bool = false):
	if not is_inside_tree(): return
	await get_tree().process_frame
	
	var player_y_pos = (GameManager.player_grid_pos.y) * -180 + 3400
	var target_scroll = int(player_y_pos)
	
	if is_first_load:
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
		await get_tree().create_timer(0.2).timeout
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(scroll_container, "scroll_vertical", target_scroll, 1.2)
	else:
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(scroll_container, "scroll_vertical", target_scroll, 0.6)

func _on_avatar_pressed():
	get_tree().change_scene_to_file("res://features/ui/CharacterScreen.tscn")
