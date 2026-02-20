extends TextureButton

# res://features/combat/Card.gd
# Handles individual card flipping and automatic icon normalization for square layouts.
# Now supports cropping non-square source images to centered squares.

signal card_flipped(card_node)

@onready var icon_sprite = %Icon
@onready var back_sprite = %Back

var card_type: String = ""
var is_matched: bool = false
var is_face_up: bool = false
var _cached_tex: Texture2D = null

func _ready():
	pressed.connect(_on_pressed)
	
	# Initial visibility
	icon_sprite.visible = false
	back_sprite.visible = true
	
	# Ensure the pivot is centered for animations
	resized.connect(_update_pivot)
	_update_pivot()
	
	# Subtle 5% hover pop
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	
	# Apply initial cropping/scaling to back sprite if it exists
	if back_sprite and back_sprite.texture:
		_apply_sprite_crop_and_scale(back_sprite, back_sprite.texture)

func _update_pivot():
	# Pivot must be at the center of the square card (e.g., 50, 50)
	pivot_offset = size / 2
	if icon_sprite: icon_sprite.position = size / 2
	if back_sprite: back_sprite.position = size / 2
	
	# Re-apply scaling whenever the card is resized by the GridContainer
	if _cached_tex:
		_apply_icon_scaling(_cached_tex)
	if back_sprite and back_sprite.texture:
		_apply_sprite_crop_and_scale(back_sprite, back_sprite.texture)

func set_icon_texture(tex: Texture2D):
	if not icon_sprite: return
	_cached_tex = tex
	icon_sprite.texture = tex
	_apply_icon_scaling(tex)

func _apply_icon_scaling(tex: Texture2D):
	_apply_sprite_crop_and_scale(icon_sprite, tex)

## Helper to crop a sprite to a centered square and scale it to fit the card
func _apply_sprite_crop_and_scale(sprite: Sprite2D, tex: Texture2D):
	if not sprite or not tex: return
	
	var tex_size = tex.get_size()
	var side = min(tex_size.x, tex_size.y)
	
	# 1. CROP: Enable region to treat the texture as a centered square
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		(tex_size.x - side) / 2.0,
		(tex_size.y - side) / 2.0,
		side,
		side
	)
	
	# 2. SCALE: Fit the cropped square into the card
	var current_card_size = size
	if current_card_size.x == 0: current_card_size = custom_minimum_size
	
	# Target the icon to occupy ~80% of the card's dimensions
	var target_dim = min(current_card_size.x, current_card_size.y) * 0.8
	
	# Calculate scale factor based on the square region width (side)
	var scale_factor = target_dim / side
	sprite.scale = Vector2(scale_factor, scale_factor)

func _on_hover(is_hovering: bool):
	if is_matched or is_face_up: 
		scale = Vector2.ONE
		z_index = 0
		return
	
	var target_scale = Vector2(1.05, 1.05) if is_hovering else Vector2.ONE
	z_index = 1 if is_hovering else 0
		
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, 0.1)

func flip():
	if is_matched or is_face_up: return
	is_face_up = true
	
	z_index = 1
	scale = Vector2.ONE
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale:x", 0.0, 0.1)
	tween.tween_callback(func(): 
		icon_sprite.visible = true
		back_sprite.visible = false
	)
	tween.tween_property(self, "scale:x", 1.0, 0.1)
	card_flipped.emit(self)

func flip_back():
	is_face_up = false
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale:x", 0.0, 0.1)
	tween.tween_callback(func(): 
		icon_sprite.visible = false
		back_sprite.visible = true
		z_index = 0
	)
	tween.tween_property(self, "scale:x", 1.0, 0.1)

func _on_pressed():
	if not is_matched and not is_face_up:
		flip()