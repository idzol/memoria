extends Control

# res://scripts/ui/CardDiscoveryPopup.gd

@onready var card_name = %CardName
@onready var card_desc = %CardDesc
@onready var claim_button = %ClaimButton

var current_card_id: String = ""

func _ready():
	claim_button.pressed.connect(_on_claim_pressed)

func show_discovery(id: String):
	current_card_id = id
	visible = true
	
	# Reference the data from CharacterScreen or a shared Database
	var data = preload("res://scripts/ui/CharacterScreen.gd").CARD_DATA
	if data.has(id):
		card_name.text = data[id].name
		card_desc.text = data[id].desc

func _on_claim_pressed():
	if not current_card_id in GameManager.player_inventory:
		GameManager.player_inventory.append(current_card_id)
		SaveManager.save_mid_run_state()
	visible = false