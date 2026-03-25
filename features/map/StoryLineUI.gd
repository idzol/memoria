extends Control

const STORY_CHAPTER_SCENE = preload("res://features/map/StoryChapter.tscn")
const STORY_MAP_SCENE = preload("res://features/map/StoryMap.tscn")
const STORY_ORDER = ["home", "town", "forest", "ice_caves", "desert", "swamp", "abyss", "void", "the_core"]
const SCROLL_CONTENT_PADDING := 24.0
const ENTRY_GAP := 18.0
const CHAPTER_GAP := 28.0
const ENTRY_TILE_PADDING := 14.0
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "gameplay"
const TUTORIAL_TIPS_KEY := "tutorial_tips"
const TUTORIAL_FLAGS_SECTION := "tutorial_flags"
const STORYMAP_FINAL_TUTORIAL_ID := "storymap_intro_complete"
const TUTORIAL_TOAST_DURATION := 10.0
const TUTORIAL_TOAST_COLOR := Color(0.4, 0.7, 1.0, 1.0)
const STORY_TILE_VIEWPORT_HEIGHT_RATIO := 0.78
const STORYLINE_TITLE := "Story Chapters"
const CULT_DAY_NAMES := [
	"Protodia",
	"Hoplidia",
	"Tridia",
	"Tetradia",
	"Pemptidia",
	"Hektidia",
	"Hebdomia",
	"Ogdoadia"
]

@onready var chapter_row = %ChapterRow
@onready var scroll_container = %ScrollContainer
@onready var avatar_button = %AvatarButton
@onready var map_button = %MapButton
@onready var phase_label = get_node_or_null("%PhaseLabel")
@onready var day_button = get_node_or_null("%DayButton")
@onready var tracker_text = get_node_or_null("%TrackerText")
@onready var menu_icon_btn = get_node_or_null("%MenuIconBtn")
@onready var background_rect = $BG
@onready var info_toast_box = %InfoToastBox
@onready var info_toast_label = %InfoToastLabel
@onready var focus_overlay = %FocusOverlay
@onready var focus_content = %FocusContent

var in_game_menu_scene = preload("res://features/ui/InGameMenu.tscn")
var in_game_menu = null
var chapter_entries: Array[Dictionary] = []
var selected_index: int = 0
var _selected_style: StyleBoxFlat
var _default_style: StyleBoxFlat
var _info_toast_tween: Tween
var _tutorial_step: int = -1
var _tutorial_completed: bool = false
var _tutorial_mode: String = ""
var _tutorial_overlay: Control = null
var _tutorial_message_label: Label = null
var _tutorial_hint_label: Label = null
var _tutorial_continue_callback: Callable
var _last_story_layout_height: int = -1
var _last_focus_layout_height: int = -1

func _ready():
	_ensure_tutorial_overlay()
	_create_styles()
	SignalBus.music_change_requested.emit(AudioData.TRACKS["STORY_MENU"], 1.5)
	if in_game_menu_scene:
		in_game_menu = in_game_menu_scene.instantiate()
		add_child(in_game_menu)
		in_game_menu.hide()
	if avatar_button:
		avatar_button.pressed.connect(_open_character_screen)
	if map_button:
		map_button.pressed.connect(_open_selected_biome_map)
	if menu_icon_btn:
		menu_icon_btn.pressed.connect(_toggle_in_game_menu)
	if focus_overlay:
		focus_overlay.gui_input.connect(_on_focus_overlay_input)
	if scroll_container:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_configure_top_bar()
	_refresh_day_ui()
	_hide_info_toast()
	_rebuild_chapters()
	_begin_tutorial_if_needed.call_deferred()

func _notification(what):
	if what == NOTIFICATION_RESIZED and is_inside_tree() and scroll_container and chapter_row:
		var scene_height = int(roundi(_get_scene_height()))
		if scene_height != _last_story_layout_height:
			_rebuild_chapters()
		if focus_overlay and focus_overlay.visible and scene_height != _last_focus_layout_height:
			_apply_focus_content_size()

