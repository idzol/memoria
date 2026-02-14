extends Node2D

# res://features/encounters/LoreScene.gd
# Handles NPC narrative encounters with branching dialog.

const GameData = preload("res://core/GameData.gd")

@onready var player_hp_label = %PlayerHP
@onready var enemy_hp_label = %EnemyHP
@onready var player_portrait_sprite = %PlayerPortraitSprite
@onready var enemy_portrait_sprite = %EnemyPortraitSprite

@onready var room_title = %RoomTitle
@onready var dialog_text = %DialogText
@onready var option_container = %OptionContainer

var current_room = {}
var active_tree = {}

func _ready():
	# 1. Load Data from GameManager
	current_room = GameManager.current_node
	if current_room.is_empty():
		# Fallback for testing
		current_room = {"name": "The Unknown Path", "dialog": "Silence greets you."}
	
	# 2. Setup UI Visuals
	_setup_portraits()
	_update_hp_display()
	
	# 3. Start Narrative
	_init_narrative()

func _setup_portraits():
	# Load Player Portrait
	var player_path = "res://assets/player/base.png"
	if ResourceLoader.exists(player_path):
		player_portrait_sprite.texture = load(player_path)
	
	# Load NPC/Lore Portrait
	var enemy_id = current_room.get("enemy", "")
	var npc_id = current_room.get("npc_id", "")
	var icon_path = "res://assets/card/scroll.png" # Default lore icon
	
	if GameData.NPCS.has(npc_id):
		var npc_data = GameData.NPCS[npc_id]
		icon_path = npc_data.get("icon", icon_path)
		enemy_hp_label.text = npc_data.get("name", "Stranger")
	elif GameData.ENEMIES.has(enemy_id):
		var enemy_data = GameData.ENEMIES[enemy_id]
		icon_path = enemy_data.get("icon", icon_path)
		enemy_hp_label.text = enemy_data.get("name", "Creature")
	else:
		enemy_hp_label.text = "Environment"

	if ResourceLoader.exists(icon_path):
		enemy_portrait_sprite.texture = load(icon_path)
	else:
		enemy_portrait_sprite.texture = load("res://assets/scroll.png")

func _init_narrative():
	# Priority 1: Dialog Tree
	var tree_id = current_room.get("dialog_tree", "")
	if GameData.DIALOG_TREES.has(tree_id):
		active_tree = GameData.DIALOG_TREES[tree_id]
		_display_tree_node("start")
	# Priority 2: Basic Dialog String
	else:
		_setup_basic_dialog()

func _display_tree_node(node_id: String):
	var node = active_tree.get(node_id)
	if !node: return
	
	room_title.text = current_room.get("name", "Lore Encounter")
	dialog_text.text = node.text
	
	# Clear Options
	for child in option_container.get_children(): 
		child.queue_free()
	
	for opt in node.options:
		# Check if player meets requirements (items/gold etc)
		if opt.has("condition") and !GameManager.evaluate_condition(opt.condition):
			continue
			
		var btn = Button.new()
		btn.text = opt.text
		btn.custom_minimum_size.x = 300
		btn.pressed.connect(_handle_choice.bind(opt))
		option_container.add_child(btn)

func _setup_basic_dialog():
	room_title.text = current_room.get("name", "Lore Encounter")
	dialog_text.text = current_room.get("dialog", "You find a fragment of a forgotten story.")
	
	for child in option_container.get_children(): 
		child.queue_free()
		
	var btn = Button.new()
	btn.text = "Leave"
	btn.custom_minimum_size.x = 200
	btn.pressed.connect(_on_finish_encounter)
	option_container.add_child(btn)

func _handle_choice(opt: Dictionary):
	# Apply logic side-effects
	if opt.has("bonus_loot"):
		GameManager.add_item(opt.bonus_loot)
	
	# Determine flow
	if opt.has("next_node"):
		_display_tree_node(opt.next_node)
	elif opt.get("action") == "battle":
		get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")
	else:
		# Default to finishing the encounter
		_on_finish_encounter()

func _update_hp_display():
	player_hp_label.text = "HP: %d/%d" % [GameManager.current_hp, GameManager.max_hp]

func _on_finish_encounter():
	# Return to map and mark the node visited/cleared if needed
	# Note: In lore rooms, we usually mark it cleared immediately upon leaving
	GameManager.mark_room_cleared(current_room.get("id", "unk"))
	get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")