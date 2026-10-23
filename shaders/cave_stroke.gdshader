shader_type canvas_item;
render_mode unshaded;
uniform vec4 ink_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float half_width = 0.5;
varying float half_length;
void vertex() {
	// Mesh colors use two UNORM8 channels for subpixel line lengths.
	half_length = (round(COLOR.r * 255.0) * 256.0 + round(COLOR.g * 255.0)) / 256.0;
}
void fragment() {
	vec2 q = abs(UV) - vec2(half_length, half_width);
	float distance_to_ink = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	float pixel = max(length(vec2(dFdx(UV.y), dFdy(UV.y))), 0.0001);
	float coverage = clamp(0.5 - distance_to_ink / pixel, 0.0, 1.0);
	COLOR = vec4(ink_color.rgb, ink_color.a * coverage);
}
