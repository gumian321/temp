shader_type spatial;
render_mode diffuse_toon, specular_schlick_ggx;
varying vec3 model_pos;
void vertex() { model_pos = VERTEX; }
void fragment() {
 float stripe = 1.0 - smoothstep(0.72, 0.77, model_pos.y);
 ALBEDO = mix(vec3(0.76,0.75,0.69), vec3(0.62,0.028,0.034), stripe);
 ROUGHNESS = 0.38; METALLIC = 0.1; SPECULAR = 0.42;
 CLEARCOAT = 0.32; CLEARCOAT_ROUGHNESS = 0.26;
 RIM = 0.12; RIM_TINT = 0.3;
}