func _input(event):
	if _tutorial_overlay and _tutorial_overlay.visible:
		if _is_tutorial_dismiss_input(event):
			_dismiss_tutorial_modal()
			_mark_input_handled()
		return
	if focus_overlay and focus_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_focus_overlay()
			_mark_input_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_close_focus_overlay()
			_mark_input_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _handle_menu_cancel():
			_mark_input_handled()
			return
		_return_to_current_biome_map()
		_mark_input_handled()
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_W:
		_open_selected_biome_map()
		_mark_input_handled()
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
	var card_height = _get_story_tile_height()
	var card_width = card_height * (640.0 / 905.0)
	var padded_card_width = card_width + (ENTRY_TILE_PADDING * 2.0)
	var padded_card_height = card_height + (ENTRY_TILE_PADDING * 2.0)
	var chapter_width = padded_card_width * (2.0 if show_story else 1.0) + (ENTRY_GAP if show_story else 0.0)
	var chapter_height = padded_card_height + 24.0
	if phase_label:
		phase_label.text = LocalizationManager.translate("storymap.header.story", STORYLINE_TITLE) if show_story else LocalizationManager.translate("storymap.header.biome", "Biome Chapters")
	chapter_row.custom_minimum_size = Vector2(
		(chapter_width * unlocked.size()) + (CHAPTER_GAP * max(0, unlocked.size() - 1)),
		chapter_height
	)

	for biome in STORY_ORDER:
		if not unlocked.has(biome):
			continue

		var chapter = VBoxContainer.new()
		chapter.custom_minimum_size = Vector2(chapter_width, chapter_height)
		chapter.alignment = BoxContainer.ALIGNMENT_BEGIN
		chapter.add_theme_constant_override("separation", 8)
		chapter_row.add_child(chapter)

		var content_row = HBoxContainer.new()
		content_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		content_row.add_theme_constant_override("separation", int(roundi(ENTRY_GAP)))
		chapter.add_child(content_row)

		if show_story:
			content_row.add_child(_build_story_tile(biome))
		content_row.add_child(_build_summary_tile(biome))

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
	_last_story_layout_height = int(roundi(_get_scene_height()))

func _build_story_tile(biome: String) -> Control:
	var wrapper = _build_entry_wrapper(biome, "story")
	var content: MarginContainer = wrapper.get_meta("content")
	var target_size: Vector2 = wrapper.get_meta("embedded_target_size")
	var chapter_card = STORY_CHAPTER_SCENE.instantiate()
	chapter_card.embedded_mode = true
	chapter_card.show_background = false
	chapter_card.allow_navigation = false
	chapter_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter_card.title_override = _get_story_tile_title(biome)
	if chapter_card.has_method("set_embedded_target_size"):
		chapter_card.set_embedded_target_size(target_size)
	chapter_card.set_biome(biome)
	chapter_card.chapter_pressed.connect(_on_story_tile_pressed)
	content.add_child(chapter_card)
	return wrapper

func _build_summary_tile(biome: String) -> Control:
	var wrapper = _build_entry_wrapper(biome, "summary")
	var content: MarginContainer = wrapper.get_meta("content")
	var target_size: Vector2 = wrapper.get_meta("embedded_target_size")
	var summary_card = STORY_MAP_SCENE.instantiate()
	summary_card.embedded_mode = true
	summary_card.show_background = false
	summary_card.allow_navigation = false
	summary_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if summary_card.has_method("set_embedded_target_size"):
		summary_card.set_embedded_target_size(target_size)
	summary_card.set_biome(biome)
	summary_card.summary_pressed.connect(_on_summary_tile_pressed)
	content.add_child(summary_card)
	return wrapper

func _build_entry_wrapper(biome: String, kind: String) -> Button:
	var wrapper = Button.new()
	wrapper.name = "%s_%s_button" % [biome, kind]
	var card_height = _get_story_tile_height()
	var card_width = card_height * (640.0 / 905.0)
	var embedded_target_size = Vector2(card_width, card_height)
	wrapper.custom_minimum_size = Vector2(
		embedded_target_size.x + (ENTRY_TILE_PADDING * 2.0),
		embedded_target_size.y + (ENTRY_TILE_PADDING * 2.0)
	)
	wrapper.flat = true
	wrapper.text = ""
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.focus_mode = Control.FOCUS_NONE
	wrapper.add_theme_stylebox_override("normal", _default_style)
	wrapper.add_theme_stylebox_override("hover", _default_style)
	wrapper.add_theme_stylebox_override("pressed", _default_style)
	wrapper.add_theme_stylebox_override("focus", _default_style)
	wrapper.pressed.connect(_on_entry_wrapper_pressed.bind(biome, kind))
	var content = MarginContainer.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = ENTRY_TILE_PADDING
	content.offset_top = ENTRY_TILE_PADDING
	content.offset_right = -ENTRY_TILE_PADDING
	content.offset_bottom = -ENTRY_TILE_PADDING
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(content)
	wrapper.set_meta("content", content)
	wrapper.set_meta("embedded_target_size", embedded_target_size)
	chapter_entries.append({"button": wrapper, "biome": biome, "kind": kind})
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
		var button: Button = entry["button"]
		var style = _selected_style if i == selected_index else _default_style
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("focus", style)

