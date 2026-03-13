extends Control

@onready var chapter_row = %ChapterRow
@onready var scroll_container = %ScrollContainer
@onready var avatar_button = %AvatarButton
@onready var map_button = %MapButton
@onready var header_label = %HeaderLabel

var chapter_entries: Array[Dictionary] = []
var selected_index: int = 0
var _selected_style: StyleBoxFlat
var _default_style: StyleBoxFlat

const STORY_ORDER = ["town", "forest", "ice_caves", "desert", "swamp", "abyss", "void", "the_core"]

func _ready():
	_create_styles()
	if avatar_button:
		avatar_button.pressed.connect(_open_character_screen)
	if map_button:
		map_button.pressed.connect(_open_selected_biome_map)
	_rebuild_chapters()

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_W:
		_open_selected_biome_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_move_selection(-1, 0)
	elif event.is_action_pressed("ui_right"):
		_move_selection(1, 0)
	elif event.is_action_pressed("ui_up"):
		_move_selection(0, -1)
	elif event.is_action_pressed("ui_down"):
		_move_selection(0, 1)
	elif event.is_action_pressed("ui_accept"):
		_activate_selected_entry()

func _rebuild_chapters():
	for child in chapter_row.get_children():
		child.queue_free()
	chapter_entries.clear()

	var unlocked = GameManager.get_unlocked_story_biomes()
	var show_story = not GameManager.is_battle_mode
	header_label.text = "Story Chapters" if show_story else "Biome Chapters"

	for biome in STORY_ORDER:
		if not unlocked.has(biome):
			continue
		var chapter = VBoxContainer.new()
		chapter.custom_minimum_size = Vector2(260, 720)
		chapter.add_theme_constant_override("separation", 18)
		chapter_row.add_child(chapter)

		var chapter_label = Label.new()
		var chapter_number = STORY_ORDER.find(biome) + 1
		chapter_label.text = "Chapter %d" % chapter_number
		chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chapter_label.add_theme_font_size_override("font_size", 24)
		chapter.add_child(chapter_label)

		var biome_label = Label.new()
		biome_label.text = biome.replace("_", " ").capitalize()
		biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		biome_label.add_theme_font_size_override("font_size", 18)
		chapter.add_child(biome_label)

		if show_story:
			chapter.add_child(_build_entry_button(biome, "story"))
		chapter.add_child(_build_entry_button(biome, "summary"))
		var spacer = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		chapter.add_child(spacer)
		var status = Label.new()
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.text = "Cleared" if GameManager.is_biome_cleared(biome) else "Uncleared"
		chapter.add_child(status)

	if chapter_entries.is_empty():
		return

	var start_biome = GameManager.selected_story_biome if GameManager.selected_story_biome != "" else unlocked[0]
	var preferred_kind = "summary"
	selected_index = 0
	for i in range(chapter_entries.size()):
		var entry = chapter_entries[i]
		if str(entry["biome"]) == start_biome and str(entry["kind"]) == preferred_kind:
			selected_index = i
			break
	_refresh_entry_styles()
	_scroll_selected_into_view.call_deferred()

func _build_entry_button(biome: String, kind: String) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(240, 320)
	button.text = _get_entry_label(biome, kind)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 28 if kind == "story" else 24)
	button.add_theme_stylebox_override("normal", _default_style)
	button.add_theme_stylebox_override("hover", _default_style)
	button.add_theme_stylebox_override("pressed", _default_style)
	button.pressed.connect(_on_entry_pressed.bind(biome, kind))
	button.gui_input.connect(_on_entry_gui_input.bind(biome, kind))
	chapter_entries.append({"button": button, "biome": biome, "kind": kind})
	return button

