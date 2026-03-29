extends Control

@onready var title_label = %TitleLabel
@onready var body_label = %BodyLabel
@onready var text_viewport = %TextViewport
@onready var story_block = %StoryBlock
@onready var continue_hint = %ContinueHint

const SCROLL_SPEED := 46.0
const STORY_PLACEHOLDERS := {
	"home": {
		"title": "Introduction",
		"body": "Upon the desolate heights of the crags, the youth did cast aside the treasures of the immortals, 
for the polished bronze had become to him as heavy stones without meaning. 
He looked upon the shield and saw only the passing of clouds, finding no reflection of his former purpose within its metallic depths. 
 Like a traveler who sheds a heavy cloak in the heat of noon, he abandoned the instruments of his fate against the jagged rocks, 
choosing instead the path that led downward to the salt-spray and the common soil of men.

He descended into the village, where the air was thick with the scent of drying kelp and the labor of the forge. 
There, his tools were put to the base service of the hearth and the pier, its keen edge used to pry the stubborn barnacle from rotted wood. 

Dictys the fisherman looked upon the lad, and saw a silent drifter with eyes clouded by the mist of forgetting. 
As the golden thread of destiny snapped, the boy stood upon the stone quay, casting his line into the grey expanse, 
knowing at last the peace of a man who has traded myth for the simple hunger of the sea."
	},
	"town": {
		"title": "Town",
		"body": "Placeholder chapter text.\n\nThe town gathers fragments into pattern.\nFaces, doors, and lantern light begin to suggest a life once lived.\nSomething important was left here, and the streets seem to know it."
	},
	"forest": {
		"title": "Forest",
		"body": "Placeholder chapter text.\n\nThe forest remembers through roots and shadow.\nIt keeps old roads buried under moss, waiting for someone brave enough to listen.\nEvery clearing feels like a memory trying to return."
	},
	"ice_caves": {
		"title": "Ice Caves",
		"body": "Placeholder chapter text.\n\nThe cold preserves what fear tried to hide.\nIn the ice, silence sharpens every thought into something brittle and true.\nWhat was buried here did not stay buried by accident."
	},
	"desert": {
		"title": "Desert",
		"body": "Placeholder chapter text.\n\nThe desert strips comfort from every answer.\nHere, memory survives as heat shimmer and stubborn will.\nThe horizon keeps retreating, as if daring you to keep going."
	},
	"swamp": {
		"title": "Swamp",
		"body": "Placeholder chapter text.\n\nThe swamp does not forget.\nIt folds old choices back into the path and asks whether you can carry them this time.\nEven the still water feels like it is watching."
	},
	"abyss": {
		"title": "Abyss",
		"body": "Placeholder chapter text.\n\nBelow the last light, the world changes its rules.\nThe abyss is a place of pressure, distance, and truths that surface too late.\nStill, something in the dark is calling you deeper."
	},
	"void": {
		"title": "Void",
		"body": "Placeholder chapter text.\n\nThe void is less a place than a wound in meaning.\nShapes and names loosen here, drifting apart under unseen tides.\nTo cross it, you will need to decide what cannot be surrendered."
	},
	"the_core": {
		"title": "The Core",
		"body": "Placeholder chapter text.\n\nAt the center of all this ruin, something still burns.\nThe core holds the oldest memory and the final answer.\nWhatever waits there has been waiting for you all along."
	}
}

var _scroll_complete: bool = false

func _ready():
	continue_hint.text = "Press Space / Enter to continue"
	if not resized.is_connected(_layout_story_block):
		resized.connect(_layout_story_block)
	var biome = GameManager.get_pending_story_sequence_biome()
	var content = STORY_PLACEHOLDERS.get(biome, {
		"title": biome.replace("_", " ").capitalize(),
		"body": "Placeholder chapter text."
	})
	title_label.text = str(content.get("title", "Story Chapter"))
	body_label.text = str(content.get("body", "Placeholder chapter text."))
	_layout_story_block.call_deferred()

func _process(delta: float):
	if _scroll_complete or not story_block or not text_viewport:
		return
	story_block.position.y -= SCROLL_SPEED * delta
	if story_block.position.y + story_block.size.y <= 0.0:
		_scroll_complete = true
		continue_hint.modulate.a = 1.0

func _input(event):
	var is_space = event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_SPACE
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or is_space:
		_finish_sequence()

func _layout_story_block():
	if not story_block or not text_viewport or not body_label:
		return
	var width = min(860.0, max(360.0, text_viewport.size.x - 120.0))
	story_block.custom_minimum_size.x = width
	body_label.custom_minimum_size.x = width
	await get_tree().process_frame
	var block_size = story_block.get_combined_minimum_size()
	story_block.size = block_size
	story_block.position = Vector2(
		(text_viewport.size.x - width) * 0.5,
		text_viewport.size.y
	)
	_scroll_complete = false
	continue_hint.modulate.a = 0.72

func _finish_sequence():
	if not is_inside_tree():
		return
	GameManager.finish_story_sequence()