func _activate_selected_entry():
	if chapter_entries.is_empty():
		return
	var entry = chapter_entries[selected_index]
	_handle_entry_action(str(entry["biome"]), str(entry["kind"]))

func _handle_entry_action(biome: String, kind: String):
	GameManager.set_selected_story_biome(biome)
	if kind == "story":
		GameManager.begin_story_sequence(biome, GameManager.get_story_line_scene_path(), false, false)
		return
	_open_selected_biome_map()

func _on_story_tile_pressed(biome: String):
	_select_entry(biome, "story")
	GameManager.begin_story_sequence(biome, GameManager.get_story_line_scene_path(), false, false)

func _on_summary_tile_pressed(biome: String):
	_select_entry(biome, "summary")
	_open_selected_biome_map()

func _select_entry(biome: String, kind: String):
	for i in range(chapter_entries.size()):
		var entry = chapter_entries[i]
		if str(entry["biome"]) == biome and str(entry["kind"]) == kind:
			selected_index = i
			break
	_refresh_entry_styles()
	_scroll_selected_into_view()

func _on_entry_wrapper_pressed(biome: String, kind: String):
	_select_entry(biome, kind)
	GameManager.set_selected_story_biome(biome)
	if kind == "story":
		GameManager.begin_story_sequence(biome, GameManager.get_story_line_scene_path(), false, false)
		return
	_open_selected_biome_map()

func _open_story_focus(biome: String):
	if not focus_overlay or not focus_content:
		return
	for child in focus_content.get_children():
		child.queue_free()
	_apply_focus_content_size()
	GameManager.set_selected_story_biome(biome)
	var chapter_scene = STORY_CHAPTER_SCENE.instantiate()
	chapter_scene.embedded_mode = false
	chapter_scene.show_background = false
	chapter_scene.allow_navigation = false
	chapter_scene.set_biome(biome)
	chapter_scene.chapter_pressed.connect(_close_focus_overlay)
	focus_content.add_child(chapter_scene)
	focus_overlay.visible = true

func _apply_focus_content_size():
	if not focus_content:
		return
	var target_height = _get_focus_content_height()
	var target_width = focus_content.custom_minimum_size.x
	focus_content.custom_minimum_size = Vector2(target_width, target_height)
	focus_content.offset_left = -target_width * 0.5
	focus_content.offset_right = target_width * 0.5
	focus_content.offset_top = 0.0
	focus_content.offset_bottom = target_height
	_last_focus_layout_height = int(roundi(target_height))

func _close_focus_overlay(_biome: String = ""):
	if not focus_overlay:
		return
	focus_overlay.visible = false
	for child in focus_content.get_children():
		child.queue_free()

func _on_focus_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
		if GameManager.open_story_biome_intro_if_needed(biome):
			return
		GameManager.enter_story_biome(biome, true)
	SceneTransition.change_scene_to_file(GameManager.get_active_biome_map_scene_path())

func _scroll_selected_into_view():
	if chapter_entries.is_empty():
		return
	var button: Button = chapter_entries[selected_index]["button"]
	var target = max(0.0, button.position.x - 80.0)
	scroll_container.scroll_horizontal = int(target)

func _get_story_tile_title(biome: String) -> String:
	if biome == "home":
		return LocalizationManager.translate("story.title.home", "Introduction")
	return LocalizationManager.format("storymap.chapter_number", {"number": STORY_ORDER.find(biome) + 1}, "Chapter {number}")

func _open_character_screen():
	GameManager.profile_return_scene = GameManager.get_story_line_scene_path()
	get_tree().change_scene_to_file("res://features/ui/CharacterScreen.tscn")

