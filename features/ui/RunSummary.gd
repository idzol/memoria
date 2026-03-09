extends Control

# res://features/ui/RunSummary.gd
# Displays final stats and handles mode-specific redirection.

@onready var result_title = %ResultTitle
@onready var level_label = %LevelLabel
@onready var rooms_label = %RoomsLabel
@onready var card_container = %CardContainer
@onready var item_container = %ItemContainer
@onready var menu_button = %MenuButton

const CardIconScene = preload("res://features/combat/CardIcon.tscn")

var _is_exiting: bool = false

func _ready():
	_setup_summary()
	if menu_button:
		menu_button.pressed.connect(_on_exit_pressed)
		menu_button.grab_focus()

func _input(event):
	if _is_exiting:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_SPACE:
		_on_exit_pressed()

func _setup_summary():
	# 1. Title Logic
	if GameManager.current_hp > 0:
		result_title.text = "RUN COMPLETED"
		result_title.modulate = Color.GOLD
	else:
		result_title.text = "DIVINITY LOST"
		result_title.modulate = Color.CRIMSON

	# 2. Basic Stats
	level_label.text = "Level %d %s" % [GameManager.player_level, GameManager.player_class]

	var rooms_cleared = 0
	for id in GameManager.world_state.rooms:
		if GameManager.world_state.rooms[id].get("cleared", false):
			rooms_cleared += 1
	rooms_label.text = "Rooms Conquered: %d" % rooms_cleared

	# 3. Populate Card Collection
	for child in card_container.get_children():
		child.queue_free()
	for card_id in GameManager.active_deck:
		var ci = CardIconScene.instantiate()
		card_container.add_child(ci)
		var res = DataManager.get_resource("res://data/cards/" + card_id + ".tres")
		if res:
			ci.setup(res)
			ci.get_node("%BackFace").visible = false
			ci.get_node("%FrontFace").visible = true
			ci.is_face_up = true

	# 4. Populate Items
	for child in item_container.get_children():
		child.queue_free()
	for item_id in GameManager.active_items:
		var lbl = Label.new()
		lbl.text = " - " + item_id.replace("_", " ").capitalize()
		lbl.add_theme_font_size_override("font_size", 18)
		item_container.add_child(lbl)

func _on_exit_pressed():
	if _is_exiting:
		return
	_is_exiting = true
	await _fade_to_white()
	await get_tree().create_timer(1.5).timeout

	if GameManager.run_summary_exit_to_main_menu:
		GameManager.run_summary_exit_to_main_menu = false
		get_tree().change_scene_to_file("res://features/ui/MainMenu.tscn")
		return

	if GameManager.is_battle_mode:
		# Battle mode: return to Main Menu
		get_tree().change_scene_to_file("res://features/ui/MainMenu.tscn")
	else:
		# Story mode: return to world map UI at home with full health
		GameManager.reset_to_home()
		GameManager.current_hp = GameManager.max_hp
		SaveManager.save_mid_run_state()
		get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")

func _fade_to_white():
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	
	var fade_rect = ColorRect.new()
	fade_rect.color = Color(1, 1, 1, 0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "color:a", 0.7, 0.45)
	tween.tween_property(fade_rect, "color:a", 1.0, 0.35)
	await tween.finished
