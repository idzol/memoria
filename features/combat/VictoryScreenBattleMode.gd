extends Control

# res://features/combat/VictoryScreenBattleMode.gd
# Specialized reward screen for Battle Mode Draft.

const CardData = preload("res://data/resources/CardData.gd")
const CardScene = preload("res://features/combat/Card.tscn")

@onready var reward_container = %RewardContainer
@onready var title_label = %TitleLabel
@onready var sub_title = %SubTitle

var selected_card_id: String = ""

func _ready():
	_generate_rewards()

func _generate_rewards():
	for child in reward_container.get_children():
		child.queue_free()
		
	var enemy = GameManager.current_node.get("enemy_data")
	# Fallback if specific enemy data isn't cached in the node
	var target_rarity = "common"
	if enemy and enemy is EnemyData:
		target_rarity = enemy.rarity.to_lower()
	elif GameManager.current_node.get("difficulty", 0) >= 4:
		target_rarity = "rare"
		
	title_label.text = "VICTORY: %s SPOILS" % target_rarity.to_upper()
	
	# 1. Fetch all cards of the target rarity from the database
	var pool = _get_cards_by_rarity(target_rarity)
	pool.shuffle()
	
	# 2. Pick top 3 unique rewards
	var rewards = pool.slice(0, 3)
	
	for card_res in rewards:
		_create_reward_card(card_res)

func _get_cards_by_rarity(rarity: String) -> Array:
	var results = []
	var path = "res://data/cards/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var res = load(path + file_name)
				if res is CardData and res.rarity.to_lower() == rarity:
					results.append(res)
			file_name = dir.get_next()
	
	# Fallback if no cards found for that rarity
	if results.is_empty():
		return [load("res://data/cards/sword.tres"), load("res://data/cards/shield.tres"), load("res://data/cards/heart.tres")]
	return results

func _create_reward_card(data: CardData):
	var holder = VBoxContainer.new()
	holder.custom_minimum_size.x = 200
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Full Card UI
	var card_ui = CardScene.instantiate()
	holder.add_child(card_ui)
	card_ui.setup(data)
	
	# Force face-up
	card_ui.get_node("%BackFace").visible = false
	card_ui.get_node("%FrontFace").visible = true
	card_ui.is_face_up = true
	
	# "Already Owned" Logic
	if data.card_id in GameManager.player_cards:
		var owned_lbl = Label.new()
		owned_lbl.text = "ALREADY OWNED"
		owned_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owned_lbl.modulate = Color.GOLD
		owned_lbl.add_theme_font_size_override("font_size", 14)
		holder.add_child(owned_lbl)
	else:
		# Add a spacer to maintain alignment
		var spacer = Control.new()
		spacer.custom_minimum_size.y = 25
		holder.add_child(spacer)
	
	# Select Button
	var btn = Button.new()
	btn.text = "CLAIM"
	btn.custom_minimum_size.y = 40
	btn.pressed.connect(_on_reward_selected.bind(data.card_id))
	holder.add_child(btn)
	
	reward_container.add_child(holder)

func _on_reward_selected(id: String):
	# Add to permanent collection
	if not id in GameManager.player_cards:
		GameManager.player_cards.append(id)
	
	# Auto-add to active deck if there is room
	if GameManager.active_deck.size() < 12 and not id in GameManager.active_deck:
		GameManager.active_deck.append(id)
		
	SaveManager.save_mid_run_state()
	
	# Return to Battle Map
	get_tree().change_scene_to_file("res://features/map/BattleMapUI.tscn")