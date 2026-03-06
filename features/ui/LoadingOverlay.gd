extends Control

# res://features/ui/LoadingOverlay.gd
# Handles the visual state of the global loading modal.
# Updated: Faster visibility to prevent "late-flashing" during transitions.

@onready var desc_label = %DescriptionLabel
@onready var progress_bar = %ProgressBar
@onready var spinner_anchor = %SpinnerAnchor

func _ready():
	# Start fully visible immediately so it appears on the same frame as instantiate()
	# Fading in is nice for long loads, but for map generation we need instant feedback.
	modulate.a = 1.0

func set_loading_info(description: String, progress: float = -1.0):
	if desc_label:
		desc_label.text = description
	
	if progress_bar:
		if progress < 0:
			progress_bar.indeterminate = true
		else:
			progress_bar.indeterminate = false
			# Convert 0.0-1.0 to 0-100
			progress_bar.value = progress * 100

func close():
	# Fade out is fine since the next scene is already loaded.
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)