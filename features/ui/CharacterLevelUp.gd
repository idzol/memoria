extends Control

# res://features/ui/CharacterLevelUp.gd
# Displays pre/post level stats and routes back to the stored scene.

@onready var title_label = %TitleLabel
@onready var old_level_label = %OldLevelLabel
@onready var new_level_label = %NewLevelLabel
@onready var old_hp = %OldHP
@onready var old_energy = %OldEnergy
@onready var old_attack = %OldAttack
@onready var old_defense = %OldDefense
@onready var new_hp = %NewHP
@onready var new_energy = %NewEnergy
@onready var new_attack = %NewAttack
@onready var new_defense = %NewDefense
@onready var continue_button = %ContinueButton

func _ready():
	var data = GameManager.pending_level_up
	if data.is_empty():
		_show_fallback_data()
	else:
		_apply_level_up_data(data)
	
	continue_button.pressed.connect(_on_continue_pressed)

func _apply_level_up_data(data: Dictionary):
	var old_level = int(data.get("old_level", max(1, GameManager.player_level - 1)))
	var new_level = int(data.get("new_level", GameManager.player_level))
	var old_stats = data.get("old_stats", {})
	var new_stats = data.get("new_stats", {})
	
	title_label.text = "%s LEVELED UP!" % GameManager.player_class.to_upper()
	old_level_label.text = "Level %d" % old_level
	new_level_label.text = "Level %d" % new_level
	
	old_hp.text = str(old_stats.get("max_hp", 0))
	old_energy.text = str(old_stats.get("energy", 0))
	old_attack.text = str(old_stats.get("player_attack", 0))
	old_defense.text = str(old_stats.get("player_defense", 0))
	
	new_hp.text = str(new_stats.get("max_hp", 0))
	new_energy.text = str(new_stats.get("energy", 0))
	new_attack.text = str(new_stats.get("player_attack", 0))
	new_defense.text = str(new_stats.get("player_defense", 0))

func _show_fallback_data():
	var new_level = GameManager.player_level
	var old_level = max(1, new_level - 1)
	var old_stats = GameData.get_stats(_normalized_class_id(), old_level)
	var new_stats = GameData.get_stats(_normalized_class_id(), new_level)
	_apply_level_up_data({
		"old_level": old_level,
		"new_level": new_level,
		"old_stats": old_stats,
		"new_stats": new_stats
	})

func _normalized_class_id() -> String:
	var raw = GameManager.player_class.to_lower()
	match raw:
		"archivist":
			return "scholar"
		"berserker":
			return "warrior"
		"illusionist":
			return "alchemist"
		_:
			return raw

func _on_continue_pressed():
	var next_scene = GameManager.level_up_return_scene
	GameManager.pending_level_up = {}
	GameManager.level_up_return_scene = ""
	if next_scene == "":
		next_scene = GameManager.get_active_biome_map_scene_path()
	get_tree().change_scene_to_file(next_scene)
