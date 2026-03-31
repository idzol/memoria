extends Control

signal summary_pressed(biome: String)

const GRANITE_TEXTURE_PATH = "res://assets/maps/story/tablet_background.png"
const TABLET_ASPECT_RATIO = 640.0 / 905.0
const TITLE_FONT_SIZE = 30
const BODY_FONT_SIZE = 24
const REMEMBERED_ICON_SIZE = 52.0
const REMEMBERED_ROW_MIN_HEIGHT = 64.0
const REMEMBERED_EMPTY_TEXT = "No remembered rooms yet."

@export var embedded_mode: bool = false
@export var show_background: bool = true
@export var allow_navigation: bool = true

@onready var background_rect = $BG
@onready var center = $Center
@onready var tablet = $Center/Tablet
@onready var granite_rect = %GraniteRect
@onready var title_label = %TitleLabel
@onready var subtitle_label = %SubtitleLabel
@onready var status_label = %StatusLabel
@onready var remembered_scroll = %RememberedScroll
@onready var remembered_list = %RememberedList
@onready var empty_label = %EmptyLabel
@onready var open_button = %OpenButton

var display_biome: String = ""
var embedded_target_size: Vector2 = Vector2.ZERO
var asset_library: MapAssetData = preload("res://data/map/map_data.tres")

func _ready():
	open_button.pressed.connect(_open_biome_map)
	if not resized.is_connected(_refresh_embedded_layout):
		resized.connect(_refresh_embedded_layout)
	if ResourceLoader.exists(GRANITE_TEXTURE_PATH):
		granite_rect.texture = load(GRANITE_TEXTURE_PATH)
		granite_rect.modulate = Color(0.8, 0.8, 0.84, 0.82)
	_apply_mode()
	_refresh_content.call_deferred()
	_refresh_embedded_layout.call_deferred()

func set_biome(biome: String):
	display_biome = biome
	if is_inside_tree():
		_refresh_content.call_deferred()

func set_embedded_target_size(target_size: Vector2):
	embedded_target_size = target_size
	if is_inside_tree():
		_refresh_embedded_layout()

func _input(event):
	if embedded_mode:
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(GameManager.get_story_line_scene_path())
	elif event.is_action_pressed("ui_accept"):
		_open_biome_map()

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if embedded_mode:
			summary_pressed.emit(_get_biome())
		elif event.double_click:
			_open_biome_map()

func _apply_mode():
	background_rect.visible = show_background and not embedded_mode
	open_button.visible = allow_navigation and not embedded_mode
	if embedded_mode:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2.ZERO
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
		subtitle_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
		if status_label:
			status_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
		remembered_scroll.custom_minimum_size = Vector2.ZERO
		open_button.text = ""
		_set_control_tree_mouse_filter(self, Control.MOUSE_FILTER_IGNORE)
		_refresh_embedded_layout.call_deferred()
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2.ZERO
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		tablet.custom_minimum_size = Vector2(640, 905)
		remembered_scroll.custom_minimum_size = Vector2(0, 680)
		title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
		subtitle_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
		if status_label:
			status_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
		open_button.text = LocalizationManager.translate("mapsummary.open", "Open Biome Map")

func _refresh_content():
	var biome = _get_biome()
	title_label.text = _get_title_for_biome(biome)
	subtitle_label.text = _get_subtitle_for_biome(biome)
	if status_label:
		status_label.text = _get_status_for_biome(biome)
	_rebuild_remembered_list()

func _get_embedded_height() -> float:
	return max(320.0, get_viewport_rect().size.y * 0.9)

func _refresh_embedded_layout():
	if not embedded_mode or not tablet or not remembered_scroll:
		return
	var available_size = embedded_target_size
	if available_size == Vector2.ZERO:
		available_size = size
	if available_size == Vector2.ZERO and get_parent() is Control:
		available_size = (get_parent() as Control).size
	if available_size == Vector2.ZERO:
		var fallback_height = _get_embedded_height()
		available_size = Vector2(fallback_height * TABLET_ASPECT_RATIO, fallback_height)
	var target_height = max(320.0, available_size.y)
	var target_width = target_height * TABLET_ASPECT_RATIO
	if available_size.x > 0.0 and target_width > available_size.x:
		target_width = available_size.x
		target_height = target_width / TABLET_ASPECT_RATIO
	tablet.custom_minimum_size = Vector2(target_width, target_height)
	# Let the scroll area consume only the remaining space inside the shared tablet height,
	# so summary tiles do not exceed the story chapter tile height in the story line.
	remembered_scroll.custom_minimum_size = Vector2(0, 0)
	_refresh_content.call_deferred()

func _get_biome() -> String:
	return display_biome if display_biome != "" else GameManager.selected_story_biome

func _get_title_for_biome(biome: String) -> String:
	if biome == "home":
		return LocalizationManager.translate("mapsummary.title.home", "Home Map Summary")
	return LocalizationManager.format("mapsummary.title.default", {"biome": biome.replace("_", " ").capitalize()}, "{biome} Map Summary")

