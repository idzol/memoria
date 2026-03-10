extends Control

const CardScene = preload("res://features/combat/Card.tscn")

@onready var active_deck_grid = %ActiveDeckGrid
@onready var player_deck_grid = %PlayerDeckGrid
@onready var item_grid = %ItemGrid
@onready var deck_count_label = %DeckCount
@onready var item_count_label = %ItemCount
@onready var class_label = %ClassName

@onready var hp_bar = %HPBar
@onready var hp_text = %HPText
@onready var xp_bar = %XPBar
@onready var xp_text = %XPText

@onready var atk_label = %AtkLabel
@onready var def_label = %DefLabel
@onready var energy_label = %EnergyLabel
@onready var gold_label = %GoldLabel
@onready var back_button = %BackButton
@onready var info_toast_box = %InfoToastBox
@onready var info_toast_label = %InfoToastLabel

const CARDS_ROOT = "res://data/cards/"
const ITEMS_ROOT = "res://data/items/"

const MAX_ACTIVE_DECK_CARDS := 12
const STACK_OFFSET_X := 8.0
const STACK_OFFSET_Y := 5.0
const STACK_BACK_COPIES := 2

var _info_toast_tween: Tween

func _ready():
	_ensure_default_player_deck()
	_update_stats_ui()
	_populate_deck_tab()
	_populate_inventory_tab()
	_update_counters()
	_hide_info_toast()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _ensure_default_player_deck():
	if GameManager.player_deck.is_empty() and GameManager.active_deck.is_empty():
		GameManager.player_deck = ["sword", "shield", "heart"]

func _update_stats_ui():
	var p_lvl = GameManager.player_level
	class_label.text = "%s (Lvl %d)" % [GameManager.player_class, p_lvl]
	
	GameManager.recalculate_player_totals()
	var totals = GameManager.get_item_stat_bonuses()
	
	var total_max_hp = GameManager.player_hp_total
	hp_bar.max_value = total_max_hp
	hp_bar.value = GameManager.current_hp
	hp_text.text = "❤️ %d / %d" % [GameManager.current_hp, total_max_hp]
	
	var max_xp = GameData.get_max_xp_for_level(GameManager.player_level)
	xp_bar.max_value = max_xp
	xp_bar.value = GameManager.player_xp
	xp_text.text = "🪟 %d / %d" % [GameManager.player_xp, max_xp]
	
	atk_label.text = "⚔️ ATTACK: %d (%d+%d)" % [
		GameManager.player_attack_total,
		GameManager.player_attack,
		totals.atk_bonus
	]
	def_label.text = "🧿 DEFENSE: %d (%d+%d)" % [
		GameManager.player_defense_total,
		GameManager.player_defense,
		totals.def_bonus
	]
	energy_label.text = "⚡ ENERGY: %d" % int(GameManager.base_energy)
	gold_label.text = "🪙 GOLD: %d" % GameManager.gold

func _populate_deck_tab():
	_clear_children(active_deck_grid)
	_clear_children(player_deck_grid)
	
	var active_counts = _count_ids(GameManager.active_deck)
	var reserve_counts = _count_ids(GameManager.player_deck)
	
	var active_ids = active_counts.keys()
	active_ids.sort()
	for card_id in active_ids:
		var card_res = _load_card(card_id)
		if card_res:
			_add_card_stack_to_grid(active_deck_grid, card_id, card_res, active_counts[card_id], "active")
	
	var reserve_ids = reserve_counts.keys()
	reserve_ids.sort()
	for card_id in reserve_ids:
		var reserve_card = _load_card(card_id)
		if reserve_card:
			_add_card_stack_to_grid(player_deck_grid, card_id, reserve_card, reserve_counts[card_id], "player")

func _populate_inventory_tab():
	_clear_children(item_grid)
	for item_id in GameManager.player_items:
		var path = ITEMS_ROOT + item_id + ".tres"
		if ResourceLoader.exists(path):
			var res = load(path) as ItemData
			_add_item_to_grid(item_id, res)

func _add_item_to_grid(id: String, res: ItemData):
	var card_ui = CardScene.instantiate()
	item_grid.add_child(card_ui)
	_configure_card_ui(card_ui, res)
	
	var is_active = id in GameManager.active_items
	if is_active:
		card_ui.modulate = Color.WHITE
		card_ui.self_modulate = Color(0.5, 0.8, 1.0)
	else:
		card_ui.modulate = Color(0.6, 0.6, 0.6, 0.8)
		card_ui.self_modulate = Color.WHITE
	
	if card_ui.has_signal("pressed"):
		card_ui.pressed.connect(_on_inventory_item_clicked.bind(id))

