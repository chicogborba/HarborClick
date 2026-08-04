shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.24, 0.26, 0.30, 0.92);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	COLOR = vec4(outline_color.rgb, outline_color.a * source.a);
}
