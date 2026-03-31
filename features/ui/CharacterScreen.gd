extends Control

const CardScene = preload("res://features/combat/Card.tscn")

@onready var right_panel: TabContainer = %RightPanel
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
@onready var vitality_label: Label = $Margin/HBox/LeftPanel/Stats/VitalitySection/BarLabel
@onready var memory_progress_label: Label = $Margin/HBox/LeftPanel/Stats/MemorySection/BarLabel

@onready var atk_label = %AtkLabel
@onready var def_label = %DefLabel
@onready var energy_label = %EnergyLabel
@onready var gold_label = %GoldLabel
@onready var back_button = %BackButton
@onready var active_deck_title: Label = $Margin/HBox/RightPanel/DECK/Header/TitlePadding/Title
@onready var player_deck_title: Label = $Margin/HBox/RightPanel/DECK/Scroll/DeckSections/PlayerDeckLabelPadding/PlayerDeckLabel
@onready var active_items_title: Label = $Margin/HBox/RightPanel/INVENTORY/Header/InventoryTitlePadding/Title
@onready var player_items_title: Label = $Margin/HBox/RightPanel/INVENTORY/Scroll/ItemSections/PlayerItemsLabelPadding/PlayerItemsLabel
@onready var info_toast_box = %InfoToastBox
@onready var info_toast_label = %InfoToastLabel
@onready var inventory_info_toast_box = %InventoryInfoToastBox
@onready var inventory_info_toast_label = %InventoryInfoToastLabel
@onready var tutorial_toast_box = %TutorialToastBox
@onready var tutorial_toast_label = %TutorialToastLabel

const CARDS_ROOT := "res://data/cards/"
const ITEMS_ROOT := "res://data/items/"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "gameplay"
const TUTORIAL_TIPS_KEY := "tutorial_tips"
const TUTORIAL_FLAGS_SECTION := "tutorial_flags"
const CHARACTER_SCREEN_TUTORIAL_ID := "character_screen_intro"
const CHARACTER_SCREEN_FIRST_ITEM_TUTORIAL_ID := "character_screen_first_item_intro"
const CHARACTER_SCREEN_ITEM_SCREEN_TUTORIAL_ID := "character_screen_item_screen_intro"
const TUTORIAL_TOAST_DURATION := 10.0
const TUTORIAL_TOAST_COLOR := Color(0.4, 0.7, 1.0, 1.0)

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
var _tutorial_active: bool = false
var _tutorial_id: String = ""
var _tutorial_overlay: Control = null
var _tutorial_message_label: Label = null
var _tutorial_hint_label: Label = null

func _ready():
	_ensure_tutorial_overlay()
	# Testing purposes if loaded directly
	_ensure_default_player_deck()
	_ensure_default_inventory_deck()

	active_deck_grid.add_theme_constant_override("h_separation", 8)
	player_deck_grid.add_theme_constant_override("h_separation", 8)
	active_item_grid.add_theme_constant_override("h_separation", 8)
	player_item_grid.add_theme_constant_override("h_separation", 8)
	
	_refresh_static_labels()
	_update_stats_ui()
	_populate_deck_tab()
	_populate_inventory_tab()
	_update_counters()
	_hide_info_toasts()
	_setup_hold_timer()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if right_panel:
		right_panel.tab_changed.connect(_on_tab_changed)
	_begin_character_tutorial_if_needed.call_deferred()

func _notification(_what):
	pass

func _setup_hold_timer():
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = LONG_HOLD_SECONDS
	add_child(_hold_timer)
	_hold_timer.timeout.connect(_on_hold_timeout)

func _ensure_default_player_deck():
	if GameManager.player_deck.is_empty() and GameManager.active_deck.is_empty():
		GameManager.active_deck = ["sword", "shield", "heart"]
		GameManager.player_deck = ["sword", "shield", "heart", "heart"]

func _ensure_default_inventory_deck():
	if GameManager.player_items.is_empty() and GameManager.active_items.is_empty():
		GameManager.active_items = ["iron_scrap"]
		GameManager.player_items = ["wood_splinter", "mug_of_ale", "iron_scrap", "iron_scrap"]

