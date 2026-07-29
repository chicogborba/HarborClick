shader_type canvas_item;
// Pixel-quantized retro water: depth dither, drifting wave dashes, sparkles.

uniform vec4 col_deep : source_color = vec4(0.09, 0.2, 0.33, 1.0);
uniform vec4 col_base : source_color = vec4(0.14, 0.31, 0.46, 1.0);
uniform vec4 col_light : source_color = vec4(0.23, 0.43, 0.6, 1.0);
uniform vec4 col_spark : source_color = vec4(0.47, 0.7, 0.79, 1.0);
uniform float depth_px = 56.0;      // rect height in px, for depth gradient
uniform vec2 pos_offset = vec2(0.0); // world offset so stacked rects align

varying vec2 v_pos;

void vertex() {
	v_pos = VERTEX + pos_offset;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = floor(v_pos);
	float ti = floor(TIME * 8.0); // 8 fps steps, retro feel

	// depth: base -> deep with 2px checker dither transition
	float depth = clamp((p.y - pos_offset.y) / depth_px, 0.0, 1.0);
	float dth = mod(p.x + p.y, 2.0);
	vec4 col = col_base;
	if (depth > 0.30 + 0.12 * dth) col = mix(col_base, col_deep, 0.55);
	if (depth > 0.62 + 0.12 * dth) col = col_deep;

	// wave dashes on some rows, drifting at per-band speeds/directions
	float band = floor(p.y / 7.0);
	float row = mod(p.y, 7.0);
	if (row < 2.0) {
		float dir = (mod(band, 2.0) < 1.0) ? 1.0 : -0.6;
		float ph = mod(p.x + ti * dir + band * 11.0, 18.0);
		if (ph < 5.0 - row * 2.0) col = mix(col, col_light, 0.85);
	}

	// sparkles
	float h = hash(p + vec2(mod(ti, 64.0) * 0.37, 0.0));
	if (h > 0.9965) col = col_spark;

	COLOR = col;
}