func _toggle_in_game_menu():
	if not in_game_menu:
		return
	if in_game_menu.visible:
		in_game_menu.close()
	else:
		in_game_menu.open()

func _handle_menu_cancel() -> bool:
	if not in_game_menu or not in_game_menu.visible:
		return false
	if in_game_menu.has_method("handle_cancel"):
		return in_game_menu.handle_cancel()
	in_game_menu.close()
	return true

func _configure_top_bar():
	if tracker_text:
		tracker_text.visible = false
	if phase_label:
		phase_label.text = LocalizationManager.translate("storymap.header.story", STORYLINE_TITLE)

func _refresh_day_ui():
	if not day_button:
		return
	var day_number = _get_current_day_number()
	var day_index = _get_day_cycle_index(day_number)
	var day_name = _get_day_name(day_index)
	day_button.text = LocalizationManager.format(
		"worldmap.day.button",
		{"day": day_number, "name": day_name},
		"Day {day}. {name}"
	)

func _get_current_day_number() -> int:
	return max(1, int(GameManager.world_state.global.get("current_day", 1)))

func _get_day_cycle_index(day_number: int) -> int:
	return posmod(day_number - 1, CULT_DAY_NAMES.size()) + 1

func _get_day_name(day_index: int) -> String:
	return LocalizationManager.translate(
		"worldmap.day.%d.name" % day_index,
		CULT_DAY_NAMES[clamp(day_index - 1, 0, CULT_DAY_NAMES.size() - 1)]
	)

func _return_to_current_biome_map():
	var biome = GameManager.player_biome if GameManager.player_biome != "" else GameManager.selected_story_biome
	if biome == "":
		var unlocked = GameManager.get_unlocked_story_biomes()
		if unlocked.is_empty():
			return
		biome = unlocked[0]
	GameManager.set_selected_story_biome(biome)
	if not GameManager.is_battle_mode:
		GameManager.enter_story_biome(biome, true)
	SceneTransition.change_scene_to_file(GameManager.get_active_biome_map_scene_path())

func _mark_input_handled():
	var viewport = get_viewport()
	if viewport:
		viewport.set_input_as_handled()

func _hide_info_toast():
	if info_toast_box:
		info_toast_box.visible = false
		info_toast_box.modulate = Color(1, 1, 1, 0)
	if info_toast_label:
		info_toast_label.text = ""

func _ensure_tutorial_overlay():
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		return
	_tutorial_overlay = Control.new()
	_tutorial_overlay.name = "TutorialOverlay"
	_tutorial_overlay.visible = false
	_tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_tutorial_overlay)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.03, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_overlay.add_child(shade)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.1, 0.97)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.7, 1.0, 0.8)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_tutorial_message_label = Label.new()
	_tutorial_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_message_label.add_theme_font_size_override("font_size", 30)
	_tutorial_message_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	vbox.add_child(_tutorial_message_label)

	_tutorial_hint_label = Label.new()
	_tutorial_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_hint_label.add_theme_font_size_override("font_size", 18)
	_tutorial_hint_label.add_theme_color_override("font_color", TUTORIAL_TOAST_COLOR)
	_tutorial_hint_label.text = LocalizationManager.translate("tutorial.continue_any_input", "Click or press any key to continue")
	vbox.add_child(_tutorial_hint_label)

func _show_tutorial_modal(message: String, on_finished: Callable = Callable()):
	if _tutorial_message_label:
		_tutorial_message_label.text = message
	if _tutorial_hint_label:
		_tutorial_hint_label.text = LocalizationManager.translate("tutorial.continue_any_input", "Click or press any key to continue")
	_tutorial_continue_callback = on_finished
	if _tutorial_overlay:
		_tutorial_overlay.visible = true
		_tutorial_overlay.move_to_front()

func _dismiss_tutorial_modal():
	if _tutorial_overlay:
		_tutorial_overlay.visible = false
	var callback = _tutorial_continue_callback
	_tutorial_continue_callback = Callable()
	if callback.is_valid():
		callback.call()

func _is_tutorial_dismiss_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and not event.is_echo()
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return abs(event.axis_value) >= 0.2
	return false

func _get_available_scroll_height() -> float:
	if scroll_container and scroll_container.size.y > 0.0:
		return scroll_container.size.y
	return max(360.0, _get_scene_height() - 110.0)

