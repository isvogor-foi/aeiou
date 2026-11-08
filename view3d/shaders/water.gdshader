shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;
// Lakes: depth-tinted, gently rippling, with foam where water meets the shore.

uniform vec3 shallow_color : source_color = vec3(0.2, 0.36, 0.36);
uniform vec3 deep_color : source_color = vec3(0.05, 0.13, 0.17);
uniform vec3 foam_color : source_color = vec3(0.55, 0.6, 0.58);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

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

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float water_depth = clamp(VERTEX.z - behind.z, 0.0, 2.0);

	vec2 p = world_pos.xz;
	float t = TIME * 0.4;
	float ripple = noise(p * 1.6 + vec2(t, t * 0.7)) * 0.5 + noise(p * 3.7 - vec2(t * 0.8, t)) * 0.5;
	vec3 c = mix(shallow_color, deep_color, smoothstep(0.05, 0.7, water_depth));
	c += vec3(0.06) * smoothstep(0.62, 0.9, ripple);
	float foam = 1.0 - smoothstep(0.01, 0.07 + 0.04 * ripple, water_depth);
	c = mix(c, foam_color, foam * 0.35);

	ALBEDO = c;
	ALPHA = mix(0.75, 0.95, smoothstep(0.0, 0.5, water_depth));
	ROUGHNESS = 0.22;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	NORMAL = normalize(NORMAL + vec3(ripple - 0.5, 0.0, noise(p * 2.3 + t) - 0.5) * 0.15);
}
