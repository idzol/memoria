extends Node

# res://features/map/BattleMapGenerator.gd
# Generates biome-specific square grids (2x2 -> 10x10) with orthogonal adjacency.

signal progress_updated(percent: float, description: String)

const BIOME_ORDER = ["home", "town", "forest", "ice_caves", "desert", "swamp", "abyss", "void", "the_core"]
const BIOME_ROOM_SOURCE = {
	"home": "town",
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

var _room_pool_by_biome: Dictionary = {}
var _used_room_paths_by_biome: Dictionary = {}

func generate_battle_map() -> Dictionary:
	var map: Dictionary = {}
	_room_pool_by_biome.clear()
	_used_room_paths_by_biome.clear()

	var layer_offset := 0
	var previous_exit_id := ""

	for biome_index in range(BIOME_ORDER.size()):
		var biome_key = BIOME_ORDER[biome_index]
		var size = _get_grid_size_for_biome_index(biome_index)
		var progress = float(biome_index) / max(1.0, float(BIOME_ORDER.size() - 1))
		progress_updated.emit(progress, "Charting the %s..." % biome_key.capitalize())
		await get_tree().process_frame

		if not _used_room_paths_by_biome.has(biome_key):
			_used_room_paths_by_biome[biome_key] = {}

		for row in range(size):
			for col in range(size):
				var node_id = _build_node_id(biome_key, row, col)
				var room_res = _pick_room_for_biome(biome_key)
				var fallback_type = _default_room_type_for_grid_position(row, col, size)
				var node_type = "home" if biome_key == "home" and row == 0 and col == 0 else (room_res.type if room_res else fallback_type)
				var data = {
					"id": node_id,
					"name": room_res.room_name if room_res else "%s %d,%d" % [biome_key.capitalize(), row + 1, col + 1],
					"type": node_type,
					"biome": biome_key,
					"biome_index": biome_index,
					"layer": layer_offset + row,
					"column": col,
					"difficulty": size,
					"room_resource_path": room_res.resource_path if room_res else _get_default_room_path_for_biome(biome_key),
					"initial_dialog": room_res.initial_dialog if room_res else "",
					"connections": []
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
					source.connections.append(_build_node_id(biome_key, neighbor.x, neighbor.y))
				map[source_id] = source

		var entry_id = _build_node_id(biome_key, 0, 0)
		var exit_id = _build_node_id(biome_key, size - 1, size - 1)
		if previous_exit_id != "":
			map[previous_exit_id].connections.append(entry_id)
			map[entry_id].connections.append(previous_exit_id)
		previous_exit_id = exit_id
		layer_offset += size

	progress_updated.emit(1.0, "Synchronization complete.")
	return map

func _build_node_id(biome: String, row: int, col: int) -> String:
	return "node_%s_%d_%d" % [biome, row, col]

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
		var fallback_res = DataManager.get_resource(fallback_path)
		return fallback_res as RoomData

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
		var biome_default_res = DataManager.get_resource(biome_default_path)
		return biome_default_res as RoomData

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
		push_warning("BattleMapGenerator: Missing room directory for biome '%s': %s" % [biome, biome_dir])
		return results

	var dir = DirAccess.open(biome_dir)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			if file_name.ends_with("_default.tres") or file_name.ends_with("_boss.tres"):
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
