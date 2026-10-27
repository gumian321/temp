shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// Experimental analytic equivalent of the native square 1.25-unit feathers.
// One instance is one complete outer/inner pair; instances retain segment order.
uniform vec4 outer_ink = vec4(0.0,0.0,0.0,1.0);
uniform vec4 inner_ink = vec4(1.0);
uniform bool separate_layers = false;
varying vec4 segment;

void vertex() {
	segment = INSTANCE_CUSTOM; // length, outer width, inner width, separate palette index
}

void fragment() {
	float outer_feather = 1.25 * min(1.0, segment.y);
	float inner_feather = 1.25 * min(1.0, segment.z);
	vec2 local = (UV - vec2(0.5)) * vec2(segment.x + 2.0 * outer_feather, segment.y + 2.0 * outer_feather);
	vec2 outer_distance = max(abs(local) - vec2(segment.x, segment.y) * 0.5, vec2(0.0));
	vec2 inner_distance = max(abs(local) - vec2(segment.x, segment.z) * 0.5, vec2(0.0));
	float outer_alpha = clamp(1.0 - max(outer_distance.x, outer_distance.y) / outer_feather, 0.0, 1.0) * outer_ink.a;
	float inner_alpha = clamp(1.0 - max(inner_distance.x, inner_distance.y) / inner_feather, 0.0, 1.0) * inner_ink.a;
	if (separate_layers) {
		vec4 ink = segment.w < 0.5 ? outer_ink : inner_ink;
		float coverage = clamp(1.0 - max(outer_distance.x, outer_distance.y) / outer_feather, 0.0, 1.0) * ink.a;
		COLOR = vec4(ink.rgb * coverage, coverage);
	} else {
	vec3 pigment = inner_ink.rgb * inner_alpha + outer_ink.rgb * outer_alpha * (1.0 - inner_alpha);
	float alpha = inner_alpha + outer_alpha * (1.0 - inner_alpha);
	COLOR = vec4(pigment, alpha);
	}
}
