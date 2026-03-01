extends Resource
class_name UIAssetData

# res://data/resources/ui_asset_data.gd
# Centralized registry for major UI textures (backgrounds, frames, menu panels).

@export_group("Backgrounds")
@export var main_menu_bg: Texture2D
@export var character_screen_bg: Texture2D
@export var map_overlay_bg: Texture2D

@export_group("Panels & Frames")
@export var login_modal_frame: Texture2D
@export var general_button_normal: Texture2D
@export var general_button_hover: Texture2D