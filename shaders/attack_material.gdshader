shader_type canvas_item;
render_mode unshaded;
// Source alpha and pigment silhouettes are preserved. Spatial frequencies are in
// local drawing pixels, so an atlas region never bleeds into a neighbouring cell.
uniform vec4 occlusion = vec4(0.0);
uniform int material_kind = 0;
uniform float clock = 0.0;
uniform float rate = 1.0;
uniform vec4 accent : source_color = vec4(0.3,0.9,0.8,1.0);
varying vec2 ink_position;
void vertex(){ ink_position=VERTEX; }
// Arithmetic hash avoids four transcendental calls per filtered noise sample.
float hash21(vec2 p){vec3 q=fract(vec3(p.xyx)*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}

// Integer highlight powers use bounded multiplication chains (all inputs >= 0).
float power3(float x){float x2=x*x;return x*x2;}
float power4(float x){float x2=x*x;float x4=x2*x2;return x4;}
float power7(float x){float x2=x*x;float x4=x2*x2;return x*x2*x4;}
float power8(float x){float x2=x*x;float x4=x2*x2;float x8=x4*x4;return x8;}
float power9(float x){float x2=x*x;float x4=x2*x2;float x8=x4*x4;return x*x8;}
float power10(float x){float x2=x*x;float x4=x2*x2;float x8=x4*x4;return x2*x8;}
float power12(float x){float x2=x*x;float x4=x2*x2;float x8=x4*x4;return x4*x8;}
float power14(float x){float x2=x*x;float x4=x2*x2;float x8=x4*x4;return x2*x4*x8;}
float power18(float x){float x2=x*x;float x4=x2*x2;float x8=x4*x4;float x16=x8*x8;return x2*x16;}
float power22(float x){float x2=x*x;float x4=x2*x2;float x8=x4*x4;float x16=x8*x8;return x2*x4*x16;}
void fragment(){
 vec4 base=COLOR;
 vec2 screen_pixel=SCREEN_UV;
 if(occlusion.z>0.0 && screen_pixel.x>=occlusion.x && screen_pixel.y>=occlusion.y && screen_pixel.x<=occlusion.x+occlusion.z && screen_pixel.y<=occlusion.y+occlusion.w){discard;}
 // Transparent generated-art margins contribute nothing; skip material work.
 if(base.a<=0.001){discard;}
 vec2 p=ink_position;
 float t=clock*rate;
 float grain=0.0;
 if(material_kind<=3 || material_kind==5 || material_kind==8){
  grain=noise(p*0.17+vec2(-t*1.7,t*0.6));
 }
 float detail=0.0;
 vec3 tint=accent.rgb;
 if(material_kind==0){ // Advecting viscous surface, small wet caustics.
  float flow=sin(p.x*0.28-t*6.0+sin(p.y*0.45+t)*1.8);
  float film=power12(max(0.0,flow));
  detail=film*0.43+smoothstep(0.77,0.96,grain)*0.35;
  tint=mix(tint,vec3(1.0,0.97,0.75),0.72);
 }else if(material_kind==1){ // Eggs: pulsing shell seams and internal cells.
  vec2 cell=p*0.24+vec2(sin(t)*0.2,t*0.16);
  float vein=power9(1.0-abs(sin(cell.x+sin(cell.y*1.7))));
  detail=vein*(0.18+0.17*sin(t*4.0+p.x*0.12))+grain*0.12;
  tint=mix(tint,vec3(1.0,0.86,0.61),0.4);
 }else if(material_kind==2){ // Larvae: peristaltic segment ripples.
  float segment=power7(max(0.0,sin(p.x*0.7-t*8.0+sin(p.y*0.17))));
  detail=segment*0.35+power4(grain)*0.15;
  tint=mix(tint,vec3(0.9,1.0,0.72),0.45);
 }else if(material_kind==3){ // Piercing tongue: fast axial pressure packets.
  detail=power14(max(0.0,sin(p.x*0.20-t*18.0)))*0.5+grain*0.09;
 }else if(material_kind==4){ // Electric cilia: irregular branching discharge.
  float branch=sin(p.x*0.35+t*12.0+noise(p*0.08+floor(t*18.0))*7.0);
  detail=power18(max(0.0,branch))*0.7;
  tint=mix(tint,vec3(0.88,0.96,1.0),0.65);
 }else if(material_kind==5){ // EMP: interference cells / broken bands.
  float band=sin(length(p)*0.42-t*9.0)*sin(p.x*0.23+p.y*0.19+t*4.0);
  detail=smoothstep(0.55,0.95,band)*0.55+grain*0.1;
 }else if(material_kind==6){ // Sonic: travelling phase interference.
  float wave=sin(p.x*0.38-t*11.0)+sin(p.y*0.25+t*5.0);
  detail=smoothstep(0.8,1.9,wave)*0.55;
  tint=mix(tint,vec3(0.97,0.75,1.0),0.4);
 }else if(material_kind==7){ // Vortex: curved accretion streaks, not a flat glow.
  float radius=length(p);float angle=atan(p.y,p.x);
  detail=power9(max(0.0,sin(angle*5.0+radius*0.14-t*7.0)))*0.55;
 }else if(material_kind==8){ // Contact: fragment cooling / moving fracture grain.
  detail=power3(grain)*(0.32+0.12*sin(t*19.0+p.x*0.4));
 }else if(material_kind==9){ // Silk: fine moving pearl glints along fibres.
  detail=power22(max(0.0,sin((p.x+p.y)*0.33-t*8.0)))*0.64;
  tint=vec3(0.85,0.97,1.0);
 }else if(material_kind==11){ // Repair drones: slow circulating renewal cells.
  detail=power10(max(0.0,sin(length(p)*0.48-t*4.5)))*0.48;
 }else if(material_kind==12){ // Scavengers: moving mineral / segmented scanning facets.
  detail=smoothstep(0.70,0.98,noise(floor(p*0.32)+vec2(t*1.8,0.0)))*0.50;
 }else{ // Tendril: alternating sap channels and muscular constriction.
  detail=power8(max(0.0,sin(p.x*0.31+p.y*0.21-t*6.0)))*0.43;
  tint=vec3(0.55,1.0,0.79);
 }
 // Keep dark illustrated outlines dark and enemy red recognition intact.
 float pigment=smoothstep(0.19,0.62,max(base.r,max(base.g,base.b)));
 vec3 highlight=mix(base.rgb,tint,0.35);
 // Moving material channels affect translucency as well as pigment. Incoming
 // lifetime alpha remains authoritative, so impact/retraction fades still work.
 float membrane=1.0;
 if(material_kind==0)membrane=0.86+0.14*smoothstep(0.1,0.8,grain);
 if(material_kind==4)membrane=0.72+min(0.28,detail);
 if(material_kind==5 || material_kind==6)membrane=0.82+min(0.18,detail);
 if(material_kind==9 || material_kind==10)membrane=0.85+min(0.15,detail);
 // Dark outline continuity is kept even where the inner membrane thins.
 membrane=mix(1.0,membrane,pigment);
 COLOR=vec4(base.rgb*(1.0-detail*0.14)+highlight*detail*pigment,base.a*membrane);
}
