extends Node

# res://features/map/MapGenerator.gd
# Story-mode map generator based on the battle-mode biome grid structure.

signal progress_updated(percent: float, description: String)

const BIOME_ORDER = ["home", "town", "forest", "ice_caves", "desert", "swamp", "abyss", "void", "the_core"]
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
const ROOM_ROOT = "res://data/rooms/"
const GLOBAL_DEFAULT_ROOM_PATH = "res://data/rooms/default_battle.tres"
const INITIAL_STORY_BIOMES = ["home", "town"]

var _room_pool_by_biome: Dictionary = {}
var _used_room_paths_by_biome: Dictionary = {}
var _node_visual_scale_rng := RandomNumberGenerator.new()

func generate_new_map() -> Dictionary:
	_room_pool_by_biome.clear()
	_used_room_paths_by_biome.clear()
	_node_visual_scale_rng.randomize()
	return await expand_story_map({}, INITIAL_STORY_BIOMES)

func expand_story_map(existing_map: Dictionary, target_biomes: Array) -> Dictionary:
	var normalized_targets = _normalize_target_biomes(target_biomes)
	for target_index in range(normalized_targets.size()):
		var biome_key = normalized_targets[target_index]
		var progress = float(target_index) / max(1.0, float(normalized_targets.size()))
		progress_updated.emit(progress, "Mapping the %s..." % biome_key.capitalize())
		await get_tree().process_frame
	var map = expand_story_map_immediate(existing_map, target_biomes)
	progress_updated.emit(1.0, "Synchronization complete.")
	return map

func expand_story_map_immediate(existing_map: Dictionary, target_biomes: Array) -> Dictionary:
	_node_visual_scale_rng.randomize()
	var map: Dictionary = existing_map.duplicate(true)
	var normalized_targets = _normalize_target_biomes(target_biomes)
	for biome_key in normalized_targets:
		var biome_index = BIOME_ORDER.find(biome_key)
		if biome_index == -1 or _biome_exists_in_map(map, biome_key):
			continue
		if not _used_room_paths_by_biome.has(biome_key):
			_used_room_paths_by_biome[biome_key] = {}
		_generate_biome_into_map(map, biome_key, biome_index)
	return map

func reroll_incomplete_story_rooms(existing_map: Dictionary, room_states: Dictionary, target_biomes: Array = []) -> Dictionary:
	var updated_map := existing_map.duplicate(true)
	_room_pool_by_biome.clear()
	_used_room_paths_by_biome.clear()
	_node_visual_scale_rng.randomize()
	var biomes_to_reroll = _normalize_target_biomes(target_biomes if not target_biomes.is_empty() else _get_biomes_present_in_map(updated_map))

	for biome in biomes_to_reroll:
		var completed_paths: Dictionary = {}
		for raw_id in updated_map.keys():
			var node_id = str(raw_id)
			var node = updated_map[raw_id]
			if str(node.get("biome", "")) != biome:
				continue
			var state = room_states.get(node_id, {})
			if state.get("completed", false):
				var locked_path = str(node.get("room_resource_path", ""))
				if locked_path != "":
					completed_paths[locked_path] = true

		_used_room_paths_by_biome[biome] = completed_paths

		for raw_id in updated_map.keys():
			var node_id = str(raw_id)
			var node = updated_map[raw_id]
			if str(node.get("biome", "")) != biome:
				continue
			var state = room_states.get(node_id, {})
			if state.get("completed", false):
				continue

			var is_home = bool(node.get("is_home", false))
			var room_res = _load_story_home_room_for_biome(biome) if is_home else _pick_room_for_biome(biome)
			var fallback_type = str(node.get("base_type", node.get("type", "battle")))
			node["room_resource_path"] = room_res.resource_path if room_res else _get_default_room_path_for_biome(biome)
			node["name"] = room_res.room_name if room_res else str(node.get("name", "Unknown Encounter"))
			node["initial_dialog"] = room_res.initial_dialog if room_res else str(node.get("initial_dialog", ""))
			node["base_type"] = "home" if is_home else (room_res.type if room_res else fallback_type)
			node["type"] = "home" if is_home else str(node.get("base_type", fallback_type))
			node["node_visual_scale"] = _get_random_node_visual_scale()
			if room_res and room_res.map_icon:
				node["custom_icon_path"] = room_res.map_icon.resource_path
			else:
				node.erase("custom_icon_path")
			updated_map[node_id] = node

	return updated_map

