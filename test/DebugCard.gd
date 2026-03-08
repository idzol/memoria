extends Control

# res://features/ui/DebugCard.gd
# Audit tool for CardData resources. Shows interactive Back and Front faces side-by-side.

const CardData = preload("res://data/resources/CardData.gd")

@onready var card_list = %CardList

var full_card_scene = preload("res://features/combat/Card.tscn")
var card_icon_scene = preload("res://features/combat/CardIcon.tscn")

const CARD_DATA_PATH = "res://data/cards/"
const PREVIEW_WIDTH = 150.0

func _ready():
	_refresh_gallery()

func _refresh_gallery():
	for child in card_list.get_children():
		child.queue_free()
	
	_add_header()
	
	if not DirAccess.dir_exists_absolute(CARD_DATA_PATH):
		_show_error("CRITICAL: Directory not found -> " + CARD_DATA_PATH)
		return

	var dir = DirAccess.open(CARD_DATA_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".tres"):
				var res = load(CARD_DATA_PATH + file_name)
				if res is CardData:
					_create_card_row(res, file_name)
				else:
					_create_error_row(file_name, "Invalid Resource Type")
			file_name = dir.get_next()

func _create_card_row(data: CardData, filename: String):
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 260
	row.add_theme_constant_override("separation", 15)
	
	# 1. Full Card Samples
	row.add_child(_instance_sample(full_card_scene, data, false)) # Face Down
	row.add_child(_instance_sample(full_card_scene, data, true))  # Face Up
	
	row.add_child(VSeparator.new())
	
	# 2. Icon Samples
	row.add_child(_instance_sample(card_icon_scene, data, false)) # Face Down
	row.add_child(_instance_sample(card_icon_scene, data, true))  # Face Up
	
	# 3. Text Data
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var name_lbl = Label.new()
	name_lbl.text = data.name + " (" + data.type.to_upper() + ")"
	name_lbl.add_theme_font_size_override("font_size", 18)
	info.add_child(name_lbl)
	
	var file_lbl = Label.new()
	file_lbl.text = filename
	file_lbl.modulate = Color.DARK_GRAY
	info.add_child(file_lbl)
	
	row.add_child(info)
	card_list.add_child(row)
	card_list.add_child(HSeparator.new())

func _instance_sample(scene: PackedScene, data: CardData, flipped: bool) -> CenterContainer:
	var container = CenterContainer.new()
	container.custom_minimum_size.x = PREVIEW_WIDTH
	
	var inst = scene.instantiate()
	container.add_child(inst)
	
	if inst.has_method("setup"):
		inst.setup(data)
	
	if flipped:
		# Use call_deferred to ensure the setup has finished before flipping
		inst.call_deferred("flip")
		
	return container

func _add_header():
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	var labels = ["FULL (BACK)", "FULL (FRONT)", "ICON (BACK)", "ICON (FRONT)", "DATA"]
	for l in labels:
		var lbl = Label.new()
		lbl.text = l
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size.x = PREVIEW_WIDTH if l != "DATA" else 100
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL if l == "DATA" else 0
		header.add_child(lbl)
	card_list.add_child(header)
	card_list.add_child(HSeparator.new())

func _create_error_row(f: String, m: String):
	var lbl = Label.new()
	lbl.text = "ERROR: %s - %s" % [f, m]
	lbl.modulate = Color.RED
	card_list.add_child(lbl)

func _show_error(msg: String):
	var lbl = Label.new()
	lbl.text = msg
	lbl.modulate = Color.YELLOW
	card_list.add_child(lbl)
