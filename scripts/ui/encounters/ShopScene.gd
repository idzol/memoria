extends Control

# References to UI elements
@onready var gold_label = $MarginContainer/VBoxContainer/Header/GoldLabel
@onready var item_container = $MarginContainer/VBoxContainer/ShopItems
@onready var leave_button = $MarginContainer/VBoxContainer/LeaveButton
@onready var merchant_dialogue = $MarginContainer/VBoxContainer/MerchantPanel/Dialogue

# Sample Shop Items
var shop_pool = [
	{"name": "Healing Potion", "price": 40, "desc": "Restores 30 HP", "type": "heal", "val": 30},
	{"name": "Vitality Crystal", "price": 75, "desc": "+15 Max HP", "type": "max_hp", "val": 15},
	{"name": "Polished Blade", "price": 60, "desc": "+5 Attack Dmg", "type": "stat_atk", "val": 5},
	{"name": "Mysterious Scroll", "price": 50, "desc": "Add 'Magic' to Deck", "type": "card", "val": "scroll"},
	{"name": "Iron Plate", "price": 50, "desc": "Add 'Wall' to Deck", "type": "card", "val": "wall"}
]

func _ready():
	_update_gold_display()
	_generate_shop_inventory()
	leave_button.pressed.connect(_on_leave_pressed)
	merchant_dialogue.text = "Take your time, traveler. Everything has a price..."

func _generate_shop_inventory():
	# Pick 3 random items from the pool
	var inventory = shop_pool.duplicate()
	inventory.shuffle()
	
	for i in range(3):
		var item = inventory[i]
		_create_item_card(item)

func _create_item_card(item_data):
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 200)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var name_lbl = Label.new()
	name_lbl.text = item_data.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var desc_lbl = Label.new()
	desc_lbl.text = item_data.desc
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	var buy_btn = Button.new()
	buy_btn.text = str(item_data.price) + " Gold"
	buy_btn.custom_minimum_size.y = 40
	
	# Check if player can afford it
	if GameManager.gold < item_data.price:
		buy_btn.disabled = true
		buy_btn.text = "Too Expensive"
	
	buy_btn.pressed.connect(_on_buy_pressed.bind(item_data, buy_btn))
	
	vbox.add_child(name_lbl)
	vbox.add_child(desc_lbl)
	vbox.add_child(buy_btn)
	panel.add_child(vbox)
	item_container.add_child(panel)

func _on_buy_pressed(item_data, button):
	if GameManager.gold >= item_data.price:
		GameManager.gold -= item_data.price
		_process_purchase(item_data)
		
		# Update UI
		button.disabled = true
		button.text = "Purchased"
		_update_gold_display()
		merchant_dialogue.text = "A fine choice! You won't regret it."
		SignalBus.gold_changed.emit(GameManager.gold)

func _process_purchase(item):
	match item.type:
		"heal":
			GameManager.current_hp = min(GameManager.max_hp, GameManager.current_hp + item.val)
		"max_hp":
			GameManager.max_hp += item.val
			GameManager.current_hp += item.val
		"card":
			GameManager.current_deck.append(item.val)
		"stat_atk":
			# Logic for global damage modifiers could go here
			print("Attack increased by ", item.val)

func _update_gold_display():
	gold_label.text = "Your Gold: " + str(GameManager.gold)

func _on_leave_pressed():
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")