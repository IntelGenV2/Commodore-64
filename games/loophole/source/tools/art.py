"""Draw the original pixel art and pack it into VIC-II high-resolution cells."""
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build"
OUT.mkdir(exist_ok=True)
BLACK, WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW = range(8)
ORANGE, BROWN, CORAL, DARK, GRAY, MINT, LBLUE, SILVER = range(8, 16)

# Five columns and seven scanlines. Both the screen art and runtime lettering
# use these same hand-set glyphs.
GLYPHS = {
    "A":"0e11111f111111","B":"1e11111e11111e","C":"0f10101010100f",
    "D":"1e11111111111e","E":"1f10101e10101f","F":"1f10101e101010",
    "G":"0f10101711110f","H":"1111111f111111","I":"0e04040404040e",
    "J":"0702020212120c","K":"11121418141211","L":"1010101010101f",
    "M":"111b1515111111","N":"11191915131311","O":"0e11111111110e",
    "P":"1e11111e101010","Q":"0e11111115120d","R":"1e11111e141211",
    "S":"0f10100e01011e","T":"1f040404040404","U":"1111111111110e",
    "V":"11111111110a04","W":"1111111515150a","X":"11110a040a1111",
    "Y":"11110a04040404","Z":"1f01020408101f","0":"0e11131519110e",
    "1":"040c040404040e","2":"0e11010204081f","3":"1e01010e01011e",
    "4":"02060a121f0202","5":"1f10101e01011e","6":"0e10101e11110e",
    "7":"1f010204080808","8":"0e11110e11110e","9":"0e11110f01010e",
    " ":"00000000000000",".":"00000000000004",",":"00000000000408",
    "/":"01020204080810","-":"0000000e000000","!":"04040404040004",
    "?":"0e110102040004",":":"00000400000400","+":"0004041f040400",
    "'":"04040800000000","<":"02040810080402",">":"08040201020408",
}
FONT = {ch:bytes.fromhex(data) for ch, data in GLYPHS.items()}


def lettering(d, xy, words, color, spacing=6):
    x, y = xy
    for ch in words:
        for dy, row in enumerate(FONT[ch]):
            for dx in range(5):
                if row & 16 >> dx:
                    d.point((x+dx, y+dy), color)
        x += spacing


def canvas():
    return Image.new("L", (320, 200), BLACK)


ROBOT = [
    "......OO........", "......OO........", ".......K........",
    "....CCCCCCCC....", "...CLLLLLLLLLC..", "..CLCCCCCCCCCLC.",
    "..CLKKKKKKKKKLC.", "..CCKKLLKKLLKCC.", "..GCKKLLKKLLKCG.",
    "..GCCKKKKKKKCCG.", "...GCCCCCCCCCG..", "....OOOOOOOOO...",
    "..GGCCLLCCCOOO..", "..GCCCLLCCCC.OO.", "..GCGCCCCCGC....",
    "....GGGGGGGG....", ".....GG..GG.....", "....CCC..CCC....",
]
INKS = {"K":BLACK, "G":GRAY, "C":CYAN, "L":WHITE, "O":CORAL}


def robot_frame(pose, left):
    rows = ROBOT.copy()
    if pose == 1:
        rows[-2:] = ["...GG.....GG....", "..CCC.....CCC..."]
    elif pose == 2:
        rows[-2:] = ["......GGGG......", ".....CCC.CC....."]
    elif pose == 3:
        rows[12:15] = ["GGC.CCLLCCCOOO..","G...CCLLCCCC.OOG","....GCCCCCCG..GG"]
        rows[-2:] = ["...GG....CCC....","..CCC..........."]
    return [r[::-1] if left else r for r in rows]


