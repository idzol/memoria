extends TextureButton

# res://features/combat/Card.gd
# Advanced card controller using Rarity for backs and Type for fronts.
# Updated: Detects layout to load correct background sizes and prevents click-spam.

signal card_flipped(card_node)

# Preload required custom types
#const CardAssetData = preload("res://data/resources/card_asset_data.gd")
#const CardData = preload("res://data/resources/card_data.gd")

var asset_templates: CardAssetData = preload("res://data/cards/_card_assets.tres")

@onready var back_face = get_node_or_null("%BackFace")
@onready var front_face = get_node_or_null("%FrontFace")
@onready var title_label = get_node_or_null("%TitleLabel")
@onready var card_image_rect = get_node_or_null("%CardImage")
@onready var center_type_icon = get_node_or_null("%CenterTypeIcon")
@onready var card_icon_rect = get_node_or_null("%CardIcon")
@onready var description_label = get_node_or_null("%DescriptionLabel")
@onready var front_template_rect = get_node_or_null("%FrontTemplate")
@onready var back_template_rect = get_node_or_null("%BackTemplate")
@onready var back_icon_rect = get_node_or_null("%BackIcon")

var card_type: String = "" 
var is_matched: bool = false
var is_face_up: bool = false
const FRONT_ASSETS_ROOT := "res://assets/cards/front/"
const TYPE_FILE_ALIASES := {
	"armor": "defend",
	"utility": "prepare",
	"charge": "spell"
}
const TITLE_ORIGINAL_RECT := Rect2(18.0, 15.0, 124.0, 14.0)
const DESCRIPTION_ORIGINAL_RECT := Rect2(18.0, 166.0, 124.0, 52.0)

func _ready():
	pressed.connect(_on_pressed)
	resized.connect(_update_pivot)
	_update_pivot()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

func _update_pivot():
	pivot_offset = size / 2

func setup(data: CardData):
	if not data: return
	
	# Manual re-fetch for cases where setup is called before _ready
	if not back_face:
		back_face = get_node_or_null("%BackFace")
		front_face = get_node_or_null("%FrontFace")
		front_template_rect = get_node_or_null("%FrontTemplate")
		back_template_rect = get_node_or_null("%BackTemplate")
		back_icon_rect = get_node_or_null("%BackIcon")
		title_label = get_node_or_null("%TitleLabel")
		card_image_rect = get_node_or_null("%CardImage")
		center_type_icon = get_node_or_null("%CenterTypeIcon")
		card_icon_rect = get_node_or_null("%CardIcon")
		description_label = get_node_or_null("%DescriptionLabel")

	card_type = data.card_id
	
	if title_label: title_label.text = data.name.to_upper()
	if description_label: description_label.text = data.description
	_ensure_front_text_layout()
	if card_image_rect: card_image_rect.texture = data.card_image
	if card_icon_rect: card_icon_rect.texture = data.card_icon
	_apply_center_type_icon(data.type)
	
	_apply_visual_templates(data)


func setup_item(data: ItemData):
	if not data: return
	card_type = data.item_id
	if title_label: title_label.text = data.name.to_upper()
	
	# Generate a stat-focused description for items
	var stat_line = ""
	if data.attack > 0: stat_line += "ATK+%d " % data.attack
	if data.armour > 0: stat_line += "DEF+%d " % data.armour
	if data.hp > 0: stat_line += "HP+%d " % data.hp
	
	if description_label: 
		description_label.text = "[ %s ]\n%s\n%s" % [data.type.to_upper(), stat_line, data.description]
	_ensure_front_text_layout()
	
	if card_image_rect: 
		card_image_rect.texture = data.item_image
	
	# Items use 'Unique' template style by default for high visibility in inventory
	if asset_templates:
		if front_template_rect: 
			front_template_rect.texture = _resolve_front_template_texture("")
		if back_template_rect: 
			back_template_rect.texture = asset_templates.card_back_unique
	
	_apply_center_type_icon(data.type)


