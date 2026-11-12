shader_type canvas_item;
// Pixel-art harbour water, seen from above.
//
// The first version banded the depth in straight vertical stripes and dusted a
// few dashes over them, which read as flat blue paper with lint on it. Three
// things make it read as water instead:
//
//   * the depth bands are *displaced by the swell*, so their edges wander
//     instead of ruling straight lines down the screen;
//   * crests are drawn as broken horizontal strokes that ride the swell and
//     drift at their own rate per row, which is how top-down water reads in
//     pixel art;
//   * the shore gets its own foam band that breaks up along its length.
//
// Every branch still has a small fixed cost. `quality_level` is chosen by
// WaterQuality from the viewport, never by a preference.

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

// The hull, in world space. The water is the only thing that can show a ship
// is under way rather than parked, so the wake is computed here instead of
// being a sprite dragged behind the boat.
uniform vec2 ship_centre = vec2(-9999.0);
uniform vec2 ship_half = vec2(33.0, 116.0);
uniform float ship_speed = 0.0;   // 0 moored, 1 full ahead

// Every hull on the water, moving or not, as (centre.xy, half.xy). A ship lying
// alongside still works the water around it, and a berth is what the player
// looks at almost all of the time — without this the surface only ever moved
// during the five seconds of an arrival, which is to say never.
const int MAX_HULLS = 3;
uniform int hull_count = 0;
uniform vec4 hulls[MAX_HULLS];

varying vec2 v_pos;

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

