extends Control

# res://features/ui/Settings.gd

@onready var master_slider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeGrid/MasterSlider
@onready var sfx_slider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeGrid/SFXSlider
@onready var music_slider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeGrid/MusicSlider
@onready var mode_options = %ModeOptions
@onready var resolution_options = %ResolutionOptions
@onready var gameplay_header = %GameplayHeader
@onready var tutorial_tips_label = %TutorialTipsLabel
@onready var tutorial_tips_button = %TutorialTipsButton
@onready var run_log_label = %RunLogLabel
@onready var run_log_button = %RunLogButton
@onready var back_button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton

const AudioSettingsScript = preload("res://core/AudioSettings.gd")
const SETTINGS_PATH := AudioSettingsScript.SETTINGS_PATH
const SETTINGS_SECTION := "gameplay"
const TUTORIAL_TIPS_KEY := "tutorial_tips"
const RUN_LOG_KEY := "show_run_log"

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1024, 576),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160)
]

const RESOLUTION_LABELS: Array[String] = [
	"1024x576",
	"1280x720 (Laptop)",
	"1366x768",
	"1600x900",
	"1920x1080 (Full HD)",
	"2560x1440 (2K)",
	"3440x1440 (Ultrawide)",
	"3840x2160 (4K)"
]

var _previous_resolution: Vector2i = Vector2i.ZERO
var _pending_resolution: Vector2i = Vector2i.ZERO
var _confirm_dialog: ConfirmationDialog
var _countdown_timer: Timer
var _countdown_seconds_left: int = 0
var _is_reverting_resolution: bool = false
var _option_base_style: StyleBoxFlat
var _option_focus_style: StyleBoxFlat
var _tutorial_tips_enabled: bool = true
var _run_log_enabled: bool = true

func _ready():
	# 1. Initialize Audio from global AudioManager settings
	master_slider.value = AudioManager.get_master_volume()
	sfx_slider.value = AudioManager.get_sfx_volume()
	music_slider.value = AudioManager.get_music_volume()
	_load_tutorial_tips_setting()
	_load_run_log_setting()
	
	# 2. Setup Dropdowns
	_setup_mode_dropdown()
	_setup_resolution_dropdown()
	_setup_option_button_styles()
	
	# 3. Connect Signals
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	
	mode_options.item_selected.connect(_on_mode_selected)
	resolution_options.item_selected.connect(_on_resolution_selected)
	if tutorial_tips_button:
		tutorial_tips_button.pressed.connect(_on_tutorial_tips_pressed)
	if run_log_button:
		run_log_button.pressed.connect(_on_run_log_pressed)
	
	back_button.pressed.connect(_save_and_close)
	_setup_resolution_confirmation_dialog()
	_refresh_localized_text()

func _input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_save_and_close()

func _setup_mode_dropdown():
	mode_options.clear()
	mode_options.add_item("Windowed", 0)
	mode_options.add_item("Exclusive Fullscreen", 1)
	mode_options.add_item("Borderless Window", 2)
	
	# Set current mode
	var current_mode = _get_current_window_mode()
	match current_mode:
		DisplayServer.WINDOW_MODE_WINDOWED: mode_options.selected = 0
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: mode_options.selected = 1
		DisplayServer.WINDOW_MODE_FULLSCREEN: mode_options.selected = 2

func _setup_resolution_dropdown():
	resolution_options.clear()
	for i in range(RESOLUTION_LABELS.size()):
		resolution_options.add_item(RESOLUTION_LABELS[i], i)
	_select_resolution_option_for_size(DisplayServer.window_get_size())

