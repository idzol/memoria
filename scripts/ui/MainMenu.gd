extends Control

# res://scripts/ui/MainMenu.gd

@onready var continue_button = %ContinueButton
@onready var name_entry_popup = %NameEntryPopup
@onready var save_list_popup = %SaveListPopup
@onready var save_container = %SaveListVBox
@onready var name_input = %NameInput

func _ready():
	_refresh_continue_button()
	
	# Connect signals using Unique Names (%)
	%StartButton.pressed.connect(_on_new_game_clicked)
	%ConfirmNameBtn.pressed.connect(_on_name_confirmed)
	%CancelNameBtn.pressed.connect(func(): name_entry_popup.visible = false)
	%CloseSavesBtn.pressed.connect(func(): save_list_popup.visible = false)
	%SettingsButton.pressed.connect(_on_settings_pressed)
	%ExitButton.pressed.connect(_on_exit_pressed)
	
	# Hide overlays by default
	name_entry_popup.visible = false
	save_list_popup.visible = false
	if has_node("%SettingsOverlay"):
		%SettingsOverlay.visible = false

func _refresh_continue_button():
	var saves = SaveManager.get_save_list()
	if saves.is_empty():
		continue_button.disabled = true
		continue_button.modulate.a = 0.5
		continue_button.text = "NO SAVES FOUND"
	else:
		continue_button.disabled = false
		continue_button.modulate.a = 1.0
		continue_button.text = "CONTINUE RUN"
		if not continue_button.pressed.is_connected(_on_continue_clicked):
			continue_button.pressed.connect(_on_continue_clicked)

func _on_new_game_clicked():
	name_entry_popup.visible = true
	name_input.text = ""
	name_input.placeholder_text = "Enter unique name..."
	name_input.grab_focus()

func _on_name_confirmed():
	var p_name = name_input.text.strip_edges()
	
	# Requirement 1: Minimum length
	if p_name.length() < 2:
		return
		
	# Requirement 2: Unique Name Validation
	var existing_saves = SaveManager.get_save_list()
	for save in existing_saves:
		if save.get("player_name", "").to_lower() == p_name.to_lower():
			name_input.text = ""
			name_input.placeholder_text = "Name already exists!"
			return
		
	GameManager.player_name = p_name
	name_entry_popup.visible = false
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")

func _on_continue_clicked():
	save_list_popup.visible = true
	_populate_save_list()

func _populate_save_list():
	for child in save_container.get_children():
		child.queue_free()
		
	var saves = SaveManager.get_save_list()
	for data in saves:
		var btn = Button.new()
		var icon = _get_class_icon(data.get("player_class", "Archivist"))
		var p_name = data.get("player_name", "Unknown")
		var level = data.get("current_level", 1)
		var date = data.get("save_date_text", "Unknown Date")
		
		btn.text = "%s %s | Floor %d | %s" % [icon, p_name, level, date]
		btn.custom_minimum_size.y = 60
		btn.pressed.connect(_load_specific_run.bind(data))
		save_container.add_child(btn)

func _get_class_icon(c_name: String) -> String:
	match c_name:
		"Archivist": return "📜"
		"Berserker": return "🪓"
		"Illusionist": return "🎭"
		_: return "👤"

func _load_specific_run(data: Dictionary):
	GameManager.load_run_from_data(data)

func _on_settings_pressed():
	if has_node("%SettingsOverlay"):
		%SettingsOverlay.visible = true

func _on_exit_pressed():
	get_tree().quit()
