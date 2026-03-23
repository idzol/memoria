extends Control

signal continue_requested

const CardScene = preload("res://features/combat/Card.tscn")

@export var overlay_mode: bool = true

@onready var title_label = %TitleLabel
@onready var subtitle_label = %SubtitleLabel
@onready var loot_row = %LootRow
@onready var empty_label = %EmptyLabel
@onready var xp_label = %XPLabel
@onready var gold_label = %GoldLabel
@onready var continue_button = %ContinueButton

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)
	if not overlay_mode:
		populate_from_game_manager()

func populate_from_game_manager():
	var enemy_name = ""
	var node_data = GameManager.current_node
	var room_path = str(node_data.get("room_resource_path", ""))
	if room_path != "" and ResourceLoader.exists(room_path):
		var room_res = load(room_path) as RoomData
		if room_res and room_res.enemy_id != "":
			var enemy_path = "res://data/enemies/%s.tres" % room_res.enemy_id
			if ResourceLoader.exists(enemy_path):
				var enemy_res = load(enemy_path) as EnemyData
				if enemy_res:
					enemy_name = enemy_res.name
	populate_rewards(GameManager.pending_loot, GameManager.last_xp_gained, _get_gold_amount(GameManager.pending_loot), enemy_name)

func populate_rewards(loot: Array, xp_amount: int, gold_amount: int, enemy_name: String = ""):
	_clear_loot_row()
	title_label.text = "VICTORY"
	subtitle_label.text = "The %s has fallen." % enemy_name if enemy_name != "" else "The enemy has fallen."
	var card_count = 0
	for entry in loot:
		if not (entry is Dictionary):
			continue
		if str(entry.get("id", "")) == "gold":
			continue
		var card_view = _build_reward_card(entry)
		if card_view == null:
			continue
		loot_row.add_child(card_view)
		card_count += 1
	empty_label.visible = card_count == 0
	xp_label.text = "You have gained %d memory" % xp_amount
	gold_label.text = "You have found %d gold" % gold_amount

func _build_reward_card(entry: Dictionary) -> Control:
	var reward_id = str(entry.get("id", ""))
	if reward_id == "":
		return null
	var card_view = CardScene.instantiate()
	card_view.custom_minimum_size = Vector2(120, 180)
	card_view.disabled = true
	var is_card = bool(entry.get("is_card", false))
	var is_item = bool(entry.get("is_item", false))
	if not is_card and not is_item:
		is_card = ResourceLoader.exists("res://data/cards/%s.tres" % reward_id)
		is_item = not is_card and ResourceLoader.exists("res://data/items/%s.tres" % reward_id)
	if is_card:
		var card_res = load("res://data/cards/%s.tres" % reward_id) as CardData
		if card_res == null:
			card_view.queue_free()
			return null
		card_view.setup(card_res)
	elif is_item:
		var item_res = load("res://data/items/%s.tres" % reward_id) as ItemData
		if item_res == null:
			card_view.queue_free()
			return null
		card_view.setup_item(item_res)
	else:
		card_view.queue_free()
		return null
	var back_face = card_view.get_node_or_null("%BackFace")
	if back_face:
		back_face.visible = false
	var front_face = card_view.get_node_or_null("%FrontFace")
	if front_face:
		front_face.visible = true
	card_view.is_face_up = true
	return card_view

func _clear_loot_row():
	for child in loot_row.get_children():
		child.queue_free()

func _get_gold_amount(loot: Array) -> int:
	var amount = 0
	for entry in loot:
		if entry is Dictionary and str(entry.get("id", "")) == "gold":
			amount += int(entry.get("amount", 0))
	return amount

func _on_continue_pressed():
	continue_requested.emit()