func _setup_option_button_styles():
	# Keep option buttons transparent in all non-focus states.
	_option_base_style = StyleBoxFlat.new()
	_option_base_style.bg_color = Color(0, 0, 0, 0)
	_option_base_style.border_width_left = 1
	_option_base_style.border_width_top = 1
	_option_base_style.border_width_right = 1
	_option_base_style.border_width_bottom = 1
	_option_base_style.border_color = Color(1, 1, 1, 0.35)
	_option_base_style.corner_radius_top_left = 4
	_option_base_style.corner_radius_top_right = 4
	_option_base_style.corner_radius_bottom_right = 4
	_option_base_style.corner_radius_bottom_left = 4

	# Focus state: outline only, no shading.
	_option_focus_style = StyleBoxFlat.new()
	_option_focus_style.bg_color = Color(0, 0, 0, 0)
	_option_focus_style.border_width_left = 2
	_option_focus_style.border_width_top = 2
	_option_focus_style.border_width_right = 2
	_option_focus_style.border_width_bottom = 2
	_option_focus_style.border_color = Color(1, 1, 1, 1)
	_option_focus_style.corner_radius_top_left = 4
	_option_focus_style.corner_radius_top_right = 4
	_option_focus_style.corner_radius_bottom_right = 4
	_option_focus_style.corner_radius_bottom_left = 4

	_apply_option_button_style(mode_options)
	_apply_option_button_style(resolution_options)

func _apply_option_button_style(option_button: OptionButton):
	if not option_button:
		return
	option_button.add_theme_stylebox_override("normal", _option_base_style)
	option_button.add_theme_stylebox_override("hover", _option_base_style)
	option_button.add_theme_stylebox_override("pressed", _option_base_style)
	option_button.add_theme_stylebox_override("disabled", _option_base_style)
	option_button.add_theme_stylebox_override("focus", _option_focus_style)

func _on_master_volume_changed(value: float):
	AudioManager.set_master_volume(value)

func _on_sfx_volume_changed(value: float):
	AudioManager.set_sfx_volume(value)

func _on_music_volume_changed(value: float):
	AudioManager.set_music_volume(value)

func _on_mode_selected(index: int):
	var target_mode = DisplayServer.WINDOW_MODE_WINDOWED
	match index:
		0: target_mode = DisplayServer.WINDOW_MODE_WINDOWED
		1: target_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		2: target_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	_apply_window_mode(target_mode)
	if target_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		_center_window()

func _on_resolution_selected(index: int):
	if index < 0 or index >= RESOLUTION_PRESETS.size():
		return
	var target_size = RESOLUTION_PRESETS[index]

	if _is_reverting_resolution:
		return
	if DisplayServer.window_get_size() == target_size:
		return

	_previous_resolution = DisplayServer.window_get_size()
	_pending_resolution = target_size

	# Force windowed mode so DisplayServer can apply a concrete window size.
	if _get_current_window_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		_apply_window_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		mode_options.select(0)

	_apply_resolution(target_size)
	
	# Only center if we are in windowed mode
	if _get_current_window_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		_center_window()
	_prompt_resolution_confirm()

func _center_window():
	var screen = DisplayServer.window_get_current_screen()
	var screen_size = Vector2(DisplayServer.screen_get_size(screen))
	var window_size = Vector2(DisplayServer.window_get_size())
	
	# FIXED: Used float division (2.0) to avoid the Integer Division warning
	# This ensures more accurate centering before being cast back to window position
	var centered_pos = (screen_size / 2.0) - (window_size / 2.0)
	DisplayServer.window_set_position(Vector2i(centered_pos))

func _setup_resolution_confirmation_dialog():
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Keep Resolution?"
	_confirm_dialog.ok_button_text = "Keep"
	_confirm_dialog.cancel_button_text = "Revert"
	_confirm_dialog.exclusive = true
	_confirm_dialog.unresizable = true
	_confirm_dialog.confirmed.connect(_on_resolution_confirmed)
	_confirm_dialog.canceled.connect(_on_resolution_revert)
	_confirm_dialog.close_requested.connect(_on_resolution_revert)
	add_child(_confirm_dialog)
	
	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = 1.0
	_countdown_timer.one_shot = false
	_countdown_timer.timeout.connect(_on_resolution_countdown_tick)
	add_child(_countdown_timer)

