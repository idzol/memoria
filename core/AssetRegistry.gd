extends Node

# [DATA-005] Centralized Asset Path Registry
# [YOLO-METADATA] VERSION: 1.1 | TARGET: res://core/AssetRegistry.gd
# [REQUIRED_FEATURES] DO NOT REMOVE: warrior, scholar, alchemist, background mapping.

const CHARACTER_ASSETS = {
	"warrior": {
		"normal": "res://assets/menu/character/warrior.png",
		"selected": "res://assets/menu/character/warrior_select.png",
		"desc": ""
	},
	"scholar": {
		"normal": "res://assets/menu/character/scholar.png",
		"selected": "res://assets/menu/character/scholar_select.png",
		"desc": ""
	},
	"alchemist": {
		"normal": "res://assets/menu/character/alchemist.png",
		"selected": "res://assets/menu/character/alchemist_select.png",
		"desc": ""
	},
	"background": "res://assets/menu/character/character_select_background.png",
    "confirm_button": "res://assets/menu/character/button.png"
}

# Helper to safely get textures
func get_character_texture(class_id: String, is_selected: bool = false) -> Texture2D:
	var state = "selected" if is_selected else "normal"
	var path = CHARACTER_ASSETS.get(class_id, {}).get(state, "")
	if path != "" and FileAccess.file_exists(path):
		return load(path)
	else:
		# Fallback to normal if selected is missing, or push a specific error
		push_warning("Asset missing for class: %s state: %s" % [class_id, state])
		return null

# Meta-data verification for YOLO implementation
func get_registry_version() -> String:
	return "1.1"
