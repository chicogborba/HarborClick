shader_type canvas_item;
// The ground's weathering pass, run once per bake (GroundSurface, UPDATE_ONCE).
//
// GroundBaker composes the terminal out of 16 px tiles, which is the right way
// to place paint and the wrong way to make a surface: every tile is the same
// tile, so asphalt read as a quilt and the apron as bathroom tiles. Once the
// water became a lit, continuous surface the ground looked like a board game
// next to it. This pass gives the ground what tiles cannot: variation at the
// scale of a whole terminal, cast concrete slabs at the size a quay is really
// poured, patched and stained asphalt, hairline cracks, and grass that grows in
// clumps — all hashed on world pixels and quantised through an ordered dither,
// so it stays in the game's pixel language and costs nothing per frame.
//
// Paint is protected: a pixel that is saturated or far from its zone's tone is
// a marking, and only the macro tone touches it (paint fades with the slab).

uniform vec2 ground_size = vec2(320.0, 1000.0);
uniform float paved_top = 30.0;
uniform float paved_bottom = 900.0;
uniform float yard_x0 = 14.0;
uniform float road_x0 = 16.0;
uniform float road_x1 = 44.0;
uniform float quay_x0 = 196.0;
uniform float water_x0 = 240.0;
// The two crane rails under the portainers' bogies.
uniform vec2 crane_rails = vec2(204.0, 224.0);
// Rows the branch line's corridor occupies (ballast, not pavement).
uniform vec2 rail_band = vec2(-1.0, -1.0);

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

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

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (BAYER[x + y * 4] + 0.5) / 16.0;
}

// A brightness multiplier, quantised into 1.5% steps with an ordered dither: a
// smooth multiply would smear the grain the tiles carry into a soft gradient,
// and coarser steps showed the dither itself as checkerboard on the concrete.
float stepped(float m, vec2 p) {
	return floor(m * 64.0 + bayer(p)) / 64.0;
}

