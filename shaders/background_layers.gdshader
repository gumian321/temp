shader_type canvas_item;
render_mode unshaded;
uniform sampler2D layer0 : source_color, filter_linear, repeat_disable;
uniform sampler2D layer1 : source_color, filter_linear, repeat_disable;
uniform sampler2D layer2 : source_color, filter_linear, repeat_disable;
uniform sampler2D layer3 : source_color, filter_linear, repeat_disable;
uniform vec2 camera_world;
uniform vec2 viewport_size=vec2(1440.0,900.0);
uniform vec4 base_color : source_color;
vec3 over(vec3 under,vec4 above){return mix(under,above.rgb,above.a);}
void fragment(){
 vec2 at=UV*viewport_size/900.0;
 vec3 color=base_color.rgb;
 color=over(color,texture(layer0,fract(at+camera_world/48.0*0.02)));
 color=over(color,texture(layer1,fract(at+camera_world/48.0*0.01)));
 color=over(color,texture(layer2,fract(at+camera_world/48.0*0.02)));
 color=over(color,texture(layer3,fract(at+camera_world/48.0*0.06)));
 COLOR=vec4(color,1.0);
}
