shader_type canvas_item;
// Two drifting bands of soft fog, pixel-quantized so it matches the art.

uniform vec4 fog_color : source_color = vec4(0.86, 0.90, 0.94, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float speed = 6.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
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
	vec2 p = floor(FRAGCOORD.xy / 2.0);          // 2px chunky noise
	float t = TIME * speed;
	float n1 = noise(p * 0.022 + vec2(t * 0.08, 0.0));
	float n2 = noise(p * 0.011 + vec2(-t * 0.04, t * 0.01));
	float density = clamp(n1 * 0.55 + n2 * 0.55, 0.0, 1.0);
	// A light haze plus drifting banks. It used to reach 64% white and wash
	// the whole port out to grey for the length of a foggy day; fog is a mood,
	// the containers still have to read through it.
	float banks = floor(density * 4.0) / 4.0;
	float a = (0.06 + banks * 0.20) * amount;
	COLOR = vec4(fog_color.rgb, clamp(a, 0.0, 1.0));
}
