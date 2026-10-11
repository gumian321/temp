from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
D=Path(__file__).resolve().parent/'assets'
D.mkdir(parents=True,exist_ok=True)
font='/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
reg='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
# Composed, legible signage on a warm enamel field
im=Image.new('RGB',(2048,400),(235,228,202));d=ImageDraw.Draw(im)
d.rounded_rectangle((15,15,2033,385),radius=22,outline=(157,171,148),width=4)
# driving-school roundel
cx,cy,r=197,200,115
d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=(40,89,83))
d.ellipse((cx-81,cy-81,cx+81,cy+81),outline=(240,229,191),width=15)
d.ellipse((cx-22,cy-22,cx+22,cy+22),fill=(240,229,191))
for ax,ay,bx,by in [(cx-81,cy-22,cx-20,cy),(cx+20,cy,cx+81,cy-22),(cx,cy+20,cx,cy+81)]:d.line((ax,ay,bx,by),fill=(240,229,191),width=15)
f=ImageFont.truetype(font,225)
for idx,char in enumerate('胡闹驾校'): d.text((455+idx*355,5),char,font=f,fill=(35,81,73),stroke_width=0)
f=ImageFont.truetype(reg,35)
text='H U N A O   D R I V I N G   S C H O O L'
d.text((574,301),text,font=f,fill=(82,106,87))
im.save(D/'school-sign.png')
# Small traffic practice plaque
im=Image.new('RGB',(512,640),(227,219,186));d=ImageDraw.Draw(im)
d.rounded_rectangle((15,15,497,625),20,outline=(72,111,99),width=6)
d.text((54,49),'训练区域',font=ImageFont.truetype(font,94),fill=(42,88,78))
d.line((54,193,458,193),fill=(144,159,119),width=3)
d.ellipse((144,225,368,449),fill=(211,103,60));d.ellipse((165,246,347,428),fill=(241,232,201))
d.text((192,261),'5',font=ImageFont.truetype(font,115),fill=(51,89,80))
d.text((63,491),'慢行 · 礼让',font=ImageFont.truetype(font,67),fill=(53,99,85))
d.text((95,579),'PRACTICE COURT',font=ImageFont.truetype(reg,28),fill=(76,115,94))
im.save(D/'practice-sign.png')
# Road stencil actual Chinese, transparent
im=Image.new('RGBA',(1024,240),(0,0,0,0));d=ImageDraw.Draw(im)
d.text((40,-3),'起 步 区',font=ImageFont.truetype(font,204),fill=(228,217,177,245))
im.save(D/'road-stencil.png')
