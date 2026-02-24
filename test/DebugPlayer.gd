extends Control

# res://features/ui/DebugCharacter.gd
# Audit tool for Player Progression Stages. Updated with verbose error reporting.

# FIX: Explicitly preloading ensures 'PlayerData' type is recognized in this scope.
const PlayerData = preload("res://data/resources/PlayerData.gd")

@onready var list_container = %PlayerList

const PLAYER_ROOT = "res://data/player/"
const PREVIEW_HEIGHT = 160.0

func _ready():
	_refresh_list()

func _refresh_list():
	for child in list_container.get_children():
		child.queue_free()
	
	if not DirAccess.dir_exists_absolute(PLAYER_ROOT):
		_show_error("CRITICAL: Directory not found -> " + PLAYER_ROOT)
		return

	_scan_dir_recursive(PLAYER_ROOT)

func _scan_dir_recursive(path: String):
	var dir = DirAccess.open(path)
	if not dir: return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
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
			elif not res is PlayerData:
				_create_error_row(file_name, "TYPE ERROR: Resource is not 'PlayerData'. Check script class.")
			else:
				_add_player_row(res, file_name)
				
		file_name = dir.get_next()

func _add_player_row(data: PlayerData, filename: String):
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 200
	row.add_theme_constant_override("separation", 20)
	
	# 1. Metadata
	var info = VBoxContainer.new()
	info.custom_minimum_size.x = 220
	
	var title = Label.new()
	title.text = "[ %s ]\nStage: %s" % [data.player_class.to_upper(), data.stage.to_upper()]
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color.CYAN
	info.add_child(title)
	
	var desc = Label.new()
	desc.text = data.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate = Color(0.7, 0.7, 0.7)
	info.add_child(desc)
	
	var file_lbl = Label.new()
	file_lbl.text = filename
	file_lbl.modulate = Color.DARK_GRAY
	info.add_child(file_lbl)
	
	row.add_child(info)
	
	# 2. Previews (Idle, Attack, Defend)
	for anim_type in ["idle", "attack", "defend"]:
		var frame = Control.new()
		frame.custom_minimum_size = Vector2(180, 180)
		frame.clip_contents = true
		
		var sprite = Sprite2D.new()
		var tex = data.get(anim_type + "_sheet")
		
		if tex:
			sprite.texture = tex
			sprite.hframes = data.hframes
			sprite.vframes = data.vframes
			
			var source_h = float(tex.get_height()) / float(data.vframes)
			var s = PREVIEW_HEIGHT / source_h if source_h > 0 else 1.0
			sprite.scale = Vector2(s, s)
			sprite.position = Vector2(90, 90)
			
			_animate_ping_pong(sprite, data.total_frames, data.frame_speed)
		else:
			var err = Label.new()
			err.text = anim_type.to_upper() + "\nMISSING"
			err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			err.modulate = Color.TOMATO
			err.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			frame.add_child(err)
		
		frame.add_child(sprite)
		row.add_child(frame)
		
	list_container.add_child(row)
	list_container.add_child(HSeparator.new())

func _create_error_row(filename: String, error_msg: String):
	var row = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.05, 0.05)
	row.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	var err_lbl = Label.new()
	err_lbl.text = " BROKEN STAGE "
	err_lbl.modulate = Color.RED
	hbox.add_child(err_lbl)
	
	var info = VBoxContainer.new()
	var f_lbl = Label.new(); f_lbl.text = filename; f_lbl.modulate = Color.WHITE; info.add_child(f_lbl)
	var e_lbl = Label.new(); e_lbl.text = error_msg; e_lbl.modulate = Color.TOMATO; info.add_child(e_lbl)
	hbox.add_child(info)
	
	row.add_child(hbox)
	list_container.add_child(row)
	list_container.add_child(HSeparator.new())

func _animate_ping_pong(sprite: Sprite2D, total: int, speed: float):
	var f = 0
	var d = 1
	if total <= 1: return
	while sprite and is_inside_tree():
		sprite.frame = f
		if f >= total - 1: d = -1
		elif f <= 0: d = 1
		f += d
		await get_tree().create_timer(speed).timeout

func _show_error(msg: String):
	var lbl = Label.new()
	lbl.text = msg
	lbl.modulate = Color.YELLOW
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_container.add_child(lbl)
