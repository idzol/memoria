extends Node

# res://scripts/logic/MapGenerator.gd
# Generates a procedural campaign map with orthogonal (U/D/L/R) connections.

const MAP_LAYERS = 20
const NODES_PER_LAYER = 5
const VERTICAL_SPACING = 180
const HORIZONTAL_SPACING = 200

class MapNode:
	var id: int
	var pos: Vector2
	var layer: int
	var column: int
	var difficulty: int
	var type: String
	var connections: Array = [] # List of node IDs

func generate_new_map() -> Dictionary:
	var nodes = {}
	
	# 1. Create Home Node (ID 0) at the start
	var home = MapNode.new()
	home.id = 0
	home.layer = -1
	home.column = 2
	home.type = "home"
	home.pos = Vector2(0, VERTICAL_SPACING)
	nodes[home.id] = home
	
	# 2. Generate Grid Layers
	for l in range(MAP_LAYERS):
		var diff = clampi(floor(l * 7.0 / MAP_LAYERS), 0, 6)
		for c in range(NODES_PER_LAYER):
			var node = MapNode.new()
			node.id = 1 + (l * NODES_PER_LAYER) + c
			node.layer = l
			node.column = c
			node.difficulty = diff
			node.type = _get_random_room_type(l)
			node.pos = Vector2((c - 2) * HORIZONTAL_SPACING, l * -VERTICAL_SPACING)
			nodes[node.id] = node

	# 3. Orthogonal Connections
	for id in nodes:
		var node = nodes[id]
		# Find neighbors: Up, Down, Left, Right coordinates
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
	
	# Final node is the Boss
	var boss_id = nodes.size() - 1
	nodes[boss_id].type = "boss"
	
	return nodes

func _find_node_at(nodes: Dictionary, coord: Vector2i):
	for id in nodes:
		if nodes[id].layer == coord.y and nodes[id].column == coord.x:
			return nodes[id]
	return null

func _get_random_room_type(layer: int) -> String:
	if layer == MAP_LAYERS - 1: return "boss"
	var r = randf()
	if r < 0.6: return "battle"
	if r < 0.8: return "event"
	if r < 0.9: return "shop"
	return "rest"

func get_difficulty_color(diff: int) -> Color:
	match diff:
		0: return Color.SEA_GREEN
		1: return Color.GREEN_YELLOW
		2: return Color.GOLD
		3: return Color.DARK_ORANGE
		4: return Color.ORANGE_RED
		5: return Color.CRIMSON
		6: return Color.MEDIUM_PURPLE
		_: return Color.WHITE