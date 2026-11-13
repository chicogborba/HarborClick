shader_type canvas_item;
// The dim behind an open board.
//
// A flat dark wash says "something is in front". This says "the port is out of
// focus": the world behind the board drops to chunkier pixels, loses most of
// its colour and sinks into the deck's navy, so a dark panel still separates
// from a dark scene. Strength rides on the rect's own alpha, which is what
// `UiTheme.pop_open` already fades, so the mosaic grows in with the board and
// needs no clock of its own.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// How many physical pixels one mosaic step is. Set from the stretch scale.
uniform float px = 2.0;

void fragment() {
	float k = clamp(COLOR.a, 0.0, 1.0);
	float cell = max(1.0, floor(1.0 + k * 3.6) * px - (px - 1.0));
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv = (floor(SCREEN_UV * res / cell) + 0.5) * cell / res;
	vec3 world = texture(screen_tex, uv).rgb;
	float luma = dot(world, vec3(0.299, 0.587, 0.114));
	world = mix(world, vec3(luma) * vec3(0.78, 0.9, 1.12), k * 0.7);
	COLOR = vec4(mix(world, COLOR.rgb, k * 0.9), 1.0);
}