func _update_stats_ui():
	var p_lvl = GameManager.player_level
	class_label.text = "%s" % GameManager.player_class
	level_label.text = LocalizationManager.format("character.level", {"level": p_lvl}, "LVL {level}")
	
	GameManager.recalculate_player_totals()
	var totals = GameManager.get_item_stat_bonuses()
	
	var total_max_hp = GameManager.player_hp_total
	hp_bar.max_value = total_max_hp
	hp_bar.value = GameManager.current_hp
	hp_text.text = LocalizationManager.format(
		"character.health",
		{"current": GameManager.current_hp, "max": total_max_hp},
		"HEALTH {current} / {max}"
	)
	
	var max_xp = GameData.get_max_xp_for_level(GameManager.player_level)
	xp_bar.max_value = max_xp
	xp_bar.value = GameManager.player_xp
	xp_text.text = LocalizationManager.format(
		"character.memory",
		{"current": GameManager.player_xp, "max": max_xp},
		"MEMORY {current} / {max}"
	)
	
	var attack_bonus = int(totals.get("atk_bonus", 0))
	var defense_bonus = int(totals.get("def_bonus", 0))
	var energy_bonus = int(totals.get("energy_bonus", 0))
	var base_energy = int(GameManager.base_energy)
	var total_energy = base_energy + energy_bonus
	
	atk_label.text = LocalizationManager.format(
		"character.attack",
		{"total": GameManager.player_attack_total, "base": GameManager.player_attack, "bonus": attack_bonus},
		"ATTACK: {total} ({base}+{bonus})"
	)
	def_label.text = LocalizationManager.format(
		"character.defense",
		{"total": GameManager.player_defense_total, "base": GameManager.player_defense, "bonus": defense_bonus},
		"DEFENSE: {total} ({base}+{bonus})"
	)
	energy_label.text = LocalizationManager.format(
		"character.energy",
		{"total": total_energy, "base": base_energy, "bonus": energy_bonus},
		"ENERGY: {total} ({base}+{bonus})"
	)
	gold_label.text = LocalizationManager.format("character.gold", {"gold": GameManager.gold}, "GOLD: {gold}")

func _populate_deck_tab():
	_clear_children(active_deck_grid)
	_clear_children(player_deck_grid)
	
	var active_counts = _count_ids(GameManager.active_deck)
	var reserve_counts = _get_reserve_deck_counts()
	
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
	var reserve_counts = _get_reserve_item_counts()
	
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
		_simplify_stack_back_card(back_card)
		back_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back_card.modulate = Color(0.85, 0.85, 0.85, 0.55)
		back_card.position = Vector2((i + 1) * STACK_OFFSET_X, (i + 1) * STACK_OFFSET_Y)
	
	var front_card = CardScene.instantiate()
	stack_root.add_child(front_card)
	_configure_card_ui(front_card, res)
	front_card.position = Vector2.ZERO
	front_card.modulate = Color.WHITE
	
	_connect_card_interactions(front_card, id, mode, source, res)
	
	if count > 1:
		var qty_label = Label.new()
		stack_root.add_child(qty_label)
		qty_label.text = "x%d" % count
		qty_label.position = Vector2(128, -6)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qty_label.add_theme_font_size_override("font_size", 16)
		qty_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))
		qty_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
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

func _on_collection_card_pressed(card_ui: Control, id: String, mode: String, source: String, _res: Resource):
	if _consume_press_instance_id == card_ui.get_instance_id():
		_consume_press_instance_id = -1
		return
	
	_hide_card_preview()
	_cancel_hold()
	
	if not _can_transfer(mode, source, id, true):
		return
	
	# Requested behavior: when deck is at minimum and action is blocked, no transition plays.
	# Keep transfer animations only for valid moves.
	_animate_card_transfer(card_ui, func():
		_apply_transfer(mode, source, id)
		_refresh_after_transfer(mode)
	)

