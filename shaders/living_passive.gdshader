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
// Staggered, irregular vesicles; their rims read as fluid pockets, not a square grid.
vec3 vesicle(vec2 p,float density,float t){
 vec2 q=p*density;
 q.x+=mod(floor(q.y),2.0)*.5;
 vec2 cell=floor(q);
 float seed=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
 vec2 centre=vec2(.5)+vec2(sin(seed*31.0),cos(seed*43.0))*.12;
 vec2 local=fract(q)-centre;
 float size=.22+.07*sin(t*1.7+seed*13.0);
 float d=length(local);
 float rim=gaussian((d-size)*37.0);
 float wet=gaussian(length(local-vec2(-.075,-.075))*22.0);
 float body=1.0-smoothstep(size*.55,size,d);
 return vec3(rim,wet,body);
}
float veins(vec2 p,float t){
 vec2 q=p+vec2(sin(p.y*4.3+t*.6),sin(p.x*5.7-t*.5))*.075;
 float trunk=stripe(q.x*13.0+sin(q.y*7.0-t*.8)*1.4,.07);
 float branch=stripe(q.y*18.0+sin(q.x*8.0+t*.45)*1.7,.05);
 return max(trunk*.8,branch*.55);
}
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
 // Only the local membrane/art moves. The background and combat positions stay fixed.
 vec2 flow=vec2(sin(p.y*11.0+t*1.6),cos(p.x*13.0-t*1.3))*0.009;
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
  float breath=0.93+0.012*sin(t*2.1)+.008*sin(a*7.0-t*1.3);
  float edge=gaussian((r-breath)*70.0);
  float inner=gaussian((r-breath+0.028)*100.0);
  float vessel=veins(p,t);
  vec3 cells=vesicle(p+flow*3.0,8.0,t);
  float periphery=smoothstep(.56,.87,r);
  float edge_sacs=gaussian((r-breath+.055)*37.0)*pow(.5+.5*sin(a*23.0+sin(a*9.0+t*.9)),5.0);
  float feeding=.5+.5*sin(r*17.0-t*2.1+a*2.0);
  float membrane=(.014+vessel*(.045+.11*periphery)*feeding+cells.x*(.02+.035*periphery)+cells.z*.012)*smoothstep(.98,.78,r);
  tint=mix(tint,mix(vec3(.08,.28,.28),vec3(.36,.08,.20),state.b),vessel*.58);
  tint=mix(tint,vec3(.83,.95,.79),clamp(cells.y*.28+edge_sacs*.7+inner*.35,0.0,.65));
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
  alpha=(membrane+edge*(.32+.22*strength)+inner*.19+edge_sacs*.40+ink*.07+wave*.6+local_flash*.3+recharge_front*.32)*live*dissolve;
  alpha*=smoothstep(1.0,.975,r)*(1.0-recharge*.65);
  tint=mix(tint,vec3(.7,.96,1.0),clamp(wave+local_flash+recharge_front,0.0,1.0));
 }else if(effect_mode==1){
  tint=vec3(.53,.37,.16);
  tint=mix(tint,vec3(.31,.64,.69),clamp(event_data.x*.5,0.0,1.0));
  float flank=smoothstep(.28,.57,abs(p.y))*smoothstep(1.0,.79,r);
  float squeeze=sin(p.x*8.0-t*2.2)*.035;
  float plates=stripe((abs(p.y)+squeeze)*29.0+sin(p.x*6.0)*2.0,.17);
  float vessel=veins(p,t);
  vec3 sacs=vesicle(p+flow*2.0,4.5,t);
  float pulse=.5+.5*sin(p.x*9.0-t*3.0);
  alpha=ink*(.22+pulse*.18)+flank*(.09+plates*.24+vessel*.15+sacs.x*.18);
  tint=mix(tint,vec3(.34,.15,.17),vessel*.55);
  tint=mix(tint,vec3(.91,.84,.55),clamp(sacs.y*.8+plates*pulse*.55,0.0,.8));
 }else if(effect_mode==2){
  tint=vec3(.21,.56,.36);
  vec2 crawl=p+vec2(sin(p.y*8.0-t*2.8),cos(p.x*6.0+t*2.2))*.055;
  float tendons=stripe(crawl.x*17.0+sin(crawl.y*9.0-t*3.0)*2.0,.14);
  float feeding=pow(.5+.5*sin(crawl.y*12.0+t*4.0+event_data.x*6.0),3.0);
  float sutures=stripe(crawl.y*20.0+sin(crawl.x*10.0+t),.1)*tendons;
  vec3 cells=vesicle(crawl,4.8,t+event_data.x);
  float edge=gaussian((r-.73-sin(atan(p.y,p.x)*8.0+t)*.035)*29.0);
  alpha=(ink*.28+tendons*(.12+.24*feeding)+sutures*.18+cells.x*.12+edge*.14)*smoothstep(1.0,.65,r)*state.b;
  tint=mix(tint,vec3(.46,.23,.30),sutures*.6);
  tint=mix(tint,vec3(.84,.95,.62),clamp(tendons*feeding*.65+cells.y*.7,0.0,.8));
 }else if(effect_mode==3){
  tint=vec3(.71,.48,.17);
  tint=mix(tint,vec3(.42,.39,.8),event_data.x/6.0);
  vec2 neural=p+vec2(sin(p.y*6.0+t),cos(p.x*8.0-t*.7))*.09;
  float nerve=veins(neural,t*.7);
  float packet=pow(.5+.5*sin(r*19.0-t*4.5+sin(p.x*5.0)),7.0);
  vec3 nodes=vesicle(neural,3.5,t*.8);
  alpha=ink*(.22+packet*.32)+(nerve*(.14+packet*.28)+nodes.x*.12+nodes.y*packet*.2)*smoothstep(.97,.55,r);
  alpha*=.4+.6*state.b;
  tint=mix(tint,vec3(.37,.15,.24),nerve*.35);
  tint=mix(tint,vec3(.98,.85,.63),clamp(packet*nerve+nodes.y*.6,0.0,.8));
 }else if(effect_mode==4){
  tint=mix(vec3(.28,.56,.43),vec3(.75,.52,.17),state.b);
  float trail=stripe(p.y*20.0+sin(p.x*7.0-t*5.0)*1.1+sin(p.x*14.0-t*7.0)*.3,.22);
  float exhaust=(1.0-smoothstep(-.8,.8,p.x))*smoothstep(.8,.1,abs(p.y));
  vec3 droplets=vesicle(vec2(p.x+t*.6,p.y)*vec2(.7,1.5),4.5,t);
  float pump=.65+.35*sin(p.x*11.0-t*5.0);
  alpha=ink*(.2+.3*state.b)+exhaust*(trail*(.15+.22*state.b)*pump+droplets.x*.12);
  tint=mix(tint,vec3(.93,.91,.64),trail*pump*.55+droplets.y*.3);
 }else{
  float a=atan(p.y,p.x);
  tint=vec3(.43,.35,.63);
  float folds=stripe(p.y*23.0+t*1.3+sin(p.x*9.0-t*.8)*2.4,.18);
  float veil=gaussian((r-.78-sin(a*5.0+t)*.035-sin(a*11.0-t*.8)*.018)*30.0);
  float vessel=veins(p+flow*4.0,t*.6);
  vec3 cells=vesicle(p+flow*2.0,6.0,t*.6);
  alpha=ink*(.13+.1*sin(t*1.4+a)*sin(t*1.4+a))+(folds*.12+vessel*.06+cells.x*.045)*smoothstep(1.0,.65,r)+veil*.26;
  tint=mix(tint,vec3(.19,.27,.34),vessel*.6);
  tint=mix(tint,vec3(.76,.85,.86),clamp(veil*.5+folds*cells.y,0.0,.7));
 }
 COLOR=vec4(tint,clamp(alpha*state.a,0.0,.8));
}
