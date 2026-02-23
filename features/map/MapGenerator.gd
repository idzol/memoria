extends Node

# res://features/map/MapGenerator.gd
# Generates a procedural map by selecting from physical RoomData (.tres) resources on disk.

const MAP_LAYERS = 20
const NODES_PER_LAYER = 5
const VERTICAL_SPACING = 180
const HORIZONTAL_SPACING = 180

# Mapping difficulty tiers to Biome folders
const BIOME_KEYS = {
	0: "town",
	1: "forest",
	2: "ice_caves",
	3: "desert",
	4: "swamp",
	5: "abyss",
	6: "void"
}

# Cache for biome contents to prevent repeated folder scanning
var _biome_cache: Dictionary = {}

func generate_new_map() -> Dictionary:
	var nodes = {}
	_biome_cache.clear()
	
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
		
		# Get list of .tres files in this biome's directory
		var available_resources = _get_available_rooms(biome_name)
		
		for c in range(NODES_PER_LAYER):
			var id = str(1 + (l * NODES_PER_LAYER) + c)
			var grid_pos = Vector2i(c, l)
			
			var room_res_name = ""
			var resource_path = ""
			
			# Check for fixed placement overrides from GameManager
			var fixed_ref = GameManager.fixed_nodes.get(grid_pos, "")
			
			if fixed_ref != "":
				room_res_name = fixed_ref if fixed_ref.ends_with(".tres") else fixed_ref + ".tres"
				resource_path = "res://data/rooms/%s/%s" % [biome_name, room_res_name]
			elif not available_resources.is_empty():
				room_res_name = available_resources[randi() % available_resources.size()]
				resource_path = "res://data/rooms/%s/%s" % [biome_name, room_res_name]
			else:
				# Emergency Fallback
				resource_path = "res://data/rooms/town/t1.tres"

			# Safety check before creating the node entry
			if not FileAccess.file_exists(resource_path):
				resource_path = "res://data/rooms/town/t1.tres" 

			# Pre-load metadata for the node dictionary (prevents loading Resource in Map view)
			var temp_res = load(resource_path) as RoomData
			
			nodes[id] = {
				"id": id,
				"room_key": room_res_name.get_basename(),
				"room_resource_path": resource_path,
				"biome": biome_name,
				"layer": l,
				"column": c,
				"difficulty": diff,
				"pos": Vector2((c - 2) * HORIZONTAL_SPACING, l * -VERTICAL_SPACING),
				"connections": [],
				"type": temp_res.type if temp_res else "battle",
				"name": temp_res.room_name if temp_res else "Unknown"
			}

	# 3. Connections
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
			if target: node.connections.append(target.id)
	
	return nodes

func _get_available_rooms(biome: String) -> Array:
	if _biome_cache.has(biome):
		return _biome_cache[biome]
		
	var path = "res://data/rooms/%s/" % biome
	var files = []
	
	if DirAccess.dir_exists_absolute(path):
		var dir = DirAccess.open(path)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				files.append(file_name)
			file_name = dir.get_next()
	
	_biome_cache[biome] = files
	return files

func _find_node_at(nodes: Dictionary, coord: Vector2i):
	for id in nodes:
		if nodes[id].layer == coord.y and nodes[id].column == coord.x:
			return nodes[id]
	return null