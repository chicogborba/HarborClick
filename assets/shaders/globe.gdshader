shader_type canvas_item;
// The planet, in pixels.
//
// The world map is an equirectangular sprite; this projects it onto a sphere
// seen from far away (orthographic), one *globe pixel* at a time: UV is snapped
// to a `pixels`-wide grid before anything is computed, so the globe is pixel
// art at any size instead of a smooth render with pixel art pasted on it.
//
// `lon0`/`lat0` are the point facing the viewer, in radians. The view frame is
// x right, y up, z toward the eye; a globe point is the view point rotated by
// the tilt about x and then by the longitude about y — `Globe.project` in
// GDScript is the exact inverse, so pins land on the coast they name.

uniform sampler2D world_map : filter_nearest, repeat_enable;
uniform sampler2D countries : filter_nearest, repeat_enable;
uniform float lon0 = 0.0;
uniform float lat0 = 0.0;
uniform float pixels = 112.0;
uniform int active_country = 1;
uniform vec4 active_tint : source_color = vec4(1.0, 0.80, 0.30, 1.0);
uniform vec4 other_tint : source_color = vec4(0.98, 0.94, 0.84, 1.0);
uniform vec4 border : source_color = vec4(0.10, 0.08, 0.12, 1.0);
uniform vec4 rim : source_color = vec4(0.55, 0.82, 0.96, 1.0);


int country_at(vec2 uv) {
	return int(round(texture(countries, uv).r * 255.0 / 60.0));
}

void fragment() {
	vec2 cell = (floor(UV * pixels) + 0.5) / pixels;
	vec2 g = cell * 2.0 - 1.0;
	float r2 = dot(g, g);
	if (r2 > 1.0) {
		// Two pixels of atmosphere round the limb, then space.
		float d = sqrt(r2);
		float halo = (d - 1.0) * pixels * 0.5;
		COLOR = halo < 2.0 ? vec4(rim.rgb, 0.55 - halo * 0.22) : vec4(0.0);
	} else {
		vec3 v = vec3(g.x, -g.y, sqrt(1.0 - r2));
		// Undo the tilt about x, then the longitude about y.
		vec3 t = vec3(v.x, v.y * cos(lat0) + v.z * sin(lat0),
			-v.y * sin(lat0) + v.z * cos(lat0));
		vec3 p = vec3(t.x * cos(lon0) + t.z * sin(lon0), t.y,
			-t.x * sin(lon0) + t.z * cos(lon0));
		float lat = asin(clamp(p.y, -1.0, 1.0));
		float lon = atan(p.x, p.z);
		vec2 uv = vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI);
		vec3 col = texture(world_map, uv).rgb;
		int id = country_at(uv);
		if (id > 0) {
			col = mix(col, id == active_country ? active_tint.rgb : other_tint.rgb,
				id == active_country ? 0.42 : 0.22);
			// The border: one texel away in any direction is another country.
			vec2 texel = vec2(1.0 / 288.0, 1.0 / 144.0);
			if (country_at(uv + vec2(texel.x, 0.0)) != id
					|| country_at(uv - vec2(texel.x, 0.0)) != id
					|| country_at(uv + vec2(0.0, texel.y)) != id
					|| country_at(uv - vec2(0.0, texel.y)) != id) {
				col = id == active_country ? vec3(1.0, 0.92, 0.55) : border.rgb;
			}
		}
		// Sun from the upper left, in three hard bands, and a lit limb.
		vec3 light = normalize(vec3(-0.55, 0.5, 0.67));
		float lit = dot(v, light);
		float band = lit > 0.45 ? 1.06 : (lit > 0.0 ? 0.9 : (lit > -0.4 ? 0.7 : 0.55));
		col *= band;
		if (r2 > 0.9) {
			col = mix(col, rim.rgb, 0.3);
		}
		COLOR = vec4(col, 1.0);
	}
}