void fragment() {
	// Whole-pixel coordinates keep the surface in the game's pixel language.
	vec2 p = floor(v_pos);
	float t = TIME;

	// --- swell: one slow field the whole surface agrees on, centred on zero ---
	float swell = sin(p.x * 0.031 + p.y * 0.017 + t * 0.50) * 0.50;
	swell += sin(p.y * 0.047 - p.x * 0.011 - t * 0.34) * 0.32;
	if (quality_level > 0) {
		swell += (value_noise(p * 0.055 + vec2(t * 0.04, -t * 0.024)) - 0.5) * 0.72;
	}
	if (quality_level > 1) {
		swell += (value_noise(p * 0.13 + vec2(-t * 0.07, t * 0.05)) - 0.5) * 0.34;
	}

	// --- depth, in discrete bands whose edges are pushed about by the swell ---
	// Displacing the band boundary is the whole trick: straight vertical
	// stripes read as a gradient someone forgot to dither, wandering ones read
	// as water getting deeper away from the quay.
	float from_shore = p.x - shore_x;
	// The curve is biased so the bright shallow band stays a narrow shelf
	// against the quay rather than half the channel.
	float depth = pow(clamp((from_shore + swell * 7.0)
		/ max(water_span, 1.0), 0.0, 1.0), 0.72);
	float bands = 4.0 + float(quality_level > 1);
	float shade = floor(depth * bands) / max(bands - 1.0, 1.0);
	vec4 col = shade < 0.34
		? mix(col_shallow, col_mid, shade / 0.34)
		: (shade < 0.67
			? mix(col_mid, col_deep, (shade - 0.34) / 0.33)
			: mix(col_deep, col_abyss, clamp((shade - 0.67) / 0.33, 0.0, 1.0)));

	// --- crests: broken strokes riding the top of the swell ---
	// Rows sit 5px apart and each drifts at its own rate, so the surface never
	// resolves into a repeating grid.
	float row = floor(p.y / 5.0);
	float row_phase = hash(vec2(row, 3.0));
	float drift = t * (5.0 + row_phase * 7.0) + row_phase * 61.0;
	float stroke = mod(p.x + drift, 23.0 + floor(row_phase * 11.0));
	if (mod(p.y, 5.0) < 1.0 && stroke < 4.0 + row_phase * 3.0 && swell > 0.22) {
		col = mix(col, col_light, 0.62);
		// the leading pixel of a stroke catches the light hardest
		if (stroke < 1.0) col = mix(col, col_spark, 0.55);
	}
	if (quality_level > 1) {
		float row2 = floor((p.y + 3.0) / 9.0);
		float drift2 = -t * (9.0 + hash(vec2(row2, 7.0)) * 5.0);
		if (mod(p.y + 3.0, 9.0) < 1.0
				&& mod(p.x + drift2, 41.0) < 3.0 && swell > 0.55) {
			col = mix(col, col_spark, 0.5);
		}
	}

	// --- glitter: the sun on the chop, out in the open water ---
	// Single pixels that come and go on a slow clock of their own. Cells are
	// 6px, one candidate each, and only where the swell is cresting — so the
	// glitter drifts across the harbour in patches the way it does on real
	// water, instead of twinkling evenly like a starfield.
	if (quality_level > 0 && from_shore > 14.0) {
		vec2 cell = floor(p / 6.0);
		float pick = hash(cell + vec2(17.0, 5.0));
		vec2 spot = floor(vec2(hash(cell), hash(cell.yx + 3.0)) * 6.0);
		float beat = fract(t * (0.35 + pick * 0.4) + pick * 9.0);
		if (pick > 0.62 && p - cell * 6.0 == spot && swell > 0.05 && beat < 0.30) {
			col = mix(col, col_spark, beat < 0.12 ? 0.95 : 0.55);
		}
	}

	// --- shore: a foam band that breaks up along the quay ---
	if (from_shore >= 0.0 && from_shore < 6.0) {
		float edge = 1.0 - from_shore / 6.0;
		float wash = value_noise(vec2(p.y * 0.14, t * 0.55));
		col = mix(col, col_light, clamp(edge * (0.45 + wash * 0.75), 0.0, 0.85));
		// the wet line right against the concrete
		if (from_shore < 2.0 && wash > 0.42) {
			col = mix(col, col_spark, 0.70 - from_shore * 0.25);
		}
	}

	// --- water worked by a hull lying alongside ---
	for (int i = 0; i < MAX_HULLS; i++) {
		if (i >= hull_count) { break; }
		vec4 hull = hulls[i];
		vec2 rel = p - hull.xy;
		// Distance outside the hull rectangle, so the band hugs the real shape.
		vec2 outside = abs(rel) - hull.zw;
		float d = max(outside.x, outside.y);
		if (d > -1.0 && d < 14.0) {
			// A slow swell running down the hull's side, and a second one against
			// it, so the band breathes instead of pulsing.
			float run = sin(rel.y * 0.24 - t * 1.5) * 0.5
				+ sin(rel.y * 0.11 + t * 0.9) * 0.5;
			// Peaked a few pixels *out* rather than hard against the plating: the
			// first three pixels are under the hull's own contact shadow, so a
			// band that was brightest at zero was a band nobody could see.
			float band = 1.0 - clamp(abs(d - 3.5) / 10.5, 0.0, 1.0);
			float lap = band * (0.42 + run * 0.46);
			col = mix(col, col_light, clamp(lap, 0.0, 0.80));
			// The crest of the lap, breaking along the hull.
			if (run > 0.30 && d > 0.5 && d < 8.0) {
				col = mix(col, col_spark, 0.70 * band);
			}
			// And a second, slower set of rings shed further out, so the water
			// beside a moored ship is never still.
			float ring = sin(d * 0.9 - t * 2.2 + rel.y * 0.05);
			if (ring > 0.80 && d > 4.0) {
				col = mix(col, col_light, 0.45 * (1.0 - d / 14.0));
			}
		}
	}

	// --- the ship cutting the water ---
	// Three parts, and the middle one is what was missing: a hull under way
	// pushes a bow wave *out to the sides*, drags a foam collar along its
	// length, and leaves a widening V astern with transverse crests inside it.
	if (ship_speed > 0.01) {
		vec2 rel = p - ship_centre;
		// The GitHub source hull points up, so its bow is already at negative y
		// in sprite space. The wake maths below is written in that same frame.
		float lateral = abs(rel.x);
		float astern = rel.y - ship_half.y;
		float ahead = -(rel.y + ship_half.y);
		float reach = 90.0 + 170.0 * ship_speed;

		// The bow wave: two crests leaving the stem at a fixed angle, brightest
		// where they are born and spreading as they run aft.
		float bow_run = -ahead;                       // 0 at the stem, + going aft
		if (ahead > -40.0 && ahead < 12.0) {
			float crest = ship_half.x * 0.55 + max(0.0, bow_run) * 0.62;
			float d = abs(lateral - crest);
			float bow_fade = ship_speed * (1.0 - clamp(bow_run / 44.0, 0.0, 1.0));
			// Three pixels of crest with a soft shoulder: at two it was a hairline
			// nobody saw go past.
			if (d < 3.2) {
				col = mix(col, col_spark, (1.0 - d / 3.2) * 1.0 * bow_fade);
			}
			if (d < 6.0) {
				col = mix(col, col_light, (1.0 - d / 6.0) * 0.45 * bow_fade);
			}
			// The water piled up right on the stem.
			if (ahead > 0.0 && lateral < ship_half.x * 0.9) {
				col = mix(col, col_spark, 0.55 * ship_speed * (ahead / 10.0));
			}
		}

		// The collar of disturbed water dragged along the hull's sides.
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

		if (astern > 0.0 && astern < reach) {
			// A V that opens with distance, and churn inside it.
			float spread = ship_half.x * 0.7 + astern * 0.17;
			float fade = (1.0 - astern / reach) * ship_speed;
			if (lateral < spread) {
				col = mix(col, col_light, 0.20 * fade);
				float churn = sin(astern * 0.30 - t * 8.0 + lateral * 0.22);
				if (churn > 0.55) col = mix(col, col_light, 0.60 * fade);
				// Transverse crests: the arcs a real wake leaves across itself,
				// curved back at the edges because the middle travels faster.
				float bow_curve = lateral * lateral * 0.010;
				float trans = sin((astern + bow_curve) * 0.42 - t * 5.0);
				if (trans > 0.72) {
					col = mix(col, col_spark, 0.45 * fade
						* (1.0 - lateral / max(spread, 1.0)));
				}
			}
			if (abs(lateral - spread) < 1.6) {
				col = mix(col, col_spark, 0.85 * fade);
			}
		}
	}

	// Sparkles are intentionally rare and entirely absent on low quality.
	if (quality_level > 0
			&& hash(floor(p / 3.0) + floor(t * 3.0)) > (0.9982 - float(quality_level) * 0.0006)
			&& swell > 0.5) {
		col = col_spark;
	}
	COLOR = col;
}
