shader_type canvas_item;
// Pixel-art top-down water. Every branch has a deliberately small fixed cost:
// low = two sine waves, medium = one value-noise field, high = a second field
// plus sparse glints. `quality_level` is selected by WaterQuality, not prefs.

uniform vec4 col_shallow : source_color = vec4(0.28, 0.56, 0.65, 1.0);
uniform vec4 col_base : source_color = vec4(0.22, 0.46, 0.60, 1.0);
uniform vec4 col_deep : source_color = vec4(0.14, 0.32, 0.47, 1.0);
uniform vec4 col_light : source_color = vec4(0.45, 0.72, 0.76, 1.0);
uniform vec4 col_spark : source_color = vec4(0.78, 0.92, 0.91, 1.0);
uniform vec2 world_offset = vec2(0.0);
uniform float shore_x = 240.0;
uniform int quality_level = 1; // 0 low, 1 medium, 2 high

varying vec2 v_pos;

void vertex() {
	v_pos = VERTEX + world_offset;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	// Whole-pixel coordinates keep the surface in the game's pixel language.
	vec2 p = floor(v_pos);
	float t = TIME;
	float swell = 0.50 + sin(p.x * 0.035 + p.y * 0.019 + t * 0.55) * 0.17;
	swell += sin(p.y * 0.052 - t * 0.38) * 0.10;
	if (quality_level > 0) {
		swell += (value_noise(p * 0.060 + vec2(t * 0.045, -t * 0.026)) - 0.5) * 0.22;
	}
	if (quality_level > 1) {
		swell += (value_noise(p * 0.135 + vec2(-t * 0.075, t * 0.055)) - 0.5) * 0.11;
	}
	swell = clamp(swell, 0.0, 1.0);

	// Four discrete depth bands make the quay edge readable, without a gradient.
	float depth = clamp((p.x - shore_x) / 72.0, 0.0, 1.0);
	float bands = 3.0 + float(quality_level > 1);
	depth = floor(depth * bands) / bands;
	vec4 col = mix(col_shallow, col_deep, depth);
	if (swell > 0.57) col = mix(col, col_light, 0.42);
	if (swell < 0.34) col = mix(col, col_base, 0.50);

	// One sparse horizontal ripple field is always present. High adds a shorter,
	// counter-moving field; no loops or per-pixel texture reads are involved.
	float row = floor(p.y / 6.0);
	float dash = mod(p.x + t * (4.0 + mod(row, 3.0)) + row * 17.0, 31.0);
	if (mod(p.y, 6.0) < 1.0 && dash < 5.0 && swell > 0.43) {
		col = mix(col, col_light, 0.70);
	}
	if (quality_level > 1) {
		float short_dash = mod(p.x - t * 8.0 + row * 9.0, 47.0);
		if (mod(p.y + 2.0, 9.0) < 1.0 && short_dash < 3.0 && swell > 0.61) {
			col = mix(col, col_spark, 0.55);
		}
	}

	// Sparkles are intentionally rare and entirely absent on low quality.
	if (quality_level > 0 && hash(floor(p / 3.0) + floor(t * 3.0)) > (0.9985 - float(quality_level) * 0.0005) && swell > 0.64) {
		col = col_spark;
	}
	COLOR = col;
}
