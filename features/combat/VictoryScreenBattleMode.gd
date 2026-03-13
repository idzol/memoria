extends Control

# res://features/combat/VictoryScreenBattleMode.gd
# Updated: High-performance implementation using DataManager registry.

const CardScene = preload("res://features/combat/Card.tscn")

@onready var reward_container = %RewardContainer
@onready var title_label = %TitleLabel
@onready var sub_title = %SubTitle

func _ready():
	if not reward_container or not title_label:
		return
	_generate_rewards()

func _generate_rewards():
	for child in reward_container.get_children():
		child.queue_free()
	
	# Determine rarity from enemy resource
	var node_data = GameManager.current_node
	var target_rarity = "common"
	
	if node_data.has("enemy_resource"):
		var enemy_res = node_data["enemy_resource"]
		if enemy_res and "rarity" in enemy_res:
			target_rarity = enemy_res.rarity.to_lower()
	
	title_label.text = "%s SPOILS" % target_rarity.to_upper()
	
	# PERFORMANCE: Instant retrieval from pre-indexed DataManager pool
	# This replaces the slow DirAccess loop
	var rewards = DataManager.get_random_by_rarity("cards", target_rarity, 3)
	
	for card_res in rewards:
		_create_reward_option(card_res)

func _create_reward_option(data: CardData):
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size.x = 200
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	
	var card_ui = CardScene.instantiate()
	vbox.add_child(card_ui)
	card_ui.setup(data)
	
	card_ui.get_node("%BackFace").visible = false
	card_ui.get_node("%FrontFace").visible = true
	card_ui.is_face_up = true
	
	# Match GameManager logic: checking for ownership in player_deck
	if data.card_id in GameManager.player_deck:
		var owned_lbl = Label.new()
		owned_lbl.text = "OWNED"
		owned_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owned_lbl.modulate = Color(1, 0.8, 0.2) 
		owned_lbl.add_theme_font_size_override("font_size", 16)
		vbox.add_child(owned_lbl)
	else:
		var spacer = Control.new()
		spacer.custom_minimum_size.y = 25
		vbox.add_child(spacer)
	
	var btn = Button.new()
	btn.text = "CLAIM"
	btn.custom_minimum_size = Vector2(140, 45)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_reward_selected.bind(data.card_id))
	vbox.add_child(btn)
	
	reward_container.add_child(vbox)

func _on_reward_selected(id: String):
	if not id in GameManager.player_deck:
		GameManager.player_deck.append(id)
	
	if GameManager.active_deck.size() < 12 and not id in GameManager.active_deck:
		GameManager.active_deck.append(id)
		
	SaveManager.save_mid_run_state()
	get_tree().change_scene_to_file(GameManager.consume_pending_post_battle_scene("res://features/map/BattleMap.tscn"))
