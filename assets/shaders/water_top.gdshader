shader_type canvas_item;
// Pixel-art harbour water, seen from above — third pass.
//
// It is rendered once per *world* pixel into WaterSurface's SubViewport and
// scaled up with nearest filtering, so its cost is fixed by the size of the
// harbour, not by the phone's resolution or the camera's zoom. That is what
// lets a phone run the whole thing instead of four flat bands.
//
// What makes it read as water rather than blue paper:
//
//   * depth is a continuous ramp through the port's four colours, quantised
//     with an ordered (Bayer) dither so the shelf blends into the channel in
//     the game's own pixel language instead of in ruled steps;
//   * the surface is a real height field — a handful of travelling swells with
//     sharp crests and broad troughs — lit from the upper left like everything
//     else in the game, so every wave has a bright face and a shaded back;
//   * crests break into foam where they are steepest, the sun glitters on the
//     faces turned to it, and the shallows under the quay carry caustics;
//   * swell runs up against the quay wall in sets and washes back;
//   * ships *shelter* the water behind them and work the water around them,
//     and anything that moves leaves a wake that stays on the sea where it was
//     laid (`trail`, fed by WaterWakes) and widens, slicks and fades with age.
//
// `quality_level` (WaterQuality, from the viewport, never a preference) only
// trims the detail octaves; every level gets the lighting and the wakes.

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

// One travelling swell with sharp crests: h = a·e^(sin φ − 1). Returns
// (height, ∂h/∂x, ∂h/∂y). The exp shape is what gives a narrow bright ridge and
// a long shallow trough instead of a sine's even corrugation.
vec3 swell(vec2 p, vec2 dir, float wavelength, float amp, float speed, float t) {
	float k = 6.2831853 / wavelength;
	float phase = dot(p, dir) * k - t * speed * k;
	float h = amp * exp(sin(phase) - 1.0);
	float dh = h * cos(phase) * k;
	return vec3(h, dh * dir.x, dh * dir.y);
}

