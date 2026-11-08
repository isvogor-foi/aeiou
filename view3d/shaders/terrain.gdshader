shader_type spatial;
// Ground: per-tile colours (linearly blended) with procedural moss, heath and
// soot, cobbled paving around buildings, national borders and the
// building-placement footprint.

// RGB = tile colour, A = paving (1 under and around buildings).
uniform sampler2D color_tex : source_color, filter_linear, repeat_disable;
// One mask channel per nation (RGBA = owners 0-3), one texel per tile.
uniform sampler2D territory_tex : filter_linear, repeat_disable;
uniform vec4 team_colors[4] : source_color;
uniform vec2 map_size = vec2(96.0, 96.0);
// Placement footprint in tiles (x, y, w, h) and its colour; alpha 0 hides it.
uniform vec4 placement_rect = vec4(0.0);
uniform vec4 placement_color : source_color = vec4(0.0);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.03 + 1.7) * 0.3 + noise(p * 4.1 + 4.3) * 0.2;
}

// Cobblestones: distance to the cell edge (mortar) and a per-stone random value.
vec2 cobbles(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = 0.15 + 0.7 * hash2(i + g);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash(i + g + 3.1);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d2 - d1, id);
}

// Territory masks blurred over ~1.5 tiles (9 bilinear taps), so the 0.5 contour
// of each nation's mask is a smooth, rounded border.
vec4 territory(vec2 p) {
	vec2 px = 1.0 / map_size;
	vec2 uv = p * px;
	vec4 m = texture(territory_tex, uv) * 4.0;
	m += (texture(territory_tex, uv + vec2(px.x, 0.0)) + texture(territory_tex, uv - vec2(px.x, 0.0))
			+ texture(territory_tex, uv + vec2(0.0, px.y)) + texture(territory_tex, uv - vec2(0.0, px.y))) * 2.0;
	m += texture(territory_tex, uv + px) + texture(territory_tex, uv - px)
			+ texture(territory_tex, uv + vec2(px.x, -px.y)) + texture(territory_tex, uv + vec2(-px.x, px.y));
	return m / 16.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wp = world_pos.xz;
	vec4 tile = texture(color_tex, wp / map_size);
	vec3 c = tile.rgb;
	float rough = 0.95;

	// Moss and heath: broad damp/dry patches, then fine tufts so the ground reads
	// as grass, not a flat colour.
	float broad = fbm(wp * 0.35);
	c *= 0.78 + 0.4 * broad;
	// Isotropic only: a direction field here drew swirls and contour-like lines.
	// Fine detail fades with distance so it never aliases into moiré lines.
	float fine = 1.0 - smoothstep(0.03, 0.09, length(fwidth(wp)));
	float tufts = noise(wp * 7.0 + 3.0) * 0.55 + noise(wp * 17.0) * 0.45 * mix(0.4, 1.0, fine);
	c *= 0.84 + 0.3 * tufts;
	// Dry, yellowed heath and dark peaty hollows.
	float dry = smoothstep(0.55, 0.75, fbm(wp * 0.12 + 9.0));
	c = mix(c, c * vec3(1.18, 1.08, 0.78), dry * 0.45);
	float damp = smoothstep(0.6, 0.8, fbm(wp * 0.18 + 31.0));
	c = mix(c, c * vec3(0.62, 0.66, 0.6), damp * 0.6);
	// Soot fallout from the chimneys: sooty, desaturated patches.
	float soot = smoothstep(0.6, 0.82, fbm(wp * 0.09 + 17.0));
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(c, vec3(lum) * vec3(0.7, 0.68, 0.66), soot * 0.6);

	// Paving: cobbles with dark mortar, ringed by packed, sooty earth.
	float pave_raw = tile.a;
	if (pave_raw > 0.01) {
		float edge = fbm(wp * 1.3) * 0.35;
		float earth = smoothstep(0.05, 0.3, pave_raw + edge - 0.15);
		float stone = smoothstep(0.45, 0.62, pave_raw + edge - 0.1);
		vec3 dirt = vec3(0.19, 0.16, 0.13) * (0.8 + 0.35 * fbm(wp * 3.0));
		c = mix(c, dirt, earth * 0.85);
		vec2 cb = cobbles(wp * 3.2);
		vec3 rock = mix(vec3(0.2, 0.2, 0.2), vec3(0.32, 0.3, 0.27), cb.y);
		rock *= 0.85 + 0.25 * noise(wp * 18.0);
		float mortar = 1.0 - smoothstep(0.03, 0.12, cb.x);
		vec3 cobble = mix(rock, vec3(0.07, 0.065, 0.06), mortar);
		// Grime and wheel ruts darken the stones in places.
		cobble *= 0.75 + 0.3 * fbm(wp * 0.6 + 5.0);
		c = mix(c, cobble, stone);
		rough = mix(rough, 0.75, stone * (1.0 - mortar));
	}

	vec4 m = territory(wp);
	int o = 0;
	float best = 0.0;
	float second = 0.0;
	for (int i = 0; i < 4; i++) {
		if (m[i] > best) {
			second = best;
			best = m[i];
			o = i + 1;
		} else if (m[i] > second) {
			second = m[i];
		}
	}
	// Signed field: > 0 inside the nation, 0 on its border (against neutral land
	// or a neighbour).
	float field = min(best - 0.5, (best - second) * 0.5);
	if (o > 0 && field > -0.5) {
		vec3 tc = team_colors[o - 1].rgb;
		// Field slope per world unit, from screen derivatives, turns the field
		// into a distance so the line keeps a constant width on the ground.
		vec2 wx = dFdx(wp);
		vec2 wy = dFdy(wp);
		vec2 gs = vec2(dFdx(field), dFdy(field));
		float det = wx.x * wy.y - wx.y * wy.x;
		vec2 gw = abs(det) > 1e-6 ? vec2(gs.x * wy.y - gs.y * wx.y, gs.y * wx.x - gs.x * wy.x) / det : vec2(0.0);
		float dist = field / max(length(gw), 0.05);
		// A soft wash of the national colour fading in from the border.
		if (dist > 0.0) {
			float wash = exp(-dist * 2.2);
			c = mix(c, tc, 0.03 + 0.12 * wash);
		}
		// A thin solid line with a dark edge outside so it reads on any ground.
		float line = 1.0 - smoothstep(0.04, 0.09, abs(dist - 0.02));
		float shade = (1.0 - smoothstep(0.0, 0.16, -dist)) * step(dist, 0.0);
		c *= 1.0 - shade * 0.35;
		c = mix(c, tc * 1.1, line * 0.85);
	}

	if (placement_color.a > 0.0) {
		vec2 p = wp - placement_rect.xy;
		if (p.x >= 0.0 && p.y >= 0.0 && p.x <= placement_rect.z && p.y <= placement_rect.w) {
			vec2 g = fract(p);
			float grid = 1.0 - smoothstep(0.03, 0.07, min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y)));
			c = mix(c, placement_color.rgb, placement_color.a * (0.45 + 0.4 * grid));
		}
	}

	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.2;
}
