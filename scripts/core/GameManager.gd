extends Node

# res://scripts/core/GameManager.gd
# Central state management for character and run progression.

# const GameData = preload("res://scripts/data/GameData.gd")

# --- Character State ---
var player_name: String = ""
var player_class: String = "Archivist"
var current_hp: int = 100
var max_hp: int = 100
var gold: int = 50
var player_inventory: Array = ["sword", "shield", "heart", "trap", "scroll"]

# --- Run Progression ---
var current_level: int = 1
var completed_nodes: Array = []
var current_node: Dictionary = {}
var run_map: Dictionary = {} # Stored persistently per run

# Tracking player by grid coordinates: x = column (0-4), y = layer (-1 to 19)
# Home is at Layer -1, Column 2 (Center)
var player_grid_pos: Vector2i = Vector2i(2, -1) 
var active_deck: Array = []

var pending_loot: Array = []   # Loot from the JUST finished battle
var run_loot: Array = []       # Cumulative loot from the WHOLE run

# --- PERSISTENT WORLD STATE ---
# This structure tracks EVERY interaction across the game world.
var world_state = {
	"global": {
		"total_runs": 0,
		"highest_floor": 0,
		"gold": 0
	},
	"rooms": {}, # Format: "f1": {"visited": true, "unlocked": true, "cleared": false}
	"npcs": {},  # Format: "blacksmith": {"wins": 0, "defeats": 0, "relationship": 10, "met": true}
	"cards": {
		"owned": ["strike", "block"], # List of IDs
		"upgraded": [] # List of unique instances
	},
	"items": {
		"owned": [], # List of item IDs
		"active": [] # Currently equipped/buffing
	}
}

# Direct access for ShopScene and Combat logic
var current_deck: Array:
	get: return world_state.cards.owned

# Persistent "Fixed" locations that stay the same for this character
# Format: { Vector2i(column, layer): "type_string" }
var fixed_nodes: Dictionary = {}

func _ready():
	SignalBus.node_selected.connect(_on_node_selected)
	SignalBus.combat_won.connect(_on_combat_won)
	SignalBus.combat_lost.connect(_on_combat_lost)

	# Pre-populate world_state 
	_initialize_state_trackers()

# Pre-populate world_state based on registry to avoid null checks
func _initialize_state_trackers():
	# Initialize Room trackers
	for area in GameData.ROOMS:
		for room_id in GameData.ROOMS[area]:
			world_state.rooms[room_id] = {"visited": false, "unlocked": true, "cleared": false}
	
	# Initialize NPC trackers
	for npc_id in GameData.NPCS:
		world_state.npcs[npc_id] = {"wins": 0, "defeats": 0, "met": false, "flags": []}

# Checks a condition dictionary against world_state
func evaluate_condition(condition: Dictionary) -> bool:
	if condition.is_empty(): return true
	
	match condition.get("type"):
		"has_item":
			return world_state.items.owned.has(condition.id)
		"room_cleared":
			return world_state.rooms.get(condition.id, {}).get("cleared", false)
		"npc_met":
			return world_state.npcs.get(condition.id, {}).get("met", false)
		"stat_check":
			return world_state.global.get(condition.stat, 0) >= condition.value
	return true

# --- ROOM LOGIC ---
func get_random_room_for_area(area_key: String) -> Dictionary:
	if GameData.ROOMS.has(area_key):
		var area_rooms = GameData.ROOMS[area_key]
		var keys = area_rooms.keys()
		var random_id = keys[randi() % keys.size()]
		var data = area_rooms[random_id].duplicate()
		data["id"] = random_id
		return data
	return {"id": "default", "name": "Unknown"}

# --- STATE ACCESSORS ---
func mark_room_visited(room_id):
	if world_state.rooms.has(room_id):
		world_state.rooms[room_id].visited = true

func mark_room_cleared(room_id):
	if world_state.rooms.has(room_id):
		world_state.rooms[room_id].cleared = true
		world_state.rooms[room_id].visited = true
	prepare_victory_loot(current_node)

func record_npc_interaction(npc_id: String, won: bool):
	if world_state.npcs.has(npc_id):
		world_state.npcs[npc_id].met = true
		if won: world_state.npcs[npc_id].wins += 1
		else: world_state.npcs[npc_id].defeats += 1

func add_card_to_deck(card_id: String):
	if GameData.CARDS.has(card_id):
		world_state.cards.owned.append(card_id)

