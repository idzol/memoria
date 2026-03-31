shader_type canvas_item;

uniform float pad_x = 0.005555556;
uniform float pad_y = 0.005555556;

void fragment() {
	float left = pad_x;
	float right = 1.0 - pad_x;
	float top = pad_y;
	float bottom = 1.0 - pad_y;
	float mid_x = 0.5;
	float upper_y = mix(top, bottom, 0.25);
	float lower_y = mix(top, bottom, 0.75);

	if (UV.x < left || UV.x > right || UV.y < top || UV.y > bottom) {
		discard;
	}

	float top_bound = top;
	float bottom_bound = bottom;
	if (UV.x < mid_x) {
		float t_left = (UV.x - left) / max(0.0001, mid_x - left);
		top_bound = mix(upper_y, top, t_left);
		bottom_bound = mix(lower_y, bottom, t_left);
	} else if (UV.x > mid_x) {
		float t_right = (UV.x - mid_x) / max(0.0001, right - mid_x);
		top_bound = mix(top, upper_y, t_right);
		bottom_bound = mix(bottom, lower_y, t_right);
	}

	if (UV.y < top_bound || UV.y > bottom_bound) {
		discard;
	}

	COLOR = texture(TEXTURE, UV) * COLOR;
}
