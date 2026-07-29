shader_type canvas_item;
// Top-down harbour water: slow swell, drifting ripple dashes, sparkles.
// Pixel-quantized so it sits inside the pixel-art look.

uniform vec4 col_deep : source_color = vec4(0.17, 0.38, 0.51, 1.0);
uniform vec4 col_base : source_color = vec4(0.24, 0.49, 0.62, 1.0);
uniform vec4 col_light : source_color = vec4(0.36, 0.62, 0.72, 1.0);
uniform vec4 col_spark : source_color = vec4(0.66, 0.84, 0.88, 1.0);
uniform vec2 world_offset = vec2(0.0);

varying vec2 v_pos;

void vertex() {
	v_pos = VERTEX + world_offset;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = floor(v_pos);
	float t = TIME;

	// large slow swell
	float swell = vnoise(p * 0.045 + vec2(t * 0.06, t * 0.03));
	swell += vnoise(p * 0.11 + vec2(-t * 0.04, t * 0.05)) * 0.5;
	swell = swell / 1.5;

	vec4 col = col_base;
	if (swell < 0.40) col = col_deep;
	else if (swell > 0.60) col = col_light;

	// ripple dashes: short horizontal strokes drifting slowly
	float band = floor(p.y / 5.0);
	float ph = mod(p.x + t * (6.0 + mod(band, 3.0) * 2.0) + band * 13.0, 26.0);
	if (mod(p.y, 5.0) < 1.0 && ph < 4.0 && swell > 0.45) {
		col = mix(col, col_light, 0.9);
	}

	// glints
	float g = hash(p + floor(t * 6.0) * 0.31);
	if (g > 0.9975 && swell > 0.5) col = col_spark;

	COLOR = col;
}
