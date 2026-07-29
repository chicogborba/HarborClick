shader_type canvas_item;
// Vertical gradient with quantized bands + bayer dither = retro sky.

uniform vec4 top_color : source_color = vec4(0.36, 0.61, 0.82, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.66, 0.82, 0.89, 1.0);
uniform float bands = 14.0;

void fragment() {
	float t = UV.y;
	vec2 px = floor(FRAGCOORD.xy);
	float d = (mod(px.x, 2.0) + mod(px.y, 2.0) * 2.0) / 4.0 - 0.375;
	t = clamp(t + d / bands, 0.0, 1.0);
	t = floor(t * bands) / bands;
	COLOR = mix(top_color, bottom_color, t);
}
