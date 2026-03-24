# [AI-CONTRACT]
# FILE: res://features/ui/CharacterSelect.gd
# FEATURES: Horizontal class tiles, keyboard selection, and live level-1 stat summary.

extends Control

@onready var description_label = %DescriptionLabel
@onready var warrior_btn = %WarriorBtn
@onready var scholar_btn = %ScholarBtn
@onready var alchemist_btn = %AlchemistBtn
@onready var warrior_tile = %WarriorTile
@onready var scholar_tile = %ScholarTile
@onready var alchemist_tile = %AlchemistTile
@onready var background_tex = %BackgroundTexture
@onready var confirm_btn = %ConfirmBtn
@onready var cancel_btn = %CancelBtn
@onready var hp_value_label = %HPValue
@onready var energy_icon_label = %EnergyIcon
@onready var energy_value_label = %EnergyValue
@onready var attack_value_label = %AttackValue
@onready var defense_value_label = %DefenseValue
@onready var warrior_label: Label = %WarriorLabel
@onready var scholar_label: Label = %ScholarLabel
@onready var alchemist_label: Label = %AlchemistLabel
@onready var stats_title_label: Label = %StatsTitle
@onready var hp_label: Label = %HPLabel
@onready var energy_label: Label = %EnergyLabel
@onready var attack_label: Label = %AttackLabel
@onready var defense_label: Label = %DefenseLabel

var selected_class: String = ""
var selected_index: int = 0

const CLASS_IDS := ["warrior", "scholar", "alchemist"]
const ENERGY_PIP_FULL = Color(1.0, 0.86, 0.35, 1.0)
const ENERGY_PIP_EMPTY = Color(0.46, 0.35, 0.08, 1.0)
const ICON_ENERGY = "\u26a1"

var tile_default_style: StyleBoxFlat
var tile_selected_style: StyleBoxFlat

func _ready():
	if AssetRegistry.CHARACTER_ASSETS.has("background"):
		background_tex.texture = load(AssetRegistry.CHARACTER_ASSETS.background)
		_fit_background_to_scene()

	_setup_confirm_button_style()
	_setup_tile_styles()
	_connect_signals()
	_refresh_localized_text()

	confirm_btn.disabled = false
	_select_index(0)

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_fit_background_to_scene()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_return_to_main_menu()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_select_index(posmod(selected_index - 1, CLASS_IDS.size()))
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_select_index(posmod(selected_index + 1, CLASS_IDS.size()))
		return
	if event.is_action_pressed("ui_accept"):
		_on_confirm_pressed()

func _setup_confirm_button_style():
	if not AssetRegistry.CHARACTER_ASSETS.has("confirm_button"):
		return
	var tex = load(AssetRegistry.CHARACTER_ASSETS.confirm_button)
	if not tex:
		return
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	confirm_btn.add_theme_stylebox_override("normal", sb)
	confirm_btn.add_theme_stylebox_override("hover", sb)
	confirm_btn.add_theme_stylebox_override("pressed", sb)
	confirm_btn.add_theme_stylebox_override("disabled", sb)
	confirm_btn.add_theme_stylebox_override("focus", sb)

func _fit_background_to_scene():
	if not background_tex or not background_tex.texture:
		return

	var scene_size := size
	if scene_size.x <= 0.0 or scene_size.y <= 0.0:
		return

	background_tex.stretch_mode = TextureRect.STRETCH_SCALE
	background_tex.position = Vector2.ZERO
	background_tex.size = scene_size

func _setup_tile_styles():
	tile_default_style = StyleBoxFlat.new()
	tile_default_style.bg_color = Color(0.08, 0.08, 0.1, 0.78)
	tile_default_style.border_width_left = 2
	tile_default_style.border_width_top = 2
	tile_default_style.border_width_right = 2
	tile_default_style.border_width_bottom = 2
	tile_default_style.border_color = Color(1, 1, 1, 0.14)
	tile_default_style.corner_radius_top_left = 12
	tile_default_style.corner_radius_top_right = 12
	tile_default_style.corner_radius_bottom_right = 12
	tile_default_style.corner_radius_bottom_left = 12

	tile_selected_style = StyleBoxFlat.new()
	tile_selected_style.bg_color = Color(0.14, 0.18, 0.14, 0.92)
	tile_selected_style.border_width_left = 3
	tile_selected_style.border_width_top = 3
	tile_selected_style.border_width_right = 3
	tile_selected_style.border_width_bottom = 3
	tile_selected_style.border_color = Color(0.34, 0.72, 0.45, 0.98)
	tile_selected_style.corner_radius_top_left = 12
	tile_selected_style.corner_radius_top_right = 12
	tile_selected_style.corner_radius_bottom_right = 12
	tile_selected_style.corner_radius_bottom_left = 12

