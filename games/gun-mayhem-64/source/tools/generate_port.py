"""Hand-drawn VIC-II characters/sprites and compressed reference-derived arenas.

The title bitmap is drawn separately by title_art.py.
"""
from pathlib import Path
import json
import math
import struct
from PIL import Image, ImageDraw
from navigation import prepare
from title_art import generate_title

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/port'
OUT.mkdir(exist_ok=True)
VIC = ['000000','ffffff','984b43','79c1c8','9b51a5','68ae5c','40318d','c9d17c',
       '9e7448','6a5400','c37b75','505050','787878','a9e99e','7869c4','a0a0a0']
PALETTE = [tuple(bytes.fromhex(v)) for v in VIC]
chars = bytearray(2048)

# Native, two-pixel-stroke C64 lettering survives composite/CRT filtering.
glyphs = (ROOT/'assets/font.bin').read_bytes()
font = {chr(c): list(glyphs[(c-32)*8:(c-31)*8]) for c in range(32,91)}
for ch,rows in font.items():
    chars[ord(ch)*8:ord(ch)*8+8] = bytes(rows)

# Two-pixel arrow shafts for the off-screen recovery indicator's sprite font.
chars[116*8:117*8] = bytes((0x10,0x30,0x7e,0xfe,0x7e,0x30,0x10,0))
chars[117*8:118*8] = bytes((0x08,0x0c,0x7e,0x7f,0x7e,0x0c,0x08,0))


def mc(index, rows):
    assert len(rows)==8 and all(len(r)==4 for r in rows)
    chars[index*8:index*8+8] = bytes(sum(int(v)<<(6-x*2) for x,v in enumerate(r)) for r in rows)


