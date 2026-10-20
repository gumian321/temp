shader_type canvas_item;
#include "res://shaders/charcoal_palette.gdshaderinc"
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float pressure : hint_range(0.0, 1.5) = 0.0;
uniform vec2 contact_uv = vec2(0.5);
void fragment() {
	vec4 ink = COLOR;
	ink.rgb = charcoal_pigment(ink.rgb);
	float bruise = exp(-dot(UV-contact_uv, UV-contact_uv)*32.0);
	ink.rgb = mix(ink.rgb, ink.rgb*vec3(0.55,0.72,0.91), bruise*pressure*0.33);
	float highlights = smoothstep(0.22,0.65,dot(ink.rgb,vec3(0.299,0.587,0.114)));
	ink.rgb = mix(ink.rgb, vec3(1.0,0.66,0.37), hit_flash*highlights*0.85);
	COLOR = ink;
}