func _generate_biome_into_map(map: Dictionary, biome_key: String, biome_index: int):
	var size = _get_grid_size_for_biome_index(biome_index)
	var layer_offset = _get_layer_offset_for_biome_index(biome_index)
	var home_coord = _pick_random_coord(size)
	var exit_coord = Vector2i(size - 1, size - 1)
	if exit_coord == home_coord:
		exit_coord = Vector2i(0, size - 1)
	var home_room_res = _load_story_home_room_for_biome(biome_key)

	for row in range(size):
		for col in range(size):
			var node_id = _build_node_id(biome_key, row, col)
			var is_home = home_coord == Vector2i(row, col)
			var room_res = home_room_res if is_home else _pick_room_for_biome(biome_key)
			var fallback_type = "home" if is_home else _default_room_type_for_grid_position(row, col, size)
			var data = {
				"id": node_id,
				"name": room_res.room_name if room_res else "%s %d,%d" % [biome_key.capitalize(), row + 1, col + 1],
				"type": "home" if is_home else (room_res.type if room_res else fallback_type),
				"base_type": room_res.type if room_res else fallback_type,
				"biome": biome_key,
				"biome_index": biome_index,
				"layer": layer_offset + row,
				"column": col,
				"difficulty": size,
				"room_resource_path": room_res.resource_path if room_res else _get_default_room_path_for_biome(biome_key),
				"initial_dialog": room_res.initial_dialog if room_res else "",
				"connections": [],
				"is_home": is_home,
				"node_visual_scale": _get_random_node_visual_scale()
			}
			if room_res and room_res.map_icon:
				data["custom_icon_path"] = room_res.map_icon.resource_path
			map[node_id] = data

	for row in range(size):
		for col in range(size):
			var source_id = _build_node_id(biome_key, row, col)
			var source = map[source_id]
			var neighbors = [
				Vector2i(row - 1, col),
				Vector2i(row + 1, col),
				Vector2i(row, col - 1),
				Vector2i(row, col + 1)
			]
			for neighbor in neighbors:
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= size or neighbor.y >= size:
					continue
				_connect_nodes(map, source_id, _build_node_id(biome_key, neighbor.x, neighbor.y))

	var entry_id = _build_node_id(biome_key, home_coord.x, home_coord.y)
	var previous_biome = _get_previous_generated_biome(map, biome_index)
	if previous_biome != "":
		_connect_nodes(map, _get_exit_node_id(previous_biome, map), entry_id)
	var next_biome = _get_next_generated_biome(map, biome_index)
	if next_biome != "":
		_connect_nodes(map, _get_exit_node_id(biome_key, map), _get_entry_node_id(next_biome, map))

func _connect_nodes(map: Dictionary, a_id: String, b_id: String):
	if a_id == "" or b_id == "" or not map.has(a_id) or not map.has(b_id):
		return
	var a_node = map[a_id]
	var a_connections = a_node.get("connections", [])
	if not a_connections.has(b_id):
		a_connections.append(b_id)
	a_node["connections"] = a_connections
	map[a_id] = a_node

	var b_node = map[b_id]
	var b_connections = b_node.get("connections", [])
	if not b_connections.has(a_id):
		b_connections.append(a_id)
	b_node["connections"] = b_connections
	map[b_id] = b_node

func _normalize_target_biomes(target_biomes: Array) -> Array[String]:
	var result: Array[String] = []
	for biome in BIOME_ORDER:
		if target_biomes.has(biome):
			result.append(biome)
	return result

func _get_biomes_present_in_map(map: Dictionary) -> Array[String]:
	var present: Array[String] = []
	for biome in BIOME_ORDER:
		if _biome_exists_in_map(map, biome):
			present.append(biome)
	return present

func _biome_exists_in_map(map: Dictionary, biome: String) -> bool:
	for raw_key in map.keys():
		var node = map[raw_key]
		if str(node.get("biome", "")) == biome:
			return true
	return false

func _get_layer_offset_for_biome_index(biome_index: int) -> int:
	var total = 0
	for i in range(biome_index):
		total += _get_grid_size_for_biome_index(i)
	return total

func _get_entry_node_id(biome: String, map: Dictionary) -> String:
	for raw_key in map.keys():
		var node = map[raw_key]
		if str(node.get("biome", "")) == biome and bool(node.get("is_home", false)):
			return str(node.get("id", ""))
	return ""

