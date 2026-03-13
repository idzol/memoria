extends Control

signal chapter_pressed(biome: String)

const GRANITE_TEXTURE_PATH = "res://assets/maps/story/tablet_background.png"
const TABLET_ASPECT_RATIO = 640.0 / 905.0

@export var embedded_mode: bool = false
@export var show_background: bool = true
@export var allow_navigation: bool = true

@onready var background_rect = $BG
@onready var center = $Center
@onready var tablet = $Center/Tablet
@onready var granite_rect = %GraniteRect
@onready var title_label = %TitleLabel
@onready var body_label = %BodyLabel
@onready var continue_button = %ContinueButton

var display_biome: String = ""

func _ready():
	continue_button.pressed.connect(_back_to_story_map)
	if ResourceLoader.exists(GRANITE_TEXTURE_PATH):
		granite_rect.texture = load(GRANITE_TEXTURE_PATH)
		granite_rect.modulate = Color(0.78, 0.78, 0.82, 0.9)
	_apply_mode()
	_refresh_content.call_deferred()

func set_biome(biome: String):
	display_biome = biome
	if is_inside_tree():
		_refresh_content()

func _input(event):
	if embedded_mode:
		return
	if event.is_action_pressed("ui_cancel"):
		_back_to_story_map()

func _gui_input(event):
	if not embedded_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		chapter_pressed.emit(_get_biome())

func _apply_mode():
	background_rect.visible = show_background and not embedded_mode
	continue_button.visible = allow_navigation and not embedded_mode
	if embedded_mode:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var embedded_height = _get_embedded_height()
		var embedded_width = embedded_height * TABLET_ASPECT_RATIO
		custom_minimum_size = Vector2(embedded_width, embedded_height)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tablet.custom_minimum_size = Vector2(embedded_width, embedded_height)
		body_label.custom_minimum_size = Vector2(0, embedded_height * 0.72)
		body_label.scroll_active = false
		body_label.fit_content = false
		title_label.add_theme_font_size_override("font_size", 24)
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2.ZERO
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		tablet.custom_minimum_size = Vector2(640, 905)
		body_label.custom_minimum_size = Vector2(0, 680)
		body_label.scroll_active = true
		title_label.add_theme_font_size_override("font_size", 30)

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
	if biome == "home":
		return LocalizationManager.translate("story.title.home", "Introduction")
	var template = LocalizationManager.translate("story.title.default", "{biome} Chronicle")
	return template.replace("{biome}", biome.replace("_", " ").capitalize())

func _get_embedded_height() -> float:
	return max(320.0, get_viewport_rect().size.y * 0.9)

func _back_to_story_map():
	if embedded_mode or not allow_navigation:
		chapter_pressed.emit(_get_biome())
		return
	get_tree().change_scene_to_file(GameManager.get_story_map_scene_path())
