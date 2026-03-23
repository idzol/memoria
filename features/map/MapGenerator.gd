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
const MAX_BIOME_MAP_SIZE = 11
const MAX_ACTIVE_ROOM_COUNT = 64

var _map_assets: MapAssetData = preload("res://data/map/map_data.tres")

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
			if not bool(node.get("passable", true)):
				continue
			var state = room_states.get(node_id, {})
			if state.get("completed", false):
				continue

			var is_home = bool(node.get("is_home", false))
			var room_res = _load_story_home_room_for_biome(biome) if is_home else (_load_story_boss_room_for_biome(biome) if str(node.get("type", "")) == "boss" else _pick_room_for_biome(biome))
			var fallback_type = str(node.get("base_type", node.get("type", "battle")))
			node["room_resource_path"] = room_res.resource_path if room_res else _get_default_room_path_for_biome(biome)
			node["name"] = room_res.room_name if room_res else str(node.get("name", "Unknown Encounter"))
			node["initial_dialog"] = room_res.initial_dialog if room_res else str(node.get("initial_dialog", ""))
			node["base_type"] = "home" if is_home else ("boss" if str(node.get("type", "")) == "boss" else (room_res.type if room_res else fallback_type))
			node["type"] = "home" if is_home else ("boss" if str(node.get("type", "")) == "boss" else str(node.get("base_type", fallback_type)))
			node["node_visual_scale"] = _get_random_node_visual_scale()
			if room_res and room_res.map_icon:
				node["custom_icon_path"] = room_res.map_icon.resource_path
			else:
				node.erase("custom_icon_path")
			updated_map[node_id] = node

	return updated_map

func _generate_biome_into_map(map: Dictionary, biome_key: String, biome_index: int):
	var active_room_count = _get_active_room_count_for_biome_index(biome_index)
	var layout = _build_biome_hex_layout(active_room_count)
	var home_coord: Vector2i = layout.get("home", Vector2i(5, 5))
	var exit_coord: Vector2i = layout.get("exit", home_coord)
	var home_room_res = _load_story_home_room_for_biome(biome_key)
	var boss_room_res = _load_story_boss_room_for_biome(biome_key)
	var active_coords: Array = layout.get("active", [])
	var background_coords: Array = layout.get("background", [])
	for coord_variant in active_coords:
		var coord: Vector2i = coord_variant
		var node_id = _build_node_id(biome_key, coord.x, coord.y)
		var is_home = coord == home_coord
		var is_exit = coord == exit_coord and not is_home
		var room_res = home_room_res if is_home else (boss_room_res if is_exit else _pick_room_for_biome(biome_key))
		var fallback_type = _default_room_type_for_coord(coord, active_room_count)
		var data = {
			"id": node_id,
			"name": room_res.room_name if room_res else "%s %d,%d" % [biome_key.capitalize(), coord.x + 1, coord.y + 1],
			"type": "home" if is_home else ("boss" if is_exit else (room_res.type if room_res else fallback_type)),
			"base_type": "home" if is_home else ("boss" if is_exit else (room_res.type if room_res else fallback_type)),
			"biome": biome_key,
			"biome_index": biome_index,
			"layer": coord.x,
			"column": coord.y,
			"difficulty": int(ceil(sqrt(active_room_count))),
			"room_resource_path": room_res.resource_path if room_res else _get_default_room_path_for_biome(biome_key),
			"initial_dialog": room_res.initial_dialog if room_res else "",
			"connections": [],
			"is_home": is_home,
			"node_visual_scale": _get_random_node_visual_scale(),
			"node_shape": "hex",
			"passable": true
		}
		if room_res and room_res.map_icon:
			data["custom_icon_path"] = room_res.map_icon.resource_path
		map[node_id] = data

	var background_icon_path = _get_biome_background_icon_path(biome_key)
	for coord_variant in background_coords:
		var coord: Vector2i = coord_variant
		var node_id = _build_node_id(biome_key, coord.x, coord.y)
		map[node_id] = {
			"id": node_id,
			"name": "",
			"type": "background",
			"base_type": "background",
			"biome": biome_key,
			"biome_index": biome_index,
			"layer": coord.x,
			"column": coord.y,
			"difficulty": int(ceil(sqrt(active_room_count))),
			"room_resource_path": "",
			"initial_dialog": "",
			"connections": [],
			"is_home": false,
			"node_visual_scale": 1.0,
			"node_shape": "hex",
			"passable": false,
			"custom_icon_path": background_icon_path
		}

	for pair_key in layout.get("connections", []):
		var pair_parts = str(pair_key).split("|")
		if pair_parts.size() != 2:
			continue
		_connect_nodes(
			map,
			_build_node_id(biome_key, int(pair_parts[0].split(",")[0]), int(pair_parts[0].split(",")[1])),
			_build_node_id(biome_key, int(pair_parts[1].split(",")[0]), int(pair_parts[1].split(",")[1]))
		)

	for coord_variant in active_coords:
		var coord: Vector2i = coord_variant
		var source_id = _build_node_id(biome_key, coord.x, coord.y)
		for neighbor in _get_hex_neighbors(coord):
			if not _is_coord_on_board(neighbor):
				continue
			var neighbor_id = _build_node_id(biome_key, neighbor.x, neighbor.y)
			if not map.has(neighbor_id):
				continue
			if bool(map[neighbor_id].get("passable", true)):
				continue
			_connect_nodes(map, source_id, neighbor_id)

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

