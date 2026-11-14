"""Draw Gun Mayhem's cover directly on the C64's 320-pixel bitmap grid."""
from collections import Counter
from itertools import combinations
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

# Colour distances use the same Colodore palette as the VICE preview.
PALETTE = Path(__file__).resolve().parents[1]/'assets/colodore.vpl'
RGB = [tuple(bytes.fromhex(line)) for line in PALETTE.read_text().splitlines()
       if line.strip() and not line.startswith('#')]

# The two whites look identical. Keep their materials distinct when a cell
# needs a substitute: steel can turn grey, a hot highlight can turn yellow.
HOT_WHITE = len(RGB)
SUBSTITUTES = {
    0: {0}, 1: {0, 1, 12, 15}, 2: {0, 2, 10}, 7: {0, 7, 8},
    8: {0, 2, 8}, 10: {0, 2, 10}, 11: {0, 11, 12, 15},
    12: {0, 11, 12, 15}, 15: {0, 11, 12, 15}, HOT_WHITE: {0, 1, 7},
}

# Separate outlines and counters for the six hand-cut letters. Coordinates
# are independent of the ROM font, including the torn feet and split stems.
CUTS = {
    'M': ([(0,38),(3,7),(1,4),(12,0),(20,17),(27,2),(37,0),(35,33),(28,39),
           (27,20),(20,32),(13,19),(11,34),(5,36),(6,31)], []),
    'A': ([(0,37),(10,7),(21,1),(32,0),(32,35),(23,38),(23,28),(13,29),(10,36)],
          [[(16,21),(23,19),(23,9)]]),
    'Y': ([(0,3),(10,1),(16,14),(24,1),(37,0),(21,24),(20,34),(7,39),(10,23)],
          []),
    'H': ([(1,37),(3,8),(1,5),(14,1),(13,17),(22,14),(23,3),(35,0),(33,32),
           (21,39),(22,24),(12,26),(11,33)], []),
    'E': ([(0,38),(3,6),(0,4),(35,0),(31,10),(15,12),(14,16),(29,13),(25,23),
           (13,25),(12,29),(30,25),(26,35)], []),
    'G': ([(0,29),(4,8),(12,2),(35,0),(32,9),(16,10),(12,15),(10,24),(22,23),
           (23,19),(17,20),(18,14),(34,12),(32,29),(25,33),(5,35)], []),
    'U': ([(0,4),(12,1),(9,21),(10,25),(19,24),(24,2),(36,0),(30,28),(22,33),
           (7,35),(0,29)], []),
    'N': ([(0,34),(4,4),(13,1),(22,15),(25,2),(35,0),(30,31),(22,34),(13,20),
           (10,32)], []),
}


def lettering(size, letters):
    mask = Image.new('L', size)
    draw = ImageDraw.Draw(mask)
    for ch, left, top, width, height, slant in letters:
        shape, holes = CUTS[ch]
        def project(points):
            return [(round(left + x*width/37 + (38-y)*slant/38),
                     round(top + y*height/38)) for x,y in points]
        draw.polygon(project(shape), fill=255)
        for hole in holes:
            draw.polygon(project(hole), fill=0)
    return mask


