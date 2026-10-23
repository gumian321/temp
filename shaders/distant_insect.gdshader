shader_type canvas_item;
#include "res://shaders/charcoal_palette.gdshaderinc"
varying float gait;
varying float walking;
void vertex() {
	gait = COLOR.r * 6.28318530718;
	walking = COLOR.g;
}
void fragment() {
	vec2 uv = UV;
	float edge = smoothstep(0.16, 0.34, abs(uv.x - 0.5));
	// Small alternating steps on the legs; the center of the torso stays still.
	uv.y += sin(gait + floor(uv.y * 6.0) * 3.14159265 + step(0.5, uv.x) * 3.14159265) * 0.018 * edge * walking;
	vec4 ink = texture(TEXTURE, uv);
	COLOR = vec4(charcoal_pigment(ink.rgb), ink.a);
}