func _get_story_tile_height() -> float:
	return max(320.0, _get_scene_height() * STORY_TILE_VIEWPORT_HEIGHT_RATIO)

func _get_scene_height() -> float:
	if background_rect and background_rect.size.y > 0.0:
		return background_rect.size.y
	if size.y > 0.0:
		return size.y
	return get_viewport_rect().size.y

func _get_focus_content_height() -> float:
	if scroll_container and scroll_container.size.y > 0.0:
		return scroll_container.size.y
	return _get_scene_height()


func _begin_tutorial_if_needed():
	if _tutorial_completed or GameManager.is_battle_mode or not _are_tutorial_tips_enabled():
		return
	if _should_show_final_tutorial():
		_tutorial_mode = "final"
		_tutorial_step = 0
		_focus_tutorial_target("town", "story")
		_show_tutorial_modal(
			LocalizationManager.translate(
				"storymap.tutorial.complete",
				"Continue to explore the world. Tutorial tips have now been turned off, you can turn them back on in settings. Good luck"
			),
			Callable(self, "_complete_tutorial")
		)
		return
	var first_biome = _get_first_unlocked_biome()
	if first_biome == "":
		return
	_tutorial_mode = "intro"
	_tutorial_step = 0
	_focus_tutorial_target(first_biome, "story")
	var show_summary_tutorial := func():
		if not is_inside_tree():
			return
		var unlocked_biome = _get_first_unlocked_biome()
		if unlocked_biome == "":
			_complete_tutorial()
			return
		_tutorial_step = 1
		_focus_tutorial_target(unlocked_biome, "summary")
		var start_message = LocalizationManager.translate(
			"storymap.tutorial.start",
			"To start your journey, click on the first memory"
		)
		_show_tutorial_modal(start_message, Callable(self, "_complete_tutorial"))
	_show_tutorial_modal(
		LocalizationManager.translate(
			"storymap.tutorial.progress",
			"The story map is where we track your progress"
		),
		show_summary_tutorial
	)

func _complete_tutorial():
	if _tutorial_mode == "final":
		_set_tutorial_seen(STORYMAP_FINAL_TUTORIAL_ID)
		_set_tutorial_tips_enabled(false)
	_tutorial_step = -1
	_tutorial_completed = true
	_tutorial_mode = ""

func _focus_tutorial_target(biome: String, kind: String):
	var entry_index = _find_entry_index(biome, kind)
	if entry_index == -1:
		return
	selected_index = entry_index
	_refresh_entry_styles()
	_scroll_selected_into_view()

func _find_entry_index(biome: String, kind: String) -> int:
	for i in range(chapter_entries.size()):
		var entry = chapter_entries[i]
		if str(entry["biome"]) == biome and str(entry["kind"]) == kind:
			return i
	return -1

func _get_selected_button() -> Button:
	if chapter_entries.is_empty() or selected_index < 0 or selected_index >= chapter_entries.size():
		return null
	return chapter_entries[selected_index]["button"] as Button

func _get_first_unlocked_biome() -> String:
	var unlocked = GameManager.get_unlocked_story_biomes()
	return unlocked[0] if not unlocked.is_empty() else ""

func _is_tutorial_active() -> bool:
	return _tutorial_step >= 0

func _are_tutorial_tips_enabled() -> bool:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return true
	return bool(config.get_value(SETTINGS_SECTION, TUTORIAL_TIPS_KEY, true))

func _set_tutorial_tips_enabled(enabled: bool):
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, TUTORIAL_TIPS_KEY, enabled)
	config.save(SETTINGS_PATH)

func _should_show_final_tutorial() -> bool:
	var unlocked = GameManager.get_unlocked_story_biomes()
	if unlocked.size() < 2:
		return false
	if not GameManager.is_biome_cleared("home"):
		return false
	return not _has_seen_tutorial(STORYMAP_FINAL_TUTORIAL_ID)

func _has_seen_tutorial(tutorial_id: String) -> bool:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return bool(config.get_value(TUTORIAL_FLAGS_SECTION, tutorial_id, false))

func _set_tutorial_seen(tutorial_id: String):
	if tutorial_id == "":
		return
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(TUTORIAL_FLAGS_SECTION, tutorial_id, true)
	config.save(SETTINGS_PATH)
