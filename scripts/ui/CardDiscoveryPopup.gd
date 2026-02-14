extends Control

# res://scripts/ui/CardDiscoveryPopup.gd
# Handles the popup when a player discovers a new card for their inventory.

@onready var card_name = %CardName
@onready var card_desc = %CardDesc
@onready var claim_button = %ClaimButton
# Note: Ensure you have a TextureRect in your .tscn named 'CardImage'
@onready var card_image = get_node_or_null("%CardImage") 

var current_card_id: String = ""

func _ready():
	claim_button.pressed.connect(_on_claim_pressed)

func show_discovery(id: String):
	current_card_id = id
	visible = true
	
	# UPDATED: Pull authoritative data from the static CardDatabase
	# The 'static' keyword in CardDatabase.gd resolves the previous Parser Error
	var data = CardDatabase.get_card(id)
	
	card_name.text = data.name
	card_desc.text = data.description
	
	# UPDATED: Display the high-resolution 'image' version (not the combat icon)
	if card_image and ResourceLoader.exists(data.image):
		card_image.texture = load(data.image)
	elif card_image:
		# Fallback to a default if the specific image path is missing
		card_image.texture = load("res://assets/trap.png")

func _on_claim_pressed():
	if current_card_id != "" and not current_card_id in GameManager.player_inventory:
		GameManager.player_inventory.append(current_card_id)
		SaveManager.save_mid_run_state()
	
	visible = false