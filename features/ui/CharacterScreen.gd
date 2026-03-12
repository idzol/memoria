extends Control

const CardScene = preload("res://features/combat/Card.tscn")

@onready var right_panel: TabContainer = $"Margin/HBox/RightPanelWrap/RightPanel"
@onready var active_deck_grid = %ActiveDeckGrid
@onready var player_deck_grid = %PlayerDeckGrid
@onready var active_item_grid = %ActiveItemGrid
@onready var player_item_grid = %PlayerItemGrid
@onready var deck_count_label = %DeckCount
@onready var item_count_label = %ItemCount
@onready var class_label = %ClassName
@onready var level_label = %LevelLabel

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
@onready var inventory_info_toast_box = %InventoryInfoToastBox
@onready var inventory_info_toast_label = %InventoryInfoToastLabel

const CARDS_ROOT := "res://data/cards/"
const ITEMS_ROOT := "res://data/items/"

const MAX_ACTIVE_DECK_CARDS := 12
const STACK_OFFSET_X := 8.0
const STACK_OFFSET_Y := 5.0
const STACK_BACK_COPIES := 2
const HOVER_SCALE := Vector2(1.08, 1.08)
const PREVIEW_SCALE := Vector2(1.7, 1.7)
const PREVIEW_Z_INDEX := 200
const LONG_HOLD_SECONDS := 0.35

var _info_toast_tween: Tween
var _expanded_preview_card: Control
var _hold_timer: Timer
var _hold_card: Control
var _hold_payload: Dictionary = {}
var _consume_press_instance_id: int = -1

func _ready():
	_ensure_default_player_deck()
	
	active_deck_grid.add_theme_constant_override("h_separation", 8)
	player_deck_grid.add_theme_constant_override("h_separation", 8)
	active_item_grid.add_theme_constant_override("h_separation", 8)
	player_item_grid.add_theme_constant_override("h_separation", 8)
	
	_update_stats_ui()
	_populate_deck_tab()
	_populate_inventory_tab()
	_update_counters()
	_hide_info_toasts()
	_setup_hold_timer()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _setup_hold_timer():
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = LONG_HOLD_SECONDS
	add_child(_hold_timer)
	_hold_timer.timeout.connect(_on_hold_timeout)

func _ensure_default_player_deck():
	if GameManager.player_deck.is_empty() and GameManager.active_deck.is_empty():
		GameManager.player_deck = ["sword", "shield", "heart"]

func _update_stats_ui():
	var p_lvl = GameManager.player_level
	class_label.text = "%s" % GameManager.player_class
	level_label.text = "LVL %d" % p_lvl
	
	GameManager.recalculate_player_totals()
	var totals = GameManager.get_item_stat_bonuses()
	
	var total_max_hp = GameManager.player_hp_total
	hp_bar.max_value = total_max_hp
	hp_bar.value = GameManager.current_hp
	hp_text.text = "HP %d / %d" % [GameManager.current_hp, total_max_hp]
	
	var max_xp = GameData.get_max_xp_for_level(GameManager.player_level)
	xp_bar.max_value = max_xp
	xp_bar.value = GameManager.player_xp
	xp_text.text = "XP %d / %d" % [GameManager.player_xp, max_xp]
	
	var attack_bonus = int(totals.get("atk_bonus", 0))
	var defense_bonus = int(totals.get("def_bonus", 0))
	var energy_bonus = int(totals.get("energy_bonus", 0))
	var base_energy = int(GameManager.base_energy)
	var total_energy = base_energy + energy_bonus
	
	atk_label.text = "ATTACK: %d (%d+%d)" % [GameManager.player_attack_total, GameManager.player_attack, attack_bonus]
	def_label.text = "DEFENSE: %d (%d+%d)" % [GameManager.player_defense_total, GameManager.player_defense, defense_bonus]
	energy_label.text = "ENERGY: %d (%d+%d)" % [total_energy, base_energy, energy_bonus]
	gold_label.text = "GOLD: %d" % GameManager.gold

func _populate_deck_tab():
	_clear_children(active_deck_grid)
	_clear_children(player_deck_grid)
	
	var active_counts = _count_ids(GameManager.active_deck)
	var reserve_counts = _count_ids(GameManager.player_deck)
	
	for card_id in _sorted_keys(active_counts):
		var card_res = _load_card(card_id)
		if card_res:
			_add_stack_to_grid(active_deck_grid, card_id, card_res, active_counts[card_id], "deck", "active")
	
	for card_id in _sorted_keys(reserve_counts):
		var reserve_res = _load_card(card_id)
		if reserve_res:
			_add_stack_to_grid(player_deck_grid, card_id, reserve_res, reserve_counts[card_id], "deck", "player")

func _populate_inventory_tab():
	_clear_children(active_item_grid)
	_clear_children(player_item_grid)
	
	var active_counts = _count_ids(GameManager.active_items)
	var reserve_counts = _count_ids(GameManager.player_items)
	
	for item_id in _sorted_keys(active_counts):
		var item_res = _load_item(item_id)
		if item_res:
			_add_stack_to_grid(active_item_grid, item_id, item_res, active_counts[item_id], "item", "active")
	
	for item_id in _sorted_keys(reserve_counts):
		var reserve_item = _load_item(item_id)
		if reserve_item:
			_add_stack_to_grid(player_item_grid, item_id, reserve_item, reserve_counts[item_id], "item", "player")

