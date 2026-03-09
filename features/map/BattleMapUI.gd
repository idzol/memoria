extends Control

# res://features/map/BattleMapUI.gd
# Linear map display for Battle Mode.
# Updated: Hand-drawn centered connection lines and visibility culling.

@onready var node_container = %NodeContainer
@onready var lines_container = %LinesContainer
@onready var biome_label = %BiomeLabel
@onready var phase_label = %PhaseLabel
@onready var tracker_text = %TrackerText
@onready var scroll_area = %MapArea
@onready var avatar_button = %AvatarButton
@onready var exit_button = %ExitBtn

# Assets & Resources
var node_scene = preload("res://features/map/MapNode.tscn")
var in_game_menu_scene = preload("res://features/ui/InGameMenu.tscn")

# Dialogs
var travel_dialog: ConfirmationDialog
var exit_confirmation: ConfirmationDialog

# State
var in_game_menu = null

# Node dimensions from MapNode.tscn to calculate center
const NODE_HALF_SIZE = Vector2(90, 90)

func _ready():
	_setup_ui()

	# If map doesn't exist (e.g. direct scene run), generate a temporary one
	if GameManager.run_map.is_empty():
		var gen = preload("res://features/map/BattleMapGenerator.gd").new()
		GameManager.run_map = gen.generate_new_map()

	_draw_map()

	# Instance the In-Game Menu (Esc key)
	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()

	# Music 
	SignalBus.music_change_requested.emit(AudioData.TRACKS["TOWN"], 1.0)

	_scroll_to_player()


func _input(event):

	# Toggle In-Game Menu on Escape
	if event.is_action_pressed("ui_cancel"):
		if in_game_menu:
			if in_game_menu.visible: in_game_menu.close()
			else: in_game_menu.open()


func _setup_ui():

	# MODAL: MOVE CHARACTER
	travel_dialog = ConfirmationDialog.new()
	travel_dialog.title = "VENTURE?"
	travel_dialog.dialog_text = "Confirm you want to travel into the unknown?"
	travel_dialog.ok_button_text = "YES"
	add_child(travel_dialog)
	
	# MODAL: EXIT CONFIRMATION
	exit_confirmation = ConfirmationDialog.new()
	exit_confirmation.title = "ABANDON?"
	exit_confirmation.dialog_text = "Are you sure you want to end this session? \nYour current progress will be summarized."
	exit_confirmation.ok_button_text = "YES"
	exit_confirmation.cancel_button_text = "NO"
	exit_confirmation.confirmed.connect(_on_exit_confirmed)
	add_child(exit_confirmation)

	scroll_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_area.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	if avatar_button:
		avatar_button.pressed.connect(_on_avatar_pressed)
	
	if exit_button:
		exit_button.pressed.connect(func(): exit_confirmation.popup_centered())

func _on_exit_confirmed():
	# Redirect to Run Summary instead of Main Menu
	get_tree().change_scene_to_file("res://features/ui/RunSummary.tscn")


func _draw_map():
	# Clear previous instances
	for n in node_container.get_children(): n.queue_free()
	for l in lines_container.get_children(): l.queue_free()
	
	var map = GameManager.run_map
	var p_pos = GameManager.player_grid_pos
	
	var current_layer = max(0, p_pos.x)
	var biome_num = floor(current_layer / 10.0) + 1
	var phase_num = (current_layer % 10) + 1
	
	tracker_text.text = "%d - %d" % [biome_num, phase_num]
	biome_label.text = "BIOME %d" % biome_num
	phase_label.text = "PHASE %d" % phase_num
	
	for id in map:
		var data = map[id]
		var layer_diff = p_pos.x - data.layer
		
		# Visibility Check for the source node
		if layer_diff > 4 or layer_diff < -2: continue
		
		var node_ui = node_scene.instantiate()
		node_container.add_child(node_ui)
		
		# Position node (Forward is Right)
		node_ui.position = Vector2(data.layer * 280 + 200, data.column * 200 + 300)
		
		var is_player_here = (data.layer == p_pos.x and data.column == p_pos.y)
		var is_reachable = (data.layer == p_pos.x + 1)
		var is_cleared = GameManager.world_state.rooms.has(id) and GameManager.world_state.rooms[id].cleared
		
		node_ui.setup_biome_node(data, null, is_cleared, is_player_here, true, is_reachable)
		
		# Apply Progressive Shadows
		if layer_diff == 1:
			node_ui.modulate = Color(0.67, 0.67, 0.67, 1.0)
		elif layer_diff == 2:
			node_ui.modulate = Color(0.34, 0.34, 0.34, 1.0)
		elif layer_diff >= 3:
			node_ui.modulate = Color(0, 0, 0, 1.0)
		
		if data.layer > p_pos.x + 1:
			node_ui.modulate.a = 0.1
		
		node_ui.node_clicked.connect(_on_node_clicked)
		
		for target_id in data.connections:
			if map.has(target_id):
				var target = map[target_id]
				var target_diff = p_pos.x - target.layer
				if layer_diff < 2 and target_diff <= 4 and target_diff >= -2:
					_draw_hand_drawn_dotted_line(node_ui.position + NODE_HALF_SIZE, Vector2(target.layer * 280 + 200, target.column * 200 + 300) + NODE_HALF_SIZE)