float saturation(vec3 c) {
	return max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a < 0.5) {
		COLOR = src;
	} else {
		vec2 p = floor(UV * ground_size);
		vec3 c = src.rgb;
		bool paint = saturation(c) > 0.16 || max(c.r, max(c.g, c.b)) > 0.86;
		bool paved = p.y >= paved_top - 2.0 && p.y < paved_bottom && p.x >= yard_x0;
		bool rail = p.y >= rail_band.x && p.y < rail_band.y;
		bool quay = p.x >= quay_x0 && p.x < water_x0;
		bool road = p.x >= road_x0 && p.x < road_x1 && p.y < paved_bottom;
		bool grass = !paved && !road && !quay;
		bool asphalt = (paved || road) && !quay && !rail;

		// --- terminal-scale tone: no two stretches of ground the same shade ---
		float macro = value_noise(p * 0.021) * 0.65 + value_noise(p * 0.067 + 17.0) * 0.35;
		float m = 1.0 + (macro - 0.5) * 0.10;

		if (asphalt && !paint) {
			// Patched repairs: a newer, darker rectangle with a sealed seam.
			vec2 pcell = floor(p / vec2(42.0, 30.0));
			float pick = hash(pcell + 3.0);
			if (pick > 0.86) {
				vec2 lo = pcell * vec2(42.0, 30.0) + floor(vec2(hash(pcell + 7.0), hash(pcell + 9.0)) * vec2(16.0, 10.0)) + 2.0;
				vec2 hi = lo + 10.0 + floor(vec2(hash(pcell + 11.0), hash(pcell + 13.0)) * vec2(16.0, 12.0));
				if (p.x >= lo.x && p.y >= lo.y && p.x < hi.x && p.y < hi.y) {
					bool seam = p.x == lo.x || p.y == lo.y || p.x == hi.x - 1.0 || p.y == hi.y - 1.0;
					m *= seam ? 0.84 : 0.94;
				}
			}
			// Oil dropped where vehicles stand: soft dark blots, dithered edge.
			vec2 ocell = floor(p / 18.0);
			if (hash(ocell + 21.0) > 0.86) {
				vec2 centre = ocell * 18.0 + 4.0 + floor(vec2(hash(ocell), hash(ocell.yx + 5.0)) * 10.0);
				float r = 1.5 + hash(ocell + 31.0) * 2.5;
				float d = length((p - centre) * vec2(1.0, 1.4)) / r;
				if (d < 1.0 + bayer(p) * 0.35) m *= d < 0.5 ? 0.76 : 0.86;
			}
			// Hairline cracks: the zero-crossing of one noise, gated by another,
			// so they meander in a few places instead of crazing everywhere.
			float crack = abs(value_noise(p * 0.085 + 40.0) - 0.5);
			if (crack < 0.016 && value_noise(p * 0.018 + 70.0) > 0.62) m *= 0.74;
			// Aggregate catching the light.
			if (hash(p + 0.37) > 0.986) m *= 1.12;
			// Tyre-polished wheel paths down the carriageway.
			if (road) {
				float lane = (p.x - road_x0) / max(road_x1 - road_x0, 1.0);
				float path = min(abs(lane - 0.22), min(abs(lane - 0.40),
					min(abs(lane - 0.60), abs(lane - 0.78))));
				if (path < 0.045) m *= 0.93;
			}
		}

		if (quay) {
			// Cast slabs, two across the apron, each poured on its own day.
			vec2 slab = vec2((water_x0 - quay_x0) * 0.5, 28.0);
			vec2 local = p - vec2(quay_x0, paved_top);
			vec2 cell = floor(local / slab);
			vec2 in_slab = local - cell * slab;
			if (!paint) {
				m *= 0.95 + hash(cell + 51.0) * 0.08;
				// Rust bleeding out of the joints, and a darker wet band seaward.
				if (in_slab.y < 3.0 && hash(vec2(cell.y, floor(p.x / 3.0))) > 0.7) m *= 0.92;
				if (p.x > water_x0 - 10.0) m *= 0.94 - (p.x - (water_x0 - 10.0)) * 0.004;
				if (hash(p + 0.71) > 0.988) m *= 0.88;
			}
			// The joints: a dark sawn line with a lit lip after it.
			if (in_slab.x < 1.0 || in_slab.y < 1.0) m *= 0.80;
			else if (in_slab.x < 2.0 || in_slab.y < 2.0) m *= 1.05;
			// Crane rails set into the slab: a dark channel and a steel crown.
			for (int i = 0; i < 2; i++) {
				float rx = i == 0 ? crane_rails.x : crane_rails.y;
				float dx = p.x - rx;
				if (abs(dx) < 1.5) {
					c = mix(vec3(0.20, 0.20, 0.22), vec3(0.62, 0.62, 0.64),
						dx > -0.5 && dx < 0.5 ? 1.0 : 0.0);
					paint = true;
					m = 1.0 + (macro - 0.5) * 0.08;
					if (dx > -0.5 && dx < 0.5 && hash(vec2(rx, floor(p.y / 2.0))) > 0.8) m *= 1.12;
				}
			}
		}

		if (grass) {
			// Clumps and bare patches, and the odd flower.
			float clump = value_noise(p * 0.11 + 90.0);
			m *= 0.92 + clump * 0.16;
			if (hash(p + 0.13) > 0.994) {
				c = hash(p + 0.5) > 0.5 ? vec3(0.95, 0.90, 0.62) : vec3(0.92, 0.92, 0.96);
				m = 1.0;
			}
		}

		if (asphalt && !paint) {
			// A touch cooler than the warm tile: blacktop against beige concrete
			// and coloured steel, rather than one brown.
			float lum = dot(c, vec3(0.3, 0.55, 0.15));
			c = mix(c, vec3(lum * 0.94, lum * 0.98, lum * 1.05), 0.30);
		}

		if (paint) {
			// Markings fade and scuff with the surface they are on.
			m = 1.0 + (m - 1.0) * 0.6;
			if (!quay && hash(floor(p / 2.0) + 0.9) > 0.93) m *= 0.90;
		}
		COLOR = vec4(c * stepped(m, p), src.a);
	}
}
