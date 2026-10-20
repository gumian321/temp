shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/charcoal_palette.gdshaderinc"
uniform bool ui_surface = false;
varying vec4 ink_modulate;
void vertex() { ink_modulate = COLOR; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 raw = tex.rgb * ink_modulate.rgb;
	vec3 ink = vec3(0.090, 0.231, 0.439);
	vec3 paper = vec3(0.965, 0.949, 0.906);
	float luminance = dot(raw, vec3(0.299, 0.587, 0.114));
	float shade = 1.0 - smoothstep(0.04, 0.91, luminance);
	if (ui_surface) { shade = smoothstep(0.05, 0.90, luminance); }
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	float hatch = smoothstep(0.78, 1.0, sin((px.x + px.y) * 0.85));
	float crosshatch = smoothstep(0.85, 1.0, sin((px.x - px.y) * 0.71));
	float midtone = 4.0 * shade * (1.0 - shade);
	float hatch_weight = ui_surface ? 0.09 : 0.25;
	shade = clamp(shade * 0.85 + hatch * midtone * hatch_weight + crosshatch * midtone * shade * hatch_weight * 0.8, 0.0, 1.0);
	vec3 result = mix(paper, ink, shade);
	// Painted blue ink and code-drawn ink lines retain their own line weights.
	if (!ui_surface && raw.b > raw.r * 1.18 && raw.r < 0.55 && raw.g < 0.52 && raw.b < 0.85) { result = raw; }
	COLOR = vec4(charcoal_pigment(result), tex.a * ink_modulate.a);
}
