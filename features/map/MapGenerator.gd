extends Node

# res://features/map/MapGenerator.gd
# Generates a procedural map and extracts metadata for performance.
# Designed to be called once per run and stored in GameManager.

const MAP_LAYERS = 20
const NODES_PER_LAYER = 5
const VERTICAL_SPACING = 180
const HORIZONTAL_SPACING = 180

const BIOME_KEYS = {
	0: "town",
	1: "forest",
	2: "ice_caves",
	3: "desert",
	4: "swamp",
	5: "abyss",
	6: "void"
}
var _biome_cache: Dictionary = {}

## Generates a full map dataset. This should be stored in GameManager.world_state.map
func generate_new_map() -> Dictionary:
	var nodes = {}
	_biome_cache.clear()
	
	# 1. Create Home Node (ID 0)

	# 1. Create Home Node (ID 0)
	nodes["0"] = {
		"id": "0",
		"room_key": "home",
		"room_resource_path": "res://data/rooms/town/home.tres",
		"biome": "town",
		"layer": -1,
		"column": 2,
		"type": "home",
		"name": "Home Base",
		"difficulty": 0,
		"pos": Vector2(0, VERTICAL_SPACING),
		"connections": []
	}
	
	# 2. Generate Grid Layers
	for l in range(MAP_LAYERS):
		var diff = clampi(floor(l * 7.0 / MAP_LAYERS), 0, 6)
		var biome_name = BIOME_KEYS[diff]
		var available = _get_available_rooms(biome_name)
		
		for c in range(NODES_PER_LAYER):
			var id = str(1 + (l * NODES_PER_LAYER) + c)
			var res_path = ""
			
			# Check for fixed placement overrides
			var fixed_ref = GameManager.fixed_nodes.get(Vector2i(c, l), "")
			if fixed_ref != "":
				res_path = "res://data/rooms/%s/%s" % [biome_name, fixed_ref if fixed_ref.ends_with(".tres") else fixed_ref + ".tres"]
			elif not available.is_empty():
				res_path = "res://data/rooms/%s/%s" % [biome_name, available[randi() % available.size()]]
			else:
				res_path = "res://data/rooms/town/t1.tres"
			
			nodes[id] = _create_node_entry(id, res_path, biome_name, l, c, diff)

	# 3. Build Connections
	for id in nodes:
		var node = nodes[id]
		var neighbors = [
			Vector2i(node.column, node.layer + 1), 
			Vector2i(node.column, node.layer - 1), 
			Vector2i(node.column + 1, node.layer), 
			Vector2i(node.column - 1, node.layer)
		]
		for coord in neighbors:
			var target = _find_node_at(nodes, coord)
			if target: 
				node.connections.append(target.id)
	
	return nodes

## Extracts minimal metadata from a Room Resource without keeping the large resource in memory.
func _create_node_entry(id: String, path: String, biome: String, l: int, c: int, diff: int) -> Dictionary:
	var res = load(path) as RoomData
	
	var entry = {
		"id": id,
		"room_resource_path": path,
		"biome": biome,
		"layer": l,
		"column": c,
		"difficulty": diff,
		"pos": Vector2((c - 2) * HORIZONTAL_SPACING, l * -VERTICAL_SPACING),
		"connections": [],
		"type": "battle",
		"name": "Unknown",
		"custom_icon_path": ""
	}
	
	if res:
		entry.type = res.type
		entry.name = res.room_name
		# PERFORMANCE: Store only the path string of the icon. 
		# MapNode.gd will use this string to load only the small PNG texture.
		if res.map_icon:
			entry.custom_icon_path = res.map_icon.resource_path
			
	return entry

func _get_available_rooms(biome: String) -> Array:
	if _biome_cache.has(biome): return _biome_cache[biome]
	var path = "res://data/rooms/%s/" % biome
	var files = []
	if DirAccess.dir_exists_absolute(path):
		var dir = DirAccess.open(path)
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if f.ends_with(".tres"): files.append(f)
			f = dir.get_next()
	_biome_cache[biome] = files
	return files

func _find_node_at(nodes: Dictionary, coord: Vector2i):
	if coord.y == -1 and coord.x == 2: return nodes["0"]
	for id in nodes:
		if nodes[id].layer == coord.y and nodes[id].column == coord.x: return nodes[id]
	return null
