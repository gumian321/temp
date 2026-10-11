shader_type spatial;
render_mode diffuse_burley, cull_disabled, specular_disabled;
uniform vec4 leaf_color : source_color = vec4(0.45,0.59,0.37,1.0);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float organic=sin(world.x*3.4+sin(world.z*2.0))*sin(world.y*3.1+world.z*2.7);
 ALBEDO=leaf_color.rgb*COLOR.rgb*(1.0+organic*0.018);
 ROUGHNESS=1.0;
 AO=0.93;
}
