extends Control

signal chapter_pressed(biome: String)

const GRANITE_TEXTURE_PATH = "res://assets/maps/story/tablet_background.png"
const TABLET_ASPECT_RATIO = 640.0 / 905.0

@export var embedded_mode: bool = false
@export var show_background: bool = true
@export var allow_navigation: bool = true
@export var title_override: String = ""

@onready var background_rect = $BG
@onready var center = $Center
@onready var tablet = $Center/Tablet
@onready var granite_rect = %GraniteRect
@onready var title_label = %TitleLabel
@onready var body_label = %BodyLabel
@onready var continue_button = %ContinueButton

var display_biome: String = ""
var embedded_target_size: Vector2 = Vector2.ZERO

func _ready():
	continue_button.pressed.connect(_back_to_story_map)
	if not resized.is_connected(_refresh_embedded_layout):
		resized.connect(_refresh_embedded_layout)
	if ResourceLoader.exists(GRANITE_TEXTURE_PATH):
		granite_rect.texture = load(GRANITE_TEXTURE_PATH)
		granite_rect.modulate = Color(0.78, 0.78, 0.82, 0.9)
	_apply_mode()
	_refresh_content.call_deferred()
	_refresh_embedded_layout.call_deferred()

func set_biome(biome: String):
	display_biome = biome
	if is_inside_tree():
		_refresh_content()

func set_embedded_target_size(target_size: Vector2):
	embedded_target_size = target_size
	if is_inside_tree():
		_refresh_embedded_layout()

func _input(event):
	if embedded_mode:
		return
	if event.is_action_pressed("ui_cancel"):
		_back_to_story_map()

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not embedded_mode and not allow_navigation:
			chapter_pressed.emit(_get_biome())
			return
	if not embedded_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		chapter_pressed.emit(_get_biome())

func _apply_mode():
	background_rect.visible = show_background and not embedded_mode
	continue_button.visible = allow_navigation and not embedded_mode
	if embedded_mode:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2.ZERO
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body_label.scroll_active = false
		body_label.fit_content = false
		title_label.add_theme_font_size_override("font_size", 30)
		body_label.add_theme_font_size_override("normal_font_size", 22)
		continue_button.text = ""
		_set_control_tree_mouse_filter(self, Control.MOUSE_FILTER_IGNORE)
		_refresh_embedded_layout.call_deferred()
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2.ZERO
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		tablet.custom_minimum_size = Vector2(640, 905)
		body_label.custom_minimum_size = Vector2(0, 680)
		body_label.scroll_active = true
		title_label.add_theme_font_size_override("font_size", 38)
		body_label.add_theme_font_size_override("normal_font_size", 28)
		continue_button.text = LocalizationManager.translate("common.back", "Back")

func _refresh_content():
	var biome = _get_biome()
	title_label.text = _get_title_for_biome(biome)
	body_label.text = LocalizationManager.translate(
		"story.body.%s" % biome,
		LocalizationManager.translate("story.body.fallback", "The stone remembers more than the traveler does.")
	)

func _get_biome() -> String:
	return display_biome if display_biome != "" else GameManager.selected_story_biome

func _get_title_for_biome(biome: String) -> String:
	if title_override != "":
		return title_override
	if biome == "home":
		return LocalizationManager.translate("story.title.home", "Introduction")
	var template = LocalizationManager.translate("story.title.default", "{biome} Chronicle")
	return template.replace("{biome}", biome.replace("_", " ").capitalize())

func _get_embedded_height() -> float:
	return max(320.0, get_viewport_rect().size.y * 0.9)

func _refresh_embedded_layout():
	if not embedded_mode or not tablet or not body_label:
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
	body_label.custom_minimum_size = Vector2(0, target_height * 0.72)

func _back_to_story_map():
	if embedded_mode or not allow_navigation:
		chapter_pressed.emit(_get_biome())
		return
	get_tree().change_scene_to_file(GameManager.get_story_map_scene_path())

func _set_control_tree_mouse_filter(node: Node, filter_mode: Control.MouseFilter):
	if node is Control:
		(node as Control).mouse_filter = filter_mode
	for child in node.get_children():
		_set_control_tree_mouse_filter(child, filter_mode)