func _create_styles():
	_default_style = StyleBoxFlat.new()
	_default_style.bg_color = Color(0.16, 0.16, 0.18, 0.96)
	_default_style.border_width_left = 2
	_default_style.border_width_top = 2
	_default_style.border_width_right = 2
	_default_style.border_width_bottom = 2
	_default_style.border_color = Color(0.38, 0.38, 0.42, 1.0)
	_default_style.corner_radius_top_left = 12
	_default_style.corner_radius_top_right = 12
	_default_style.corner_radius_bottom_left = 12
	_default_style.corner_radius_bottom_right = 12

	_selected_style = _default_style.duplicate()
	_selected_style.bg_color = Color(0.72, 0.88, 0.74, 0.95)
	_selected_style.border_color = Color(0.88, 0.96, 0.88, 1.0)

func _move_selection(dx: int, dy: int):
	if chapter_entries.is_empty():
		return
	var current = chapter_entries[selected_index]
	var target_biome = str(current["biome"])
	var target_kind = str(current["kind"])
	if dx != 0:
		var unlocked = GameManager.get_unlocked_story_biomes()
		var unlocked_index = unlocked.find(target_biome)
		if unlocked_index == -1:
			return
		var next_index = clamp(unlocked_index + dx, 0, unlocked.size() - 1)
		target_biome = unlocked[next_index]
	if dy != 0:
		target_kind = "summary" if target_kind == "story" else "story"
		if GameManager.is_battle_mode:
			target_kind = "summary"
	for i in range(chapter_entries.size()):
		var entry = chapter_entries[i]
		if str(entry["biome"]) == target_biome and str(entry["kind"]) == target_kind:
			selected_index = i
			_refresh_entry_styles()
			_scroll_selected_into_view()
			return

func _refresh_entry_styles():
	for i in range(chapter_entries.size()):
		var entry = chapter_entries[i]
		var button: Button = entry["button"]
		var style = _selected_style if i == selected_index else _default_style
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)

func _activate_selected_entry():
	if chapter_entries.is_empty():
		return
	var entry = chapter_entries[selected_index]
	_handle_entry_action(str(entry["biome"]), str(entry["kind"]))

func _on_entry_pressed(biome: String, kind: String):
	for i in range(chapter_entries.size()):
		var entry = chapter_entries[i]
		if str(entry["biome"]) == biome and str(entry["kind"]) == kind:
			selected_index = i
			break
	_refresh_entry_styles()
	_handle_entry_action(biome, kind)

func _on_entry_gui_input(event: InputEvent, biome: String, kind: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		GameManager.set_selected_story_biome(biome)
		_open_selected_biome_map()

func _handle_entry_action(biome: String, kind: String):
	GameManager.set_selected_story_biome(biome)
	if kind == "story" and not GameManager.is_battle_mode:
		get_tree().change_scene_to_file("res://features/map/StoryChapter.tscn")
		return
	get_tree().change_scene_to_file("res://features/map/MapSummary.tscn")

func _open_selected_biome_map():
	var biome = GameManager.selected_story_biome
	if biome == "":
		var unlocked = GameManager.get_unlocked_story_biomes()
		if unlocked.is_empty():
			return
		biome = unlocked[0]
	GameManager.set_selected_story_biome(biome)
	GameManager.enter_story_biome(biome, true)
	get_tree().change_scene_to_file(GameManager.get_active_biome_map_scene_path())

func _scroll_selected_into_view():
	if chapter_entries.is_empty():
		return
	var button: Button = chapter_entries[selected_index]["button"]
	var target = max(0.0, button.position.x - 80.0)
	scroll_container.scroll_horizontal = int(target)

func _get_entry_label(biome: String, kind: String) -> String:
	var biome_name = biome.replace("_", " ").capitalize()
	if kind == "story":
		return "%s\nStory" % biome_name
	return "%s\nMap Summary" % biome_name

func _open_character_screen():
	GameManager.profile_return_scene = GameManager.get_story_map_scene_path()
	get_tree().change_scene_to_file("res://features/ui/CharacterScreen.tscn")
