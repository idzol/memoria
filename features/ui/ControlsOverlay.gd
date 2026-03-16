extends Control

signal closed

@onready var title_label: Label = %Title
@onready var controls_list: VBoxContainer = %ControlsList
@onready var back_button: Button = %BackButton
@onready var hint_label: Label = %Hint

var default_controls := [
	{"label_key": "controls.move_up", "default_label": "Move Up", "key": KEY_W},
	{"label_key": "controls.move_down", "default_label": "Move Down", "key": KEY_S},
	{"label_key": "controls.move_left", "default_label": "Move Left", "key": KEY_A},
	{"label_key": "controls.move_right", "default_label": "Move Right", "key": KEY_D},
	{"label_key": "controls.confirm", "default_label": "Confirm / Select", "key": KEY_ENTER},
	{"label_key": "controls.cancel", "default_label": "Cancel / Back", "key": KEY_ESCAPE},
	{"label_key": "controls.menu", "default_label": "Menu", "key": KEY_ESCAPE},
	{"label_key": "controls.story_map", "default_label": "Story Map", "key": KEY_W}
]

func _ready():
	visible = false
	_rebuild_controls()
	back_button.pressed.connect(_close)
	_refresh_localized_text()

func _input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _rebuild_controls():
	for child in controls_list.get_children():
		child.queue_free()

	for control_data in default_controls:
		var h_box := HBoxContainer.new()
		h_box.custom_minimum_size.y = 42
		h_box.add_theme_constant_override("separation", 16)

		var label := Label.new()
		label.text = LocalizationManager.translate(control_data.label_key, control_data.default_label)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var key_button := Button.new()
		key_button.disabled = true
		key_button.focus_mode = Control.FOCUS_NONE
		key_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_button.text = OS.get_keycode_string(control_data.key)
		key_button.custom_minimum_size.x = 170

		h_box.add_child(label)
		h_box.add_child(key_button)
		controls_list.add_child(h_box)

func _refresh_localized_text():
	if title_label:
		title_label.text = LocalizationManager.translate("menu.controls", "CONTROLS")
	if hint_label:
		hint_label.text = LocalizationManager.translate("controls.cancel_hint", "[ESC] to Close")
	if back_button:
		back_button.text = LocalizationManager.translate("menu.close", "CLOSE")

func open():
	visible = true
	_refresh_localized_text()
	_rebuild_controls()

func _close():
	visible = false
	closed.emit()