func _add_stack_to_grid(container: GridContainer, id: String, res: Resource, count: int, mode: String, source: String):
	var stack_root = Control.new()
	stack_root.custom_minimum_size = Vector2(160, 246)
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
	
	_connect_card_interactions(front_card, id, mode, source, res)
	
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

func _connect_card_interactions(card_ui: Control, id: String, mode: String, source: String, res: Resource):
	card_ui.set_meta("card_id", id)
	card_ui.set_meta("card_mode", mode)
	card_ui.set_meta("card_source", source)
	card_ui.set_meta("card_data", res)
	
	card_ui.resized.connect(_sync_card_pivot.bind(card_ui))
	_sync_card_pivot(card_ui)
	card_ui.mouse_entered.connect(_on_card_hover.bind(card_ui, true))
	card_ui.mouse_exited.connect(_on_card_hover.bind(card_ui, false))
	card_ui.mouse_exited.connect(_on_card_mouse_exited.bind(card_ui))
	card_ui.button_down.connect(_on_card_button_down.bind(card_ui, id, mode, source, res))
	card_ui.button_up.connect(_on_card_button_up.bind(card_ui))
	card_ui.gui_input.connect(_on_card_gui_input.bind(card_ui, id, mode, source, res))
	card_ui.pressed.connect(_on_collection_card_pressed.bind(card_ui, id, mode, source, res))

func _on_collection_card_pressed(card_ui: Control, id: String, mode: String, source: String, res: Resource):
	if _consume_press_instance_id == card_ui.get_instance_id():
		_consume_press_instance_id = -1
		return
	
	_hide_card_preview()
	_cancel_hold()
	
	if not _can_transfer(mode, source, true):
		return
	
	# Requested behavior: when deck is at minimum and action is blocked, no transition plays.
	# Keep transfer animations only for valid moves.
	_animate_card_transfer(card_ui, func():
		_apply_transfer(mode, source, id)
		_refresh_after_transfer(mode)
	)

func _can_transfer(mode: String, source: String, show_feedback: bool) -> bool:
	if mode == "deck":
		var min_required = GameManager.player_level
		if source == "active":
			if GameManager.active_deck.size() <= min_required:
				if show_feedback:
					_show_info_toast("You must have at least %d card(s) in your deck." % min_required)
				return false
		else:
			if GameManager.active_deck.size() >= MAX_ACTIVE_DECK_CARDS:
				if show_feedback:
					_show_info_toast("Active deck is full (%d cards)." % MAX_ACTIVE_DECK_CARDS)
				return false
	elif mode == "item":
		var max_slots = max(1, GameManager.player_level)
		if source == "player" and GameManager.active_items.size() >= max_slots:
			if show_feedback:
				_show_info_toast("You may only have %d active items." % max_slots)
			return false
	return true

func _apply_transfer(mode: String, source: String, id: String):
	if mode == "deck":
		if source == "active":
			if _remove_one(GameManager.active_deck, id):
				GameManager.player_deck.append(id)
		else:
			if _remove_one(GameManager.player_deck, id):
				GameManager.active_deck.append(id)
	else:
		if source == "active":
			if _remove_one(GameManager.active_items, id):
				GameManager.player_items.append(id)
		else:
			if _remove_one(GameManager.player_items, id):
				GameManager.active_items.append(id)

func _refresh_after_transfer(mode: String):
	if mode == "deck":
		_populate_deck_tab()
		_animate_grid_entry([active_deck_grid, player_deck_grid])
	else:
		_populate_inventory_tab()
		_animate_grid_entry([active_item_grid, player_item_grid])
		_update_stats_ui()
	
	_update_counters()
	SaveManager.save_mid_run_state()

func _update_counters():
	var active_deck_size = GameManager.active_deck.size()
	var min_cards = GameManager.player_level
	deck_count_label.text = "cards: %d | %d" % [active_deck_size, min_cards]
	if active_deck_size > min_cards:
		deck_count_label.modulate = Color.GOLD
	elif active_deck_size == min_cards:
		deck_count_label.modulate = Color.WHITE
	else:
		deck_count_label.modulate = Color.TOMATO
	
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
	
	if card_ui.has_method("_on_pressed") and card_ui.pressed.is_connected(card_ui._on_pressed):
		card_ui.pressed.disconnect(card_ui._on_pressed)

func _count_ids(ids: Array) -> Dictionary:
	var counts := {}
	for id in ids:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts

func _sorted_keys(dict: Dictionary) -> Array:
	var keys = dict.keys()
	keys.sort()
	return keys

func _load_card(card_id: String) -> CardData:
	var path = CARDS_ROOT + card_id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as CardData

func _load_item(item_id: String) -> ItemData:
	var path = ITEMS_ROOT + item_id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as ItemData

func _remove_one(target: Array, id: String) -> bool:
	var index := target.find(id)
	if index == -1:
		return false
	target.remove_at(index)
	return true

