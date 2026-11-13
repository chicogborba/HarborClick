shader_type canvas_item;
// The gloss that crosses an amber key.
//
// Every key that can be pressed for something good wears this, and they are all
// driven by the one clock and the one screen-space diagonal, so the light
// crosses the whole interface as a single sweep instead of each key blinking to
// itself. Stepped to the pixel grid: a smooth gradient over pixel art is the
// one thing here that would look pasted on.

uniform float period = 3.4;
uniform float px = 2.0;
uniform float strength = 0.24;

void fragment() {
	float d = floor((FRAGCOORD.x + FRAGCOORD.y * 0.55) / px);
	float head = fract(TIME / period) * period * 520.0;
	float off = head - d;
	float band = step(0.0, off) * step(off, 9.0);
	band += 0.55 * step(13.0, off) * step(off, 16.0);
	// Only the lit face takes the gloss: the dark label and the ink edge stay.
	float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb += band * strength * smoothstep(0.38, 0.62, luma);
}
