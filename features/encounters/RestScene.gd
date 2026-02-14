extends Control

# References to UI elements
@onready var title_label = $MarginContainer/VBoxContainer/Title
@onready var desc_label = $MarginContainer/VBoxContainer/Description
@onready var rest_button = $MarginContainer/VBoxContainer/Choices/RestButton
@onready var upgrade_button = $MarginContainer/VBoxContainer/Choices/UpgradeButton
@onready var icon_label = $MarginContainer/VBoxContainer/Illustration/Icon

func _ready():
	# Initial UI state
	title_label.text = "Campfire Sanctuary"
	desc_label.text = "The crackling flames provide a moment of peace. How will you spend your time?"
	icon_label.text = "🔥"
	
	# Connect button signals
	rest_button.pressed.connect(_on_rest_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)

func _on_rest_pressed():
	# Rest logic: Heal a percentage of Max HP
	var heal_amount = floor(GameManager.max_hp * 0.3)
	GameManager.current_hp = min(GameManager.max_hp, GameManager.current_hp + heal_amount)
	
	_resolve_scene("You rest by the fire. You feel refreshed and restored.")

func _on_upgrade_pressed():
	# Upgrade logic: For now, a permanent minor damage boost
	# In a full game, this would open a 'Deck Upgrade' UI
	GameManager.max_hp += 10
	GameManager.current_hp += 10
	
	_resolve_scene("You hone your spirit. Your maximum vitality has increased.")

func _resolve_scene(message: String):
	# Disable buttons to prevent double-clicking
	rest_button.disabled = true
	upgrade_button.disabled = true
	
	desc_label.text = message
	
	# Emit signals for HUD updates
	SignalBus.hp_changed.emit(GameManager.current_hp, GameManager.max_hp)
	
	# Brief pause for the player to read before returning to map
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")