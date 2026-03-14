extends Control

@onready var title_label = %TitleLabel
@onready var body_label = %BodyLabel
@onready var continue_button = %ContinueButton

func _ready():
	var cleared_biome = str(GameManager.current_node.get("biome", "unknown")).replace("_", " ").capitalize()
	var next_biome = _get_next_biome_name()
	title_label.text = "%s Cleared" % cleared_biome
	body_label.text = "The memory of %s settles. A new path opens toward %s." % [cleared_biome, next_biome]
	continue_button.pressed.connect(_go_to_story_map)

func _input(event):
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_go_to_story_map()

func _go_to_story_map():
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://features/map/StoryMap.tscn")

func _get_next_biome_name() -> String:
	for id in GameManager.run_map:
		var node = GameManager.run_map[id]
		if int(node.get("layer", -999)) == GameManager.player_grid_pos.y and int(node.get("column", -999)) == GameManager.player_grid_pos.x:
			return str(node.get("biome", "unknown")).replace("_", " ").capitalize()
	return "the unknown"
