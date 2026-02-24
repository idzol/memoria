extends Resource
class_name MapAssetData

# res://data/resources/MapAssetData.gd
# Specialized resource to track global Map UI assets for auditing and dynamic loading.

@export_group("Map Icons")
@export var map_icon_home: Texture2D
@export var map_icon_battle: Texture2D
@export var map_icon_shop: Texture2D
@export var map_icon_rest: Texture2D
@export var map_icon_event: Texture2D
@export var map_icon_boss: Texture2D
@export var map_icon_mystery: Texture2D

@export_group("Biome Backgrounds")
@export var map_town_background: Texture2D
@export var map_forest_background: Texture2D
@export var map_ice_caves_background: Texture2D
@export var map_desert_background: Texture2D
@export var map_swamp_background: Texture2D
@export var map_abyss_background: Texture2D
@export var map_void_background: Texture2D
@export var map_the_core_background: Texture2D

@export_group("Biome Grids")
@export var map_town_grid: Texture2D
@export var map_forest_grid: Texture2D
@export var map_ice_caves_grid: Texture2D
@export var map_desert_grid: Texture2D
@export var map_swamp_grid: Texture2D
@export var map_abyss_grid: Texture2D
@export var map_void_grid: Texture2D
@export var map_the_core_grid: Texture2D