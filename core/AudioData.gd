# [AI-CONTRACT]
# FILE: res://core/AudioData.gd
# FEATURES: Centralized audio registries for Music and SFX.
# [YOLO-METADATA] TARGET: res://core/AudioData.gd

extends Node

# [CORE-008] Audio Data Registry
# This file handles the "What" so the Manager can handle the "How".

const TRACKS = {
	"MAIN_MENU": "intro_main_menu",
	"CREDITS": "intro_credits",
	"VICTORY": "victory_end",
	"BATTLE_STANDARD": "battle_scene_standard",
	"BATTLE_BOSS": "battle_scene_boss",
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

static func get_sfx_id(key_or_id: String) -> String:
	if SFX.has(key_or_id):
		return SFX[key_or_id]
	return key_or_id
