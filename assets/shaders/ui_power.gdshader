shader_type canvas_item;
render_mode blend_add;
// A panel coming on: one bright line runs down the board the moment it lands,
// with the glow it leaves fading behind it. Additive, so it lights what is
// under it rather than covering it.

uniform float progress = 0.0;
uniform float height = 200.0;
uniform vec3 tint : source_color = vec3(0.55, 0.95, 0.9);

void fragment() {
	float y = floor(UV.y * height);
	float head = floor(progress * (height + 40.0));
	float behind = head - y;
	float line = step(0.0, behind) * step(behind, 1.0);
	float trail = step(0.0, behind) * clamp(1.0 - behind / 46.0, 0.0, 1.0);
	// two-pixel scanline rhythm in the trail
	trail *= 0.55 + 0.45 * step(1.0, mod(y, 2.0));
	float fade = 1.0 - progress;
	float a = (line * 0.55 + trail * 0.16) * fade + 0.07 * fade * fade;
	COLOR = vec4(tint * a, 1.0);
}
