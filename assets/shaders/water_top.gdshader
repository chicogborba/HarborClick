shader_type canvas_item;
// Pixel-art harbour water, seen from above — fourth pass.
//
// It is rendered once per *world* pixel into WaterSurface's SubViewport and
// scaled up with nearest filtering, so its cost is fixed by the size of the
// harbour, not by the phone's resolution or the camera's zoom.
//
// The third pass simulated a sea: a lit height field, caustics, reflected
// rings off every hull, a bow wave. Each was defensible and together they were
// mud — soft webs and halos in a game whose every other pixel is placed. This
// pass draws the water the way a pixel artist does, with four ideas only:
//
//   * depth is a few *flat* bands of the port's four colours whose contours
//     breathe slowly, with a two-pixel checker fringe where they meet;
//   * the surface is told by wavelets — short level strokes with drooping
//     ends that open, hold and close in whole pixels, each on its own clock,
//     and a darker set between them for the troughs;
//   * the quay wall carries a hard white foam line that swells and drains,
//     and sets of ripples walk away from it;
//   * anything that moves leaves a wake that stays on the sea where it was
//     laid (`trail`, fed by WaterWakes) and thins out with age.
//
// Nothing here is drawn around a hull any more. A hull is a sprite with a real
// outline and the shader only ever knew its bounding box, which is where the
// capsule halo and the square bow wave came from; ShipWake owns that foam. The
// boxes are still read, for the one thing a box is good enough for: the water
// in a ship's lee is calmer.
//
// `quality_level` (WaterQuality, from the viewport, never a preference) only
// trims the second wavelet layer and the glitter.

uniform vec4 col_shallow : source_color = vec4(0.40, 0.70, 0.74, 1.0);
uniform vec4 col_mid : source_color = vec4(0.26, 0.54, 0.65, 1.0);
uniform vec4 col_deep : source_color = vec4(0.13, 0.30, 0.47, 1.0);
uniform vec4 col_abyss : source_color = vec4(0.09, 0.21, 0.36, 1.0);
uniform vec4 col_light : source_color = vec4(0.56, 0.82, 0.85, 1.0);
uniform vec4 col_spark : source_color = vec4(0.86, 0.96, 0.96, 1.0);
uniform vec2 world_offset = vec2(0.0);
uniform float shore_x = 240.0;
uniform float water_span = 80.0;
uniform int quality_level = 1; // 0 low, 1 medium, 2 high
// 0 calm .. 1 squall. Weather raises the chop and lays rain rings on the water.
uniform float chop = 0.0;
uniform float rain = 0.0;

// The hull under way, in shader space, for the water it pushes ahead of itself.
uniform vec2 ship_centre = vec2(-9999.0);
uniform vec2 ship_half = vec2(33.0, 116.0);
uniform float ship_speed = 0.0;   // 0 moored, 1 full ahead

// Every hull on the water, moving or not, as (centre.xy, half.xy).
const int MAX_HULLS = 3;
uniform int hull_count = 0;
uniform vec4 hulls[MAX_HULLS];

// Wake samples, oldest to newest per chain: (x, y, age seconds, half width).
// A negative half width starts a new chain. See WaterWakes.
const int MAX_TRAIL = 40;
const float TRAIL_LIFE = 9.0;
uniform int trail_count = 0;
uniform vec4 trail[MAX_TRAIL];

varying vec2 v_pos;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);
const float BANDS = 5.0;

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

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (BAYER[x + y * 4] + 0.5) / 16.0;
}

// Band `i` of BANDS, as a colour on the shallow → abyss ramp.
vec4 band_colour(float i) {
	float s = clamp(i / (BANDS - 1.0), 0.0, 1.0) * 3.0;
	if (s < 1.0) return mix(col_shallow, col_mid, s);
	if (s < 2.0) return mix(col_mid, col_deep, s - 1.0);
	return mix(col_deep, col_abyss, s - 2.0);
}

