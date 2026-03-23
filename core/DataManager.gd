extends Node

# res://core/DataManager.gd
# Centralized registry and cache with time-budgeted background loading.
# Prioritizes the current chapter and next chapter before streaming the rest.

signal initialization_progress(percent: float, current_task: String)
signal initialization_complete
signal transition_loading_resumed

const PATHS = {
	"cards": "res://data/cards/",
	"items": "res://data/items/",
	"rooms": "res://data/rooms/",
	"enemies": "res://data/enemies/"
}
const MAP_DATA_PATH = "res://data/map/map_data.tres"
const GLOBAL_DEFAULT_ROOM_PATH = "res://data/rooms/default_battle.tres"
const BIOME_ORDER = ["home", "town", "forest", "ice_caves", "desert", "swamp", "abyss", "void", "the_core"]
const PERFORMANCE_SENSITIVE_SCENE_NAMES = {
	"StoryCutscene": true,
	"StoryChapterSequence": true
}
const PERFORMANCE_SENSITIVE_SCENE_PATHS = {
	"res://features/ui/StoryCutscene.tscn": true,
	"res://features/map/StoryChapterSequence.tscn": true
}
const BIOME_ROOM_SOURCE = {
	"home": "tutorial",
	"town": "town",
	"forest": "forest",
	"ice_caves": "ice_caves",
	"desert": "desert",
	"swamp": "swamp",
	"abyss": "abyss",
	"void": "void",
	"the_core": "the_core"
}

# CONFIG: Time Budget (in microseconds)
const FRAME_BUDGET_USEC = 1000

var _registry: Dictionary = {
	"cards": {},
	"items": {},
	"rooms": {},
	"enemies": {"all": [], "by_biome": {}}
}
var _resource_cache: Dictionary = {}
var _room_paths_by_biome: Dictionary = {}
var _enemy_paths_by_biome: Dictionary = {}
var is_initialized: bool = false
var _load_entries: Array[Dictionary] = []
var _queued_paths: Dictionary = {}
var _total_to_load: int = 0
var _processed_count: int = 0
var _is_processing_queue: bool = false
var _is_transition_paused: bool = false

func _ready():
	_start_smooth_init()

func _start_smooth_init():
	_index_paths_only("cards")
	_index_paths_only("items")
	_index_room_paths_only()
	_index_enemy_paths_only()
	_refresh_load_plan("", "", false)
	_ensure_background_loader_running()

func prioritize_story_assets(current_biome: String = "", next_biome: String = "", include_completed_biomes: bool = false):
	_refresh_load_plan(current_biome, next_biome, include_completed_biomes)
	_ensure_background_loader_running()

func prioritize_story_assets_for_resume(current_biome: String = "", next_biome: String = ""):
	prioritize_story_assets(current_biome, next_biome, true)

func pause_for_scene_transition():
	_is_transition_paused = true

func resume_after_scene_transition():
	var was_paused = _is_transition_paused
	_is_transition_paused = false
	if was_paused:
		transition_loading_resumed.emit()
	_ensure_background_loader_running()

func _refresh_load_plan(current_biome: String = "", next_biome: String = "", include_completed_biomes: bool = false):
	var priority_biomes = _get_priority_biomes(current_biome, next_biome, include_completed_biomes)
	_load_entries.clear()
	_queued_paths.clear()

	_queue_path(MAP_DATA_PATH, "Preparing chapter maps...")
	_queue_path(GLOBAL_DEFAULT_ROOM_PATH, "Preparing chapter maps...")

	for biome in priority_biomes:
		_queue_biome_assets(biome, "Preparing %s..." % biome.replace("_", " ").capitalize())

	_queue_global_rewards("Preparing cards and items...")

	_total_to_load = _load_entries.size()
	_processed_count = 0
	is_initialized = _total_to_load == 0
	if is_initialized:
		initialization_complete.emit()

func _ensure_background_loader_running():
	if _is_processing_queue or _total_to_load <= 0:
		return
	_process_background_loading()

func _process_background_loading():
	_is_processing_queue = true
	var start_time = Time.get_ticks_usec()

	while _processed_count < _total_to_load:
		if _should_pause_background_loading():
			await _wait_for_background_loading_resume()
			start_time = Time.get_ticks_usec()
			continue

		var entry = _load_entries[_processed_count]
		_maybe_cache_resource(str(entry.get("path", "")))
		_processed_count += 1

		var current_time = Time.get_ticks_usec()
		if (current_time - start_time) > FRAME_BUDGET_USEC:
			var progress = float(_processed_count) / max(1.0, float(_total_to_load))
			initialization_progress.emit(progress, str(entry.get("label", "Streaming Memoria...")))
			await get_tree().process_frame
			if _should_pause_background_loading():
				await _wait_for_background_loading_resume()
			start_time = Time.get_ticks_usec()

	_is_processing_queue = false
	is_initialized = true
	initialization_complete.emit()
	print("[DataManager] Priority background loading complete.")