func add_item(item_id: String):
	if !world_state.items.owned.has(item_id):
		world_state.items.owned.append(item_id)

func has_item(item_id: String) -> bool:
	return world_state.items.owned.has(item_id)

# --- SAVE/LOAD BRIDGE ---
func get_save_data() -> Dictionary:
	return world_state

func load_save_data(data: Dictionary):
	world_state = data


func start_actual_run():
	current_hp = max_hp
	gold = 50
	current_level = 1
	completed_nodes = []
	player_grid_pos = Vector2i(2, -1) # Ensure player starts at Home
	active_deck = ["sword", "shield", "heart", "frost", "scroll", "trap"]
	
	# INITIALIZE FIXED NODES:
	# Certain squares become "fixed" over time or are guaranteed by the map design
	fixed_nodes.clear()
	# Requirement: First mapnode (center of first layer) is always a Town Square
	fixed_nodes[Vector2i(2, 0)] = "town_square"
	
	SaveManager.save_mid_run_state()
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")

func load_run_from_data(data: Dictionary):
	player_name = data.get("player_name", "Unknown")
	player_class = data.get("player_class", "Archivist")
	current_hp = data.get("hp", 100)
	max_hp = data.get("max_hp", 100)
	gold = data.get("gold", 0)
	current_level = data.get("current_level", 1)
	completed_nodes = data.get("completed_nodes", [])
	
	# Restore fixed node data
	fixed_nodes = data.get("fixed_nodes", {})
	
	var saved_pos = data.get("grid_pos", [2, -1])
	player_grid_pos = Vector2i(saved_pos[0], saved_pos[1])
	
	if data.has("run_map"):
		run_map = data.run_map

	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")

func _on_node_selected(data):
	# Flexible handler to avoid Object-to-Dictionary conversion errors.
	# We force the ID to a String to ensure dictionary lookups remain consistent.
	if data is Dictionary:
		current_node = data
		if current_node.has("id"):
			current_node["id"] = str(current_node["id"])
	else:
		# Object.get() only takes 1 argument. We handle defaults manually.
		current_node = {
			"id": str(data.get("id")) if data.get("id") != null else "unk",
			"name": data.get("name") if data.get("name") != null else "Unknown Room",
			"type": data.get("type") if data.get("type") != null else "battle",
			"layer": data.get("layer") if data.get("layer") != null else 0,
			"column": data.get("column") if data.get("column") != null else 0,
			"difficulty": data.get("difficulty") if data.get("difficulty") != null else 1,
			"enemy": data.get("enemy") if data.get("enemy") != null else ""
		}
	
	# Update the world state tracking
	if world_state.rooms.has(current_node.id):
		world_state.rooms[current_node.id].visited = true

# --- LOOT LOGIC ---
func prepare_victory_loot(source_data: Dictionary):
	pending_loot.clear()
	
	# Determine enemy loot if applicable
	var enemy_id = source_data.get("enemy", "")
	var enemy_loot_pool = []
	if GameData.ENEMIES.has(enemy_id):
		enemy_loot_pool = GameData.ENEMIES[enemy_id].get("loot", [])

	# Combine room/NPC loot with enemy loot
	var master_pool = source_data.get("loot", []) + enemy_loot_pool
	
	for item_def in master_pool:
		var reward = {}
		if item_def is String:
			reward = {"id": item_def, "amount": 1, "name": item_def.capitalize()}
			add_item(item_def)
		elif item_def is Dictionary:
			var amount = randi_range(item_def.get("min", 1), item_def.get("max", 1))
			var item_id = item_def.get("id", "gold")
			reward = {"id": item_id, "amount": amount, "name": str(amount) + " " + item_id.capitalize()}
			
			if item_id == "gold":
				world_state.global.gold += amount
			else:
				add_item(item_id)
		
		pending_loot.append(reward)
		run_loot.append(reward) # Track for the final Run Summary

func _on_combat_won():
	gold += 25
	if current_node.has("id"):
		completed_nodes.append(current_node.id)
		# Update grid position on victory
		player_grid_pos = Vector2i(current_node.column, current_node.layer)
		
	SaveManager.save_mid_run_state()
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")

func _on_combat_lost():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/DeathScreen.tscn")

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	SignalBus.hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		SignalBus.combat_lost.emit()

# Helper function for MapGenerator to check for specific overrides
func get_fixed_type(col: int, layer: int) -> String:
	var pos = Vector2i(col, layer)
	return fixed_nodes.get(pos, "")