func _build_node_id(biome: String, row: int, col: int) -> String:
	return "node_%s_%d_%d" % [biome, row, col]

func _get_random_node_visual_scale() -> float:
	return _node_visual_scale_rng.randf_range(0.8, 1.2)

func _get_active_room_count_for_biome_index(biome_index: int) -> int:
	return mini((biome_index + 2) * (biome_index + 2), MAX_ACTIVE_ROOM_COUNT)

func _default_room_type_for_coord(coord: Vector2i, active_room_count: int) -> String:
	var seed_value = coord.x * 31 + coord.y * 17 + active_room_count
	if posmod(seed_value, 7) == 0:
		return "rest"
	if posmod(seed_value, 5) == 0:
		return "shop"
	if posmod(seed_value, 3) == 0:
		return "event"
	return "battle"

func _build_biome_hex_layout(active_room_count: int) -> Dictionary:
	var center = Vector2i(MAX_BIOME_MAP_SIZE / 2, MAX_BIOME_MAP_SIZE / 2)
	var active: Dictionary = {_coord_key(center): center}
	var connections: Dictionary = {}
	while active.size() < active_room_count:
		var growth_options: Array[Dictionary] = []
		for coord_variant in active.values():
			var coord: Vector2i = coord_variant
			for neighbor in _get_hex_neighbors(coord):
				var neighbor_key = _coord_key(neighbor)
				if not _is_coord_on_board(neighbor) or active.has(neighbor_key):
					continue
				growth_options.append({"coord": neighbor, "parent": coord})
		if growth_options.is_empty():
			break
		var picked: Dictionary = growth_options.pick_random()
		var picked_coord: Vector2i = picked.get("coord", center)
		var parent_coord: Vector2i = picked.get("parent", center)
		active[_coord_key(picked_coord)] = picked_coord
		_add_connection_pair(connections, parent_coord, picked_coord)

	for coord_variant in active.values():
		var coord: Vector2i = coord_variant
		for neighbor in _get_hex_neighbors(coord):
			if not _is_coord_on_board(neighbor):
				continue
			if not active.has(_coord_key(neighbor)):
				continue
			if randf() <= 0.34:
				_add_connection_pair(connections, coord, neighbor)

	var exit_coord = _find_farthest_coord(center, active.values())
	var background: Dictionary = {}
	for coord_variant in active.values():
		var coord: Vector2i = coord_variant
		for neighbor in _get_hex_neighbors(coord):
			var neighbor_key = _coord_key(neighbor)
			if not _is_coord_on_board(neighbor) or active.has(neighbor_key):
				continue
			background[neighbor_key] = neighbor

	return {
		"home": center,
		"exit": exit_coord,
		"active": active.values(),
		"background": background.values(),
		"connections": connections.keys()
	}

func _add_connection_pair(connections: Dictionary, a: Vector2i, b: Vector2i):
	var a_key = _coord_key(a)
	var b_key = _coord_key(b)
	if a_key == b_key:
		return
	if not _are_hex_neighbors(a, b):
		return
	var pair_key = "%s|%s" % [a_key, b_key] if a_key < b_key else "%s|%s" % [b_key, a_key]
	connections[pair_key] = true

func _find_farthest_coord(origin: Vector2i, coords: Array) -> Vector2i:
	var best_coord = origin
	var best_distance = -1
	for coord_variant in coords:
		var coord: Vector2i = coord_variant
		var distance = origin.distance_squared_to(coord)
		if distance > best_distance:
			best_distance = distance
			best_coord = coord
	return best_coord

func _get_hex_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var offsets_even = [
		Vector2i(-1, -1),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(1, -1),
		Vector2i(1, 0)
	]
	var offsets_odd = [
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(1, 0),
		Vector2i(1, 1)
	]
	var source = offsets_even if posmod(coord.x, 2) == 0 else offsets_odd
	var neighbors: Array[Vector2i] = []
	for offset in source:
		neighbors.append(coord + offset)
	return neighbors

func _are_hex_neighbors(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return false
	for neighbor in _get_hex_neighbors(a):
		if neighbor == b:
			return true
	return false

func _is_coord_on_board(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < MAX_BIOME_MAP_SIZE and coord.y < MAX_BIOME_MAP_SIZE

func _coord_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

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

func _get_boss_room_path_for_biome(biome: String) -> String:
	var source_biome = str(BIOME_ROOM_SOURCE.get(biome, biome))
	var boss_path = "%s%s/%s_boss.tres" % [ROOM_ROOT, source_biome, source_biome]
	if ResourceLoader.exists(boss_path):
		return boss_path
	return _get_default_room_path_for_biome(biome)

func _load_story_home_room_for_biome(biome: String) -> RoomData:
	var home_path = _get_home_room_path_for_biome(biome)
	if ResourceLoader.exists(home_path):
		return DataManager.get_resource(home_path) as RoomData
	return null

func _load_story_boss_room_for_biome(biome: String) -> RoomData:
	var boss_path = _get_boss_room_path_for_biome(biome)
	if ResourceLoader.exists(boss_path):
		return DataManager.get_resource(boss_path) as RoomData
	return null

func _get_biome_background_icon_path(biome: String) -> String:
	if not _map_assets:
		return ""
	var normalized_biome = "town" if biome == "home" else biome
	var prop = "map_%s_background" % normalized_biome
	if prop in _map_assets:
		var texture = _map_assets.get(prop) as Texture2D
		if texture:
			return texture.resource_path
	return ""