func _get_exit_node_id(biome: String, map: Dictionary) -> String:
	var biome_index = BIOME_ORDER.find(biome)
	if biome_index == -1:
		return ""
	var size = _get_grid_size_for_biome_index(biome_index)
	var bottom_right_id = _build_node_id(biome, size - 1, size - 1)
	if map.has(bottom_right_id) and not bool(map[bottom_right_id].get("is_home", false)):
		return bottom_right_id
	return _build_node_id(biome, 0, size - 1)

func _get_previous_generated_biome(map: Dictionary, biome_index: int) -> String:
	for i in range(biome_index - 1, -1, -1):
		var biome = BIOME_ORDER[i]
		if _biome_exists_in_map(map, biome):
			return biome
	return ""

func _get_next_generated_biome(map: Dictionary, biome_index: int) -> String:
	for i in range(biome_index + 1, BIOME_ORDER.size()):
		var biome = BIOME_ORDER[i]
		if _biome_exists_in_map(map, biome):
			return biome
	return ""

func _build_node_id(biome: String, row: int, col: int) -> String:
	return "node_%s_%d_%d" % [biome, row, col]

func _pick_random_coord(size: int) -> Vector2i:
	return Vector2i(randi_range(0, size - 1), randi_range(0, size - 1))

func _get_random_node_visual_scale() -> float:
	return _node_visual_scale_rng.randf_range(0.8, 1.2)

func _get_grid_size_for_biome_index(biome_index: int) -> int:
	return clampi(biome_index + 2, 2, 10)

func _default_room_type_for_grid_position(row: int, col: int, size: int) -> String:
	if row == size - 1 and col == size - 1:
		return "event"
	if (row + col) % 5 == 0:
		return "rest"
	if (row + col) % 4 == 0:
		return "shop"
	return "battle"

func _pick_room_for_biome(biome: String) -> RoomData:
	if not _room_pool_by_biome.has(biome):
		_room_pool_by_biome[biome] = _load_biome_room_pool(biome)

	var pool: Array = _room_pool_by_biome[biome]
	if pool.is_empty():
		var fallback_path = _get_default_room_path_for_biome(biome)
		return DataManager.get_resource(fallback_path) as RoomData

	var used_set: Dictionary = _used_room_paths_by_biome.get(biome, {})
	var unused_rooms: Array[RoomData] = []
	for room_res in pool:
		var room_path = room_res.resource_path
		if room_path == "":
			continue
		if not used_set.has(room_path):
			unused_rooms.append(room_res)

	if unused_rooms.is_empty():
		var biome_default_path = _get_default_room_path_for_biome(biome)
		return DataManager.get_resource(biome_default_path) as RoomData

	var picked: RoomData = unused_rooms.pick_random()
	if picked and picked.resource_path != "":
		used_set[picked.resource_path] = true
		_used_room_paths_by_biome[biome] = used_set
	return picked

func _load_biome_room_pool(biome: String) -> Array:
	var source_biome = str(BIOME_ROOM_SOURCE.get(biome, biome))
	var biome_dir = ROOM_ROOT + source_biome + "/"
	var results: Array = []
	if not DirAccess.dir_exists_absolute(biome_dir):
		push_warning("MapGenerator: Missing room directory for biome '%s': %s" % [biome, biome_dir])
		return results

	var dir = DirAccess.open(biome_dir)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			if file_name.ends_with("_default.tres") or file_name.ends_with("_boss.tres") or file_name.ends_with("_home.tres"):
				file_name = dir.get_next()
				continue
			var full_path = biome_dir + file_name
			var res = DataManager.get_resource(full_path)
			if res is RoomData:
				results.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results

func _get_default_room_path_for_biome(biome: String) -> String:
	var source_biome = str(BIOME_ROOM_SOURCE.get(biome, biome))
	var biome_default = "%s%s/%s_default.tres" % [ROOM_ROOT, source_biome, source_biome]
	if ResourceLoader.exists(biome_default):
		return biome_default
	return GLOBAL_DEFAULT_ROOM_PATH

func _get_home_room_path_for_biome(biome: String) -> String:
	var source_biome = str(BIOME_ROOM_SOURCE.get(biome, biome))
	return "%s%s/%s_home.tres" % [ROOM_ROOT, source_biome, source_biome]

func _load_story_home_room_for_biome(biome: String) -> RoomData:
	var home_path = _get_home_room_path_for_biome(biome)
	if ResourceLoader.exists(home_path):
		return DataManager.get_resource(home_path) as RoomData
	return null
