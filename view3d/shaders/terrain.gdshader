shader_type spatial;
// Ground: per-tile colours (linearly blended), procedural detail, national
// borders and the building-placement footprint.

uniform sampler2D color_tex : source_color, filter_linear, repeat_disable;
// R channel = territory owner + 1 (0 = neutral), one texel per tile.
uniform sampler2D territory_tex : filter_nearest, repeat_disable;
uniform vec4 team_colors[4] : source_color;
// Second heraldic colour per team: borders are dashed in both (e.g. black and gold).
uniform vec4 team_colors2[4] : source_color;
uniform vec2 map_size = vec2(96.0, 96.0);
// Placement footprint in tiles (x, y, w, h) and its colour; alpha 0 hides it.
uniform vec4 placement_rect = vec4(0.0);
uniform vec4 placement_color : source_color = vec4(0.0);

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

int owner_at(ivec2 t) {
	ivec2 c = clamp(t, ivec2(0), ivec2(map_size) - 1);
	if (c != t) {
		return 0;
	}
	return int(texelFetch(territory_tex, t, 0).r * 255.0 + 0.5);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / map_size;
	vec3 c = texture(color_tex, uv).rgb;
	float n = noise(world_pos.xz * 2.5) * 0.6 + noise(world_pos.xz * 9.0) * 0.4;
	c *= 0.86 + 0.28 * n;

	ivec2 t = ivec2(floor(world_pos.xz));
	int o = owner_at(t);
	if (o > 0) {
		vec3 tc = team_colors[o - 1].rgb;
		c = mix(c, tc, 0.08);
		vec2 f = fract(world_pos.xz);
		float edge = 1.0;
		if (owner_at(t + ivec2(-1, 0)) != o) { edge = min(edge, f.x); }
		if (owner_at(t + ivec2(1, 0)) != o) { edge = min(edge, 1.0 - f.x); }
		if (owner_at(t + ivec2(0, -1)) != o) { edge = min(edge, f.y); }
		if (owner_at(t + ivec2(0, 1)) != o) { edge = min(edge, 1.0 - f.y); }
		float line = 1.0 - smoothstep(0.05, 0.12, edge);
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
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
