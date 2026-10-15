shader_type canvas_item;
render_mode unshaded;
// Six fixed batches share this program. Colors/custom carry per-instance state.
uniform float sim_time = 0.0;
uniform vec2 viewport_size=vec2(1440.0,900.0);
uniform int effect_mode = 0;
uniform vec4 atlas_rect = vec4(0.0,0.0,1.0,1.0);
varying vec4 state;
varying vec4 event_data;
void vertex() {
 state=COLOR;
 event_data=INSTANCE_CUSTOM;
}
float stripe(float x,float width){return 1.0-smoothstep(width,width+0.045,abs(sin(x)));}
float gaussian(float x){return exp(-x*x);}
void fragment(){
 // Reject occluded/transparent fragments before texture fetches or trigonometry.
 vec2 screen=SCREEN_UV*viewport_size;
 bool hud=screen.x>viewport_size.x-210.0 && screen.x<viewport_size.x-30.0 && screen.y>viewport_size.y-235.0 && screen.y<viewport_size.y-85.0;
 if(hud || state.a<=0.0){discard;}
 vec2 p=UV*2.0-1.0;
 float radius_squared=dot(p,p);
 if(effect_mode==0){
  if(radius_squared>=1.0 || (state.r<=0.0 && event_data.w<=0.0)){discard;}
 }else if(effect_mode==2){
  if(radius_squared>=1.0 || state.b<=0.0){discard;}
 }
 float r=sqrt(radius_squared);
 float t=sim_time;
 vec2 flow=vec2(sin(p.y*11.0+t*1.6),cos(p.x*13.0-t*1.3))*0.005;
 vec4 art=texture(TEXTURE,atlas_rect.xy+clamp(UV+flow,vec2(.004),vec2(.996))*atlas_rect.zw);
 float luminance=dot(art.rgb,vec3(0.299,0.587,0.114));
 // Suppress the atlas paper matte; preserve its illustrated motifs.
 float ink=art.a*(1.0-smoothstep(0.82,0.99,luminance));
 vec3 tint=vec3(0.16,0.58,0.62);
 float alpha=0.0;
 if(effect_mode==0){
  float a=atan(p.y,p.x);
  tint=mix(tint,vec3(.75,.27,.44),state.b);
  float strength=state.r;
  float recharge=state.g;
  float breaking=event_data.w;
  float breath=0.94+0.012*sin(t*2.1+event_data.x*3.0);
  float edge=gaussian((r-breath)*70.0);
  float inner=gaussian((r-breath+0.028)*100.0);
  float streams=stripe(a*7.0+r*14.0-t*1.8,0.12)*stripe(r*24.0+t*0.7,0.4);
  float cell=stripe(p.x*23.0+sin(p.y*18.0+t*.55),.1)*stripe(p.y*21.0-t*.5,.16);
  float membrane=(0.018+streams*0.047+cell*0.025)*smoothstep(.98,.78,r);
  float wave=0.0;
  float local_flash=0.0;
  // Uniform within each instance: idle shields avoid contact/recharge exponentials.
  if(event_data.z>0.0){
   float hit=clamp(event_data.z/0.25,0.0,1.0);
   float distance_hit=distance(p,event_data.xy);
   float wave_distance=(distance_hit-(1.0-hit)*1.25)*22.0;
   wave=gaussian(wave_distance)*hit;
   local_flash=exp(-distance_hit*8.0)*hit;
  }
  float recharge_front=0.0;
  if(recharge>0.0){
   float front_distance=(r-(1.0-recharge)*1.1)*22.0;
   recharge_front=gaussian(front_distance)*recharge;
  }
  float break_age=1.0;
  float dissolve=1.0;
  if(breaking>0.0){
   break_age=1.0-clamp(breaking/0.7,0.0,1.0);
   float fracture=stripe(a*13.0+sin(r*33.0+t*2.0),.12);
   dissolve=step(break_age,fract(sin(floor(a*19.0)*17.3)*437.5));
   edge=gaussian((r-breath-break_age*.045)*60.0);
   membrane*=1.0-break_age;
   tint=mix(tint,vec3(.91,.65,.25),fracture*.7);
  }
  float live=max(strength>0.0 ? 0.30+0.70*strength : 0.0,breaking>0.0?1.0-break_age:0.0);
  alpha=(membrane+edge*(.28+.22*strength)+inner*.13+ink*.07+wave*.6+local_flash*.3+recharge_front*.32)*live*dissolve;
  alpha*=smoothstep(1.0,.975,r)*(1.0-recharge*.65);
  tint=mix(tint,vec3(.7,.96,1.0),clamp(wave+local_flash+recharge_front,0.0,1.0));
 }else if(effect_mode==1){
  tint=vec3(.58,.41,.16);
  tint=mix(tint,vec3(.31,.64,.69),clamp(event_data.x*.5,0.0,1.0));
  float flank=smoothstep(.34,.6,abs(p.y))*smoothstep(1.0,.75,r);
  float scan=pow(max(0.0,sin(p.x*7.0-t*2.5)),14.0);
  alpha=ink*(.22+scan*.48)+flank*scan*.16;
  tint=mix(tint,vec3(.95,.78,.36),scan);
 }else if(effect_mode==2){
  tint=vec3(.19,.65,.45);
  float rise=fract(UV.y+t*.42);
  float stitch=stripe(p.x*15.0,.16)*stripe(rise*15.0,.28);
  float ring=gaussian((r-fract(t*.6+event_data.x))*22.0);
  alpha=(ink*(.2+.3*sin(t*4.0)*sin(t*4.0))+stitch*.22+ring*.15)*smoothstep(1.0,.7,r)*state.b;
 }else if(effect_mode==3){
  tint=vec3(.85,.59,.16);
  tint=mix(tint,vec3(.42,.39,.8),event_data.x/6.0);
  float track=stripe(p.x*(14.0+event_data.x*2.0),.1)+stripe(p.y*(18.0+event_data.x),.1);
  float packet=pow(max(0.0,sin(r*20.0-t*6.0)),9.0);
  alpha=ink*(.2+packet*.5)+track*packet*.12*smoothstep(.9,.5,r);
  alpha*=.4+.6*state.b;
 }else if(effect_mode==4){
  tint=mix(vec3(.22,.65,.63),vec3(.95,.57,.18),state.b);
  float trail=stripe(p.y*17.0+sin(p.x*8.0-t*8.0)*.7,.2);
  float exhaust=smoothstep(.8,-.8,p.x)*smoothstep(.8,.1,abs(p.y));
  alpha=ink*(.16+.4*state.b)+trail*exhaust*(.09+.23*state.b);
 }else{
  float a=atan(p.y,p.x);
  tint=vec3(.44,.40,.76);
  float interference=stripe(p.y*33.0+t*3.0+sin(p.x*13.0-t)*1.8,.12);
  float veil=gaussian((r-.78-sin(a*5.0+t)*.04)*27.0);
  alpha=ink*(.12+.12*sin(t*2.0+a)*sin(t*2.0+a))+interference*.09*smoothstep(1.0,.6,r)+veil*.17;
 }
 COLOR=vec4(tint,clamp(alpha*state.a,0.0,.8));
}