// One layer of wavelets on a staggered grid. Each cell may hold one stroke: a
// level run of 2-7 pixels whose two ends hang a pixel low once it is long
// enough to have ends. It opens from its middle, holds and closes again, in
// whole pixels, on its own clock. Returns 0 nothing, 1 stroke, 2 the bright
// heart of a stroke at full stretch.
float wavelets(vec2 p, vec2 cell_size, float t, float seed, float density) {
	float row = floor(p.y / cell_size.y);
	float xs = p.x + mod(row, 2.0) * floor(cell_size.x * 0.5)
		+ floor(hash(vec2(row, seed)) * cell_size.x);
	vec2 cell = vec2(floor(xs / cell_size.x), row);
	vec2 local = vec2(xs - cell.x * cell_size.x, p.y - row * cell_size.y);
	float pick = hash(cell + seed);
	if (pick > density) { return 0.0; }
	float h2 = hash(cell.yx + seed * 1.7 + 3.1);
	float h3 = hash(cell + seed * 2.3 + 7.7);
	float life = fract(t * (0.11 + h2 * 0.09) + h3);
	if (life > 0.6) { return 0.0; }
	float grow = sin(life / 0.6 * 3.14159265);
	float full = 3.0 + floor(h2 * 5.0);
	float len = max(1.0, floor(grow * full + 0.5));
	float ox = floor(h3 * (cell_size.x - full)) + floor((full - len) * 0.5);
	float oy = floor(pick / max(density, 0.001) * (cell_size.y - 2.0));
	float lx = local.x - ox;
	float ly = local.y - oy;
	if (lx < 0.0 || lx >= len) { return 0.0; }
	bool tip = len >= 5.0 && (lx < 1.0 || lx >= len - 1.0);
	if (ly != (tip ? 1.0 : 0.0)) { return 0.0; }
	return (len >= 6.0 && lx >= 2.0 && lx < len - 2.0 && h3 > 0.55) ? 2.0 : 1.0;
}

