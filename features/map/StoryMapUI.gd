extends Control

const STORY_CHAPTER_SCENE = preload("res://features/map/StoryChapter.tscn")
const MAP_SUMMARY_SCENE = preload("res://features/map/MapSummary.tscn")
const STORY_ORDER = ["home", "town", "forest", "ice_caves", "desert", "swamp", "abyss", "void", "the_core"]

@onready var chapter_row = %ChapterRow
@onready var scroll_container = %ScrollContainer
@onready var avatar_button = %AvatarButton
@onready var map_button = %MapButton
@onready var header_label = %HeaderLabel
@onready var focus_overlay = %FocusOverlay
@onready var focus_content = %FocusContent

var chapter_entries: Array[Dictionary] = []
var selected_index: int = 0
var _selected_style: StyleBoxFlat
var _default_style: StyleBoxFlat

func _ready():
	_create_styles()
	if avatar_button:
		avatar_button.pressed.connect(_open_character_screen)
	if map_button:
		map_button.pressed.connect(_open_selected_biome_map)
	if focus_overlay:
		focus_overlay.gui_input.connect(_on_focus_overlay_input)
	_rebuild_chapters()

func _input(event):
	if focus_overlay and focus_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_focus_overlay()
			get_viewport().set_input_as_handled()
		return
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
		chapter.custom_minimum_size = Vector2(660 if show_story else 320, 720)
		chapter.add_theme_constant_override("separation", 18)
		chapter_row.add_child(chapter)

		var chapter_label = Label.new()
		chapter_label.text = "Chapter %d" % (STORY_ORDER.find(biome) + 1)
		chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chapter_label.add_theme_font_size_override("font_size", 24)
		chapter.add_child(chapter_label)

		var biome_label = Label.new()
		biome_label.text = _get_biome_heading(biome)
		biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		biome_label.add_theme_font_size_override("font_size", 18)
		chapter.add_child(biome_label)

		var content_row = HBoxContainer.new()
		content_row.alignment = BoxContainer.ALIGNMENT_CENTER
		content_row.add_theme_constant_override("separation", 18)
		chapter.add_child(content_row)

		if show_story:
			content_row.add_child(_build_story_tile(biome))
		content_row.add_child(_build_summary_tile(biome))

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

func _build_story_tile(biome: String) -> Control:
	var wrapper = _build_entry_wrapper(biome, "story")
	var chapter_card = STORY_CHAPTER_SCENE.instantiate()
	chapter_card.embedded_mode = true
	chapter_card.show_background = false
	chapter_card.allow_navigation = false
	chapter_card.set_biome(biome)
	chapter_card.chapter_pressed.connect(_on_story_tile_pressed)
	wrapper.add_child(chapter_card)
	return wrapper

func _build_summary_tile(biome: String) -> Control:
	var wrapper = _build_entry_wrapper(biome, "summary")
	var summary_card = MAP_SUMMARY_SCENE.instantiate()
	summary_card.embedded_mode = true
	summary_card.show_background = false
	summary_card.allow_navigation = false
	summary_card.set_biome(biome)
	summary_card.summary_pressed.connect(_on_summary_tile_pressed)
	wrapper.add_child(summary_card)
	return wrapper

func _build_entry_wrapper(biome: String, kind: String) -> PanelContainer:
	var wrapper = PanelContainer.new()
	wrapper.custom_minimum_size = Vector2(310, 360)
	wrapper.add_theme_stylebox_override("panel", _default_style)
	chapter_entries.append({"panel": wrapper, "biome": biome, "kind": kind})
	return wrapper

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
		var panel: PanelContainer = entry["panel"]
		panel.add_theme_stylebox_override("panel", _selected_style if i == selected_index else _default_style)

func _activate_selected_entry():
	if chapter_entries.is_empty():
		return
	var entry = chapter_entries[selected_index]
	_handle_entry_action(str(entry["biome"]), str(entry["kind"]))

func _handle_entry_action(biome: String, kind: String):
	GameManager.set_selected_story_biome(biome)
	if kind == "story" and not GameManager.is_battle_mode:
		_open_story_focus(biome)
		return
	_open_selected_biome_map()

func _on_story_tile_pressed(biome: String):
	_select_entry(biome, "story")
	_open_story_focus(biome)

func _on_summary_tile_pressed(biome: String):
	_select_entry(biome, "summary")
	GameManager.set_selected_story_biome(biome)
	_open_selected_biome_map()

func _select_entry(biome: String, kind: String):
	for i in range(chapter_entries.size()):
		var entry = chapter_entries[i]
		if str(entry["biome"]) == biome and str(entry["kind"]) == kind:
			selected_index = i
			break
	_refresh_entry_styles()

func _open_story_focus(biome: String):
	if not focus_overlay or not focus_content:
		return
	for child in focus_content.get_children():
		child.queue_free()
	GameManager.set_selected_story_biome(biome)
	var chapter_scene = STORY_CHAPTER_SCENE.instantiate()
	chapter_scene.embedded_mode = false
	chapter_scene.show_background = false
	chapter_scene.allow_navigation = false
	chapter_scene.set_biome(biome)
	chapter_scene.chapter_pressed.connect(_close_focus_overlay)
	focus_content.add_child(chapter_scene)
	focus_overlay.visible = true

func _close_focus_overlay(_biome: String = ""):
	if not focus_overlay:
		return
	focus_overlay.visible = false
	for child in focus_content.get_children():
		child.queue_free()

func _on_focus_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if focus_content and focus_content.get_global_rect().has_point(focus_content.get_global_mouse_position()):
			return
		_close_focus_overlay()

func _open_selected_biome_map():
	var biome = GameManager.selected_story_biome
	if biome == "":
		var unlocked = GameManager.get_unlocked_story_biomes()
		if unlocked.is_empty():
			return
		biome = unlocked[0]
	GameManager.set_selected_story_biome(biome)
	if GameManager.is_battle_mode:
		var biome_nodes = GameManager.get_nodes_for_biome(biome)
		if biome_nodes.is_empty():
			return
		var entry_node: Dictionary = {}
		for node in biome_nodes:
			if bool(node.get("is_home", false)):
				entry_node = node
				break
		if entry_node.is_empty():
			entry_node = biome_nodes[0]
		GameManager.player_biome = biome
		GameManager.player_grid_pos = Vector2i(int(entry_node.get("layer", 0)), int(entry_node.get("column", 0)))
	else:
		GameManager.enter_story_biome(biome, true)
	get_tree().change_scene_to_file(GameManager.get_active_biome_map_scene_path())

func _scroll_selected_into_view():
	if chapter_entries.is_empty():
		return
	var panel: PanelContainer = chapter_entries[selected_index]["panel"]
	var target = max(0.0, panel.position.x - 80.0)
	scroll_container.scroll_horizontal = int(target)

func _get_biome_heading(biome: String) -> String:
	if biome == "home":
		return "Introduction"
	return biome.replace("_", " ").capitalize()

func _open_character_screen():
	GameManager.profile_return_scene = GameManager.get_story_map_scene_path()
	get_tree().change_scene_to_file("res://features/ui/CharacterScreen.tscn")