func _clear_children(node: Node):
	for child in node.get_children():
		child.queue_free()

func _sync_card_pivot(card_ui: Control):
	card_ui.pivot_offset = card_ui.size / 2.0

func _on_card_hover(card_ui: Control, is_hovering: bool):
	if _expanded_preview_card != null:
		return
	var target_scale = HOVER_SCALE if is_hovering else Vector2.ONE
	var tween: Tween = null
	if card_ui.has_meta("hover_tween"):
		tween = card_ui.get_meta("hover_tween") as Tween
	if tween:
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "scale", target_scale, 0.12)
	card_ui.set_meta("hover_tween", tween)

func _show_card_preview(res: Resource):
	_hide_card_preview()
	
	_expanded_preview_card = CardScene.instantiate()
	add_child(_expanded_preview_card)
	_configure_card_ui(_expanded_preview_card, res)
	_expanded_preview_card.scale = PREVIEW_SCALE
	_expanded_preview_card.z_index = PREVIEW_Z_INDEX
	_expanded_preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_sync_card_pivot(_expanded_preview_card)
	var center = get_viewport_rect().size * 0.5
	_expanded_preview_card.global_position = center - (_expanded_preview_card.size * PREVIEW_SCALE * 0.5)
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_expanded_preview_card.modulate = Color(1, 1, 1, 0)
	tween.tween_property(_expanded_preview_card, "modulate:a", 1.0, 0.12)

func _hide_card_preview():
	if _expanded_preview_card:
		_expanded_preview_card.queue_free()
	_expanded_preview_card = null

func _input(event: InputEvent):
	if _expanded_preview_card == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rect = Rect2(_expanded_preview_card.global_position, _expanded_preview_card.size * _expanded_preview_card.scale)
		if not rect.has_point(event.position):
			_hide_card_preview()
			accept_event()

func _on_card_button_down(card_ui: Control, id: String, mode: String, source: String, res: Resource):
	_hold_card = card_ui
	_hold_payload = {
		"id": id,
		"mode": mode,
		"source": source,
		"res": res
	}
	if _hold_timer:
		_hold_timer.start()

func _on_card_button_up(_card_ui: Control):
	if _hold_timer and not _hold_timer.is_stopped():
		_hold_timer.stop()

func _on_card_mouse_exited(card_ui: Control):
	if _hold_card == card_ui:
		_cancel_hold()

func _on_card_gui_input(event: InputEvent, _card_ui: Control, _id: String, _mode: String, _source: String, res: Resource):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_card_preview(res)
		_cancel_hold()
		accept_event()

func _on_hold_timeout():
	if _hold_card == null or not is_instance_valid(_hold_card):
		return
	var res = _hold_payload.get("res", null)
	if res == null:
		return
	_show_card_preview(res)
	_consume_press_instance_id = _hold_card.get_instance_id()

func _cancel_hold():
	if _hold_timer and not _hold_timer.is_stopped():
		_hold_timer.stop()
	_hold_card = null
	_hold_payload.clear()

func _animate_card_transfer(card_ui: Control, on_finished: Callable):
	if not is_instance_valid(card_ui):
		on_finished.call()
		return
	
	var button := card_ui as BaseButton
	if button:
		button.disabled = true
	
	card_ui.z_index = PREVIEW_Z_INDEX - 1
	_sync_card_pivot(card_ui)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(card_ui, "scale:x", 0.02, 0.14)
	tween.parallel().tween_property(card_ui, "modulate:a", 0.0, 0.14)
	tween.finished.connect(func():
		on_finished.call()
	)

func _animate_grid_entry(grids: Array):
	for grid in grids:
		if grid == null:
			continue
		for child in grid.get_children():
			if child is Control:
				var ctrl := child as Control
				ctrl.modulate = Color(1, 1, 1, 0)
				var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(ctrl, "modulate:a", 1.0, 0.14)

func _hide_info_toasts():
	info_toast_box.visible = false
	info_toast_box.modulate = Color(1, 1, 1, 0)
	info_toast_label.text = ""
	inventory_info_toast_box.visible = false
	inventory_info_toast_box.modulate = Color(1, 1, 1, 0)
	inventory_info_toast_label.text = ""

func _show_info_toast(message: String):
	if _info_toast_tween:
		_info_toast_tween.kill()
	
	var show_deck_toast = true
	if right_panel != null:
		show_deck_toast = right_panel.current_tab == 0
	var toast_box = info_toast_box if show_deck_toast else inventory_info_toast_box
	var toast_label = info_toast_label if show_deck_toast else inventory_info_toast_label
	
	toast_label.text = message
	toast_box.visible = true
	toast_box.modulate = Color(1, 1, 1, 0)
	
	_info_toast_tween = create_tween()
	_info_toast_tween.tween_property(toast_box, "modulate:a", 1.0, 0.12)
	_info_toast_tween.tween_interval(1.0)
	_info_toast_tween.tween_property(toast_box, "modulate:a", 0.0, 0.45)
	_info_toast_tween.finished.connect(_hide_info_toasts)
