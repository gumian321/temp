shader_type canvas_item;
render_mode unshaded;
uniform sampler2D neck_data : filter_nearest, repeat_disable;
varying vec4 pigment;
vec2 point_at(int i,int slot){return texelFetch(neck_data,ivec2(i,slot),0).xy;}
vec2 normalized_safe(vec2 v){float len=sqrt(dot(v,v));return len==0.0?vec2(0.0):v/len;}
vec2 ortho(vec2 v){return vec2(v.y,-v.x);}
bool approximately(vec2 a,vec2 b){return all(lessThan(abs(a-b),max(vec2(0.00001),0.00001*abs(a))));}
vec2 edge_offset(vec2 direction,vec2 previous){
	vec2 bisector=normalized_safe(previous*length(direction)-direction*length(previous));
	float angle=atan(bisector.x*previous.y-bisector.y*previous.x,dot(bisector,previous));
	float sine=sin(angle);float reach=1.0;
	if(abs(sine)>=0.00001 && !approximately(direction,previous)){reach=clamp(1.0/sine,-3.0,3.0);}
	else{bisector=ortho(direction);}
	if(dot(bisector,bisector)==0.0){bisector=ortho(direction);}
	return bisector*reach;
}
void vertex(){
	int slot=int(INSTANCE_CUSTOM.r);
	vec4 pose=texelFetch(neck_data,ivec2(9,slot),0);
	vec4 opacity=texelFetch(neck_data,ivec2(10,slot),0);
	if(UV.y<0.5){
		VERTEX=VERTEX*(pose.z+UV.x*1.25)+pose.xy;
		pigment=vec4(vec3(18.0/255.0),UV.x>0.5?0.0:opacity.x);
	}else{
		int index=int(VERTEX.x);float side=VERTEX.y;
		vec2 first=vec2(0.0);vec2 last=vec2(0.0);
		for(int i=1;i<9;i++){
			vec2 delta=point_at(i,slot)-point_at(i-1,slot);
			if(dot(delta,delta)>0.0){first=normalized_safe(delta);break;}
		}
		for(int i=8;i>0;i--){
			vec2 delta=point_at(i,slot)-point_at(i-1,slot);
			if(dot(delta,delta)>0.0){last=normalized_safe(delta);break;}
		}
		vec2 previous=index==0?vec2(0.0):normalized_safe(point_at(index,slot)-point_at(index-1,slot));
		vec2 direction=index==8?previous:normalized_safe(point_at(index+1,slot)-point_at(index,slot));
		if(dot(direction,direction)==0.0){direction=previous;}
		vec2 base=index==0?ortho(first):(index==8?ortho(last):edge_offset(direction,previous));
		float width=(UV.y<1.5?6.0:3.0)*pose.w;
		float feather=width<1.0?1.25*width:1.25;
		float cap=UV.x>=2.0?UV.x-3.0:UV.x;
		vec2 edge=base*(width*0.5);vec2 border=base*feather;
		// Preserve native additions rather than combining a different expression.
		vec2 offset=point_at(index,slot)+side*edge;
		if(UV.x>=2.0){offset+=side*border;}
		if(cap!=0.0){offset+=(index==0?direction:previous)*(cap*feather);}
		VERTEX=offset;
		vec3 ink=UV.y<1.5?vec3(18.0/255.0):vec3(146.0/255.0,145.0/255.0,139.0/255.0);
		pigment=vec4(ink,UV.x==0.0?(UV.y<1.5?opacity.y:opacity.z):0.0);
	}
}
void fragment(){COLOR=pigment;}
