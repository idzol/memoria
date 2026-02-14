extends TextureButton

# res://features/combat/Card.gd
# Handles individual card flipping and automatic icon normalization.

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

func _update_pivot():
	pivot_offset = size / 2
	if icon_sprite: icon_sprite.position = size / 2
	if back_sprite: back_sprite.position = size / 2
	
	# Re-apply scaling whenever the card is resized by the GridContainer
	if _cached_tex:
		_apply_icon_scaling(_cached_tex)

func set_icon_texture(tex: Texture2D):
	if not icon_sprite: return
	_cached_tex = tex
	icon_sprite.texture = tex
	_apply_icon_scaling(tex)

func _apply_icon_scaling(tex: Texture2D):
	var current_card_size = size
	if current_card_size.x == 0: current_card_size = custom_minimum_size
	
	var target_dim = min(current_card_size.x, current_card_size.y) * 1.6
	
	var tex_size = tex.get_size()
	var max_tex_dim = max(tex_size.x, tex_size.y)
	
	# Calculate the scale required to bring the largest side down to our target
	var scale_factor = target_dim / max_tex_dim
	icon_sprite.scale = Vector2(scale_factor, scale_factor)

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