tiles = [
 ['2222','2332','3333','3133','3313','3333','1111','1111'], # 128 platform lip
 ['3333','1333','1331','1111','0000','0000','0000','0000'], # end left
 ['3333','3331','1331','1111','0000','0000','0000','0000'],
 ['2333','3333','3333','1131','3323','3333','3333','3111'], # masonry
 ['0033','0033','0022','0011','0033','0033','0022','0011'],
 ['1221','1331','1331','1331','1221','1331','1331','1111'], # column
 ['2222','3333','3333','3113','3133','3333','1111','1111'], # metal
 ['0110','1331','1311','1131','1331','1110','0110','0000'], # foliage
 ['0000','0000','0011','0111','1111','1111','1111','1111'], # hills
 ['0000','0000','1100','1110','1111','1111','1111','1111'],
 ['1111']*8,
 ['0000','0330','3333','3333','3333','0000','0000','0000'], # clouds
 ['3113','1221','3113','3113','1221','3113','1221','1111'], # girder
 ['0030','0030','0333','3313','3113','1113','0003','0003'], # vine
 ['3333','3323','3233','2333','1111','0000','0000','0000'], # wood lip
 ['0110','1331','1331','1331','1111','1221','1331','1111'], # lamp post
 ['0110','1331','1331','1111','1331','1331','1331','1111'], # roof brick
 ['0110','1331','1331','1111','1221','1221','1221','1111'],
 ['2222','2232','2323','3333','3333','1331','1131','0110'], # ice
 ['1313','1333','3133','3313','1333','3133','3313','1111'], # rock
 ['0000','0000','0000','3333','3333','1111','1111','1111'], # far shoreline
 ['0000','0000','0000','0000','2222','0000','0000','0000'], # waves
 ['0000','0000','0100','0110','0111','1111','1111','1111'],
 ['0000','0000','0010','0110','1110','1111','1111','1111'],
 ['1111','1331','1331','1111','1111','1331','1331','1111'], # windows
 ['1111','1331','1331','1111','1111','1111','1111','1111'],
 ['3333','2323','3333','1111','3133','3313','3331','1111'], # grass lip
 ['1331','1331','1331','1331','1331','1331','1331','1111'],
 ['0000','0000','0000','0000','1111','1331','1221','1111'],
 ['1331','1311','1331','1131','1331','1311','1331','1111'],
 ['0110','1221','2332','2332','2332','2332','1221','0110'], # crate
 ['0000','0020','0300','0300','0300','0300','0100','0000'], # dynamite
 ['0000','0200','0020','2323','0230','2320','0202','0000'], # blast
 ['0000','0000','0010','1111','1331','1111','0000','0000'], # pistol pickup
]
for i,rows in enumerate(tiles): mc(128+i,rows)
# Architectural details share the same 2 KB character set across all arenas.
extra = [
 ['0033','0033','0333','0333','3333','3333','1111','0000'], #162 roof left
 ['3300','3300','3330','3330','3333','3333','1111','0000'],
 ['3333','3131','3333','3131','3333','3333','1111','0000'],
 ['0000','0000','0000','0000','0330','2332','2332','0110'], #165 lantern
 ['3333','3313','3313','3313','3313','3313','3313','1111'], #166 post
 ['3333','1333','1133','3113','3311','3331','1333','1133'], #167 hazard
 ['0110','1221','2112','2132','2132','2112','1221','0110'], #168 tire
 ['0110','1221','1221','1221','1221','1221','1221','0110'], #169 pipe
 ['3333','3333','3113','3113','3113','3113','3333','3333'], #170 windows
 ['3131','3131','3333','3333','3333','3333','3333','1111'], #171 battlement
 ['1111','1131','1333','3333','3333','3333','3333','3333'], #172 cliff slope
 ['1111','1311','3331','3333','3333','3333','3333','3333'],
 ['3333','3333','3333','3333','3333','3333','3333','3333'], #174 solid
 ['3333','2332','3333','3333','1331','1111','0110','0000'], #175 canopy
 ['3000','3300','0330','0330','0033','0033','0003','0003'], #176 branch
 ['0003','0033','0330','0330','3300','3300','3000','3000'],
 ['1331','1331','1331','1331','1331','1331','1331','1331'], #178 column
 ['0000','0000','0000','1111','1331','1221','1331','1111'], #179 capital
 ['3333','3133','3133','3333','3313','3313','3333','1111'], #180 wood
 ['1111','1111','1111','1111','1111','1111','1111','2222'], #181 concrete
 ['2222','1331','1331','1331','1331','1331','1111','2222'], #182 lit window
]
for i, rows in enumerate(extra): mc(162+i, rows)
for y in range(4):
    for x in range(4):
        rows=[0]*8
        rows[y*2]=rows[y*2+1]=(0xf0,0x3c,0x0f,0x03)[x]
        chars[(224+y*4+x)*8:(225+y*4+x)*8]=bytes(rows)

# Large title letters are built from the same hand-authored font.
for i,ch in enumerate('GUNMAYHE64'):
    glyph=font[ch]
    for half in range(2):
        rows=[]
        for row in glyph[half*4:half*4+4]: rows.extend([row,row])
        chars[(96+i*2+half)*8:(97+i*2+half)*8]=bytes(rows)
generate_title(OUT)
(OUT/'charset.bin').write_bytes(chars)

# Multicolor sprite pixels: transparent, black outline, body color, white.
body = [
 '000111100000','001222210000','012222221000','012222221000',
 '012222221000','012332331000','012112111000','012222221000',
 '012221221000','001222210000','000122110000','001333311110',
 '012333322331','012333311111','001333310000','000111110000',
 '000122210000','000120210000','001220221000','001110111000','000000000000']
frames=[]
for facing in range(2):
    for pose in range(6):
        rows=body.copy()
        if pose==1:
            rows[17:20]=['001220021000','012210022100','011100011100']
        if pose==2:
            rows[17:20]=['000122100000','000122210000','000111110000']
        if pose==3:
            rows[16:21]=['001222221000','012110122100','011000011100','000000000000','000000000000']
        if pose==4: # recoil and muzzle flash
            rows[10:13]=['012333311131','012333322333','001333311131']
        if pose==5: # hat
            rows[0:3]=['000111110000','001333331000','011111111100']
        if facing==0: rows=[r[::-1] for r in rows]
        frames.append(rows)
