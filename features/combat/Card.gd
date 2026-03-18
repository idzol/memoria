extends TextureButton

# res://features/combat/Card.gd
# Advanced card controller using Rarity for backs and Type for fronts.
# Updated: Detects layout to load correct background sizes and prevents click-spam.

signal card_flipped(card_node)

# Preload required custom types
#const CardAssetData = preload("res://data/resources/card_asset_data.gd")
#const CardData = preload("res://data/resources/card_data.gd")

var asset_templates: CardAssetData = preload("res://data/card_asset_data.tres")

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
const OBJECT_BACK_ICON_PATH := "res://assets/cards/back_icon/card_back_object_icon.png"
const CARD_BASE_SIZE := Vector2(160.0, 240.0)
const TYPE_FILE_ALIASES := {
	"armor": "defend",
	"utility": "prepare",
	"charge": "spell"
}
const TITLE_ORIGINAL_RECT := Rect2(18.0, 15.0, 124.0, 14.0)
const DESCRIPTION_ORIGINAL_RECT := Rect2(18.0, 166.0, 124.0, 52.0)
const CARD_IMAGE_ORIGINAL_OFFSETS := Vector4(18.0, 30.0, -18.0, -70.0)
const CENTER_ICON_ORIGINAL_SIZE := Vector2(28.0, 28.0)
const CENTER_ICON_ORIGINAL_OFFSETS := Vector4(-14.0, -13.920013, 14.0, 14.079987)
const TITLE_BASE_FONT_SIZE := 14
const DESCRIPTION_BASE_FONT_SIZE := 11
const TITLE_MIN_FONT_SIZE := 8
const DESCRIPTION_MIN_FONT_SIZE := 7

func _ready():
	pressed.connect(_on_pressed)
	resized.connect(_on_card_resized)
	_on_card_resized()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

func _on_card_resized():
	pivot_offset = size / 2
	_apply_scaled_front_layout()

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
	
	var localized_name = LocalizationManager.localized_resource_name(data, data.name)
	if title_label: title_label.text = localized_name.to_upper()
	if description_label: description_label.text = data.description
	_apply_scaled_front_layout()
	if card_image_rect: card_image_rect.texture = data.card_image
	if card_icon_rect: card_icon_rect.texture = data.card_icon
	_apply_center_type_icon(data.type)
	
	_apply_visual_templates(data)
	_apply_forced_back_texture()


func setup_item(data: ItemData):
	if not data: return
	card_type = data.item_id
	var localized_name = LocalizationManager.localized_resource_name(data, data.name)
	if title_label: title_label.text = localized_name.to_upper()
	
	# Generate a stat-focused description for items
	var stat_line = ""
	if data.attack > 0: stat_line += "ATK+%d " % data.attack
	if data.armour > 0: stat_line += "DEF+%d " % data.armour
	if data.hp > 0: stat_line += "HP+%d " % data.hp
	
	if description_label: 
		description_label.text = "[ %s ]\n%s\n%s" % [data.type.to_upper(), stat_line, data.description]
	_apply_scaled_front_layout()
	
	if card_image_rect: 
		card_image_rect.texture = data.item_image
	if card_icon_rect:
		card_icon_rect.texture = data.item_icon
	
	# Items use 'Unique' template style by default for high visibility in inventory
	if asset_templates:
		if front_template_rect: 
			front_template_rect.texture = asset_templates.card_front_unique if asset_templates.card_front_unique else _resolve_front_template_texture("unique")
		if back_template_rect: 
			back_template_rect.texture = asset_templates.card_back_unique
	
	_apply_center_type_icon(data.type)
	_apply_forced_back_texture()


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
		front_template_rect.texture = _resolve_card_front_texture(data)
	
	# 3. Center icon by type only, shared across all rarities.
	_apply_center_type_icon(data.type)

