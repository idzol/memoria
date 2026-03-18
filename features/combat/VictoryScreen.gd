extends Control

# res://features/combat/VictoryScreen.gd
# Immediate results screen shown after a single battle.

@onready var loot_container = %LootContainer
@onready var continue_button = %ContinueButton

func _ready():
	var xp_lbl = Label.new()
	xp_lbl.text = "XP Gained: %d" % GameManager.last_xp_gained
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_container.add_child(xp_lbl)

	# Display only the loot from the most recent battle
	for item in GameManager.pending_loot:
		var lbl = Label.new()
		lbl.text = "Gained: " + item.name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loot_container.add_child(lbl)
	
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed():
	var fallback_scene = GameManager.get_active_biome_map_scene_path()
	if not GameManager.pending_level_up.is_empty():
		GameManager.level_up_return_scene = GameManager.consume_pending_post_battle_scene(fallback_scene)
		SceneTransition.change_scene_to_file("res://features/ui/CharacterLevelUp.tscn")
		return
	SceneTransition.change_scene_to_file(GameManager.consume_pending_post_battle_scene(fallback_scene))
