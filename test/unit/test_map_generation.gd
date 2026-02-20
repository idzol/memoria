extends "res://addons/gut/test.gd"

# res://test/unit/test_map_gen.gd
# Tests the validity of the procedural 100-node map.

var MapGenerator = load("res://features/map/MapGenerator.gd")
var _mg = null

func before_each():
	_mg = MapGenerator.new()

func test_map_size_validity():
	var nodes = _mg.generate_new_map()
	# 20 layers * 5 nodes per layer = 100
	assert_eq(nodes.size(), 100, "Map should generate exactly 100 nodes")

func test_boss_placement():
	var nodes = _mg.generate_new_map()
	var last_node = nodes[99]
	assert_eq(last_node.type, "boss", "The final node must be a boss")
	assert_eq(last_node.difficulty, 6, "Boss must be difficulty 6")

func test_node_connectivity():
	var nodes = _mg.generate_new_map()
	var orphan_found = false
	
	for id in nodes:
		var node = nodes[id]
		# Check all nodes except the top layer have upward connections
		if node.layer < 19 and node.connections.size() == 0:
			orphan_found = true
			break
			
	assert_false(orphan_found, "Every node below the final layer must have at least one connection")

func test_difficulty_progression():
	var nodes = _mg.generate_new_map()
	assert_eq(nodes[0].difficulty, 0, "Layer 0 should be diff 0")
	assert_gt(nodes[99].difficulty, 4, "Layer 19 should be high difficulty")