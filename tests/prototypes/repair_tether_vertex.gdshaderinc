if(INSTANCE_CUSTOM.b<-66.5 && INSTANCE_CUSTOM.b>-67.5){
 int slot=int(INSTANCE_CUSTOM.r);
 vec4 pose=texelFetch(repair_data,ivec2(9,slot),0);
 if(UV.y<0.5){
  VERTEX=VERTEX*(pose.z+UV.x*1.25)+pose.xy;
  COLOR=vec4(vec3(105.0/255.0,182.0/255.0,156.0/255.0),UV.x>0.5?0.0:0.75);
 }else{
  int index=int(VERTEX.x);float side=VERTEX.y;
  vec2 first=vec2(0.0);vec2 last=vec2(0.0);
  for(int i=1;i<9;i++){
   vec2 delta=repair_point(i,slot)-repair_point(i-1,slot);
   if(dot(delta,delta)>0.0){first=repair_normalized(delta);break;}
  }
  for(int i=8;i>0;i--){
   vec2 delta=repair_point(i,slot)-repair_point(i-1,slot);
   if(dot(delta,delta)>0.0){last=repair_normalized(delta);break;}
  }
  vec2 previous=index==0?vec2(0.0):repair_normalized(repair_point(index,slot)-repair_point(index-1,slot));
  vec2 direction=index==8?previous:repair_normalized(repair_point(index+1,slot)-repair_point(index,slot));
  if(dot(direction,direction)==0.0){direction=previous;}
  vec2 base=index==0?repair_ortho(first):(index==8?repair_ortho(last):repair_edge(direction,previous));
  float width=(UV.y<1.5?3.2:1.7)*pose.w;
  float feather=width<1.0?1.25*width:1.25;
  float cap=UV.x>=2.0?UV.x-3.0:UV.x;
  vec2 edge=base*(width*0.5);vec2 border=base*feather;
  vec2 offset=repair_point(index,slot)+side*edge;
  if(UV.x>=2.0){offset+=side*border;}
  if(cap!=0.0){offset+=(index==0?direction:previous)*(cap*feather);}
  VERTEX=offset;
  vec3 ink=UV.y<1.5?vec3(36.0/255.0,71.0/255.0,92.0/255.0):vec3(105.0/255.0,182.0/255.0,156.0/255.0);
  COLOR=vec4(ink,UV.x==0.0?(UV.y<1.5?0.8:0.9):0.0);
 }
 UV=vec2(0.0);
}
