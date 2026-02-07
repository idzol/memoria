extends Control

# res://scripts/ui/RunSummary.gd
# Summary screen handling the distinction between expedition cycles and run resets.

@onready var total_gold_label = %TotalGoldLabel
@onready var items_list = %ItemsList
@onready var close_button = %CloseButton
# Assuming a second button for hard resets exists in the TSCN or is added
@onready var end_run_button = get_node_or_null("%EndRunButton") 

func _ready():
	# Display cumulative stats for the current expedition/day
	var run_gold = 0
	for loot in GameManager.run_loot:
		if loot.id == "gold":
			run_gold += loot.amount
	
	total_gold_label.text = "Total Gold Found: " + str(run_gold)
	
	var unique_items = []
	for loot in GameManager.run_loot:
		if loot.id != "gold" and not unique_items.has(loot.name):
			unique_items.append(loot.name)
			var lbl = Label.new()
			lbl.text = loot.name
			items_list.add_child(lbl)

	# Primary flow: Finish the day and return home
	close_button.pressed.connect(_finish_run)
	
	# Optional flow: Completely end the run and clear map progress
	if end_run_button:
		end_run_button.pressed.connect(_end_run)

## Finish the Day/Expedition:
## Returns the player home but keeps the map and exploration progress intact.
func _finish_run():
	# Return to Home location at Layer -1, Column 2
	GameManager.reset_to_home()
	
	# We DO NOT clear run_map here. 
	# This allows the map to progressively become more explored over multiple expeditions.
	
	# Transition back to menu so player can "Continue"
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

## End the Run:
## Clears all session history, including the map and cumulative loot.
func _end_run():
	# Hard reset of player position
	GameManager.reset_to_home()
	
	# Full wipe of session/run data
	GameManager.run_loot.clear()
	GameManager.run_map = {} 
	
	# Return to Main Menu
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")