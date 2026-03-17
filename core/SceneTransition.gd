extends Node

const DEFAULT_FADE_DURATION := 0.35
const TRANSITION_LAYER := 200

var _overlay_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _transition_in_progress: bool = false

func change_scene_to_file(scene_path: String, fade_duration: float = DEFAULT_FADE_DURATION):
	if scene_path == "":
		return
	if _transition_in_progress:
		return
	_transition_in_progress = true
	_ensure_overlay()
	_fade_rect.color = Color(0, 0, 0, 0)
	_overlay_layer.visible = true

	var fade_out = create_tween()
	fade_out.tween_property(_fade_rect, "color:a", 1.0, fade_duration)
	await fade_out.finished

	var tree = get_tree()
	var err = tree.change_scene_to_file(scene_path)
	if err != OK:
		push_warning("SceneTransition: Failed to change scene to %s (error %d)" % [scene_path, err])
		_finish_transition()
		return

	await tree.process_frame
	await tree.process_frame

	var fade_in = create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, fade_duration)
	await fade_in.finished
	_finish_transition()

func _ensure_overlay():
	if _overlay_layer and is_instance_valid(_overlay_layer) and _fade_rect and is_instance_valid(_fade_rect):
		if _overlay_layer.get_parent() != get_tree().root:
			get_tree().root.add_child(_overlay_layer)
		return

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = TRANSITION_LAYER
	_overlay_layer.visible = false
	get_tree().root.add_child(_overlay_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_fade_rect)

func _finish_transition():
	if _fade_rect and is_instance_valid(_fade_rect):
		_fade_rect.color = Color(0, 0, 0, 0)
	if _overlay_layer and is_instance_valid(_overlay_layer):
		_overlay_layer.visible = false
	_transition_in_progress = false