func _resolve_card_front_texture(data: CardData) -> Texture2D:
	if data == null:
		return _resolve_front_template_texture("")
	if _is_enemy_card(data):
		if asset_templates and asset_templates.card_front_enemy:
			return asset_templates.card_front_enemy
		return _resolve_front_template_texture("enemy")
	var rarity_key = data.rarity.strip_edges().to_lower()
	if asset_templates:
		match rarity_key:
			"common":
				if asset_templates.card_front_common:
					return asset_templates.card_front_common
			"uncommon":
				if asset_templates.card_front_uncommon:
					return asset_templates.card_front_uncommon
			"rare":
				if asset_templates.card_front_rare:
					return asset_templates.card_front_rare
			"epic":
				if asset_templates.card_front_epic:
					return asset_templates.card_front_epic
			"unique":
				if asset_templates.card_front_unique:
					return asset_templates.card_front_unique
		if asset_templates.card_front_default:
			return asset_templates.card_front_default
	return _resolve_front_template_texture(rarity_key)

func _is_enemy_card(data: CardData) -> bool:
	if data == null:
		return false
	var normalized_id = data.card_id.strip_edges().to_lower()
	return normalized_id.begins_with("enemy_")

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

func _apply_forced_back_texture():
	var forced_path = str(get_meta("forced_back_texture_path", ""))
	if forced_path == "":
		return
	if not ResourceLoader.exists(forced_path):
		return
	var forced_tex = load(forced_path) as Texture2D
	if forced_tex == null:
		return
	if back_template_rect:
		back_template_rect.texture = forced_tex
	if back_icon_rect:
		back_icon_rect.texture = forced_tex
		back_icon_rect.visible = false

func _apply_scaled_front_layout():
	var ratio = _get_card_layout_ratio()
	_lock_label_rect(title_label, _scaled_rect(TITLE_ORIGINAL_RECT, ratio))
	_lock_label_rect(description_label, _scaled_rect(DESCRIPTION_ORIGINAL_RECT, ratio))
	if title_label:
		title_label.add_theme_font_size_override("font_size", max(TITLE_MIN_FONT_SIZE, roundi(float(TITLE_BASE_FONT_SIZE) * ratio)))
	if description_label:
		description_label.add_theme_font_size_override("font_size", max(DESCRIPTION_MIN_FONT_SIZE, roundi(float(DESCRIPTION_BASE_FONT_SIZE) * ratio)))
	if card_image_rect:
		card_image_rect.offset_left = CARD_IMAGE_ORIGINAL_OFFSETS.x * ratio
		card_image_rect.offset_top = CARD_IMAGE_ORIGINAL_OFFSETS.y * ratio
		card_image_rect.offset_right = CARD_IMAGE_ORIGINAL_OFFSETS.z * ratio
		card_image_rect.offset_bottom = CARD_IMAGE_ORIGINAL_OFFSETS.w * ratio
	if center_type_icon:
		var icon_size = CENTER_ICON_ORIGINAL_SIZE * ratio
		center_type_icon.custom_minimum_size = icon_size
		center_type_icon.offset_left = CENTER_ICON_ORIGINAL_OFFSETS.x * ratio
		center_type_icon.offset_top = CENTER_ICON_ORIGINAL_OFFSETS.y * ratio
		center_type_icon.offset_right = CENTER_ICON_ORIGINAL_OFFSETS.z * ratio
		center_type_icon.offset_bottom = CENTER_ICON_ORIGINAL_OFFSETS.w * ratio

func _get_card_layout_ratio() -> float:
	var width_ratio = size.x / CARD_BASE_SIZE.x if CARD_BASE_SIZE.x > 0.0 else 1.0
	var height_ratio = size.y / CARD_BASE_SIZE.y if CARD_BASE_SIZE.y > 0.0 else 1.0
	return clamp(min(width_ratio, height_ratio), 0.45, 2.6)

func _scaled_rect(rect: Rect2, ratio: float) -> Rect2:
	return Rect2(rect.position * ratio, rect.size * ratio)

func _lock_label_rect(label: Label, rect: Rect2):
	if not label:
		return
	label.set("layout_mode", 1)
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