func _connect_signals():
	warrior_btn.pressed.connect(_on_class_clicked.bind(0))
	scholar_btn.pressed.connect(_on_class_clicked.bind(1))
	alchemist_btn.pressed.connect(_on_class_clicked.bind(2))
	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_return_to_main_menu)

func _on_class_clicked(index: int):
	_select_index(index)

func _select_index(index: int):
	selected_index = clamp(index, 0, CLASS_IDS.size() - 1)
	selected_class = CLASS_IDS[selected_index]
	_update_tiles_and_icons()
	_update_stats_summary()

func _update_tiles_and_icons():
	var buttons = [warrior_btn, scholar_btn, alchemist_btn]
	var tiles = [warrior_tile, scholar_tile, alchemist_tile]

	for i in range(CLASS_IDS.size()):
		var class_id = CLASS_IDS[i]
		var is_selected = i == selected_index
		var btn: TextureButton = buttons[i]
		var tile: PanelContainer = tiles[i]

		btn.texture_normal = AssetRegistry.get_character_texture(class_id, is_selected)
		btn.modulate = Color(1, 1, 1, 1) if is_selected else Color(0.84, 0.84, 0.84, 1)
		tile.add_theme_stylebox_override("panel", tile_selected_style if is_selected else tile_default_style)

func _update_stats_summary():
	var stats = GameData.get_stats(selected_class, 1)
	if stats.is_empty():
		description_label.text = LocalizationManager.translate("character_select.no_stats", "No stats found for selected class.")
		hp_value_label.text = "0"
		energy_value_label.text = "0"
		attack_value_label.text = "0"
		defense_value_label.text = "0"
		energy_icon_label.text = ICON_ENERGY
		return

	var desc = _get_class_description(selected_class)
	var hp := int(stats.get("max_hp", 0))
	var energy := int(stats.get("energy", 0))
	var attack := int(stats.get("player_attack", 0))
	var defense := int(stats.get("player_defense", 0))

	description_label.text = desc
	hp_value_label.text = str(hp)
	energy_value_label.text = str(energy)
	attack_value_label.text = str(attack)
	defense_value_label.text = str(defense)
	energy_icon_label.text = ICON_ENERGY
	energy_icon_label.modulate = ENERGY_PIP_FULL if energy > 0 else ENERGY_PIP_EMPTY

func _on_confirm_pressed():
	if selected_class == "":
		return

	GameManager.show_loading(LocalizationManager.translate("character_select.loading", "Restoring your identity..."))
	await get_tree().process_frame
	await get_tree().process_frame

	GameManager.player_class = selected_class.capitalize()
	GameManager.player_level = 1

	var stats = GameData.get_stats(selected_class, 1)
	if not stats.is_empty():
		GameManager.max_hp = stats.max_hp
		GameManager.current_hp = GameManager.max_hp
		GameManager.base_energy = stats.energy
		GameManager.base_attack = stats.player_attack
		GameManager.base_defense = stats.player_defense
	else:
		push_error("Stats initialization failed for: " + selected_class)

	SignalBus.game_started.emit()

	# Starting a new character should not inherit the previous session's in-memory world.
	GameManager.run_map = {}
	GameManager.reset_world_state()
	GameManager.current_node = {}
	GameManager.pending_loot = []
	GameManager.run_loot = []
	GameManager.completed_nodes = []

	if GameManager.is_battle_mode:
		GameManager.start_battle_mode()
	else:
		GameManager.start_actual_run()

func _return_to_main_menu():
	get_tree().change_scene_to_file("res://features/ui/MainMenu.tscn")

func _refresh_localized_text():
	warrior_label.text = LocalizationManager.translate("character_select.class.warrior", "WARRIOR")
	scholar_label.text = LocalizationManager.translate("character_select.class.scholar", "SCHOLAR")
	alchemist_label.text = LocalizationManager.translate("character_select.class.alchemist", "ALCHEMIST")
	stats_title_label.text = LocalizationManager.translate("character_select.stats_title", "LEVEL 1 STATS")
	hp_label.text = LocalizationManager.translate("character_select.health", "HEALTH")
	energy_label.text = LocalizationManager.translate("character_select.energy", "ENERGY")
	attack_label.text = LocalizationManager.translate("character_select.attack", "ATTACK")
	defense_label.text = LocalizationManager.translate("character_select.defense", "DEFENSE")
	confirm_btn.text = LocalizationManager.translate("character_select.confirm", "RESTORE IDENTITY")
	cancel_btn.text = LocalizationManager.translate("menu.cancel", "CANCEL")

func _get_class_description(class_id: String) -> String:
	return LocalizationManager.translate(
		"character_select.desc.%s" % class_id,
		AssetRegistry.CHARACTER_ASSETS.get(class_id, {}).get("desc", "")
	)
