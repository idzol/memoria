extends Control

# res://features/ui/DebugItem.gd
# Audit tool for item resources. Updated to provide verbose error reporting for missing/broken data.

# FIX: Explicitly preloading the script ensures 'ItemData' is a valid type in this scope.
const ItemData = preload("res://data/resources/ItemData.gd")

@onready var item_list = %ItemList

const ITEM_DATA_PATH = "res://data/items/"
const LARGE_IMAGE_SIZE = Vector2(100, 100)
const ICON_SIZE = Vector2(40, 40)

func _ready():
	_refresh_gallery()

func _refresh_gallery():
	# Clear existing entries
	for child in item_list.get_children():
		child.queue_free()
	
	_add_header()
	
	if not DirAccess.dir_exists_absolute(ITEM_DATA_PATH):
		_show_error("CRITICAL: Directory not found -> " + ITEM_DATA_PATH)
		_show_error("Please ensure the folder 'res://data/items/' exists in your Godot project.")
		return

	var dir = DirAccess.open(ITEM_DATA_PATH)
	var tres_count = 0
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Only process actual files ending in .tres
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".tres"):
				tres_count += 1
				var full_path = ITEM_DATA_PATH + file_name
				
				# Attempt to load the resource
				var res = load(full_path)
				
				if res == null:
					_create_error_row(file_name, "LOAD FAILED: File may be missing assets or script path is broken. Check console errors.")
				elif not res is ItemData:
					_create_error_row(file_name, "TYPE ERROR: Resource is not 'ItemData'. Check the 'script' property in the .tres.")
				else:
					_create_item_row(res, file_name)
			
			file_name = dir.get_next()
			
	if tres_count == 0:
		_show_error("No .tres files detected in " + ITEM_DATA_PATH)
		_show_error("Godot Tip: If files exist in Windows Explorer but not here, try restarting the Godot Editor to force an import refresh.")

func _create_item_row(data: ItemData, filename: String):
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 120
	row.add_theme_constant_override("separation", 20)
	
	# 1. High-Res Image Audit
	var large_rect = _create_texture_rect(data.item_image, LARGE_IMAGE_SIZE, "Full Image Missing")
	row.add_child(large_rect)
	
	# 2. Icon Audit
	var icon_rect = _create_texture_rect(data.item_icon, ICON_SIZE, "Icon Missing")
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size.x = 60
	icon_container.add_child(icon_rect)
	row.add_child(icon_container)
	
	# 3. Data Details
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var name_lbl = Label.new()
	name_lbl.text = "%s [%s]" % [data.name, data.type.to_upper()]
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.modulate = Color.CYAN
	info.add_child(name_lbl)
	
	var stats_lbl = Label.new()
	stats_lbl.text = "HP: %d | ATK: %d | DEF: %d" % [data.hp, data.attack, data.armour]
	stats_lbl.modulate = Color.DARK_GRAY
	info.add_child(stats_lbl)
	
	row.add_child(info)
	
	# 4. Filename Meta
	var file_lbl = Label.new()
	file_lbl.text = filename
	file_lbl.modulate = Color(0.4, 0.4, 0.4)
	file_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(file_lbl)
	
	item_list.add_child(row)
	item_list.add_child(HSeparator.new())

func _create_error_row(filename: String, error_msg: String):
	var row = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.05, 0.05)
	row.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	var err_icon = Label.new()
	err_icon.text = " ERROR "
	err_icon.modulate = Color.RED
	hbox.add_child(err_icon)
	
	var info = VBoxContainer.new()
	var f_lbl = Label.new(); f_lbl.text = filename; f_lbl.modulate = Color.WHITE; info.add_child(f_lbl)
	var e_lbl = Label.new(); e_lbl.text = error_msg; e_lbl.modulate = Color.TOMATO; info.add_child(e_lbl)
	hbox.add_child(info)
	
	row.add_child(hbox)
	item_list.add_child(row)
	item_list.add_child(HSeparator.new())

func _create_texture_rect(tex: Texture2D, target_size: Vector2, err_msg: String) -> TextureRect:
	var tr = TextureRect.new()
	tr.custom_minimum_size = target_size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if tex:
		tr.texture = tex
	else:
		tr.texture = load("res://icon.svg")
		tr.modulate = Color(1, 0, 0, 0.4)
		var lbl = Label.new()
		lbl.text = err_msg
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		tr.add_child(lbl)
		
	return tr

func _add_header():
	var header = HBoxContainer.new()
	var h1 = Label.new(); h1.text = "IMAGE"; h1.custom_minimum_size.x = LARGE_IMAGE_SIZE.x; h1.horizontal_alignment = 1
	var h2 = Label.new(); h2.text = "ICON"; h2.custom_minimum_size.x = 60; h2.horizontal_alignment = 1
	var h3 = Label.new(); h3.text = "ITEM DATA & STATS"; h3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h4 = Label.new(); h4.text = "SOURCE FILE"
	
	header.add_child(h1); header.add_child(h2); header.add_child(h3); header.add_child(h4)
	item_list.add_child(header)
	item_list.add_child(HSeparator.new())

func _show_error(msg: String):
	var lbl = Label.new()
	lbl.text = msg
	lbl.modulate = Color.YELLOW
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_list.add_child(lbl)
