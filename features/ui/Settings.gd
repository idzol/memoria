extends Control

# res://features/ui/Settings.gd

@onready var master_slider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeGrid/MasterSlider
@onready var sfx_slider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeGrid/SFXSlider
@onready var music_slider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeGrid/MusicSlider
@onready var mode_options = %ModeOptions
@onready var resolution_options = %ResolutionOptions
@onready var back_button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton

func _ready():
	# 1. Initialize Audio
	var master_bus = AudioServer.get_bus_index("Master")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var music_bus = AudioServer.get_bus_index("Music")
	
	if master_bus != -1: master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus))
	if sfx_bus != -1: sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))
	if music_bus != -1: music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
	
	# 2. Setup Dropdowns
	_setup_mode_dropdown()
	_setup_resolution_dropdown()
	
	# 3. Connect Signals
	master_slider.value_changed.connect(func(v): _set_vol("Master", v))
	sfx_slider.value_changed.connect(func(v): _set_vol("SFX", v))
	music_slider.value_changed.connect(func(v): _set_vol("Music", v))
	
	mode_options.item_selected.connect(_on_mode_selected)
	resolution_options.item_selected.connect(_on_resolution_selected)
	
	back_button.pressed.connect(func(): visible = false)

func _setup_mode_dropdown():
	mode_options.clear()
	mode_options.add_item("Windowed", 0)
	mode_options.add_item("Exclusive Fullscreen", 1)
	mode_options.add_item("Borderless Window", 2)
	
	# Set current mode
	var current_mode = DisplayServer.window_get_mode()
	match current_mode:
		DisplayServer.WINDOW_MODE_WINDOWED: mode_options.selected = 0
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: mode_options.selected = 1
		DisplayServer.WINDOW_MODE_FULLSCREEN: mode_options.selected = 2

func _setup_resolution_dropdown():
	resolution_options.clear()
	resolution_options.add_item("1280x720 (Laptop)", 0)
	resolution_options.add_item("1600x900", 1)
	resolution_options.add_item("1920x1080 (Full HD)", 2)
	resolution_options.add_item("2560x1440 (2K)", 3)

func _set_vol(bus_name: String, value: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func _on_mode_selected(index: int):
	match index:
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_resolution_selected(index: int):
	# FIXED: Renamed 'size' to 'target_size' to avoid shadowing Control.size
	var target_size = Vector2i(1280, 720)
	match index:
		1: target_size = Vector2i(1600, 900)
		2: target_size = Vector2i(1920, 1080)
		3: target_size = Vector2i(2560, 1440)
	
	DisplayServer.window_set_size(target_size)
	
	# Only center if we are in windowed mode
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		_center_window()

func _center_window():
	var screen = DisplayServer.window_get_current_screen()
	var screen_size = Vector2(DisplayServer.screen_get_size(screen))
	var window_size = Vector2(DisplayServer.window_get_size())
	
	# FIXED: Used float division (2.0) to avoid the Integer Division warning
	# This ensures more accurate centering before being cast back to window position
	var centered_pos = (screen_size / 2.0) - (window_size / 2.0)
	DisplayServer.window_set_position(Vector2i(centered_pos))
