extends Node

# res://core/GameManager.gd
# Central state management for character and run progression.

# --- Character State ---
var player_name: String = ""
var player_class: String = "Warrior"
var player_level: int = 1
var player_xp: int = 0
var last_xp_gained: int = 0
var pending_level_up: Dictionary = {}
var level_up_return_scene: String = ""
var run_summary_exit_to_main_menu: bool = false
var pending_post_battle_scene: String = ""
var pending_story_sequence_biome: String = ""
var pending_story_sequence_return_scene: String = ""
var pending_storyline_fade_in: bool = false
var pending_storyline_focus_biome: String = ""
var pending_storyline_focus_kind: String = ""
var player_biome: String = "tutorial"
var selected_story_biome: String = "tutorial"
var profile_return_scene: String = ""

var base_energy: int = 0	# number of guesses start of each board  
var base_attack: int = 0	
var base_defense: int = 0	

var current_energy: int = 0	   # number of guesses this turn 

var current_hp: int = 10
var max_hp: int = 10
var gold: int = 0
var player_deck: Array = [] # "sword", "shield", "heart", "trap", "scroll"
var active_deck: Array = [] # "sword", "shield", "heart"

var player_items: Array = [] # "wood_splinter", "mug_of_ale", "iron_scrap" 
var active_items: Array = [] # "wood_splinter"

# --- Game Mode ---
const GAME_MODE_BATTLE := "battle_mode"
const GAME_MODE_STORY := "story_mode"

var game_mode: String = GAME_MODE_STORY:
	set(value):
		game_mode = GAME_MODE_BATTLE if value == GAME_MODE_BATTLE else GAME_MODE_STORY

var is_battle_mode: bool:
	get:
		return game_mode == GAME_MODE_BATTLE
	set(value):
		game_mode = GAME_MODE_BATTLE if value else GAME_MODE_STORY

var is_story_mode: bool:
	get:
		return game_mode == GAME_MODE_STORY

# --- Run Progression ---
var completed_nodes: Array = []
var current_run_visited_nodes: Array = []

# Combat Stats
var player_attack: int = 10
var player_defense: int = 5
var player_hp_total: int = 10
var player_attack_total: int = 10
var player_defense_total: int = 5

var current_node: Dictionary = {}
var run_map: Dictionary = {} # Stored persistently per run
var biome_run_paths: Dictionary = {} # Format: "forest": [Vector2i(layer, column), ...]
var world_map_skew_direction: String = ""

# Tracking player by grid coordinates: x = column (0-4), y = layer (-1 to 19)
# Home is at Layer -1, Column 2 (Center)
# var player_grid_pos: Vector2i = Vector2i(2, -1) 

# Default to uninitialized to avoid (0,0) collision bugs
var player_grid_pos: Vector2i = Vector2i(-99, -99)

var pending_loot: Array = []   # Loot from the JUST finished battle
var run_loot: Array = []       # Cumulative loot from the WHOLE run
var run_log: Array = []
const MAX_RUN_LOG_ENTRIES := 200

# --- LOADING SCREEN ---
var loading_overlay_scene = preload("res://features/ui/LoadingOverlay.tscn")
var active_loading_overlay = null

func show_loading(description: String):
	if active_loading_overlay: return
	active_loading_overlay = loading_overlay_scene.instantiate()
	get_tree().root.add_child(active_loading_overlay)
	
	active_loading_overlay.modulate.a = 1.0
	active_loading_overlay.set_loading_info(description)

func update_loading(description: String, progress: float):
	if active_loading_overlay:
		active_loading_overlay.modulate.a = 1.0
		active_loading_overlay.set_loading_info(description, progress)

func hide_loading():
	if active_loading_overlay:
		active_loading_overlay.close()
		active_loading_overlay = null

func add_run_log(entry_data):
	var entry = {}
	if entry_data is Dictionary:
		entry = (entry_data as Dictionary).duplicate(true)
		entry["text"] = str(entry.get("text", "")).strip_edges()
	else:
		entry = {"text": str(entry_data).strip_edges()}
	if str(entry.get("text", "")) == "":
		return
	run_log.append(entry)
	while run_log.size() > MAX_RUN_LOG_ENTRIES:
		run_log.remove_at(0)
	SignalBus.run_log_updated.emit()

func get_run_log() -> Array:
	var entries: Array = []
	for entry in run_log:
		if entry is Dictionary:
			entries.append((entry as Dictionary).duplicate(true))
		else:
			entries.append({"text": str(entry)})
	return entries

func clear_run_log():
	run_log.clear()
	SignalBus.run_log_updated.emit()

func reset_current_run_room_tracking():
	current_run_visited_nodes = []
	biome_run_paths = {}

func randomize_world_map_skew_direction():
	var directions = ["up", "down", "left", "right"]
	world_map_skew_direction = directions[randi() % directions.size()]

func set_game_mode(mode: String):
	game_mode = mode

func is_game_mode(mode: String) -> bool:
	return game_mode == mode