func _can_transfer(mode: String, source: String, id: String, show_feedback: bool) -> bool:
	if not _can_modify_loadout_here():
		if show_feedback:
			_show_info_toast(LocalizationManager.translate(
				"character.toast.home_only_changes",
				"You must be safe at home to make these changes."
			))
		return false
	if mode == "deck":
		var min_required = GameManager.player_level
		if source == "active":
			var next_active_deck = GameManager.active_deck.duplicate()
			_remove_one(next_active_deck, id)
			if _count_unique_cards(next_active_deck) < min_required:
				if show_feedback:
					_show_info_toast(LocalizationManager.format(
						"character.toast.min_deck_cards",
						{"count": min_required},
						"You must have at least {count} unique card(s) in your active deck."
					))
				return false
		else:
			var reserve_counts = _get_reserve_deck_counts()
			if int(reserve_counts.get(id, 0)) <= 0:
				if show_feedback:
					_show_info_toast(LocalizationManager.translate(
						"character.toast.no_card_copy",
						"No unallocated copy of that card is available."
					))
				return false
			if GameManager.active_deck.size() >= MAX_ACTIVE_DECK_CARDS:
				if show_feedback:
					_show_info_toast(LocalizationManager.format(
						"character.toast.deck_full",
						{"count": MAX_ACTIVE_DECK_CARDS},
						"Active deck is full ({count} cards)."
					))
				return false
	elif mode == "item":
		var max_slots = max(1, GameManager.player_level)
		if source == "player":
			var reserve_counts = _get_reserve_item_counts()
			if int(reserve_counts.get(id, 0)) <= 0:
				if show_feedback:
					_show_info_toast(LocalizationManager.translate(
						"character.toast.no_item_copy",
						"No unallocated copy of that item is available."
					))
				return false
			if GameManager.active_items.size() >= max_slots:
				if show_feedback:
					_show_info_toast(LocalizationManager.format(
						"character.toast.max_active_items",
						{"count": max_slots},
						"You may only have {count} active items."
					))
				return false
	return true

func _can_modify_loadout_here() -> bool:
	var current_node = GameManager.current_node
	if current_node.is_empty():
		return false
	return bool(current_node.get("is_home", false)) or str(current_node.get("type", "")) == "home"

func _apply_transfer(mode: String, source: String, id: String):
	if mode == "deck":
		if source == "active":
			_remove_one(GameManager.active_deck, id)
		else:
			if _get_available_owned_card_count(id) > 0:
				GameManager.active_deck.append(id)
	else:
		if source == "active":
			_remove_one(GameManager.active_items, id)
		else:
			if _get_available_owned_item_count(id) > 0:
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
	var active_pair_count = _count_unique_cards(GameManager.active_deck)
	var min_cards = GameManager.player_level
	deck_count_label.text = LocalizationManager.format(
		"character.pairs",
		{"current": active_pair_count, "required": min_cards},
		"Unique Cards: {current} / {required}"
	)
	if active_pair_count > min_cards:
		deck_count_label.modulate = Color.GOLD
	elif active_pair_count == min_cards:
		deck_count_label.modulate = Color.WHITE
	else:
		deck_count_label.modulate = Color.TOMATO
	
	var active_item_count = GameManager.active_items.size()
	var max_items = max(1, GameManager.player_level)
	item_count_label.text = LocalizationManager.format(
		"character.equipped",
		{"current": active_item_count, "max": max_items},
		"Equipped: {current} / {max}"
	)
	item_count_label.modulate = Color.GOLD if active_item_count >= max_items else Color.WHITE

func _on_back_pressed():
	if _count_unique_cards(GameManager.active_deck) < GameManager.player_level:
		_show_info_toast(LocalizationManager.format(
			"character.toast.min_deck_exit",
			{"count": GameManager.player_level},
			"You must have at least {count} unique cards in your active deck."
		))
		return
	
	if GameManager.is_battle_mode:
		var next_scene = GameManager.profile_return_scene if GameManager.profile_return_scene != "" else GameManager.get_active_biome_map_scene_path()
		GameManager.profile_return_scene = ""
		get_tree().change_scene_to_file(next_scene)
	else:
		var next_scene = GameManager.profile_return_scene if GameManager.profile_return_scene != "" else GameManager.get_story_line_scene_path()
		GameManager.profile_return_scene = ""
		get_tree().change_scene_to_file(next_scene)

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

func _simplify_stack_back_card(card_ui: Control):
	var card_image = card_ui.get_node_or_null("%CardImage")
	if card_image:
		card_image.visible = false
	var center_type_icon = card_ui.get_node_or_null("%CenterTypeIcon")
	if center_type_icon:
		center_type_icon.visible = false
	var text_overlay = card_ui.get_node_or_null("FrontFace/TextOverlay")
	if text_overlay:
		text_overlay.visible = false

func _count_ids(ids: Array) -> Dictionary:
	var counts := {}
	for id in ids:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts

