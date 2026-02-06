extends Control

# res://scripts/ui/combat/VictoryScreen.gd
# Immediate results screen shown after a single battle.

@onready var loot_container = %LootContainer
@onready var continue_button = %ContinueButton

func _ready():
	# Display only the loot from the most recent battle
	for item in GameManager.pending_loot:
		var lbl = Label.new()
		lbl.text = "Gained: " + item.name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loot_container.add_child(lbl)
	
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed():
	# Return to map to continue the run
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")