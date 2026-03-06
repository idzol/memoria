extends Node

# res://features/map/BattleMapGenerator.gd
# Generates a linear 80-room map by loading hand-crafted RoomData resources.

# Progress signals and async support for loading overlays.
signal progress_updated(percent: float, description: String)

const BIOMES = ["town", "forest", "ice_caves", "desert", "swamp", "abyss", "void","the_core"]
const ROOM_ROOT = "res://data/rooms/"

# Cache to store loaded rooms: { "town": { 1: [Room, Room], 2: [...] } }
var _room_pool: Dictionary = {}

func generate_battle_map() -> Dictionary:
	_scan_all_rooms()
	var map = {}
	
	# 1. CREATE HOME (Layer 0)
	map["node_0_0"] = {
		"id": "node_0_0",
		"name": "Testing Base",
		"type": "home",
		"biome": "town",
		"layer": 0,
		"column": 0,
		"room_resource_path": "res://data/rooms/town/home.tres",
		"initial_dialog": "", # Suppress dialog in Battle Mode
		"connections": ["node_1_0", "node_1_1"]
	}
	
	# 2. GENERATE BIOMES (8 Biomes x 10 Phases/Layers)
	for b_idx in range(BIOMES.size()):
		var biome_id = BIOMES[b_idx]
		var start_layer = (b_idx * 10) + 1
		
		# Emit progress for each biome transition
		var biome_percent = (float(b_idx) / BIOMES.size()) * 0.9 + 0.1
		progress_updated.emit(biome_percent, "Charting the %s..." % biome_id.capitalize())
		
		# Small delay to allow UI to update and simulate complex calculation
		await get_tree().process_frame

		for phase in range(1, 11): # Phase 1 to 10 within the biome
			var current_layer = start_layer + (phase - 1)
			var nodes_in_layer = 2 
			
			for n_idx in range(nodes_in_layer):
				var node_id = "node_%d_%d" % [current_layer, n_idx]
				var target_type = _get_room_type(phase)
				
				# Select a room resource matching biome, phase difficulty, and type
				var room_res = _get_room_resource(biome_id, phase, target_type)
				
				var data = {
					"id": node_id,
					"name": room_res.room_name if room_res else "%s Phase %d" % [biome_id.capitalize(), phase],
					"type": room_res.type if room_res else target_type,
					"biome": biome_id,
					"layer": current_layer,
					"phase": phase,
					"column": n_idx,
					"difficulty": current_layer,
					"room_resource_path": room_res.resource_path if room_res else "",
					"initial_dialog": "", # Suppress narrative fluff
					"connections": []
				}
				
				# Link to next layer
				if current_layer < 80:
					data.connections.append("node_%d_0" % (current_layer + 1))
					data.connections.append("node_%d_1" % (current_layer + 1))
				
				map[node_id] = data
				
	return map

func _get_room_type(phase: int) -> String:
	if phase == 10: return "event" # Boss/Unique Encounter
	if phase == 5: return "rest"
	if phase % 3 == 0: return "treasure"
	return "battle"

# --- ROOM POOL LOGIC ---

func _scan_all_rooms():
	_room_pool.clear()
	for biome in BIOMES:
		_room_pool[biome] = {}
		var path = ROOM_ROOT + biome + "/"
		_scan_biome_folder(biome, path)

func _scan_biome_folder(biome: String, path: String):
	if not DirAccess.dir_exists_absolute(path):
		push_warning("BattleMapGenerator: Biome folder missing: " + path)
		return

	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res = load(path + file_name)
			if res is RoomData:
				# Categorize by difficulty_tier (falling back to difficulty_override)
				var tier = res.get("difficulty_tier")
				if tier == null:
					tier = res.difficulty_override if res.difficulty_override > 0 else 1
				
				if not _room_pool[biome].has(tier):
					_room_pool[biome][tier] = []
				_room_pool[biome][tier].append(res)
			
		file_name = dir.get_next()

func _get_room_resource(biome: String, phase: int, type: String):
	if not _room_pool.has(biome) or _room_pool[biome].is_empty():
		return null
	
	# Match phase (1-10) to difficulty_tier
	var tier = phase
	
	# If specific tier doesn't exist, find the closest available tier
	if not _room_pool[biome].has(tier):
		var available_tiers = _room_pool[biome].keys()
		if available_tiers.is_empty(): return null
		available_tiers.sort()
		
		var best_tier = available_tiers[0]
		for t in available_tiers:
			if abs(t - tier) < abs(best_tier - tier):
				best_tier = t
		tier = best_tier
	
	# Filter possible rooms by the requested type (battle, rest, etc.)
	var possible_rooms = []
	for room in _room_pool[biome][tier]:
		if room.type == type:
			possible_rooms.append(room)
	
	# Fallback: If no room of that type exists in the tier, ignore type restriction
	if possible_rooms.is_empty():
		possible_rooms = _room_pool[biome][tier]
		
	return possible_rooms.pick_random()
