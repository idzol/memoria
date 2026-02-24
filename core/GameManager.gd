extends Node

# res://core/GameManager.gd
# Central state management for character and run progression.

# --- Character State ---
var player_name: String = ""
var player_class: String = "Archivist"
var player_level: int = 1
var player_xp: int = 0

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
# var player_grid_pos: Vector2i = Vector2i(2, -1) 

# Default to uninitialized to avoid (0,0) collision bugs
var player_grid_pos: Vector2i = Vector2i(-99, -99)
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
		"owned": [], # List of IDs
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
## Scans the file system for a random .tres file in the requested biome folder.
func get_random_room_resource(area_key: String) -> RoomData:
	var path = "res://data/rooms/%s/" % area_key
	if not DirAccess.dir_exists_absolute(path):
		push_warning("GameManager: Biome directory missing -> %s" % path)
		return null
	
	var files = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				files.append(file_name)
			file_name = dir.get_next()
	
	if files.is_empty():
		return null
		
	var random_file = files[randi() % files.size()]
	return load(path + random_file) as RoomData

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

## Note: previously `add_card_to_deck` 
func add_card_to_collection(card_id: String):
	var path = "res://data/cards/%s.tres" % card_id
	if ResourceLoader.exists(path):
		if not card_id in world_state.cards.owned:
			world_state.cards.owned.append(card_id)
			# Sync with player_inventory for UI compatibility
			if not card_id in player_inventory:
				player_inventory.append(card_id)
			print("GameManager: Card verified and added to owned collection: ", card_id)
	else:
		push_warning("GameManager: Failed to add card. Resource not found at: " + path)


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

	# Set player location 	
	reset_to_home()

	# INITIALIZE FIXED NODES:
	# Certain squares become "fixed" over time or are guaranteed by the map design
	fixed_nodes.clear()
	# Requirement: First mapnode (center of first layer) is always a Town Square
	fixed_nodes[Vector2i(2, 0)] = "town_square"
	
	SaveManager.save_mid_run_state()
	
	# Transition to Intro Cinematic instead of WorldMap directly
	get_tree().change_scene_to_file("res://features/ui/IntroCinematic.tscn")

func reset_to_home():
	# Standard Home location: Layer -1, Column 2
	player_grid_pos = Vector2i(2, -1)

func load_run_from_data(data: Dictionary):
	player_name = data.get("player_name", "Unknown")
	player_class = data.get("player_class", "Archivist")
	player_level = data.get("player_level", 1)

	current_hp = data.get("hp", 100)
	max_hp = data.get("max_hp", 100)
	gold = data.get("gold", 0)
	current_level = data.get("current_level", 1)
	completed_nodes = data.get("completed_nodes", [])
	
	# Restore fixed node data
	# fixed_nodes = data.get("fixed_nodes", {})
	fixed_nodes = data.get("fixed_nodes", {Vector2i(2, 0): "town_square"})
	
	var saved_pos = data.get("grid_pos", [2, -1])
	player_grid_pos = Vector2i(saved_pos[0], saved_pos[1])
	
	if data.has("run_map"):
		run_map = data.run_map

	get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")


func _on_node_selected(node_data: Dictionary):
	current_node = node_data
	
	# UPDATED: Loading external room resource if path is provided
	var res_path = node_data.get("room_resource_path", "")
	var room_res: RoomData = null
	
	if res_path != "" and ResourceLoader.exists(res_path):
		room_res = load(res_path) as RoomData
	
	SaveManager.save_mid_run_state()
	
	# Priority: Use Resource Type, Fallback to Dictionary Type
	var type = room_res.type if room_res else node_data.get("type", "battle")
	
	match type:
		"battle", "boss":
			get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")
		"shop":
			get_tree().change_scene_to_file("res://features/encounters/ShopScene.tscn")
		"rest":
			get_tree().change_scene_to_file("res://features/encounters/RestScene.tscn")
		_:
			get_tree().change_scene_to_file("res://features/encounters/EventScene.tscn")


# --- LOOT LOGIC ---
func prepare_victory_loot(node_data: Dictionary):
	pending_loot.clear()
	
	var room_loot_pool = []
	var enemy_loot_pool = []
	
	var res_path = node_data.get("room_resource_path", "")
	if res_path != "" and ResourceLoader.exists(res_path):
		var room_res = load(res_path) as RoomData
		
		# Defensive check for room_res
		if room_res:
			room_loot_pool = room_res.loot_list
			
			if room_res.enemy_id != "":
				var enemy_path = "res://data/enemies/%s.tres" % room_res.enemy_id
				if ResourceLoader.exists(enemy_path):
					var enemy_res = load(enemy_path) as EnemyData
					
					# FIXED: Handle Nil enemy_res to prevent property access crash
					if enemy_res:
						enemy_loot_pool += enemy_res.item_drops
						enemy_loot_pool.append({
							"id": "gold", 
							"min": enemy_res.gold_min, 
							"max": enemy_res.gold_max
						})
					else:
						push_warning("GameManager: Enemy resource found but failed to load: " + enemy_path)
	
	var master_pool = room_loot_pool + enemy_loot_pool
	
	for item_def in master_pool:
		var reward = {}
		if item_def is String:
			reward = {"id": item_def, "amount": 1, "name": item_def.replace("_", " ").capitalize()}
			
			# Integrated Check: If the item exists in cards/ path, handle as a card discovery
			var card_path = "res://data/cards/%s.tres" % item_def
			if ResourceLoader.exists(card_path):
				add_card_to_collection(item_def)
			else:
				add_item(item_def)
				
		elif item_def is Dictionary:
			var amount = randi_range(item_def.get("min", 1), item_def.get("max", 1))
			var item_id = item_def.get("id", "gold")
			reward = {
				"id": item_id, 
				"amount": amount, 
				"name": str(amount) + " " + item_id.replace("_", " ").capitalize()
			}
			
			if item_id == "gold":
				gold += amount
				world_state.global.gold = gold
			else:
				add_item(item_id)
		
		pending_loot.append(reward)
		run_loot.append(reward)


func _on_combat_won():
	prepare_victory_loot(current_node)
	
	if current_node.has("id"):
		completed_nodes.append(current_node.id)
		player_grid_pos = Vector2i(current_node.column, current_node.layer)
		
		if world_state.rooms.has(current_node.id):
			world_state.rooms[current_node.id].cleared = true
		
	SaveManager.save_mid_run_state()
	
	if not pending_loot.is_empty():
		get_tree().change_scene_to_file("res://features/ui/LootScene.tscn")
	else:
		get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")

func _on_combat_lost():
	get_tree().call_deferred("change_scene_to_file", "res://features/ui/DeathScreen.tscn")

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	SignalBus.hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		SignalBus.combat_lost.emit()

# Helper function for MapGenerator to check for specific overrides
func get_fixed_type(col: int, layer: int) -> String:
	var pos = Vector2i(col, layer)
	return fixed_nodes.get(pos, "")
