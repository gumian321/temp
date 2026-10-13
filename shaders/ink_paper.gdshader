shader_type canvas_item;
render_mode unshaded;
uniform vec2 camera_world;
uniform vec2 viewport_size = vec2(1440.0, 900.0);
uniform float camera_zoom = 1.0;
uniform vec2 screen_offset;
uniform float terrain_strength = 1.0;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float wash(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), blend.x), blend.y);
}

float sand(vec2 p, float aa, float patch) {
	vec2 cell = floor(p / 44.0);
	// Keep each jittered mark inside its cell, so no neighbour search is needed.
	vec2 point = (cell + 0.16 + 0.68 * vec2(hash(cell), hash(cell + 17.3))) * 44.0;
	float radius = mix(0.8, 1.8, hash(cell + 8.7));
	float dot_mask = 1.0 - smoothstep(radius, radius + aa, length((p - point) * vec2(0.85, 1.25)));
	float present = step(0.2 + patch * 0.35, hash(cell + 41.8));
	return dot_mask * present * mix(0.24, 0.42, hash(cell + 2.4));
}

float pebbles(vec2 p, float aa) {
	vec2 cell = floor(p / 184.0);
	vec2 point = (cell + 0.18 + 0.64 * vec2(hash(cell + 5.6), hash(cell + 23.1))) * 184.0;
	vec2 local = p - point;
	float angle = hash(cell + 11.4) * 6.283185;
	local = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * local;
	float stone = 1.0 - smoothstep(2.7, 2.7 + aa, length(local * vec2(0.7, 1.3)));
	float grain = 1.0 - smoothstep(1.2, 1.2 + aa, length(local - vec2(7.0, 4.0)));
	float fleck = 1.0 - smoothstep(1.0, 1.0 + aa, length((local + vec2(5.0, 6.0)) * vec2(0.5, 1.4)));
	return (stone * 0.25 + grain * 0.30 + fleck * 0.18) * step(0.48, hash(cell + 51.2));
}

void fragment() {
	vec2 paper_px = UV * viewport_size;
	float fiber = hash(floor(paper_px)) * 0.018 + sin(paper_px.y * 2.1) * 0.005;
	float edge = smoothstep(0.28, 0.82, length(UV - 0.5));
	vec3 paper = vec3(0.965, 0.949, 0.906) - fiber - edge * 0.035;
	// Invert main.world(): ground and actors share translation, zoom and recoil.
	// No TIME or frame-random noise: stopping the camera stops the terrain.
	vec2 world_px = (paper_px - viewport_size * 0.5 - screen_offset) / max(camera_zoom, 0.01) + camera_world;
	float aa = 0.65 / max(camera_zoom, 0.01);
	float patch = wash(world_px / 320.0);
	vec3 ground = mix(paper, vec3(0.60, 0.68, 0.74), smoothstep(0.32, 0.82, patch) * 0.055);
	float marks = clamp(sand(world_px, aa, patch) + pebbles(world_px, aa), 0.0, 0.5);
	ground = mix(ground, vec3(0.34, 0.44, 0.55), marks);
	COLOR = vec4(mix(paper, ground, terrain_strength), 1.0);
}
