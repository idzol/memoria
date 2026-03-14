extends Control

# res://features/ui/CharacterLevelUp.gd
# Displays a graphical stat preview and recovered lore after a level up.

@onready var title_label = %TitleLabel
@onready var stat_summary_label = %StatSummaryLabel
@onready var hp_label = %HPLabel
@onready var hp_bar_old = %HPBarOld
@onready var hp_bar_new = %HPBarNew
@onready var hp_delta = %HPDelta
@onready var energy_label = %EnergyLabel
@onready var energy_bar_old = %EnergyBarOld
@onready var energy_bar_new = %EnergyBarNew
@onready var energy_delta = %EnergyDelta
@onready var attack_label = %AttackLabel
@onready var attack_value = %AttackValue
@onready var attack_delta = %AttackDelta
@onready var defense_label = %DefenseLabel
@onready var defense_value = %DefenseValue
@onready var defense_delta = %DefenseDelta
@onready var pairs_label = %PairsLabel
@onready var pairs_value = %PairsValue
@onready var pairs_delta = %PairsDelta
@onready var lore_title = %LoreTitle
@onready var lore_body = %LoreBody
@onready var continue_button = %ContinueButton

func _ready():
	var data = GameManager.pending_level_up
	if data.is_empty():
		_show_fallback_data()
	else:
		_apply_level_up_data(data)

	continue_button.pressed.connect(_on_continue_pressed)

func _apply_level_up_data(data: Dictionary):
	var old_level = int(data.get("old_level", max(1, GameManager.player_level - 1)))
	var new_level = int(data.get("new_level", GameManager.player_level))
	var old_stats: Dictionary = data.get("old_stats", {})
	var new_stats: Dictionary = data.get("new_stats", {})
	var required_pairs = int(data.get("required_pairs", new_level))
	var previous_pairs = max(1, old_level)

	title_label.text = LocalizationManager.format(
		"levelup.title",
		{"class": GameManager.player_class.to_upper()},
		"{class} LEVELED UP!"
	)
	stat_summary_label.text = LocalizationManager.format(
		"levelup.level_summary",
		{"old": old_level, "new": new_level},
		"Level {old} -> Level {new}"
	)

	_apply_bar_row(
		hp_label,
		hp_bar_old,
		hp_bar_new,
		hp_delta,
		"levelup.hp",
		"HP",
		int(old_stats.get("max_hp", 0)),
		int(new_stats.get("max_hp", 0)),
		Color(0.84, 0.24, 0.24, 1.0),
		Color(1.0, 0.48, 0.48, 1.0)
	)
	_apply_bar_row(
		energy_label,
		energy_bar_old,
		energy_bar_new,
		energy_delta,
		"levelup.energy",
		"ENERGY",
		int(old_stats.get("energy", 0)),
		int(new_stats.get("energy", 0)),
		Color(0.92, 0.72, 0.18, 1.0),
		Color(1.0, 0.9, 0.38, 1.0)
	)

	attack_label.text = LocalizationManager.translate("levelup.attack", "ATTACK")
	_apply_value_row(
		attack_value,
		attack_delta,
		int(old_stats.get("player_attack", 0)),
		int(new_stats.get("player_attack", 0))
	)

	defense_label.text = LocalizationManager.translate("levelup.defense", "DEFENSE")
	_apply_value_row(
		defense_value,
		defense_delta,
		int(old_stats.get("player_defense", 0)),
		int(new_stats.get("player_defense", 0))
	)

	pairs_label.text = LocalizationManager.translate("levelup.pairs", "CARD PAIRS")
	_apply_value_row(pairs_value, pairs_delta, previous_pairs, required_pairs)

	lore_title.text = LocalizationManager.format(
		"levelup.lore_title",
		{"level": new_level},
		"Recovered Memory {level}"
	)
	var lore_key = "levelup.lore.%d" % new_level
	lore_body.text = LocalizationManager.translate(
		lore_key,
		LocalizationManager.translate(
			"levelup.lore.fallback",
			"As memories comes back, you regain your strength. You were more than a fisher, but you cannot place the name"
		)
	)
	continue_button.text = LocalizationManager.translate("levelup.continue", "CONTINUE")

func _show_fallback_data():
	var new_level = GameManager.player_level
	var old_level = max(1, new_level - 1)
	var old_stats = GameData.get_stats(_normalized_class_id(), old_level)
	var new_stats = GameData.get_stats(_normalized_class_id(), new_level)
	_apply_level_up_data({
		"old_level": old_level,
		"new_level": new_level,
		"old_stats": old_stats,
		"new_stats": new_stats,
		"required_pairs": new_level,
		"active_pairs": GameManager.active_deck.size()
	})

func _apply_bar_row(label_node: Label, old_bar: ProgressBar, new_bar: ProgressBar, delta_label: Label, key: String, fallback: String, old_value: int, new_value: int, old_color: Color, new_color: Color):
	label_node.text = LocalizationManager.translate(key, fallback)
	var max_value = max(old_value, new_value, 1)
	old_bar.max_value = max_value
	old_bar.value = old_value
	new_bar.max_value = max_value
	new_bar.value = new_value
	old_bar.modulate = old_color
	new_bar.modulate = new_color
	delta_label.text = _format_delta(old_value, new_value)

func _apply_value_row(value_label: Label, delta_label: Label, old_value: int, new_value: int):
	value_label.text = "%d -> %d" % [old_value, new_value]
	delta_label.text = _format_delta(old_value, new_value)

func _format_delta(old_value: int, new_value: int) -> String:
	var delta = new_value - old_value
	if delta > 0:
		return "+%d" % delta
	if delta < 0:
		return "%d" % delta
	return "0"

func _normalized_class_id() -> String:
	var raw = GameManager.player_class.to_lower()
	match raw:
		"archivist":
			return "scholar"
		"berserker":
			return "warrior"
		"illusionist":
			return "alchemist"
		_:
			return raw

func _on_continue_pressed():
	var next_scene = GameManager.level_up_return_scene
	GameManager.pending_level_up = {}
	GameManager.level_up_return_scene = ""
	if next_scene == "":
		next_scene = GameManager.get_active_biome_map_scene_path()
	get_tree().change_scene_to_file(next_scene)
