extends Node

# res://scripts/logic/MapGenerator.gd
# Generates a procedural map by selecting a subset of 210 unique rooms.

const MAP_LAYERS = 20
const NODES_PER_LAYER = 5
const VERTICAL_SPACING = 180
const HORIZONTAL_SPACING = 180

# The selected subset for the current run
var active_room_sets = {} 

func generate_new_map() -> Dictionary:
	if GameData.ROOM_POOL[0].is_empty():
		var temp_gd = GameData.new()
		temp_gd._generate_room_definitions()
		temp_gd.queue_free()
	
	_select_active_rooms_for_run()
	
	var nodes = {}
	
	# 1. Create Home Node
	var home = {
		"id": "0",
		"name": "Home Base",
		"type": "home",
		"layer": -1,
		"column": 2,
		"difficulty": 0,
		"pos": Vector2(0, VERTICAL_SPACING),
		"connections": []
	}
	nodes[home.id] = home
	
	# 2. Generate Grid Layers
	for l in range(MAP_LAYERS):
		var diff = clampi(floor(l * 7.0 / MAP_LAYERS), 0, 6)
		var current_set = active_room_sets[diff]
		
		for c in range(NODES_PER_LAYER):
			var room_template = {}
			
			# Check if room pool is empty
			if current_set.is_empty():
				push_error("MapGenerator: ROOM_POOL for difficulty %d is empty! Check GameData.gd" % diff)
				# Fallback to a generic room to prevent crash
				room_template = {
					"name": "Unstable Reality",
					"type": "battle",
					"difficulty": diff,
					"enemy": "skeletal_sentry",
					"loot": ["gold"]
				}
			else:
				room_template = current_set[randi() % current_set.size()].duplicate()

			var id = str(1 + (l * NODES_PER_LAYER) + c)
			room_template["id"] = id
			room_template["layer"] = l
			room_template["column"] = c
			room_template["pos"] = Vector2((c - 2) * HORIZONTAL_SPACING, l * -VERTICAL_SPACING)
			room_template["connections"] = []
			
			nodes[id] = room_template

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

func _select_active_rooms_for_run():
	# For each difficulty (0-6), pick 20 random rooms out of the 30 available
	for diff in range(7):
		var full_pool = GameData.ROOM_POOL[diff].duplicate()
		full_pool.shuffle()
		active_room_sets[diff] = full_pool.slice(0, 20)

func _find_node_at(nodes: Dictionary, coord: Vector2i):
	for id in nodes:
		if nodes[id].layer == coord.y and nodes[id].column == coord.x:
			return nodes[id]
	return null

func get_difficulty_color(diff: int) -> Color:
	var colors = [Color.SEA_GREEN, Color.GREEN_YELLOW, Color.GOLD, Color.DARK_ORANGE, Color.ORANGE_RED, Color.CRIMSON, Color.MEDIUM_PURPLE]
	return colors[clampi(diff, 0, 6)]
