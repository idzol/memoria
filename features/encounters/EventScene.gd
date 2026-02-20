extends Control

# res://features/encounters/EventScene.gd

# IMPORT: Centralized data
const GameData = preload("res://core/GameData.gd")

@onready var title_label = $MarginContainer/VBoxContainer/Title
@onready var desc_label = $MarginContainer/VBoxContainer/Description
@onready var button_container = $MarginContainer/VBoxContainer/Choices
@onready var icon_label = $MarginContainer/VBoxContainer/Illustration/Icon

var current_event_data = null

func _ready():
	_setup_event()

func _setup_event():
	var node = GameManager.current_node
	var event_id = node.get("event_id", "")
	
	# 1. Attempt to load specific event ID defined in the room
	if event_id != "" and GameData.EVENTS.has(event_id):
		current_event_data = GameData.EVENTS[event_id]
	else:
		# 2. Fallback: Pick a random event if node is generic 'event' type 
		# or if the defined ID was invalid
		var keys = GameData.EVENTS.keys()
		var random_key = keys[randi() % keys.size()]
		current_event_data = GameData.EVENTS[random_key]
	
	_display_event(current_event_data)

func _display_event(event):
	title_label.text = event.title
	desc_label.text = event.text
	icon_label.text = event.get("icon", "❓")
	
	# Clear previous choice buttons
	for child in button_container.get_children():
		child.queue_free()
		
	# Build choice buttons dynamically
	for choice in event.choices:
		var btn = Button.new()
		btn.text = choice.text
		btn.custom_minimum_size.y = 50
		btn.pressed.connect(_on_choice_selected.bind(choice.effect))
		button_container.add_child(btn)

func _on_choice_selected(effect: String):
	# Handle gameplay logic for specific effects
	match effect:
		"blood":
			GameManager.current_hp = max(0, GameManager.current_hp - 15)
			GameManager.gold += 40
		"buy_tonic":
			if GameManager.gold >= 30:
				GameManager.gold -= 30
				GameManager.current_hp = min(GameManager.max_hp, GameManager.current_hp + 25)
		"charge":
			# Placeholder for future logic
			print("Status Applied: Charged")
		"scavenge":
			GameManager.gold += 15
		"leave":
			pass
			
	# Update Global UI listeners
	SignalBus.gold_changed.emit(GameManager.gold)
	SignalBus.hp_changed.emit(GameManager.current_hp, GameManager.max_hp)
	
	# Return to the world map
	get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")