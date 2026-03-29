extends RefCounted
class_name WorldMapTileBackgroundSettings

const SETTINGS_PATH := "res://data/map/worldmap_tile_background_scales.json"
const DEFAULT_SCALE_X := 1.0
const DEFAULT_SCALE_Y := 1.0
const DEFAULT_OFFSET_X := 0.0
const DEFAULT_OFFSET_Y := 0.0

static func get_settings_path() -> String:
	return SETTINGS_PATH

static func load_settings() -> Dictionary:
	var defaults := _build_default_document()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return defaults
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return defaults
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return defaults
	return _normalize_document(parsed)

static func save_settings(document: Dictionary) -> bool:
	var normalized = _normalize_document(document)
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalized, "\t"))
	return true

static func get_scale_for_room(room_path: String, icon_path: String = "") -> Vector2:
	var entry = _get_room_entry(room_path, icon_path)
	var document = load_settings()
	var defaults = document.get("defaults", {})
	var fallback_x = float(defaults.get("scale_x", DEFAULT_SCALE_X))
	var fallback_y = float(defaults.get("scale_y", DEFAULT_SCALE_Y))
	return Vector2(
		float(entry.get("scale_x", fallback_x)),
		float(entry.get("scale_y", fallback_y))
	)

static func get_offset_for_room(room_path: String, icon_path: String = "") -> Vector2:
	var entry = _get_room_entry(room_path, icon_path)
	var document = load_settings()
	var defaults = document.get("defaults", {})
	var fallback_x = float(defaults.get("offset_x", DEFAULT_OFFSET_X))
	var fallback_y = float(defaults.get("offset_y", DEFAULT_OFFSET_Y))
	return Vector2(
		float(entry.get("offset_x", fallback_x)),
		float(entry.get("offset_y", fallback_y))
	)

static func _build_default_document() -> Dictionary:
	return {
		"version": 1,
		"defaults": {
			"scale_x": DEFAULT_SCALE_X,
			"scale_y": DEFAULT_SCALE_Y,
			"offset_x": DEFAULT_OFFSET_X,
			"offset_y": DEFAULT_OFFSET_Y
		},
		"rooms": {}
	}

static func _normalize_document(raw: Dictionary) -> Dictionary:
	var normalized = _build_default_document()
	normalized["version"] = int(raw.get("version", 1))
	var raw_defaults = raw.get("defaults", {})
	if raw_defaults is Dictionary:
		normalized["defaults"] = {
			"scale_x": float(raw_defaults.get("scale_x", DEFAULT_SCALE_X)),
			"scale_y": float(raw_defaults.get("scale_y", DEFAULT_SCALE_Y)),
			"offset_x": float(raw_defaults.get("offset_x", DEFAULT_OFFSET_X)),
			"offset_y": float(raw_defaults.get("offset_y", DEFAULT_OFFSET_Y))
		}

	var raw_rooms = raw.get("rooms", {})
	var normalized_rooms: Dictionary = {}
	if raw_rooms is Dictionary:
		var sorted_room_paths = raw_rooms.keys()
		sorted_room_paths.sort()
		for room_path in sorted_room_paths:
			var entry = raw_rooms.get(room_path, {})
			if not (entry is Dictionary):
				continue
			normalized_rooms[str(room_path)] = {
				"texture_path": str(entry.get("texture_path", "")),
				"scale_x": float(entry.get("scale_x", normalized["defaults"]["scale_x"])),
				"scale_y": float(entry.get("scale_y", normalized["defaults"]["scale_y"])),
				"offset_x": float(entry.get("offset_x", normalized["defaults"]["offset_x"])),
				"offset_y": float(entry.get("offset_y", normalized["defaults"]["offset_y"]))
			}
	normalized["rooms"] = normalized_rooms
	return normalized

static func _get_room_entry(room_path: String, icon_path: String = "") -> Dictionary:
	var document = load_settings()
	var rooms: Dictionary = document.get("rooms", {})
	var entry: Dictionary = rooms.get(room_path, {})
	if entry.is_empty() and icon_path != "":
		for candidate_room_path in rooms.keys():
			var candidate = rooms.get(candidate_room_path, {})
			if str(candidate.get("texture_path", "")) == icon_path:
				entry = candidate
				break
	return entry
