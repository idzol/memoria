extends CanvasLayer

# res://features/ui/InGameMenu.gd

enum State { IDLE, CONFIRM_SAVE, CONFIRM_ABANDON, CONFIRM_END_DAY }
var current_state = State.IDLE
var _menu_buttons: Array[Button] = []
var _menu_selected_index: int = 0
var _confirm_buttons: Array[Button] = []
var _confirm_selected_index: int = 0
var _selected_button_style: StyleBoxFlat
const CONFIRM_ACCEPT_DELAY_MS := 220
var _confirm_accept_unlocked_at_ms: int = 0

func _input(event):
	_handle_menu_input(event)

func _unhandled_input(event):
	_handle_menu_input(event)

func _handle_menu_input(event):
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		# Esc must match pressing "Resume".
		get_viewport().set_input_as_handled()
		_resume_game()
		return

	if %ConfirmationDialog.visible:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
			_move_confirm_selection(-1)
			return
		if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
			_move_confirm_selection(1)
			return
		if event.is_action_pressed("ui_accept") or _is_space_pressed(event):
			if Time.get_ticks_msec() < _confirm_accept_unlocked_at_ms:
				return
			_activate_confirm_selection()
			return
		return

	if %MenuPanel.visible:
		if event.is_action_pressed("ui_up"):
			_move_menu_selection(-1)
			return
		if event.is_action_pressed("ui_down"):
			_move_menu_selection(1)
			return
		if event.is_action_pressed("ui_accept") or _is_space_pressed(event):
			_activate_menu_selection()
			return

func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	%ResumeBtn.pressed.connect(_resume_game)
	%SettingsBtn.pressed.connect(_on_settings_pressed)
	%SaveExitBtn.pressed.connect(_on_save_exit_pressed)
	%EndDayBtn.pressed.connect(_on_end_day_pressed)
	%AbandonBtn.pressed.connect(_on_abandon_pressed)
	%YesBtn.pressed.connect(_on_confirm_yes)
	%NoBtn.pressed.connect(_on_confirm_no)
	_menu_buttons = [%ResumeBtn, %SettingsBtn, %SaveExitBtn, %EndDayBtn, %AbandonBtn]
	_confirm_buttons = [%YesBtn, %NoBtn]
	_create_button_styles()
	_refresh_menu_button_outlines()
	_refresh_confirm_button_outlines()

func open():
	visible = true
	get_tree().paused = true
	current_state = State.IDLE
	%ConfirmationDialog.visible = false
	%MenuPanel.visible = true
	_update_save_button_state()
	_update_story_mode_buttons()
	_focus_menu_selection(0)
	if has_node("%SettingsOverlay"):
		%SettingsOverlay.visible = false

func close():
	visible = false
	get_tree().paused = false

func _resume_game():
	close()

func handle_cancel() -> bool:
	if not visible:
		return false
	close()
	return true

func _on_settings_pressed():
	if has_node("%SettingsOverlay"):
		%SettingsOverlay.visible = true
		return
	var settings_overlay_scene := load("res://features/ui/SettingsOverlay.tscn")
	if settings_overlay_scene:
		var overlay = settings_overlay_scene.instantiate()
		overlay.name = "SettingsOverlay"
		overlay.unique_name_in_owner = true
		add_child(overlay)

func _on_save_exit_pressed():
	if %SaveExitBtn.disabled:
		return
	current_state = State.CONFIRM_SAVE
	%ConfirmLabel.text = "Save progress and return to Main Menu?"
	_show_confirm_dialog()

func _on_end_day_pressed():
	current_state = State.CONFIRM_END_DAY
	%ConfirmLabel.text = "End day and return to the overworld?"
	_show_confirm_dialog()

func _on_abandon_pressed():
	current_state = State.CONFIRM_ABANDON
	%ConfirmLabel.text = "Abandon this run? All progress from this session will be lost."
	_show_confirm_dialog()

func _show_confirm_dialog():
	%ConfirmationDialog.visible = true
	%MenuPanel.visible = false
	_confirm_accept_unlocked_at_ms = Time.get_ticks_msec() + CONFIRM_ACCEPT_DELAY_MS
	_focus_confirm_selection(0)

func _on_confirm_yes():
	if current_state == State.CONFIRM_SAVE:
		SaveManager.save_mid_run_state()
		_exit_to_menu()
	elif current_state == State.CONFIRM_ABANDON:
		_exit_to_run_summary_main_menu()
	elif current_state == State.CONFIRM_END_DAY:
		_end_day_story_mode()

func _on_confirm_no():
	current_state = State.IDLE
	%ConfirmationDialog.visible = false
	%MenuPanel.visible = true
	_focus_menu_selection(_menu_selected_index)

func _exit_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://features/ui/MainMenu.tscn")

func _exit_to_run_summary_main_menu():
	GameManager.run_summary_exit_to_main_menu = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://features/ui/RunSummary.tscn")

