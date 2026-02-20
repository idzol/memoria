extends Node

# res://features/map/MapGenerator.gd
# Generates a procedural campaign map by selecting from hand-crafted room pools.

const MAP_LAYERS = 20
const NODES_PER_LAYER = 5
const VERTICAL_SPACING = 180
const HORIZONTAL_SPACING = 180

# Mapping difficulty tiers to GameData.ROOMS keys
const BIOME_KEYS = {
	0: "town",
	1: "forest",
	2: "ice_caves",
	3: "desert",
	4: "swamp",
	5: "abyss",
	6: "void"
}

func generate_new_map() -> Dictionary:
	var nodes = {}
	
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
		var available_rooms = GameData.ROOMS.get(biome_name, {}).keys()
		
		for c in range(NODES_PER_LAYER):
			var id = str(1 + (l * NODES_PER_LAYER) + c)
			var grid_pos = Vector2i(c, l)
			
			var room_key = "default"
			var room_data = {}
			
			# Check for fixed placement overrides (Town Square, etc.)
			var fixed_ref = GameManager.fixed_nodes.get(grid_pos, "")
			
			if fixed_ref != "":
				room_key = fixed_ref
				room_data = GameData.ROOMS.get(biome_name, {}).get(room_key, {}).duplicate()
			elif not available_rooms.is_empty():
				# Randomly select a hand-crafted room ID from GameData
				room_key = available_rooms[randi() % available_rooms.size()]
				room_data = GameData.ROOMS[biome_name][room_key].duplicate()
			
			# CONSTRUCT RESOURCE PATH
			var resource_path = "res://data/rooms/%s/%s.tres" % [biome_name, room_key]

			# Ensure the file actually exists before assigning it
			if not FileAccess.file_exists(resource_path):
				resource_path = "res://data/rooms/forest/default_battle.tres" # Safety fallback

			nodes[id] = {
				"id": id,
				"room_key": room_key,
				"room_resource_path": resource_path, # THIS is the key reference
				"biome": biome_name,
				"layer": l,
				"column": c,
				"difficulty": diff,
				"pos": Vector2((c - 2) * HORIZONTAL_SPACING, l * -VERTICAL_SPACING),
				"connections": [],
				"type": room_data.get("type", "battle")
			}
			
			# Merge remaining room data (dialog, npc, enemies, etc.)
			for key in room_data:
				if key != "type": # Already set in the constructor above
					nodes[id][key] = room_data[key]
				
			if not nodes[id].has("type"):
				nodes[id]["type"] = "battle"

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

func _find_node_at(nodes: Dictionary, coord: Vector2i):
	for id in nodes:
		if nodes[id].layer == coord.y and nodes[id].column == coord.x:
			return nodes[id]
	return null