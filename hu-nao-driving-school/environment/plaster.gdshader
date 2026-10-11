shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 plaster_color : source_color = vec4(0.827,0.802,0.681,1.0);
varying vec3 world;
float hash(vec3 p){ return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float fine=hash(floor(world*110.0));
 float low=sin(world.x*1.2+sin(world.y*1.4))*sin(world.z*1.7+world.y*1.8);
 float base_patina=mix(0.90,1.0,smoothstep(0.35,1.40,world.y));
 ALBEDO=plaster_color.rgb*base_patina+(fine-0.5)*0.004+low*0.006;
 ROUGHNESS=0.96;
 SPECULAR=0.08;
}
