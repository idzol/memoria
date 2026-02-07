extends Control

# res://scripts/ui/MainMenu.gd

@onready var continue_button = %ContinueButton
@onready var name_entry_popup = %NameEntryPopup
@onready var save_list_popup = %SaveListPopup
@onready var save_container = %SaveListVBox
@onready var name_input = %NameInput

# Confirmation Popup for deletion
@onready var confirm_delete_popup = %ConfirmDeletePopup
var _pending_delete_filename: String = ""

func _ready():
	_refresh_continue_button()
	
	# Connect signals
	%StartButton.pressed.connect(_on_new_game_clicked)
	%ConfirmNameBtn.pressed.connect(_on_name_confirmed)
	%CancelNameBtn.pressed.connect(func(): name_entry_popup.visible = false)
	%CloseSavesBtn.pressed.connect(func(): save_list_popup.visible = false)
	%SettingsButton.pressed.connect(_on_settings_pressed)
	%ExitButton.pressed.connect(_on_exit_pressed)
	
	# Delete Confirmation connections
	%ConfirmDeleteBtn.pressed.connect(_on_delete_confirmed)
	%CancelDeleteBtn.pressed.connect(func(): confirm_delete_popup.visible = false)
	
	# Hide overlays
	name_entry_popup.visible = false
	save_list_popup.visible = false
	confirm_delete_popup.visible = false
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
	if p_name.length() < 2: return
		
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
		var hbox = HBoxContainer.new()
		save_container.add_child(hbox)
		
		# Load Button
		var btn = Button.new()
		var icon = _get_class_icon(data.get("player_class", "Archivist"))
		var p_name = data.get("player_name", "Unknown")
		var floor_num = data.get("current_level", 1)
		btn.text = "%s %s | Floor %d" % [icon, p_name, floor_num]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 50
		btn.pressed.connect(_load_specific_run.bind(data))
		hbox.add_child(btn)
		
		# Delete Button
		var del_btn = Button.new()
		del_btn.text = " X "
		del_btn.modulate = Color.INDIAN_RED
		del_btn.pressed.connect(_on_delete_request.bind(data.filename))
		hbox.add_child(del_btn)

func _on_delete_request(filename: String):
	_pending_delete_filename = filename
	confirm_delete_popup.visible = true

func _on_delete_confirmed():
	if _pending_delete_filename != "":
		SaveManager.delete_run(_pending_delete_filename)
		_pending_delete_filename = ""
		confirm_delete_popup.visible = false
		_populate_save_list()
		_refresh_continue_button()

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