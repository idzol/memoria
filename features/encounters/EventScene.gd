extends Control

# res://features/encounters/EventScene.gd
# Narrative encounter logic utilizing Room and NPC resources.

@onready var background = %Background
@onready var room_title = %RoomTitle
@onready var dialog_text = %DialogText
@onready var choice_container = %ChoiceContainer
@onready var npc_name_label = %NPCName
@onready var player_sprite = %PlayerSprite
@onready var npc_sprite = %NPCSprite
@onready var exit_button = %ExitButton

var current_room_res: RoomData = null
var current_npc_res: NPCData = null

func _ready():
	exit_button.pressed.connect(_on_exit_pressed)
	_load_encounter_data()

func _load_encounter_data():
	var node = GameManager.current_node
	if not node.has("room_resource_path"): return
	
	current_room_res = load(node.room_resource_path) as RoomData
	if not current_room_res: return
	
	# 1. Visuals
	room_title.text = current_room_res.room_name
	if current_room_res.background_texture:
		background.texture = current_room_res.background_texture
		
	# 2. Player Spritesheet
	_setup_unit_visuals(player_sprite, _get_player_res())
	
	# 3. NPC Logic
	if current_room_res.npc_id != "":
		var npc_path = "res://data/npcs/%s.tres" % current_room_res.npc_id
		if ResourceLoader.exists(npc_path):
			current_npc_res = load(npc_path) as NPCData
			_setup_npc(current_npc_res)
		else:
			_setup_empty_npc()
	else:
		_setup_empty_npc()

func _setup_npc(data: NPCData):
	npc_name_label.text = data.name
	npc_name_label.visible = true
	_setup_unit_visuals(npc_sprite, data)

	# Start Narrative
	if data.dialog_tree_id != "" and GameData.DIALOG_TREES.has(data.dialog_tree_id):
		_display_dialog_node(data.dialog_tree_id, "start")
	else:
		dialog_text.text = data.initial_greeting

func _setup_empty_npc():
	npc_name_label.visible = false
	npc_sprite.visible = false
	dialog_text.text = current_room_res.initial_dialog

func _display_dialog_node(tree_id: String, node_id: String):
	var tree = GameData.DIALOG_TREES[tree_id]
	if not tree.has(node_id): return
	
	var node = tree[node_id]
	dialog_text.text = node.text
	
	for child in choice_container.get_children(): child.queue_free()
	
	for opt in node.options:
		var btn = Button.new()
		btn.text = opt.text
		btn.custom_minimum_size.y = 50
		if opt.has("next_node"):
			btn.pressed.connect(_display_dialog_node.bind(tree_id, opt.next_node))
		else:
			btn.pressed.connect(_on_exit_pressed)
		choice_container.add_child(btn)

func _setup_unit_visuals(sprite: Sprite2D, res: Resource):
	if not sprite or not res: return
	
	var sheet = res.get("idle_sheet")
	if sheet:
		sprite.texture = sheet
		sprite.hframes = res.get("hframes")
		sprite.vframes = res.get("vframes")
		_animate_unit(sprite, res.get("total_frames"), res.get("frame_speed"))
	else:
		sprite.visible = false

func _animate_unit(sprite: Sprite2D, total: int, speed: float):
	var frame = 0
	var dir = 1
	while sprite and is_inside_tree():
		sprite.frame = frame
		if total > 1:
			if frame >= total - 1: dir = -1
			elif frame <= 0: dir = 1
			frame += dir
		await get_tree().create_timer(speed).timeout

func _get_player_res() -> PlayerData:
	# var p_class = GameManager.player_class.to_lower()
	var p_path = "res://data/player/base.tres" # Static path based on new player logic
	if ResourceLoader.exists(p_path):
		return load(p_path) as PlayerData
	return null

func _on_exit_pressed():

	# 1. Branching return path
	if GameManager.is_battle_mode:
		# Return to the linear testing map
		get_tree().change_scene_to_file("res://features/map/BattleMap.tscn")
	else:
		# Return to the procedural campaign map
		get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")
