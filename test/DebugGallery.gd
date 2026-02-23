extends Control

# res://features/ui/DebugGallery.gd
# Visual testing hub for all Enemies and NPCs.
# FIXES: Unified NPC/Enemy preview slots and added robust asset validation.

@onready var enemy_list = get_node_or_null("%EnemyList")
@onready var npc_list = get_node_or_null("%NPCList")

# CONFIGURATION: Ensure these match your actual folder structure
const ENEMY_PATH = "res://data/enemies/"
const NPC_PATH = "res://data/npcs/" 
const BATTLE_PORTRAIT_HEIGHT = 160.0 

func _ready():
	_check_directories()
	_refresh_galleries()
	_setup_state_manipulator()

func _check_directories():
	for path in [ENEMY_PATH, NPC_PATH]:
		if not DirAccess.dir_exists_absolute(path):
			push_warning("DebugGallery: Directory missing: %s" % path)

func _refresh_galleries():
	if enemy_list: _populate_list(ENEMY_PATH, enemy_list, "Enemy")
	if npc_list: _populate_list(NPC_PATH, npc_list, "NPC")

func _populate_list(dir_path: String, container: VBoxContainer, type: String):
	if not container: return
	for child in container.get_children(): child.queue_free()
	
	container.add_child(_create_row_ui(null, true, type))
	
	if not DirAccess.dir_exists_absolute(dir_path):
		_add_debug_label(container, "DIR NOT FOUND: " + dir_path, Color.RED)
		return

	var dir = DirAccess.open(dir_path)
	var files_on_disk = 0
	var successfully_loaded = 0
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var is_tres = file_name.to_lower().ends_with(".tres")
				var is_remap = file_name.to_lower().ends_with(".tres.remap")
				
				if is_tres or is_remap:
					files_on_disk += 1
					var clean_path = file_name.replace(".remap", "")
					var full_path = dir_path + clean_path
					
					var res = load(full_path)
					
					if res: 
						container.add_child(_create_row_ui(res, false, type, full_path))
						successfully_loaded += 1
					else:
						_add_debug_label(container, "CORRUPT .TRES: " + clean_path, Color.TOMATO)
						printerr("DebugGallery: %s contains references to files that don't exist." % clean_path)
				
			file_name = dir.get_next()
	
	if successfully_loaded == 0:
		if files_on_disk > 0:
			_add_debug_label(container, str(files_on_disk) + " found, but all had missing assets.", Color.YELLOW)
		else:
			_add_debug_label(container, "0 files found in: " + dir_path, Color.ORANGE)

func _add_debug_label(container: Control, text: String, color: Color):
	var lbl = Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(lbl)

func _create_row_ui(res: Resource, is_header: bool, type: String, full_path: String = "") -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	
	# Unified format for both Enemy and NPC
	var columns = ["Name", "Idle", "Action 1", "Action 2", "Test"]
	
	for col in columns:
		var control = Control.new()
		var cell_w = 180 if col != "Name" else 220
		control.custom_minimum_size = Vector2(cell_w, 180)
		control.clip_contents = true
		
		if is_header:
			control.custom_minimum_size.y = 40
			var lbl = Label.new()
			# Contextual Header names
			if type == "NPC":
				match col:
					"Action 1": lbl.text = "TALK"
					"Action 2": lbl.text = "INTERACT"
					_: lbl.text = col.to_upper()
			else:
				match col:
					"Action 1": lbl.text = "ATTACK"
					"Action 2": lbl.text = "DEFEND"
					_: lbl.text = col.to_upper()
					
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			control.add_child(lbl)
		else:
			match col:
				"Name":
					var lbl = Label.new()
					lbl.text = res.get("name") if res.get("name") else "Unknown"
					lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
					control.add_child(lbl)
				"Idle", "Action 1", "Action 2":
					var anim = _create_anim_preview(res, col, type)
					control.add_child(anim)
				"Test":
					var btn = Button.new()
					btn.text = "LAUNCH"
					btn.custom_minimum_size = Vector2(100, 40)
					btn.pressed.connect(_on_launch_pressed.bind(full_path, type))
					btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
					control.add_child(btn)
					
		row.add_child(control)
	return row

func _create_anim_preview(res: Resource, slot: String, type: String) -> Sprite2D:
	var sprite = Sprite2D.new()
	var prop_name = "idle_sheet"
	
	# Map generic slots to specific resource properties
	if type == "Enemy":
		match slot:
			"Action 1": prop_name = "attack_sheet"
			"Action 2": prop_name = "defend_sheet"
	else: # NPC
		match slot:
			"Action 1": prop_name = "talk_sheet"
			"Action 2": prop_name = "interact_sheet"
	
	var tex = res.get(prop_name)
	
	# FALLBACK: If Talk sheet is missing for NPC, use Idle
	if not tex and type == "NPC" and slot == "Action 1":
		tex = res.get("idle_sheet")
		sprite.modulate = Color(0.7, 0.7, 1.0, 0.5)
	
	if tex:
		sprite.texture = tex
		# Use resource values or safe defaults (8x1)
		sprite.hframes = res.get("hframes") if res.get("hframes") else 8
		sprite.vframes = res.get("vframes") if res.get("vframes") else 1
		
		var source_h = float(tex.get_height()) / float(sprite.vframes)
		var target_scale = BATTLE_PORTRAIT_HEIGHT / source_h if source_h > 0 else 1.0
		
		sprite.scale = Vector2(target_scale, target_scale)
		sprite.position = Vector2(90, 90) 
		_animate_ping_pong(sprite, res.get("total_frames"), res.get("frame_speed"))
	else:
		var lbl = Label.new()
		lbl.text = "[NONE]"
		lbl.modulate = Color.GRAY
		lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		sprite.add_child(lbl)
		
	return sprite

func _animate_ping_pong(sprite: Sprite2D, total: int, speed: float):
	if total <= 1: return
	var frame = 0
	var dir = 1
	while sprite and is_inside_tree():
		sprite.frame = frame
		if frame >= total - 1: dir = -1
		elif frame <= 0: dir = 1
		frame += dir
		await get_tree().create_timer(speed if speed > 0 else 0.1).timeout

func _setup_state_manipulator():
	if has_node("%HPSpin"): 
		%HPSpin.value = GameManager.current_hp
		%HPSpin.value_changed.connect(func(v): GameManager.current_hp = int(v))
	if has_node("%GoldSpin"): 
		%GoldSpin.value = GameManager.gold
		%GoldSpin.value_changed.connect(func(v): GameManager.gold = int(v))

func _on_launch_pressed(path: String, type: String):
	GameManager.current_node = {
		"id": "debug",
		"room_resource_path": path, 
		"type": "battle" if type == "Enemy" else "event"
	}
	var scene = "res://features/combat/BattleScene.tscn" if type == "Enemy" else "res://features/encounters/EventScene.tscn"
	get_tree().change_scene_to_file(scene)