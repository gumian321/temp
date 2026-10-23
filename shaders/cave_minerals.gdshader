shader_type canvas_item;
render_mode unshaded;

varying vec3 mineral_tint;

void vertex() {
	mineral_tint = COLOR.rgb;
}

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float value = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
	// The atlas's exposed colored grains are the only hue mask. Host rock,
	// dark matrix and ordinary silver-white grains remain strictly grayscale.
	float exposed = smoothstep(0.015, 0.065, min(sample_color.g, sample_color.b) - sample_color.r);
	float tint_value = max(dot(mineral_tint, vec3(0.299, 0.587, 0.114)), 0.01);
	vec3 mineral = clamp(vec3(value) * mineral_tint / tint_value, vec3(0.0), vec3(1.0));
	COLOR = vec4(mix(vec3(value), mineral, exposed), sample_color.a);
}