func _end_day_story_mode():
	if GameManager.is_battle_mode:
		return
	GameManager.begin_new_story_run(GameManager.player_biome if GameManager.player_biome != "" else "town")
	SaveManager.save_mid_run_state()
	get_tree().paused = false
	get_tree().change_scene_to_file(GameManager.get_story_line_scene_path())

func _update_save_button_state():
	var disable_save = _is_save_disabled_in_current_scene()
	%SaveExitBtn.disabled = disable_save
	%SaveExitBtn.modulate = Color(1, 1, 1, 0.5) if disable_save else Color(1, 1, 1, 1)

func _update_story_mode_buttons():
	%EndDayBtn.visible = not GameManager.is_battle_mode and _is_player_at_story_home()

func _is_player_at_story_home() -> bool:
	var current_node = GameManager.current_node
	if current_node.is_empty():
		return false
	return bool(current_node.get("is_home", false)) or str(current_node.get("type", "")) == "home"

func _is_save_disabled_in_current_scene() -> bool:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return false
	var scene_path = current_scene.scene_file_path
	return scene_path.ends_with("features/combat/BattleScene.tscn") or scene_path.ends_with("features/encounters/EventScene.tscn")

func _is_space_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_SPACE

func _move_menu_selection(step: int):
	var options = _get_visible_enabled_menu_buttons()
	if options.is_empty():
		return
	var current_btn = options[_menu_selected_index] if _menu_selected_index < options.size() else options[0]
	var current_idx = options.find(current_btn)
	if current_idx == -1:
		current_idx = 0
	_focus_menu_selection(posmod(current_idx + step, options.size()))

func _focus_menu_selection(index: int):
	var options = _get_visible_enabled_menu_buttons()
	if options.is_empty():
		return
	_menu_selected_index = clamp(index, 0, options.size() - 1)
	_refresh_menu_button_outlines()

func _activate_menu_selection():
	var options = _get_visible_enabled_menu_buttons()
	if options.is_empty():
		return
	options[_menu_selected_index].pressed.emit()

func _move_confirm_selection(step: int):
	if _confirm_buttons.is_empty():
		return
	_focus_confirm_selection(posmod(_confirm_selected_index + step, _confirm_buttons.size()))

func _focus_confirm_selection(index: int):
	if _confirm_buttons.is_empty():
		return
	_confirm_selected_index = clamp(index, 0, _confirm_buttons.size() - 1)
	_refresh_confirm_button_outlines()

func _activate_confirm_selection():
	if _confirm_buttons.is_empty():
		return
	_confirm_buttons[_confirm_selected_index].pressed.emit()

func _get_visible_enabled_menu_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for btn in _menu_buttons:
		if btn and btn.visible and not btn.disabled:
			result.append(btn)
	return result

func _create_button_styles():
	_selected_button_style = StyleBoxFlat.new()
	_selected_button_style.bg_color = Color(0, 0, 0, 0)
	_selected_button_style.border_width_left = 2
	_selected_button_style.border_width_top = 2
	_selected_button_style.border_width_right = 2
	_selected_button_style.border_width_bottom = 2
	_selected_button_style.border_color = Color(1, 1, 1, 1)
	_selected_button_style.corner_radius_top_left = 6
	_selected_button_style.corner_radius_top_right = 6
	_selected_button_style.corner_radius_bottom_left = 6
	_selected_button_style.corner_radius_bottom_right = 6

func _refresh_menu_button_outlines():
	var options = _get_visible_enabled_menu_buttons()
	for btn in _menu_buttons:
		if btn:
			_clear_button_style_overrides(btn)
	if options.is_empty():
		return
	_menu_selected_index = clamp(_menu_selected_index, 0, options.size() - 1)
	var selected_button = options[_menu_selected_index]
	selected_button.add_theme_stylebox_override("normal", _selected_button_style)
	selected_button.add_theme_stylebox_override("hover", _selected_button_style)
	selected_button.add_theme_stylebox_override("pressed", _selected_button_style)
	selected_button.add_theme_stylebox_override("focus", _selected_button_style)

func _refresh_confirm_button_outlines():
	for btn in _confirm_buttons:
		if btn:
			_clear_button_style_overrides(btn)
	if _confirm_buttons.is_empty():
		return
	_confirm_selected_index = clamp(_confirm_selected_index, 0, _confirm_buttons.size() - 1)
	var selected_button = _confirm_buttons[_confirm_selected_index]
	selected_button.add_theme_stylebox_override("normal", _selected_button_style)
	selected_button.add_theme_stylebox_override("hover", _selected_button_style)
	selected_button.add_theme_stylebox_override("pressed", _selected_button_style)
	selected_button.add_theme_stylebox_override("focus", _selected_button_style)

func _clear_button_style_overrides(btn: Button):
	btn.remove_theme_stylebox_override("normal")
	btn.remove_theme_stylebox_override("hover")
	btn.remove_theme_stylebox_override("pressed")
	btn.remove_theme_stylebox_override("focus")
