from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import math, numpy as np
R=Path(__file__).resolve().parents[1]/'assets/textures'; R.mkdir(parents=True,exist_ok=True)
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
MONO='/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
def font(n,mono=False):return ImageFont.truetype(MONO if mono else FONT,n)
def center(d,xy,text,size=22,fill='#ded9c6',mono=False):d.text(xy,text,font=font(size,mono),fill=fill,anchor='mm')
im=Image.new('RGB',(1536,640),'#151b1e');d=ImageDraw.Draw(im)
d.rounded_rectangle((8,8,1528,632),28,fill='#111619',outline='#72756c',width=3)
def dial(cx,cy,r,maxval,step,caption,needle):
 d.ellipse((cx-r-12,cy-r-12,cx+r+12,cy+r+12),fill='#333b3d',outline='#8c9185',width=3)
 d.ellipse((cx-r,cy-r,cx+r,cy+r),fill='#111719',outline='#444b4a',width=3)
 for v in range(0,maxval+1,step//2):
  a=math.radians(135+270*v/maxval); major=v%step==0
  rr=r-17;ri=rr-(24 if major else 12)
  p=(cx+math.cos(a)*rr,cy+math.sin(a)*rr,cx+math.cos(a)*ri,cy+math.sin(a)*ri)
  d.line(p,fill='#e9e0c9',width=5 if major else 3)
  if major:center(d,(cx+math.cos(a)*(r-64),cy+math.sin(a)*(r-64)),str(v),27)
 center(d,(cx,cy+r*.36),caption,24)
 a=math.radians(135+270*needle/maxval)
 d.line((cx-math.cos(a)*25,cy-math.sin(a)*25,cx+math.cos(a)*(r-60),cy+math.sin(a)*(r-60)),fill='#dc7453',width=7)
 d.ellipse((cx-17,cy-17,cx+17,cy+17),fill='#b4b09c',outline='#282e2d',width=5)
dial(380,312,244,180,20,'km/h',0)
dial(938,312,244,70,10,'x100 r/min',9)
d.rounded_rectangle((279,427,481,474),4,fill='#090d0e',outline='#60685d',width=2)
center(d,(380,451),'0 8 5 0 1 2',21,mono=True)
for idx,(label,pct) in enumerate([('FUEL',.62),('TEMP',.4)]):
 x=1320;y=185+idx*228
 center(d,(x,y-66),label,23)
 d.arc((x-96,y-65,x+96,y+65),190,350,fill='#cbd2bb',width=5)
 for t in [0,.25,.5,.75,1]:
  a=math.radians(190+160*t);d.line((x+math.cos(a)*94,y+math.sin(a)*64,x+math.cos(a)*78,y+math.sin(a)*50),fill='#d6dbc4',width=4)
 a=math.radians(190+160*pct);d.line((x,y+12,x+math.cos(a)*76,y+math.sin(a)*49),fill='#e58460',width=5)
 d.ellipse((x-8,y+4,x+8,y+20),fill='#b5bdaa')
for x,t,c in [(80,'OIL','#c96645'),(140,'BAT','#c96645'),(1210,'N','#6d9c83')]:
 d.rounded_rectangle((x-24,555,x+24,590),5,fill=c);center(d,(x,572),t,17,fill='#181e1e')
im.save(R/'analogue_cluster.png')
im=Image.new('RGB',(1024,384),'#171e21');d=ImageDraw.Draw(im)
d.rounded_rectangle((7,7,1017,377),18,outline='#70776b',width=4)
center(d,(512,45),'FM / AM     STEREO',27)
d.rounded_rectangle((195,84,825,166),6,fill='#313e32',outline='#77836a',width=2)
center(d,(510,125),'88  92  96  100  104  108',28,fill='#c4cf9b',mono=True)
d.line((573,89,573,160),fill='#d69062',width=4)
d.rounded_rectangle((205,205,818,253),5,fill='#070c0d',outline='#6b716b',width=3)
center(d,(510,286),'AUTO REVERSE  ·  CASSETTE',20)
for i in range(6):
 x=250+i*105;d.rounded_rectangle((x-37,313,x+37,355),6,fill='#313b3c',outline='#747d72',width=2);center(d,(x,334),str(i+1),20)
im.save(R/'period_radio.png')
im=Image.new('RGB',(1024,300),'#192124');d=ImageDraw.Draw(im)
for row,label in enumerate(['AIR','FAN','HEAT']):
 y=56+row*89;center(d,(85,y),label,26)
 d.line((185,y,925,y),fill='#8b9685',width=4)
 for x in range(200,926,90):d.line((x,y-9,x,y+9),fill='#849080',width=3)
 if row==2:
  d.line((185,y,535,y),fill='#83a8b0',width=6);d.line((535,y,925,y),fill='#bc785c',width=6)
center(d,(530,22),'VENTILATION',20)
im.save(R/'climate_panel.png')
n=512;y,x=np.mgrid[:n,:n];warp=((x//3+y//5)%2)*5+np.sin(x*.48)*3+np.cos(y*.4)*3
base=np.stack([49+warp,65+warp,67+warp],axis=-1).clip(0,255).astype('uint8')
Image.fromarray(base).save(R/'cloth_weave.png')
rough=np.clip(206+warp*1.4,0,255).astype('uint8');Image.fromarray(rough).save(R/'cloth_roughness.png')
grain=(np.sin(x*1.739+y*7.13)*np.sin(x*5.933-y*3.457))*4
Image.fromarray(np.clip(128+grain,0,255).astype('uint8')).save(R/'plastic_grain.png')
print('Generated six deterministic detail textures',R)
