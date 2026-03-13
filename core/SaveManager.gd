extends Node

# res://core/SaveManager.gd
# Manages multi-slot run saves and persistent account progression.

const SAVE_DIR = "user://saves/"
const ACCOUNT_SAVE = "user://account_progression.json"

func _ready():
	# Ensure the save directory exists on boot
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

# --- Account Progression ---
func save_progression(data: Dictionary):
	var file = FileAccess.open(ACCOUNT_SAVE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_progression() -> Dictionary:
	if not FileAccess.file_exists(ACCOUNT_SAVE): return {}
	var file = FileAccess.open(ACCOUNT_SAVE, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file else {}

# --- Multi-Slot Run Management ---

func get_save_list() -> Array:
	var saves = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var full_path = SAVE_DIR + file_name
				var data = _load_file_raw(full_path)
				if data:
					# Add file reference for deletion/loading
					data["filename"] = file_name
					saves.append(data)
			file_name = dir.get_next()
	
	# Sort by date (newest first)
	saves.sort_custom(func(a, b): return a.last_saved > b.last_saved)
	return saves

func save_mid_run_state():
	if GameManager.player_name == "": return
	GameManager.refresh_story_room_completions()
	
	# AUTHENTICATED PROFILE DATA
	var run_data = {
		"is_battle_mode": GameManager.is_battle_mode,
		"player_name": GameManager.player_name,
		"player_class": GameManager.player_class,
		"player_level": GameManager.player_level,
		"player_xp": GameManager.player_xp,
		"last_xp_gained": GameManager.last_xp_gained,
		"pending_level_up": var_to_str(GameManager.pending_level_up),
		"level_up_return_scene": GameManager.level_up_return_scene,
		"pending_post_battle_scene": GameManager.pending_post_battle_scene,
		"player_biome": GameManager.player_biome,
		"selected_story_biome": GameManager.selected_story_biome,
		"profile_return_scene": GameManager.profile_return_scene,

		"hp": GameManager.current_hp,
		"max_hp": GameManager.max_hp,
		"gold": GameManager.gold,
		"base_energy": GameManager.base_energy,
		"base_attack": GameManager.base_attack,
		"base_defense": GameManager.base_defense,
		"current_energy": GameManager.current_energy,
		"player_attack": GameManager.player_attack,
		"player_defense": GameManager.player_defense,
		
		"deck": GameManager.player_deck,
		"active_deck": GameManager.active_deck,

		"items": GameManager.player_items,
		"active_items": GameManager.active_items,
		"world_state": var_to_str(GameManager.world_state),
		"current_node": var_to_str(GameManager.current_node),
		"run_map": var_to_str(GameManager.run_map),
		"biome_run_paths": var_to_str(GameManager.biome_run_paths),
		"pending_loot": var_to_str(GameManager.pending_loot),
		"run_loot": var_to_str(GameManager.run_loot),
		
		"completed_nodes": GameManager.completed_nodes,
		"current_run_visited_nodes": var_to_str(GameManager.current_run_visited_nodes),
		"grid_pos": [GameManager.player_grid_pos.x, GameManager.player_grid_pos.y],
		
		"last_saved": Time.get_unix_time_from_system(),
		"save_date_text": Time.get_datetime_string_from_system(false, true)
	}
	
	var safe_name = GameManager.player_name.validate_filename()
	var path = SAVE_DIR + "run_" + safe_name + ".json"
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(run_data))
		file.close()

func delete_run(filename: String):
	var path = SAVE_DIR + filename
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _load_file_raw(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			return json.get_data()
	return {}