func _apply_visual_templates(data: CardData):
	if not asset_templates: return
	
	# Detect Layout: If title_label is null, we are in CardIcon mode (square)
	var is_icon_mode = title_label == null
	var rarity_key = data.rarity.to_lower()
	
	# 1. Skin the Back based on RARITY and LAYOR
	if back_template_rect:
		if is_icon_mode:
			# Use the square icon background for CardIcon.tscn
			back_template_rect.texture = asset_templates.get("card_back_" + rarity_key + "_icon")
		else:
			# Use the full narrative background for Card.tscn
			back_template_rect.texture = asset_templates.get("card_back_" + rarity_key)
			
	if back_icon_rect:
		back_icon_rect.texture = asset_templates.get("card_back_" + rarity_key + "_icon")

	# 2. Front frame by rarity with default fallback.
	if front_template_rect:
		front_template_rect.texture = _resolve_front_template_texture(rarity_key)
	
	# 3. Center icon by type only, shared across all rarities.
	_apply_center_type_icon(data.type)

func _resolve_front_template_texture(rarity_key: String) -> Texture2D:
	var normalized_rarity = rarity_key.strip_edges().to_lower()
	var candidate_paths: Array[String] = []
	if normalized_rarity != "" and normalized_rarity != "default":
		candidate_paths.append(FRONT_ASSETS_ROOT + "card_front_%s.png" % normalized_rarity)
	candidate_paths.append(FRONT_ASSETS_ROOT + "card_front.png")
	return _load_first_texture(candidate_paths)

func _apply_center_type_icon(type_key: String):
	if not center_type_icon:
		return
	var tex = _resolve_center_type_icon_texture(type_key)
	center_type_icon.texture = tex
	center_type_icon.visible = tex != null

func _resolve_center_type_icon_texture(type_key: String) -> Texture2D:
	var card_type_key = type_key.strip_edges().to_lower()
	var alias = TYPE_FILE_ALIASES.get(card_type_key, "")
	var candidate_paths: Array[String] = [
		FRONT_ASSETS_ROOT + "card_front_%s_icon.png" % card_type_key
	]
	# Compatibility paths for current asset naming conventions.
	if alias != "":
		candidate_paths.append(FRONT_ASSETS_ROOT + "card_front_%s_icon.png" % alias)
	candidate_paths.append(FRONT_ASSETS_ROOT + "card_front_%s.png" % card_type_key)
	if alias != "":
		candidate_paths.append(FRONT_ASSETS_ROOT + "card_front_%s.png" % alias)
	candidate_paths.append(FRONT_ASSETS_ROOT + "card_front.png")
	return _load_first_texture(candidate_paths)

func _load_first_texture(paths: Array[String]) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

func _ensure_front_text_layout():
	_lock_label_rect(title_label, TITLE_ORIGINAL_RECT)
	_lock_label_rect(description_label, DESCRIPTION_ORIGINAL_RECT)

func _lock_label_rect(label: Label, rect: Rect2):
	if not label:
		return
	label.layout_mode = 0
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = rect.position.x
	label.offset_top = rect.position.y
	label.offset_right = rect.position.x + rect.size.x
	label.offset_bottom = rect.position.y + rect.size.y

func _on_hover(is_hovering: bool):
	if is_matched or is_face_up: 
		scale = Vector2.ONE
		return
	var target_scale = Vector2(1.05, 1.05) if is_hovering else Vector2.ONE
	z_index = 1 if is_hovering else 0
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(self, "scale", target_scale, 0.1)

func flip():
	if is_matched or is_face_up: return
	is_face_up = true
	z_index = 2
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale:x", 0.0, 0.1)
	tween.tween_callback(func(): 
		if back_face: back_face.visible = false
		if front_face: front_face.visible = true
	)
	tween.tween_property(self, "scale:x", 1.0, 0.1)
	card_flipped.emit(self)

func flip_back():
	if is_matched: return
	is_face_up = false
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale:x", 0.0, 0.1)
	tween.tween_callback(func(): 
		if front_face: front_face.visible = false
		if back_face: back_face.visible = true
		z_index = 0
	)
	tween.tween_property(self, "scale:x", 1.0, 0.1)

func _on_pressed():
	# BLOCK: If BattleScene has physically disabled the button, don't flip
	if disabled: return
	
	if not is_matched and not is_face_up:
		flip()
