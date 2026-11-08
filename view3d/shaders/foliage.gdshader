shader_type spatial;
// Trees (MultiMesh): low-poly meshes made to read as foliage. Canopy normals are
// bent outward from the trunk so the crown shades as one soft mass instead of
// flat facets; world-space noise paints leaf clumps, needle speckle and soot;
// the lower canopy and trunk fall into shadow; leaves sway gently in the wind.
// The instance colour (MultiMesh) varies each tree.

uniform vec3 base_color : source_color = vec3(0.11, 0.22, 0.17);
// 1 for leaves/needles, 0 for bark.
uniform float leafy = 1.0;
// Approximate tree height in world units, for the shadowed-base gradient.
uniform float tree_height = 4.0;

varying vec3 wpos;
varying float rel_h;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), u.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), u.x), u.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), u.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}

// 3D cellular noise: x = distance to the nearest cell centre, y = to the second.
vec2 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash3(i + g), hash3(i + g + 17.3), hash3(i + g + 41.7));
				float d = length(g + o - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec2(d1, d2);
}

// Bumps the shading normal by a height field `h` using screen-space derivatives.
vec3 bump(vec3 n, vec3 view_pos, float h, float strength) {
	vec3 dpdx = dFdx(view_pos);
	vec3 dpdy = dFdy(view_pos);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - grad * strength);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rel_h = clamp((w.y - origin.y) / tree_height, 0.0, 1.0);
	if (leafy > 0.5) {
		// Sway: higher parts move more; each tree has its own phase.
		float phase = origin.x * 0.37 + origin.z * 0.61;
		vec2 sway = vec2(sin(TIME * 1.1 + phase), cos(TIME * 0.83 + phase * 1.3)) * 0.05 * rel_h * rel_h;
		w.xz += sway;
		// Bend normals outward from the trunk (and a little up): a soft crown.
		vec3 out_dir = vec3(w.x - origin.x, 0.0, w.z - origin.z);
		vec3 crown_n = normalize(out_dir + vec3(0.0, 0.55 * tree_height * 0.25, 0.0) + vec3(1e-4));
		vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
		wn = normalize(mix(wn, crown_n, 0.7));
		NORMAL = normalize(inverse(mat3(MODEL_MATRIX)) * wn);
		VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
	}
	wpos = w;
}

void fragment() {
	vec3 c = base_color * COLOR.rgb;
	if (leafy > 0.5) {
		// Leaf clusters: rounded clumps (cellular), lit on top, dark in the gaps.
		vec2 cl = cells(wpos * 2.2);
		float clump = 1.0 - smoothstep(0.0, 0.85, cl.x);
		float gap = smoothstep(0.0, 0.22, cl.y - cl.x);
		vec2 cl2 = cells(wpos * 6.0 + 3.0);
		float small = 1.0 - smoothstep(0.0, 0.8, cl2.x);
		float h = clump * 0.7 + small * 0.3;
		c *= 0.72 + 0.5 * h;
		c *= 0.78 + 0.22 * gap;
		// Needle / leaf grain.
		float grain = noise3(vec3(wpos.x * 26.0, wpos.y * 9.0, wpos.z * 26.0));
		c *= 0.9 + 0.2 * grain;
		// Hue drift: some crowns olive, some blue-green, a few rusting.
		float hue = noise3(wpos * 0.35 + 11.0);
		c = mix(c, c * vec3(1.2, 1.1, 0.7), smoothstep(0.55, 0.85, hue) * 0.5);
		c = mix(c, c * vec3(0.85, 1.0, 1.12), smoothstep(0.45, 0.15, hue) * 0.4);
		// Soot settles in patches.
		float soot = smoothstep(0.6, 0.9, noise3(wpos * 0.6 + 4.0)) * 0.3;
		c = mix(c, vec3(dot(c, vec3(0.33))) * 0.7, soot);
		// Inner/lower canopy in shade, tips catching light.
		c *= mix(0.75, 1.2, smoothstep(0.1, 0.95, rel_h));
		NORMAL = bump(NORMAL, VERTEX, h, 0.45);
		SSS_STRENGTH = 0.25;
		ROUGHNESS = 0.8;
		BACKLIGHT = c * 0.35;
	} else {
		// Bark: vertical fibres and dark furrows, mossy at the foot.
		float fibres = noise3(vec3(wpos.x * 14.0, wpos.y * 1.5, wpos.z * 14.0));
		float furrow = smoothstep(0.35, 0.6, noise3(vec3(wpos.x * 30.0, wpos.y * 3.0, wpos.z * 30.0)));
		c *= 0.55 + 0.6 * fibres;
		c *= 0.65 + 0.35 * furrow;
		c = mix(vec3(0.16, 0.2, 0.12), c, smoothstep(0.0, 0.12, rel_h));
		NORMAL = bump(NORMAL, VERTEX, furrow * 0.5 + fibres * 0.5, 0.5);
		ROUGHNESS = 0.95;
	}
	ALBEDO = c;
}