# --- PERSISTENT WORLD STATE ---
# This structure tracks EVERY interaction across the game world.
var world_state = {
	"global": {
		"total_runs": 0,
		"highest_floor": 0,
		"gold": 0,
		"current_day": 1,
		"days_passed": 0
	},
	"biomes": {}, # Format: "forest": {"cleared": true, "unlocked": false, "home_node_id": ""}
	"rooms": {}, # Format: "f1": {"visited": true, "unlocked": true, "cleared": false}
	"enemies": {}, # Format: "giant_rat": {"defeated": 3}
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
const ITEMS_ROOT = "res://data/items/"
const CARDS_ROOT = "res://data/cards/"
const STORY_BIOME_ORDER = ["tutorial", "town", "forest", "ice_caves", "desert", "swamp", "abyss", "void", "the_core"]
const BATTLE_BIOME_ORDER = ["tutorial", "town", "forest", "ice_caves", "desert", "swamp", "abyss", "void", "the_core"]
const STORY_BIOME_ROOM_SOURCE = {
	"tutorial": "tutorial",
	"town": "town",
	"forest": "forest",
	"ice_caves": "ice_caves",
	"desert": "desert",
	"swamp": "swamp",
	"abyss": "abyss",
	"void": "void",
	"the_core": "the_core"
}
const STORY_ROOM_ROOT = "res://data/rooms/"
const GLOBAL_KEY_LAST_WORLDMAP_HOME_EVENT_DAY := "last_worldmap_home_event_day"

func _ready():
	SignalBus.node_selected.connect(_on_node_selected)
	SignalBus.combat_won.connect(_on_combat_won)
	SignalBus.combat_lost.connect(_on_combat_lost)

func reset_world_state():
	world_state = {
		"global": {
			"total_runs": 0,
			"highest_floor": 0,
			"gold": 0,
			"current_day": 1,
			"days_passed": 0
		},
		"biomes": {},
		"rooms": {},
		"enemies": {},
		"npcs": {},
		"cards": {
			"owned": [],
			"upgraded": []
		},
		"items": {
			"owned": [],
			"active": []
		}
	}


# Checks a condition dictionary against world_state
func evaluate_condition(condition: Dictionary, context: Dictionary = {}) -> bool:
	if condition.is_empty(): return true
	
	match condition.get("type"):
		"all":
			for sub_condition in condition.get("conditions", []):
				if sub_condition is Dictionary and not evaluate_condition(sub_condition, context):
					return false
			return true
		"any":
			for sub_condition in condition.get("conditions", []):
				if sub_condition is Dictionary and evaluate_condition(sub_condition, context):
					return true
			return false
		"not":
			return not evaluate_condition(condition.get("condition", {}), context)
		"has_item":
			return world_state.items.owned.has(condition.get("id", ""))
		"has_card":
			return world_state.cards.owned.has(condition.get("id", ""))
		"room_cleared":
			var cleared_room_id = str(condition.get("id", context.get("id", "")))
			return world_state.rooms.get(cleared_room_id, {}).get("cleared", false)
		"room_visited", "discover_room":
			var visited_room_id = str(condition.get("id", context.get("id", "")))
			return world_state.rooms.get(visited_room_id, {}).get("visited", false)
		"npc_met":
			var npc_id = str(condition.get("id", context.get("npc_id", "")))
			return world_state.npcs.get(npc_id, {}).get("met", false)
		"defeated_enemy":
			var enemy_id = str(condition.get("id", context.get("enemy_id", "")))
			return world_state.enemies.get(enemy_id, {}).get("defeated", 0) > 0
		"has_gold":
			return gold >= int(condition.get("amount", condition.get("value", 0)))
		"level", "min_level":
			return player_level >= int(condition.get("value", condition.get("level", 1)))
		"day":
			return world_state.global.get("current_day", 1) >= int(condition.get("value", condition.get("day", 1)))
		"day_of_cycle":
			var cycle_value = int(condition.get("value", condition.get("day", 1)))
			var current_day = int(world_state.global.get("current_day", 1))
			var cycle_day = posmod(current_day - 1, 8) + 1
			return cycle_day == cycle_value
		"days_passed":
			return world_state.global.get("days_passed", 0) >= int(condition.get("value", condition.get("days", 0)))
		"rooms_visited_count":
			return _matches_numeric_condition(current_run_visited_nodes.size(), condition)
		"room_visit_count":
			var room_id = str(condition.get("id", context.get("id", "")))
			var visit_count = int(world_state.rooms.get(room_id, {}).get("visit_count", 0))
			return _matches_numeric_condition(visit_count, condition)
		"run_mode":
			var mode = str(condition.get("value", condition.get("mode", "story"))).to_lower()
			return (
				(mode == "battle" or mode == "battle_mode") and is_battle_mode
			) or (
				(mode == "story" or mode == "story_mode") and is_story_mode
			)
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
	_ensure_room_state(room_id)
	world_state.rooms[room_id].visited = true
	world_state.rooms[room_id].visit_count = int(world_state.rooms[room_id].get("visit_count", 0)) + 1
	refresh_story_room_completions()

func mark_room_cleared(room_id):
	_ensure_room_state(room_id)
	world_state.rooms[room_id].cleared = true
	world_state.rooms[room_id].visited = true
	refresh_story_room_completions()
	SaveManager.save_mid_run_state()
	prepare_victory_loot(current_node)

func mark_biome_cleared(biome: String):
	biome = _normalize_story_biome_key(biome)
	if biome == "":
		return
	_ensure_biome_state(biome)
	world_state.biomes[biome].cleared = true

func unlock_biome(biome: String):
	biome = _normalize_story_biome_key(biome)
	if biome == "":
		return
	_ensure_biome_state(biome)
	world_state.biomes[biome].unlocked = true

func is_biome_unlocked(biome: String) -> bool:
	biome = _normalize_story_biome_key(biome)
	if biome == "":
		return false
	if biome == STORY_BIOME_ORDER[0]:
		return true
	return world_state.biomes.has(biome) and world_state.biomes[biome].get("unlocked", false)

func is_biome_cleared(biome: String) -> bool:
	biome = _normalize_story_biome_key(biome)
	if biome == "":
		return false
	return world_state.biomes.has(biome) and world_state.biomes[biome].get("cleared", false)

func get_unlocked_story_biomes() -> Array[String]:
	var result: Array[String] = []
	for biome in STORY_BIOME_ORDER:
		if is_biome_unlocked(biome):
			result.append(biome)
	return result

func set_selected_story_biome(biome: String):
	var normalized_biome = _normalize_story_biome_key(biome)
	if normalized_biome == "":
		return
	selected_story_biome = normalized_biome
	if DataManager and DataManager.has_method("prioritize_story_assets"):
		DataManager.prioritize_story_assets(selected_story_biome)

func get_story_line_scene_path() -> String:
	return "res://features/map/StoryLine.tscn"

func request_storyline_fade_in():
	pending_storyline_fade_in = true

func consume_storyline_fade_in_request() -> bool:
	var should_fade := pending_storyline_fade_in
	pending_storyline_fade_in = false
	return should_fade

func set_storyline_return_focus(biome: String, kind: String = "summary"):
	pending_storyline_focus_biome = _normalize_story_biome_key(biome)
	pending_storyline_focus_kind = kind

func consume_storyline_return_focus() -> Dictionary:
	var out = {
		"biome": pending_storyline_focus_biome,
		"kind": pending_storyline_focus_kind
	}
	pending_storyline_focus_biome = ""
	pending_storyline_focus_kind = ""
	return out

func get_story_cutscene_scene_path() -> String:
	return "res://features/ui/StoryCutscene.tscn"

func get_story_chapter_sequence_scene_path() -> String:
	return "res://features/map/StoryChapterSequence.tscn"

func get_active_biome_map_scene_path() -> String:
	return "res://features/map/WorldMap.tscn"

func add_player_xp(amount: int) -> Dictionary:
	var gained = max(0, amount)
	player_xp += gained
	last_xp_gained = gained
	
	var start_level = player_level
	var start_stats = _get_class_stats_for_level(start_level)
	var max_level = _get_max_class_level()
	
	while player_level < max_level and player_xp >= GameData.get_max_xp_for_level(player_level):
		player_level += 1
	
	var leveled_up = player_level > start_level
	if leveled_up:
		var new_stats = _get_class_stats_for_level(player_level)
		_apply_level_stats(new_stats)
		_ensure_minimum_active_pairs_for_level()
		pending_level_up = {
			"old_level": start_level,
			"new_level": player_level,
			"old_stats": start_stats,
			"new_stats": new_stats,
			"required_pairs": player_level,
			"active_pairs": get_active_deck_unique_pair_count()
		}
		SignalBus.level_up.emit(player_level)

	refresh_story_room_completions()
	
	return {
		"gained": gained,
		"leveled_up": leveled_up,
		"new_level": player_level
	}

func award_player_xp(amount: int, return_scene: String = "") -> Dictionary:
	var result = add_player_xp(amount)
	if bool(result.get("leveled_up", false)) and return_scene != "":
		level_up_return_scene = return_scene
	return result

func show_level_up_scene_if_needed(return_scene: String = "") -> bool:
	if pending_level_up.is_empty():
		return false
	level_up_return_scene = return_scene if return_scene != "" else level_up_return_scene
	if level_up_return_scene == "":
		level_up_return_scene = get_active_biome_map_scene_path()
	SceneTransition.change_scene_to_file("res://features/ui/CharacterLevelUp.tscn")
	return true

func is_room_cleared(room_id: String) -> bool:
	if room_id == "":
		return false
	return world_state.rooms.has(room_id) and world_state.rooms[room_id].get("cleared", false)

func get_enemy_defeat_count(enemy_id: String) -> int:
	if enemy_id == "":
		return 0
	return int(world_state.enemies.get(enemy_id, {}).get("defeated", 0))

func _ensure_room_state(room_id: String):
	if room_id == "":
		return
	if not world_state.rooms.has(room_id):
		world_state.rooms[room_id] = {"visited": false, "cleared": false, "completed": false, "visit_count": 0}
	if not world_state.rooms[room_id].has("completed"):
		world_state.rooms[room_id].completed = false
	if not world_state.rooms[room_id].has("visit_count"):
		world_state.rooms[room_id].visit_count = 0

func _ensure_biome_state(biome: String):
	if biome == "":
		return
	if not world_state.biomes.has(biome):
		world_state.biomes[biome] = {"cleared": false, "unlocked": false, "home_node_id": "", "entered": false}
	if not world_state.biomes[biome].has("home_node_id"):
		world_state.biomes[biome].home_node_id = ""
	if not world_state.biomes[biome].has("entered"):
		world_state.biomes[biome].entered = false
	if not world_state.biomes[biome].has("unlocked"):
		world_state.biomes[biome].unlocked = false

func _ensure_enemy_state(enemy_id: String):
	if enemy_id == "":
		return
	if not world_state.enemies.has(enemy_id):
		world_state.enemies[enemy_id] = {"defeated": 0}

func _ensure_world_state_shape():
	if not world_state.has("global"):
		world_state.global = {}
	if not world_state.global.has("total_runs"):
		world_state.global.total_runs = 0
	if not world_state.global.has("highest_floor"):
		world_state.global.highest_floor = 0
	if not world_state.global.has("gold"):
		world_state.global.gold = 0
	if not world_state.global.has("current_day"):
		world_state.global.current_day = 1
	if not world_state.global.has("days_passed"):
		world_state.global.days_passed = 0
	if not world_state.global.has("selected_story_biome_this_run"):
		world_state.global.selected_story_biome_this_run = ""
	if not world_state.global.has(GLOBAL_KEY_LAST_WORLDMAP_HOME_EVENT_DAY):
		world_state.global[GLOBAL_KEY_LAST_WORLDMAP_HOME_EVENT_DAY] = 0
	if not world_state.has("biomes"):
		world_state.biomes = {}
	if not world_state.has("rooms"):
		world_state.rooms = {}
	if not world_state.has("enemies"):
		world_state.enemies = {}
	if not world_state.has("npcs"):
		world_state.npcs = {}
	if not world_state.has("cards"):
		world_state.cards = {"owned": [], "upgraded": []}
	if not world_state.has("items"):
		world_state.items = {"owned": [], "active": []}

func record_npc_interaction(npc_id: String, won: bool):
	if npc_id == "":
		return
	if not world_state.npcs.has(npc_id):
		world_state.npcs[npc_id] = {"wins": 0, "defeats": 0, "relationship": 0, "met": true}
	if world_state.npcs.has(npc_id):
		world_state.npcs[npc_id].met = true
		if won: world_state.npcs[npc_id].wins += 1
		else: world_state.npcs[npc_id].defeats += 1
	refresh_story_room_completions()

func mark_npc_met(npc_id: String):
	if npc_id == "":
		return
	record_npc_interaction(npc_id, false)

## Note: previously `add_card_to_deck` 
func add_card_to_collection(card_id: String):
	var path = "res://data/cards/%s.tres" % card_id
	if ResourceLoader.exists(path):
		if not card_id in world_state.cards.owned:
			world_state.cards.owned.append(card_id)
			# Sync with player_deck for UI compatibility
			if not card_id in player_deck:
				player_deck.append(card_id)
			print("GameManager: Card verified and added to owned collection: ", card_id)
			refresh_story_room_completions()
	else:
		push_warning("GameManager: Failed to add card. Resource not found at: " + path)


func add_item(item_id: String):
	if !world_state.items.owned.has(item_id):
		world_state.items.owned.append(item_id)
	if not player_items.has(item_id):
		player_items.append(item_id)
	refresh_story_room_completions()

func register_room_interaction_complete(node_data: Dictionary, mark_cleared: bool = true):
	var node_id = str(node_data.get("id", ""))
	if node_id == "":
		return
	var has_explicit_complete_condition := false
	var room_path = str(node_data.get("room_resource_path", ""))
	if room_path != "" and ResourceLoader.exists(room_path):
		var room_res = load(room_path) as RoomData
		has_explicit_complete_condition = room_res != null and not room_res.complete_condition.is_empty()
	_ensure_room_state(node_id)
	world_state.rooms[node_id].visited = true
	if mark_cleared:
		world_state.rooms[node_id].cleared = true
		_consume_room_object(node_id)
		if not has_explicit_complete_condition:
			world_state.rooms[node_id].completed = true
			if not completed_nodes.has(node_id):
				completed_nodes.append(node_id)
			SignalBus.map_node_completed.emit(node_id)
	refresh_story_room_completions()
	SaveManager.save_mid_run_state()

func _consume_room_object(node_id: String):
	if node_id == "":
		return
	if run_map.has(node_id):
		var run_node = run_map[node_id]
		if run_node is Dictionary:
			run_node["object_consumed"] = true
			run_map[node_id] = run_node
	if str(current_node.get("id", "")) == node_id:
		current_node["object_consumed"] = true

func has_item(item_id: String) -> bool:
	return world_state.items.owned.has(item_id)

func get_item_stat_bonuses() -> Dictionary:
	var bonuses = {"atk_bonus": 0, "def_bonus": 0, "hp_bonus": 0, "energy_bonus": 0}
	for item_id in active_items:
		var path = ITEMS_ROOT + item_id + ".tres"
		if ResourceLoader.exists(path):
			var res = load(path) as ItemData
			if res:
				bonuses.atk_bonus += res.attack
				bonuses.def_bonus += res.armour
				bonuses.hp_bonus += res.hp
				bonuses.energy_bonus += res.energy
	return bonuses

func recalculate_player_totals():
	var totals = get_item_stat_bonuses()
	player_hp_total = max_hp + totals.hp_bonus
	player_attack_total = player_attack + totals.atk_bonus
	player_defense_total = player_defense + totals.def_bonus
	current_hp = clamp(current_hp, 0, player_hp_total)

# --- SAVE/LOAD BRIDGE ---
func get_save_data() -> Dictionary:
	return world_state

func load_save_data(data: Dictionary):
	world_state = data

func start_battle_mode():
	set_game_mode(GAME_MODE_BATTLE)
	player_level = 1
	player_xp = 0
	last_xp_gained = 0
	clear_run_log()
	pending_level_up = {}
	level_up_return_scene = ""
	var start_stats = _get_class_stats_for_level(player_level)
	_apply_level_stats(start_stats)
	current_hp = max_hp
	gold = 100
	
	# Testing suite starting items
	player_items = ["wood_splinter", "mug_of_ale", "iron_scrap"]
	active_items = []
	
	player_deck = ["sword", "shield", "heart"]
	active_deck = player_deck.duplicate()
	recalculate_player_totals()
	
	# Use specialized linear generator
	var gen = preload("res://features/map/BattleMapGenerator.gd").new()
	add_child(gen) 
	
	# 2. Connect Loading Signals
	if not gen.is_connected("progress_updated", _on_gen_progress):
		gen.progress_updated.connect(_on_gen_progress)
		 
	# 3. Generate Async
	run_map = await gen.generate_battle_map()

	# 4. Cleanup	
	gen.queue_free()
	biome_run_paths = {}
	var battle_home = _find_home_node_for_biome("tutorial")
	if not battle_home.is_empty():
		player_grid_pos = Vector2i(int(battle_home.get("layer", 0)), int(battle_home.get("column", 0)))
		record_biome_path_step(battle_home)
	else:
		player_grid_pos = Vector2i(0, 0)
	world_state.rooms = {}
	world_state.biomes = {}
	world_state.enemies = {}
	pending_post_battle_scene = ""
	reset_current_run_room_tracking()
	player_biome = "tutorial"
	selected_story_biome = "tutorial"
	randomize_world_map_skew_direction()
	_initialize_story_progression()
	
	hide_loading()
	get_tree().change_scene_to_file(get_active_biome_map_scene_path())

func start_actual_run():
	set_game_mode(GAME_MODE_STORY)
	player_level = 1
	clear_run_log()
	var start_stats = _get_class_stats_for_level(player_level)
	_apply_level_stats(start_stats)
	gold = 50
	player_xp = 0
	last_xp_gained = 0
	pending_level_up = {}
	level_up_return_scene = ""
	pending_post_battle_scene = ""
	completed_nodes = []
	reset_current_run_room_tracking()
	player_grid_pos = Vector2i(-99, -99)
	player_biome = "tutorial"
	selected_story_biome = "tutorial"
	randomize_world_map_skew_direction()
	active_deck = ["sword", "shield", "heart"]
	recalculate_player_totals()
	current_hp = player_hp_total

	# 1. Setup fixed locations - Certain squares become "fixed" over time or are guaranteed by the map design
	fixed_nodes.clear()
	# Requirement: First mapnode (center of first layer) is always a Town Square
	fixed_nodes[Vector2i(2, 0)] = "town_square"
	
	# 2. Generate Persistent Map (Run once per run)
	var generated_new_map := false
	if run_map.is_empty():
		var gen = preload("res://features/map/MapGenerator.gd").new()
		add_child(gen)
		
		# Connect Loading Signals
		if not gen.is_connected("progress_updated", _on_gen_progress):
			gen.progress_updated.connect(_on_gen_progress)
		
		run_map = await gen.generate_new_map()
		gen.queue_free()
		generated_new_map = true

	_initialize_story_progression()
	_initialize_story_biome_homes()
	if not generated_new_map:
		_ensure_story_biomes_generated(_get_story_biome_generation_targets("tutorial", false))
		_reroll_incomplete_story_rooms_for_new_run()
	enter_story_biome("tutorial", true)
	SaveManager.save_mid_run_state()
	
	# 3. Cleanup
	hide_loading()
	request_storyline_fade_in()

	begin_story_sequence("tutorial", get_story_line_scene_path(), false, true)

func _on_gen_progress(percent: float, description: String):
	update_loading(description, percent)

func reset_to_home():
	if not is_battle_mode and not run_map.is_empty():
		enter_story_biome(player_biome if player_biome != "" else "tutorial", true)
		return
	player_biome = "tutorial"
	selected_story_biome = "tutorial"
	player_grid_pos = Vector2i(-99, -99)

func load_run_from_data(data: Dictionary):
	var saved_mode = str(data.get("game_mode", ""))
	if saved_mode == "":
		saved_mode = GAME_MODE_BATTLE if bool(data.get("is_battle_mode", false)) else GAME_MODE_STORY
	set_game_mode(saved_mode)
	player_name = data.get("player_name", "Unknown")
	player_class = data.get("player_class", "Archivist")
	player_level = data.get("player_level", data.get("current_level", 1))
	player_xp = data.get("player_xp", 0)
	last_xp_gained = data.get("last_xp_gained", 0)
	pending_level_up = _decode_variant_field(data, "pending_level_up", {})
	level_up_return_scene = data.get("level_up_return_scene", "")
	pending_post_battle_scene = data.get("pending_post_battle_scene", "")
	pending_story_sequence_biome = _normalize_story_biome_key(data.get("pending_story_sequence_biome", ""))
	pending_story_sequence_return_scene = data.get("pending_story_sequence_return_scene", "")
	player_biome = _normalize_story_biome_key(data.get("player_biome", player_biome))
	selected_story_biome = _normalize_story_biome_key(data.get("selected_story_biome", player_biome))
	profile_return_scene = data.get("profile_return_scene", "")

	current_hp = data.get("hp", 100)
	max_hp = data.get("max_hp", 100)
	gold = data.get("gold", 0)
	base_energy = data.get("base_energy", base_energy)
	base_attack = data.get("base_attack", base_attack)
	base_defense = data.get("base_defense", base_defense)
	current_energy = data.get("current_energy", current_energy)
	player_attack = data.get("player_attack", base_attack)
	player_defense = data.get("player_defense", base_defense)
	player_deck = data.get("deck", [])
	active_deck = data.get("active_deck", [])
	run_log = _decode_variant_field(data, "run_log", [])
	player_items = data.get("items", [])
	active_items = data.get("active_items", [])
	world_state = _decode_variant_field(data, "world_state", world_state)
	_ensure_world_state_shape()
	_initialize_story_progression()
	current_node = _decode_variant_field(data, "current_node", {})
	run_map = _decode_variant_field(data, "run_map", run_map)
	biome_run_paths = _decode_variant_field(data, "biome_run_paths", {})
	world_map_skew_direction = data.get("world_map_skew_direction", "")
	pending_loot = _decode_variant_field(data, "pending_loot", [])
	run_loot = _decode_variant_field(data, "run_loot", [])
	recalculate_player_totals()
	completed_nodes = data.get("completed_nodes", [])
	current_run_visited_nodes = _decode_variant_field(data, "current_run_visited_nodes", [])
	
	# Restore fixed node data
	# fixed_nodes = data.get("fixed_nodes", {})
	fixed_nodes = data.get("fixed_nodes", {Vector2i(2, 0): "town_square"})
	
	var saved_pos = data.get("grid_pos", [2, -1])
	player_grid_pos = Vector2i(saved_pos[0], saved_pos[1])
	if world_map_skew_direction == "":
		randomize_world_map_skew_direction()
	if not is_battle_mode:
		_ensure_story_biomes_generated(_get_story_biome_generation_targets(selected_story_biome if selected_story_biome != "" else player_biome, true))
		if DataManager and DataManager.has_method("prioritize_story_assets_for_resume"):
			DataManager.prioritize_story_assets_for_resume(
				selected_story_biome if selected_story_biome != "" else player_biome,
				_get_next_biome_key(selected_story_biome if selected_story_biome != "" else player_biome)
			)
	
	if is_battle_mode:
		get_tree().change_scene_to_file(get_active_biome_map_scene_path())
	else:
		if selected_story_biome == "":
			selected_story_biome = player_biome
		if pending_story_sequence_biome != "":
			get_tree().change_scene_to_file(get_story_chapter_sequence_scene_path())
		else:
			get_tree().change_scene_to_file(get_story_line_scene_path())

func _decode_variant_field(data: Dictionary, key: String, default_value):
	var raw = data.get(key, default_value)
	if raw is String:
		var decoded = str_to_var(raw)
		return decoded if decoded != null else default_value
	return raw

func _initialize_story_progression():
	_ensure_world_state_shape()
	for biome in STORY_BIOME_ORDER:
		_ensure_biome_state(biome)
	unlock_biome(STORY_BIOME_ORDER[0])

func _initialize_story_biome_homes():
	for biome in STORY_BIOME_ORDER:
		_ensure_biome_state(biome)
		var existing_home_id = get_biome_home_node_id(biome)
		if existing_home_id != "":
			_apply_home_type_to_node(existing_home_id)
			continue
		var home_node_id = _pick_random_story_biome_home_node_id(biome)
		if home_node_id != "":
			set_biome_home_node_id(biome, home_node_id)
			_apply_home_type_to_node(home_node_id)

func _get_story_biome_generation_targets(current_biome: String = "", include_completed_biomes: bool = false) -> Array[String]:
	var resolved_current = current_biome if current_biome != "" else (player_biome if player_biome != "" else "tutorial")
	var targets: Array[String] = []
	if include_completed_biomes:
		for biome in STORY_BIOME_ORDER:
			if is_biome_cleared(biome) and not targets.has(biome):
				targets.append(biome)
	if resolved_current != "" and not targets.has(resolved_current):
		targets.append(resolved_current)
	var next_biome = _get_next_biome_key(resolved_current)
	if next_biome != "" and not targets.has(next_biome):
		targets.append(next_biome)
	return targets

func _ensure_story_biomes_generated(target_biomes: Array[String]):
	if is_battle_mode or target_biomes.is_empty():
		return
	var gen = preload("res://features/map/MapGenerator.gd").new()
	add_child(gen)
	run_map = gen.expand_story_map_immediate(run_map, target_biomes)
	gen.queue_free()

func get_nodes_for_biome(biome: String) -> Array[Dictionary]:
	biome = _normalize_story_biome_key(biome)
	var results: Array[Dictionary] = []
	for raw_key in run_map.keys():
		var node = run_map[raw_key]
		if str(node.get("biome", "")) == biome:
			results.append(node)
	return results

func _get_run_node_by_id(node_id: String) -> Dictionary:
	for raw_key in run_map.keys():
		if str(raw_key) == node_id:
			return run_map[raw_key]
	return {}

func get_biome_home_node_id(biome: String) -> String:
	_ensure_biome_state(biome)
	return str(world_state.biomes[biome].get("home_node_id", ""))

func set_biome_home_node_id(biome: String, node_id: String):
	_ensure_biome_state(biome)
	world_state.biomes[biome].home_node_id = node_id

func has_entered_story_biome(biome: String) -> bool:
	if biome == "":
		return false
	_ensure_biome_state(biome)
	return bool(world_state.biomes[biome].get("entered", false))

func mark_story_biome_entered(biome: String):
	if biome == "":
		return
	_ensure_biome_state(biome)
	world_state.biomes[biome].entered = true

func has_pending_story_sequence() -> bool:
	return pending_story_sequence_biome != ""

func consume_first_worldmap_load_for_day() -> bool:
	if is_battle_mode:
		return false
	_ensure_world_state_shape()
	var current_day = max(1, int(world_state.global.get("current_day", 1)))
	var last_home_event_day = int(world_state.global.get(GLOBAL_KEY_LAST_WORLDMAP_HOME_EVENT_DAY, 0))
	if last_home_event_day == current_day:
		return false
	world_state.global[GLOBAL_KEY_LAST_WORLDMAP_HOME_EVENT_DAY] = current_day
	return true

func queue_story_sequence(biome: String, return_scene: String = ""):
	var normalized_biome = _normalize_story_biome_key(biome)
	if normalized_biome == "":
		return
	pending_story_sequence_biome = normalized_biome
	pending_story_sequence_return_scene = return_scene if return_scene != "" else get_story_line_scene_path()

func clear_story_sequence():
	pending_story_sequence_biome = ""
	pending_story_sequence_return_scene = ""

func get_pending_story_sequence_biome() -> String:
	if pending_story_sequence_biome != "":
		return _normalize_story_biome_key(pending_story_sequence_biome)
	return _normalize_story_biome_key(selected_story_biome if selected_story_biome != "" else player_biome)

func begin_story_sequence(
	biome: String,
	return_scene: String = "",
	prepare_biome_entry: bool = false,
	mark_entered: bool = false
):
	biome = _normalize_story_biome_key(biome)
	if biome == "":
		return
	if prepare_biome_entry and not is_battle_mode:
		enter_story_biome(biome, true)
	else:
		set_selected_story_biome(biome)
	if mark_entered:
		mark_story_biome_entered(biome)
	queue_story_sequence(biome, return_scene)
	SaveManager.save_mid_run_state()
	SceneTransition.change_scene_to_file(get_story_chapter_sequence_scene_path())

func advance_story_sequence_from_cutscene():
	if not has_pending_story_sequence():
		SceneTransition.change_scene_to_file(get_story_line_scene_path())
		return
	set_selected_story_biome(get_pending_story_sequence_biome())
	SceneTransition.change_scene_to_file(get_story_chapter_sequence_scene_path())

func finish_story_sequence():
	var return_scene = pending_story_sequence_return_scene if pending_story_sequence_return_scene != "" else get_story_line_scene_path()
	clear_story_sequence()
	SaveManager.save_mid_run_state()
	SceneTransition.change_scene_to_file(return_scene)

func enter_story_biome(biome: String, mark_as_home_if_new: bool = true):
	biome = _normalize_story_biome_key(biome)
	if biome == "":
		return
	unlock_biome(biome)
	var biome_nodes = get_nodes_for_biome(biome)
	if biome_nodes.is_empty():
		return
	var home_node_id = get_biome_home_node_id(biome)
	var entry_node: Dictionary = {}
	if home_node_id != "":
		entry_node = _get_run_node_by_id(home_node_id)
	if entry_node.is_empty():
		var fallback_home_id = _pick_random_story_biome_home_node_id(biome)
		if fallback_home_id != "":
			entry_node = _get_run_node_by_id(fallback_home_id)
		elif not biome_nodes.is_empty():
			entry_node = biome_nodes[0]
		if mark_as_home_if_new:
			set_biome_home_node_id(biome, str(entry_node.get("id", "")))
			_apply_home_type_to_node(str(entry_node.get("id", "")))
	player_biome = biome
	selected_story_biome = biome
	if DataManager and DataManager.has_method("prioritize_story_assets"):
		DataManager.prioritize_story_assets(player_biome)
	_set_player_position_from_node(entry_node)

func get_story_biome_home_node(biome: String) -> Dictionary:
	if biome == "":
		return {}
	var home_node_id = get_biome_home_node_id(biome)
	if home_node_id != "":
		var entry_node = _get_run_node_by_id(home_node_id)
		if not entry_node.is_empty():
			return entry_node
	return _find_home_node_for_biome(biome)

func get_scene_path_for_room(node_data: Dictionary) -> String:
	if node_data.is_empty():
		return get_active_biome_map_scene_path()
	var room_path = str(node_data.get("room_resource_path", ""))
	var room_res: RoomData = null
	if room_path != "" and ResourceLoader.exists(room_path):
		room_res = load(room_path) as RoomData
	var room_type = str(node_data.get("type", "battle"))
	if room_res:
		room_type = str(room_res.type)
	match room_type:
		"battle", "boss":
			return "res://features/combat/BattleScene.tscn"
		"rest":
			return "res://features/encounters/RestScene.tscn"
		"shop":
			return "res://features/encounters/ShopScene.tscn"
		"event", "home", "lore", "npc":
			return "res://features/encounters/EventScene.tscn"
		_:
			return "res://features/combat/BattleScene.tscn"

func open_story_biome_intro_if_needed(biome: String) -> bool:
	if biome == "" or is_battle_mode or has_entered_story_biome(biome):
		return false
	begin_story_sequence(biome, get_story_line_scene_path(), true, true)
	return true

func _pick_random_story_biome_home_node_id(biome: String) -> String:
	var biome_nodes = get_nodes_for_biome(biome)
	if biome_nodes.is_empty():
		return ""
	var expected_home_path = _get_story_biome_home_room_path(biome)
	if expected_home_path != "":
		for node in biome_nodes:
			if str(node.get("room_resource_path", "")) == expected_home_path:
				return str(node.get("id", ""))
	var tagged_home_node = _find_home_node_for_biome(biome)
	if not tagged_home_node.is_empty():
		return str(tagged_home_node.get("id", ""))
	var picked_node = biome_nodes.pick_random()
	return str(picked_node.get("id", ""))

func _get_story_biome_home_room_path(biome: String) -> String:
	if biome == "":
		return ""
	var source_biome = str(STORY_BIOME_ROOM_SOURCE.get(biome, biome))
	return "%s%s/%s_home.tres" % [STORY_ROOM_ROOT, source_biome, source_biome]

func _find_home_node_for_biome(biome: String) -> Dictionary:
	for raw_key in run_map.keys():
		var node = run_map[raw_key]
		if str(node.get("biome", "")) == biome and bool(node.get("is_home", false)):
			return node
	return {}

func _apply_home_type_to_node(node_id: String):
	var node = _get_run_node_by_id(node_id)
	if node.is_empty():
		return
	var biome = str(node.get("biome", ""))
	if biome != "":
		for raw_key in run_map.keys():
			var other_id = str(raw_key)
			var other_node = run_map[raw_key]
			if str(other_node.get("biome", "")) != biome:
				continue
			if other_id == node_id:
				continue
			if bool(other_node.get("is_home", false)) or str(other_node.get("type", "")) == "home":
				other_node["is_home"] = false
				other_node["type"] = str(other_node.get("base_type", other_node.get("type", "battle")))
				run_map[other_id] = other_node
	node["is_home"] = true
	node["type"] = "home"
	run_map[node_id] = node
	_ensure_room_state(node_id)
	var room_state = world_state.rooms[node_id]
	var was_completed = bool(room_state.get("completed", false))
	room_state["completed"] = true
	world_state.rooms[node_id] = room_state
	if not was_completed:
		SignalBus.map_node_completed.emit(node_id)

func is_story_room_completed(node_id: String) -> bool:
	if node_id == "":
		return false
	return world_state.rooms.get(node_id, {}).get("completed", false)

func refresh_story_room_completions():
	if is_battle_mode:
		return
	for raw_key in run_map.keys():
		var node_id = str(raw_key)
		var node = run_map[raw_key]
		var room_path = str(node.get("room_resource_path", ""))
		if room_path == "" or not ResourceLoader.exists(room_path):
			continue
		_ensure_room_state(node_id)
		if world_state.rooms[node_id].get("completed", false):
			continue
		var room_res = load(room_path) as RoomData
		if not room_res or room_res.complete_condition.is_empty():
			continue
		var context = {
			"id": node_id,
			"biome": node.get("biome", ""),
			"enemy_id": room_res.enemy_id,
			"npc_id": room_res.npc_id
		}
		if evaluate_condition(room_res.complete_condition, context):
			world_state.rooms[node_id].completed = true
			SignalBus.map_node_completed.emit(node_id)

func _reroll_incomplete_story_rooms_for_new_run():
	if is_battle_mode or run_map.is_empty():
		return
	var gen = preload("res://features/map/MapGenerator.gd").new()
	run_map = gen.reroll_incomplete_story_rooms(run_map, world_state.rooms)
	for raw_key in run_map.keys():
		var node_id = str(raw_key)
		_ensure_room_state(node_id)
		if world_state.rooms[node_id].get("completed", false):
			continue
		var visit_count = int(world_state.rooms[node_id].get("visit_count", 0))
		world_state.rooms[node_id] = {"visited": false, "cleared": false, "completed": false, "visit_count": visit_count}
	refresh_story_room_completions()

func begin_new_story_run(return_biome: String = ""):
	if is_battle_mode:
		return
	_initialize_story_progression()
	_initialize_story_biome_homes()
	_reroll_incomplete_story_rooms_for_new_run()
	world_state.global.current_day = int(world_state.global.get("current_day", 1)) + 1
	world_state.global.days_passed = int(world_state.global.get("days_passed", 0)) + 1
	world_state.global.total_runs = int(world_state.global.get("total_runs", 0)) + 1
	current_hp = player_hp_total
	current_node = {}
	pending_loot = []
	run_loot = []
	completed_nodes = []
	reset_current_run_room_tracking()
	world_state.global.selected_story_biome_this_run = ""
	enter_story_biome(return_biome if return_biome != "" else (player_biome if player_biome != "" else "tutorial"), true)
	request_storyline_fade_in()

func get_current_story_chapter_index() -> int:
	return max(0, STORY_BIOME_ORDER.find(selected_story_biome))

func get_biome_run_path(biome: String) -> Array:
	if biome == "":
		return []
	if not biome_run_paths.has(biome):
		return []
	return biome_run_paths[biome]

func has_visited_node_this_run(node_id: String) -> bool:
	if node_id == "":
		return false
	return current_run_visited_nodes.has(node_id)

func get_room_visit_count_this_run(node_id: String) -> int:
	if node_id == "":
		return 0
	var count := 0
	for visited_id in current_run_visited_nodes:
		if str(visited_id) == node_id:
			count += 1
	return count

func record_biome_path_step(node_data: Dictionary):
	var biome = str(node_data.get("biome", ""))
	if biome == "":
		return
	var position = Vector2i(int(node_data.get("layer", 0)), int(node_data.get("column", 0)))
	if not biome_run_paths.has(biome):
		biome_run_paths[biome] = []
	biome_run_paths[biome].append(position)


func _on_node_selected(node_data: Dictionary):
	current_node = node_data.duplicate(true)
	current_node.erase("skip_visit_record")
	if bool(node_data.get("skip_visit_record", false)):
		SaveManager.save_mid_run_state()
		return
	record_biome_path_step(node_data)
	var node_id = str(node_data.get("id", ""))
	if node_id != "":
		current_run_visited_nodes.append(node_id)
	_ensure_room_state(str(node_data.get("id", "")))
	mark_room_visited(str(node_data.get("id", "")))
	
	SaveManager.save_mid_run_state()


# --- LOOT LOGIC ---
func prepare_victory_loot(node_data: Dictionary, enemy_defeat_count_before: int = 0):
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
						if is_story_mode:
							if enemy_defeat_count_before <= 0:
								for raw_drop in enemy_res.item_drops:
									var drop_id = str(raw_drop).strip_edges()
									if drop_id == "":
										continue
									var reward_kind = _resolve_reward_kind(drop_id)
									enemy_loot_pool.append({
										"id": drop_id,
										"min": 1,
										"max": 1,
										"is_card": reward_kind == "card",
										"is_item": reward_kind == "item"
									})
							room_loot_pool = []
						else:
							var power_reward = _roll_power_matched_loot(enemy_res.loot_power)
							if not power_reward.is_empty():
								enemy_loot_pool.append(power_reward)
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
			var reward_kind = _resolve_reward_kind(item_def)
			reward = {
				"id": item_def,
				"amount": 1,
				"name": _get_reward_display_name(item_def, 1),
				"is_card": reward_kind == "card",
				"is_item": reward_kind == "item"
			}
			
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
				"name": _get_reward_display_name(item_id, amount)
			}
			
			if item_id == "gold":
				gold += amount
				world_state.global.gold = gold
			else:
				var reward_kind = "card" if bool(item_def.get("is_card", false)) else ("item" if bool(item_def.get("is_item", false)) else _resolve_reward_kind(item_id))
				reward["is_card"] = reward_kind == "card"
				reward["is_item"] = reward_kind == "item"
				if bool(item_def.get("is_card", false)):
					add_card_to_collection(item_id)
				else:
					add_item(item_id)
		
		pending_loot.append(reward)
		run_loot.append(reward)

