# [AI-CONTRACT]
# FILE: res://core/AudioData.gd
# FEATURES: Centralized audio registries for Music and SFX.
# [YOLO-METADATA] TARGET: res://core/AudioData.gd

extends Node

# [CORE-008] Audio Data Registry
# This file handles the "What" so the Manager can handle the "How".

const TRACKS = {
	"MAIN_MENU": "intro_main_menu", 
	"MAIN_MENU_AMB": "intro_main_menu_ambient",
	"CREDITS": "victory_credits",
	"STORY_MENU": "story_menu",
	"STORY_MENU_AMB": "story_menu_ambient",
	# Biome Tracks	
	"TUTORIAL": "world_tutorial",
	"TOWN": "world_town",
	"FOREST": "world_forest",
	"ICE_CAVES": "world_ice_caves",
	"DESERT": "world_desert",
	"SWAMP": "world_swamp",
	"ABYSS": "world_abyss",
	"VOID": "world_void",
	"CORE": "world_the_core",
	# Ambient Layers
	"TUTORIAL_AMB": "world_tutorial_ambient",
	"TOWN_AMB": "world_town_ambient",
	"FOREST_AMB": "world_forest_ambient",
	"ICE_CAVES_AMB": "world_ice_caves_ambient",
	"DESERT_AMB": "world_desert_ambient",
	"SWAMP_AMB": "world_swamp_ambient",
	"ABYSS_AMB": "world_abyss_ambient",
	"VOID_AMB": "world_void_ambient",
	"CORE_AMB": "world_the_core_ambient",
	# Events
	"VICTORY": "victory_end",
	"BATTLE_STANDARD": "battle_scene_standard",
	# "BATTLE_STANDARD_AMB": "battle_scene_standard_ambient",
	"OBJECT_STANDARD": "object_scene_standard",
	"BATTLE_BOSS": "battle_scene_boss",
	# Event Tracks
	"EVENT_TOWN": "event_town",
	"EVENT_FOREST": "event_forest",
	"EVENT_ICE": "event_ice_caves",
	"EVENT_DESERT": "event_desert",
	"EVENT_SWAMP": "event_swamp",
	"EVENT_ABYSS": "event_abyss",
	"EVENT_VOID": "event_void",
	"EVENT_CORE": "event_the_core"
}

const SFX = {
	"START_DAY": "start_day",
	"ITEM_PICKUP": "item_pickup",
	"VICTORY": "victory",
	"DEATH": "death",
	"SWORD": "sword",
	"SHIELD": "shield",
	"HEAL": "health",
	"TRAP": "trap",
	"UI_CLICK": "ui_click"
}

# Helper to resolve IDs (allows passing either the key "VICTORY" or the ID "victory_end")
static func get_track_id(key_or_id: String) -> String:
	if TRACKS.has(key_or_id):
		return TRACKS[key_or_id]
	return key_or_id

static func get_ambient_track_id(key_or_id: String) -> String:
	var actual_id = get_track_id(key_or_id)
	for track_key in TRACKS.keys():
		if not str(track_key).ends_with("_AMB"):
			continue
		var base_key = str(track_key).trim_suffix("_AMB")
		if not TRACKS.has(base_key):
			continue
		if TRACKS[base_key] == actual_id:
			return str(TRACKS[track_key])

	var ambient_id = "%s_ambient" % actual_id
	return ambient_id if FileAccess.file_exists("res://assets/music/%s.ogg" % ambient_id) else ""

static func get_biome_track_id(biome: String) -> String:
	var normalized = biome.to_upper()
	if normalized == "HOME":
		normalized = "TUTORIAL"
	return TRACKS.get(normalized, "")

static func get_biome_ambient_track_id(biome: String) -> String:
	var normalized = biome.to_upper()
	if normalized == "HOME":
		normalized = "TUTORIAL"
	return TRACKS.get("%s_AMB" % normalized, "")

static func get_sfx_id(key_or_id: String) -> String:
	if SFX.has(key_or_id):
		return SFX[key_or_id]
	return key_or_id
