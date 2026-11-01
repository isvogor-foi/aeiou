shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
// Fog of war as a full-screen pass: reconstructs each pixel's world position from
// the depth buffer and darkens it by the player's visibility map (1 texel per tile).

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(96.0, 96.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec2 uv = world.xz / map_size;
	float a = 1.0;
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		a = texture(fog_tex, uv).a;
	}
	ALBEDO = vec3(0.0);
	ALPHA = a;
}