func _draw_hand_drawn_dotted_line(p1: Vector2, p2: Vector2):
	var dir = (p2 - p1).normalized()
	var dist = p1.distance_to(p2)
	var current_dist = 0.0
	while current_dist < dist:
		var segment = Line2D.new()
		segment.width = 6.0
		segment.default_color = Color(0.2, 0.12, 0.05, 0.8)
		segment.begin_cap_mode = Line2D.LINE_CAP_ROUND
		var jitter_s = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		var jitter_e = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		segment.add_point(p1 + dir * current_dist + jitter_s)
		segment.add_point(p1 + dir * min(current_dist + 10.0, dist) + jitter_e)
		lines_container.add_child(segment)
		current_dist += 22.0


func _draw_line(p1: Vector2, p2: Vector2, layer_diff: int):
	var line = Line2D.new()
	line.width = 6.0
	# Dotted Brown Hand-Drawn Color
	line.default_color = Color(0.35, 0.22, 0.1, 0.6) 
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	
	# Hand-drawn variation logic
	var segments = 12
	for i in range(segments + 1):
		var t = float(i) / segments
		var pos = p1.lerp(p2, t)
		
		# Jitter intermediate points to create a "sketched" look
		if i > 0 and i < segments:
			var jitter = Vector2(randf_range(-6, 6), randf_range(-6, 6))
			pos += jitter
			
		line.add_point(pos)
	
	# Hide lines if source node is blacked out
	if layer_diff >= 2: 
		line.default_color.a = 0.0
	
	lines_container.add_child(line)

func _on_node_clicked(data: Dictionary):
	var p_pos = GameManager.player_grid_pos
	if data.layer == p_pos.x and data.column == p_pos.y:
		_enter_room(data)
		return
	if data.layer != p_pos.x + 1:
		return

	# travel_dialog.dialog_text = "VENTURE?"
	for c in travel_dialog.confirmed.get_connections(): travel_dialog.confirmed.disconnect(c.callable)
	travel_dialog.confirmed.connect(func():
		GameManager.player_grid_pos = Vector2i(data.layer, data.column)
		_draw_map()
		_scroll_to_player()
		_enter_room(data)
	)
	travel_dialog.popup_centered()

func _enter_room(data: Dictionary):
	GameManager.current_node = data
	SignalBus.node_selected.emit(data)
	match data.type:
		"battle": get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")
		"treasure": get_tree().change_scene_to_file("res://features/encounters/TreasureScene.tscn")
		"rest": get_tree().change_scene_to_file("res://features/encounters/RestScene.tscn")
		"event": get_tree().change_scene_to_file("res://features/encounters/EventScene.tscn")

func _scroll_to_player():
	await get_tree().process_frame
	var target_x = (GameManager.player_grid_pos.x * 280) - (size.x / 2.0) + 200
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(scroll_area, "scroll_horizontal", int(max(0, target_x)), 0.5)

func _on_avatar_pressed():
	get_tree().change_scene_to_file("res://features/ui/CharacterScreen.tscn")
