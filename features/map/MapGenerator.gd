extends Node

# res://features/map/MapGenerator.gd
# Procedural Map Generator optimized with DataManager caching.

signal progress_updated(percent: float, description: String)

const MAP_LAYERS = 20
const NODES_PER_LAYER = 5
const VERTICAL_SPACING = 180
const HORIZONTAL_SPACING = 180

const BIOME_KEYS = {
	0: "town", 1: "forest", 2: "ice_caves", 3: "desert", 4: "swamp", 5: "abyss", 6: "void", 7: "the_core"
}

func generate_new_map() -> Dictionary:
	var nodes = {}
	
	# 1. Create Home Node
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
	
	# 2. Generate Layers
	for l in range(MAP_LAYERS):
		var tier = clampi(floor(l * 10.0 / MAP_LAYERS) + 1, 1, 10)
		var diff_idx = clampi(floor(l * 7.0 / MAP_LAYERS), 0, 6)
		var biome_name = BIOME_KEYS[diff_idx]
		
		var progress = (float(l) / MAP_LAYERS) * 0.8 + 0.1
		progress_updated.emit(progress, "Mapping the %s..." % biome_name.capitalize())
		
		await get_tree().process_frame
		
		for c in range(NODES_PER_LAYER):
			var id = str(1 + (l * NODES_PER_LAYER) + c)
			
			# Fetch random room from the cached biome/tier pool
			var room_res = DataManager.get_random_room(biome_name, tier)
			
			# DEFENSIVE CODING: Ensure local defaults in case DataManager returns null
			# or properties like 'type' or 'room_name' are missing from the resource.
			var r_type = "battle"
			var r_name = "Unknown Encounter"
			var icon_path = ""
			
			if room_res:
				r_type = room_res.get("type") if room_res.get("type") != null else "battle"
				r_name = room_res.get("room_name") if room_res.get("room_name") != null else "Unknown"
				var icon = room_res.get("map_icon")
				if icon:
					icon_path = icon.resource_path
			
			nodes[id] = {
				"id": id,
				"room_resource_path": room_res.resource_path if room_res else "res://data/rooms/town/t1.tres",
				"biome": biome_name,
				"layer": l,
				"column": c,
				"difficulty": tier,
				"pos": Vector2((c - 2) * HORIZONTAL_SPACING, l * -VERTICAL_SPACING),
				"connections": [],
				"type": r_type,
				"name": r_name,
				"custom_icon_path": icon_path
			}

	# 3. Connections
	progress_updated.emit(0.95, "Finalizing ley lines...")
	for id in nodes:
		var node = nodes[id]
		var neighbors = [Vector2i(node.column, node.layer + 1), Vector2i(node.column, node.layer - 1)]
		for coord in neighbors:
			var target = _find_node_at(nodes, coord)
			if target: node.connections.append(target.id)
	
	progress_updated.emit(1.0, "Synchronization complete.")
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

func _find_node_at(nodes: Dictionary, coord: Vector2i):
	if coord.y == -1 and coord.x == 2: return nodes["0"]
	for id in nodes:
		if nodes[id].layer == coord.y and nodes[id].column == coord.x: return nodes[id]
	return null