void fragment() {
	vec2 p = floor(v_pos);
	float t = TIME;
	float from_shore = p.x - shore_x;
	float open = smoothstep(2.0, 30.0, from_shore);

	// --- the wakes: nearest point on the track, with its age and width ---
	float wake_d = 1.0e4;
	float wake_age = TRAIL_LIFE;
	float wake_half = 1.0;
	vec2 wake_dir = vec2(0.0, 1.0);
	for (int i = 1; i < MAX_TRAIL; i++) {
		if (i >= trail_count) { break; }
		vec4 b = trail[i];
		if (b.w < 0.0) { continue; }
		vec4 a = trail[i - 1];
		vec2 ab = b.xy - a.xy;
		float len2 = max(dot(ab, ab), 0.0001);
		float h = clamp(dot(p - a.xy, ab) / len2, 0.0, 1.0);
		float dist = length(p - (a.xy + ab * h));
		if (dist < wake_d) {
			float age = mix(a.z, b.z, h);
			if (age < TRAIL_LIFE) {
				wake_d = dist;
				wake_age = age;
				wake_half = abs(mix(a.w, b.w, h));
				wake_dir = ab * inversesqrt(len2);
			}
		}
	}
	float wake_f = clamp(wake_age / TRAIL_LIFE, 0.0, 1.0);
	// The arms run out at a fixed rate — that is the V — the wash spreads slowly.
	float arm_w = wake_half + wake_age * (2.6 + wake_half * 0.55);
	float wash_w = wake_half * 0.9 + wake_age * 0.9;
	bool in_wake = wake_d < arm_w + 1.5 && wake_f < 1.0;

	// --- shelter: the water between a hull and the quay is calm ---
	float calm = 1.0;
	for (int i = 0; i < MAX_HULLS; i++) {
		if (i >= hull_count) { break; }
		vec4 hull = hulls[i];
		vec2 rel = p - hull.xy;
		float along = 1.0 - smoothstep(hull.w - 10.0, hull.w + 18.0, abs(rel.y));
		float lee = smoothstep(hull.z + 10.0, hull.z, rel.x);
		calm = min(calm, 1.0 - 0.7 * along * lee);
	}
	if (wake_d < wash_w + 2.0) {
		// Fresh wash is a slick: nothing stands up on it.
		calm = min(calm, wake_f);
	}

	// --- depth: flat bands whose contours breathe ---
	float wobble = (value_noise(vec2(p.y * 0.05, t * 0.07)) - 0.5) * 7.0
		+ sin(p.y * 0.13 + t * 0.35) * 1.0;
	float depth = pow(clamp((from_shore + wobble * open) / max(water_span, 1.0),
		0.0, 1.0), 0.78) * (BANDS - 0.001);
	float band = floor(depth);
	// A two-pixel checker fringe on the deep side of every contour.
	if (fract(depth) > 0.80 && mod(p.x + p.y, 2.0) < 1.0) {
		band += 1.0;
	}
	vec4 col = band_colour(band);
	vec4 trough = band_colour(band + 1.6);
	vec4 light = mix(col, col_light, 0.62);

	// --- the surface, told in wavelets ---
	float busy = (0.55 + chop * 0.35) * mix(0.35, 1.0, open) * calm;
	// They ride toward the quay, slowly, a whole pixel at a time.
	vec2 ride = vec2(floor(t * 1.6), floor(t * 0.35));
	float crest = wavelets(p + ride, vec2(16.0, 6.0), t, 1.0, busy);
	if (crest < 0.5 && quality_level > 0) {
		crest = wavelets(p + vec2(7.0, 3.0) + floor(ride * 0.6), vec2(22.0, 9.0),
			t * 0.8, 17.0, busy * 0.8);
	}
	if (crest > 1.5) {
		col = chop > 0.05 ? col_spark : mix(col, col_spark, 0.78);
	} else if (crest > 0.5) {
		col = light;
	} else if (wavelets(p + vec2(3.0, 2.0) + floor(ride * 0.8), vec2(19.0, 7.0),
			t * 0.9, 41.0, busy * 0.9) > 0.5) {
		// The trough between two crests, a shade deeper: what gives them body.
		col = mix(col, trough, 0.55);
	}

	// --- the sun, catching a pixel here and there ---
	if (quality_level > 0 && from_shore > 14.0 && calm > 0.6) {
		vec2 cell = floor(p / 7.0);
		float beat = floor(t * 1.5 + hash(cell) * 9.0);
		if (hash(cell + beat * 0.37) > 0.955
				&& p == cell * 7.0 + floor(vec2(hash(cell + beat), hash(cell.yx - beat)) * 7.0)) {
			col = col_spark;
		}
	}

	// --- the quay wall: a hard foam line, and ripples walking off it ---
	if (from_shore >= 0.0 && from_shore < 14.0) {
		float swell = value_noise(vec2(p.y * 0.17, t * 0.4)) * 2.4
			+ sin(p.y * 0.6 + t * 1.2) * 0.6;
		float foam = floor(1.2 + swell);
		if (from_shore < foam) {
			// Holes in it, so it is foam and not a kerb.
			bool hole = from_shore >= 1.0
				&& hash(vec2(floor(p.y / 2.0), floor(from_shore) + floor(t * 1.5))) > 0.72;
			col = hole ? light : col_spark;
		} else if (from_shore < foam + 1.0) {
			col = light;
		}
		for (int i = 0; i < 2; i++) {
			float lane = value_noise(vec2(p.y * 0.035, 3.0 + float(i) * 9.0));
			float cycle = fract(t * 0.14 + lane * 0.8 + float(i) * 0.5);
			float front = floor(4.0 + cycle * 9.0 + sin(p.y * 0.23 + float(i) * 2.0) * 1.2);
			if (from_shore == front && cycle < 0.85
					&& hash(vec2(floor((p.y + float(i) * 3.0) / 4.0), float(i) + floor(cycle * 6.0))) > 0.30 + cycle * 0.5) {
				col = light;
			}
		}
	}

	// --- the wake ---
	if (in_wake) {
		float fade = 1.0 - wake_f;
		vec2 perp = vec2(-wake_dir.y, wake_dir.x);
		float along = dot(p, wake_dir);
		float across = dot(p, perp);
		// The propeller wash: one tone paler, its edge and its age both thinned
		// with the ordered dither rather than faded, then foam drawn out along
		// the track in dashes.
		if (wake_d < wash_w) {
			float r = wake_d / max(wash_w, 0.5);
			if (r < 0.30 + fade * 0.35 && wake_f < 0.55) {
				col = mix(col, col_light, 0.26 * fade + 0.06);
			}
			vec2 dash = floor(vec2(along / 5.0, across / 1.5));
			if (hash(dash) > 0.50 + wake_f * 0.55 + r * 0.25) {
				col = wake_f < 0.35 ? col_spark : mix(col, col_spark, 0.6);
			}
		}
		// The two arms of the V, breaking into dashes as they age.
		if (abs(wake_d - arm_w) < 0.8) {
			float dash = hash(vec2(floor(along / 4.0), step(0.0, across)));
			if (dash > wake_f * 1.1 - 0.1) {
				col = wake_f < 0.25 ? col_spark : mix(col, col_light, 0.75);
			}
		}
	}

	// --- rain on the water: rings that open and are gone ---
	if (rain > 0.02) {
		vec2 cell = floor(p / 9.0);
		float seed = hash(cell + vec2(3.0, 11.0));
		float life = fract(t * (0.9 + seed * 0.8) + seed * 13.0);
		if (seed < rain * 0.75) {
			vec2 centre = cell * 9.0 + 2.0 + floor(vec2(hash(cell), hash(cell.yx)) * 5.0);
			float rr = length(p - centre);
			float radius = life * 4.0;
			if (abs(rr - radius) < 0.7 && life < 0.8) {
				col = mix(col, col_light, 0.7 * (1.0 - life));
			}
		}
	}

	COLOR = vec4(col.rgb, 1.0);
}
