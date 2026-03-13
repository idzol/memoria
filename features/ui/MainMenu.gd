extends Control

# res://features/ui/MainMenu.gd

@onready var continue_button = %ContinueButton
@onready var name_entry_popup = %NameEntryPopup
@onready var save_list_popup = %SaveListPopup
@onready var save_list_blocker = %SaveListBlocker
@onready var save_container = %SaveListVBox
@onready var save_scroll: ScrollContainer = %SaveListPopup.get_node("VBox/ScrollContainer")
@onready var name_input = %NameInput
@onready var battle_mode_btn = %BattleModeButton

# Confirmation Popup for deletion
@onready var confirm_delete_popup = %ConfirmDeletePopup
var _pending_delete_filename: String = ""
var _pending_mode_is_battle: bool = false
var _main_menu_buttons: Array[Button] = []
var _save_option_buttons: Array[Button] = []
var _main_selected_index: int = 0
var _save_selected_index: int = -1
var _suppress_next_save_accept: bool = false
var _selected_button_style: StyleBoxFlat
var _save_hold_direction: int = 0
var _save_hold_elapsed: float = 0.0
var _save_next_repeat_at: float = 0.0
const SAVE_HOLD_INITIAL_DELAY := 0.35
const SAVE_HOLD_REPEAT_INTERVAL := 0.09

func _ready():
	_request_initial_music.call_deferred()

	_refresh_continue_button()
	
	# Connect signals
	%StartButton.pressed.connect(_on_new_game_clicked)
	%ConfirmNameBtn.pressed.connect(_on_name_confirmed)
	%CancelNameBtn.pressed.connect(func(): name_entry_popup.visible = false)
	%CloseSavesBtn.pressed.connect(func(): _set_save_list_popup_visible(false))
	%SettingsButton.pressed.connect(_on_settings_pressed)
	%ControlsBtn.pressed.connect(_on_controls_pressed) # New Connection
	%CreditsBtn.pressed.connect(_on_credits_pressed)
	%ExitButton.pressed.connect(_on_exit_pressed)
	%BattleModeButton.pressed.connect(_on_battle_mode_clicked)

	# Delete Confirmation connections
	%ConfirmDeleteBtn.pressed.connect(_on_delete_confirmed)
	%CancelDeleteBtn.pressed.connect(func(): confirm_delete_popup.visible = false)
	
	# Hide overlays
	name_entry_popup.visible = false
	_set_save_list_popup_visible(false)
	confirm_delete_popup.visible = false
	if has_node("%SettingsOverlay"):
		%SettingsOverlay.visible = false
	
	_main_menu_buttons = [
		%ContinueButton,
		%StartButton,
		%BattleModeButton,
		%SettingsButton,
		%ControlsBtn,
		%CreditsBtn,
		%ExitButton
	]
	_setup_selected_button_style()
	for btn in _main_menu_buttons:
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_entered.connect(_on_main_button_hovered.bind(btn))
	_focus_main_option(0)
	_fade_in_from_white()

func _input(event):
	if name_entry_popup.visible:
		if event.is_action_pressed("ui_accept"):
			_on_name_confirmed()
			return
		if event.is_action_pressed("ui_cancel"):
			name_entry_popup.visible = false
			_focus_main_option(_main_selected_index)
			return
		return
	if confirm_delete_popup.visible:
		return
	if has_node("%SettingsOverlay") and %SettingsOverlay.visible:
		return
	
	if save_list_popup.visible:
		if event.is_action_pressed("ui_cancel"):
			_set_save_list_popup_visible(false)
			return
		if event.is_action_pressed("ui_up"):
			_suppress_next_save_accept = false
			_move_save_selection(-1)
			_start_save_hold(-1)
			return
		if event.is_action_pressed("ui_down"):
			_suppress_next_save_accept = false
			_move_save_selection(1)
			_start_save_hold(1)
			return
		if event.is_action_pressed("ui_accept"):
			if _suppress_next_save_accept:
				_suppress_next_save_accept = false
				return
			_activate_save_selection()
			return
		return
	
	if event.is_action_pressed("ui_up"):
		_move_main_selection(-1)
		return
	if event.is_action_pressed("ui_down"):
		_move_main_selection(1)
		return
	if event.is_action_pressed("ui_accept"):
		_activate_main_selection()
		return

