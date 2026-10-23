shader_type canvas_item;
render_mode unshaded;
// Local pigment only: source alpha, collision silhouettes and atlas margins stay exact.
// No screen reads, added glow quads or per-projectile material instances.
uniform vec4 occlusion = vec4(0.0);
uniform int material_kind = 0;
uniform float clock = 0.0;
uniform float rate = 1.0;
uniform vec4 accent : source_color = vec4(0.3,0.9,0.8,1.0);
varying vec2 ink_position;
varying vec4 egg_ring;
varying vec3 ribbon_uv;
varying float ribbon_flag;
void vertex(){
 ink_position=VERTEX;egg_ring=vec4(0.0);
 ribbon_uv=vec3(0.0);ribbon_flag=0.0;
 // UV rows 2..7 are reserved for fluid flight, beam and pressure-jet strips.
 // All illustrated
 // sprites and other primitives retain their ordinary 0..1 UV coordinates.
 if(UV.y>=2.0){
  float along=clamp(UV.x,0.0,1.0);
  float bank=fract(UV.y)*2.0-1.0;
  vec2 normal=(COLOR.rg-vec2(0.5))*(UV.y>=4.0?128.0:16.0);
  float phase=COLOR.b;
  ribbon_flag=floor(UV.y);
  bool hostile=mod(ribbon_flag,2.0)>0.5;
  bool beam=ribbon_flag>=4.0 && ribbon_flag<6.0;
  bool jet=ribbon_flag>=6.0;
  ribbon_uv=vec3(along,bank,phase);
  float profile=pow(1.0-along,0.55);
  if(beam){profile=0.65+0.35*sin(along*3.14159265);}
  if(jet){profile=0.2+0.8*pow(max(0.0,sin(along*3.14159265)),0.6);}
  float taper=profile*(0.88+0.12*sin(along*14.0-clock*21.0+phase));
  float sway=sin(along*10.0-clock*18.0+phase)*sin(along*3.14159265)*(beam?1.05:(hostile?0.95:0.65));
  VERTEX+=normal*(bank*taper+sway);
  vec3 pigment=vec3(0.725,0.804,0.282);
  if(material_kind==1){pigment=vec3(0.929,0.722,0.231);}
  else if(material_kind==2){pigment=vec3(0.898,0.749,0.506);}
  else if(material_kind==3 || material_kind==4 || material_kind==6){pigment=vec3(0.925,0.682,0.596);}
  else if(material_kind==5){pigment=vec3(0.275,0.871,0.835);}
  else if(material_kind==7){pigment=vec3(0.675,0.506,0.961);}
  else if(material_kind==11){pigment=vec3(0.322,0.875,0.690);}
  else if(material_kind==12){pigment=vec3(0.969,0.773,0.420);}
  if(beam && material_kind==3){pigment=vec3(0.329,0.839,0.914);}
  if(beam && material_kind==4){pigment=vec3(0.318,0.843,1.0);}
  if(beam && material_kind==6){pigment=vec3(0.588,0.627,1.0);}
  if(hostile){pigment=vec3(0.847,0.153,0.275);}
  vec3 lip=mix(pigment,vec3(1.0,0.957,0.812),0.64);
  COLOR.rgb=bank< -0.22?mix(pigment*0.47,lip,(bank+1.0)/0.78):mix(lip,pigment,(bank+0.22)/1.22);
  COLOR.a*=0.94*((beam || jet)?1.0:1.0-along);
  ink_position=VERTEX;
 }
 // Instanced egg markers retain the same pigment in screen coordinates.
 // All ordinary drawing and the egg sprites/halos have custom alpha zero.
 if(INSTANCE_CUSTOM.a>1.0001){
  float radius=INSTANCE_CUSTOM.r;
  float half_width=INSTANCE_CUSTOM.a-1.0;
  VERTEX*=radius+half_width+1.0;
  egg_ring=vec4(VERTEX,radius,half_width);
  ink_position=VERTEX+INSTANCE_CUSTOM.gb;
 }
}
float hash21(vec2 p){vec3 q=fract(vec3(p.xyx)*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
// Broad dark crease with a narrow moist lip. Never blooms outside the source art.
vec2 fold(float phase){
 float wave=sin(phase);
 return vec2(1.0-smoothstep(0.10,0.42,abs(wave)),1.0-smoothstep(0.06,0.24,abs(wave-0.48)));
}
// Soft internal egg sacs with off-centre nuclei, without hard cellular grid edges.
vec3 sacs(vec2 q,float time){
 float seed=hash21(floor(q));
 vec2 cell=fract(q)-0.5;
 cell-=vec2(sin(seed*19.0),cos(seed*13.0))*0.08;
 cell*=vec2(1.0+0.12*sin(time*2.2+seed*6.0),1.2);
 float radius=length(cell);
 float shell=1.0-smoothstep(0.025,0.095,abs(radius-(0.29+seed*0.06)));
 float nucleus=1.0-smoothstep(0.065,0.19,length(cell+vec2(0.07,-0.04)));
 float wet=1.0-smoothstep(0.025,0.10,length(cell-vec2(-0.12,-0.19)));
 return vec3(shell,nucleus,wet);
}
void fragment(){
 vec4 base=COLOR;
 if(egg_ring.z>0.0){
  float radial=length(egg_ring.xy);
  float distance_to_ring=abs(radial-egg_ring.z)-egg_ring.w;
  base.a*=clamp(0.5-distance_to_ring/max(fwidth(radial),0.001),0.0,1.0);
 }
 if(occlusion.z>0.0 && SCREEN_UV.x>=occlusion.x && SCREEN_UV.y>=occlusion.y && SCREEN_UV.x<=occlusion.x+occlusion.z && SCREEN_UV.y<=occlusion.y+occlusion.w){discard;}
 if(base.a<=0.001){discard;}
 if(ribbon_flag>0.0){
  float pressure=0.5+0.5*sin(ribbon_uv.x*27.0-clock*17.0+ribbon_uv.z);
  float lip=pow(pressure,5.0)*(1.0-smoothstep(0.05,0.82,abs(ribbon_uv.y+0.22)));
  vec3 fluid=base.rgb*(0.82+0.18*pressure);
  fluid=mix(fluid,vec3(1.0,0.94,0.81),lip*0.26);
  if(mod(ribbon_flag,2.0)>0.5){fluid=mix(base.rgb,fluid,0.45);}
  float edge=1.0-smoothstep(0.65,1.0,abs(ribbon_uv.y));
  float ends=1.0;
  if(ribbon_flag>=4.0){ends=smoothstep(0.0,0.035,ribbon_uv.x)*(1.0-smoothstep(0.97,1.0,ribbon_uv.x));}
  COLOR=vec4(fluid,base.a*edge*ends);
 }else{
 vec2 p=ink_position;
 float t=clock*rate;
 float coarse=noise(p*0.075+vec2(-t*0.38,t*0.17));
 float tissue=0.0;float crease=0.0;float wet=0.0;
 vec3 fluid=mix(accent.rgb,vec3(0.63,0.76,0.31),0.24);
 if(material_kind==0){ // Viscous mucus: ropes of sap and trapped-fluid pockets.
  vec2 channel=fold(p.x*0.32+sin(p.y*0.24+t*0.9)*2.3-t*3.4+coarse*2.1);
  vec2 stringy=fold(p.y*0.75+sin(p.x*0.15-t*1.8)*1.6);
  crease=channel.x*0.78+stringy.x*0.25;
  wet=channel.y*0.75+smoothstep(0.67,0.90,coarse)*0.30;
  tissue=coarse*0.22;
 }else if(material_kind==1){ // Egg shell: sacs flex around opaque curled embryos.
  vec3 egg=sacs(p*0.095+vec2(coarse*0.22,t*0.065),t);
  crease=egg.x*0.72+egg.y*0.45;
  wet=egg.z*0.95+egg.x*(0.18+0.08*sin(t*2.3+p.x*0.15));
  tissue=egg.y*0.36+coarse*0.16;
  fluid=mix(accent.rgb,vec3(0.68,0.82,0.37),0.38);
 }else if(material_kind==2){ // Larvae: travelling gut contractions and paired ribs.
  vec2 segment=fold(p.x*0.60-t*3.7+sin(p.y*0.16)*0.8);
  float gut=1.0-smoothstep(0.14,0.55,abs(sin(p.y*0.19+coarse*1.5)));
  crease=segment.x*0.72+gut*0.30;
  wet=segment.y*0.70+gut*segment.y*0.25;tissue=coarse*0.22;
  fluid=mix(accent.rgb,vec3(0.72,0.80,0.38),0.38);
 }else if(material_kind==3){ // Tongue: muscular rings squeeze sap down a wet throat.
  vec2 muscle=fold(p.x*0.23-t*5.1+sin(p.y*0.28+t)*0.8);
  vec2 artery=fold(p.y*0.44+coarse*2.6-t*0.8);
  crease=muscle.x*0.75+artery.x*0.28;wet=muscle.y*0.72+artery.y*0.22;tissue=coarse*0.24;
  fluid=mix(accent.rgb,vec3(0.64,0.35,0.51),0.25);
 }else if(material_kind==4){ // Electric cilia: fluid nerve tubes carry smooth impulses.
  vec2 nerve=fold(p.x*0.23+sin(p.y*0.22+coarse*2.0)*2.3-t*4.4);
  float impulse=0.45+0.55*smoothstep(-0.3,0.9,sin(p.x*0.08-t*4.2));
  crease=nerve.x*0.82;wet=nerve.y*impulse;tissue=coarse*0.22;
  fluid=mix(accent.rgb,vec3(0.56,0.81,0.67),0.30);
 }else if(material_kind==5){ // EMP: swollen ganglia joined by contracting membranes.
  vec3 nodes=sacs(p*0.085+vec2(coarse*0.30,t*0.06),t*0.8);
  vec2 nerve=fold(length(p)*0.30-t*3.0+coarse*2.5);
  crease=nodes.x*0.46+nerve.x*0.52;wet=nodes.z*0.90+nerve.y*0.55;tissue=nodes.y*0.34;
 }else if(material_kind==6){ // Wing resonance: vascular membranes ripple in waves.
  vec2 vein=fold(p.y*0.37+sin(p.x*0.19-t*2.0)*1.7+coarse*1.5);
  float pressure=0.5+0.5*sin(p.x*0.15-t*4.8);
  crease=vein.x*(0.58+pressure*0.32);wet=vein.y*0.70;tissue=coarse*0.25;
  fluid=mix(accent.rgb,vec3(0.77,0.47,0.61),0.27);
 }else if(material_kind==7){ // Vortex: concentric swallowing folds, a living maw.
  float radius=length(p);float angle=atan(p.y,p.x);
  vec2 throat=fold(radius*0.20+sin(angle*5.0+t*0.7)*1.3-t*2.7);
  crease=throat.x*0.90+smoothstep(0.65,0.9,coarse)*0.20;wet=throat.y*0.78;tissue=0.22+coarse*0.14;
  fluid=mix(accent.rgb,vec3(0.56,0.27,0.45),0.35);
 }else if(material_kind==8){ // Impact slime: ragged clots retain crawling fluid channels.
  vec2 clot=fold(p.x*0.30+p.y*0.18+coarse*4.4-t*1.8);
  crease=clot.x*0.65+smoothstep(0.65,0.89,coarse)*0.28;wet=clot.y*0.66;tissue=coarse*0.30;
 }else if(material_kind==9){ // Silk: sticky strands collect moving saliva beads.
  vec2 strands=fold(p.y*0.55+sin(p.x*0.10-t*1.4)+coarse);
  float bead=1.0-smoothstep(0.20,0.58,abs(sin(p.x*0.22-t*3.1)));
  crease=strands.x*0.62+bead*0.17;wet=strands.y*bead*0.90+bead*0.18;tissue=coarse*0.18;
  fluid=vec3(0.65,0.82,0.53);
 }else if(material_kind==11){ // Repair insects: cloudy lymph and circulating cells.
  vec3 lymph=sacs(p*0.11+vec2(t*0.10,coarse*0.3),t);
  crease=lymph.x*0.70+lymph.y*0.25;wet=lymph.z*0.90;tissue=coarse*0.24;
 }else if(material_kind==12){ // Scavengers: chitin sutures and a segmented gut.
  vec2 gut=fold(p.x*0.41-t*2.5+sin(p.y*0.23)*1.4);
  crease=gut.x*0.86;wet=gut.y*0.66;tissue=coarse*0.30;
  fluid=mix(accent.rgb,vec3(0.67,0.58,0.26),0.30);
 }else{ // Tendril: longitudinal veins cross travelling muscular constrictions.
  vec2 muscle=fold(p.x*0.32+p.y*0.18-t*3.6+coarse*1.6);
  vec2 vessel=fold(p.y*0.48+sin(p.x*0.12-t)*1.2);
  crease=muscle.x*0.65+vessel.x*0.32;wet=muscle.y*0.60+vessel.y*0.24;tissue=coarse*0.25;
  fluid=vec3(0.55,0.78,0.39);
 }
 float bright=max(base.r,max(base.g,base.b));float dim=min(base.r,min(base.g,base.b));
 // Navy/purple ink survives every family. Ivory hazard separation remains clean.
 float pigment=smoothstep(0.25,0.64,bright);
 float ivory=step(0.90,dim)*(1.0-smoothstep(0.08,0.14,bright-dim));
 float red=smoothstep(0.16,0.38,base.r-max(base.g,base.b));
 float surface=pigment*(1.0-ivory);
 vec3 soaked=mix(base.rgb,base.rgb*0.70+fluid*0.15,tissue);
 soaked*=1.0-clamp(crease,0.0,1.0)*0.44;
 vec3 moist=mix(base.rgb,vec3(0.96,0.94,0.76),0.62);
 vec3 living=mix(soaked,moist,clamp(wet,0.0,1.0)*0.52);
 // Shared by both teams: hostile crimson keeps its hue, with only slight value changes.
 vec3 crimson=base.rgb*(1.0-clamp(crease,0.0,1.0)*0.12)+base.rgb*wet*0.05;
 living=mix(living,crimson,red);
 COLOR=vec4(mix(base.rgb,living,surface),base.a);
 }
}
