extends Control

const GRANITE_TEXTURE_PATH = "res://assets/rooms/scene/the_core_red_rock_vault_room.png"

@onready var granite_rect = %GraniteRect
@onready var title_label = %TitleLabel
@onready var body_label = %BodyLabel
@onready var continue_button = %ContinueButton

const STORY_TEXT = {
	"town": "The tablets begin in the town where memory first fractures. Faces are familiar, but names refuse to settle.",
	"forest": "The forest chapter records a canopy of whispers. Every path asks what was forgotten to make the next step possible.",
	"ice_caves": "In the ice caves, the chapter is preserved in crystal seams. Old truths survive, but only in splinters.",
	"desert": "The desert tablets speak of heat, distance, and endurance. What remains is what could survive exposure.",
	"swamp": "The swamp keeps nothing clean. Memory sinks, resurfaces, and returns wearing a different shape.",
	"abyss": "The abyss chapter is all pressure and silence. Meaning compresses until only the strongest fragments remain.",
	"void": "Inside the void, absence becomes an archive. Missing pieces leave outlines sharp enough to guide by.",
	"the_core": "The core keeps the oldest story under layers of force and ash. Reaching it means deciding what should be restored."
}

func _ready():
	var biome = GameManager.selected_story_biome
	title_label.text = "%s Chronicle" % biome.replace("_", " ").capitalize()
	body_label.text = STORY_TEXT.get(biome, "The stone remembers more than the traveler does.")
	continue_button.pressed.connect(_back_to_story_map)
	if ResourceLoader.exists(GRANITE_TEXTURE_PATH):
		granite_rect.texture = load(GRANITE_TEXTURE_PATH)
		granite_rect.modulate = Color(0.78, 0.78, 0.82, 0.9)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_back_to_story_map()

func _back_to_story_map():
	get_tree().change_scene_to_file(GameManager.get_story_map_scene_path())
