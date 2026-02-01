extends Control

# References to UI elements
@onready var title_label = $MarginContainer/VBoxContainer/Title
@onready var desc_label = $MarginContainer/VBoxContainer/Description
@onready var button_container = $MarginContainer/VBoxContainer/Choices
@onready var icon_label = $MarginContainer/VBoxContainer/Illustration/Icon

# Sample Event Data Pool
# In a larger project, these could be custom Resources
var events = [
	{
		"title": "The Whispering Well",
		"icon": "🕳️",
		"text": "You encounter an ancient stone well. A faint whisper promises power in exchange for a drop of life essence.",
		"choices": [
			{"text": "Offer Blood (-15 HP, +40 Gold)", "effect": "blood"},
			{"text": "Walk Away (Nothing happens)", "effect": "leave"}
		]
	},
	{
		"title": "A Traveling Merchant",
		"icon": "🐫",
		"text": "A shady figure offers you a 'miracle tonic' for a handful of coins. It smells slightly of vinegar.",
		"choices": [
			{"text": "Buy Tonic (-30 Gold, +25 HP)", "effect": "buy_tonic"},
			{"text": "Refuse", "effect": "leave"}
		]
	},
	{
		"title": "Abandoned Shrine",
		"icon": "⛩️",
		"text": "An old shrine to a forgotten memory god. It feels heavy with static electricity.",
		"choices": [
			{"text": "Pray (Become 'Charged')", "effect": "charge"},
			{"text": "Scavenge (+15 Gold)", "effect": "scavenge"}
		]
	}
]

var current_event = null

func _ready():
	# Select a random event from the pool
	current_event = events.pick_random()
	_display_event(current_event)

func _display_event(event):
	title_label.text = event.title
	desc_label.text = event.text
	icon_label.text = event.icon
	
	# Clear old buttons
	for child in button_container.get_children():
		child.queue_free()
		
	# Create new choice buttons
	for choice in event.choices:
		var btn = Button.new()
		btn.text = choice.text
		btn.custom_minimum_size.y = 50
		btn.pressed.connect(_on_choice_selected.bind(choice.effect))
		button_container.add_child(btn)

func _on_choice_selected(effect: String):
	match effect:
		"blood":
			GameManager.take_damage(15)
			GameManager.gold += 40
		"buy_tonic":
			if GameManager.gold >= 30:
				GameManager.gold -= 30
				GameManager.current_hp = min(GameManager.max_hp, GameManager.current_hp + 25)
			else:
				print("Not enough gold!")
				return
		"charge":
			# Logic for a 'charged' state could be added to GameManager
			print("Player is now charged!") 
		"scavenge":
			GameManager.gold += 15
		"leave":
			pass
			
	# Update global UI and return to map
	SignalBus.gold_changed.emit(GameManager.gold)
	SignalBus.hp_changed.emit(GameManager.current_hp, GameManager.max_hp)
	
	# Transition back to map
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")