extends Node

# res://core/DataManager.gd
# Centralized registry and cache with Time-Budgeted Throttling.
# Designed to eliminate UI latency by limiting background work per frame.

signal initialization_progress(percent: float, current_task: String)
signal initialization_complete

const PATHS = {
	"cards": "res://data/cards/",
	"items": "res://data/items/",
	"rooms": "res://data/rooms/"
}

# CONFIG: Time Budget (in microseconds)
# 2000 usec = 2ms. A 60fps frame is ~16.6ms. 
# We use only a tiny fraction to ensure UI remains perfectly smooth.
const FRAME_BUDGET_USEC = 2000 

var _registry: Dictionary = {"cards": {}, "items": {}, "rooms": {}}
var _resource_cache: Dictionary = {}
var is_initialized: bool = false
var _all_paths_to_load: Array = []
var _total_to_load: int = 0
var _processed_count: int = 0

func _ready():
	_start_smooth_init()

func _start_smooth_init():
	# 1. IMMEDIATE: Map paths only (Sub-millisecond operation)
	_index_paths_only("cards")
	_index_paths_only("items")
	_index_room_paths_only()
	
	# Prepare the master list for the throttled loader
	_all_paths_to_load.clear()
	for type in ["cards", "items"]:
		for rarity in _registry[type]:
			_all_paths_to_load.append_array(_registry[type][rarity])
	for biome in _registry["rooms"]:
		for type_key in _registry["rooms"][biome]["types"]:
			_all_paths_to_load.append_array(_registry["rooms"][biome]["types"][type_key])
	
	_total_to_load = _all_paths_to_load.size()
	_processed_count = 0
	
	# 2. THROTTLED BACKGROUND LOAD
	_process_background_loading()

func _process_background_loading():
	var start_time = Time.get_ticks_usec()
	
	while _processed_count < _total_to_load:
		var path = _all_paths_to_load[_processed_count]
		
		# Perform the load
		if not _resource_cache.has(path):
			var res = load(path)
			if res:
				_resource_cache[path] = res
				_update_registry_metadata(res, path)
		
		_processed_count += 1
		
		# CHECK BUDGET: If we've spent more than 2ms, yield to the next frame
		var current_time = Time.get_ticks_usec()
		if (current_time - start_time) > FRAME_BUDGET_USEC:
			# Signal progress to UI
			var progress = float(_processed_count) / _total_to_load
			initialization_progress.emit(progress, "Streaming Memoria...")
			
			# Wait for next frame
			await get_tree().process_frame
			# Reset the frame timer for the next batch
			start_time = Time.get_ticks_usec()
	
	is_initialized = true
	initialization_complete.emit()
	print("[DataManager] Smooth background loading complete.")

# --- INDEXING LOGIC (METADATA ONLY) ---

func _index_paths_only(type: String):
	var root_path = PATHS[type]
	if not DirAccess.dir_exists_absolute(root_path): return
	var dir = DirAccess.open(root_path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path = root_path + file_name
			if not _registry[type].has("common"): _registry[type]["common"] = []
			_registry[type]["common"].append(full_path)
		file_name = dir.get_next()

func _index_room_paths_only():
	var root = PATHS["rooms"]
	if not DirAccess.dir_exists_absolute(root): return
	var biomes = ["town", "forest", "ice_caves", "swamp", "mountain", "ruins", "desert", "castle", "abyss", "void", "the_core"]
	for biome in biomes:
		var biome_path = root + biome + "/"
		if not DirAccess.dir_exists_absolute(biome_path): continue
		_registry["rooms"][biome] = { "tiers": {}, "types": {"unassigned": []} }
		var dir = DirAccess.open(biome_path)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				_registry["rooms"][biome]["types"]["unassigned"].append(biome_path + file_name)
			file_name = dir.get_next()

func _update_registry_metadata(res: Resource, path: String):
	if "cards" in path or "items" in path:
		var type = "cards" if "cards" in path else "items"
		var rarity = str(res.get("rarity") if res.get("rarity") != null else "common").to_lower()
		if not _registry[type].has(rarity): _registry[type][rarity] = []
		if not path in _registry[type][rarity]: _registry[type][rarity].append(path)
	elif "rooms" in path:
		var biome = str(res.get("biome") if res.get("biome") != null else "town").to_lower()
		if not _registry["rooms"].has(biome): return
		var tier = int(res.get("difficulty_tier") if res.get("difficulty_tier") != null else 1)
		var r_type = str(res.get("type") if res.get("type") != null else "battle")
		if not _registry["rooms"][biome]["tiers"].has(tier): _registry["rooms"][biome]["tiers"][tier] = []
		_registry["rooms"][biome]["tiers"][tier].append(path)
		if not _registry["rooms"][biome]["types"].has(r_type): _registry["rooms"][biome]["types"][r_type] = []
		_registry["rooms"][biome]["types"][r_type].append(path)

# --- RETRIEVAL API (LAZY-LOAD READY) ---

func get_random_by_rarity(type: String, rarity: String, count: int = 3) -> Array:
	var r_key = rarity.to_lower()
	if not _registry[type].has(r_key): r_key = "common"
	var pool = _registry[type].get(r_key, [])
	if pool.is_empty(): return []
	var shuffled = pool.duplicate(); shuffled.shuffle()
	var results = []
	for i in range(min(count, shuffled.size())):
		results.append(get_resource(shuffled[i]))
	return results

func get_random_room(biome: String, tier: int = -1, type: String = "") -> Resource:
	if not _registry["rooms"].has(biome): return null
	var pool = []
	if type != "" and _registry["rooms"][biome]["types"].has(type):
		pool = _registry["rooms"][biome]["types"][type]
	elif tier > 0 and _registry["rooms"][biome]["tiers"].has(tier):
		pool = _registry["rooms"][biome]["tiers"][tier]
	if pool.is_empty(): pool = _registry["rooms"][biome]["types"].get("unassigned", [])
	if pool.is_empty(): return null
	return get_resource(pool.pick_random())

func get_resource(path: String) -> Resource:
	if _resource_cache.has(path): return _resource_cache[path]
	if ResourceLoader.exists(path):
		var res = load(path)
		_resource_cache[path] = res
		_update_registry_metadata(res, path)
		return res
	return null