def draw_title():
    im = canvas()
    d = ImageDraw.Draw(im)
    # The inner opening surrounds the doubled hardware sprite at (238, 50).
    # Offset the rims toward it, as in the original Loophole cover.
    for cx,cy,r,width in ((260,63,56,2),(259,64,51,1),(257,65,46,1),
                           (255,66,40,2),(254,67,33,1),(253,68,26,1)):
        d.ellipse((cx-r,cy-r,cx+r,cy+r),outline=GRAY,width=width)
    for start,end in ((207,252),(282,309),(29,75),(108,135)):
        d.arc((201,4,319,122),start,end,fill=GRAY)
    for x,y in ((192,22),(198,44),(208,8),(216,112),(199,91),(285,6),
                (307,17),(317,33),(312,109),(293,121),(231,123)):
        d.point((x,y),fill=GRAY)
    for x,y in ((212,28),(308,100)):
        # Give each four-point glint one VIC-II color cell of its own.
        left,top=x//8*8,y//8*8
        d.rectangle((left,top,left+7,top+7),fill=BLACK)
        d.line((x-2,y,x+2,y),fill=CYAN)
        d.line((x,y-3,x,y+3),fill=CYAN)
    display = {
        "L":["11000"]*5+["11111","11111"],
        "O":["01110","11111","11011","11011","11011","11111","01110"],
        "P":["11110","11111","11011","11111","11110","11000","11000"],
        "H":["11011","11011","11011","11111","11011","11011","11011"],
        "E":["11111","11111","11000","11110","11000","11111","11111"],
    }
    for word, y0, face in [("LOOP",18,WHITE),("HOLE",66,CYAN)]:
        for shadow in (True,False):
            for n,letter in enumerate(word):
                for y,row in enumerate(display[letter]):
                    for yy in range(6):
                        py=y*6+yy
                        for x,ink in enumerate(row):
                            if ink=="1":
                                base=11+n*42+x*7+(41-py)//6
                                dx,dy=(3,4) if shadow else (0,0)
                                if shadow:
                                    for px in range(base+dx,base+dx+7):
                                        if (px+py)%3==0:
                                            d.point((px,y0+py+dy),fill=face)
                                else:
                                    d.line((base,y0+py,base+6,y0+py),fill=face)
    lettering(d,(13,4),"A LITTLE WAY HOME",SILVER)
    lettering(d,(13,120),"FOUR WORLDS. FORTY WAYS OUT.",SILVER)
    d.line((8,136,311,136),fill=GRAY)
    for x in range(8,306,8):
        d.point((x,138),fill=GRAY)
    lettering(d,(14,144),"PORT 2 JOYSTICK",CYAN)
    lettering(d,(14,156),"LEFT/RIGHT  MOVE",SILVER)
    lettering(d,(14,168),"FIRE/UP  JUMP",SILVER)
    lettering(d,(158,144),"F5 SAVE   F7 LOAD",CYAN)
    lettering(d,(158,156),"F1 HINT   F3 RETRY",SILVER)
    lettering(d,(158,168),"F8 SOUND",SILVER)
    d.rounded_rectangle((9,180,310,198),radius=4, fill=CYAN)
    lettering(d,(104,186),"PRESS FIRE TO BEGIN",BLACK)
    return im