func _should_pause_background_loading() -> bool:
	return _is_transition_paused or _is_performance_sensitive_scene_active()

func _wait_for_background_loading_resume():
	while _should_pause_background_loading():
		if _is_transition_paused:
			await transition_loading_resumed
		else:
			await get_tree().process_frame

func _is_performance_sensitive_scene_active() -> bool:
	var tree = get_tree()
	if tree == null:
		return false
	var current_scene = tree.current_scene
	if current_scene == null:
		return false
	if PERFORMANCE_SENSITIVE_SCENE_NAMES.has(str(current_scene.name)):
		return true
	return PERFORMANCE_SENSITIVE_SCENE_PATHS.has(str(current_scene.scene_file_path))

func _index_paths_only(type: String):
	var root_path = PATHS[type]
	if not DirAccess.dir_exists_absolute(root_path):
		return
	var dir = DirAccess.open(root_path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path = root_path + file_name
			if not _registry[type].has("common"):
				_registry[type]["common"] = []
			_registry[type]["common"].append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _index_room_paths_only():
	var root = PATHS["rooms"]
	if not DirAccess.dir_exists_absolute(root):
		return
	for biome in BIOME_ORDER:
		var source_biome = str(BIOME_ROOM_SOURCE.get(biome, biome))
		var biome_path = root + source_biome + "/"
		if not DirAccess.dir_exists_absolute(biome_path):
			continue
		_registry["rooms"][biome] = {"tiers": {}, "types": {"unassigned": []}}
		_room_paths_by_biome[biome] = []
		var dir = DirAccess.open(biome_path)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = biome_path + file_name
				_registry["rooms"][biome]["types"]["unassigned"].append(full_path)
				_room_paths_by_biome[biome].append(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()

func _index_enemy_paths_only():
	var root_path = PATHS["enemies"]
	if not DirAccess.dir_exists_absolute(root_path):
		return
	var dir = DirAccess.open(root_path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			_registry["enemies"]["all"].append(root_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _queue_biome_assets(biome: String, label: String):
	for room_path in _room_paths_by_biome.get(biome, []):
		_queue_path(room_path, label)
	for enemy_path in _get_enemy_paths_for_biome(biome):
		_queue_path(enemy_path, label)

func _queue_global_rewards(label: String):
	for type in ["cards", "items"]:
		for rarity in _registry[type].keys():
			for path in _registry[type][rarity]:
				_queue_path(path, label)

func _queue_path(path: String, label: String):
	if path == "" or _queued_paths.has(path) or _resource_cache.has(path):
		return
	if not ResourceLoader.exists(path):
		return
	_queued_paths[path] = true
	_load_entries.append({"path": path, "label": label})

func _get_priority_biomes(current_biome: String = "", next_biome: String = "", include_completed_biomes: bool = false) -> Array[String]:
	var result: Array[String] = []
	var resolved_current = current_biome
	if resolved_current == "":
		resolved_current = _get_current_priority_biome()
	if resolved_current == "":
		resolved_current = BIOME_ORDER[0]
	if include_completed_biomes:
		for biome in _get_completed_biomes():
			if BIOME_ORDER.has(biome) and not result.has(biome):
				result.append(biome)
	if BIOME_ORDER.has(resolved_current) and not result.has(resolved_current):
		result.append(resolved_current)

	var resolved_next = next_biome
	if resolved_next == "":
		resolved_next = _get_next_biome(resolved_current)
	if resolved_next != "" and resolved_next != resolved_current and BIOME_ORDER.has(resolved_next) and not result.has(resolved_next):
		result.append(resolved_next)
	return result

func _get_completed_biomes() -> Array[String]:
	var result: Array[String] = []
	if GameManager == null:
		return result
	for biome in BIOME_ORDER:
		if GameManager.is_biome_cleared(biome):
			result.append(biome)
	return result

func _get_current_priority_biome() -> String:
	if GameManager == null:
		return BIOME_ORDER[0]
	if GameManager.selected_story_biome != "":
		return GameManager.selected_story_biome
	if GameManager.player_biome != "":
		return GameManager.player_biome
	var unlocked = GameManager.get_unlocked_story_biomes()
	return unlocked[0] if not unlocked.is_empty() else BIOME_ORDER[0]

func _get_next_biome(current_biome: String) -> String:
	var current_index = BIOME_ORDER.find(current_biome)
	if current_index == -1:
		return ""
	if current_index + 1 >= BIOME_ORDER.size():
		return ""
	return BIOME_ORDER[current_index + 1]

func _get_enemy_paths_for_biome(biome: String) -> Array[String]:
	if _enemy_paths_by_biome.has(biome):
		return _enemy_paths_by_biome[biome]

	var enemy_paths: Array[String] = []
	var seen: Dictionary = {}
	for room_path in _room_paths_by_biome.get(biome, []):
		var enemy_id = _extract_enemy_id_from_room_file(room_path)
		if enemy_id == "":
			continue
		var enemy_path = "%s%s.tres" % [PATHS["enemies"], enemy_id]
		if seen.has(enemy_path) or not ResourceLoader.exists(enemy_path):
			continue
		seen[enemy_path] = true
		enemy_paths.append(enemy_path)
	_enemy_paths_by_biome[biome] = enemy_paths
	return enemy_paths

func _extract_enemy_id_from_room_file(room_path: String) -> String:
	if not FileAccess.file_exists(room_path):
		return ""
	var file = FileAccess.open(room_path, FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if not line.begins_with("enemy_id ="):
			continue
		var raw_value = line.trim_prefix("enemy_id =").strip_edges()
		return raw_value.trim_prefix("\"").trim_suffix("\"")
	return ""

func _maybe_cache_resource(path: String) -> Resource:
	if path == "":
		return null
	if _resource_cache.has(path):
		return _resource_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res:
		_resource_cache[path] = res
		_update_registry_metadata(res, path)
	return res

func _update_registry_metadata(res: Resource, path: String):
	if "cards" in path or "items" in path:
		var type = "cards" if "cards" in path else "items"
		var rarity = str(res.get("rarity") if res.get("rarity") != null else "common").to_lower()
		if not _registry[type].has(rarity):
			_registry[type][rarity] = []
		if not _registry[type][rarity].has(path):
			_registry[type][rarity].append(path)
	elif "rooms" in path:
		var biome = str(res.get("biome") if res.get("biome") != null else "town").to_lower()
		if not _registry["rooms"].has(biome):
			return
		var tier = int(res.get("difficulty_tier") if res.get("difficulty_tier") != null else 1)
		var room_type = str(res.get("type") if res.get("type") != null else "battle")
		if not _registry["rooms"][biome]["tiers"].has(tier):
			_registry["rooms"][biome]["tiers"][tier] = []
		if not _registry["rooms"][biome]["tiers"][tier].has(path):
			_registry["rooms"][biome]["tiers"][tier].append(path)
		if not _registry["rooms"][biome]["types"].has(room_type):
			_registry["rooms"][biome]["types"][room_type] = []
		if not _registry["rooms"][biome]["types"][room_type].has(path):
			_registry["rooms"][biome]["types"][room_type].append(path)
	elif "enemies" in path:
		var biome = str(res.get("biome") if res.get("biome") != null else "town").to_lower()
		if not _registry["enemies"]["by_biome"].has(biome):
			_registry["enemies"]["by_biome"][biome] = []
		if not _registry["enemies"]["by_biome"][biome].has(path):
			_registry["enemies"]["by_biome"][biome].append(path)

func get_random_by_rarity(type: String, rarity: String, count: int = 3) -> Array:
	var r_key = rarity.to_lower()
	if not _registry[type].has(r_key):
		r_key = "common"
	var pool = _registry[type].get(r_key, [])
	if pool.is_empty():
		return []
	var shuffled = pool.duplicate()
	shuffled.shuffle()
	var results = []
	for i in range(min(count, shuffled.size())):
		results.append(get_resource(shuffled[i]))
	return results

func get_random_room(biome: String, tier: int = -1, type: String = "") -> Resource:
	if not _registry["rooms"].has(biome):
		return null
	var pool = []
	if type != "" and _registry["rooms"][biome]["types"].has(type):
		pool = _registry["rooms"][biome]["types"][type]
	elif tier > 0 and _registry["rooms"][biome]["tiers"].has(tier):
		pool = _registry["rooms"][biome]["tiers"][tier]
	if pool.is_empty():
		pool = _registry["rooms"][biome]["types"].get("unassigned", [])
	if pool.is_empty():
		return null
	return get_resource(pool.pick_random())

func get_resource(path: String) -> Resource:
	return _maybe_cache_resource(path)
