shader_type canvas_item;
render_mode unshaded;
// Shared, texture-only mapping for the existing generated ink icon atlas.
// World illustration materials are intentionally untouched.
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
void fragment() {
 vec4 t=texture(TEXTURE,UV);
 float l=dot(t.rgb,vec3(0.299,0.587,0.114));
 vec3 pale=vec3(0.96,0.87,0.98);
 vec3 rose=vec3(1.0,0.30,0.64);
 vec3 color=mix(pale,rose,smoothstep(0.25,0.95,l)*0.68);
 COLOR=vec4(color,t.a)*vertex_tint;
}
