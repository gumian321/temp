shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 asphalt_dark : source_color = vec4(0.285,0.335,0.331,1.0);
uniform vec4 asphalt_light : source_color = vec4(0.320,0.365,0.350,1.0);
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+1.0),f.x),f.y);
}
void vertex(){ world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float grain=noise(world.xz*190.0);
 float aggregate=noise(world.xz*31.0);
 float broad=noise(world.xz*0.38);
 vec3 base=mix(asphalt_dark.rgb,asphalt_light.rgb,broad);
 ALBEDO=base+(grain-0.5)*0.012+(aggregate-0.5)*0.009;
 ROUGHNESS=0.92;
 SPECULAR=0.12;
}
