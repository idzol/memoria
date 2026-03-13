extends Control

signal chapter_pressed(biome: String)

const GRANITE_TEXTURE_PATH = "res://assets/rooms/scene/the_core_red_rock_vault_room.png"
const STORY_TEXT = {
	"home": "Introduction\n\nThe first tablets are kept at home, where routines still feel safe and memory has not yet learned to hide. This chapter is a tutorial of familiar rooms, small choices, and the first quiet signs that something underneath the town is shifting.",
	"town": "The tablets continue in the town where memory first fractures. Faces are familiar, but names refuse to settle.",
	"forest": "The forest chapter records a canopy of whispers. Every path asks what was forgotten to make the next step possible.",
	"ice_caves": "In the ice caves, the chapter is preserved in crystal seams. Old truths survive, but only in splinters.",
	"desert": "The desert tablets speak of heat, distance, and endurance. What remains is what could survive exposure.",
	"swamp": "The swamp keeps nothing clean. Memory sinks, resurfaces, and returns wearing a different shape.",
	"abyss": "The abyss chapter is all pressure and silence. Meaning compresses until only the strongest fragments remain.",
	"void": "Inside the void, absence becomes an archive. Missing pieces leave outlines sharp enough to guide by.",
	"the_core": "The core keeps the oldest story under layers of force and ash. Reaching it means deciding what should be restored."
}

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
	_refresh_content()

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
		custom_minimum_size = Vector2(300, 340)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tablet.custom_minimum_size = Vector2(300, 340)
		body_label.custom_minimum_size = Vector2(0, 190)
		body_label.scroll_active = false
		body_label.fit_content = false
		title_label.add_theme_font_size_override("font_size", 24)
	else:
		custom_minimum_size = Vector2.ZERO
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		tablet.custom_minimum_size = Vector2(640, 905)
		body_label.custom_minimum_size = Vector2(0, 680)
		body_label.scroll_active = true
		title_label.add_theme_font_size_override("font_size", 30)

func _refresh_content():
	var biome = _get_biome()
	title_label.text = _get_title_for_biome(biome)
	body_label.text = STORY_TEXT.get(biome, "The stone remembers more than the traveler does.")

func _get_biome() -> String:
	return display_biome if display_biome != "" else GameManager.selected_story_biome

func _get_title_for_biome(biome: String) -> String:
	if biome == "home":
		return "Introduction"
	return "%s Chronicle" % biome.replace("_", " ").capitalize()

func _back_to_story_map():
	if embedded_mode or not allow_navigation:
		chapter_pressed.emit(_get_biome())
		return
	get_tree().change_scene_to_file(GameManager.get_story_map_scene_path())
