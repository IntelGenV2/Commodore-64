"""Four hand-drawn landscapes for the high-resolution VIC-II bitmap."""
from math import sin
from random import Random
from PIL import Image, ImageDraw

WORLDS = ("ORCHARD", "SEASHORE", "SNOW DAY", "BEDTIME")
# Inclusive walking bounds, shared by the renderer and generated collision data.
LEDGES = ((48,98,102,170,186,230), (56,106,110,178,198,242),
          (40,94,96,162,178,222), (52,100,102,174,192,238))
SKY = ((5,13,9),(14,3,6),(12,15,14),(6,4,14))
SURFACE = (13,7,1,10)


def orchard(d):
    for x,y,s in [(6,49,31),(50,36,27),(245,49,34),(298,38,34)]:
        d.polygon([(x-3,146),(x+1,y+18),(x-13,y+1),(x+5,y+15),(x+15,y+1),(x+7,y+21),(x+10,146)],fill=1)
        for dx,dy,r in [(-s//2,4,s//2),(0,-7,s//2+4),(s//2,4,s//2),(0,11,s//2)]:
            d.ellipse((x+dx-r,y+dy-r,x+dx+r,y+dy+r),fill=1)
        for dx,dy in [(-12,1),(3,-7),(15,6),(-2,11)]:
            d.ellipse((x+dx-2,y+dy-2,x+dx+2,y+dy+2),fill=0)
    for x in range(-6,323,15):
        d.polygon([(x,145),(x,124),(x+3,120),(x+6,124),(x+6,145)],outline=1)
    d.line((0,131,319,131),fill=1)
    d.arc((90,50,201,127),190,337,fill=1)


def seashore(d):
    d.ellipse((210,31,244,65),fill=1)
    for x,y in [(41,44),(57,36),(168,51),(271,41)]:
        d.line([(x-5,y-2),(x-2,y-2),(x,y+1),(x+2,y-2),(x+5,y-2)],fill=1)
    d.line((0,98,319,98),fill=1)
    for x,y,s in [(22,89,17),(170,95,12)]:
        d.polygon([(x,y),(x+s,y),(x+s-4,y+4),(x+4,y+4)],fill=1)
        d.polygon([(x+8,y-3),(x+8,y-25),(x-2,y-3)],fill=1)
        d.polygon([(x+10,y-17),(x+10,y-3),(x+18,y-3)],outline=1)
    for y in range(104,145,7):
        for x in range(-20+(y*3)%29,320,32):
            d.arc((x,y-5,x+18,y+2),5,175,fill=1)


def snow(d):
    for x,y,w in [(-23,94,90),(15,65,97),(70,42,137),(152,69,99),(196,38,137),(282,76,76)]:
        h=w//2
        d.polygon([(x,139),(x+h,y),(x+w,139)],fill=0,outline=1)
        d.line([(x+h-13,y+23),(x+h-5,y+17),(x+h,y+24),(x+h+5,y+13),(x+h+15,y+25)],fill=1)
    for x,y,h in [(12,107,33),(26,119,22),(73,113,26),(227,115,26),(248,103,37),(308,111,31)]:
        for i in (0,1,2):
            a=4+i*3
            d.polygon([(x,y+i*7),(x-a,y+i*7+12),(x+a,y+i*7+12)],fill=1)
        d.line((x,y+23,x,y+h),fill=1,width=2)
    rng=Random(24)
    for _ in range(65):
        d.point((rng.randrange(320),rng.randrange(26,95)),1)


def bedtime(d):
    # Wallpaper, a curtained window, a bookshelf and a bedside lamp.
    for x in range(5,320,14):
        for y in range(31,144,16):
            d.line([(x-1,y),(x,y-2),(x+1,y),(x,y+2),(x-1,y)],fill=1)
    d.rectangle((32,37,98,91),fill=0,outline=1,width=2)
    d.ellipse((53,43,73,63),fill=1)
    d.ellipse((59,40,77,59),fill=0)
    d.line((65,38,65,91),fill=1)
    d.line((32,66,98,66),fill=1)
    for x in (30,87):
        d.polygon([(x,36),(x+15,36),(x+7,65),(x+12,90),(x,90)],fill=1)
    d.rectangle((213,42,286,92),fill=0,outline=1,width=2)
    for j in (0,1):
        floor=66+j*23
        d.line((214,floor,285,floor),fill=1,width=2)
        for i in range(6):
            x=217+i*8
            d.rectangle((x,floor-12-(i*3+j)%7,x+4,floor-2),outline=1)
        d.line((272,floor-18,280,floor-2),fill=1,width=3)
    d.polygon([(10,105),(21,105),(26,119),(5,119)],fill=1)
    d.line((15,120,15,139),fill=1,width=2)
    d.line((8,140,22,140),fill=1)


def scenery(im, zone):
    mask=Image.new("1", im.size)
    (orchard,seashore,snow,bedtime)[zone](ImageDraw.Draw(mask))
    for y in range(24,152,8):
        for x in range(0,320,8):
            if zone==0:
                shade=0 if y<80 else 2
            elif zone==1:
                shade=1 if x>=208 and x<248 and y<72 else (0 if y>=96 else 2)
            elif zone==2:
                shade=1 if y<64 else (0 if y<104 else 2)
            else:
                shade=2 if 24<=x<104 and y<96 else (1 if 208<=x<288 and y<96 else 0)
            box=(x,y,x+8,y+8)
            im.paste(SKY[zone][shade],box,mask.crop(box))