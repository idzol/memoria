extends Control

# res://features/ui/CharacterLevelUp.gd
# Displays a numerical stat preview and recovered lore after a level up.

@onready var title_label = %TitleLabel
@onready var stat_summary_label = %StatSummaryLabel
@onready var stats_table = %StatsTable
@onready var lore_title = %LoreTitle
@onready var lore_body = %LoreBody
@onready var continue_button = %ContinueButton

func _ready():
	var data = GameManager.pending_level_up
	if data.is_empty():
		_show_fallback_data()
	else:
		_apply_level_up_data(data)
		var new_level = int(data.get("new_level", GameManager.player_level))
		GameManager.add_run_log(
			LocalizationManager.format(
				"log.level_up",
				{"name": GameManager.player_name if GameManager.player_name != "" else GameManager.player_class, "level": new_level},
				"{name} leveled up to {level}."
			)
		)

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
	_populate_stats_table([
		{
			"label": LocalizationManager.translate("levelup.hp", "HP"),
			"old": int(old_stats.get("max_hp", 0)),
			"new": int(new_stats.get("max_hp", 0))
		},
		{
			"label": LocalizationManager.translate("levelup.energy", "ENERGY"),
			"old": int(old_stats.get("energy", 0)),
			"new": int(new_stats.get("energy", 0))
		},
		{
			"label": LocalizationManager.translate("levelup.attack", "ATTACK"),
			"old": int(old_stats.get("player_attack", 0)),
			"new": int(new_stats.get("player_attack", 0))
		},
		{
			"label": LocalizationManager.translate("levelup.defense", "DEFENSE"),
			"old": int(old_stats.get("player_defense", 0)),
			"new": int(new_stats.get("player_defense", 0))
		},
		{
			"label": LocalizationManager.translate("levelup.pairs", "CARD PAIRS"),
			"old": previous_pairs,
			"new": required_pairs
		}
	])

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

func _populate_stats_table(rows: Array):
	if not stats_table:
		return
	for child in stats_table.get_children():
		child.queue_free()
	_add_stats_header_row()
	for row in rows:
		_add_stats_value_row(str(row.get("label", "")), int(row.get("old", 0)), int(row.get("new", 0)))

func _add_stats_header_row():
	_add_table_cell("", HORIZONTAL_ALIGNMENT_LEFT, true, false)
	_add_table_cell(LocalizationManager.translate("levelup.table.current", "CURRENT"), HORIZONTAL_ALIGNMENT_CENTER, true, true)
	_add_table_cell(LocalizationManager.translate("levelup.table.next", "NEXT"), HORIZONTAL_ALIGNMENT_CENTER, true, true)
	_add_table_cell(LocalizationManager.translate("levelup.table.change", "CHANGE"), HORIZONTAL_ALIGNMENT_RIGHT, true, true)

func _add_stats_value_row(label_text: String, old_value: int, new_value: int):
	_add_table_cell(label_text, HORIZONTAL_ALIGNMENT_LEFT, false, false)
	_add_table_cell(str(old_value), HORIZONTAL_ALIGNMENT_CENTER, false, false)
	_add_table_cell(str(new_value), HORIZONTAL_ALIGNMENT_CENTER, false, false)
	_add_table_cell(_format_delta(old_value, new_value), HORIZONTAL_ALIGNMENT_RIGHT, false, true)

func _add_table_cell(text: String, alignment: HorizontalAlignment, is_header: bool, emphasize: bool):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.y = 34 if is_header else 30
	label.add_theme_font_size_override("font_size", 18 if is_header else 20)
	if is_header:
		label.modulate = Color(0.76, 0.8, 0.9, 1.0)
	elif emphasize:
		label.modulate = Color(0.45, 0.95, 0.6, 1.0)
	stats_table.add_child(label)

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
	SceneTransition.change_scene_to_file(next_scene)
