extends CanvasLayer

# res://features/ui/InGameMenu.gd

enum State { IDLE, CONFIRM_SAVE, CONFIRM_ABANDON }
var current_state = State.IDLE
func _input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		handle_cancel()

func _ready():
	visible = false
	%ResumeBtn.pressed.connect(close)
	%SettingsBtn.pressed.connect(_on_settings_pressed)
	%SaveExitBtn.pressed.connect(_on_save_exit_pressed)
	%AbandonBtn.pressed.connect(_on_abandon_pressed)
	%YesBtn.pressed.connect(_on_confirm_yes)
	%NoBtn.pressed.connect(_on_confirm_no)

func open():
	visible = true
	get_tree().paused = true
	current_state = State.IDLE
	%ConfirmationDialog.visible = false
	%MenuPanel.visible = true
	_update_save_button_state()
	if has_node("%SettingsOverlay"):
		%SettingsOverlay.visible = false

func close():
	visible = false
	get_tree().paused = false

func handle_cancel() -> bool:
	if not visible:
		return false
	if has_node("%SettingsOverlay") and %SettingsOverlay.visible:
		%SettingsOverlay.visible = false
		return true
	if %ConfirmationDialog.visible:
		_on_confirm_no()
		return true
	close()
	return true

func _on_settings_pressed():
	if has_node("%SettingsOverlay"):
		%SettingsOverlay.visible = true

func _on_save_exit_pressed():
	if %SaveExitBtn.disabled:
		return
	current_state = State.CONFIRM_SAVE
	%ConfirmLabel.text = "Save progress and return to Main Menu?"
	%ConfirmationDialog.visible = true
	%MenuPanel.visible = false

func _update_save_button_state():
	var disable_save = _is_save_disabled_in_current_scene()
	%SaveExitBtn.disabled = disable_save
	%SaveExitBtn.modulate = Color(1, 1, 1, 0.5) if disable_save else Color(1, 1, 1, 1)

func _is_save_disabled_in_current_scene() -> bool:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return false
	var scene_path = current_scene.scene_file_path
	return scene_path.ends_with("features/combat/BattleScene.tscn") or scene_path.ends_with("features/encounters/EventScene.tscn")

func _on_abandon_pressed():
	current_state = State.CONFIRM_ABANDON
	%ConfirmLabel.text = "Abandon this run? All progress from this session will be lost."
	%ConfirmationDialog.visible = true
	%MenuPanel.visible = false

func _on_confirm_yes():
	if current_state == State.CONFIRM_SAVE:
		SaveManager.save_mid_run_state()
		_exit_to_menu()
	elif current_state == State.CONFIRM_ABANDON:
		_exit_to_run_summary()

func _on_confirm_no():
	current_state = State.IDLE
	%ConfirmationDialog.visible = false
	%MenuPanel.visible = true

func _exit_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://features/ui/MainMenu.tscn")

func _exit_to_run_summary():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://features/ui/RunSummary.tscn")