frames += [
 ['000000000000']*3+['000111111000','001333333100','001321123100','001312133100','001331233100','001333333100','000111111000']+['000000000000']*11,
 ['000000000000']*3+['000003000000','000030000000','000122100000','000122100000','000122100000','000111100000']+['000000000000']*12,
 ['000000000000','000030003000','003003030000','000323230300','003232323000','032323232300','003232323000','000323230000','030030003000']+['000000000000']*12,
 ['000000000000']*5+['000111111110','001333333331','001222211110',
 '000122210000','000122100000','000111100000']+['000000000000']*10]
for base in frames[:12]:
    rows=base.copy()
    rows[:3]=['000111110000','000133310000','001111111000']
    frames.append(rows)
sprites=bytearray()
for rows in frames:
    assert len(rows)==21
    for row in rows:
        assert len(row)==12
        for start in (0,4,8):
            sprites.append(sum(int(v)<<(6-j*2) for j,v in enumerate(row[start:start+4])))
    sprites.append(0)
(OUT/'sprites.bin').write_bytes(sprites)

# Names identify redrawn visual themes; numeric ordering matches the original.
NAMES=['DRAGON TEMPLE','ROADWORKS','POWER STATION','ORBITAL','BAMBOO',
       'FROZEN CAVERN','PIPEWORK','SKY SCAFFOLD','JUNGLE RUINS','CONCRETE',
       'TIMBER','COLOSSEUM','PIPE TOWERS','FORTRESS','VINES','WOODWORK',
       'FLOATING FORT','TREE CANOPY','ICEBERG','ROOFTOPS','GRASS CANYON']
# sky, shadow, highlight, platform hue, support hue, platform tile, support tile
THEMES=[(3,6,10,2,4,128,131),(3,11,15,5,7,134,140),(6,11,15,4,7,134,140),
        (0,6,3,3,5,134,140),(3,9,7,7,2,142,157),(6,11,3,3,6,146,147),
        (0,11,7,5,7,134,140),(14,6,15,3,3,134,140),(3,9,7,7,5,128,131),
        (11,0,15,1,1,134,131),(14,9,7,7,7,142,157),(14,11,1,1,1,128,133),
        (0,11,15,3,1,134,140),(3,9,7,7,7,128,131),(14,9,13,5,5,154,141),
        (3,9,7,7,7,142,157),(14,9,13,5,2,154,131),(3,9,13,5,7,154,141),
        (14,6,1,3,3,146,147),(14,11,15,1,7,134,152),(3,9,13,5,7,154,147)]


def rle(data):
    out=bytearray()
    pos=0
    while pos<len(data):
        count=1
        while count<255 and pos+count<len(data) and data[pos+count]==data[pos]: count+=1
        out.extend((count,data[pos]))
        pos+=count
    out.append(0)
    return out


