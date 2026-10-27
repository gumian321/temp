shader_type canvas_item;
uniform sampler2D icon_data : filter_nearest, repeat_disable;
uniform sampler2D source_0 : filter_linear, repeat_disable;
uniform sampler2D source_1 : filter_linear, repeat_disable;
uniform sampler2D source_2 : filter_linear, repeat_disable;
uniform sampler2D source_3 : filter_linear, repeat_disable;
uniform sampler2D source_4 : filter_linear, repeat_disable;
uniform sampler2D source_5 : filter_linear, repeat_disable;
uniform sampler2D source_6 : filter_linear, repeat_disable;
uniform sampler2D source_7 : filter_linear, repeat_disable;
varying flat float icon_flag;
varying flat int icon_source;
varying flat float icon_clip;
varying vec4 icon_tint;
varying vec4 icon_bounds;
void vertex(){
	icon_flag=INSTANCE_CUSTOM.b<-70.5 && INSTANCE_CUSTOM.b>-71.5?1.0:0.0;
	icon_source=0;icon_clip=0.0;icon_tint=vec4(1.0);icon_bounds=vec4(0.0);
	if(icon_flag>0.5){
		int index=int(INSTANCE_CUSTOM.r);
		vec4 placement=texelFetch(icon_data,ivec2(0,index),0);
		vec4 entry=texelFetch(icon_data,ivec2(2,index),0);
		icon_source=int(entry.r);icon_clip=entry.g;
		vec4 region=texelFetch(icon_data,ivec2(3,index),0);icon_bounds=texelFetch(icon_data,ivec2(4,index),0);
		icon_tint=texelFetch(icon_data,ivec2(1,index),0)*COLOR;
		VERTEX=placement.xy+placement.zw*VERTEX;
		UV=region.xy+abs(region.zw)*UV;
	}
}
void fragment(){
	if(icon_flag>0.5){
		vec2 coord=icon_clip>0.5?clamp(UV,icon_bounds.xy,icon_bounds.zw):UV;
		vec4 tex;
		if(icon_source==0){tex=texture(source_0,coord);}
		else if(icon_source==1){tex=texture(source_1,coord);}
		else if(icon_source==2){tex=texture(source_2,coord);}
		else if(icon_source==3){tex=texture(source_3,coord);}
		else if(icon_source==4){tex=texture(source_4,coord);}
		else if(icon_source==5){tex=texture(source_5,coord);}
		else if(icon_source==6){tex=texture(source_6,coord);}
		else{tex=texture(source_7,coord);}
		COLOR=tex*icon_tint;
	}
}
