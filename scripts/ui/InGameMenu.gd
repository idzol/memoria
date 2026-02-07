extends CanvasLayer

# res://scripts/ui/InGameMenu.gd

enum State { IDLE, CONFIRM_SAVE, CONFIRM_ABANDON }
var current_state = State.IDLE

func _ready():
	visible = false
	%ResumeBtn.pressed.connect(close)
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

func close():
	visible = false
	get_tree().paused = false

func _on_save_exit_pressed():
	current_state = State.CONFIRM_SAVE
	%ConfirmLabel.text = "Save progress and return to Main Menu?"
	%ConfirmationDialog.visible = true
	%MenuPanel.visible = false

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
		_exit_to_menu()

func _on_confirm_no():
	current_state = State.IDLE
	%ConfirmationDialog.visible = false
	%MenuPanel.visible = true

func _exit_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")