def platform(d, x1, x2, y, ink, zone):
    d.rectangle((x1//8*8,y,(x2//8+1)*8-1,y+7),fill=BLACK)
    d.line((x1,y,x2,y),fill=ink,width=2)
    for x in range(x1+2,x2-4,7):
        if zone==0:
            d.line([(x,y+2),(x+1,y+5),(x+4,y+3)],fill=ink)
        elif zone==1:
            d.line((x,y+3,x+4,y+3),fill=ink)
            d.point((x+2,y+5),ink)
        elif zone==2:
            d.line([(x,y+2),(x+1,y+6),(x+3,y+2)],fill=ink)
        else:
            d.line((x,y+5,x+3,y+4),fill=ink)


def door(d, opened):
    d.rectangle((264,112,311,151),fill=BLACK)
    ink=MINT if opened else CORAL
    d.arc((270,113,305,137),180,360,fill=ink,width=2)
    for x in (270,304):
        d.line((x,125,x,150),fill=ink,width=2)
    if opened:
        d.polygon([(275,124),(283,119),(283,143),(275,148)],outline=MINT,width=2)
    else:
        d.rectangle((276,121,298,149),outline=CORAL,width=2)
        d.rectangle((279,125,295,134),outline=CORAL)
        d.rectangle((279,140,295,146),outline=CORAL)
        d.point((294,137),CORAL)


def plate(d, pressed):
    d.rectangle((128,80,159,87),fill=BLACK)
    y = 85 if pressed else 82
    d.rounded_rectangle((132,y,155,86), radius=1, fill=CORAL)
    d.line((135,y+1,151,y+1),fill=BLACK)


def retry_button(d, flashed):
    d.rectangle((216,176,311,191),fill=BLACK)
    d.rounded_rectangle((218,177,310,189),radius=3,outline=CYAN,fill=CYAN if flashed else BLACK)
    ink = BLACK if flashed else CYAN
    d.line([(226,181),(224,183),(226,185)],fill=ink)
    d.line([(225,183),(232,183),(232,186),(230,187)],fill=ink)
    lettering(d,(239,180),"RETRIED" if flashed else "F3: RETRY",ink)


def draw_room(zone=0):
    from zones import LEDGES, SURFACE, WORLDS, scenery
    im=canvas()
    scenery(im,zone)
    d=ImageDraw.Draw(im)
    ink=SURFACE[zone]
    lettering(d,(8,4),WORLDS[zone],ink)
    d.line((8,16,311,16),fill=GRAY)
    d.rectangle((0,144,319,167),fill=BLACK)
    for a,b in ((7,123),(168,312)):
        d.line((a,151,b,151),fill=ink,width=2)
        for x in range(a+4,b-6,10):
            d.line((x,156,x+3,155),fill=ink)
            d.point((x+5,160),ink)
    for x in range(128,168,8):
        d.polygon([(x,162),(x+3,151),(x+6,162)],fill=CORAL)
    left,end,high,top,right,edge=LEDGES[zone]
    for a,b,y in ((left,end,120),(high,top,88),(right,edge,112)):
        platform(d,a,b,y,ink,zone)
    d.rectangle((128,96,151,103),fill=BLACK)
    for x in (130,138,146):
        d.rectangle((x,98,x+3,99),fill=GRAY)
    d.rectangle((272,96,303,111),fill=BLACK)
    lettering(d,(275,101),"EXIT",SILVER)
    door(d,False)
    plate(d,False)
    d.line((6,168,313,168),fill=GRAY)
    retry_button(d,False)
    return im


def encode(im):
    """Lossless VIC-II packing. Reject artwork that would leak cell colors."""
    bits, colors = bytearray(), bytearray()
    for y in range(0,im.height,8):
        for x in range(0,im.width,8):
            pixels=list(im.crop((x,y,x+8,y+8)).get_flattened_data())
            inks=sorted(set(pixels))
            if len(inks)>2:
                raise ValueError(f"Cell at ({x},{y}) uses {inks}; only two inks fit")
            bg,fg=inks[0],inks[-1]
            colors.append((fg<<4)|bg)
            for start in range(0,64,8):
                b=0
                for c in pixels[start:start+8]:
                    b=b*2+(c!=bg)
                bits.append(b)
    return bytes(bits),bytes(colors)


def packets(raw):
    """Literal runs and overlapping LZ back-references into the decoded scene."""
    result = bytearray()
    literals = bytearray()
    i = 0
    while i < len(raw):
        needle = raw[i:i+4]
        stop = i+3
        best, distance = 0, 0
        for _ in range(24):
            j = raw.rfind(needle, 0, stop) if len(needle)==4 else -1
            if j < 0:
                break
            n = 4
            while n < 130 and i+n < len(raw) and raw[i+n] == raw[j+n]:
                n += 1
            if n > best:
                best, distance = n, i-j
            if n == 130:
                break
            stop = j+3
        if best or len(literals) == 127:
            if literals:
                result.append(len(literals))
                result.extend(literals)
                literals.clear()
        if best:
            result.append(128+best-3)
            result.extend((-distance).to_bytes(2,"little",signed=True))
            i += best
        else:
            literals.append(raw[i])
            i += 1
    if literals:
        result.append(len(literals))
        result.extend(literals)
    return result+b"\0"


def emit():
    from zones import LEDGES
    (OUT/"ledges.h").write_text("static const byte ledges[4][6] = {"+
        ",".join("{"+",".join(map(str,row))+"}" for row in LEDGES)+"};\n")
    room=draw_room()
    scenes=[("title",draw_title())]+[(name,draw_room(zone)) for zone,name in
                                     enumerate(("room","shore","snow","bedtime"))]
    for name,im in scenes:
        bits,colors=encode(im)
        (OUT/(name+".bin")).write_bytes(packets(bits)+packets(colors))
    for name,area,draw in [("door",(264,112,312,152),door),("plate",(128,80,160,88),plate),
                           ("retry",(216,176,312,192),retry_button)]:
        data=bytearray()
        for active in range(2):
            tile=room.copy()
            draw(ImageDraw.Draw(tile),active)
            bits,colors=encode(tile.crop(area))
            data.extend(bits+colors)
        (OUT/(name+".bin")).write_bytes(data)
    sprites=bytearray()
    for left in (False,True):
        for pose in range(4):
            rows=robot_frame(pose,left)
            for ink in INKS:
                for row in rows:
                    mask=sum((c==ink)<<(23-x) for x,c in enumerate(row))
                    sprites.extend(mask.to_bytes(3,"big"))
                sprites.extend(bytes(64-3*len(rows)))
    for glyph in (
        ("..####..",".######.","########","########","########",".######.","..####.."),
        ("#.......","####....","#######.","####....","#.......","#.......","#......."),
        (".......#","....####",".#######","....####",".......#",".......#",".......#"),
        ("####################", ".#..#..#..#..#..#..#", "..################.."),
        ("#####...","...#....","..#.....",".#......","#####..."),
        ("..#####..", ".##.#.##.", "##.#.#.##", "#.#.#.#.#", ".#.#.#.#.", "..#####..", "...###..."),
        ("...##...", "..##....", "...##...", "....##..", "...##...", "..##...."),
        ("#.......", "##......", "#.#.....", "#..#....", "#...#...", "#.####..", "##.#....", "...##..."),
    ):
        data=bytearray()
        for row in glyph:
            mask=sum((c=="#")<<(23-x) for x,c in enumerate(row))
            data.extend(mask.to_bytes(3,"big"))
        sprites.extend(data+bytes(64-len(data)))
    (OUT/"sprites.bin").write_bytes(sprites)
    font=bytearray()
    for k in range(32,91):
        font.extend(n<<2 for n in FONT.get(chr(k),FONT[" "]))
        font.append(0)
    (OUT/"font.bin").write_bytes(font)


if __name__=="__main__":
    emit()