def render(screen,colors,theme):
    im=Image.new('RGB',(320,200),PALETTE[theme[0]])
    px=im.load()
    for cell,ch in enumerate(screen):
        cx,cy=(cell%40)*8,(cell//40)*8
        color=colors[cell]
        for y,bits in enumerate(chars[ch*8:ch*8+8]):
            if color&8:
                palette=[theme[0],theme[1],theme[2],color&7]
                for x in range(4):
                    c=PALETTE[palette[(bits>>(6-x*2))&3]]
                    px[cx+x*2,cy+y]=px[cx+x*2+1,cy+y]=c
            else:
                for x in range(8): px[cx+x,cy+y]=PALETTE[color if bits&(128>>x) else theme[0]]
    return im


layouts=json.loads((ROOT/'assets/maps/layouts.json').read_text())
blob=bytearray()
offsets=[]
atlas=Image.new('RGB',(320*3,224*7),'#111111')
draw=ImageDraw.Draw(atlas)
manifest=[]
for i,layout in enumerate(layouts):
    # Black sky and a shared white highlight keep projectiles readable.
    theme=(0, THEMES[i][1], 1, *THEMES[i][3:])
    screen=bytearray([32]*1000)
    colors=bytearray([1]*1000)
    def tile(x,y,t,c):
        if 0<=x<40 and 3<=y<24:
            screen[y*40+x]=t
            colors[y*40+x]=8+(c&7)
    platforms,routes=prepare(layout['platforms'])
    assert 1 <= len(platforms) <= 19
    assert all(1 <= col < col+width <= 39 and 3 <= row <= 22
               for col,row,width in platforms)
    background_screen,background_colors=screen.copy(),colors.copy()
    for col,row,width in reversed(platforms):
        # Architectural supports vary with the original arena's construction.
        if i in (3,9,18,19,20):
            columns=range(col+1,col+width-1)
            limit=24 if row==max(p[1] for p in platforms) else min(24,row+3)
        else:
            centers=[col+2,col+width-3] if width>12 else [col+width//2]
            columns=[x for center in centers for x in (center,center+1)]
            limit=24
        for cx in columns:
            for cy in range(row+1,limit):
                tile(cx,cy,theme[6],theme[4])
    for col,row,width in platforms:
        for dx in range(width): tile(col+dx,row,theme[5],theme[3])
        if i in (0,4,8,14,16,17,20):
            tile(col+1,row-1,135,5)
            if width>10: tile(col+width-2,row-1,135,5)
    if i==0: # Temple gate and paired roof lanterns.
        # The original has two long legs, not a forest of full-height supports.
        for y in range(7,24):
            for x in range(40):
                if screen[y*40+x]==131: tile(x,y,32,1)
        for x,start,end in [(13,14,24),(14,14,24),(27,7,24),(28,7,24),
                            (21,7,10),(22,7,10)]:
            for y in range(start,end): tile(x,y,131,4)
        col,row,w=platforms[0]
        for y in range(row-3,row):
            tile(col+1,y,166,2); tile(col+w-2,y,166,2)
        for x in range(col,col+w): tile(x,row-3,171,2)
        for x in (5,34):
            for y in range(6,13): tile(x,y,166,2)
            tile(x-1,4,162,2); tile(x,4,164,2); tile(x+1,4,163,2)
            tile(x-1,5,165,7); tile(x+1,5,165,7)
    if i in (1,2,6):
        for x in (8,20,32):
            for y in range(4,23):
                if screen[y*40+x]==32: tile(x,y,132,7)
            tile(x,3,139,1)
    if i==1:
        for x in (6,7,17,18,29,30): tile(x,22,167,7)
        for x in (4,5,6,9,10,15,16,19,20,26,27,31,32,33): tile(x,23,168,6)
    if i==11:
        for y in range(7,24):
            for x in range(40):
                if screen[y*40+x]==133: tile(x,y,178,1)
        for x in (7,31):
            tile(x,7,155,2); tile(x,8,155,2)
    if i==16:
        for x in range(9,17):
            for y in range(10,13): tile(x,y,152 if y==11 else 131,7 if y==11 else 2)
        for x in range(22,30):
            for y in range(12,14): tile(x,y,152,7)
    if i==17:
        for y in range(7,24):
            for x in range(40):
                if screen[y*40+x]==141: tile(x,y,32,1)
        for y in range(7,24):
            for x in (19,20): tile(x,y,180,7)
        for col,row,width in platforms:
            for x in range(col+width//2,20) if col<20 else range(20,col+width//2):
                cy=min(23,row+1+abs(x-(col+width//2))//2)
                tile(x,cy,176 if col<20 else 177,7)
    if i==13:
        for col,row,width in platforms:
            if width>15:
                for x in range(col,col+width):
                    for y in range(row+1,24): tile(x,y,131,7)
            elif row<12:
                for x in range(col,col+width):
                    tile(x,row-1,171,7)
                    for y in range(row+1,19): tile(x,y,131,7)
    if i==19:
        for col,row,width in platforms:
            for x in range(col,col+width):
                for y in range(row+1,24):
                    tile(x,y,170 if y%3==0 and x%3!=0 else 174,7 if y%3==0 and x%3!=0 else 1)
    # Scene-specific supports are redrawn from the reference silhouettes.
    if i in (1,2,3,4,5,6,7,8,9,10,12,14,15,16,18,19,20):
        screen,colors=background_screen.copy(),background_colors.copy()
        def column(x,start,end,t,c,width=1):
            for cy in range(start,end):
                for dx in range(width): tile(x+dx,cy,t,c)
        def beam(x0,y0,x1,y1,t,c):
            steps=max(abs(x1-x0),abs(y1-y0),1)
            for step in range(steps+1):
                tile(round(x0+(x1-x0)*step/steps),round(y0+(y1-y0)*step/steps),t,c)
        if i==1:
            for x in (8,20,32):
                column(x,4,24,169,1)
                tile(x-1,3,139,1); tile(x,3,139,1)
            for col,row,width in platforms: tile(col+width//2,row-1,165,7)
            for x in (6,7,17,18,29,30): tile(x,22,167,7)
            for x in (4,5,6,9,10,15,16,19,20,26,27,31,32,33): tile(x,23,168,6)
        elif i==2:
            column(19,7,24,178,4,2)
            for x in (7,9,12,26,29,32):
                column(x,7,9,140,3); column(x,17,20,140,3)
            for col,row,width in platforms:
                if row in (9,13,16):
                    column(col+1,row-3,row,140,3)
                    column(col+width-2,row-3,row,140,3)
            beam(2,3,2,11,166,7); beam(2,11,7,11,166,7)
            beam(36,18,39,18,166,7); beam(39,18,39,23,166,7)
            column(23,3,24,166,7)
        elif i==3:
            for x in (12,27):
                column(x,7,9,140,3,2); column(x,10,16,140,3,2)
            for x in range(8,33): tile(x,17,134,3)
            for x in (8,9,31,32): column(x,18,20,170,3)
            for x,y in ((6,10),(31,10),(17,14),(23,4)): tile(x,y,168,5)
        elif i==4:
            for x,start in ((9,7),(20,7),(29,7),(33,14)): column(x,start,24,180,2)
        elif i==5:
            for x,start,end in ((8,7,24),(9,7,24),(30,7,24),(31,7,24),
                                (19,7,9),(20,7,9),(22,10,16),(23,10,16)):
                column(x,start,end,147,6)
        elif i==6:
            column(19,7,22,169,5)
            beam(10,7,18,18,169,5); beam(29,7,21,18,169,5)
            beam(6,7,0,16,169,7); beam(32,7,39,16,169,7)
            beam(10,14,0,23,169,7); beam(29,14,39,23,169,7)
            beam(19,21,17,24,169,5); beam(20,21,22,24,169,5)
        elif i==7:
            column(5,13,24,140,3); column(34,13,24,140,3)
            column(19,7,22,140,3,2)
            for x in range(9,32): tile(x,16,140,3)
        elif i==8:
            for x in (12,13,28,29): column(x,7,24,131,7)
            column(7,7,16,131,7); column(33,7,16,131,7); column(20,10,13,131,7)
            for col,row,width in platforms:
                tile(col,row+1,141,5); tile(col+width-1,row+1,141,5)
        elif i==9:
            for x in range(3,37): tile(x,5,174,1)
            for x in (3,36): column(x,6,17,174,1)
            column(19,7,17,174,1,2)
            for x in (8,17,22,31): column(x,17,24,178,1)
            for col,row,width in platforms[1:-1]: column(col+width//2,row+1,row+3,178,1)
        elif i==10:
            for x,start in ((5,7),(9,10),(14,14),(26,14),(31,10),(34,7)):
                column(x,start,24,180,7)
            column(17,14,16,180,7); column(23,14,16,180,7)
        elif i==12:
            for x in (9,30): column(x,7,24,169,1)
            column(19,12,24,169,1,2)
            beam(9,10,19,10,169,1); beam(21,17,30,17,169,1)
        elif i==14:
            for col,row,width in platforms:
                center=col+width//2
                for y in range(row+1,min(row+8,24)):
                    x=center+round(math.sin((y-row)*.65)*2)
                    tile(x,y,178,5)
                    if width>6: tile(x+2,y,178,5)
        elif i==15:
            for x in (7,12,27,32): column(x,7,24,180,7)
        elif i==16:
            for left,top,right,bottom in ((7,10,19,18),(20,12,32,18)):
                for y in range(top,bottom):
                    for x in range(left,right):
                        window = y in (top+1,top+2) and x%4 in (1,2)
                        tile(x,y,174 if window else 180,3 if window else 2)
            for x in (8,31): column(x,5,18,178,1)
            for y in range(19,24):
                inset=(y-19)*3
                for x in range(3+inset,37-inset): tile(x,y,147,7)
        elif i==18:
            for col,row,width in platforms:
                for y in range(row+1,24):
                    for x in range(col,col+width): tile(x,y,178 if x%3==0 else 174,3)
        elif i==19:
            for left,top,right in ((10,7,30),(4,13,36),(2,20,16),(23,20,38)):
                end=19 if top<20 else 24
                for y in range(top,end):
                    for x in range(left,right): tile(x,y,182 if y%3!=1 and x%3!=0 else 181,7)
            column(29,4,6,131,2)
        elif i==20:
            for col,row,width in platforms[:2]:
                for x in range(col,col+width):
                    for y in range(row+1,9): tile(x,y,147,7)
            for x in (7,8,30,31): column(x,10,24,147,7)
            for y in range(17,24):
                for x in range(8,31): tile(x,y,147,7)
    # Platforms are drawn last so decorative supports cannot cover their edges.
    for col,row,width in platforms:
        for dx in range(width): tile(col+dx,row,theme[5],theme[3])
        if i==17:
            for dx in range(width): tile(col+dx,row,175,5)
    offsets.append(len(blob))
    # Header: VIC colors, number of platforms, four spawn platform indices.
    left=min(range(len(platforms)),key=lambda n:platforms[n][0]*8+platforms[n][2]*4)
    right=max(range(len(platforms)),key=lambda n:platforms[n][0]*8+platforms[n][2]*4)
    spawns=[left,right,0,len(platforms)-1]
    blob.extend([*theme[:3],len(platforms),*spawns])
    for col,row,width in platforms:
        blob.extend(struct.pack('<HHB',col*8,(col+width)*8,row*8))
    blob.extend(routes)
    blob+=rle(screen)+rle(colors)
    arena=blob[offsets[-1]:]
    assert len(arena)<=1536, 'Arena exceeds the resident load window'
    (ROOT/f'build/files/arena{i+1:02}.prg').write_bytes(struct.pack('<H',0x5000)+arena)
    preview=render(screen,colors,theme)
    preview.save(ROOT/f'build/arena-{i+1:02}.png')
    x,y=(i%3)*320,(i//3)*224
    draw.text((x+8,y+5),f'{i+1:02} {NAMES[i]}',fill='white')
    atlas.paste(preview,(x,y+24))
    manifest.append({'name':NAMES[i],'bytes':len(blob)-offsets[-1],**layout,
                     'reference_platforms':layout['platforms'],'platforms':platforms,
                     'routes':list(routes)})
(OUT/'maps.bin').write_bytes(blob)
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
lines=['// Generated by tools/generate_port.py','map_names:']
lines += ['.text "'+name.ljust(16)+'"' for name in NAMES]
(OUT/'tables.asm').write_text('\n'.join(lines)+'\n')
atlas.save(ROOT/'build/redrawn-arenas.png')
sp=Image.new('RGB',(24*8,21*4),'#7869c4')
for i,rows in enumerate(frames):
    for y,row in enumerate(rows):
        for x,v in enumerate(row):
            color=[14,0,10 if i<6 else 3,1][int(v)]
            for dx in range(2): sp.putpixel(((i%8)*24+x*2+dx,(i//8)*21+y),PALETTE[color])
sp.resize((768,336),Image.Resampling.NEAREST).save(ROOT/'build/redrawn-sprites.png')
print(f'21 arenas: {len(blob)} bytes; charset: {len(chars)}; sprites: {len(sprites)}')