func _count_unique_pairs(ids: Array) -> int:
	var counts = _count_ids(ids)
	var total_pairs := 0
	for count in counts.values():
		if int(count) >= 2:
			total_pairs += 1
	return total_pairs

func _count_unique_cards(ids: Array) -> int:
	return _count_ids(ids).size()

func _get_reserve_deck_counts() -> Dictionary:
	var owned_counts = _count_ids(GameManager.player_deck)
	var active_counts = _count_ids(GameManager.active_deck)
	var reserve_counts := {}
	for card_id in owned_counts.keys():
		var available = int(owned_counts.get(card_id, 0)) - int(active_counts.get(card_id, 0))
		if available > 0:
			reserve_counts[card_id] = available
	return reserve_counts

func _get_available_owned_card_count(card_id: String) -> int:
	var reserve_counts = _get_reserve_deck_counts()
	return int(reserve_counts.get(card_id, 0))

func _get_reserve_item_counts() -> Dictionary:
	var owned_counts = _count_ids(GameManager.player_items)
	var active_counts = _count_ids(GameManager.active_items)
	var reserve_counts := {}
	for item_id in owned_counts.keys():
		var available = int(owned_counts.get(item_id, 0)) - int(active_counts.get(item_id, 0))
		if available > 0:
			reserve_counts[item_id] = available
	return reserve_counts

func _get_available_owned_item_count(item_id: String) -> int:
	var reserve_counts = _get_reserve_item_counts()
	return int(reserve_counts.get(item_id, 0))

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
	if _tutorial_active:
		if _is_tutorial_dismiss_input(event):
			_dismiss_character_tutorial()
			accept_event()
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		return
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
	if tutorial_toast_box:
		tutorial_toast_box.visible = false
		tutorial_toast_box.modulate = Color(1, 1, 1, 0)
	if tutorial_toast_label:
		tutorial_toast_label.text = ""

func _ensure_tutorial_overlay():
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		return
	_tutorial_overlay = Control.new()
	_tutorial_overlay.name = "TutorialOverlay"
	_tutorial_overlay.visible = false
	_tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_tutorial_overlay)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.03, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_overlay.add_child(shade)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.1, 0.97)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.7, 1.0, 0.8)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_tutorial_message_label = Label.new()
	_tutorial_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_message_label.add_theme_font_size_override("font_size", 30)
	_tutorial_message_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	vbox.add_child(_tutorial_message_label)

	_tutorial_hint_label = Label.new()
	_tutorial_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_hint_label.add_theme_font_size_override("font_size", 18)
	_tutorial_hint_label.add_theme_color_override("font_color", TUTORIAL_TOAST_COLOR)
	_tutorial_hint_label.text = LocalizationManager.translate("tutorial.continue_any_input", "Click or press any key to continue")
	vbox.add_child(_tutorial_hint_label)

func _is_tutorial_dismiss_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and not event.is_echo()
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return abs(event.axis_value) >= 0.2
	return false

func _show_info_toast(message: String):
	_show_info_toast_with_style(message, 1.0, Color(1, 1, 1, 1.0))

func _show_info_toast_with_style(message: String, duration: float, font_color: Color):
	if _info_toast_tween:
		_info_toast_tween.kill()
		_hide_info_toasts()

	var is_tutorial_toast = font_color == TUTORIAL_TOAST_COLOR and tutorial_toast_box and tutorial_toast_label
	if is_tutorial_toast:
		tutorial_toast_label.text = message
		tutorial_toast_label.add_theme_color_override("font_color", font_color)
		tutorial_toast_box.visible = true
		tutorial_toast_box.modulate = Color(1, 1, 1, 0)
		_info_toast_tween = create_tween()
		_info_toast_tween.tween_property(tutorial_toast_box, "modulate:a", 1.0, 0.12)
		_info_toast_tween.tween_interval(duration)
		_info_toast_tween.tween_property(tutorial_toast_box, "modulate:a", 0.0, 0.45)
		_info_toast_tween.finished.connect(_hide_info_toasts)
		return

	var show_deck_toast = true
	if right_panel != null:
		show_deck_toast = right_panel.current_tab == 0
	var toast_box = info_toast_box if show_deck_toast else inventory_info_toast_box
	var toast_label = info_toast_label if show_deck_toast else inventory_info_toast_label
	
	toast_label.text = message
	toast_label.add_theme_color_override("font_color", font_color)
	toast_box.visible = true
	toast_box.modulate = Color(1, 1, 1, 0)
	
	_info_toast_tween = create_tween()
	_info_toast_tween.tween_property(toast_box, "modulate:a", 1.0, 0.12)
	_info_toast_tween.tween_interval(duration)
	_info_toast_tween.tween_property(toast_box, "modulate:a", 0.0, 0.45)
	_info_toast_tween.finished.connect(_hide_info_toasts)

