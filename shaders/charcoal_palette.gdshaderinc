// Retain sparse cyan/rose cues while mapping legacy blue pigment to black ink.
vec3 charcoal_pigment(vec3 raw) {
	float light = dot(raw, vec3(0.299, 0.587, 0.114));
	float navy = step(raw.r * 1.18, raw.b) * (1.0 - smoothstep(0.35, 0.64, raw.g));
	float tone = smoothstep(0.10, 0.86, light) * (1.0 - navy * 0.68);
	vec3 chalk = mix(vec3(0.018), vec3(0.92, 0.91, 0.88), tone);
	float cyan = step(raw.r * 1.5, raw.g) * step(0.48, raw.g) * step(raw.r * 1.5, raw.b);
	float rose = step(0.66, raw.r) * step(0.42, raw.b) * (1.0 - step(0.48, raw.g));
	return mix(chalk, raw, max(cyan, rose));
}
