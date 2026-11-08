shader_type spatial;
// Ground: per-tile colours (linearly blended), procedural detail, national
// borders and the building-placement footprint.

uniform sampler2D color_tex : source_color, filter_linear, repeat_disable;
// One mask channel per nation (RGBA = owners 0-3), one texel per tile.
uniform sampler2D territory_tex : filter_linear, repeat_disable;
uniform vec4 team_colors[4] : source_color;
// Second heraldic colour per team: borders are dashed in both (e.g. black and gold).
uniform vec4 team_colors2[4] : source_color;
uniform vec2 map_size = vec2(96.0, 96.0);
// Placement footprint in tiles (x, y, w, h) and its colour; alpha 0 hides it.
uniform vec4 placement_rect = vec4(0.0);
uniform vec4 placement_color : source_color = vec4(0.0);
// Aether ley-lines: faint glowing veins in the earth.
uniform vec3 ley_color : source_color = vec3(0.35, 0.75, 1.0);
uniform float ley_strength = 0.6;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
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
	vec2 uv = world_pos.xz / map_size;
	vec3 c = texture(color_tex, uv).rgb;
	float n = noise(world_pos.xz * 2.5) * 0.6 + noise(world_pos.xz * 9.0) * 0.4;
	c *= 0.82 + 0.34 * n;
	// Scorched, sooty patches break up the green.
	float soot = smoothstep(0.62, 0.8, noise(world_pos.xz * 0.21 + 17.0));
	c = mix(c, c * vec3(0.62, 0.58, 0.55), soot * 0.7);

	// Ley-lines: contour lines of a slow noise field, shown only in some regions
	// and kept off the water, pulsing gently.
	vec3 ley = vec3(0.0);
	if (world_pos.y > -0.12) {
		vec2 q = world_pos.xz * 0.085 + vec2(noise(world_pos.xz * 0.3), noise(world_pos.xz * 0.3 + 5.0)) * 0.6;
		float f = noise(q) + 0.5 * noise(q * 2.3 + 3.0);
		float w = max(fwidth(f), 1e-4);
		float line = 1.0 - smoothstep(w * 0.4, w * 1.6, abs(f - 0.72));
		float region = smoothstep(0.52, 0.7, noise(world_pos.xz * 0.05 + 40.0));
		float pulse = 0.65 + 0.35 * sin(TIME * 1.3 + f * 18.0);
		float glow = line * region * pulse;
		c = mix(c, ley_color * 0.5, glow * 0.35);
		ley = ley_color * glow * ley_strength;
	}

	vec4 m = territory(world_pos.xz);
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
		vec2 wx = dFdx(world_pos.xz);
		vec2 wy = dFdy(world_pos.xz);
		vec2 gs = vec2(dFdx(field), dFdy(field));
		float det = wx.x * wy.y - wx.y * wy.x;
		vec2 gw = abs(det) > 1e-6 ? vec2(gs.x * wy.y - gs.y * wx.y, gs.y * wx.x - gs.x * wy.x) / det : vec2(0.0);
		float dist = field / max(length(gw), 0.05);
		if (field > 0.0) {
			c = mix(c, tc, 0.08);
		}
		float line = 1.0 - smoothstep(0.05, 0.12, abs(dist));
		float dash = step(0.5, fract((world_pos.x + world_pos.z) * 0.9));
		vec3 border = mix(tc * 1.15, team_colors2[o - 1].rgb, dash);
		c = mix(c, border, line * 0.9);
	}

	if (placement_color.a > 0.0) {
		vec2 p = world_pos.xz - placement_rect.xy;
		if (p.x >= 0.0 && p.y >= 0.0 && p.x <= placement_rect.z && p.y <= placement_rect.w) {
			vec2 g = fract(p);
			float grid = 1.0 - smoothstep(0.03, 0.07, min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y)));
			c = mix(c, placement_color.rgb, placement_color.a * (0.45 + 0.4 * grid));
		}
	}

	ALBEDO = c;
	EMISSION = ley;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
