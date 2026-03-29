extends Control

const RoomData = preload("res://data/resources/RoomData.gd")
const MapNodeScene = preload("res://features/map/MapNode.tscn")
const WorldMapTileBackgroundSettings = preload("res://features/map/WorldMapTileBackgroundSettings.gd")

const ROOMS_ROOT := "res://data/rooms/"
const TILE_PREVIEW_SIZE := Vector2(260, 230)
const TILE_COLUMNS := 4

@onready var section_list: VBoxContainer = %SectionList
@onready var status_label: Label = %StatusLabel

func _ready():
	_refresh_tiles()

func _refresh_tiles():
	_clear_children(section_list)
	var settings = WorldMapTileBackgroundSettings.load_settings()
	var defaults: Dictionary = settings.get("defaults", {})
	if status_label:
		status_label.text = "Overrides: %s | Default scale: %.2f x %.2f" % [
			WorldMapTileBackgroundSettings.get_settings_path(),
			float(defaults.get("scale_x", 1.0)),
			float(defaults.get("scale_y", 1.0))
		]

	if not DirAccess.dir_exists_absolute(ROOMS_ROOT):
		_show_error("Missing rooms directory: %s" % ROOMS_ROOT)
		return

	var room_entries = _collect_room_entries()
	if room_entries.is_empty():
		_show_error("No room resources found under %s" % ROOMS_ROOT)
		return

	for biome_name in room_entries.keys():
		_add_biome_section(biome_name, room_entries[biome_name])

func _collect_room_entries() -> Dictionary:
	var by_biome: Dictionary = {}
	_scan_room_dir(ROOMS_ROOT, by_biome)
	var sorted_biomes = by_biome.keys()
	sorted_biomes.sort()
	var sorted_result: Dictionary = {}
	for biome_name in sorted_biomes:
		var entries: Array = by_biome.get(biome_name, [])
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("room_name", "")) < str(b.get("room_name", ""))
		)
		sorted_result[biome_name] = entries
	return sorted_result

func _scan_room_dir(dir_path: String, by_biome: Dictionary):
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_room_dir(dir_path.path_join(file_name), by_biome)
		elif file_name.ends_with(".tres"):
			var room_path = dir_path.path_join(file_name)
			var room_res = load(room_path)
			if room_res is RoomData:
				var icon_path = room_res.map_icon.resource_path if room_res.map_icon else ""
				var biome_name = str(room_res.biome if room_res.biome != "" else file_name.get_basename())
				if not by_biome.has(biome_name):
					by_biome[biome_name] = []
				by_biome[biome_name].append({
					"room_name": room_res.room_name,
					"room_path": room_path,
					"room_type": room_res.type,
					"icon_path": icon_path
				})
		file_name = dir.get_next()
	dir.list_dir_end()

func _add_biome_section(biome_name: String, entries: Array):
	var header = Label.new()
	header.text = biome_name.replace("_", " ").capitalize()
	header.add_theme_font_size_override("font_size", 24)
	section_list.add_child(header)

	var grid = GridContainer.new()
	grid.columns = TILE_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 18)
	section_list.add_child(grid)

	for entry in entries:
		grid.add_child(_build_tile_card(entry))

func _build_tile_card(entry: Dictionary) -> Control:
	var room_path = str(entry.get("room_path", ""))
	var icon_path = str(entry.get("icon_path", ""))
	var scale = WorldMapTileBackgroundSettings.get_scale_for_room(room_path, icon_path)
	var offset = WorldMapTileBackgroundSettings.get_offset_for_room(room_path, icon_path)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(290, 360)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.11, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.26, 0.3, 0.35, 1.0)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = str(entry.get("room_name", room_path.get_file()))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var preview = CenterContainer.new()
	preview.custom_minimum_size = TILE_PREVIEW_SIZE
	vbox.add_child(preview)

	var preview_frame = Control.new()
	preview_frame.custom_minimum_size = TILE_PREVIEW_SIZE
	preview_frame.size = TILE_PREVIEW_SIZE
	preview.add_child(preview_frame)

	var node = MapNodeScene.instantiate()
	preview_frame.add_child(node)
	node.size = Vector2(180, 180)
	node.position = (TILE_PREVIEW_SIZE - node.size) * 0.5
	node.setup_biome_node({
		"id": room_path.get_file(),
		"name": str(entry.get("room_name", "")),
		"type": "background",
		"node_shape": "hex",
		"passable": false,
		"custom_icon_path": icon_path,
		"force_custom_icon": true,
		"icon_scale_x": scale.x,
		"icon_scale_y": scale.y,
		"icon_offset_x": offset.x,
		"icon_offset_y": offset.y,
		"icon_alpha": 1.0,
		"node_visual_scale": 1.0
	}, null, false, false, true, false)

	var subtitle = Label.new()
	subtitle.text = "%s | %s" % [str(entry.get("room_type", "")), room_path.get_file()]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.76, 0.78, 0.82, 0.9)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	var scale_label = Label.new()
	scale_label.text = "scale_x: %.3f | scale_y: %.3f | offset_x: %.2f | offset_y: %.2f" % [scale.x, scale.y, offset.x, offset.y]
	scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scale_label.modulate = Color(0.42, 0.74, 1.0, 1.0)
	vbox.add_child(scale_label)

	var path_label = Label.new()
	path_label.text = icon_path if icon_path != "" else "Missing map icon"
	path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_label.modulate = Color(0.65, 0.67, 0.72, 0.88)
	vbox.add_child(path_label)

	return panel

func _clear_children(node: Node):
	for child in node.get_children():
		child.queue_free()

func _show_error(message: String):
	var label = Label.new()
	label.text = message
	label.modulate = Color(1.0, 0.8, 0.4, 1.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section_list.add_child(label)