func _add_card_stack_to_grid(container: GridContainer, id: String, res: CardData, count: int, source: String):
	var stack_root = Control.new()
	stack_root.custom_minimum_size = Vector2(172, 246)
	stack_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(stack_root)
	
	var back_copies = mini(max(count - 1, 0), STACK_BACK_COPIES)
	for i in range(back_copies):
		var back_card = CardScene.instantiate()
		stack_root.add_child(back_card)
		_configure_card_ui(back_card, res)
		back_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back_card.modulate = Color(0.85, 0.85, 0.85, 0.55)
		back_card.position = Vector2((i + 1) * STACK_OFFSET_X, (i + 1) * STACK_OFFSET_Y)
	
	var front_card = CardScene.instantiate()
	stack_root.add_child(front_card)
	_configure_card_ui(front_card, res)
	front_card.position = Vector2.ZERO
	if source == "player":
		front_card.modulate = Color(0.72, 0.72, 0.72, 0.95)
	
	if front_card.has_signal("pressed"):
		front_card.pressed.connect(_on_deck_card_clicked.bind(id, source))
	
	if count > 1:
		var qty_label = Label.new()
		stack_root.add_child(qty_label)
		qty_label.text = "x%d" % count
		qty_label.position = Vector2(116, 4)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qty_label.theme_override_font_sizes.font_size = 16
		qty_label.theme_override_colors.font_color = Color(1.0, 0.95, 0.6, 1.0)
		qty_label.theme_override_colors.font_outline_color = Color(0, 0, 0, 1)
		qty_label.add_theme_constant_override("outline_size", 2)

func _on_deck_card_clicked(id: String, source: String):
	var min_required = GameManager.player_level
	
	if source == "active":
		if GameManager.active_deck.size() <= min_required:
			_show_info_toast("You must have at least %d card(s) in your deck." % min_required)
			return
		if _remove_one(GameManager.active_deck, id):
			GameManager.player_deck.append(id)
	else:
		if GameManager.active_deck.size() >= MAX_ACTIVE_DECK_CARDS:
			_show_info_toast("Active deck is full (%d cards)." % MAX_ACTIVE_DECK_CARDS)
			return
		if _remove_one(GameManager.player_deck, id):
			GameManager.active_deck.append(id)
	
	_populate_deck_tab()
	_update_counters()
	SaveManager.save_mid_run_state()

func _on_inventory_item_clicked(id: String):
	var max_slots = max(1, GameManager.player_level)
	
	if id in GameManager.active_items:
		GameManager.active_items.erase(id)
	else:
		if GameManager.active_items.size() >= max_slots:
			_show_info_toast("You may only have %d active items." % max_slots)
			return
		GameManager.active_items.append(id)
	
	_populate_inventory_tab()
	_update_counters()
	_update_stats_ui()
	SaveManager.save_mid_run_state()

func _update_counters():
	var active_deck_size = GameManager.active_deck.size()
	var min_cards = GameManager.player_level
	deck_count_label.text = "Active Deck: %d cards (min %d)" % [active_deck_size, min_cards]
	deck_count_label.modulate = Color.TOMATO if active_deck_size < min_cards else Color.WHITE
	
	var active_item_count = GameManager.active_items.size()
	var max_items = max(1, GameManager.player_level)
	item_count_label.text = "Active Items: %d / %d" % [active_item_count, max_items]
	item_count_label.modulate = Color.GOLD if active_item_count >= max_items else Color.WHITE

func _on_back_pressed():
	if GameManager.active_deck.size() < GameManager.player_level:
		_show_info_toast("You must have at least %d cards in your deck." % GameManager.player_level)
		return
	
	if GameManager.is_battle_mode:
		get_tree().change_scene_to_file("res://features/map/BattleMap.tscn")
	else:
		get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")

func _configure_card_ui(card_ui: Control, res: Resource):
	card_ui.custom_minimum_size = Vector2(156, 234)
	card_ui.scale = Vector2(0.96, 0.96)
	
	if res is CardData:
		card_ui.setup(res)
	elif res is ItemData and card_ui.has_method("setup_item"):
		card_ui.setup_item(res)
	
	card_ui.get_node("%BackFace").visible = false
	card_ui.get_node("%FrontFace").visible = true
	card_ui.is_face_up = true
	
	if card_ui.has_method("_on_pressed") and card_ui.has_signal("pressed") and card_ui.pressed.is_connected(card_ui._on_pressed):
		card_ui.pressed.disconnect(card_ui._on_pressed)

func _count_ids(ids: Array) -> Dictionary:
	var counts := {}
	for id in ids:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts

func _load_card(card_id: String) -> CardData:
	var path = CARDS_ROOT + card_id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as CardData

func _remove_one(target: Array, id: String) -> bool:
	var index := target.find(id)
	if index == -1:
		return false
	target.remove_at(index)
	return true

func _clear_children(node: Node):
	for child in node.get_children():
		child.queue_free()

func _hide_info_toast():
	info_toast_box.visible = false
	info_toast_box.modulate = Color(1, 1, 1, 0)
	info_toast_label.text = ""

func _show_info_toast(message: String):
	if _info_toast_tween:
		_info_toast_tween.kill()
	
	info_toast_label.text = message
	info_toast_box.visible = true
	info_toast_box.modulate = Color(1, 1, 1, 0)
	
	_info_toast_tween = create_tween()
	_info_toast_tween.tween_property(info_toast_box, "modulate:a", 1.0, 0.12)
	_info_toast_tween.tween_interval(1.0)
	_info_toast_tween.tween_property(info_toast_box, "modulate:a", 0.0, 0.45)
	_info_toast_tween.finished.connect(_hide_info_toast)
