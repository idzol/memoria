extends Resource
class_name ObjectData

@export_group("Identity")
@export var object_id: String = ""
@export var name: String = "Unknown Object"

@export_group("Visuals")
@export var object_image: Texture2D
@export var hframes: int = 8
@export var vframes: int = 1
var _total_frames: int = 8
@export var total_frames: int = 8:
	set(value):
		_total_frames = value
	get:
		return _total_frames
@export var frame_speed: float = 0.12

@export_group("Interaction")
@export_range(2, 8, 1) var object_size: int = 4
@export var object_items: Array[String] = []
@export var object_probability: Array[float] = []
