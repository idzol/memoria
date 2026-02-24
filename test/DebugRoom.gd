extends Control

# res://features/ui/DebugRoom.gd
# Audit tool for Room resources. Updated to account for every .tres file and report load errors.

# FIX: Explicitly preloading ensures 'RoomData' type is recognized in this scope.
const RoomData = preload("res://data/resources/RoomData.gd")

@onready var room_list = %RoomList

const ROOMS_ROOT = "res://data/rooms/"
const BG_PREVIEW_SIZE = Vector2(160, 90)
const ICON_PREVIEW_SIZE = Vector2(40, 40)

func _ready():
	_refresh_gallery()

func _refresh_gallery():
	for child in room_list.get_children():
		child.queue_free()
	
	if not DirAccess.dir_exists_absolute(ROOMS_ROOT):
		_show_error("CRITICAL: Directory not found -> " + ROOMS_ROOT)
		return

	_scan_dir_recursive(ROOMS_ROOT)

func _scan_dir_recursive(path: String):
	var dir = DirAccess.open(path)
	if not dir: return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	# Add a Biome Header if we are inside a subfolder
	if path != ROOMS_ROOT:
		var parts = path.rstrip("/").split("/")
		var biome_name = parts[parts.size() - 1]
		_add_biome_header(biome_name)

	while file_name != "":
		var full_path = path + file_name
		
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_dir_recursive(full_path + "/")
		elif file_name.to_lower().ends_with(".tres"):
			# ATTEMPT TO LOAD
			var res = load(full_path)
			
			if res == null:
				_create_error_row(file_name, "LOAD FAILED: File corrupted or missing script reference.")
			elif not res is RoomData:
				_create_error_row(file_name, "TYPE ERROR: Resource is not 'RoomData'. Check script class.")
			else:
				_create_room_audit_row(res, full_path)
				
		file_name = dir.get_next()

func _add_biome_header(biome_name: String):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.15)
	panel.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = " REGION: " + biome_name.to_upper()
	lbl.modulate = Color.CYAN
	panel.add_child(lbl)
	room_list.add_child(panel)

func _create_room_audit_row(data: RoomData, full_path: String):
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 100
	row.add_theme_constant_override("separation", 20)
	
	# 1. Map Icon Audit
	var icon_rect = _create_preview(data.map_icon, ICON_PREVIEW_SIZE, "Icon Missing")
	row.add_child(icon_rect)
	
	# 2. Scene Background Audit
	var bg_rect = _create_preview(data.background_texture, BG_PREVIEW_SIZE, "Scene Missing")
	row.add_child(bg_rect)
	
	# 3. Info
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	name_lbl.text = data.room_name + " (" + data.type.to_upper() + ")"
	name_lbl.add_theme_font_size_override("font_size", 18)
	info.add_child(name_lbl)
	
	var path_lbl = Label.new()
	path_lbl.text = full_path.get_file()
	path_lbl.modulate = Color.DARK_GRAY
	info.add_child(path_lbl)
	
	row.add_child(info)
	
	# 4. Test Launch
	var btn = Button.new()
	btn.text = "LAUNCH"
	btn.custom_minimum_size = Vector2(80, 40)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_launch_pressed.bind(data, full_path))
	row.add_child(btn)
	
	room_list.add_child(row)
	room_list.add_child(HSeparator.new())

func _create_error_row(filename: String, error_msg: String):
	var row = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.05, 0.05)
	row.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	var err_lbl = Label.new()
	err_lbl.text = " BROKEN ROOM "
	err_lbl.modulate = Color.RED
	hbox.add_child(err_lbl)
	
	var info = VBoxContainer.new()
	var f_lbl = Label.new(); f_lbl.text = filename; f_lbl.modulate = Color.WHITE; info.add_child(f_lbl)
	var e_lbl = Label.new(); e_lbl.text = error_msg; e_lbl.modulate = Color.TOMATO; info.add_child(e_lbl)
	hbox.add_child(info)
	
	row.add_child(hbox)
	room_list.add_child(row)
	room_list.add_child(HSeparator.new())

func _create_preview(tex: Texture2D, size: Vector2, err_msg: String) -> TextureRect:
	var tr = TextureRect.new()
	tr.custom_minimum_size = size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	if tex:
		tr.texture = tex
	else:
		tr.texture = load("res://icon.svg")
		tr.modulate = Color(1, 0, 0, 0.3)
		var lbl = Label.new()
		lbl.text = err_msg
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		tr.add_child(lbl)
	return tr

func _show_error(msg: String):
	var lbl = Label.new()
	lbl.text = msg
	lbl.modulate = Color.YELLOW
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_list.add_child(lbl)

func _on_launch_pressed(data: RoomData, path: String):
	GameManager.current_node = {
		"id": "debug",
		"room_resource_path": path,
		"type": data.type,
		"difficulty": 1
	}
	get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")