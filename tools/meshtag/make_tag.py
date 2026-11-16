import json, hashlib, base64, os, qrcode
from PIL import Image, ImageDraw, ImageFont, ImageFilter, PngImagePlugin
import numpy as np, nacl.signing, random
W,H=1800,900
GOLD=(232,190,92); GOLD2=(255,224,140); TURQ=(38,222,205); CREAM=(243,238,226); GREY=(150,156,160)
PB='/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf'; PM='/usr/share/fonts/truetype/google-fonts/Poppins-Medium.ttf'
IM='/usr/share/fonts/opentype/inter/Inter-Medium.otf'; IS='/usr/share/fonts/opentype/inter/Inter-SemiBold.otf'
F=lambda p,s: ImageFont.truetype(p,s)
# --- the receipt (SAMPLE, demo key) ---
receipt={"v":1,"kind":"game.run","tag":"MT-SAMPLE-0001","game":"Mesh City: Proof Run",
 "lane":"human","result":{"time_ms":161370,"orbs":42,"orbs_total":42},
 "build":"sha256:"+hashlib.sha256(b"mesh-city-build-demo").hexdigest(),
 "inputs":"sha256:"+hashlib.sha256(b"demo-input-log").hexdigest(),"seed":20261114,
 "replay":"match","issued_at":"2026-11-14T21:00:00Z","issuer":"runtime.meshtool.ai","sample":True}
sk=nacl.signing.SigningKey(hashlib.sha256(b"MESHTAG-DEMO-KEY-NOT-REAL").digest())
body=json.dumps(receipt,sort_keys=True,separators=(',',':')).encode()
sig=sk.sign(body).signature; pk=sk.verify_key.encode()
tagdoc={"receipt":receipt,"alg":"ed25519","sig":base64.b64encode(sig).decode(),"pub":base64.b64encode(pk).decode(),
 "cid":"sha256:"+hashlib.sha256(body).hexdigest()}
fp=hashlib.sha256(pk).hexdigest()
# --- art ---
y,x=np.mgrid[0:H,0:W]
bg=np.zeros((H,W,3)); bg[:]=(8,9,11)
def glow(cx,cy,r,c,s):
    bg[:]+= np.exp(-((x-cx)**2+(y-cy)**2)/(r*r))[...,None]*np.array(c)*s
glow(380,450,420,GOLD,0.10); glow(900,300,600,TURQ,0.035)
img=Image.fromarray(np.clip(bg,0,255).astype('uint8')); d=ImageDraw.Draw(img)
random.seed(5)
for _ in range(700):
    px,py=random.random()*W,random.random()*H; c=random.choice([GOLD,TURQ]); a=random.uniform(.1,.45); r=random.choice([1,1.5,2])
    d.ellipse([px-r,py-r,px+r,py+r],fill=tuple(int(v*a) for v in c))
# gold foil frame
def foil(box,width):
    for i in range(width):
        t=i/width; c=tuple(int(GOLD[k]*(1-t)+GOLD2[k]*t) if i%3 else int(GOLD[k]*0.8) for k in range(3))
        d.rounded_rectangle([box[0]+i,box[1]+i,box[2]-i,box[3]-i],radius=40-i if 40-i>4 else 4,outline=c)
foil([20,20,W-20,H-20],10)
d.rounded_rectangle([44,44,W-44,H-44],radius=28,outline=(120,96,44),width=2)
# stub perforation
sx=1330
for py in range(70,H-60,22): d.ellipse([sx-4,py-4,sx+4,py+4],fill=(70,58,30))
# orb emblem
A=Image.open('os.path.join(os.path.dirname(__file__),'..','..','brand','avatar.png')').resize((300,300),Image.LANCZOS)
m=Image.new('L',A.size,0); ImageDraw.Draw(m).ellipse([22,22,278,278],fill=255); m=m.filter(ImageFilter.GaussianBlur(10))
img.paste(A,(95,95),m); d=ImageDraw.Draw(img)
# title
d.text((430,95),"MESH",font=F(PB,118),fill=CREAM); w=d.textlength("MESH ",font=F(PB,118))
d.text((430+w,95),"TAG",font=F(PB,118),fill=GOLD)
d.text((436,235),"Every run, proven.",font=F(PB,44),fill=TURQ)
# fields
fields=[("GAME","Mesh City: Proof Run"),("LANE","HUMAN"),("TIME","02:41.37"),("ORBS","42 / 42"),
        ("REPLAY","MATCH"),("ISSUED","2026-11-14 · 21:00Z")]
xs=[110,620,900]; fx,fy=110,440
for i,(k,v) in enumerate(fields):
    cx=xs[i%3]; cy=fy+(i//3)*120
    d.text((cx,cy),k,font=F(IS,26),fill=GREY)
    d.text((cx,cy+34),v,font=F(PM,40),fill=GOLD2 if k in("TIME","REPLAY") else CREAM)
d.line([110,700,1270,700],fill=(80,66,34),width=2)
d.text((110,720),f"BUILD  {receipt['build'][7:23]}…   INPUTS  {receipt['inputs'][7:23]}…   SEED  {receipt['seed']}",font=F(IM,24),fill=GREY)
d.text((110,760),f"SIGNED ed25519 · key {fp[:8]}…{fp[-8:]} · issuer runtime.meshtool.ai",font=F(IM,24),fill=GREY)
d.text((110,800),"SAMPLE TAG · demo key · not a real run",font=F(IS,24),fill=(200,90,90))
# stub: tag number + QR
d.text((1395,70),"TAG NO.",font=F(IS,24),fill=GREY)
d.text((1395,100),"MT-0001",font=F(PB,56),fill=GOLD)
q=qrcode.QRCode(border=1,box_size=10,error_correction=qrcode.constants.ERROR_CORRECT_M)
q.add_data("https://runtime.meshtool.ai/verify?tag=MT-SAMPLE-0001"); q.make()
qi=q.make_image(fill_color=(8,9,11),back_color=GOLD2).convert('RGB').resize((340,340),Image.NEAREST)
img.paste(qi,(1395,190))
# check mark next to MATCH
d.line([(792,632),(806,646),(832,614)],fill=GOLD2,width=6)
d.text((1395,550),"SCAN TO VERIFY",font=F(IS,28),fill=CREAM)
d.text((1395,595),"Works without an account.",font=F(IM,22),fill=GREY)
d.text((1395,625),"The full signed receipt",font=F(IM,22),fill=GREY)
d.text((1395,653),"lives inside this image.",font=F(IM,22),fill=GREY)
d.text((1395,740),"meshtool.itch.io",font=F(PM,28),fill=TURQ)
# embed
meta=PngImagePlugin.PngInfo(); meta.add_itxt("meshtag",json.dumps(tagdoc),zip=True)
meta.add_text("Software","Meshtool Mesh Tag v1"); meta.add_text("Comment","Signed run receipt. Verify: runtime.meshtool.ai/verify")
img.save(os.path.join(os.path.dirname(__file__),'mesh-tag-sample.png'),pnginfo=meta,dpi=(300,300))
print("saved", tagdoc["cid"][:20])
