uniform sampler2D repair_data : filter_nearest, repeat_disable;
vec2 repair_point(int i,int slot){return texelFetch(repair_data,ivec2(i,slot),0).xy;}
vec2 repair_normalized(vec2 v){float len=sqrt(dot(v,v));return len==0.0?vec2(0.0):v/len;}
vec2 repair_ortho(vec2 v){return vec2(v.y,-v.x);}
bool repair_approximately(vec2 a,vec2 b){return all(lessThan(abs(a-b),max(vec2(0.00001),0.00001*abs(a))));}
vec2 repair_edge(vec2 direction,vec2 previous){
 vec2 bisector=repair_normalized(previous*length(direction)-direction*length(previous));
 float angle=atan(bisector.x*previous.y-bisector.y*previous.x,dot(bisector,previous));
 float sine=sin(angle);float reach=1.0;
 if(abs(sine)>=0.00001 && !repair_approximately(direction,previous)){reach=clamp(1.0/sine,-3.0,3.0);}
 else{bisector=repair_ortho(direction);}
 if(dot(bisector,bisector)==0.0){bisector=repair_ortho(direction);}
 return bisector*reach;
}