func _process(delta: float):
	if not _can_repeat_save_scroll():
		_reset_save_hold()
		return
	var dir := 0
	if Input.is_action_pressed("ui_down"):
		dir = 1
	elif Input.is_action_pressed("ui_up"):
		dir = -1
	
	if dir == 0:
		_reset_save_hold()
		return
	
	if dir != _save_hold_direction:
		_start_save_hold(dir)
		return
	
	_save_hold_elapsed += delta
	while _save_hold_elapsed >= _save_next_repeat_at:
		_move_save_selection(_save_hold_direction)
		_save_next_repeat_at += SAVE_HOLD_REPEAT_INTERVAL


func _request_initial_music():
	# Double check AudioData constant exists
	var track = AudioData.TRACKS.get("MAIN_MENU", "intro_main_menu")
	SignalBus.music_change_requested.emit(track, 1.5)

func _refresh_continue_button():
	# Note: Assumes SaveManager singleton exists
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
	_pending_mode_is_battle = false
	_open_name_entry_popup()

func _on_battle_mode_clicked():
	_pending_mode_is_battle = true
	_open_name_entry_popup()

func _open_name_entry_popup():
	GameManager.is_battle_mode = _pending_mode_is_battle
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
	get_tree().change_scene_to_file("res://features/ui/CharacterSelect.tscn")

func _on_continue_clicked():
	_set_save_list_popup_visible(true)
	_populate_save_list()

func _set_save_list_popup_visible(visible_state: bool):
	save_list_popup.visible = visible_state
	if save_list_blocker:
		save_list_blocker.visible = visible_state
	_reset_save_hold()
	if visible_state:
		_suppress_next_save_accept = true
		_clear_save_selection()
	else:
		_suppress_next_save_accept = false
		_clear_save_selection()
		_focus_main_option(_main_selected_index)

func _populate_save_list():
	for child in save_container.get_children():
		child.queue_free()
	_save_option_buttons.clear()
		
	var saves = SaveManager.get_save_list()
	for data in saves:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		save_container.add_child(hbox)

		var mode_label = Label.new()
		var is_battle = data.get("is_battle_mode", false)
		mode_label.text = "BATTLE MODE" if is_battle else "STORY MODE"
		mode_label.custom_minimum_size = Vector2(130, 50)
		mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mode_label.modulate = Color(1.0, 0.8, 0.4, 1.0) if is_battle else Color(0.6, 0.9, 1.0, 1.0)
		hbox.add_child(mode_label)
		
		var btn = Button.new()
		var icon = _get_class_icon(data.get("player_class", "Archivist"))
		var p_name = data.get("player_name", "Unknown")
		var floor_num = data.get("player_level", data.get("current_level", 1))
		btn.text = "%s %s | Floor %d" % [icon, p_name, floor_num]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 50
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_load_specific_run.bind(data))
		btn.mouse_entered.connect(_on_save_button_hovered.bind(btn))
		hbox.add_child(btn)
		_save_option_buttons.append(btn)
		
		var del_btn = Button.new()
		del_btn.text = " X "
		del_btn.modulate = Color.INDIAN_RED
		del_btn.pressed.connect(_on_delete_request.bind(data.filename))
		hbox.add_child(del_btn)
	_clear_save_selection()

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
	_set_save_list_popup_visible(false)
	GameManager.load_run_from_data(data)

func _on_settings_pressed():
	_play_click_sfx()
	if has_node("%SettingsOverlay"):
		%SettingsOverlay.visible = true

func _on_controls_pressed():
	_play_click_sfx()
	get_tree().change_scene_to_file("res://features/ui/ControlsMenu.tscn")

func _on_credits_pressed():
	_play_click_sfx()
	get_tree().change_scene_to_file("res://features/ui/Credits.tscn")

func _on_exit_pressed():
	_play_click_sfx()
	SignalBus.game_exited.emit()
	get_tree().quit()

func _play_click_sfx():
	# Trigger common UI click sound from music.csv (e.g., sfx_207)
	SignalBus.sfx_triggered.emit("UI_CLICK")

func _setup_selected_button_style():
	_selected_button_style = StyleBoxFlat.new()
	_selected_button_style.bg_color = Color(0, 0, 0, 0)
	_selected_button_style.draw_center = true
	_selected_button_style.border_width_left = 2
	_selected_button_style.border_width_top = 2
	_selected_button_style.border_width_right = 2
	_selected_button_style.border_width_bottom = 2
	_selected_button_style.border_color = Color(1, 1, 1, 1)

