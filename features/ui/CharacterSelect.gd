# [AI-CONTRACT]
# FILE: res://features/ui/CharacterSelect.gd
# FEATURES: Warrior/Scholar/Alchemist selection, stylebox override for ConfirmBtn background stretch, persistent button highlighting.
# [YOLO-METADATA] TARGET: res://features/ui/CharacterSelect.gd

extends Control

# [UI-107] Character Selection Screen Implementation
# Manages selection state, icon swapping, and class initialization.

@onready var description_label = %DescriptionLabel
@onready var warrior_btn = %WarriorBtn
@onready var scholar_btn = %ScholarBtn
@onready var alchemist_btn = %AlchemistBtn
@onready var background_tex = %BackgroundTexture
@onready var confirm_btn = %ConfirmBtn

var selected_class: String = ""

func _ready():
	# 1. Set background texture
	if AssetRegistry.CHARACTER_ASSETS.has("background"):
		background_tex.texture = load(AssetRegistry.CHARACTER_ASSETS.background)
	
	# 2. Stretch button.png to full size of ConfirmBtn using StyleBoxTexture
	if AssetRegistry.CHARACTER_ASSETS.has("confirm_button"):
		var tex = load(AssetRegistry.CHARACTER_ASSETS.confirm_button)
		var sb = StyleBoxTexture.new()
		sb.texture = tex
		# Apply stylebox to all states to ensure the background is always visible and stretched
		confirm_btn.add_theme_stylebox_override("normal", sb)
		confirm_btn.add_theme_stylebox_override("hover", sb)
		confirm_btn.add_theme_stylebox_override("pressed", sb)
		confirm_btn.add_theme_stylebox_override("disabled", sb)
		confirm_btn.add_theme_stylebox_override("focus", sb)
	
	# 3. Enable toggle mode for class buttons to maintain visual "pressed" state
	for btn in [warrior_btn, scholar_btn, alchemist_btn]:
		btn.toggle_mode = true
		# Prevent un-toggling the same button by clicking it again
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	
	# 4. Connect signals
	warrior_btn.pressed.connect(_on_class_clicked.bind("warrior"))
	scholar_btn.pressed.connect(_on_class_clicked.bind("scholar"))
	alchemist_btn.pressed.connect(_on_class_clicked.bind("alchemist"))
	confirm_btn.pressed.connect(_on_confirm_pressed)
	
	# 5. Initial UI state
	confirm_btn.disabled = true
	description_label.text = "Choose your path to reclaim your divinity..."
	_update_icons()

func _on_class_clicked(class_id: String):
	selected_class = class_id
	
	if AssetRegistry.CHARACTER_ASSETS.has(class_id):
		description_label.text = AssetRegistry.CHARACTER_ASSETS[class_id].desc
		
	confirm_btn.disabled = false
	_update_icons()

func _update_icons():
	var classes = ["warrior", "scholar", "alchemist"]
	var buttons = [warrior_btn, scholar_btn, alchemist_btn]
	
	for i in range(classes.size()):
		var class_id = classes[i]
		var btn = buttons[i]
		var is_selected = (selected_class == class_id)
		
		# Swap to selected icon if this class is the active choice
		btn.icon = AssetRegistry.get_character_texture(class_id, is_selected)
		
		# Keep the button visually "highlighted/pressed" via the theme
		btn.set_pressed_no_signal(is_selected)

func _on_confirm_pressed():
	if selected_class == "": return
	
	# 5. Initialize Global Stats via GameManager and GameData level 1 stats
	GameManager.player_class = selected_class.capitalize()
	GameManager.player_level = 1
	
	var stats = GameData.get_stats(selected_class, 1)
	if not stats.is_empty():
		GameManager.max_hp = stats.max_hp
		GameManager.current_hp = GameManager.max_hp
		# Initialize combat stats in GameManager for later use
		GameManager.base_energy = stats.energy
		GameManager.base_attack = stats.player_attack
		GameManager.base_defense = stats.player_defense
	else:
		push_error("Stats initialization failed for: " + selected_class)
			
	SignalBus.game_started.emit()
	get_tree().change_scene_to_file("res://features/map/WorldMap.tscn")