func _roll_power_matched_loot(loot_power: int) -> Dictionary:
	if loot_power <= 0:
		return {}
	var pool = _get_rewards_matching_power(loot_power)
	if pool.is_empty():
		return {}
	return pool.pick_random()

func _get_rewards_matching_power(target_power: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	pool.append_array(_collect_power_rewards_from_dir(CARDS_ROOT, target_power, true))
	pool.append_array(_collect_power_rewards_from_dir(ITEMS_ROOT, target_power, false))
	return pool

func _collect_power_rewards_from_dir(root: String, target_power: int, is_card: bool) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(root):
		return rewards
	var dir = DirAccess.open(root)
	if dir == null:
		return rewards
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			if file_name.begins_with("_"):
				file_name = dir.get_next()
				continue
			var resource_path = "%s/%s" % [root, file_name]
			var resource = load(resource_path)
			if resource == null:
				push_warning("GameManager: Failed to load reward resource: %s" % resource_path)
				file_name = dir.get_next()
				continue
			if is_card:
				var card_res := resource as CardData
				if card_res == null:
					push_warning("GameManager: Skipping non-CardData resource in card reward pool: %s (%s)" % [resource_path, resource.get_class()])
					file_name = dir.get_next()
					continue
				if int(card_res.card_power) == target_power and card_res.card_id != "":
					rewards.append({
						"id": str(card_res.card_id),
						"min": 1,
						"max": 1,
						"is_card": true
					})
			else:
				var item_res := resource as ItemData
				if item_res == null:
					push_warning("GameManager: Skipping non-ItemData resource in item reward pool: %s (%s)" % [resource_path, resource.get_class()])
					file_name = dir.get_next()
					continue
				if int(item_res.item_power) == target_power and item_res.item_id != "":
					rewards.append({
						"id": str(item_res.item_id),
						"min": 1,
						"max": 1,
						"is_card": false
					})
		file_name = dir.get_next()
	dir.list_dir_end()
	return rewards

func _get_reward_display_name(item_id: String, amount: int) -> String:
	if item_id == "gold":
		return str(amount) + " " + item_id.replace("_", " ").capitalize()
	var card_path = "%s/%s.tres" % [CARDS_ROOT, item_id]
	if ResourceLoader.exists(card_path):
		var card_res = load(card_path) as CardData
		if card_res:
			return LocalizationManager.localized_resource_name(card_res, card_res.name)
	var item_path = "%s/%s.tres" % [ITEMS_ROOT, item_id]
	if ResourceLoader.exists(item_path):
		var item_res = load(item_path) as ItemData
		if item_res:
			return LocalizationManager.localized_resource_name(item_res, item_res.name)
	return item_id.replace("_", " ").capitalize()

func _resolve_reward_kind(item_id: String) -> String:
	if item_id == "" or item_id == "gold":
		return "gold"
	var card_path = "%s/%s.tres" % [CARDS_ROOT, item_id]
	if ResourceLoader.exists(card_path):
		return "card"
	var item_path = "%s/%s.tres" % [ITEMS_ROOT, item_id]
	if ResourceLoader.exists(item_path):
		return "item"
	return "item"


func _on_combat_won():
	register_room_victory(current_node, current_hp)
	SaveManager.save_mid_run_state()
	
	if not pending_loot.is_empty():
		get_tree().change_scene_to_file("res://features/ui/LootScene.tscn")
	else:
		get_tree().change_scene_to_file(consume_pending_post_battle_scene(_get_default_overworld_scene()))

func register_room_victory(node_data: Dictionary, remaining_hp: int):
	current_hp = remaining_hp
	pending_post_battle_scene = ""
	var enemy_defeat_count_before := 0

	var node_id = str(node_data.get("id", ""))
	if node_id != "":
		if not completed_nodes.has(node_id):
			completed_nodes.append(node_id)
		_ensure_room_state(node_id)
		world_state.rooms[node_id].cleared = true
		world_state.rooms[node_id].visited = true
		if _is_boss_room(node_data):
			world_state.rooms[node_id].completed = true
		var room_path = str(node_data.get("room_resource_path", ""))
		if room_path != "" and ResourceLoader.exists(room_path):
			var room_res = load(room_path) as RoomData
			if room_res and room_res.enemy_id != "":
				_ensure_enemy_state(room_res.enemy_id)
				enemy_defeat_count_before = int(world_state.enemies[room_res.enemy_id].get("defeated", 0))
				world_state.enemies[room_res.enemy_id].defeated += 1
		refresh_story_room_completions()
		if _is_boss_room(node_data):
			SignalBus.map_node_completed.emit(node_id)

	prepare_victory_loot(node_data, enemy_defeat_count_before)

	if _is_boss_room(node_data):
		var biome = str(node_data.get("biome", ""))
		mark_biome_cleared(biome)
		var next_biome = _get_next_biome_key(biome)
		unlock_biome(next_biome)
		_ensure_story_biomes_generated(_get_story_biome_generation_targets(next_biome, false))
		if DataManager and DataManager.has_method("prioritize_story_assets"):
			DataManager.prioritize_story_assets(next_biome)
		_move_player_to_random_next_biome(node_data)
		if is_battle_mode:
			pending_post_battle_scene = get_active_biome_map_scene_path()
		elif next_biome != "" and not has_entered_story_biome(next_biome):
			mark_story_biome_entered(next_biome)
			queue_story_sequence(next_biome, get_story_line_scene_path())
			pending_post_battle_scene = get_story_chapter_sequence_scene_path()
		else:
			pending_post_battle_scene = get_story_line_scene_path()
	else:
		_set_player_position_from_node(node_data)
		if not is_battle_mode:
			pending_post_battle_scene = "res://features/encounters/EventScene.tscn"

	SaveManager.save_mid_run_state()

func consume_pending_post_battle_scene(fallback_scene: String) -> String:
	var scene = pending_post_battle_scene if pending_post_battle_scene != "" else fallback_scene
	pending_post_battle_scene = ""
	return scene

func peek_pending_post_battle_scene(fallback_scene: String) -> String:
	return pending_post_battle_scene if pending_post_battle_scene != "" else fallback_scene

func _get_default_overworld_scene() -> String:
	return get_active_biome_map_scene_path()

func _is_boss_room(node_data: Dictionary) -> bool:
	var node_type = str(node_data.get("type", ""))
	var node_id = str(node_data.get("id", ""))
	return node_type == "boss" or node_id.ends_with("_boss")

func _set_player_position_from_node(node_data: Dictionary):
	player_biome = str(node_data.get("biome", player_biome))
	selected_story_biome = player_biome
	if is_battle_mode:
		player_grid_pos = Vector2i(int(node_data.get("layer", 0)), int(node_data.get("column", 0)))
	else:
		player_grid_pos = Vector2i(int(node_data.get("column", 0)), int(node_data.get("layer", 0)))

func _move_player_to_random_next_biome(node_data: Dictionary):
	var current_biome = str(node_data.get("biome", ""))
	var next_biome = _get_next_biome_key(current_biome)
	if next_biome == "":
		_set_player_position_from_node(node_data)
		return

	var next_biome_nodes: Array[Dictionary] = []
	for raw_key in run_map.keys():
		var candidate = run_map[raw_key]
		if str(candidate.get("biome", "")) == next_biome:
			next_biome_nodes.append(candidate)

	if next_biome_nodes.is_empty():
		_set_player_position_from_node(node_data)
		return

	var next_node: Dictionary = {}
	if is_battle_mode:
		next_node = _find_home_node_for_biome(next_biome)
	else:
		var story_home_id = get_biome_home_node_id(next_biome)
		if story_home_id != "":
			next_node = _get_run_node_by_id(story_home_id)
	if next_node.is_empty():
		next_node = next_biome_nodes.pick_random()
	if is_battle_mode:
		if get_biome_home_node_id(next_biome) == "":
			set_biome_home_node_id(next_biome, str(next_node.get("id", "")))
		_set_player_position_from_node(next_node)
		return
	player_biome = next_biome
	selected_story_biome = next_biome
	player_grid_pos = Vector2i(int(next_node.get("column", 0)), int(next_node.get("layer", 0)))
	if get_biome_home_node_id(next_biome) == "":
		set_biome_home_node_id(next_biome, str(next_node.get("id", "")))

func _get_next_biome_key(current_biome: String) -> String:
	current_biome = _normalize_story_biome_key(current_biome)
	var order = BATTLE_BIOME_ORDER if is_battle_mode else STORY_BIOME_ORDER
	var biome_index = order.find(current_biome)
	if biome_index == -1:
		return ""
	var next_index = biome_index + 1
	if next_index >= order.size():
		return ""
	return str(order[next_index])

func _normalize_story_biome_key(biome: String) -> String:
	return "tutorial" if str(biome) == "home" else str(biome)

func _on_combat_lost():
	get_tree().call_deferred("change_scene_to_file", "res://features/ui/DeathScreen.tscn")

func _get_normalized_class_id() -> String:
	var raw = player_class.to_lower()
	match raw:
		"archivist":
			return "scholar"
		"berserker":
			return "warrior"
		"illusionist":
			return "alchemist"
		_:
			return raw

func _get_max_class_level() -> int:
	var class_id = _get_normalized_class_id()
	if GameData.CLASS_STATS.has(class_id):
		return GameData.CLASS_STATS[class_id].size()
	return 1

func _get_class_stats_for_level(level: int) -> Dictionary:
	return GameData.get_stats(_get_normalized_class_id(), level)

func _apply_level_stats(stats: Dictionary):
	if stats.is_empty():
		return
	var old_hp_total = player_hp_total
	max_hp = int(stats.get("max_hp", max_hp))
	base_energy = int(stats.get("energy", base_energy))
	base_attack = int(stats.get("player_attack", base_attack))
	base_defense = int(stats.get("player_defense", base_defense))
	player_attack = base_attack
	player_defense = base_defense
	recalculate_player_totals()
	
	if player_hp_total > old_hp_total:
		current_hp += (player_hp_total - old_hp_total)
	current_hp = clamp(current_hp, 0, player_hp_total)
	SignalBus.hp_changed.emit(current_hp, player_hp_total)

func _ensure_minimum_active_pairs_for_level():
	var required_pairs = max(1, player_level)
	var fallback_card_ids = ["sword", "shield", "heart"]

	while get_active_deck_unique_pair_count() < required_pairs:
		var next_pair_id = _find_next_missing_pair_card_id()
		if next_pair_id == "":
			for fallback_id in fallback_card_ids:
				if _count_occurrences(active_deck, fallback_id) < 2:
					next_pair_id = fallback_id
					break
		if next_pair_id == "":
			break
		while _count_occurrences(active_deck, next_pair_id) < 2:
			active_deck.append(next_pair_id)
			if _count_occurrences(player_deck, next_pair_id) < _count_occurrences(active_deck, next_pair_id):
				player_deck.append(next_pair_id)

func get_active_deck_unique_pair_count() -> int:
	return _count_unique_pairs(active_deck)

func _find_next_missing_pair_card_id() -> String:
	var candidate_ids: Array = []
	for card_id in player_deck:
		var text_id = str(card_id)
		if not candidate_ids.has(text_id):
			candidate_ids.append(text_id)
	for card_id in active_deck:
		var text_id = str(card_id)
		if not candidate_ids.has(text_id):
			candidate_ids.append(text_id)
	for card_id in candidate_ids:
		if _count_occurrences(active_deck, card_id) < 2:
			return card_id
	return ""

func _count_unique_pairs(source: Array) -> int:
	var counts := {}
	for entry in source:
		counts[entry] = int(counts.get(entry, 0)) + 1
	var total_pairs := 0
	for count in counts.values():
		if int(count) >= 2:
			total_pairs += 1
	return total_pairs

func _count_occurrences(source: Array, value) -> int:
	var count = 0
	for entry in source:
		if entry == value:
			count += 1
	return count

func _matches_numeric_condition(actual: int, condition: Dictionary) -> bool:
	if condition.has("equals"):
		return actual == int(condition.get("equals", 0))
	if condition.has("max"):
		return actual <= int(condition.get("max", 0))
	return actual >= int(condition.get("value", condition.get("min", 0)))

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	SignalBus.hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		SignalBus.combat_lost.emit()

# Helper function for MapGenerator to check for specific overrides
func get_fixed_type(col: int, layer: int) -> String:
	var pos = Vector2i(col, layer)
	return fixed_nodes.get(pos, "")
