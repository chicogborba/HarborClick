shader_type canvas_item;
// The lens the port is seen through: the corners of the screen sink a little
// into navy, so the eye is held on the quay and the steel HUD has something to
// sit against. Banded and dithered on the game's own pixel grid — a smooth
// radial gradient over pixel art is the one thing that would look like a filter.

uniform float px = 2.0;
uniform float strength = 0.34;
uniform vec3 tint : source_color = vec3(0.03, 0.06, 0.13);

float bayer(vec2 p) {
	vec2 q = mod(floor(p), 4.0);
	float i = q.x + q.y * 4.0;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[int(i)] + 0.5) / 16.0;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = dot(c * vec2(0.82, 0.94), c * vec2(0.82, 0.94));
	float v = smoothstep(0.42, 1.5, d);
	float bands = 5.0;
	float stepped = floor(v * bands + bayer(FRAGCOORD.xy / px)) / bands;
	COLOR = vec4(tint, clamp(stepped, 0.0, 1.0) * strength);
}
