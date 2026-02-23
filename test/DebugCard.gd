extends Control

# res://features/ui/DebugCard.gd
# Audit tool for CardData resources. Accounts for every .tres file and reports errors.

# Explicitly preloading ensures 'CardData' type is recognized in this scope.
const CardData = preload("res://data/resources/CardData.gd")

@onready var card_list = %CardList

const CARD_DATA_PATH = "res://data/cards/"
const ART_PREVIEW_SIZE = Vector2(100, 140)
const ICON_PREVIEW_SIZE = Vector2(50, 50)

func _ready():
	_refresh_gallery()

func _refresh_gallery():
	# Clear existing entries
	for child in card_list.get_children():
		child.queue_free()
	
	_add_header()
	
	if not DirAccess.dir_exists_absolute(CARD_DATA_PATH):
		_show_error("CRITICAL: Directory not found -> " + CARD_DATA_PATH)
		return

	var dir = DirAccess.open(CARD_DATA_PATH)
	var tres_count = 0
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Only process actual files ending in .tres
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".tres"):
				tres_count += 1
				var full_path = CARD_DATA_PATH + file_name
				
				# ATTEMPT TO LOAD
				# Note: If internal assets are missing, Godot will log to console,
				# but the 'res' object will still exist for metadata inspection.
				var res = load(full_path)
				
				if res == null:
					_create_error_row(file_name, "LOAD FAILED: File corrupted or missing script reference.")
				elif not res is CardData:
					_create_error_row(file_name, "TYPE ERROR: Resource is not 'CardData'. Check the script class.")
				else:
					_create_card_row(res, file_name)
			
			file_name = dir.get_next()
			
	if tres_count == 0:
		_show_error("No .tres files detected in " + CARD_DATA_PATH)

func _create_card_row(data: CardData, filename: String):
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 160
	row.add_theme_constant_override("separation", 20)
	
	# 1. Full Art Audit
	var art_rect = _create_preview(data.card_image, ART_PREVIEW_SIZE, "Art Missing")
	row.add_child(art_rect)
	
	# 2. Grid Icon Audit
	var icon_rect = _create_preview(data.card_icon, ICON_PREVIEW_SIZE, "Icon Missing")
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size.x = 80
	icon_container.add_child(icon_rect)
	row.add_child(icon_container)
	
	# 3. Card Data & Stats
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var title_hbox = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = data.name if data.name != "" else "[UNNAMED]"
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.modulate = _get_type_color(data.type)
	title_hbox.add_child(name_lbl)
	
	var type_lbl = Label.new()
	type_lbl.text = " (%s)" % data.type.to_upper()
	type_lbl.modulate = Color(0.5, 0.5, 0.5)
	title_hbox.add_child(type_lbl)
	info.add_child(title_hbox)
	
	var stats_lbl = Label.new()
	var effect_text = " | " + data.special_effect if data.special_effect != "" else ""
	stats_lbl.text = "Value: %d%s" % [data.value, effect_text]
	stats_lbl.modulate = Color.GOLD
	info.add_child(stats_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = data.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.modulate = Color(0.8, 0.8, 0.8)
	info.add_child(desc_lbl)
	
	row.add_child(info)
	
	# 4. Source Metadata
	var file_lbl = Label.new()
	file_lbl.text = filename
	file_lbl.modulate = Color.DARK_GRAY
	file_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(file_lbl)
	
	card_list.add_child(row)
	card_list.add_child(HSeparator.new())

func _create_error_row(filename: String, error_msg: String):
	var row = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.05, 0.05)
	row.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	var err_lbl = Label.new()
	err_lbl.text = " BROKEN CARD "
	err_lbl.modulate = Color.RED
	hbox.add_child(err_lbl)
	
	var info = VBoxContainer.new()
	var f_lbl = Label.new(); f_lbl.text = filename; f_lbl.modulate = Color.WHITE; info.add_child(f_lbl)
	var e_lbl = Label.new(); e_lbl.text = error_msg; e_lbl.modulate = Color.TOMATO; info.add_child(e_lbl)
	hbox.add_child(info)
	
	row.add_child(hbox)
	card_list.add_child(row)
	card_list.add_child(HSeparator.new())

func _create_preview(tex: Texture2D, size: Vector2, err_msg: String) -> TextureRect:
	var tr = TextureRect.new()
	tr.custom_minimum_size = size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if tex:
		tr.texture = tex
		tr.modulate = Color.WHITE
	else:
		# Visual placeholder for missing art
		tr.texture = load("res://icon.svg")
		tr.modulate = Color(1, 0, 0, 0.3)
		var lbl = Label.new()
		lbl.text = err_msg
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		tr.add_child(lbl)
	return tr

func _get_type_color(type: String) -> Color:
	match type.to_lower():
		"attack": return Color.INDIAN_RED
		"armor": return Color.SKY_BLUE
		"heal": return Color.LIGHT_GREEN
		"trap": return Color.ORANGE_RED
		"treasure": return Color.GOLD
		_: return Color.WHITE

func _add_header():
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	var h1 = Label.new(); h1.text = "FULL ART"; h1.custom_minimum_size.x = ART_PREVIEW_SIZE.x; h1.horizontal_alignment = 1
	var h2 = Label.new(); h2.text = "ICON"; h2.custom_minimum_size.x = 80; h2.horizontal_alignment = 1
	var h3 = Label.new(); h3.text = "CARD SPECIFICATIONS & DESCRIPTION"; h3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h4 = Label.new(); h4.text = "FILENAME"
	
	header.add_child(h1); header.add_child(h2); header.add_child(h3); header.add_child(h4)
	card_list.add_child(header)
	card_list.add_child(HSeparator.new())

func _show_error(msg: String):
	var lbl = Label.new()
	lbl.text = msg
	lbl.modulate = Color.YELLOW
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_list.add_child(lbl)