func _get_subtitle_for_biome(biome: String) -> String:
	if GameManager.is_battle_mode:
		return LocalizationManager.translate("mapsummary.subtitle.battle", "Remembered rooms from this biome are listed here.")
	return LocalizationManager.translate(
		"mapsummary.subtitle.%s" % biome,
		LocalizationManager.translate("mapsummary.subtitle.story", "Home and completed rooms remain remembered here. Select to enter the biome map.")
	)

func _get_status_for_biome(biome: String) -> String:
	var total_rooms = 0
	var remembered_rooms = 0
	for node in GameManager.get_nodes_for_biome(biome):
		if str(node.get("type", "")) == "background" or not bool(node.get("passable", true)):
			continue
		total_rooms += 1
		if _is_node_remembered(node, biome):
			remembered_rooms += 1
	return "Remembered: %d / %d" % [remembered_rooms, total_rooms]

func _rebuild_remembered_list():
	if not remembered_list:
		return
	for child in remembered_list.get_children():
		if child == empty_label:
			continue
		child.queue_free()

	var remembered_nodes = _get_remembered_nodes(_get_biome())
	if empty_label:
		empty_label.text = LocalizationManager.translate("mapsummary.empty", REMEMBERED_EMPTY_TEXT)
		empty_label.visible = remembered_nodes.is_empty()

	for node in remembered_nodes:
		remembered_list.add_child(_build_room_row(node))

func _get_remembered_nodes(biome: String) -> Array[Dictionary]:
	var remembered: Array[Dictionary] = []
	for node in GameManager.get_nodes_for_biome(biome):
		if str(node.get("type", "")) == "background" or not bool(node.get("passable", true)):
			continue
		if _is_node_remembered(node, biome):
			remembered.append(node)
	remembered.sort_custom(func(a, b) -> bool:
		var a_home = bool(a.get("is_home", false))
		var b_home = bool(b.get("is_home", false))
		if a_home != b_home:
			return a_home
		var a_layer = int(a.get("layer", 0))
		var b_layer = int(b.get("layer", 0))
		if a_layer != b_layer:
			return a_layer < b_layer
		return int(a.get("column", 0)) < int(b.get("column", 0))
	)
	return remembered

func _is_node_remembered(node: Dictionary, biome: String) -> bool:
	var node_id = str(node.get("id", ""))
	if node_id == "":
		return false
	if bool(node.get("is_home", false)) or node_id == GameManager.get_biome_home_node_id(biome):
		return true
	var state = GameManager.world_state.rooms.get(node_id, {})
	if GameManager.is_battle_mode:
		return state.get("visited", false) or state.get("cleared", false)
	return state.get("completed", false)

func _build_room_row(node: Dictionary) -> Control:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, REMEMBERED_ROW_MIN_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 16)

	var icon_holder = CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(REMEMBERED_ICON_SIZE, REMEMBERED_ICON_SIZE)
	row.add_child(icon_holder)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(REMEMBERED_ICON_SIZE, REMEMBERED_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _get_room_icon_texture(node)
	icon_holder.add_child(icon)

	var name_label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text = _get_room_display_name(node)
	name_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	row.add_child(name_label)

	return row

func _get_room_display_name(node: Dictionary) -> String:
	var room_path = str(node.get("room_resource_path", ""))
	if room_path != "" and ResourceLoader.exists(room_path):
		var room_res = load(room_path) as RoomData
		if room_res and room_res.room_name != "":
			return room_res.room_name
	var explicit_name = str(node.get("name", ""))
	if explicit_name != "":
		return explicit_name
	return str(node.get("type", "room")).replace("_", " ").capitalize()

func _get_room_icon_texture(node: Dictionary) -> Texture2D:
	var custom_icon_path = str(node.get("custom_icon_path", ""))
	if custom_icon_path != "" and ResourceLoader.exists(custom_icon_path):
		var custom_icon = load(custom_icon_path) as Texture2D
		if custom_icon:
			return custom_icon
	var room_path = str(node.get("room_resource_path", ""))
	if room_path != "" and ResourceLoader.exists(room_path):
		var room_res = load(room_path) as RoomData
		if room_res and room_res.map_icon:
			return room_res.map_icon
	var icon_type = "home" if bool(node.get("is_home", false)) or str(node.get("type", "")) == "home" else str(node.get("type", "mystery"))
	return _get_type_icon_texture(icon_type)

func _get_type_icon_texture(type: String) -> Texture2D:
	if not asset_library:
		return null
	var property_name = "map_icon_" + type.to_lower()
	if property_name in asset_library:
		return asset_library.get(property_name) as Texture2D
	return asset_library.map_icon_mystery

func _open_biome_map():
	var biome = _get_biome()
	if embedded_mode or not allow_navigation:
		summary_pressed.emit(biome)
		return
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
	get_tree().change_scene_to_file(GameManager.get_active_biome_map_scene_path())

func _set_control_tree_mouse_filter(node: Node, filter_mode: Control.MouseFilter):
	if node is Control:
		(node as Control).mouse_filter = filter_mode
	for child in node.get_children():
		_set_control_tree_mouse_filter(child, filter_mode)
