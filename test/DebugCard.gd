extends Control

# res://features/ui/DebugCard.gd
# Audit tool for CardData resources, full art, and grid icons.

@onready var card_list = %CardList

const CARD_DATA_PATH = "res://data/cards/"
const LARGE_ART_SIZE = Vector2(100, 150) # Taller aspect for cards
const ICON_SIZE = Vector2(50, 50)        # Square for grid icons

func _ready():
	_refresh_gallery()

func _refresh_gallery():
	for child in card_list.get_children():
		child.queue_free()
	
	_add_header()
	
	if not DirAccess.dir_exists_absolute(CARD_DATA_PATH):
		_show_error("Directory not found: " + CARD_DATA_PATH)
		return

	var dir = DirAccess.open(CARD_DATA_PATH)
	var found_any = false
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = CARD_DATA_PATH + file_name
				var res = load(full_path)
				
				if res is CardData:
					_create_card_row(res, file_name)
					found_any = true
				else:
					push_warning("DebugCard: %s is not a valid CardData resource." % file_name)
			
			file_name = dir.get_next()
			
	if not found_any:
		_show_error("No Card .tres files found in " + CARD_DATA_PATH)

func _create_card_row(data: CardData, filename: String):
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 170
	row.add_theme_constant_override("separation", 20)
	
	# 1. Full Art Preview
	var art_rect = _create_texture_rect(data.card_image, LARGE_ART_SIZE)
	row.add_child(art_rect)
	
	# 2. Grid Icon Preview
	var icon_rect = _create_texture_rect(data.card_icon, ICON_SIZE)
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size.x = 80
	icon_container.add_child(icon_rect)
	row.add_child(icon_container)
	
	# 3. Card Details
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var title_hbox = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = data.name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.modulate = _get_type_color(data.type)
	title_hbox.add_child(name_lbl)
	
	var type_lbl = Label.new()
	type_lbl.text = " [%s]" % data.type.to_upper()
	type_lbl.modulate = Color(0.5, 0.5, 0.5)
	title_hbox.add_child(type_lbl)
	text_vbox.add_child(title_hbox)
	
	var stats_lbl = Label.new()
	stats_lbl.text = "Value: %d | Effect: %s" % [data.value, data.special_effect if data.special_effect != "" else "None"]
	stats_lbl.modulate = Color.GOLD
	text_vbox.add_child(stats_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = data.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.modulate = Color(0.8, 0.8, 0.8)
	text_vbox.add_child(desc_lbl)
	
	row.add_child(text_vbox)
	
	# 4. File Path
	var file_lbl = Label.new()
	file_lbl.text = filename
	file_lbl.modulate = Color.DARK_GRAY
	row.add_child(file_lbl)
	
	card_list.add_child(row)
	card_list.add_child(HSeparator.new())

func _create_texture_rect(tex: Texture2D, target_size: Vector2) -> TextureRect:
	var tr = TextureRect.new()
	tr.custom_minimum_size = target_size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if tex:
		tr.texture = tex
	else:
		tr.texture = load("res://icon.svg")
		tr.modulate = Color(1, 0.2, 0.2, 0.6)
		var err_lbl = Label.new()
		err_lbl.text = "MISSING"
		err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		err_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		tr.add_child(err_lbl)
		
	return tr

func _get_type_color(type: String) -> Color:
	match type.lower():
		"attack": return Color.INDIAN_RED
		"armor": return Color.SKY_BLUE
		"heal": return Color.LIGHT_GREEN
		"trap": return Color.ORANGE_RED
		"treasure": return Color.GOLD
		_: return Color.WHITE

func _add_header():
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	
	var h1 = Label.new(); h1.text = "FULL ART"; h1.custom_minimum_size.x = LARGE_ART_SIZE.x; h1.horizontal_alignment = 1
	var h2 = Label.new(); h2.text = "ICON"; h2.custom_minimum_size.x = 80; h2.horizontal_alignment = 1
	var h3 = Label.new(); h3.text = "CARD SPECIFICATIONS"; h3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h4 = Label.new(); h4.text = "FILENAME"
	
	header.add_child(h1); header.add_child(h2); header.add_child(h3); header.add_child(h4)
	card_list.add_child(header)
	card_list.add_child(HSeparator.new())

func _show_error(msg: String):
	var lbl = Label.new()
	lbl.text = msg
	lbl.modulate = Color.TOMATO
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_list.add_child(lbl)