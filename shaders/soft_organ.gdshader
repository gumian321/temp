shader_type canvas_item;
render_mode unshaded;

// Same 8 x 8 grid and equations as soft_organ_art.deform(). The CPU controls
// time, so pausing and hit holds do not advance the organ independently.
uniform vec2 extent = vec2(1.0);
uniform int family = 0;
uniform vec4 pose = vec4(0.0); // phase, kick, activity, flame pumping
uniform vec3 traction = vec3(0.0); // normalized local axis, signed strain

void vertex() {
	vec2 p = VERTEX;
	vec2 local_uv = p + vec2(0.5);
	float phase = pose.x;
	float kick = pose.y;
	float weight = clamp((0.5 - p.y) / 0.85, 0.0, 1.0);
	float breath = sin(phase * 3.1) * 0.035;
	if (family == 1) {
		float side = p.x < 0.0 ? -1.0 : 1.0;
		float wing = smoothstep(0.07, 0.40, abs(p.x));
		float flap = sin(phase * 5.8 + side * 0.22 - p.y * 1.7);
		p.x *= 1.0 - wing * (0.24 + 0.22 * flap) + wing * kick * 0.15;
		p.y += wing * (0.10 * flap + 0.045 * sin(phase * 7.2 - abs(p.x) * 8.0) - kick * 0.13);
		p.x += wing * sin(phase * 3.5 - p.y * 4.0) * 0.025;
	} else if (family == 2) {
		float belly = sin(local_uv.y * PI) * weight;
		p.x *= 1.0 + (breath + kick * 0.32 + pose.w) * belly;
		p.y += (kick * 0.17 - breath * 0.3) * weight;
		p.x += sin(phase * 3.6 - local_uv.y * 5.0) * 0.025 * weight;
	} else if (family == 3) {
		float tip = weight * weight;
		p.x *= 1.0 + (sin(phase * 3.2) * 0.055 + kick * 0.38) * tip;
		p.y -= kick * 0.20 * tip;
		p.x += sin(phase * 4.5 - local_uv.y * 4.0) * 0.018 * tip;
	} else if (family == 0) {
		p.x *= 1.0 + (breath + kick * 0.20 + pose.z * sin(phase * 8.0) * 0.035) * weight;
		p.y += (breath * 0.5 + kick * 0.09) * weight;
	}
	if (family >= 0) { p.x += sin(phase * 2.3) * 0.016 * weight; }
	p *= extent;
	vec2 axis = traction.xy;
	vec2 normal = vec2(axis.y, -axis.x);
	p += axis * dot(p, axis) * traction.z - normal * dot(p, normal) * traction.z * 0.42;
	VERTEX = p;
}