func _prompt_resolution_confirm():
	_countdown_seconds_left = 5
	_update_resolution_countdown_text()
	_confirm_dialog.popup_centered(Vector2i(420, 180))
	_countdown_timer.start()

func _on_resolution_countdown_tick():
	_countdown_seconds_left -= 1
	if _countdown_seconds_left <= 0:
		_countdown_timer.stop()
		_on_resolution_revert()
		return
	_update_resolution_countdown_text()

func _update_resolution_countdown_text():
	_confirm_dialog.dialog_text = "Keep this resolution?\nReverting in %d seconds..." % _countdown_seconds_left

func _on_resolution_confirmed():
	_countdown_timer.stop()
	_confirm_dialog.hide()
	_previous_resolution = _pending_resolution

func _on_resolution_revert():
	_countdown_timer.stop()
	_confirm_dialog.hide()
	_is_reverting_resolution = true
	_apply_resolution(_previous_resolution)
	if _get_current_window_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		_center_window()
	_select_resolution_option_for_size(_previous_resolution)
	_is_reverting_resolution = false

func _select_resolution_option_for_size(target: Vector2i):
	var idx = RESOLUTION_PRESETS.find(target)
	if idx != -1:
		resolution_options.select(idx)

func _save_and_close():
	# If a resolution confirmation is active, keep the currently-applied mode/size.
	if _confirm_dialog and _confirm_dialog.visible:
		_on_resolution_confirmed()
	visible = false

func _get_current_window_mode() -> int:
	return DisplayServer.window_get_mode()

func _apply_window_mode(mode: int):
	DisplayServer.window_set_mode(mode)

func _apply_resolution(target_size: Vector2i):
	DisplayServer.window_set_size(target_size)

func _on_tutorial_tips_pressed():
	_tutorial_tips_enabled = not _tutorial_tips_enabled
	_save_tutorial_tips_setting()
	_refresh_localized_text()
	SignalBus.run_log_updated.emit()

func _on_run_log_pressed():
	_run_log_enabled = not _run_log_enabled
	_save_run_log_setting()
	_refresh_localized_text()
	SignalBus.run_log_updated.emit()

func _refresh_localized_text():
	if has_node("%Title"):
		%Title.text = LocalizationManager.translate("menu.settings", "SETTINGS")
	if has_node("%AudioHeader"):
		%AudioHeader.text = LocalizationManager.translate("settings.audio", "Audio")
	if has_node("%DisplayHeader"):
		%DisplayHeader.text = LocalizationManager.translate("settings.display", "Display")
	if gameplay_header:
		gameplay_header.text = LocalizationManager.translate("settings.gameplay", "Gameplay")
	if tutorial_tips_label:
		tutorial_tips_label.text = LocalizationManager.translate("settings.tutorial_tips_label", "Tutorial Tips")
	if tutorial_tips_button:
		tutorial_tips_button.text = LocalizationManager.translate("common.on", "On") if _tutorial_tips_enabled else LocalizationManager.translate("common.off", "Off")
	if run_log_label:
		run_log_label.text = LocalizationManager.translate("settings.run_log_label", "Global Log")
	if run_log_button:
		run_log_button.text = LocalizationManager.translate("common.on", "On") if _run_log_enabled else LocalizationManager.translate("common.off", "Off")
	if back_button:
		back_button.text = LocalizationManager.translate("menu.close", "CLOSE")

func _load_tutorial_tips_setting():
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_tutorial_tips_enabled = true
		return
	_tutorial_tips_enabled = bool(config.get_value(SETTINGS_SECTION, TUTORIAL_TIPS_KEY, true))

func _save_tutorial_tips_setting():
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, TUTORIAL_TIPS_KEY, _tutorial_tips_enabled)
	config.save(SETTINGS_PATH)

func _load_run_log_setting():
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_run_log_enabled = true
		return
	_run_log_enabled = bool(config.get_value(SETTINGS_SECTION, RUN_LOG_KEY, true))

func _save_run_log_setting():
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, RUN_LOG_KEY, _run_log_enabled)
	config.save(SETTINGS_PATH)
