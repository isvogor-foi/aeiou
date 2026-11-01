shader_type spatial;
render_mode cull_disabled;
// Cloth that ripples in the wind; the pole edge (UV.x = 0) stays put.

uniform sampler2D flag_tex : source_color, filter_nearest;
uniform float wave = 0.12;
uniform float speed = 3.0;
uniform float phase = 0.0;

void vertex() {
	float k = UV.x;
	VERTEX.z += sin(UV.x * 7.0 - TIME * speed + phase) * wave * k;
	VERTEX.y += sin(UV.x * 5.0 - TIME * speed * 0.7 + phase) * wave * 0.25 * k;
}

void fragment() {
	vec3 c = texture(flag_tex, UV).rgb;
	// Gentle shading along the folds.
	float fold = 0.85 + 0.15 * sin(UV.x * 7.0 - TIME * speed + phase);
	ALBEDO = c * fold;
	ROUGHNESS = 0.9;
}