def draw_cover():
    size = (320,96)
    im = Image.new('P',size)
    im.putpalette(bytes(channel for rgb in [*RGB, RGB[1]] for channel in rgb))
    d = ImageDraw.Draw(im)
    def poly(points, ink):
        d.polygon(points,fill=ink)
    def line(points, ink, width=1):
        d.line(points,fill=ink,width=width)

    # Offset rays and coarse ink dots fade out around the muzzle blast.
    for y in range(3,81,5):
        for x in range(233+(y%2)*2,318,5):
            dx,dy=(x-269)/45,(y-34)/34
            r=dx*dx+dy*dy
            if .38 < r < 1.35:
                radius=1 if r<.85 else 0
                d.rectangle((x,y,x+radius,y+radius),fill=2)
    for pts in [[(272,17),(284,4)],[(295,20),(312,13)],[(293,43),(314,48)],
                [(277,57),(290,71)],[(253,11),(255,3)],[(304,32),(317,29)]]:
        line(pts,10)
    outer=[(224,33),(244,27),(238,14),(253,23),(259,3),(264,20),(278,8),
           (273,24),(297,15),(284,28),(314,26),(290,35),(306,41),(280,40),
           (293,56),(270,45),(273,65),(260,48),(253,58),(252,43),(237,49),(244,38)]
    poly(outer,8)
    poly([(226,33),(247,29),(244,22),(254,27),(258,12),(262,26),(274,17),
          (269,28),(288,22),(279,31),(300,29),(280,35),(293,39),(274,37),
          (282,48),(266,41),(268,53),(260,42),(254,49),(254,39),(242,44),(248,36)],7)
    poly([(223,32),(250,31),(255,26),(256,31),(271,27),(265,32),(282,32),
          (266,35),(271,40),(258,36),(255,41),(252,36),(232,36)],HOT_WHITE)

    # Side profile of the firing pistol. The breech, serrated slide, sights,
    # exposed barrel and trigger guard are all drawn at native resolution.
    poly([(6,78),(23,44),(13,40),(24,30),(86,33),(116,40),(112,49),(96,64),
          (66,64),(59,59),(51,61),(43,78),(37,82),(12,85)],11)
    poly([(7,78),(22,48),(42,52),(34,75),(26,80)],12)
    for x in range(14,36,5):
        line([(x,76),(x+11,53)],11,2)
    poly([(63,48),(75,45),(102,46),(89,58),(68,59)],0)
    line([(77,45),(74,52),(78,55)],15,2)
    line([(74,61),(92,61),(108,47)],15)
    poly([(10,28),(14,19),(24,20),(31,26),(24,33)],12)
    line([(15,21),(22,22),(26,26)],15)
    # The muzzle is square-ended, with a separate bright steel barrel.
    poly([(185,26),(234,24),(239,27),(239,36),(234,38),(195,38)],12)
    d.rectangle((227,27,237,28),fill=1)
    d.rectangle((232,31,238,35),fill=0)
    poly([(17,31),(30,12),(186,7),(213,10),(220,15),(217,39),(207,44),
          (75,49),(45,47),(18,44)],11)
    poly([(25,29),(34,14),(188,10),(210,12),(213,16),(210,32),(202,37),
          (46,43),(24,40)],12)
    poly([(32,15),(186,9),(210,11),(214,14),(40,20),(26,29)],15)
    line([(37,14),(183,9),(209,11)],1)
    line([(25,40),(62,43),(204,37),(211,32)],0,2)
    line([(73,45),(202,40)],15)
    poly([(30,14),(32,8),(43,8),(45,13)],11)
    line([(33,8),(41,8)],15)
    poly([(193,9),(195,4),(202,4),(205,10)],11)
    line([(195,4),(201,4)],1)
    for x in (32,37,42,47):
        line([(x+4,21),(x,31)],11,2)
    poly([(151,15),(177,14),(173,20),(148,21)],0)
    line([(152,16),(174,15)],11)
    for x in (183,189,195,201):
        line([(x+3,19),(x,26)],11,2)

    # The name is engraved across the slide. Its black keyline separates the
    # ivory lettering from the steel rather than reducing the gun to a box.
    name = lettering(size,[('G',49,15,31,29,3),('U',80,14,31,29,3),
                           ('N',112,12,33,29,3)])
    im.paste(0,mask=name.filter(ImageFilter.MaxFilter(3)))
    im.paste(1,mask=name)
    # A die-stamped 64 sits under the ejection port.
    for idx, rows in enumerate([('0111','1000','1110','1011','0110'),
                                ('1010','1010','1111','0010','0010')]):
        for yy,row in enumerate(rows):
            for xx,bit in enumerate(row):
                if bit=='1': d.rectangle((154+idx*12+xx*2,25+yy*2,155+idx*12+xx*2,26+yy*2),fill=0)

    # Keep the bevel inside the lower wordmark's irregular silhouette.
    main=lettering(size,[('M',7,49,46,38,9),('A',52,47,41,39,7),
                         ('Y',91,45,35,42,8),('H',123,47,43,39,7),
                         ('E',166,43,40,41,8),('M',202,46,49,38,10)])
    outline=main.filter(ImageFilter.MaxFilter(5))
    im.paste(0,mask=outline)
    # Colour is laid into the letter mask, so the torn edges and counters stay open.
    finish=Image.new('P',size,7)
    gloss=ImageDraw.Draw(finish)
    gloss.polygon([(0,43),(260,39),(260,45),(0,55)],fill=HOT_WHITE)
    gloss.polygon([(0,86),(260,77),(260,96),(0,96)],fill=8)
    for x,y,w in [(22,54,10),(66,60,6),(103,51,6),(151,58,6),(186,53,10),
                  (227,55,8),(35,75,4),(135,72,4),(211,76,5)]:
        gloss.line((x,y,x+w,y-2),fill=0)
    im.paste(finish,mask=main)
    # Shell casing spinning out of the open action.
    poly([(139,5),(151,0),(153,2),(142,8)],8)
    line([(141,5),(151,1)],7,2)
    return im


def encode(im):
    # Multicolor bitmap mode reserves black globally and has three local inks.
    # A VIC pixel is two source dots wide. It may take only a colour allowed
    # by BOTH dots, so even a single black outline dot vetoes painting the pair.
    distance = [[sum(w*(a-b)**2 for a,b,w in zip(rgb,other,(2,3,1)))
                 for other in RGB] for rgb in [*RGB, RGB[1]]]
    bits, matrix, color_ram = bytearray(), bytearray(), bytearray()
    for y in range(0, im.height, 8):
        for x in range(0, im.width, 8):
            cell = im.crop((x, y, x+8, y+8)).tobytes()
            pairs = list(zip(cell[::2], cell[1::2]))
            counts = Counter(pairs)
            colours = sorted({1 if c == HOT_WHITE else c for c in cell} - {0})
            best_error = None
            for inks in combinations(colours, min(3, len(colours))):
                palette = (0, *inks)
                codes = {}
                error = 0
                for (left, right), count in counts.items():
                    allowed = SUBSTITUTES[left] & SUBSTITUTES[right]
                    cost, code = min((distance[left][ink] + distance[right][ink], i)
                                     for i, ink in enumerate(palette) if ink in allowed)
                    codes[left, right] = code
                    error += count * cost
                if best_error is None or error < best_error:
                    best_error = error
                    best_codes = codes
                    registers = (*inks, 0, 0, 0)
            matrix.append(registers[0] << 4 | registers[1])
            color_ram.append(registers[2])
            for offset in range(0, len(pairs), 4):
                bits.append(sum(best_codes[pair] << (6 - 2*i)
                                for i, pair in enumerate(pairs[offset:offset+4])))
    return bytes(bits), bytes(matrix), bytes(color_ram)


def generate_title(output):
    bits, inks, color_ram = encode(draw_cover())
    packed = bytearray()
    for start in range(0, len(bits), 8):
        rows = bits[start:start+8]
        previous = 0
        mask = 0
        changed = bytearray()
        for i, row in enumerate(rows):
            if row != previous:
                mask |= 0x80 >> i
                changed.append(row)
                previous = row
        packed.append(mask)
        packed.extend(changed)
    (output/'title-cover.bin').write_bytes(packed)
    (output/'title-ink.bin').write_bytes(inks)
    (output/'title-color.bin').write_bytes(color_ram)
