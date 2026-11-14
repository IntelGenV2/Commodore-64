"""Build C64 character tiles, turret poses and campaign data."""
from math import cos, sin, tau
from pathlib import Path
from score import write_score
from turrets import turret_atlas
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build"
OUT.mkdir(exist_ok=True)
write_score(OUT)


def cdata(name, data, kind="unsigned char"):
    return "const " + kind + " " + name + "[] = {\n" + "".join(
        "    " + ",".join(map(str, data[i:i + 24])) + ",\n" for i in range(0, len(data), 24)
    ) + "};\n"


def image(size=(8, 16)):
    im = Image.new("L", size)
    return im, ImageDraw.Draw(im)


def terrain(style, angle=6):
    # Each 16x16 tile is eight multicolor pixels wide. 0 = charcoal,
    # 1 = brown, 2 = silver, 3 = the tile's own color.
    im, d = image()
    if style.startswith("dust"):
        d.rectangle((0, 0, 7, 15), fill=1)
        for p in [(1, 3), (6, 11)] if style == "dust" else [(3, 13), (5, 5)]:
            d.point(p, 0)
    elif style in ("brick", "heavy"):
        for y in range(0, 16, 4 if style == "brick" else 8):
            step = 4 if style == "brick" else 8
            for x in range(-4 + (y // step % 2) * 2, 8, 4):
                d.rectangle((x, y, x + 2, y + step - 2), fill=3)
                d.line((x, y + step - 2, x + 2, y + step - 2), fill=1)
                if style == "heavy":
                    d.line((x, y, x+2, y),fill=2)
    elif style in ("stone", "crack"):
        d.rectangle((0, 0, 7, 15), fill=0)
        d.rectangle((1, 1, 6, 13), fill=2)
        d.line((1, 1, 5, 1), fill=3)
        d.line((1, 2, 1, 4), fill=3)
        d.point((5, 5),fill=0)
        d.line((5, 12, 6, 11), fill=0)
        if style == "crack":
            d.line([(5, 1), (3, 6), (4, 8), (2, 12)], fill=0)
    elif style in ("wood", "crate"):
        d.rectangle((0, 0, 7, 14), fill=1)
        for x in (0, 3, 6):
            d.line((x, 1, x, 13), fill=0)
            d.line((x+1, 2+x, x+1, 4+x), fill=3)
        if style == "crate":
            d.rectangle((0, 0, 7, 14), outline=0)
            d.line((1, 1, 6, 1), fill=3)
            d.line((1, 2, 6, 12), fill=3)
            d.line((6, 2, 1, 12), fill=3)
    elif style == "gate":
        for x in (1, 4, 7):
            d.rectangle((x, 0, x, 15), fill=2)
        for y in (3, 11):
            d.rectangle((0, y, 7, y + 1), fill=3)
    elif style == "barrel":
        d.rectangle((0, 0, 7, 15), fill=1)
        d.rounded_rectangle((1, 1, 6, 14), radius=2, fill=3, outline=0)
        for y in (4, 10):
            d.line((2, y, 5, y), fill=2)
    elif style in ("depot", "tower", "boss"):
        d.rounded_rectangle((0, 0, 7, 15), 2, fill=0, outline=2)
        d.rectangle((1, 2, 6, 13), fill=3)
        if style == "depot":
            for x in (2, 4, 6):
                d.line((x, 5, x, 10), fill=0)
        elif style == "boss":
            d.ellipse((1, 4, 6, 11), fill=0)
            d.line((3,7,round(3.5+3.5*cos(tau*angle/8)),round(7+7*sin(tau*angle/8))),fill=2,width=2)
        else:
            d.rectangle((1, 2, 6, 13), fill=1, outline=0)
            for x in (1, 6):
                for y in (2, 13):
                    d.point((x, y), fill=2)
    elif style in ("coin", "repair", "ammo"):
        d.rectangle((0, 0, 7, 15), fill=1)
        if style == "coin":
            d.ellipse((1, 3, 6, 12), fill=3, outline=0)
            d.line((3, 5, 3, 9), fill=2)
        elif style == "repair":
            d.rectangle((1, 4, 6, 12), fill=2, outline=0)
            d.line((3, 6, 3, 10), fill=3)
            d.line((2, 8, 4, 8), fill=3)
        else:
            for x in (2, 4, 6):
                d.line((x, 5, x, 11), fill=3)
    return im


styles = ["void", "dust", "dust2", "brick", "heavy", "stone", "crate", "gate", "barrel",
          "depot", "tower", "boss", "wood", "crack", "coin", "repair", "ammo"]
inks = [0, 0, 0, 2, 2, 1, 7, 7, 2, 5, 4, 2, 7, 1, 7, 2, 7]
tiles = bytearray()
def tile_bytes(im):
    result = bytearray()
    for cy in (0, 8):
        for cx in (0, 4):
            for y in range(cy, cy + 8):
                result.append(sum(im.getpixel((cx + x, y)) << (6 - x * 2) for x in range(4)))
    return result
for style in styles:
    tiles.extend(tile_bytes(terrain(style)))
style_for_id = [0, 1, 3, 4, 5, 6, 1, 7, 8] + [9] * 7 + [10] * 8 + [11] * 7 + [12, 13, 14, 15, 16, 2]
style_for_id.extend((15,8))  # freeze capsule and burning bomb
assert len(style_for_id) == 39


def sprite_frame(kind, angle):
    im, d = image((24, 21))
    c, s = cos(angle), sin(angle)

    def poly(points, color):
        d.polygon([(round(11.5 + x * c - y * s), round(10 + x * s + y * c)) for x, y in points], fill=color)

    def rect(x1, y1, x2, y2, color):
        poly([(x1, y1), (x2, y1), (x2, y2), (x1, y2)], color)

    # Sprite value 1 is the shared dark outline, 3 the shared highlight.
    wide = 1 if kind == "boss" else 0
    for side in (-1, 1):
        outer, inner = side * (8 + wide), side * 4
        rect(-8, inner, 8, outer, 1)
        rect(-7, side * 5, 7, side * (7 + wide), 2)
        for x in (-5, 0, 5):
            rect(x, side * 6, x+1, side * (7+wide), 1)
    poly([(-7,-4),(5,-4),(7,-2),(7,2),(5,4),(-7,4)], 2)
    rect(-6, -3, -5, 3, 1)
    rect(4, -3, 5, -2, 3)
    data = bytearray()
    for y in range(21):
        for col in range(3):
            data.append(sum(im.getpixel((col * 8 + x * 2, y)) << (6 - x * 2) for x in range(4)))
    return data + bytes(1)


# Slots 8 and 9 hold the player's head and enemy compositing scratch.
sprites = bytearray(b"".join(sprite_frame("hull", tau*i/8) for i in range(8)) + bytes(128))
atlas, pointers = turret_atlas(0xe000 + len(sprites))
(OUT / "turrets.inc").write_text(pointers)
sprites.extend(atlas)
assert len(sprites) <= 44*64, "Turret atlas overlaps boss hulls"
sprites.extend(bytes(44*64 - len(sprites)))
sprites.extend(b"".join(sprite_frame("boss", tau*i/4) for i in range(4)))

def pack_sprites(data):
    """Choose shortest encodings of literal runs and two-byte back references."""
    count = len(data)
    costs = [0] * (count + 1)
    steps = [None] * count
    for i in reversed(range(count)):
        best, length, distance = 2*count + 1, 0, 0
        for size in range(1, min(127, count-i) + 1):
            cost = 1 + size + costs[i+size]
            if cost < best:
                best, length = cost, size
        for size in range(2, min(65, count-i) + 1):
            match = data.rfind(data[i:i+size], max(0, i-1280), i+size-1)
            if match < 0:
                break
            back = i - match
            if back > 256 and (size < 3 or size > 18):
                continue
            cost = 2 + costs[i+size]
            if cost < best:
                best, length, distance = cost, size, back
        costs[i], steps[i] = best, (length, distance)
    encoded = bytearray()
    i = 0
    while i < count:
        length, distance = steps[i]
        if distance:
            token = (0x80 + length-2 if distance <= 256 else
                     0xc0 + ((distance-257)//256)*16 + length-3)
            encoded.extend((token, (distance-1) & 255))
        else:
            encoded.append(length)
            encoded.extend(data[i:i+length])
        i += length
    encoded.append(0)
    return encoded

(OUT / "sprites.bin").write_bytes(pack_sprites(sprites))
# Cracks widen through the roof and expose a dark breach on the last stage.
damaged = bytearray()
for severe in (False, True):
    roof = [[0]*8 for _ in range(16)]
    for y in range(1,15):
        for x in range(8):
            roof[y][x] = 2 if y in (1,14) or x in (0,7) else 3
    for y in (5,7,9):
        for x in range(2,6): roof[y][x]=0
    for y in range(2,14 if severe else 9):
        x=(3,3,2,3,4,4)[y%6];roof[y][x]=0
        if severe: roof[y][x+1]=0
    for oy,ox in ((0,0),(0,4),(8,0),(8,4)):
        for y in range(oy,oy+8):
            damaged.append(sum(roof[y][ox+x] << (6-2*x) for x in range(4)))
(OUT/"damage.bin").write_bytes(pack_sprites(damaged))
(OUT / "tiles.bin").write_bytes(pack_sprites(tiles))
(OUT / "tower-base.bin").write_bytes(tile_bytes(terrain("tower")))

# The title graphic uses a separate hires character set and the full C64 palette.
im, d = image((320, 100))
alphabet = {
    "A":["01110","11011","11011","11111","11011","11011","11011"],
    "W":["11011","11011","11011","11011","11111","11111","01010"],
    "E":["11111","11000","11000","11110","11000","11000","11111"],
    "S":["01111","11000","11000","01110","00011","00011","11110"],
    "O":["01110","11011","11011","11011","11011","11011","01110"],
    "M":["11011","11111","11111","11011","11011","11011","11011"],
    "T":["11111","11111","00110","00110","00110","00110","00110"],
    "N":["11001","11101","11101","11111","11011","11011","11001"],
    "K":["11011","11011","11110","11100","11110","11011","11011"],
    "2":["11110","00011","00011","01110","11000","11000","11111"],
}


def word(text, x, y, sx, sy, ink):
    for i, letter in enumerate(text):
        if letter == " ":
            continue
        for row, line in enumerate(alphabet[letter]):
            for col, bit in enumerate(line):
                if bit == "1":
                    left = x + (i * 6 + col) * sx + ((6 - row) // 2 if sx==5 else 0)
                    top = y + row * sy
                    d.rectangle((left, top, left + sx - 1, top + sy - 1), fill=ink)


word("AWESOME", 8, 8, 4, 4, 15)
word("TANKS 2", 9, 47, 5, 6, 7)
# Top-down tank plate on the right, with a distinct track tread and gun muzzle.
d.polygon([(244,24),(251,17),(288,17),(296,25),(296,79),(289,88),(249,88),(242,80)], fill=11)
for x in (237,285):
    d.rounded_rectangle((x,20,x+15,84),4,fill=12)
    for y in range(24,81,7):
        d.rectangle((x+1,y,x+14,y+2),fill=0)
d.polygon([(254,24),(278,24),(286,34),(286,72),(277,81),(253,81),(248,74),(248,34)],fill=5)
d.line((252,76,280,76),fill=13,width=2)
for x in range(254,281,5):
    d.line((x,66,x,72),fill=0,width=2)
d.polygon([(253,41),(258,34),(273,34),(279,40),(279,52),(271,59),(257,57),(251,50)],fill=13)
d.line((258,48,280,19), fill=0,width=8)
d.line((260,46,285,12), fill=15,width=5)
d.line((279,21,288,9),fill=12,width=8)
d.line((281,19,287,11),fill=1,width=2)
for x,y,dx,dy in [(228,7,1,1),(309,7,-1,1),(228,91,1,-1),(309,91,-1,-1)]:
    d.line((x,y,x+6*dx,y),fill=11)
    d.line((x,y,x,y+5*dy),fill=11)

patterns = [bytes(8)]
title_chars, title_ink = [], []
for cy in range(12):
    for cx in range(40):
        box = im.crop((cx*8, cy*8, cx*8+8, cy*8+8))
        counts = [(n, v) for n, v in box.getcolors() if v]
        ink = max(counts)[1] if counts else 0
        bits = bytes(sum(bool(box.getpixel((x,y))) << (7-x) for x in range(8)) for y in range(8))
        if bits not in patterns:
            patterns.append(bits)
        title_chars.append(32 if not any(bits) else 63 + patterns.index(bits))
        title_ink.append(ink)
assert len(patterns) <= 193, len(patterns)
(OUT / "title.bin").write_bytes(b"".join(patterns[1:]))

arenas = []
for block in (ROOT / "src/arenas.txt").read_text().strip().split("\n\n"):
    rows = block.splitlines()[1:]
    grid = [int(c, 36) for row in rows for c in row]
    assert sum(9<=t<=30 for t in grid)<=16 and len(rows)<=23 and len(rows[0])<=24
    assert sum(16<=t<24 for t in grid)<=8, "Each fixed tower needs its own four glyphs"
    assert len(set(map(len, rows))) == 1 and grid.count(6) == 1
    # High bit marks a run. Every original editor ID fits in six bits.
    packed = [len(rows[0]), len(rows)]
    i = 0
    while i < len(grid):
        j = i + 1
        while j < len(grid) and grid[j] == grid[i] and j-i < 255:
            j += 1
        if j-i >= 3:
            packed.extend((128+grid[i], j-i))
        else:
            packed.extend(grid[i:j])
        i = j
    arenas.append(packed)
assert len(arenas) == 15
h = cdata("tile_code", [64 + n*4 for n in style_for_id]) + cdata("tile_ink", [inks[n]+8 for n in style_for_id[:-2]]+[14,10])
(OUT/"titlemap.bin").write_bytes(pack_sprites(bytes(title_chars)))
(OUT/"titleink.bin").write_bytes(pack_sprites(bytes(title_ink)))
h += f"#define TITLE_BYTES {(len(patterns)-1)*8}u\n"
for axis, fn in [("vx", cos), ("vy", sin)]:
    h += cdata(axis, [round(16*fn(tau*i/32)) for i in range(32)], "signed char")
# Arena data lives in RAM under I/O. Copy two pages into the idle route queue
# before expanding a sector. The last arena has a padded second page.
bank = bytearray()
addresses = []
for arena in arenas:
    addresses.append(0xd000 + len(bank))
    packed_arena=pack_sprites(bytes(arena))
    assert len(packed_arena)<=512
    bank.extend(packed_arena)
addresses.append(0xd000 + len(bank))
packed_title = pack_sprites((OUT/"title.bin").read_bytes())
assert len(packed_title)<=1024
bank.extend(packed_title)
assert max(map(len, arenas)) <= 512 and len(bank) <= 4096
assert max(len(row) for block in (ROOT/"src/arenas.txt").read_text().strip().split("\n\n") for row in block.splitlines()[1:]) <= 24
(OUT / "arenas.bin").write_bytes(bank)
h += "const unsigned int arena_address[] = {" + ",".join((hex(a) for a in addresses)) + "};\n"
(OUT / "assets.h").write_text(h)