func _refresh_static_labels():
	right_panel.set_tab_title(0, LocalizationManager.translate("character.tab.deck", "DECK"))
	right_panel.set_tab_title(1, LocalizationManager.translate("character.tab.inventory", "INVENTORY"))
	vitality_label.text = LocalizationManager.translate("character.vitality", "VITALITY")
	memory_progress_label.text = LocalizationManager.translate("character.memory_progress", "MEMORY PROGRESS")
	active_deck_title.text = LocalizationManager.translate("character.active_deck", "ACTIVE DECK")
	player_deck_title.text = LocalizationManager.translate("character.player_deck", "PLAYER DECK")
	active_items_title.text = LocalizationManager.translate("character.active_items", "ACTIVE ITEMS")
	player_items_title.text = LocalizationManager.translate("character.player_items", "PLAYER ITEMS")
	back_button.text = LocalizationManager.translate("character.back_to_map", "RETURN TO MAP")

func _begin_character_tutorial_if_needed():
	if _tutorial_active or not _are_tutorial_tips_enabled():
		return
	if not _has_seen_tutorial(CHARACTER_SCREEN_TUTORIAL_ID):
		_show_character_tutorial(
			CHARACTER_SCREEN_TUTORIAL_ID,
			LocalizationManager.translate(
				"character.tutorial.memory_cards",
				"Memory cards are how you interact with the world. You need at a minimum number (1) of unique cards"
			)
		)
		return
	if GameManager.world_state.items.owned.size() > 0 and not _has_seen_tutorial(CHARACTER_SCREEN_FIRST_ITEM_TUTORIAL_ID):
		_show_character_tutorial(
			CHARACTER_SCREEN_FIRST_ITEM_TUTORIAL_ID,
			LocalizationManager.translate(
				"character.tutorial.first_item_intro",
				"Select items, to manage your equipment"
			)
		)
		return
	if GameManager.world_state.items.owned.size() > 0 and right_panel and right_panel.current_tab == 1 and not _has_seen_tutorial(CHARACTER_SCREEN_ITEM_SCREEN_TUTORIAL_ID):
		_show_character_tutorial(
			CHARACTER_SCREEN_ITEM_SCREEN_TUTORIAL_ID,
			LocalizationManager.translate(
				"character.tutorial.item_screen",
				"You can equip a maximum number of items (3) for the quest"
			)
		)

func _dismiss_character_tutorial():
	_tutorial_active = false
	if _tutorial_overlay:
		_tutorial_overlay.visible = false
	if _tutorial_id != "":
		_set_tutorial_seen(_tutorial_id)
	_tutorial_id = ""
	_begin_character_tutorial_if_needed.call_deferred()

func _are_tutorial_tips_enabled() -> bool:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return true
	return bool(config.get_value(SETTINGS_SECTION, TUTORIAL_TIPS_KEY, true))

func _has_seen_tutorial(tutorial_id: String) -> bool:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return bool(config.get_value(TUTORIAL_FLAGS_SECTION, tutorial_id, false))

func _set_tutorial_seen(tutorial_id: String):
	if tutorial_id == "":
		return
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(TUTORIAL_FLAGS_SECTION, tutorial_id, true)
	config.save(SETTINGS_PATH)

func _show_character_tutorial(tutorial_id: String, message: String):
	_tutorial_id = tutorial_id
	_tutorial_active = true
	if _tutorial_message_label:
		_tutorial_message_label.text = message
	if _tutorial_hint_label:
		_tutorial_hint_label.text = LocalizationManager.translate("tutorial.continue_any_input", "Click or press any key to continue")
	if _tutorial_overlay:
		_tutorial_overlay.visible = true
		_tutorial_overlay.move_to_front()

func _on_tab_changed(_tab: int):
	_begin_character_tutorial_if_needed()
