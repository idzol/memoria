extends Node

# res://scripts/logic/MapGenerator.gd
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
	# We treat Home as a special "town" node or unique starting point
	nodes["0"] = {
		"id": "0",
		"room_key": "home",
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
		
		# Get available hand-crafted rooms for this biome
		var available_rooms = GameData.ROOMS.get(biome_name, {}).keys()
		
		for c in range(NODES_PER_LAYER):
			var id = str(1 + (l * NODES_PER_LAYER) + c)
			var grid_pos = Vector2i(c, l)
			
			# CHECK FOR FIXED NODE OVERRIDE
			var fixed_ref = GameManager.fixed_nodes.get(grid_pos, "")
			
			# Pick a random hand-crafted room key (e.g., "t1", "f5")
			var room_key = "default"
			var room_data = {}
			
			if fixed_ref != "":
				# If fixed_ref matches a known room key in the current biome, load it
				if GameData.ROOMS.get(biome_name, {}).has(fixed_ref):
					room_key = fixed_ref
					room_data = GameData.ROOMS[biome_name][room_key].duplicate()
				else:
					# Fallback: treat as a generic type or unique landmark
					room_data = {"type": fixed_ref, "name": fixed_ref.capitalize().replace("_", " ")}

			elif not available_rooms.is_empty():
				room_key = available_rooms[randi() % available_rooms.size()]
				room_data = GameData.ROOMS[biome_name][room_key].duplicate()
			
			# Construct final node dictionary
			nodes[id] = {
				"id": id,
				"room_key": room_key,
				"biome": biome_name,
				"layer": l,
				"column": c,
				"difficulty": diff,
				"pos": Vector2((c - 2) * HORIZONTAL_SPACING, l * -VERTICAL_SPACING),
				"connections": []
			}
			
			# Merge in data from GameData (name, type, enemy, loot, etc.)
			for key in room_data:
				nodes[id][key] = room_data[key]
				
			# Default type if missing
			if not nodes[id].has("type"):
				nodes[id]["type"] = _get_random_type_fallback(l)

	# 3. Orthogonal Connections
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

func _find_node_at(nodes: Dictionary, coord: Vector2i):
	for id in nodes:
		if nodes[id].layer == coord.y and nodes[id].column == coord.x:
			return nodes[id]
	return null

func _get_random_type_fallback(layer: int) -> String:
	if layer == MAP_LAYERS - 1: return "boss"
	var r = randf()
	if r < 0.6: return "battle"
	if r < 0.8: return "event"
	if r < 0.9: return "shop"
	return "rest"

func get_difficulty_color(diff: int) -> Color:
	var colors = [Color.SEA_GREEN, Color.GREEN_YELLOW, Color.GOLD, Color.DARK_ORANGE, Color.ORANGE_RED, Color.CRIMSON, Color.MEDIUM_PURPLE]
	return colors[clampi(diff, 0, 6)]