// The four depth colours as one continuous ramp, v in 0..1, quantised into
// twelve close steps with an ordered dither between neighbours. Dithering
// between the four palette colours themselves made loud checkerboard seams that
// crawled with the swell; between near-identical steps the dither is texture,
// not noise, and the shelf still falls away in the game's own pixels.
const float RAMP_STEPS = 12.0;
vec4 ramp(float v, float d) {
	float s = floor(clamp(v, 0.0, 1.0) * RAMP_STEPS + d) / RAMP_STEPS * 3.0;
	if (s < 1.0) return mix(col_shallow, col_mid, s);
	if (s < 2.0) return mix(col_mid, col_deep, s - 1.0);
	return mix(col_deep, col_abyss, clamp(s - 2.0, 0.0, 1.0));
}

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = floor(v_pos);
	float t = TIME;
	float from_shore = p.x - shore_x;
	float dith = bayer(p);
	float sea = 1.0 + chop * 0.9;

	// --- the wakes, first: an old wake is a slick that flattens the swell ---
	// Nearest point on the track, with the age, width and heading there.
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
	float in_wake = wake_d < arm_w + 1.5 ? (1.0 - wake_f) : 0.0;

	// --- shelter: the water in a hull's lee is calm ---
	// The swell runs in from the sea (east), so whatever lies between a ship and
	// the quay is sheltered. This is what makes a moored ship look *heavy*.
	float calm = 1.0;
	for (int i = 0; i < MAX_HULLS; i++) {
		if (i >= hull_count) { break; }
		vec4 hull = hulls[i];
		vec2 rel = p - hull.xy;
		float along = 1.0 - smoothstep(hull.w - 10.0, hull.w + 18.0, abs(rel.y));
		float lee = smoothstep(-hull.z + 2.0, -hull.z - 6.0, rel.x)
			* smoothstep(-hull.z - 70.0, -hull.z - 20.0, rel.x);
		calm = min(calm, 1.0 - 0.62 * along * lee);
	}
	// Old wash is a slick: the swell goes flat over it.
	calm = min(calm, 1.0 - 0.6 * (1.0 - wake_f)
		* smoothstep(wash_w + 2.0, wash_w * 0.5, wake_d) * smoothstep(0.1, 0.45, wake_f));

	// --- the height field ---
	vec2 q = p;
	if (quality_level > 0) {
		// A slow domain warp keeps the swells from reading as ruled lines.
		q += vec2(value_noise(p * 0.035 + vec2(t * 0.05, 0.0)),
			value_noise(p * 0.035 + vec2(9.1, -t * 0.04))) * 7.0 - 3.5;
	}
	vec3 wv = swell(q, normalize(vec2(-1.0, 0.32)), 47.0, 1.00 * sea, 8.5, t);
	wv += swell(q, normalize(vec2(-0.9, -0.55)), 29.0, 0.62 * sea, 6.8, t);
	wv += swell(q, normalize(vec2(-0.45, 1.0)), 17.0, 0.34 * sea, 5.2, t);
	if (quality_level > 0) {
		wv += swell(q, normalize(vec2(-1.0, 0.08)), 11.0, 0.24 * sea, 4.1, t);
	}
	if (quality_level > 1) {
		wv += swell(q, normalize(vec2(0.3, 1.0)), 7.0, 0.14 * sea, 3.3, t);
	}
	// The shelf damps the swell; the open channel lets it run.
	float open = smoothstep(0.0, 34.0, from_shore);
	float energy = mix(0.45, 1.0, open) * calm;
	float height = wv.x * energy;
	// Light from the upper left: faces rising toward +x/+y are turned to it.
	float lit = (wv.y + wv.z) * 0.7071 * energy;

	// --- depth, swell-displaced, through the dithered ramp ---
	float depth = pow(clamp((from_shore + height * 5.0) / max(water_span, 1.0),
		0.0, 1.0), 0.70);
	float cloud = 0.0;
	if (quality_level > 0) {
		// Cloud shadow drifting over the harbour: big, slow, faint.
		cloud = smoothstep(0.55, 0.85,
			value_noise(p * 0.0065 + vec2(t * 0.012, t * 0.006)));
	}
	float v = 0.04 + depth * 0.92 - lit * 0.30 + cloud * 0.10;
	vec4 col = ramp(v, dith);

	// Bright faces lift toward the light colour, dithered so they keep an edge.
	// --- ripples: the short chop drawn as thin broken strokes ---
	// Pixel-art water is read from its strokes, and real ripples are lines
	// across the direction they run, so each stroke is the narrow peak of one
	// short wave, gated by a slow envelope so they come and go in patches
	// rather than ruling the whole harbour.
	float envelope = value_noise(p * 0.045 + vec2(-t * 0.06, t * 0.03));
	// Running up and down the channel, so the strokes lie across the screen:
	// strokes down the screen read as rain.
	vec2 r1 = normalize(vec2(0.18, -1.0));
	float s1 = sin(dot(q, r1) * (6.2831853 / 9.0) - t * 2.1);
	float gate = envelope * mix(0.55, 1.0, open) * calm;
	float dash1 = hash(vec2(floor((p.x + floor(p.y / 9.0) * 3.0) / 4.0), floor(p.y / 3.0)));
	if (s1 > 0.90 && gate > 0.38 - chop * 0.2 && dash1 > 0.48) {
		col = mix(col, col_light, 0.40 + (gate - 0.40) * 0.8);
	} else if (s1 < -0.96 && gate > 0.5) {
		// The trough behind a ripple, a shade darker: half of what gives it body.
		col = mix(col, col_abyss, 0.22);
	}
	if (quality_level > 0) {
		vec2 r2 = normalize(vec2(-0.35, 1.0));
		float s2 = sin(dot(q, r2) * (6.2831853 / 6.0) - t * 1.7);
		if (s2 > 0.94 && envelope < 0.40 && open > 0.3
				&& hash(vec2(floor(p.x / 3.0), floor(p.y / 2.0)) + 5.0) > 0.55) {
			col = mix(col, col_light, 0.30 * calm);
		}
	}

	// --- whitecaps: only when the weather has raised a chop ---
	float crest = height - (1.55 - chop * 0.55) * sea;
	if (crest > 0.0 && lit > 0.02 && (chop > 0.05 || crest > 0.35)) {
		float broken = hash(floor(vec2(p.x / 4.0, p.y)));
		if (broken > 0.62 - crest * 1.0) {
			col = mix(col, col_light, 0.75);
			if (crest > 0.25 && broken > 0.85) col = col_spark;
		}
	}

	// --- the sun glittering on the faces turned to it ---
	if (from_shore > 10.0 && lit > 0.16) {
		vec2 cell = floor(p / 3.0);
		float pick = hash(cell + floor(t * (2.0 + hash(cell) * 2.0)));
		float need = 0.985 - lit * 0.18 - float(quality_level) * 0.004;
		if (pick > need && p == cell * 3.0 + floor(hash(cell.yx) * 3.0)) {
			col = col_spark;
		}
	}

	// --- caustics on the shelf under the quay ---
	if (from_shore >= 0.0 && from_shore < 28.0) {
		float c = abs(sin(p.x * 0.23 + sin(p.y * 0.11 + t * 0.9) * 1.8 + t * 0.7)
			+ sin(p.y * 0.19 + sin(p.x * 0.15 - t * 0.7) * 1.6 - t * 0.5));
		float fade = 1.0 - from_shore / 28.0;
		if (c < 0.20 * fade + 0.02) {
			col = mix(col, col_light, 0.22 * fade + 0.06);
		}
	}

	// --- swell running up the quay wall in sets ---
	if (from_shore >= 0.0 && from_shore < 22.0) {
		float lane = value_noise(vec2(p.y * 0.045, 3.0)) * 0.35;
		float cycle = fract(t * 0.21 + lane);
		float front = (1.0 - cycle) * 20.0;     // distance of the incoming line
		if (abs(from_shore - front) < 1.0 && cycle > 0.15) {
			col = mix(col, col_light, 0.55 * cycle);
		}
		// Broken every couple of rows, so the wall foam is foam and not a kerb.
		float wash = value_noise(vec2(p.y * 0.14, t * 0.55)) * 0.75
			+ hash(vec2(floor(p.y / 2.0), floor(t * 3.0))) * 0.25;
		// The wall foam flares as each line arrives, then drains back.
		float surge = smoothstep(0.75, 1.0, cycle) + smoothstep(0.25, 0.0, cycle) * 0.6;
		float band = 4.0 + surge * 4.0;
		if (from_shore < band) {
			float edge = 1.0 - from_shore / band;
			col = mix(col, col_light, clamp(edge * (0.45 + wash * 0.7), 0.0, 0.85));
			if (from_shore < 2.0 + surge * 2.0 && wash > 0.40 - surge * 0.2) {
				col = mix(col, col_spark, 0.75 - from_shore * 0.15);
			}
		}
	}

	// --- the water a hull works, moving or not ---
	for (int i = 0; i < MAX_HULLS; i++) {
		if (i >= hull_count) { break; }
		vec4 hull = hulls[i];
		vec2 rel = p - hull.xy;
		// A hull under way has its own bow wave and collar below; lapping water
		// on top of those is clutter.
		float moored = 1.0 - ship_speed * step(length(hull.xy - ship_centre), 2.0);
		if (moored < 0.05) { continue; }
		// Capsule ends: the bow is pointed and the stern rounded, and a square
		// box drew a halo floating off both.
		float d = sd_round_box(rel, hull.zw, hull.z);
		if (d > -1.0 && d < 14.0) {
			float run = sin(rel.y * 0.24 - t * 1.5) * 0.5
				+ sin(rel.y * 0.11 + t * 0.9) * 0.5;
			// Hugging the plating, just clear of the contact shadow.
			float band = 1.0 - clamp(abs(d - 2.0) / 4.5, 0.0, 1.0);
			col = mix(col, col_light, clamp(band * (0.30 + run * 0.36), 0.0, 0.66) * moored);
			if (run > 0.30 && d > 0.5 && d < 4.0
					&& hash(vec2(floor(rel.y / 2.0), floor(rel.x / 3.0))) > 0.30) {
				col = mix(col, col_spark, 0.60 * band * moored);
			}
			// Swell reflected off the plating, faint rings walking outward.
			float ring = sin(d * 0.9 - t * 2.2 + rel.y * 0.05);
			if (ring > 0.88 && d > 4.0
					&& hash(vec2(floor(rel.y / 3.0), floor(d))) > 0.35) {
				col = mix(col, col_light, 0.30 * (1.0 - d / 14.0) * calm * moored);
			}
		}
	}

	// --- the wake ---
	if (in_wake > 0.0) {
		float fade = 1.0 - wake_f;
		vec2 perp = vec2(-wake_dir.y, wake_dir.x);
		// Streaks laid *along* the track: foam is drawn out by the hull, never
		// scattered in blobs.
		float along = dot(p, wake_dir);
		float across = dot(p, perp);
		// The propeller wash: pale aerated water with foam streaks, dense at the
		// screws, thinning and greying out as it ages.
		if (wake_d < wash_w) {
			float r = wake_d / max(wash_w, 0.5);
			col = mix(col, col_light, 0.34 * fade * (1.0 - r * r));
			float streak = value_noise(vec2(along * 0.16 + t * 0.4, across * 0.9));
			float need = 0.40 + wake_f * 0.62 + r * 0.30;
			if (streak > need) {
				col = mix(col, streak > need + 0.12 && wake_f < 0.5 ? col_spark : col_light,
					0.88 * fade);
			}
		}
		// Transverse crests between the arms: arcs that travel with the hull.
		float ra = wake_d / max(arm_w, 0.5);
		if (ra < 1.0 && wake_f < 0.6) {
			float trans = sin(wake_age * 7.5 + ra * ra * 2.6);
			if (trans > 0.86 && hash(floor(vec2(across / 2.0, along / 2.0))) > 0.35) {
				col = mix(col, col_light, 0.48 * fade * (1.0 - ra * 0.6));
			}
		}
		// The two arms of the V, thin and broken into dashes as they age.
		float seam = abs(wake_d - arm_w);
		if (seam < 1.0 + fade * 0.6) {
			float dash = hash(vec2(floor(along / 3.0), floor(across / 6.0)));
			if (dash > wake_f * 0.85) {
				col = mix(col, wake_f < 0.3 ? col_spark : col_light, 0.85 * fade);
			}
		}
	}

	// --- water piled ahead of a hull under way ---
	// The wake behind is the trail's; this is the half a sample cannot make:
	// the bow wave thrown out to the sides and the collar along the plating.
	if (ship_speed > 0.01) {
		vec2 rel = p - ship_centre;
		float lateral = abs(rel.x);
		float ahead = -(rel.y + ship_half.y);
		float bow_run = -ahead;
		if (ahead > -44.0 && ahead < 12.0) {
			float crest_x = ship_half.x * 0.55 + max(0.0, bow_run) * 0.62;
			float dd = abs(lateral - crest_x);
			float bow_fade = ship_speed * (1.0 - clamp(bow_run / 44.0, 0.0, 1.0));
			if (dd < 3.2) {
				col = mix(col, col_spark, (1.0 - dd / 3.2) * bow_fade);
			}
			if (dd < 6.0) {
				col = mix(col, col_light, (1.0 - dd / 6.0) * 0.45 * bow_fade);
			}
			if (ahead > 0.0 && lateral < ship_half.x * 0.9) {
				col = mix(col, col_spark, 0.55 * ship_speed * (ahead / 10.0));
			}
		}
		if (rel.y > -ship_half.y && rel.y < ship_half.y) {
			float side = abs(lateral - ship_half.x);
			if (side < 5.0) {
				float boil = value_noise(vec2(rel.y * 0.20, t * 1.6));
				col = mix(col, col_light,
					(1.0 - side / 5.0) * (0.45 + boil * 0.50) * ship_speed);
				if (side < 2.0 && boil > 0.55) {
					col = mix(col, col_spark, 0.7 * ship_speed);
				}
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