func _apply_selection_outline(btn: Button, selected: bool):
	if not btn:
		return
	if selected:
		btn.add_theme_stylebox_override("normal", _selected_button_style)
		btn.add_theme_stylebox_override("hover", _selected_button_style)
		btn.add_theme_stylebox_override("pressed", _selected_button_style)
		btn.add_theme_stylebox_override("focus", _selected_button_style)
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_stylebox_override("pressed")
		btn.remove_theme_stylebox_override("focus")

func _move_main_selection(step: int):
	if _main_menu_buttons.is_empty():
		return
	var start = _main_selected_index
	var idx = start
	var safety = 0
	while safety < _main_menu_buttons.size():
		idx = posmod(idx + step, _main_menu_buttons.size())
		if not _main_menu_buttons[idx].disabled:
			_focus_main_option(idx)
			return
		safety += 1

func _focus_main_option(index: int):
	if _main_menu_buttons.is_empty():
		return
	_main_selected_index = clamp(index, 0, _main_menu_buttons.size() - 1)
	if _main_menu_buttons[_main_selected_index].disabled:
		_move_main_selection(1)
		return
	for i in range(_main_menu_buttons.size()):
		var btn = _main_menu_buttons[i]
		if btn.disabled:
			btn.modulate.a = 0.5
			_apply_selection_outline(btn, false)
		else:
			btn.modulate.a = 1.0 if i == _main_selected_index else 0.82
			_apply_selection_outline(btn, i == _main_selected_index)

func _activate_main_selection():
	if _main_menu_buttons.is_empty():
		return
	var btn = _main_menu_buttons[_main_selected_index]
	if btn and not btn.disabled:
		btn.pressed.emit()

func _on_main_button_hovered(btn: Button):
	var idx = _main_menu_buttons.find(btn)
	if idx != -1:
		_focus_main_option(idx)

func _move_save_selection(step: int):
	if _save_option_buttons.is_empty():
		return
	if _save_selected_index == -1:
		if step < 0:
			_focus_save_option(_save_option_buttons.size() - 1)
		else:
			_focus_save_option(0)
		return
	_focus_save_option(posmod(_save_selected_index + step, _save_option_buttons.size()))

func _focus_save_option(index: int):
	if _save_option_buttons.is_empty():
		%CloseSavesBtn.grab_focus()
		return
	_save_selected_index = clamp(index, 0, _save_option_buttons.size() - 1)
	for i in range(_save_option_buttons.size()):
		var btn = _save_option_buttons[i]
		btn.modulate.a = 1.0 if i == _save_selected_index else 0.8
		_apply_selection_outline(btn, i == _save_selected_index)
	var selected_btn = _save_option_buttons[_save_selected_index]
	if save_scroll:
		save_scroll.ensure_control_visible(selected_btn)

func _activate_save_selection():
	if _save_option_buttons.is_empty():
		%CloseSavesBtn.pressed.emit()
		return
	if _save_selected_index < 0 or _save_selected_index >= _save_option_buttons.size():
		return
	_save_option_buttons[_save_selected_index].pressed.emit()

func _on_save_button_hovered(btn: Button):
	var idx = _save_option_buttons.find(btn)
	if idx != -1:
		_focus_save_option(idx)

func _clear_save_selection():
	_save_selected_index = -1
	for btn in _save_option_buttons:
		btn.modulate.a = 0.8
		_apply_selection_outline(btn, false)

func _start_save_hold(direction: int):
	_save_hold_direction = direction
	_save_hold_elapsed = 0.0
	_save_next_repeat_at = SAVE_HOLD_INITIAL_DELAY

func _reset_save_hold():
	_save_hold_direction = 0
	_save_hold_elapsed = 0.0
	_save_next_repeat_at = 0.0

func _can_repeat_save_scroll() -> bool:
	if not save_list_popup.visible:
		return false
	if name_entry_popup.visible or confirm_delete_popup.visible:
		return false
	if has_node("%SettingsOverlay") and %SettingsOverlay.visible:
		return false
	return true

func _fade_in_from_white():
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	
	var fade_rect = ColorRect.new()
	fade_rect.color = Color(1, 1, 1, 1)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(fade_rect, "color:a", 0.0, 0.9)
	await tween.finished
	if is_instance_valid(fade_layer):
		fade_layer.queue_free()
