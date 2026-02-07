extends Control

# res://scripts/ui/RunSummary.gd
# The "End of Day" or "End of Run" summary.

@onready var total_gold_label = %TotalGoldLabel
@onready var items_list = %ItemsList
@onready var close_button = %CloseButton

func _ready():
	# Show cumulative gold gained during this run
	var run_gold = 0
	for loot in GameManager.run_loot:
		if loot.id == "gold":
			run_gold += loot.amount
	
	total_gold_label.text = "Total Gold Found: " + str(run_gold)
	
	# List all unique items acquired in this run
	var unique_items = []
	for loot in GameManager.run_loot:
		if loot.id != "gold" and not unique_items.has(loot.name):
			unique_items.append(loot.name)
			var lbl = Label.new()
			lbl.text = loot.name
			items_list.add_child(lbl)

	close_button.pressed.connect(_on_finish_run)

func _on_finish_run():
	# Reset run-specific data in GameManager and return to Main Menu
	GameManager.run_loot.clear()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")