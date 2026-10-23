shader_type canvas_item;
render_mode unshaded;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap, repeat_enable;
void fragment() {
	float ink = dot(texture(rock_texture, UV).rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(0.44 + ink * 0.24), COLOR.a);
}
