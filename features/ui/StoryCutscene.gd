extends Control

@onready var title_label = %TitleLabel
@onready var body_label = %BodyLabel
@onready var continue_button = %ContinueButton

var _is_continuing := false

const CUTSCENE_PLACEHOLDERS := {
	"home": {
		"title": "Chapter 1: The First Memory",
		"body": "Placeholder cutscene.\nA splinter of memory drifts across the dark, and the first path opens."
	},
	"town": {
		"title": "Chapter 2: The Quiet Streets",
		"body": "Placeholder cutscene.\nThe town waits like a memory half-recalled, full of doors that seem to remember your name."
	},
	"forest": {
		"title": "Chapter 3: The Green Silence",
		"body": "Placeholder cutscene.\nThe forest breathes around forgotten steps, and every branch points toward an older story."
	},
	"ice_caves": {
		"title": "Chapter 4: The Frozen Echo",
		"body": "Placeholder cutscene.\nIce keeps what the mind cannot. Beneath the frost, another truth is sleeping."
	},
	"desert": {
		"title": "Chapter 5: The Dust Between Names",
		"body": "Placeholder cutscene.\nWind strips the world to bone and sand, leaving only the shape of what was lost."
	},
	"swamp": {
		"title": "Chapter 6: The Drowned Path",
		"body": "Placeholder cutscene.\nIn the swamp, every step sinks into old choices, and the water gives nothing back for free."
	},
	"abyss": {
		"title": "Chapter 7: Below the Last Light",
		"body": "Placeholder cutscene.\nThe abyss opens where certainty ends, and memory must learn to breathe in the deep."
	},
	"void": {
		"title": "Chapter 8: The Fractured Dark",
		"body": "Placeholder cutscene.\nBeyond the edges of the world, the void rearranges meaning into sharper questions."
	},
	"the_core": {
		"title": "Chapter 9: The Heart of the World",
		"body": "Placeholder cutscene.\nAt the core, the oldest memory burns brightest, waiting to be named at last."
	}
}

func _ready():
	if DataManager and DataManager.has_method("pause_for_cutscene"):
		DataManager.pause_for_cutscene()

	var biome = GameManager.get_pending_story_sequence_biome()
	var content = CUTSCENE_PLACEHOLDERS.get(biome, {
		"title": biome.replace("_", " ").capitalize(),
		"body": "Placeholder cutscene."
	})
	title_label.text = str(content.get("title", "Story Cutscene"))
	body_label.text = str(content.get("body", "Placeholder cutscene."))
	continue_button.text = "Continue"
	continue_button.pressed.connect(_continue_sequence)

func _exit_tree():
	if DataManager and DataManager.has_method("resume_after_cutscene"):
		DataManager.resume_after_cutscene()

func _input(event):
	var is_space = event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_SPACE
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or is_space:
		_continue_sequence()

func _continue_sequence():
	if _is_continuing or not is_inside_tree():
		return
	_is_continuing = true
	GameManager.advance_story_sequence_from_cutscene()
